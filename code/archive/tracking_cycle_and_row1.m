%% TRACKING_CYCLE_AND_ROW1
%  Row 1 of Figure 2.
%
%    Panel a  perceived difficulty by condition
%    Panel b  tracking error by condition, and across the movement cycle
%
%  The cycle-resolved tracking error is warped here rather than loaded,
%  since no warped copy survives. Flexion and extension are warped
%  separately onto equal halves, matching the EMG warp targets of
%  [0 2000 4000]. See the note beside NHALF for why the two datasets
%  agree on that composition once their sampling rates are accounted for.
%
%  Note the sample sizes differ between rows. Tracking and ratings have
%  all 14 participants; the EMG row has 13, since one contributed no
%  usable EMG. Both numbers appear in the figure and must be stated in
%  the Participants subsection.
%
%  Requires: Statistics and Machine Learning Toolbox.
% =====================================================================

clc; clear;

%% 0. Configuration and load
% ---------------------------------------------------------------------
cfg = ansymb_config();
addpath(genpath(cfg.code));

load([cfg.derived, filesep, 'behavior_table.mat'], 'T');
load('Subject_Tracking_Error.mat');          % adjust path if needed

LEVELS     = [1 3 6];
COND_NAMES = {'Low', 'Medium', 'High'};

% Warp composition. The EMG was warped to [0 2000 4000], placing the
% reversal at exactly 50% of the cycle, so the tracking data is warped to
% the same composition and both panels mark the reversal at the same
% point in the movement.
%
% This is a deliberate choice, not an assumption. Computing the median
% event indices within each subject and then across subjects gives a
% flexion fraction of 0.515 for tracking against 0.503 for the EMG before
% rounding. That gap is 1.2% of the cycle, and one tracking sample is
% about 1.4% of the cycle, so the difference is finer than the tracking
% data can resolve. The two agree subject by subject to a mean absolute
% difference of 0.006 and preserve the same ranking, which is what rules
% out a segmentation difference between the pipelines.
NHALF  = 25;                 % warped samples per phase
NSAMP  = 2 * NHALF;          % 50 points, so 2% of the cycle per sample

% Native resolution is a median of roughly 34 samples per cycle, so 50
% warped points is a modest upsample. Going higher would imply a temporal
% precision the recording does not have.
N_PERM = 5000;
CLUST_ALPHA = 0.05;
RNG_SEED    = 21;

subject_list = 5:18;

% Show pairwise brackets on the tracking condition panel. Off by default:
% no pairwise comparison survives Holm correction, so all three would
% read "n.s.", which is clutter. The omnibus result goes in the caption.
SHOW_TRACK_BRACKETS = false;


%% 1. Screen the behaviour table
% ---------------------------------------------------------------------
if iscategorical(T.Pressure)
    Tpres = str2double(string(T.Pressure));
else
    Tpres = double(T.Pressure);
end
Tsubj = double(string(T.SubjectID));

bad   = T.Score == 0 | isnan(T.Score) | T.Score < 1 | T.Score > 10;
T     = T(~bad,:); Tpres = Tpres(~bad); Tsubj = Tsubj(~bad);

fprintf('Screened table: %d trials, %d subjects\n\n', height(T), numel(unique(Tsubj)));


%% 2. Per-subject condition means for ratings and tracking error
% ---------------------------------------------------------------------
subs   = unique(Tsubj, 'stable');
nSubj  = numel(subs);
nCond  = numel(LEVELS);

M_sub = nan(nSubj, nCond);       % perceived difficulty
E_sub = nan(nSubj, nCond);       % tracking error

for i = 1:nSubj
    for c = 1:nCond
        sel = Tsubj == subs(i) & Tpres == LEVELS(c);
        M_sub(i,c) = mean(T.Score(sel));
        E_sub(i,c) = mean(T.Error(sel));
    end
end

mM  = mean(M_sub,1);  mSD  = std(M_sub,0,1);
eM  = mean(E_sub,1);  eSD  = std(E_sub,0,1);

fprintf('--- Perceived difficulty ---\n');
for c = 1:nCond
    fprintf('%-7s %.2f +- %.2f\n', COND_NAMES{c}, mM(c), mSD(c));
end
fprintf('Demand effect: %.2f rating points\n', mM(3)-mM(1));

fprintf('\n--- Tracking error (deg) ---\n');
for c = 1:nCond
    fprintf('%-7s %.2f +- %.2f\n', COND_NAMES{c}, eM(c), eSD(c));
end
fprintf('High minus Low: %+.2f deg\n\n', eM(3)-eM(1));

% Ratings: rank-based, chosen a priori because the rating scale is
% bounded and ordinal.
pairs = [1 2; 1 3; 2 3]; nP = size(pairs,1);
pR = nan(nP,1); pR_holm = nan(nP,1);
for c = 1:nP
    pR(c) = signrank(M_sub(:,pairs(c,2)), M_sub(:,pairs(c,1)), 'method','exact');
end
[ps,o] = sort(pR); pR_holm(o) = min(cummax(ps .* (nP:-1:1)'),1);

% Tracking error: continuous, so parametric.
pE = nan(nP,1); pE_holm = nan(nP,1);
for c = 1:nP
    [~, pE(c)] = ttest(E_sub(:,pairs(c,2)) - E_sub(:,pairs(c,1)));
end
[ps,o] = sort(pE); pE_holm(o) = min(cummax(ps .* (nP:-1:1)'),1);


%% 3. Warp the cycle-resolved tracking error
% ---------------------------------------------------------------------
% Epochs are stored raw, at 43 to 53 samples each, with events giving
% [start, flexion end, extension end] as sample indices. Flexion and
% extension are warped separately onto NHALF points each, which places
% the reversal at 50% and matches the EMG convention.
%
% Averaging order is epochs within trial, then trials within condition,
% for the same reason as the EMG: epoch counts vary between trials, and
% trial is the unit used everywhere else.

curves = nan(nSubj, NSAMP, nCond);
joinChk = [];

for s = 1:numel(subject_list)

    subID = subject_list(s);
    if isempty(Subject_Tracking_Error{s}), continue; end
    trk = Subject_Tracking_Error{s};

    iSub = find(subs == subID);
    if isempty(iSub), continue; end

    rows    = Tsubj == subID;
    keepIDs = T.Trial(rows);
    keepP   = Tpres(rows);
    keepS   = T.Score(rows);

    % Verify the join before using it. The epoch-level pressure and score
    % must agree with the behaviour table row carrying that trial number.
    [tf, loc] = ismember(trk.trial, keepIDs);
    agree = mean(trk.pressure(tf) == keepP(loc(tf)) & ...
                 trk.score(tf)    == keepS(loc(tf)));
    joinChk = [joinChk; subID, sum(tf), numel(keepIDs), agree]; %#ok<AGROW>

    % Warp every retained epoch.
    nEp     = numel(trk.tracking_error);
    warped  = nan(nEp, NSAMP);
    for k = 1:nEp
        if ~tf(k), continue; end
        te = trk.tracking_error{k}(:)';
        ev = trk.events(k,:);
        if ev(3) > numel(te) || ev(2) <= ev(1) || ev(3) <= ev(2)+1, continue; end

        flx = te(ev(1):ev(2));
        ext = te(ev(2)+1:ev(3));
        warped(k,:) = [interp1(1:numel(flx), flx, linspace(1,numel(flx),NHALF)), ...
                       interp1(1:numel(ext), ext, linspace(1,numel(ext),NHALF))];
    end

    % Epochs to trials, then trials to conditions.
    uTr = unique(trk.trial(tf));
    trialCurve = nan(numel(uTr), NSAMP);
    trialPres  = nan(numel(uTr), 1);
    for t = 1:numel(uTr)
        sel = trk.trial == uTr(t) & tf & ~all(isnan(warped),2);
        if ~any(sel), continue; end
        trialCurve(t,:) = mean(warped(sel,:), 1, 'omitnan');
        trialPres(t)    = trk.pressure(find(sel,1));
    end

    for c = 1:nCond
        sel = trialPres == LEVELS(c) & ~all(isnan(trialCurve),2);
        curves(iSub,:,c) = mean(trialCurve(sel,:), 1, 'omitnan');
    end
end

J = array2table(joinChk, 'VariableNames', ...
    {'Subject','EpochsMatched','TableTrials','PressScoreAgree'});
fprintf('--- Join check ---\n');
disp(J);
fprintf('Mean agreement: %.3f (should be 1.000)\n\n', mean(J.PressScoreAgree));


%% 4. Cluster-based permutation on the cycle-resolved error
% ---------------------------------------------------------------------
% Same procedure as the EMG row: a repeated measures F at each warped
% sample, contiguous suprathreshold samples grouped into clusters, and a
% null built by permuting condition labels within participant.

rng(RNG_SEED,'twister');
dfC = nCond - 1;
dfE = (nSubj - 1) * (nCond - 1);
Fcrit = finv(1 - CLUST_ALPHA, dfC, dfE);

Y = permute(curves, [1 3 2]);                    % nSubj x nCond x NSAMP
[Fobs, etaObs] = rmF(Y);
[obsMass, obsRuns] = clusterMass(Fobs, Fcrit);

nullMax = zeros(N_PERM,1);
for p = 1:N_PERM
    Yp = Y;
    for i = 1:nSubj
        Yp(i,:,:) = Y(i, randperm(nCond), :);
    end
    nullMax(p) = max([clusterMass(rmF(Yp), Fcrit); 0]);
end

fprintf('--- Tracking error, cycle-resolved ---\n');
fprintf('Cluster threshold F(%d,%d) > %.3f, %d permutations\n', dfC, dfE, Fcrit, N_PERM);
[pk, pkIdx] = max(etaObs);
fprintf('Peak partial eta2 = %.3f at %.1f%% of cycle\n', pk, pkIdx/NSAMP*100);
fprintf('Mean partial eta2: flexion %.3f, extension %.3f\n', ...
    mean(etaObs(1:NHALF)), mean(etaObs(NHALF+1:end)));

trackClusters = table();
if isempty(obsMass)
    fprintf('No suprathreshold cluster.\n\n');
else
    pClust = arrayfun(@(x)(sum(nullMax >= x)+1)/(N_PERM+1), obsMass);
    trackClusters = table(obsRuns(:,1)/NSAMP*100, obsRuns(:,2)/NSAMP*100, ...
        obsMass(:), pClust(:), ...
        'VariableNames', {'StartPct','EndPct','Mass','p'});
    trackClusters = sortrows(trackClusters,'Mass','descend');
    disp(trackClusters);
end


%% 5. Figure, row 1
% ---------------------------------------------------------------------
COL = [1 115 178; 222 143 5; 148 73 92]/255;
FS_TICK = 6; FS_LAB = 7; FS_PANEL = 8; FS_EVENT = 5.5; FONT = 'Arial';

% Gap between the axis labels and the tick labels, applied through
% padLabels to every axis in the figure. The same two values should be
% used in the EMG row so the spacing is uniform across the whole of
% Figure 2. Kept as separate constants because horizontal and vertical
% breathing room do not always want the same number.
XLAB_PAD = 0.18;             % centimetres, below the x tick labels
YLAB_PAD = 0.18;             % centimetres, left of the y tick labels

% Row 1 divides the canvas differently from row 2, which is fine: the
% margins, fonts and panel heights match. The two tracking plots sit
% close enough to read as one panel but far enough apart that the
% effect-size strip's y-label clears the panel to its left.
figW = 18.0; figH = 6.4;
mainY = 1.95; mainH = 2.85;
stripY = 1.20; stripH = 0.55;
fullH  = mainY + mainH - stripY;
TITLE_OFF = 0.50;

xA  = 1.30;  wA  = 4.10;
xB1 = 7.15;  wB1 = 4.10;
xB2 = 12.70; wB2 = 4.45;

fig1 = figure('Units','centimeters','Position',[1 1 figW figH], ...
              'Color','w','PaperPositionMode','auto');

% ---- Panel a: perceived difficulty -----------------------------------
axA = axes(fig1,'Units','centimeters','Position',[xA stripY wA fullH]);
hold(axA,'on');
plotConditionCloud(axA, M_sub, COL, nCond);

% One combined bracket rather than three. All three pairwise comparisons
% are significant, so three separate brackets would repeat the same
% symbol three times. A single rule with a tick under each condition
% says the same thing once. The caption carries the exact p values.
ylim(axA, [0.5 10.5]);
combinedBracket(axA, 1:nCond, 9.35, 0.30, allSame(pR_holm), FONT, FS_EVENT, false);

set(axA,'XTick',1:nCond,'XTickLabel',COND_NAMES,'YTick',1:10, ...
    'FontName',FONT,'FontSize',FS_TICK,'TickDir','in','Box','off','LineWidth',0.5);
ylabel(axA,'Perceived difficulty','FontName',FONT,'FontSize',FS_LAB);
xlabel(axA,'Physical demand','FontName',FONT,'FontSize',FS_LAB);
padLabels(axA,  XLAB_PAD, YLAB_PAD);
hold(axA,'off');

% ---- Panel b, left: tracking error by condition ----------------------
axB1 = axes(fig1,'Units','centimeters','Position',[xB1 stripY wB1 fullH]);
hold(axB1,'on');
plotConditionCloud(axB1, E_sub, COL, nCond);

ylAuto = ylim(axB1); axTop = ylAuto(2);
% Same combined form as panel a. Here no pairwise comparison survives
% Holm correction, so the single label reads n.s. rather than listing
% three identical verdicts. It sits below the data, where the panel has
% empty space once the axis is anchored at zero.
dataLow = min([E_sub(:); (eM-eSD)']);
combinedBracket(axB1, 1:nCond, dataLow - 0.14*axTop, 0.045*axTop, ...
    allSame(pE_holm), FONT, FS_EVENT, true);
ylim(axB1,[0 axTop]);

set(axB1,'XTick',1:nCond,'XTickLabel',COND_NAMES,'YTick',0:2:floor(axTop), ...
    'FontName',FONT,'FontSize',FS_TICK,'TickDir','in','Box','off','LineWidth',0.5);
ylabel(axB1,'Tracking error (deg)','FontName',FONT,'FontSize',FS_LAB);
xlabel(axB1,'Physical demand','FontName',FONT,'FontSize',FS_LAB);
th = title(axB1,'By condition','FontName',FONT,'FontSize',FS_LAB,'FontWeight','normal');
th.Units='centimeters'; th.Position(2) = fullH + TITLE_OFF;
padLabels(axB1, XLAB_PAD, YLAB_PAD);
hold(axB1,'off');

% ---- Panel b, right: tracking error across the cycle -----------------
axB2 = axes(fig1,'Units','centimeters','Position',[xB2 mainY wB2 mainH]);
hold(axB2,'on');

% Spanning 0 to 100 inclusive, so the axis starts at the cycle start
% rather than one sample after it.
cyclePct = linspace(0, 100, NSAMP);
mu  = squeeze(mean(curves,1,'omitnan'))';
sem = squeeze(std(curves,0,1,'omitnan'))'/sqrt(nSubj);

for c = 1:nCond
    fill(axB2,[cyclePct fliplr(cyclePct)], ...
        [mu(c,:)+sem(c,:), fliplr(mu(c,:)-sem(c,:))], COL(c,:), ...
        'EdgeColor','none','FaceAlpha',0.30,'HandleVisibility','off');
end
for c = 1:nCond
    plot(axB2, cyclePct, mu(c,:), 'Color', COL(c,:), 'LineWidth', 0.9);
end

yTop = max(mu(:)+sem(:)) * 1.10;
ylim(axB2,[0 yTop]); xlim(axB2,[0 100]);
plot(axB2,[50 50],[0 yTop],'--','Color',[0.35 0.35 0.35], ...
    'LineWidth',0.5,'HandleVisibility','off');

evLabels = {'FlxS', sprintf('FlxE\nExtS'), 'ExtE'};
EV_X = [2 50 98];
for e = 1:3
    text(axB2, EV_X(e), yTop, evLabels{e}, 'Rotation',90, ...
        'HorizontalAlignment','left','VerticalAlignment','middle', ...
        'Clipping','off','FontName',FONT,'FontSize',FS_EVENT, ...
        'Color',[0.25 0.25 0.25]);
end

set(axB2,'XTick',[0 50 100],'XTickLabel',[], ...
    'FontName',FONT,'FontSize',FS_TICK,'TickDir','in','Box','on','LineWidth',0.5);
ylabel(axB2,'Tracking error (deg)','FontName',FONT,'FontSize',FS_LAB);

% Legend moved to the bottom centre. The curves peak either side of the
% reversal and dip to their minimum at it, so the space beneath the
% midpoint is the only region no condition occupies.
lg = legend(axB2, COND_NAMES,'Location','south','Orientation','horizontal', ...
    'FontName',FONT,'FontSize',FS_TICK);
legend(axB2,'boxoff'); lg.ItemTokenSize = [7 7];

th = title(axB2,'Across the movement cycle','FontName',FONT,'FontSize',FS_LAB,'FontWeight','normal');
th.Units='centimeters'; th.Position(2) = mainH + TITLE_OFF;
padLabels(axB2, XLAB_PAD, YLAB_PAD);
hold(axB2,'off');

% Effect-size strip
axS = axes(fig1,'Units','centimeters','Position',[xB2 stripY wB2 stripH]);
hold(axS,'on');
plot(axS, cyclePct, etaObs, '-', 'Color',[0.25 0.25 0.25],'LineWidth',0.7);
plot(axS, [0 100],[0.14 0.14],':','Color',[0.5 0.5 0.5],'LineWidth',0.5);
plot(axS, [50 50],[0 1],'--','Color',[0.35 0.35 0.35],'LineWidth',0.5);
if ~isempty(trackClusters)
    sig = trackClusters(trackClusters.p < 0.05,:);
    for k = 1:height(sig)
        plot(axS,[sig.StartPct(k) sig.EndPct(k)],[-0.08 -0.08],'k-','LineWidth',1.8);
    end
end
ylim(axS,[-0.16 1]); xlim(axS,[0 100]);
set(axS,'XTick',[0 50 100],'YTick',[0 0.5 1], ...
    'FontName',FONT,'FontSize',FS_TICK,'TickDir','in','Box','off','LineWidth',0.5);
xlabel(axS,'Cycle (%)','FontName',FONT,'FontSize',FS_LAB);
ylabel(axS,'\eta^2_p','FontName',FONT,'FontSize',FS_LAB);
padLabels(axS,  XLAB_PAD, YLAB_PAD);
hold(axS,'off');

% ---- Panel letters ---------------------------------------------------
annotation(fig1,'textbox',[0.004 0.925 0.05 0.07],'String','a', ...
    'FontName',FONT,'FontSize',FS_PANEL,'FontWeight','bold', ...
    'EdgeColor','none','VerticalAlignment','middle');
annotation(fig1,'textbox',[(xB1-1.10)/figW 0.925 0.05 0.07],'String','b', ...
    'FontName',FONT,'FontSize',FS_PANEL,'FontWeight','bold', ...
    'EdgeColor','none','VerticalAlignment','middle');

% ---- Export ----------------------------------------------------------
if isfield(cfg,'figures') && ~isempty(cfg.figures), figDir = cfg.figures; else, figDir = pwd; end
if ~exist(figDir,'dir'), mkdir(figDir); end
exportgraphics(fig1, fullfile(figDir,'fig2_row1.pdf'), ...
    'ContentType','vector','BackgroundColor','white');
exportgraphics(fig1, fullfile(figDir,'fig2_row1.png'), ...
    'Resolution',600,'BackgroundColor','white');
fprintf('\nRow 1 written to %s\n', figDir);


%% Local functions
% ---------------------------------------------------------------------
function plotConditionCloud(ax, D, COL, nCond)
% Individual traces plus per-condition points and a group summary. The
% traces carry within-subject consistency, the summary carries magnitude.
    n = size(D,1);
    rng(7,'twister');
    jit    = (rand(n,1)-0.5)*0.24;
    xCond  = 1:nCond;
    xCloud = xCond - 0.05;

    for i = 1:n
        plot(ax, xCloud + jit(i), D(i,:), '-', ...
            'Color',[0.65 0.65 0.65 0.45],'LineWidth',0.4);
    end
    for c = 1:nCond
        scatter(ax, xCloud(c)+jit, D(:,c), 12, ...
            'MarkerFaceColor',COL(c,:),'MarkerFaceAlpha',0.55, ...
            'MarkerEdgeColor','w','LineWidth',0.35);
    end
    errorbar(ax, xCond+0.28, mean(D,1), std(D,0,1), 'k-', ...
        'LineWidth',0.9,'CapSize',2.5,'Marker','o','MarkerSize',3, ...
        'MarkerFaceColor','k','MarkerEdgeColor','k');
    xlim(ax,[0.55 nCond+0.65]);
end

function combinedBracket(ax, xs, y, h, label, fontName, fontSize, below)
% One horizontal rule spanning all conditions, with a short tick beneath
% each, and a single label. Used when every pairwise comparison shares
% the same verdict: three separate brackets would repeat one symbol three
% times, which is ink without information. When below is true the ticks
% point up toward the data and the label sits under the rule.
    x1 = min(xs); x2 = max(xs);
    plot(ax, [x1 x2], [y y], 'k-', 'LineWidth', 0.5, 'HandleVisibility','off');
    for i = 1:numel(xs)
        if below
            plot(ax, [xs(i) xs(i)], [y y+h], 'k-', ...
                'LineWidth', 0.5, 'HandleVisibility','off');
        else
            plot(ax, [xs(i) xs(i)], [y-h y], 'k-', ...
                'LineWidth', 0.5, 'HandleVisibility','off');
        end
    end
    if below, va = 'top'; else, va = 'bottom'; end
    text(ax, (x1+x2)/2, y, label, ...
        'HorizontalAlignment','center','VerticalAlignment',va, ...
        'FontName',fontName,'FontSize',fontSize);
end

function s = allSame(pHolm)
% Label for a combined bracket. Only valid when all three comparisons
% agree; if they do not, the combined form would hide a real difference
% between them and separate brackets are needed instead.
    if all(pHolm < 0.05)
        s = pStars(max(pHolm));
    elseif all(pHolm >= 0.05)
        s = 'n.s.';
    else
        error(['Pairwise comparisons disagree, so a single combined ' ...
               'bracket would misrepresent them. Use separate brackets.']);
    end
end

function padLabels(ax, xPad, yPad)
% Widen the gap between the axis labels and the tick labels. MATLAB
% places each label tight against the longest tick label, and that length
% varies with the number of digits, so panels drift out of alignment
% without this. Applied to both axes with the same constants throughout
% the figure. An empty label is left alone.
    if nargin < 3 || isempty(yPad), yPad = xPad; end

    ylh = get(ax, 'YLabel');
    if ~isempty(get(ylh, 'String'))
        set(ylh, 'Units', 'centimeters');
        p = get(ylh, 'Position');
        set(ylh, 'Position', [p(1) - yPad, p(2), p(3)]);
    end

    xlh = get(ax, 'XLabel');
    if ~isempty(get(xlh, 'String'))
        set(xlh, 'Units', 'centimeters');
        p = get(xlh, 'Position');
        set(xlh, 'Position', [p(1), p(2) - xPad, p(3)]);
    end
end

function s = pStars(p)
    if     p < 0.001, s = '***';
    elseif p < 0.01,  s = '**';
    elseif p < 0.05,  s = '*';
    else,             s = 'n.s.';
    end
end

function [F, eta2p] = rmF(Y)
% Repeated measures F and partial eta squared at every sample.
    [n,k,~] = size(Y);
    gm = mean(Y,[1 2]); mc = mean(Y,1); ms = mean(Y,2);
    ssCond  = n * sum((mc-gm).^2, 2);
    ssSubj  = k * sum((ms-gm).^2, 1);
    ssTotal = sum((Y-gm).^2, [1 2]);
    ssErr   = ssTotal - ssCond - ssSubj;
    F = squeeze((ssCond/(k-1)) ./ (ssErr/((n-1)*(k-1))))';
    F(~isfinite(F)) = 0;
    eta2p = squeeze(ssCond ./ (ssCond + ssErr))';
    eta2p(~isfinite(eta2p)) = 0;
end

function [mass, runs] = clusterMass(F, thresh)
    above = F > thresh;
    if ~any(above), mass = zeros(0,1); runs = zeros(0,2); return; end
    d = diff([0 above 0]);
    runs = [find(d==1)', (find(d==-1)-1)'];
    mass = arrayfun(@(a,b) sum(F(a:b)), runs(:,1), runs(:,2));
end
