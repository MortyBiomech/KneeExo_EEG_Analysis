%% BEHAVIOUR_RATINGS_ANALYSIS
%  Perceived difficulty (1-10) as a function of imposed physical demand.
%
%  Single source of truth: the trial-level table produced by
%  build_behavior_table.m, which holds the intersection of trials
%  surviving EMG and tracking-error quality control. All descriptive and
%  inferential statistics below are computed from that one table, so the
%  numbers reported alongside the trial-level models describe the same
%  data those models were fitted to.
%
%  Outputs: per-subject condition means and SDs, across-subject
%  descriptives, within-individual consistency counts, Friedman omnibus
%  with Kendall's W, Holm-corrected pairwise Wilcoxon signed-rank tests,
%  a paste-ready LaTeX fragment, and Figure 2a.
%
%  NOTE ON PROVENANCE. Earlier versions of this analysis used meanScores
%  and stdScores built directly from All_scores_trackErr.mat. Those
%  variables were found to be corrupted: they systematically
%  underestimated the Medium and High condition means for subjects 11-18
%  by up to 1.49 rating points. They are not used here and should not be
%  reintroduced.
%
%  Requires: Statistics and Machine Learning Toolbox.
% =====================================================================

clc; clear;

%% 0. Configuration and load
% ---------------------------------------------------------------------
cfg = ansymb_config();
addpath(genpath(cfg.code));

load([cfg.derived, filesep, 'behavior_table.mat'], 'T');

LEVELS     = [1 3 6];                          % bar
COND_NAMES = {'Low', 'Medium', 'High'};
SCALE_MIN  = 1;
SCALE_MAX  = 10;

fprintf('Loaded table: %d rows, %d subjects\n', ...
        height(T), numel(unique(T.SubjectID)));

% Pressure may be stored numeric or categorical depending on the build.
% Normalise once, here, so nothing downstream has to branch on type.
if iscategorical(T.Pressure)
    pres = str2double(string(T.Pressure));
else
    pres = double(T.Pressure);
end
assert(all(ismember(pres, LEVELS)), 'Unexpected pressure level in table.');


%% 1. Rating validity screen
% ---------------------------------------------------------------------
% The scale runs 1 to 10, so a zero is not a rating: it marks a trial
% where the response was never captured. Values outside the scale and
% NaNs are treated the same way. This screen runs once, before anything
% reads the table, so that every statistic below describes the same set
% of trials.

isZero   = T.Score == 0;
isNaNsc  = isnan(T.Score);
isRange  = ~isNaNsc & ~isZero & (T.Score < SCALE_MIN | T.Score > SCALE_MAX);
isNonInt = ~isNaNsc & mod(T.Score, 1) ~= 0;
bad      = isZero | isNaNsc | isRange;

fprintf('\n--- Rating validity screen ---\n');
fprintf('Score == 0         : %d\n', sum(isZero));
fprintf('NaN                : %d\n', sum(isNaNsc));
fprintf('Outside %d to %d    : %d\n', SCALE_MIN, SCALE_MAX, sum(isRange));
fprintf('Non-integer (kept) : %d\n', sum(isNonInt));

if any(bad)
    % Broken down two ways. Clustering by subject indicates a logging
    % failure in one session. Clustering by pressure would mean ratings
    % went missing non-randomly with respect to demand, which would bias
    % the condition means and would need reporting.
    fprintf('\nInvalid ratings by subject:\n');
    disp(groupsummary(T(bad, :), 'SubjectID'));
    fprintf('Invalid ratings by pressure:\n');
    disp(groupsummary(table(pres(bad), 'VariableNames', {'Pressure'}), 'Pressure'));
end

T    = T(~bad, :);
pres = pres(~bad);
fprintf('\nRemoved %d rows. Analysed: %d trials.\n\n', sum(bad), height(T));


%% 2. Per-subject condition means and SDs
% ---------------------------------------------------------------------
% The participant is the observational unit. Trial counts differ
% substantially between participants (roughly 98 to 179), so pooling
% trials would weight participants unequally. Every statistic below
% therefore operates on per-subject condition averages.

subs    = unique(T.SubjectID, 'stable');
subsStr = string(subs);
nSubj   = numel(subs);
nCond   = numel(LEVELS);

M_sub  = nan(nSubj, nCond);      % per-subject condition mean
SD_sub = nan(nSubj, nCond);      % per-subject within-condition SD
N_sub  = nan(nSubj, nCond);      % trial count

for i = 1:nSubj
    for j = 1:nCond
        s = T.Score(T.SubjectID == subs(i) & pres == LEVELS(j));
        N_sub(i,j)  = numel(s);
        M_sub(i,j)  = mean(s);
        SD_sub(i,j) = std(s);
    end
end

fprintf('--- Per-subject condition means ---\n');
disp(array2table(M_sub, 'VariableNames', COND_NAMES, 'RowNames', cellstr(subsStr)));

fprintf('--- Per-subject within-condition SD ---\n');
disp(array2table(SD_sub, 'VariableNames', COND_NAMES, 'RowNames', cellstr(subsStr)));

fprintf('--- Trial counts ---\n');
disp(array2table(N_sub, 'VariableNames', COND_NAMES, 'RowNames', cellstr(subsStr)));


%% 3. Across-subject descriptives
% ---------------------------------------------------------------------
grpM  = mean(M_sub, 1, 'omitnan');
grpSD = std(M_sub, 0, 1, 'omitnan');
demandEffect = grpM(end) - grpM(1);

fprintf('--- Descriptives (across-subject) ---\n');
for j = 1:nCond
    fprintf('%-7s M = %.2f, SD = %.2f, range [%.2f, %.2f]\n', ...
        COND_NAMES{j}, grpM(j), grpSD(j), min(M_sub(:,j)), max(M_sub(:,j)));
end
fprintf('Demand effect, High minus Low: %.2f rating points\n', demandEffect);

% Consistency check. Pooling trials adds between-subject variance to
% within-subject variance, so the pooled SD must be at least as large as
% the mean within-subject SD. A violation means the two quantities were
% computed from different data, which is how the corrupted variables
% were originally detected.
fprintf('\n--- Variance consistency check ---\n');
for j = 1:nCond
    withinSD = mean(SD_sub(:,j), 'omitnan');
    pooledSD = std(T.Score(pres == LEVELS(j)));
    flag = '';
    if pooledSD < withinSD, flag = '   <-- INCONSISTENT'; end
    fprintf('%-7s mean within-subject SD = %.2f, pooled trial SD = %.2f%s\n', ...
        COND_NAMES{j}, withinSD, pooledSD, flag);
end


%% 4. Within-individual consistency
% ---------------------------------------------------------------------
[~, idxMin] = min(M_sub, [], 2);
[~, idxMax] = max(M_sub, [], 2);
nEndpoints  = sum(idxMin == 1 & idxMax == nCond);
nMonotonic  = sum(all(diff(M_sub, 1, 2) > 0, 2));

fprintf('\n--- Within-individual consistency ---\n');
fprintf('Lowest under Low and highest under High : %d of %d\n', nEndpoints, nSubj);
fprintf('Strict ordering Low < Medium < High     : %d of %d\n', nMonotonic, nSubj);


%% 5. Friedman omnibus and Kendall's W
% ---------------------------------------------------------------------
% Perceived difficulty is a bounded ordinal rating, so a rank-based
% omnibus test was chosen a priori. Friedman assumes neither normality
% nor sphericity. Kendall's W rescales the same chi-square onto 0 to 1
% and is reported as an effect size, not as a second test.

[pFried, tblFried] = friedman(M_sub, 1, 'off');
chi2 = tblFried{2,5};
dfF  = tblFried{2,3};
W    = chi2 / (nSubj * (nCond - 1));

fprintf('\n--- Friedman omnibus ---\n');
fprintf('chi2(%d) = %.2f, p = %.3g, Kendall W = %.3f\n', dfF, chi2, pFried, W);


%% 6. Pairwise Wilcoxon signed-rank, Holm-corrected
% ---------------------------------------------------------------------
% Three comparisons form a small confirmatory family, and the
% monotonicity claim requires all three to stand, so familywise control
% (Holm) is used rather than FDR. The exact method is feasible at this n
% and avoids the normal approximation.

pairs   = [1 2; 1 3; 2 3];
nPairs  = size(pairs, 1);
pRaw    = nan(nPairs, 1);
pHolm   = nan(nPairs, 1);
pairLab = cell(nPairs, 1);

for c = 1:nPairs
    a = pairs(c,1); b = pairs(c,2);
    pairLab{c} = sprintf('%s vs %s', COND_NAMES{b}, COND_NAMES{a});
    pRaw(c) = signrank(M_sub(:,b), M_sub(:,a), 'method', 'exact');
end

% Holm step-down, with monotonicity of the adjusted values enforced.
[pSorted, ord] = sort(pRaw);
pHolm(ord) = min(cummax(pSorted .* (nPairs:-1:1)'), 1);

fprintf('\n--- Pairwise Wilcoxon signed-rank (Holm-corrected) ---\n');
for c = 1:nPairs
    fprintf('%-18s p_raw = %.4g, p_Holm = %.4g\n', pairLab{c}, pRaw(c), pHolm(c));
end


%% 7. Paste-ready LaTeX fragment
% ---------------------------------------------------------------------
fprintf('\n--- Paste-ready ---\n');
fprintf('Low: $%.2f \\pm %.2f$; Medium: $%.2f \\pm %.2f$; High: $%.2f \\pm %.2f$\n', ...
    grpM(1), grpSD(1), grpM(2), grpSD(2), grpM(3), grpSD(3));
fprintf('Friedman $\\chi^{2}(%d) = %.2f$, $p %s$, Kendall''s $W = %.2f$\n', ...
    dfF, chi2, fmtP(pFried), W);
fprintf('Wilcoxon signed-rank, Holm-corrected, all $p %s$\n', fmtP(max(pHolm)));
fprintf('Consistency: %d of %d participants\n', nMonotonic, nSubj);
fprintf('Demand effect: %.2f rating points\n', demandEffect);


%% 8. Figure 2a
% ---------------------------------------------------------------------
% Every element is subject-level, matching the text. Individual traces
% carry the main claim (the ordering was unanimous); the group summary
% carries the magnitude. No box plot: with 14 participants the raw data
% are fully visible, and a box would summarise something the reader can
% already see.
%
% Colour encodes pressure level only, consistently with the rest of the
% paper. The full 1 to 10 scale is shown so that the headroom above the
% High condition is visible, which pre-empts a ceiling-effect concern.

colLow  = [0.18 0.53 0.76];
colMed  = [0.91 0.64 0.24];
colHigh = [0.75 0.22 0.17];
condCol = [colLow; colMed; colHigh];

FS_TICK  = 6;      % pt, Nature Communications
FS_LABEL = 7;
FS_PANEL = 8;
FONT     = 'Arial';

xCond = 1:nCond;
xSumm = xCond + 0.26;                     % group summary, offset right

% One fixed horizontal offset per participant, reused at all three
% conditions, so the connecting traces stay straight rather than
% zig-zagging through independent jitter.
rng(7, 'twister');
xJit = (rand(nSubj,1) - 0.5) * 0.16;

fig = figure('Units', 'centimeters', 'Position', [2 2 6.0 5.5], ...
             'Color', 'w', 'PaperPositionMode', 'auto');
ax = axes(fig); hold(ax, 'on');

% Individual traces
for i = 1:nSubj
    plot(ax, xCond + xJit(i), M_sub(i,:), '-', ...
        'Color', [0.6 0.6 0.6 0.55], 'LineWidth', 0.4);
end

% Individual points, coloured by condition
for j = 1:nCond
    scatter(ax, xCond(j) + xJit, M_sub(:,j), 9, ...
        'MarkerFaceColor', condCol(j,:), 'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.85);
end

% Group mean and SD
errorbar(ax, xSumm, grpM, grpSD, 'k-', ...
    'LineWidth', 0.9, 'CapSize', 2.5, ...
    'Marker', 'o', 'MarkerSize', 3, ...
    'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');

% Axes
xlim(ax, [0.55, nCond + 0.65]);
ylim(ax, [SCALE_MIN - 0.4, SCALE_MAX + 0.2]);
set(ax, 'XTick', xCond, ...
        'XTickLabel', {sprintf('Low\n(%d bar)',    LEVELS(1)), ...
                       sprintf('Medium\n(%d bar)', LEVELS(2)), ...
                       sprintf('High\n(%d bar)',   LEVELS(3))}, ...
        'YTick', [1 2 4 6 8 10], ...
        'FontName', FONT, 'FontSize', FS_TICK, ...
        'TickDir', 'out', 'Box', 'off', 'LineWidth', 0.5);
ylabel(ax, 'Perceived difficulty', 'FontName', FONT, 'FontSize', FS_LABEL);
xlabel(ax, 'Physical demand',      'FontName', FONT, 'FontSize', FS_LABEL);

% Panel letter, placed in figure coordinates so it survives resizing
annotation(fig, 'textbox', [0.005 0.93 0.08 0.07], 'String', 'a', ...
    'FontName', FONT, 'FontSize', FS_PANEL, 'FontWeight', 'bold', ...
    'EdgeColor', 'none', 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'middle');

hold(ax, 'off');

% Export. Vector for the submission, PNG for quick inspection.
if isfield(cfg, 'figures') && ~isempty(cfg.figures)
    figDir = cfg.figures;
else
    figDir = pwd;
end
if ~exist(figDir, 'dir'), mkdir(figDir); end

exportgraphics(fig, fullfile(figDir, 'fig2a_perceived_difficulty.pdf'), ...
               'ContentType', 'vector', 'BackgroundColor', 'white');
exportgraphics(fig, fullfile(figDir, 'fig2a_perceived_difficulty.png'), ...
               'Resolution', 600, 'BackgroundColor', 'white');

fprintf('\nFigure written to %s\n', figDir);


%% Local functions
% ---------------------------------------------------------------------
% MATLAB requires local functions to appear at the end of a script file.

function s = fmtP(p)
% Journal-style p formatting: small values reported as a bound rather
% than as a spuriously precise figure.
    if p < 0.001
        s = '< 0.001';
    else
        s = sprintf('= %.3f', p);
    end
end
