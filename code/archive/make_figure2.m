%% MAKE_FIGURE2
%  Figure 2, rows 1 and 2, on one canvas.
%
%    Row 1 (a) perceived difficulty by condition
%          (b) tracking error by condition, and across the movement cycle
%    Row 2 (c) four muscles across the cycle, plus the effort index
%
%  Row 3, the mediation diagram, is drawn separately: a path diagram is
%  not something MATLAB should be asked to produce.
%
%  SOURCES. Condition-level numbers come from behaviour_table.mat, so the
%  panels and the paragraph beside them cannot drift apart. Waveforms come
%  from the per-subject master files, since the tables hold no time
%  series. Both are screened through screen_epochs with one policy, so
%  every panel describes the same set of trials.
%
%  WHY THIS REPLACED THE EARLIER SCRIPTS. Rows 1 and 2 previously lived in
%  separate files reading separate legacy structures, each applying its
%  own screening. Those structures used two different trial numbering
%  conventions and disagreed for four participants without saying so.
%  Everything here keys on (SubjectID, RawTrial, RawEpoch), assigned
%  before any filtering, so position never carries identity.
%
%  Requires: screen_epochs.m on the path, and the master tables built by
%  build_emg_master.m, build_tracking_master.m and build_behaviour_table.m.
% =====================================================================

clc; clear;

%% 0. Configuration
% ---------------------------------------------------------------------
data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
out_path  = [data_path, '7_Master_Tables\'];
fig_path  = [data_path, '8_Figures\'];
if ~exist(fig_path,'dir'), mkdir(fig_path); end

LEVELS       = [1 3 6];
COND_NAMES   = {'Low','Medium','High'};
MUSCLE_COLS  = {'iEMG_VM','iEMG_RF','iEMG_GM','iEMG_BF'};
MUSCLE_NAMES = {'Vastus med R','Rectus femoris R','Gastrocnemius R','Biceps femoris R'};
POLICY       = 'intersection';

% Warped grid. Resolution is set to what each recording can actually
% support, not to what looks smooth. The EMG envelope is already low-pass
% filtered, so 200 points is ample despite a native 4000 samples per
% cycle; the encoder gives a median of about 34 samples per cycle, so 50
% points is already a modest upsample.
NSAMP_EMG = 200;
NSAMP_TRK = 50;

% Both modalities are warped to equal halves, placing the reversal at 50%
% in every panel. The measured flexion fraction is computed and printed
% below for the Methods, but the plots use 50:50 so that the reversal
% mark means the same thing in every panel of the figure and the rows
% line up vertically. The measured value sits within a fraction of a
% percent of 0.50, so the compression this imposes is negligible.
FLEX_FRAC_PLOT = 0.50;

N_PERM      = 5000;
CLUST_ALPHA = 0.05;
RNG_SEED    = 21;

% ---- Style, defined once and used by every panel --------------------
S.col       = [1 115 178; 222 143 5; 148 73 92]/255;   % Low, Medium, High
S.font      = 'Arial';
S.fsTick    = 6;
S.fsLab     = 7;
S.fsPanel   = 8;
S.fsEvent   = 5.5;
S.lw        = 0.5;
S.xlabPad   = 0.18;      % cm, below the x tick labels
S.ylabPad   = 0.18;      % cm, left of the y tick labels
S.titleOff  = 0.50;      % cm, above each axes top

% Box convention: on for panels carrying cycle event labels, since the
% box gives those labels something to sit on; off everywhere else, where
% there is no landmark for a box to anchor.

fprintf('=== Figure 2 ===\n');


%% 1. Load and screen
% ---------------------------------------------------------------------
load(fullfile(out_path,'emg_master_index.mat'), 'masterIndex'); E = masterIndex;
load(fullfile(out_path,'trk_master_index.mat'), 'masterIndex'); X = masterIndex;
load(fullfile(out_path,'behaviour_table.mat'),  'T');
clear masterIndex

[keepE, keepX, info] = screen_epochs(E, X, POLICY);
fprintf('Policy %s: %d EMG epochs, %d tracking epochs\n', ...
    info.policy, info.epochsEMG, info.epochsTrack);

% Retained keys, used to select rows inside the per-subject files.
keyE = E(keepE, {'SubjectID','RawTrial','RawEpoch'});
keyX = X(keepX, {'SubjectID','RawTrial','RawEpoch'});


%% 2. Subject-level condition means
% ---------------------------------------------------------------------
% Per-subject means first, then across subjects. Trial counts differ by
% design between the early and late participants (the protocol was
% revised after subject 10), so pooling trials would weight them
% unequally.

subsAll = unique(T.SubjectID);
nCond   = numel(LEVELS);

R = nan(numel(subsAll), nCond);        % perceived difficulty
Q = nan(numel(subsAll), nCond);        % tracking error
F = nan(numel(subsAll), nCond);        % effort index
M = nan(numel(subsAll), nCond, 4);     % per muscle

for i = 1:numel(subsAll)
    for c = 1:nCond
        s = T.SubjectID == subsAll(i) & T.Pressure == LEVELS(c);
        R(i,c) = mean(T.Score(s),       'omitnan');
        Q(i,c) = mean(T.Error(s),       'omitnan');
        F(i,c) = mean(T.EffortIndex(s), 'omitnan');
        for m = 1:4
            M(i,c,m) = mean(T.(MUSCLE_COLS{m})(s), 'omitnan');
        end
    end
end

hasEMG = any(~isnan(F), 2);
Rm = mean(R,1,'omitnan'); Rs = std(R,0,1,'omitnan');
Qm = mean(Q,1,'omitnan'); Qs = std(Q,0,1,'omitnan');
Fm = mean(F,1,'omitnan'); Fs = std(F,0,1,'omitnan');

fprintf('\nPerceived difficulty  %.2f %.2f %.2f  (n = %d), effect %.2f\n', ...
    Rm, sum(any(~isnan(R),2)), Rm(3)-Rm(1));
fprintf('Tracking error (deg)  %.2f %.2f %.2f  (n = %d), High-Low %+.2f\n', ...
    Qm, sum(any(~isnan(Q),2)), Qm(3)-Qm(1));
fprintf('Effort index          %.2f %.2f %.2f  (n = %d), %.2f-fold\n', ...
    Fm, sum(hasEMG), Fm(3)/Fm(1));


%% 3. Pairwise tests, for the panel annotations
% ---------------------------------------------------------------------
% Ratings are a bounded ordinal scale, so rank-based tests were chosen a
% priori. Tracking error and the effort index are continuous, so the
% parametric route applies. The difference is principled, not a matter of
% which result each produced.

pairs = [1 2; 1 3; 2 3];
pR = holmPairwise(R(any(~isnan(R),2),:), pairs, 'signrank');
pQ = holmPairwise(Q(any(~isnan(Q),2),:), pairs, 'ttest');
[pF, dzF] = holmPairwise(F(hasEMG,:),    pairs, 'ttest');


%% 4. Warp composition, measured then fixed
% ---------------------------------------------------------------------
% Computed for the Methods; the plots use FLEX_FRAC_PLOT regardless.

fprintf('\n--- Measured flexion fraction (screened epochs) ---\n');
fprintf('EMG      %.4f\n', flexFraction(E(keepE,:)));
fprintf('Tracking %.4f\n', flexFraction(X(keepX,:)));
fprintf('Plotted at %.2f so the reversal marks the same point in every panel.\n', ...
    FLEX_FRAC_PLOT);


%% 5. Cycle curves
% ---------------------------------------------------------------------
% Epochs are averaged within a trial, then trials within a condition.
% Epoch counts vary between trials, so pooling epochs would weight long
% trials more heavily, and trial is the unit every model in the paper
% operates on.

fprintf('\nBuilding cycle curves ...\n');
[emgCurves, emgSubs] = buildEMGCurves(out_path, keyE, T, LEVELS, ...
                                      NSAMP_EMG, FLEX_FRAC_PLOT);
[trkCurves, trkSubs] = buildTrackingCurves(out_path, keyX, T, LEVELS, ...
                                      NSAMP_TRK, FLEX_FRAC_PLOT);
fprintf('  EMG      %d subjects\n', numel(emgSubs));
fprintf('  Tracking %d subjects\n', numel(trkSubs));


%% 6. Cluster-based permutation
% ---------------------------------------------------------------------
% A repeated measures F at every warped sample, contiguous suprathreshold
% samples grouped into clusters, and a null built by permuting condition
% labels within participant.
%
% The omnibus F is unsigned, so a significant cluster says the conditions
% differ somewhere in that window, not which is larger and not where the
% effect is concentrated. A cluster grows to absorb every adjacent
% suprathreshold sample, so its extent is not an estimate of the effect's
% extent. Partial eta squared is plotted beneath each panel to carry that
% question instead.
%
% Each muscle is its own family. These are four a priori hypotheses about
% anatomically distinct muscles, not a screen over many candidates, so no
% correction is applied across them.

rng(RNG_SEED,'twister');
emgClust = cell(4,1); emgEta = nan(4, NSAMP_EMG);
for m = 1:4
    [emgClust{m}, emgEta(m,:)] = clusterTest( ...
        squeeze(emgCurves(:,m,:,:)), N_PERM, CLUST_ALPHA);
    fprintf('  %-18s %d significant cluster(s)\n', MUSCLE_NAMES{m}, ...
        height(emgClust{m}(emgClust{m}.p < 0.05, :)));
end
[trkClust, trkEta] = clusterTest(trkCurves, N_PERM, CLUST_ALPHA);


%% 7. Figure
% ---------------------------------------------------------------------
% One canvas for both rows, so the panels align vertically and the fonts
% and margins cannot drift apart. Positions are explicit in centimetres
% rather than through subplot or tiledlayout: the geometry is then edited
% in one block, and fonts are specified at final print size instead of
% being rescaled after the fact.

figW = 18.0; figH = 13.4;
L.rowY   = [7.00, 0.55];        % origin of row 1 and row 2
L.stripO = 0.80;  L.stripH = 0.55;
L.mainO  = 1.55;  L.mainH  = 2.85;
L.fullH  = L.mainO + L.mainH - L.stripO;

% Row 1 divides the canvas differently from row 2. That is deliberate:
% forcing three plots onto a five-column grid would leave empty columns
% that read as a mistake. Margins, fonts and panel heights match, which
% is what makes the rows belong to one figure.
L.r1x = [1.30, 7.15, 12.70];   L.r1w = [4.10, 4.10, 4.45];
L.r2x = 1.30 + (0:4)*(2.70 + 0.70);  L.r2w = 2.70;

fig = figure('Units','centimeters','Position',[1 1 figW figH], ...
             'Color','w','PaperPositionMode','auto');

% ================= ROW 1 =============================================
y0 = L.rowY(1);

% ---- a: perceived difficulty ----------------------------------------
ax = axes(fig,'Units','centimeters','Position',[L.r1x(1) y0+L.stripO L.r1w(1) L.fullH]);
hold(ax,'on');
conditionCloud(ax, R(any(~isnan(R),2),:), S.col, nCond);
ylim(ax,[0.5 10.5]);
% One combined bracket, not three. All three comparisons share the same
% verdict, so three brackets would repeat one symbol three times. Above
% the data here because the scale floors at 1 and a participant sits on it.
combinedBracket(ax, 1:nCond, 9.35, 0.30, sameVerdict(pR), S, false);
set(ax,'XTick',1:nCond,'XTickLabel',COND_NAMES,'YTick',1:10, ...
    'FontName',S.font,'FontSize',S.fsTick,'TickDir','in','Box','off','LineWidth',S.lw);
ylabel(ax,'Perceived difficulty','FontName',S.font,'FontSize',S.fsLab);
xlabel(ax,'Physical demand','FontName',S.font,'FontSize',S.fsLab);
padLabels(ax, S); hold(ax,'off');

% ---- b left: tracking error by condition ----------------------------
ax = axes(fig,'Units','centimeters','Position',[L.r1x(2) y0+L.stripO L.r1w(2) L.fullH]);
hold(ax,'on');
conditionCloud(ax, Q(any(~isnan(Q),2),:), S.col, nCond);
axTop = max(ylim(ax));
% Below the data here: anchoring at zero opens a gap the annotation can
% use, which keeps the top of the panel clear.
combinedBracket(ax, 1:nCond, min([Q(:); (Qm-Qs)']) - 0.14*axTop, ...
    0.045*axTop, sameVerdict(pQ), S, true);
ylim(ax,[0 axTop]);
set(ax,'XTick',1:nCond,'XTickLabel',COND_NAMES,'YTick',0:2:floor(axTop), ...
    'FontName',S.font,'FontSize',S.fsTick,'TickDir','in','Box','off','LineWidth',S.lw);
ylabel(ax,'Tracking error (deg)','FontName',S.font,'FontSize',S.fsLab);
xlabel(ax,'Physical demand','FontName',S.font,'FontSize',S.fsLab);
panelTitle(ax,'By condition',S,L.fullH);
padLabels(ax, S); hold(ax,'off');

% ---- b right: tracking error across the cycle ------------------------
axM = axes(fig,'Units','centimeters','Position',[L.r1x(3) y0+L.mainO L.r1w(3) L.mainH]);
axS = axes(fig,'Units','centimeters','Position',[L.r1x(3) y0+L.stripO L.r1w(3) L.stripH]);
cyclePanel(axM, axS, trkCurves, trkEta, trkClust, S, COND_NAMES, ...
    'Tracking error (deg)', 'Across the movement cycle', true, L.mainH);

% ================= ROW 2 =============================================
y0 = L.rowY(2);

% Extensors and flexors take separate shared y-limits. Their amplitudes
% differ by roughly threefold, and one common scale would flatten the
% extensors against the axis.
mu  = squeeze(mean(emgCurves,1,'omitnan'));
sem = squeeze(std(emgCurves,0,1,'omitnan'))/sqrt(size(emgCurves,1));
topExt = max(max(max(mu(1:2,:,:) + sem(1:2,:,:))));
topFlx = max(max(max(mu(3:4,:,:) + sem(3:4,:,:))));

for m = 1:4
    axM = axes(fig,'Units','centimeters', ...
        'Position',[L.r2x(m) y0+L.mainO L.r2w L.mainH]);
    axS = axes(fig,'Units','centimeters', ...
        'Position',[L.r2x(m) y0+L.stripO L.r2w L.stripH]);

    if m <= 2, yTop = topExt*1.10; else, yTop = topFlx*1.10; end
    ylab = ''; if m == 1, ylab = 'Normalised EMG'; end

    cyclePanel(axM, axS, squeeze(emgCurves(:,m,:,:)), emgEta(m,:), ...
        emgClust{m}, S, COND_NAMES, ylab, MUSCLE_NAMES{m}, m == 1, L.mainH, yTop);
end

% ---- effort index ----------------------------------------------------
ax = axes(fig,'Units','centimeters', ...
    'Position',[L.r2x(5) y0+L.stripO L.r2w L.fullH]);
hold(ax,'on');
conditionCloud(ax, F(hasEMG,:), S.col, nCond);
axTop = max(ylim(ax));
% Zero is a meaningful floor for a sum of normalised iEMG, and anchoring
% there matches the muscle panels beside it.
combinedBracket(ax, 1:nCond, min([F(hasEMG); (Fm-Fs)']) - 0.13*axTop, ...
    0.04*axTop, sameVerdict(pF), S, true);
ylim(ax,[0 axTop]);
set(ax,'XTick',1:nCond,'XTickLabel',COND_NAMES,'YTick',0:1:floor(axTop), ...
    'FontName',S.font,'FontSize',S.fsTick,'TickDir','in','Box','off','LineWidth',S.lw);
ylabel(ax,'Effort index','FontName',S.font,'FontSize',S.fsLab);
xlabel(ax,'Physical demand','FontName',S.font,'FontSize',S.fsLab);
panelTitle(ax,'All four muscles',S,L.fullH);
padLabels(ax, S); hold(ax,'off');

% ---- panel letters ---------------------------------------------------
% Row 2 takes a single letter: its five plots are one panel of the
% figure, not five.
letterAt(fig, 0.004, (L.rowY(1)+L.mainO+L.mainH+0.75)/figH, 'a', S);
letterAt(fig, (L.r1x(2)-1.10)/figW, (L.rowY(1)+L.mainO+L.mainH+0.75)/figH, 'b', S);
letterAt(fig, 0.004, (L.rowY(2)+L.mainO+L.mainH+0.75)/figH, 'c', S);


%% 8. Export
% ---------------------------------------------------------------------
exportgraphics(fig, fullfile(fig_path,'figure2_rows12.pdf'), ...
    'ContentType','vector','BackgroundColor','white');
exportgraphics(fig, fullfile(fig_path,'figure2_rows12.png'), ...
    'Resolution',600,'BackgroundColor','white');
fprintf('\nWritten to %s\n', fig_path);


%% ====================================================================
%  Local functions
%  ====================================================================

function [curves, subs] = buildEMGCurves(out_path, keyE, T, LEVELS, NG, flexFrac)
% Per-subject, per-condition EMG cycle curves.
% Returns nSubj x 4 muscles x NG x 3 conditions.
%
% Normalisation divides each muscle by that subject's own mean across
% retained epochs, removing between-subject amplitude differences from
% electrode placement and tissue. It is a scalar divide per muscle, so it
% leaves condition ratios untouched and no fold change depends on it.

    subs = unique(keyE.SubjectID);
    nF = round(NG*flexFrac); nE = NG - nF;
    curves = nan(numel(subs), 4, NG, numel(LEVELS));

    for i = 1:numel(subs)
        f = fullfile(out_path, sprintf('emg_master_sub-%d.mat', subs(i)));
        D = load(f, 'E', 'Sig');

        sel = ismember(D.E(:,{'SubjectID','RawTrial','RawEpoch'}), keyE);
        rows = find(sel);
        if isempty(rows), continue; end

        W = nan(numel(rows), 4, NG);
        for q = 1:numel(rows)
            r = rows(q);
            W(q,:,:) = warpEpoch(double(D.Sig{r}), D.E.ExtStart(r), ...
                                 D.E.ExtEnd(r), nF, nE);
        end

        % Epochs to trials, then trials to conditions.
        tr  = D.E.RawTrial(rows);
        pr  = D.E.Pressure(rows);
        uTr = unique(tr);
        TC  = nan(numel(uTr), 4, NG); TP = nan(numel(uTr),1);
        for t = 1:numel(uTr)
            s = tr == uTr(t);
            TC(t,:,:) = mean(W(s,:,:), 1, 'omitnan');
            TP(t) = pr(find(s,1));
        end

        nf = mean(mean(TC, 3, 'omitnan'), 1, 'omitnan');   % 1 x 4
        for c = 1:numel(LEVELS)
            s = TP == LEVELS(c);
            if ~any(s), continue; end
            curves(i,:,:,c) = squeeze(mean(TC(s,:,:),1,'omitnan')) ./ nf(:);
        end
        clear D
    end

    good = squeeze(~all(all(all(isnan(curves),2),3),4));
    curves = curves(good,:,:,:); subs = subs(good);
end


function [curves, subs] = buildTrackingCurves(out_path, keyX, T, LEVELS, NG, flexFrac)
% Per-subject, per-condition tracking error curves.
% Returns nSubj x NG x 3.
%
% Error is the absolute difference between encoder and reference angle,
% matching the trial-level measure in the behaviour table. The masters
% store the two angles rather than a derived error precisely so that this
% definition is visible at the point of use.

    subs = unique(keyX.SubjectID);
    nF = round(NG*flexFrac); nE = NG - nF;
    curves = nan(numel(subs), NG, numel(LEVELS));

    for i = 1:numel(subs)
        f = fullfile(out_path, sprintf('trk_master_sub-%d.mat', subs(i)));
        D = load(f, 'X', 'Enc', 'Ref');

        sel = ismember(D.X(:,{'SubjectID','RawTrial','RawEpoch'}), keyX);
        rows = find(sel);
        if isempty(rows), continue; end

        W = nan(numel(rows), NG);
        for q = 1:numel(rows)
            r = rows(q);
            e = abs(D.Enc{r} - D.Ref{r});
            W(q,:) = warpEpoch(e, D.X.ExtStart(r), D.X.ExtEnd(r), nF, nE);
        end

        tr  = D.X.RawTrial(rows);
        pr  = D.X.Pressure(rows);
        uTr = unique(tr);
        TC  = nan(numel(uTr), NG); TP = nan(numel(uTr),1);
        for t = 1:numel(uTr)
            s = tr == uTr(t);
            TC(t,:) = mean(W(s,:), 1, 'omitnan');
            TP(t) = pr(find(s,1));
        end

        for c = 1:numel(LEVELS)
            s = TP == LEVELS(c);
            if any(s), curves(i,:,c) = mean(TC(s,:),1,'omitnan'); end
        end
        clear D
    end

    good = squeeze(~all(all(isnan(curves),2),3));
    curves = curves(good,:,:); subs = subs(good);
end


function W = warpEpoch(sig, extStart, extEnd, nF, nE)
% Warp one epoch onto a common grid, flexion and extension separately.
% sig is nChannels x nSamples or 1 x nSamples.
    if isvector(sig), sig = sig(:)'; end
    nCh = size(sig,1);
    W = nan(nCh, nF + nE);
    if any(isnan([extStart extEnd])) || extEnd > size(sig,2) || ...
       extStart < 2 || extEnd <= extStart + 1
        return
    end
    for ch = 1:nCh
        flx = sig(ch, 1:extStart);
        ext = sig(ch, extStart+1:extEnd);
        W(ch,:) = [interp1(1:numel(flx), flx, linspace(1,numel(flx),nF)), ...
                   interp1(1:numel(ext), ext, linspace(1,numel(ext),nE))];
    end
    if nCh == 1, W = W(:)'; end
end


function fr = flexFraction(Etbl)
% Median within subject, then across subjects, following the convention
% the EMG pipeline used.
    subs = unique(Etbl.SubjectID);
    m = nan(numel(subs),2);
    for i = 1:numel(subs)
        s = Etbl.SubjectID == subs(i);
        m(i,1) = median(Etbl.ExtStart(s) - Etbl.FlxStart(s), 'omitnan');
        m(i,2) = median(Etbl.ExtEnd(s)   - Etbl.ExtStart(s), 'omitnan');
    end
    fr = median(m(:,1)) / (median(m(:,1)) + median(m(:,2)));
end


function [clust, eta] = clusterTest(C, nPerm, alpha)
% Cluster-based permutation across the three conditions.
% C is nSubj x nSamp x nCond.
    Y = permute(C, [1 3 2]);                 % nSubj x nCond x nSamp
    [n, k, ns] = size(Y);
    Fcrit = finv(1-alpha, k-1, (n-1)*(k-1));

    [Fobs, eta] = rmF(Y);
    [mass, runs] = clusterMass(Fobs, Fcrit);

    nullMax = zeros(nPerm,1);
    for p = 1:nPerm
        Yp = Y;
        for i = 1:n, Yp(i,:,:) = Y(i, randperm(k), :); end
        nullMax(p) = max([clusterMass(rmF(Yp), Fcrit); 0]);
    end

    if isempty(mass)
        clust = table();
    else
        pc = arrayfun(@(x)(sum(nullMax >= x)+1)/(nPerm+1), mass);
        clust = table(runs(:,1)/ns*100, runs(:,2)/ns*100, mass(:), pc(:), ...
            'VariableNames', {'StartPct','EndPct','Mass','p'});
        clust = sortrows(clust,'Mass','descend');
    end
end


function [F, eta2p] = rmF(Y)
% Repeated measures F and partial eta squared at every sample.
% F decides significance; eta squared describes magnitude. They diverge:
% a small but highly consistent difference gives a large F because the
% error term is tiny, while eta squared stays modest.
    [n,k,~] = size(Y);
    gm = mean(Y,[1 2],'omitnan'); mc = mean(Y,1,'omitnan'); ms = mean(Y,2,'omitnan');
    ssCond  = n * sum((mc-gm).^2, 2);
    ssSubj  = k * sum((ms-gm).^2, 1);
    ssTotal = sum((Y-gm).^2, [1 2], 'omitnan');
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


function [pHolm, dz] = holmPairwise(D, pairs, kind)
% Holm-corrected pairwise comparisons, with monotonicity enforced.
    nP = size(pairs,1);
    pRaw = nan(nP,1); dz = nan(nP,1); pHolm = nan(nP,1);
    for c = 1:nP
        d = D(:,pairs(c,2)) - D(:,pairs(c,1));
        d = d(~isnan(d));
        if strcmp(kind,'signrank')
            pRaw(c) = signrank(d, 0, 'method','exact');
        else
            [~, pRaw(c)] = ttest(d);
        end
        dz(c) = mean(d)/std(d);
    end
    [ps, ord] = sort(pRaw);
    pHolm(ord) = min(cummax(ps .* (nP:-1:1)'), 1);
end


function conditionCloud(ax, D, COL, nCond)
% Individual traces, per-condition points, and the group summary. The
% traces carry within-subject consistency, the summary carries magnitude.
% A white marker edge separates overlapping points that transparency
% alone cannot, which matters where a condition's distribution is tight.
    n = size(D,1);
    rng(7,'twister');
    jit = (rand(n,1)-0.5)*0.24;
    xc  = 1:nCond;  xcl = xc - 0.05;

    for i = 1:n
        plot(ax, xcl + jit(i), D(i,:), '-', ...
            'Color',[0.65 0.65 0.65 0.45],'LineWidth',0.4);
    end
    for c = 1:nCond
        scatter(ax, xcl(c)+jit, D(:,c), 12, ...
            'MarkerFaceColor',COL(c,:),'MarkerFaceAlpha',0.55, ...
            'MarkerEdgeColor','w','LineWidth',0.35);
    end
    errorbar(ax, xc+0.28, mean(D,1,'omitnan'), std(D,0,1,'omitnan'), 'k-', ...
        'LineWidth',0.9,'CapSize',2.5,'Marker','o','MarkerSize',3, ...
        'MarkerFaceColor','k','MarkerEdgeColor','k');
    xlim(ax,[0.55 nCond+0.65]);
end


function cyclePanel(axM, axS, C, eta, clust, S, COND, ylab, ttl, showLegend, mainH, yTop)
% A cycle plot with its effect-size strip beneath.
%
% The panel takes a box because it carries event labels, which need
% something to sit on. The strip does not: it shares the x-axis and the
% reversal is already marked above it.
    ns = size(C,2);
    x  = linspace(0,100,ns);
    mu  = squeeze(mean(C,1,'omitnan'))';
    sem = squeeze(std(C,0,1,'omitnan'))'/sqrt(size(C,1));

    hold(axM,'on');
    for c = 1:3
        fill(axM,[x fliplr(x)],[mu(c,:)+sem(c,:), fliplr(mu(c,:)-sem(c,:))], ...
            S.col(c,:),'EdgeColor','none','FaceAlpha',0.30,'HandleVisibility','off');
    end
    for c = 1:3
        plot(axM, x, mu(c,:), 'Color', S.col(c,:), 'LineWidth', 0.9);
    end

    if nargin < 12 || isempty(yTop), yTop = max(mu(:)+sem(:))*1.10; end
    ylim(axM,[0 yTop]); xlim(axM,[0 100]);
    plot(axM,[50 50],[0 yTop],'--','Color',[0.35 0.35 0.35], ...
        'LineWidth',S.lw,'HandleVisibility','off');

    % Event labels sit above the box, so they never collide with a curve.
    ev = {'FlxS', sprintf('FlxE\nExtS'), 'ExtE'};
    evx = [2 50 98];
    for e = 1:3
        text(axM, evx(e), yTop, ev{e}, 'Rotation',90, ...
            'HorizontalAlignment','left','VerticalAlignment','middle', ...
            'Clipping','off','FontName',S.font,'FontSize',S.fsEvent, ...
            'Color',[0.25 0.25 0.25]);
    end

    set(axM,'XTick',[0 50 100],'XTickLabel',[], ...
        'FontName',S.font,'FontSize',S.fsTick,'TickDir','in', ...
        'Box','on','LineWidth',S.lw);
    if ~isempty(ylab), ylabel(axM, ylab, 'FontName',S.font,'FontSize',S.fsLab); end
    panelTitle(axM, ttl, S, mainH);

    if showLegend
        lg = legend(axM, COND, 'Location','northwest', ...
            'FontName',S.font,'FontSize',S.fsTick);
        legend(axM,'boxoff'); lg.ItemTokenSize = [7 7];
    end
    hold(axM,'off');

    % ---- strip -------------------------------------------------------
    hold(axS,'on');
    plot(axS, x, eta, '-', 'Color',[0.25 0.25 0.25],'LineWidth',0.7);
    plot(axS, [0 100],[0.14 0.14],':','Color',[0.5 0.5 0.5],'LineWidth',S.lw);
    plot(axS, [50 50],[0 1],'--','Color',[0.35 0.35 0.35],'LineWidth',S.lw);
    if ~isempty(clust)
        sig = clust(clust.p < 0.05, :);
        for k = 1:height(sig)
            plot(axS,[sig.StartPct(k) sig.EndPct(k)],[-0.08 -0.08], ...
                'k-','LineWidth',1.8);
        end
    end
    ylim(axS,[-0.16 1]); xlim(axS,[0 100]);
    set(axS,'XTick',[0 50 100],'YTick',[0 0.5 1], ...
        'FontName',S.font,'FontSize',S.fsTick,'TickDir','in', ...
        'Box','off','LineWidth',S.lw);
    xlabel(axS,'Cycle (%)','FontName',S.font,'FontSize',S.fsLab);
    if ~isempty(ylab)
        ylabel(axS,'\eta^2_p','FontName',S.font,'FontSize',S.fsLab);
    end
    padLabels(axS, S);
    hold(axS,'off');
    padLabels(axM, S);
end


function combinedBracket(ax, xs, y, h, label, S, below)
% One rule spanning all conditions with a tick beneath each, and a single
% label. Used when every pairwise comparison shares the same verdict:
% three separate brackets would repeat one symbol three times.
    x1 = min(xs); x2 = max(xs);
    plot(ax,[x1 x2],[y y],'k-','LineWidth',S.lw,'HandleVisibility','off');
    for i = 1:numel(xs)
        if below, yy = [y y+h]; else, yy = [y-h y]; end
        plot(ax,[xs(i) xs(i)], yy,'k-','LineWidth',S.lw,'HandleVisibility','off');
    end
    if below, va = 'top'; else, va = 'bottom'; end
    text(ax,(x1+x2)/2, y, label, 'HorizontalAlignment','center', ...
        'VerticalAlignment',va,'FontName',S.font,'FontSize',S.fsEvent);
end


function s = sameVerdict(pHolm)
% Label for a combined bracket. Errors if the comparisons disagree, since
% the combined form would then hide a real difference between them.
    if all(pHolm < 0.05)
        s = pStars(max(pHolm));
    elseif all(pHolm >= 0.05)
        s = 'n.s.';
    else
        error(['Pairwise comparisons disagree, so one combined bracket ' ...
               'would misrepresent them. Use separate brackets.']);
    end
end


function s = pStars(p)
    if     p < 0.001, s = '***';
    elseif p < 0.01,  s = '**';
    elseif p < 0.05,  s = '*';
    else,             s = 'n.s.';
    end
end


function panelTitle(ax, str, S, axH)
    th = title(ax, str, 'FontName',S.font,'FontSize',S.fsLab,'FontWeight','normal');
    th.Units = 'centimeters';
    th.Position(2) = axH + S.titleOff;
end


function padLabels(ax, S)
% Widen the gap between axis labels and tick labels. MATLAB places each
% label tight against the longest tick label, and that length varies with
% the number of digits, so panels drift out of alignment without this.
    ylh = get(ax,'YLabel');
    if ~isempty(get(ylh,'String'))
        set(ylh,'Units','centimeters');
        p = get(ylh,'Position'); set(ylh,'Position',[p(1)-S.ylabPad p(2) p(3)]);
    end
    xlh = get(ax,'XLabel');
    if ~isempty(get(xlh,'String'))
        set(xlh,'Units','centimeters');
        p = get(xlh,'Position'); set(xlh,'Position',[p(1) p(2)-S.xlabPad p(3)]);
    end
end


function letterAt(fig, x, y, str, S)
    annotation(fig,'textbox',[max(x,0.002) y 0.05 0.05],'String',str, ...
        'FontName',S.font,'FontSize',S.fsPanel,'FontWeight','bold', ...
        'EdgeColor','none','HorizontalAlignment','left', ...
        'VerticalAlignment','middle');
end
