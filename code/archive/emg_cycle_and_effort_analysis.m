%% EMG_CYCLE_AND_EFFORT_ANALYSIS
%  Two analyses of the muscular response to imposed demand.
%
%  Part A. Time-resolved. Per-subject, per-condition EMG cycle curves,
%  rebuilt from EMG_Data_timewarped and restricted to the trials in the
%  screened behaviour table. Each muscle is tested with a cluster-based
%  permutation omnibus across the three pressure levels, which localises
%  where in the movement cycle the conditions diverge.
%
%  Part B. Magnitude. Effort index (sum of the four normalised iEMG
%  channels) per subject and condition, taken from the behaviour table,
%  with descriptives and difference tests. Gradedness is carried here,
%  not by the time-resolved test, because an omnibus F is unsigned.
%
%  DEPARTURE FROM THE EARLIER PIPELINE. main_EMG_detailed_plot.m dropped
%  entire score-by-pressure cells containing few trials:
%
%     thresholds_per_score = round(sum(trials_count_all)/30*0.4);
%     pressure_score_to_keep = trials_count_pressure_score > ...
%
%  That is a selection on the outcome variable: it removes rare
%  combinations, which are the extremes (high ratings under Low pressure,
%  low ratings under High). It is reasonable for the score-resolved
%  panel, where a box cannot be drawn from two points, but the curves and
%  the condition statistics were built from the same filtered arrays and
%  so inherited it. No such threshold is applied here.
%
%  Requires: Statistics and Machine Learning Toolbox.
% =====================================================================

clc; clear;

%% 0. Configuration
% ---------------------------------------------------------------------
cfg = ansymb_config();
addpath(genpath(cfg.code));

load([cfg.derived, filesep, 'behavior_table.mat'], 'T');
load('EMG_Data_timewarped.mat');            % adjust path if needed

LEVELS       = [1 3 6];
COND_NAMES   = {'Low', 'Medium', 'High'};
MUSCLE_NAMES = EMG_Data_timewarped.Muscle_Name;
WARPTO       = EMG_Data_timewarped.final_warpingto;   % [0 2000 4000]
NSAMP        = WARPTO(3);
MIDPOINT     = WARPTO(2);                             % flexion / extension border

N_PERM      = 5000;      % permutations for the cluster test
CLUST_ALPHA = 0.05;      % cluster-forming threshold
RNG_SEED    = 21;

subject_list = 5:18;
data = EMG_Data_timewarped.data;

fprintf('Muscles: %s\n', strjoin(MUSCLE_NAMES, ', '));
fprintf('Cycle: %d samples, flexion 1-%d, extension %d-%d\n\n', ...
    NSAMP, MIDPOINT, MIDPOINT+1, NSAMP);


%% 1. Screen the behaviour table
% ---------------------------------------------------------------------
if iscategorical(T.Pressure)
    Tpres = str2double(string(T.Pressure));
else
    Tpres = double(T.Pressure);
end
Tsubj = double(string(T.SubjectID));

bad = T.Score == 0 | isnan(T.Score) | T.Score < 1 | T.Score > 10;
T     = T(~bad, :);
Tpres = Tpres(~bad);
Tsubj = Tsubj(~bad);

fprintf('Screened table: %d trials, %d subjects\n\n', height(T), numel(unique(Tsubj)));


%% 2. Rebuild per-subject, per-condition cycle curves
% ---------------------------------------------------------------------
% Averaging order matters. Epochs are averaged within a trial first, then
% trial curves within a condition. Epoch counts differ between trials
% (some epochs were removed as event-timing outliers upstream), so
% pooling epochs directly would weight long trials more heavily. Trial is
% the unit everywhere else in the paper, so it is the unit here.

nMus  = numel(MUSCLE_NAMES);
nCond = numel(LEVELS);

curves   = [];      % nSubj x nMus x NSAMP x nCond
usedSubs = [];
trialLog = [];

for s = 1:numel(subject_list)

    subID = subject_list(s);
    if isempty(data{s,2}), continue; end
    st = data{s,2};

    % Column 2 of trial_epoch is the original trial index and is the
    % identifier shared with the behaviour table. Column 1 is a counter
    % over experimental trials only and does NOT match.
    trialIDs = unique(st.trial_epoch(:,2), 'stable');
    nStored  = numel(st.EMG);
    if numel(trialIDs) ~= nStored
        error('Sub %d: trial identifier count does not match stored trials.', subID);
    end

    % Trials this subject contributes to the screened table.
    rows      = Tsubj == subID;
    keepIDs   = T.Trial(rows);
    keepPres  = Tpres(rows);

    [inTable, loc] = ismember(trialIDs, keepIDs);

    % One curve per retained trial: average across that trial's epochs.
    trialCurves = nan(nMus, NSAMP, nStored);
    for t = 1:nStored
        if ~inTable(t), continue; end
        ep = st.EMG{t};
        if isempty(ep), continue; end
        trialCurves(:,:,t) = mean(cat(3, ep{:}), 3);
    end

    valid = inTable(:) & squeeze(~all(isnan(trialCurves(1,:,:)), 2));
    trialPres = nan(nStored,1);
    trialPres(inTable) = keepPres(loc(inTable));

    % Per-subject normalisation, matching the earlier pipeline: each
    % muscle is divided by its own mean amplitude across all retained
    % trials and all samples. This removes between-subject amplitude
    % differences arising from electrode placement and tissue properties.
    % It is a scalar divide per muscle, so it leaves condition ratios
    % unchanged and any fold-change statement is unaffected by it.
    normFac = mean(mean(trialCurves(:,:,valid), 3), 2);     % nMus x 1
    trialCurves = trialCurves ./ normFac;

    % Average trial curves within condition.
    subCurves = nan(nMus, NSAMP, nCond);
    nPerCond  = zeros(1, nCond);
    for c = 1:nCond
        sel = valid & trialPres == LEVELS(c);
        nPerCond(c) = sum(sel);
        subCurves(:,:,c) = mean(trialCurves(:,:,sel), 3);
    end

    if any(nPerCond == 0)
        warning('Sub %d has an empty condition. Excluded.', subID);
        continue;
    end

    curves   = cat(4, curves, subCurves);        % nMus x NSAMP x nCond x nSubj
    usedSubs = [usedSubs; subID];                 %#ok<AGROW>
    trialLog = [trialLog; subID, nPerCond];       %#ok<AGROW>
end

curves = permute(curves, [4 1 2 3]);             % nSubj x nMus x NSAMP x nCond
nSubj  = size(curves, 1);

fprintf('--- Trials contributing per subject and condition ---\n');
disp(array2table(trialLog, 'VariableNames', [{'Subject'}, COND_NAMES]));
fprintf('Curves built for %d subjects.\n\n', nSubj);


%% 3. Cluster-based permutation, omnibus across the three conditions
% ---------------------------------------------------------------------
% At each sample, a one-way repeated measures F across the three pressure
% levels. Contiguous samples exceeding the cluster-forming threshold are
% grouped and their F values summed to give a cluster mass. The null is
% built by permuting condition labels within each subject, which is the
% exchangeability the repeated measures design licenses, and recording
% the largest cluster mass on each permutation.
%
% The omnibus F is unsigned, so a cluster says the conditions differ
% somewhere in that window, not which is larger. Direction is read off
% the curves and stated descriptively.
%
% Each muscle is tested as its own family. These are four a priori
% hypotheses about anatomically distinct muscles, not a screen over many
% candidates, so no correction is applied across them. The Methods
% should say so explicitly.

rng(RNG_SEED, 'twister');
dfCond = nCond - 1;
dfErr  = (nSubj - 1) * (nCond - 1);
Fcrit  = finv(1 - CLUST_ALPHA, dfCond, dfErr);

fprintf('Cluster-forming threshold: F(%d,%d) > %.3f\n', dfCond, dfErr, Fcrit);
fprintf('Permutations: %d\n\n', N_PERM);

clusterResults = cell(nMus, 1);
etaTrace       = nan(nMus, NSAMP);

for m = 1:nMus

    Y = squeeze(curves(:, m, :, :));          % nSubj x NSAMP x nCond
    Y = permute(Y, [1 3 2]);                  % nSubj x nCond x NSAMP

    [Fobs, etaObs] = rmF(Y);
    etaTrace(m,:)  = etaObs;
    [obsMass, obsRuns] = clusterMass(Fobs, Fcrit);

    % Null distribution of the maximum cluster mass.
    nullMax = zeros(N_PERM, 1);
    for p = 1:N_PERM
        Yp = Y;
        for i = 1:nSubj
            Yp(i,:,:) = Y(i, randperm(nCond), :);
        end
        nullMax(p) = max([clusterMass(rmF(Yp), Fcrit); 0]);
    end

    fprintf('=== %s ===\n', MUSCLE_NAMES{m});

    % Where the effect is large, independent of any threshold. The
    % cluster test says whether the conditions differ; these numbers say
    % where the difference is substantial. Conventional benchmarks for
    % partial eta squared are 0.01 small, 0.06 medium, 0.14 large.
    [peakEta, peakIdx] = max(etaObs);
    flexIdx = 1:MIDPOINT;
    extIdx  = (MIDPOINT+1):NSAMP;
    fprintf('Peak partial eta2 = %.3f at %.1f%% of cycle\n', ...
        peakEta, peakIdx/NSAMP*100);
    fprintf('Mean partial eta2: flexion %.3f, extension %.3f\n', ...
        mean(etaObs(flexIdx)), mean(etaObs(extIdx)));
    fprintf('Cycle above eta2 = 0.14: %.1f%%\n', mean(etaObs > 0.14)*100);

    if isempty(obsMass)
        fprintf('No suprathreshold cluster.\n\n');
        clusterResults{m} = table();
        continue;
    end

    pClust = arrayfun(@(x) (sum(nullMax >= x) + 1) / (N_PERM + 1), obsMass);

    onsetPct  = (obsRuns(:,1) / NSAMP) * 100;
    offsetPct = (obsRuns(:,2) / NSAMP) * 100;

    R = table(obsRuns(:,1), obsRuns(:,2), onsetPct, offsetPct, ...
              obsMass(:), pClust(:), ...
              'VariableNames', {'StartSample','EndSample', ...
                                'StartPct','EndPct','Mass','p'});
    R = sortrows(R, 'Mass', 'descend');
    disp(R);

    sig = R(R.p < 0.05, :);
    if isempty(sig)
        fprintf('No cluster survives permutation testing.\n\n');
    else
        fprintf('Significant windows (%% of cycle): ');
        fprintf('%.1f to %.1f  ', [sig.StartPct, sig.EndPct]');
        fprintf('\n\n');
    end
    clusterResults{m} = R;
end


%% 4. Effort index: descriptives and difference tests
% ---------------------------------------------------------------------
% Taken from the behaviour table, so the reported magnitudes describe the
% same trials as the mediation. The effort index sums all four channels
% and is therefore unaffected by the flexor/extensor labelling error that
% affected the two sub-indices.

hasEMG = ~isnan(T.EffortIndex);
subsE  = unique(Tsubj(hasEMG), 'stable');
nSubjE = numel(subsE);

E_sub = nan(nSubjE, nCond);
for i = 1:nSubjE
    for c = 1:nCond
        E_sub(i,c) = mean(T.EffortIndex(hasEMG & Tsubj == subsE(i) & Tpres == LEVELS(c)));
    end
end

gM  = mean(E_sub, 1);
gSD = std(E_sub, 0, 1);

fprintf('--- Effort index (across-subject, n = %d) ---\n', nSubjE);
for c = 1:nCond
    fprintf('%-7s M = %.2f, SD = %.2f\n', COND_NAMES{c}, gM(c), gSD(c));
end
fprintf('High / Low ratio: %.2f-fold\n', gM(3) / gM(1));
fprintf('Monotonic increase in %d of %d participants\n', ...
    sum(all(diff(E_sub, 1, 2) > 0, 2)), nSubjE);

% Omnibus. The effort index is continuous, so the parametric route is
% primary, as for tracking error. The rank-based choice used for the
% ratings rested on their ordinal scale and does not apply here.
tblRM  = array2table(E_sub, 'VariableNames', COND_NAMES);
within = table(categorical(LEVELS(:)), 'VariableNames', {'Pressure'});
rm     = fitrm(tblRM, 'Low,Medium,High ~ 1', 'WithinDesign', within);

fprintf('\n--- Repeated measures ANOVA ---\n');
ravTbl = ranova(rm);
mauTbl = mauchly(rm);
epsTbl = epsilon(rm);
disp(ravTbl);
disp(mauTbl);

% Which p value to report is decided by the sphericity test, not by which
% one is more convenient. Applying Greenhouse-Geisser when sphericity
% holds is needlessly conservative; omitting it when sphericity fails
% inflates the error rate. The rule is applied here so the choice is
% recorded rather than made by hand.
ggEps = epsTbl.GreenhouseGeisser(1);
Fval  = ravTbl.F(1);
df1   = ravTbl.DF(1);
df2   = ravTbl.DF(2);

fprintf('\nMauchly W = %.3f, p = %.4f\n', mauTbl.W(1), mauTbl.pValue(1));
if mauTbl.pValue(1) < 0.05
    fprintf(['Sphericity violated. Report Greenhouse-Geisser:\n' ...
             '  F(%.2f, %.2f) = %.2f, p = %.3g, epsilon = %.3f\n'], ...
        df1*ggEps, df2*ggEps, Fval, ravTbl.pValueGG(1), ggEps);
else
    fprintf(['Sphericity holds. Report uncorrected:\n' ...
             '  F(%d, %d) = %.2f, p = %.3g\n'], ...
        df1, df2, Fval, ravTbl.pValue(1));
end

% Pairwise, paired, Holm-corrected. Note that stat_analysis.m used
% ttest2 and ranksum, which are unpaired tests, on within-subject data.
% Any significance markers produced by that function need recomputing.
pairs = [1 2; 1 3; 2 3];
nP    = size(pairs,1);
pRaw  = nan(nP,1); pHolm = nan(nP,1); dz = nan(nP,1);

fprintf('\n--- Pairwise paired t-tests (Holm-corrected) ---\n');
for c = 1:nP
    d = E_sub(:,pairs(c,2)) - E_sub(:,pairs(c,1));
    [~, pRaw(c)] = ttest(d);
    dz(c) = mean(d) / std(d);
end
[pS, ord] = sort(pRaw);
pHolm(ord) = min(cummax(pS .* (nP:-1:1)'), 1);
for c = 1:nP
    fprintf('%-18s diff = %+.3f, dz = %+.2f, p_Holm = %.4g\n', ...
        sprintf('%s vs %s', COND_NAMES{pairs(c,2)}, COND_NAMES{pairs(c,1)}), ...
        mean(E_sub(:,pairs(c,2)) - E_sub(:,pairs(c,1))), dz(c), pHolm(c));
end


%% 5. Per-muscle iEMG, for the supplementary table
% ---------------------------------------------------------------------
muscCols = {'VastusMed', 'Recfem', 'Gastroc', 'BicepFem'};

fprintf('\n--- Per-muscle iEMG by condition ---\n');
for m = 1:numel(muscCols)
    v = T.(muscCols{m});
    Msub = nan(nSubjE, nCond);
    for i = 1:nSubjE
        for c = 1:nCond
            Msub(i,c) = mean(v(hasEMG & Tsubj == subsE(i) & Tpres == LEVELS(c)));
        end
    end
    pr = nan(nP,1); ph = nan(nP,1);
    for c = 1:nP
        [~, pr(c)] = ttest(Msub(:,pairs(c,2)) - Msub(:,pairs(c,1)));
    end
    [pS2, o2] = sort(pr);
    ph(o2) = min(cummax(pS2 .* (nP:-1:1)'), 1);

    fprintf('%-18s Low %.2f+-%.2f, Med %.2f+-%.2f, High %.2f+-%.2f | %.2f-fold | p_Holm %.3g %.3g %.3g\n', ...
        MUSCLE_NAMES{m}, mean(Msub(:,1)), std(Msub(:,1)), ...
        mean(Msub(:,2)), std(Msub(:,2)), mean(Msub(:,3)), std(Msub(:,3)), ...
        mean(Msub(:,3))/mean(Msub(:,1)), ph(1), ph(2), ph(3));
end


%% 6. Figure: cycle curves with significant windows, plus the effort index
% ---------------------------------------------------------------------
% Five panels on an 18 cm canvas: one per muscle, plus the effort index.
% Positions are set explicitly in centimetres rather than through
% subplot, so panel geometry is edited in one place and fonts are
% specified at final print size instead of being rescaled afterwards.
%
% Bands are the standard error across participants. Black bars beneath
% each panel mark windows where the permutation test found a significant
% cluster. Those bars indicate that the conditions differ somewhere in
% that window; the direction is read from the curves, since the omnibus
% F carries no sign.

COL = [  1 115 178;      % Low
       222 143   5;      % Medium
       148  73  92]/255; % High

FS_TICK = 6; FS_LAB = 7; FS_PANEL = 8; FONT = 'Arial';
FS_EVENT = 5.5;            % event labels read larger than digits at equal pt
PANEL_LETTER = 'c';        % position of the EMG row in the assembled figure
% Bracket labels on the effort index panel. With all three comparisons at
% p < 0.001 the asterisks are identical and carry little information, so
% 'effect' labels them with Cohen's dz instead, which varies across the
% three and shows that Medium versus High is the weaker contrast.
% Either way the exact p values belong in the caption.
BRACKET_LABEL = 'effect';        % 'stars' or 'effect'

% Event label placement. EV_X are cycle percentages. Labels sit above the
% axes box rather than inside it, so they never collide with the curves.
EV_X = [2, 50, 98];

figW = 18.0; figH = 6.4;
axW  = 2.70; gap  = 0.72; xL = 1.25;
mainY = 1.95; mainH = 2.85;               % cycle curves
stripY = 1.20; stripH = 0.55;             % effect-size trace
effortH = mainY + mainH - stripY;         % effort panel spans both rows
TITLE_OFF = 0.50;                         % cm above each axes top

fig2 = figure('Units','centimeters','Position',[1 1 figW figH], ...
              'Color','w','PaperPositionMode','auto');

axc = gobjects(nMus+1,1);
axs = gobjects(nMus,1);

% ---- Muscle panels --------------------------------------------------
cyclePct = (1:NSAMP) / NSAMP * 100;

mu  = squeeze(mean(curves, 1));                 % nMus x NSAMP x nCond
sem = squeeze(std(curves, 0, 1)) / sqrt(nSubj);

% Extensors and flexors get separate shared y-limits, since their
% amplitudes differ by roughly a factor of three and one common scale
% would flatten the extensors into the axis.
topExt = max(max(max(mu(1:2,:,:) + sem(1:2,:,:))));
topFlx = max(max(max(mu(3:4,:,:) + sem(3:4,:,:))));

for m = 1:nMus
    axc(m) = axes(fig2, 'Units','centimeters', ...
        'Position',[xL + (m-1)*(axW+gap), mainY, axW, mainH]);
    hold(axc(m),'on');

    for c = 1:nCond
        band = [mu(m,:,c) + sem(m,:,c), fliplr(mu(m,:,c) - sem(m,:,c))];
        fill(axc(m), [cyclePct, fliplr(cyclePct)], band, COL(c,:), ...
            'EdgeColor','none','FaceAlpha',0.30,'HandleVisibility','off');
    end
    for c = 1:nCond
        plot(axc(m), cyclePct, mu(m,:,c), 'Color', COL(c,:), 'LineWidth', 0.9);
    end

    if m <= 2, yTop = topExt * 1.10; else, yTop = topFlx * 1.10; end
    ylim(axc(m), [0, yTop]);
    xlim(axc(m), [0 100]);

    % Cycle events, following add_event_lines.m in the original plotting
    % code: flexion start, the flexion-to-extension reversal, and
    % extension end. The outer two coincide with the axis limits, so only
    % the reversal is drawn as a line. Label placement is exposed through
    % EV_X and EV_Y below, since the ideal spot depends on where each
    % muscle peaks and may need nudging per panel.
    plot(axc(m), [50 50], [0 yTop], '--', 'Color', [0.35 0.35 0.35], ...
        'LineWidth', 0.5, 'HandleVisibility','off');

    evLabels = {'FlxS', sprintf('FlxE\nExtS'), 'ExtE'};
    for e = 1:3
        text(axc(m), EV_X(e), yTop, evLabels{e}, ...
            'Rotation', 90, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle', ...
            'Clipping', 'off', ...
            'FontName', FONT, 'FontSize', FS_EVENT, ...
            'Color', [0.25 0.25 0.25]);
    end

    set(axc(m), 'XTick', [0 50 100], 'XTickLabel', [], ...
        'FontName', FONT, 'FontSize', FS_TICK, ...
        'TickDir','in','Box','on','LineWidth',0.5);
    th = title(axc(m), strrep(MUSCLE_NAMES{m}, '_', ' '), ...
        'FontName', FONT, 'FontSize', FS_LAB, 'FontWeight','normal');
    th.Units = 'centimeters';
    th.Position(2) = mainH + TITLE_OFF;
    if m == 1
        ylabel(axc(m), 'Normalised EMG', 'FontName', FONT, 'FontSize', FS_LAB);
        lg = legend(axc(m), COND_NAMES, 'Location','northwest', ...
                    'FontName', FONT, 'FontSize', FS_TICK);
        legend(axc(m),'boxoff');
        lg.ItemTokenSize = [8 8];
    end
    hold(axc(m),'off');

    % ---- Effect-size strip ------------------------------------------
    % Partial eta squared at each sample. This is what localises the
    % effect. The cluster test answers only whether the conditions
    % differ; because a cluster grows to absorb every adjacent sample
    % above threshold, its extent is not an estimate of where the effect
    % lives and must not be read as one.
    axs(m) = axes(fig2, 'Units','centimeters', ...
        'Position',[xL + (m-1)*(axW+gap), stripY, axW, stripH]);
    hold(axs(m),'on');

    plot(axs(m), cyclePct, etaTrace(m,:), '-', ...
        'Color', [0.25 0.25 0.25], 'LineWidth', 0.7);

    % 0.14 is the conventional boundary for a large effect.
    plot(axs(m), [0 100], [0.14 0.14], ':', 'Color', [0.5 0.5 0.5], ...
        'LineWidth', 0.5);

    % Reversal line only. No box and no event labels here: the strip
    % shares its x-axis with the panel above, which carries the labels.
    plot(axs(m), [50 50], [0 1], '--', 'Color', [0.35 0.35 0.35], ...
        'LineWidth', 0.5);

    % Significant cluster windows, drawn as a thin rule at the base.
    R = clusterResults{m};
    if ~isempty(R)
        sig = R(R.p < 0.05, :);
        for k = 1:height(sig)
            plot(axs(m), [sig.StartPct(k), sig.EndPct(k)], ...
                 [-0.08 -0.08], 'k-', 'LineWidth', 1.8);
        end
    end

    ylim(axs(m), [-0.16 1]);
    xlim(axs(m), [0 100]);
    % Box off here, and no event lines. The strip carries no event labels
    % of its own, so a box would anchor nothing, and the reversal is
    % already marked directly above on a shared x-axis.
    set(axs(m), 'XTick', [0 50 100], 'YTick', [0 0.5 1], ...
        'FontName', FONT, 'FontSize', FS_TICK, ...
        'TickDir','in','Box','off','LineWidth',0.5);
    xlabel(axs(m), 'Cycle (%)', 'FontName', FONT, 'FontSize', FS_LAB);
    if m == 1
        ylabel(axs(m), '\eta^2_p', 'FontName', FONT, 'FontSize', FS_LAB);
    end
    hold(axs(m),'off');
end

% ---- Effort index panel ---------------------------------------------
% Same construction as the perceived difficulty panel: individual traces
% carry the within-subject consistency, the black summary carries the
% magnitude. Spans the full height of the row.
m = nMus + 1;
axc(m) = axes(fig2, 'Units','centimeters', ...
    'Position',[xL + (m-1)*(axW+gap), stripY, axW, effortH]);
hold(axc(m),'on');

% Marker separation. Medium has the tightest distribution (SD 0.21
% against 0.32 and 0.39), so its points stack almost vertically and
% transparency alone will not separate them. Three things do: a wider
% jitter spread, a lower fill opacity, and a thin white edge that breaks
% the outline of overlapping markers against the white background.
JIT_SPREAD = 0.24;
MARKER_SZ  = 12;

rng(7,'twister');
xJit   = (rand(nSubjE,1) - 0.5) * JIT_SPREAD;
xCond  = 1:nCond;
xCloud = xCond - 0.05;          % cloud nudged left, clear of the summary

for i = 1:nSubjE
    plot(axc(m), xCloud + xJit(i), E_sub(i,:), '-', ...
        'Color', [0.65 0.65 0.65 0.45], 'LineWidth', 0.4);
end
for c = 1:nCond
    scatter(axc(m), xCloud(c) + xJit, E_sub(:,c), MARKER_SZ, ...
        'MarkerFaceColor', COL(c,:), 'MarkerFaceAlpha', 0.55, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.35);
end
errorbar(axc(m), xCond + 0.28, gM, gSD, 'k-', 'LineWidth', 0.9, ...
    'CapSize', 2.5, 'Marker','o', 'MarkerSize', 3, ...
    'MarkerFaceColor','k', 'MarkerEdgeColor','k');

xlim(axc(m), [0.55, nCond + 0.65]);

% Significance brackets. Every other plot in this row carries its
% statistics, so leaving this one bare would read as untested. Asterisks
% compress three different magnitudes into one symbol, so the exact
% Holm-corrected p values belong in the caption.
% The effort index is a sum of normalised integrated EMG, so zero is a
% meaningful floor rather than an arbitrary one. Anchoring the axis there
% avoids visually exaggerating the condition differences, and matches the
% muscle panels in this row, which also start at zero.
%
% Anchoring at zero also opens a gap beneath the data, so the comparison
% brackets go there rather than above. That uses space the panel already
% has, keeps the top of the plot clear, and lets the axis stop at the
% data instead of being stretched to make room for annotation.
ylAuto   = ylim(axc(m));
axTop    = ylAuto(2);
dataLow  = min([E_sub(:); gM(:) - gSD(:)]);
tickVals = 0:1:floor(axTop);

step  = 0.075 * axTop;
base  = dataLow - 0.13 * axTop;      % nearest bracket, just under the data

% Columns: first condition, second condition, p value, Cohen's dz,
% vertical level. Level counts downward here, so the widest comparison
% (Low versus High) sits lowest and does not cross the other two.
brackets = [1 2 pHolm(1) dz(1) 0
            2 3 pHolm(3) dz(3) 0
            1 3 pHolm(2) dz(2) 1];

for b = 1:size(brackets,1)
    if strcmp(BRACKET_LABEL, 'effect')
        lbl = sprintf('d_{z} = %.1f', brackets(b,4));
    else
        lbl = pStars(brackets(b,3));
    end
    sigBracket(axc(m), brackets(b,1), brackets(b,2), ...
        base - brackets(b,5)*step, 0.016*axTop, ...
        lbl, FONT, FS_EVENT, true);
end

ylim(axc(m), [0, axTop]);

% Box off: this is a condition summary, not a cycle plot, so there are no
% event landmarks for a box to anchor. Ticks come from the data range, so
% none is drawn up in the annotation space.
set(axc(m), 'XTick', xCond, 'XTickLabel', COND_NAMES, ...
    'YTick', tickVals, ...
    'FontName', FONT, 'FontSize', FS_TICK, ...
    'TickDir','in','Box','off','LineWidth',0.5);
xlabel(axc(m), 'Physical demand', 'FontName', FONT, 'FontSize', FS_LAB);
ylabel(axc(m), 'Effort index', 'FontName', FONT, 'FontSize', FS_LAB);
th = title(axc(m), 'All four muscles', 'FontName', FONT, ...
    'FontSize', FS_LAB, 'FontWeight','normal');
th.Units = 'centimeters';
th.Position(2) = effortH + TITLE_OFF;
hold(axc(m),'off');

% ---- Panel letter ---------------------------------------------------
% The five plots form one panel of Figure 2, not five, so the row takes a
% single letter at its top left. Set PANEL_LETTER to match the position
% of the EMG row in the assembled figure.
annotation(fig2,'textbox',[0.004, 0.925, 0.05, 0.07], ...
    'String', PANEL_LETTER, 'FontName', FONT, ...
    'FontSize', FS_PANEL, 'FontWeight','bold', 'EdgeColor','none', ...
    'HorizontalAlignment','left','VerticalAlignment','middle');

% ---- Export ---------------------------------------------------------
if isfield(cfg,'figures') && ~isempty(cfg.figures)
    figDir = cfg.figures;
else
    figDir = pwd;
end
if ~exist(figDir,'dir'), mkdir(figDir); end

exportgraphics(fig2, fullfile(figDir,'fig2_emg_row.pdf'), ...
    'ContentType','vector','BackgroundColor','white');
exportgraphics(fig2, fullfile(figDir,'fig2_emg_row.png'), ...
    'Resolution',600,'BackgroundColor','white');

fprintf('\nEMG figure written to %s\n', figDir);


%% Local functions
% ---------------------------------------------------------------------
function sigBracket(ax, x1, x2, y, h, label, fontName, fontSize, below)
% A comparison bracket with its significance label. When below is true
% the bracket sits under the data, so its ticks point up toward the
% points being compared and the label sits beneath the rule.
    if nargin < 9, below = false; end

    if below
        plot(ax, [x1 x1 x2 x2], [y+h, y, y, y+h], 'k-', ...
            'LineWidth', 0.5, 'HandleVisibility', 'off');
        va = 'top';
    else
        plot(ax, [x1 x1 x2 x2], [y-h, y, y, y-h], 'k-', ...
            'LineWidth', 0.5, 'HandleVisibility', 'off');
        va = 'bottom';
    end

    text(ax, (x1+x2)/2, y, label, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', va, ...
        'FontName', fontName, 'FontSize', fontSize);
end

function s = pStars(p)
% Conventional asterisk coding. Deliberately coarse: it marks which
% comparisons cleared threshold, and the caption carries the actual
% values.
    if     p < 0.001, s = '***';
    elseif p < 0.01,  s = '**';
    elseif p < 0.05,  s = '*';
    else,             s = 'n.s.';
    end
end

function [F, eta2p] = rmF(Y)
% One-way repeated measures F and partial eta squared at every sample.
% Y is nSubj x nCond x nSamp. Returns 1 x nSamp each.
%
% F decides significance; partial eta squared describes magnitude. The
% two answer different questions, and they diverge sharply here: a small
% but highly consistent difference produces a large F because the error
% term is tiny, while partial eta squared stays modest because it is a
% proportion of variance rather than a ratio to error.
    [n, k, ~] = size(Y);
    gm  = mean(Y, [1 2]);
    mc  = mean(Y, 1);                     % condition means
    ms  = mean(Y, 2);                     % subject means

    ssCond  = n * sum((mc - gm).^2, 2);
    ssSubj  = k * sum((ms - gm).^2, 1);
    ssTotal = sum((Y - gm).^2, [1 2]);
    ssErr   = ssTotal - ssCond - ssSubj;

    msCond = ssCond / (k - 1);
    msErr  = ssErr  / ((n - 1) * (k - 1));

    F = squeeze(msCond ./ msErr)';
    F(~isfinite(F)) = 0;

    eta2p = squeeze(ssCond ./ (ssCond + ssErr))';
    eta2p(~isfinite(eta2p)) = 0;
end

function [mass, runs] = clusterMass(F, thresh)
% Contiguous runs above threshold, and the summed F within each.
% The cycle is treated as linear rather than circular. Epochs are cut at
% movement reversals, so sample NSAMP does adjoin sample 1 of the next
% cycle; treating it as linear is the conservative choice, since a
% cluster spanning that boundary would be split rather than merged.
    above = F > thresh;
    if ~any(above), mass = zeros(0,1); runs = zeros(0,2); return; end

    d      = diff([0, above, 0]);
    starts = find(d == 1);
    ends   = find(d == -1) - 1;

    runs = [starts(:), ends(:)];
    mass = arrayfun(@(a,b) sum(F(a:b)), runs(:,1), runs(:,2));
end
