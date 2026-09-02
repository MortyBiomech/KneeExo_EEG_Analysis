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
        'YTick', [1 2 3 4 5 6 7 8 9 10], ...
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




%% TRACKING_ERROR_ANALYSIS
%  Tracking accuracy (trial-wise RMS error, degrees) as a function of
%  imposed physical demand.
%
%  Source: the same screened trial-level table used for the ratings, so
%  that all behavioural numbers describe one set of trials.
%
%  This script is built to establish what is true rather than to confirm
%  a prior claim. Specifically:
%
%   - A non-significant omnibus test does not license the word
%     "equivalent". Equivalence requires TOST against a bound chosen on
%     substantive grounds, not read off the data.
%
%   - The trial-level mediation model reported an effect of pressure on
%     tracking error whose CIs excluded zero (3 vs 1: +0.40 [0.06, 0.74];
%     6 vs 1: +0.53 [0.03, 1.02]). The subject-level test has n = 14,
%     the trial-level model has ~1700 observations, so the two can
%     disagree purely through power. Section 5 refits the trial-level
%     model here so the two can be compared directly.
%
%  Requires: Statistics and Machine Learning Toolbox.
% =====================================================================

clc; 

%% 0. Configuration and load
% ---------------------------------------------------------------------
cfg = ansymb_config();
addpath(genpath(cfg.code));

load([cfg.derived, filesep, 'behavior_table.mat'], 'T');

LEVELS     = [1 3 6];
COND_NAMES = {'Low', 'Medium', 'High'};

% ---- Equivalence bound, in degrees. --------------------------------
% This MUST be set on substantive grounds before looking at the result:
% the smallest difference in tracking error that would matter for the
% interpretation. Candidates are the reference-path tolerance from the
% task design, the angular resolution of the goniometer, or a smallest
% effect size of interest argued from the tracking literature.
% Section 4 reports the smallest bound that the data would satisfy, so
% that an unjustifiable choice is visible rather than hidden.
DELTA = NaN;    % <-- set in degrees, e.g. 1.0. Leave NaN to skip TOST.

if iscategorical(T.Pressure)
    pres = str2double(string(T.Pressure));
else
    pres = double(T.Pressure);
end

fprintf('Loaded table: %d rows, %d subjects\n', height(T), numel(unique(T.SubjectID)));


%% 1. Validity screen
% ---------------------------------------------------------------------
% Two screens, reported separately. The rating screen is applied so that
% the analysed trial set matches the ratings analysis and the mediation.
% The error screen catches missing or impossible RMS values.

badScore = T.Score == 0 | isnan(T.Score) | T.Score < 1 | T.Score > 10;
badError = isnan(T.Error) | T.Error < 0;

fprintf('\n--- Validity screen ---\n');
fprintf('Invalid rating rows : %d\n', sum(badScore));
fprintf('Invalid error rows  : %d\n', sum(badError));
fprintf('Rows failing either : %d\n', sum(badScore | badError));

% Reported for transparency: restricting to rating-valid trials is a
% choice, not a necessity, since an error value is valid whether or not
% the rating was captured. The effect of that choice is shown here.
if sum(badScore & ~badError) > 0
    fprintf(['Note: %d trials have a valid error but no valid rating. ' ...
             'They are excluded to keep the analysed set identical to ' ...
             'the ratings and mediation analyses.\n'], sum(badScore & ~badError));
end

keep = ~(badScore | badError);
T    = T(keep, :);
pres = pres(keep);
fprintf('Analysed: %d trials.\n\n', height(T));


%% 2. Per-subject condition means
% ---------------------------------------------------------------------
subs    = unique(T.SubjectID, 'stable');
subsStr = string(subs);
nSubj   = numel(subs);
nCond   = numel(LEVELS);

E_sub  = nan(nSubj, nCond);      % per-subject condition mean RMS error
Esd    = nan(nSubj, nCond);
N_sub  = nan(nSubj, nCond);

for i = 1:nSubj
    for j = 1:nCond
        e = T.Error(T.SubjectID == subs(i) & pres == LEVELS(j));
        N_sub(i,j) = numel(e);
        E_sub(i,j) = mean(e);
        Esd(i,j)   = std(e);
    end
end

fprintf('--- Per-subject condition mean RMS error (deg) ---\n');
disp(array2table(E_sub, 'VariableNames', COND_NAMES, 'RowNames', cellstr(subsStr)));

grpM  = mean(E_sub, 1, 'omitnan');
grpSD = std(E_sub, 0, 1, 'omitnan');

fprintf('--- Descriptives (across-subject) ---\n');
for j = 1:nCond
    fprintf('%-7s M = %.2f, SD = %.2f, range [%.2f, %.2f]\n', ...
        COND_NAMES{j}, grpM(j), grpSD(j), min(E_sub(:,j)), max(E_sub(:,j)));
end
fprintf('High minus Low: %+.2f deg (%.1f%% of the Low mean)\n\n', ...
    grpM(3) - grpM(1), 100*(grpM(3)-grpM(1))/grpM(1));

% Direction of the within-subject change, which a group mean can hide.
nUp = sum(E_sub(:,3) > E_sub(:,1));
fprintf('Participants with higher error under High than Low: %d of %d\n\n', nUp, nSubj);


%% 3. Difference testing
% ---------------------------------------------------------------------
% RMS error is continuous, so the parametric route is primary here. This
% differs from the ratings analysis by design: the a priori argument for
% rank-based tests there rested on the ordinal, bounded rating scale,
% which does not apply to a continuous kinematic measure.

% One-way repeated measures ANOVA via a within-subject model.
tblRM = array2table(E_sub, 'VariableNames', {'Low','Medium','High'});
within = table(categorical(LEVELS(:)), 'VariableNames', {'Pressure'});
rm = fitrm(tblRM, 'Low,Medium,High ~ 1', 'WithinDesign', within);
ranovaTbl = ranova(rm);

fprintf('--- Repeated measures ANOVA ---\n');
disp(ranovaTbl);
fprintf('Mauchly test of sphericity:\n');
disp(mauchly(rm));

% Friedman, as a distribution-free robustness check.
[pFr, tblFr] = friedman(E_sub, 1, 'off');
fprintf('Friedman robustness check: chi2(%d) = %.2f, p = %.3g\n\n', ...
    tblFr{2,3}, tblFr{2,5}, pFr);

% Pairwise paired t-tests, Holm-corrected.
pairs   = [1 2; 1 3; 2 3];
nPairs  = size(pairs,1);
pRaw    = nan(nPairs,1);
pHolm   = nan(nPairs,1);
dz      = nan(nPairs,1);
diffM   = nan(nPairs,1);
ci90    = nan(nPairs,2);
pairLab = cell(nPairs,1);

for c = 1:nPairs
    a = pairs(c,1); b = pairs(c,2);
    pairLab{c} = sprintf('%s minus %s', COND_NAMES{b}, COND_NAMES{a});
    d = E_sub(:,b) - E_sub(:,a);

    [~, pRaw(c)] = ttest(d);
    diffM(c) = mean(d);
    dz(c)    = mean(d) / std(d);                      % Cohen's dz

    % 90% CI, because a TOST at alpha = 0.05 is equivalent to asking
    % whether the 90% CI falls entirely inside the equivalence bounds.
    se  = std(d) / sqrt(nSubj);
    tcr = tinv(0.95, nSubj - 1);
    ci90(c,:) = mean(d) + [-1 1] * tcr * se;
end

[pS, ord] = sort(pRaw);
pHolm(ord) = min(cummax(pS .* (nPairs:-1:1)'), 1);

fprintf('--- Pairwise paired t-tests (Holm-corrected) ---\n');
for c = 1:nPairs
    fprintf('%-22s diff = %+.3f deg, 90%% CI [%+.3f, %+.3f], dz = %+.2f, p_Holm = %.4g\n', ...
        pairLab{c}, diffM(c), ci90(c,1), ci90(c,2), dz(c), pHolm(c));
end


%% 4. Equivalence testing
% ---------------------------------------------------------------------
% Reported in two parts. First, the smallest equivalence bound each
% comparison would satisfy, which is simply the larger absolute limit of
% its 90% CI. This makes visible what bound the data would require, so
% that a bound cannot be quietly reverse-engineered from the result.
% Second, the TOST itself against the pre-specified DELTA.

fprintf('\n--- Smallest bound the data would satisfy ---\n');
minDelta = max(abs(ci90), [], 2);
for c = 1:nPairs
    fprintf('%-22s equivalence holds for Delta >= %.3f deg\n', pairLab{c}, minDelta(c));
end
fprintf('Across all comparisons: Delta >= %.3f deg\n', max(minDelta));
fprintf(['A bound must be justified independently of this number. ' ...
         'If no defensible bound exceeds it, the equivalence claim ' ...
         'should be dropped rather than fitted to the data.\n']);

if ~isnan(DELTA)
    fprintf('\n--- TOST against Delta = %.3f deg ---\n', DELTA);
    for c = 1:nPairs
        a = pairs(c,1); b = pairs(c,2);
        d  = E_sub(:,b) - E_sub(:,a);
        se = std(d) / sqrt(nSubj);
        df = nSubj - 1;

        tLower = (mean(d) - (-DELTA)) / se;     % H0: diff <= -DELTA
        tUpper = (mean(d) -   DELTA)  / se;     % H0: diff >=  DELTA
        pLower = 1 - tcdf(tLower, df);
        pUpper = tcdf(tUpper, df);
        pTOST  = max(pLower, pUpper);

        verdict = 'not equivalent';
        if pTOST < 0.05, verdict = 'equivalent'; end
        fprintf('%-22s p_TOST = %.4g  (%s)\n', pairLab{c}, pTOST, verdict);
    end
end

% Bayes factors for the null, as a second line of evidence. BF01 above
% about 3 is conventionally read as moderate support for the null.
fprintf('\n--- JZS Bayes factors (Cauchy prior, r = 0.707) ---\n');
for c = 1:nPairs
    a = pairs(c,1); b = pairs(c,2);
    d = E_sub(:,b) - E_sub(:,a);
    [bf10, bf01] = jzsBayesFactorPaired(d, 0.707);
    fprintf('%-22s BF10 = %.3f, BF01 = %.2f\n', pairLab{c}, bf10, bf01);
end


%% 5. Trial-level model, for comparison with the mediation
% ---------------------------------------------------------------------
% The mediation reported a pressure effect on tracking error. That model
% runs on ~1700 trials; section 3 runs on 14 subject means. If the two
% disagree, the likely explanation is power, not contradiction. Refitting
% here makes the comparison direct.

T.PressureCat = categorical(pres, LEVELS, COND_NAMES);
T.PressureCat = reordercats(T.PressureCat, COND_NAMES);   % Low is reference

lme = fitlme(T, 'Error ~ PressureCat + (1|SubjectID)');

fprintf('\n--- Trial-level model: Error ~ Pressure + (1|Subject) ---\n');
disp(lme.Coefficients);
fprintf('\nFixed-effect CIs:\n');
disp(coefCI(lme));

fprintf(['\nCompare the Medium and High coefficients above against the ' ...
         'subject-level differences in section 3. A significant effect ' ...
         'here alongside a null there indicates a small effect that ' ...
         'n = 14 cannot resolve, and the manuscript wording should ' ...
         'follow the better-powered estimate.\n']);







%% STIFFENING_CHECK
%  Does greater knee-extensor activation on a trial go with lower
%  tracking error on that trial?
%
%  Motivation. Vastus medialis activity rises with imposed resistance
%  while rectus femoris does not. One reading is selective recruitment of
%  the extensor whose action is confined to the knee, stiffening the
%  joint to stabilise against the added load. That reading predicts a
%  within-subject association: among trials at the same pressure, those
%  with more extensor activity should show less tracking error.
%
%  This is an association, not a causal test. Two readings survive a
%  negative coefficient (stiffening aids stabilisation) and one survives
%  a positive one (trials that went badly involved both more muscular
%  activity and more error). Section 4 addresses the specificity of the
%  result, which is what separates them.
%
%  Requires: Statistics and Machine Learning Toolbox.
% =====================================================================

clc; 

%% 0. Load
% ---------------------------------------------------------------------
cfg = ansymb_config();
addpath(genpath(cfg.code));

load([cfg.derived, filesep, 'behavior_table.mat'], 'T');

LEVELS     = [1 3 6];
COND_NAMES = {'Low', 'Medium', 'High'};

if iscategorical(T.Pressure)
    pres = str2double(string(T.Pressure));
else
    pres = double(T.Pressure);
end


%% 1. Rebuild the muscle indices from the raw channels
% ---------------------------------------------------------------------
% Deliberately not using the FlexorIndex and ExtensorIndex columns in
% the saved table. Earlier versions of build_behavior_table.m assigned
% those two names the wrong way round, so a table built before that fix
% has them swapped. The four single-muscle columns are unambiguous, so
% the indices are recomputed here from them.
%
%   vastus medialis, rectus femoris -> knee extensors
%   gastrocnemius, biceps femoris   -> knee flexors

ExtensorIdx = T.VastusMed + T.Recfem;
FlexorIdx   = T.Gastroc   + T.BicepFem;
EffortIdx   = ExtensorIdx + FlexorIdx;

% Sanity check against the stored columns, so the labelling state of the
% loaded table is visible rather than assumed.
if all(ismember({'ExtensorIndex','FlexorIndex'}, T.Properties.VariableNames))
    matchesDirect  = isequaln(round(T.ExtensorIndex,6), round(ExtensorIdx,6));
    matchesSwapped = isequaln(round(T.FlexorIndex,6),   round(ExtensorIdx,6));
    if matchesSwapped && ~matchesDirect
        fprintf(['NOTE: the loaded table has FlexorIndex and ExtensorIndex ' ...
                 'swapped. Recomputed values are used below.\n\n']);
    elseif matchesDirect
        fprintf('Stored muscle indices are correctly labelled.\n\n');
    end
end


%% 2. Screen and assemble
% ---------------------------------------------------------------------
badScore = T.Score == 0 | isnan(T.Score) | T.Score < 1 | T.Score > 10;
badError = isnan(T.Error) | T.Error < 0;
badEMG   = isnan(EffortIdx);

keep = ~(badScore | badError | badEMG);

D = table();
D.SubjectID = T.SubjectID(keep);
D.Trial     = T.Trial(keep);
D.Error     = T.Error(keep);
D.Extensor  = ExtensorIdx(keep);
D.Flexor    = FlexorIdx(keep);
D.Effort    = EffortIdx(keep);
D.Pressure  = categorical(pres(keep), LEVELS, COND_NAMES);
D.Pressure  = reordercats(D.Pressure, COND_NAMES);   % Low is reference

fprintf('Excluded: %d invalid rating, %d invalid error, %d missing EMG\n', ...
    sum(badScore), sum(badError), sum(badEMG));
fprintf('Analysed: %d trials, %d subjects\n\n', height(D), numel(unique(D.SubjectID)));


%% 3. Split each predictor into within- and between-subject parts
% ---------------------------------------------------------------------
% The question is within-subject: among a participant's own trials, does
% more extensor activity accompany less error? Entering the raw predictor
% would blend that with the between-subject question of whether
% participants who activate more are more accurate overall, which is a
% different and much weaker design. Person-mean centring separates them,
% so the within-subject coefficient answers the question asked.

subs = unique(D.SubjectID);
D.ExtensorW = nan(height(D),1);  D.ExtensorB = nan(height(D),1);
D.FlexorW   = nan(height(D),1);  D.FlexorB   = nan(height(D),1);
D.EffortW   = nan(height(D),1);  D.EffortB   = nan(height(D),1);

for i = 1:numel(subs)
    r = D.SubjectID == subs(i);
    D.ExtensorB(r) = mean(D.Extensor(r));
    D.ExtensorW(r) = D.Extensor(r) - mean(D.Extensor(r));
    D.FlexorB(r)   = mean(D.Flexor(r));
    D.FlexorW(r)   = D.Flexor(r)   - mean(D.Flexor(r));
    D.EffortB(r)   = mean(D.Effort(r));
    D.EffortW(r)   = D.Effort(r)   - mean(D.Effort(r));
end

% Standardise the within-subject parts so coefficients read as degrees of
% error per SD of activation, which is comparable across muscles.
D.ExtensorWz = D.ExtensorW / std(D.ExtensorW);
D.FlexorWz   = D.FlexorW   / std(D.FlexorW);
D.EffortWz   = D.EffortW   / std(D.EffortW);

% Trial number, centred, to absorb drift across the session.
D.TrialC = (D.Trial - mean(D.Trial)) / std(D.Trial);


%% 4. Models
% ---------------------------------------------------------------------
fprintf('=== Model 1: extensor activity ===\n');
fprintf('Error ~ ExtensorWz + Pressure + TrialC + (1|SubjectID)\n');
m1 = fitlme(D, 'Error ~ ExtensorWz + Pressure + TrialC + (1|SubjectID)');
disp(m1.Coefficients);

fprintf('\n=== Model 2: flexor activity, for comparison ===\n');
m2 = fitlme(D, 'Error ~ FlexorWz + Pressure + TrialC + (1|SubjectID)');
disp(m2.Coefficients);

fprintf('\n=== Model 3: total effort, for comparison ===\n');
m3 = fitlme(D, 'Error ~ EffortWz + Pressure + TrialC + (1|SubjectID)');
disp(m3.Coefficients);

fprintf('\n=== Model 4: extensor and flexor together ===\n');
% If the extensor coefficient survives adjustment for flexor activity,
% the association is specific rather than a by-product of overall
% activation. If both carry the same sign and similar magnitude, the
% stiffening reading is not supported over a generic effort account.
m4 = fitlme(D, 'Error ~ ExtensorWz + FlexorWz + Pressure + TrialC + (1|SubjectID)');
disp(m4.Coefficients);


%% 5. Reading the result
% ---------------------------------------------------------------------
b1 = m1.Coefficients.Estimate(strcmp(m1.Coefficients.Name, 'ExtensorWz'));
p1 = m1.Coefficients.pValue(  strcmp(m1.Coefficients.Name, 'ExtensorWz'));
b4 = m4.Coefficients.Estimate(strcmp(m4.Coefficients.Name, 'ExtensorWz'));

fprintf('\n--- Summary ---\n');
fprintf('Extensor, alone      : %+.4f deg per SD (p = %.3g)\n', b1, p1);
fprintf('Extensor, adjusted   : %+.4f deg per SD\n', b4);
fprintf(['\nNegative and specific to the extensors supports the ' ...
         'stabilisation reading. Positive, or equal across muscle ' ...
         'groups, does not, and the Discussion should hedge ' ...
         'accordingly.\n']);








%% EMG_TABLE_JOIN_CHECK
%  Determines how the EMG structure's trial identifiers map onto the
%  Trial column of the screened behaviour table.
%
%  Why this is needed. EMG_Data_timewarped stores two candidate trial
%  identifiers in trial_epoch:
%     column 1  a counter over experimental trials only
%     column 2  the raw index into structured_EMG_data, which also
%               contains non-experimental trials
%  Only one of them can match T.Trial. The test below does not assume
%  either: for each candidate it checks whether the pressure and score
%  recorded in the EMG structure agree with the behaviour table row
%  carrying that trial number. The correct identifier should agree on
%  essentially every trial; the wrong one should disagree often.
% =====================================================================

clc; 

cfg = ansymb_config();
addpath(genpath(cfg.code));

load([cfg.derived, filesep, 'behavior_table.mat'], 'T');
% load('EMG_Data_timewarped.mat');          % adjust path if needed

data         = EMG_Data_timewarped.data;
subject_list = 5:18;

if iscategorical(T.Pressure)
    Tpres = str2double(string(T.Pressure));
else
    Tpres = double(T.Pressure);
end
Tsubj = double(string(T.SubjectID));

fprintf('Muscle order in file: %s\n\n', strjoin(EMG_Data_timewarped.Muscle_Name, ', '));

results = [];

for s = 1:numel(subject_list)

    subID = subject_list(s);
    if isempty(data{s,2}), continue; end

    st = data{s,2};

    % Trial-level pressure and score, one value per stored trial.
    pTrial = cellfun(@(x) x(1), st.pressure);
    sTrial = cellfun(@(x) x(1), st.score);
    nTrials = numel(pTrial);

    % The two candidate identifiers, one per stored trial. unique() is
    % ascending, and the cell arrays were built and filtered in the same
    % order, so the k-th unique id belongs to the k-th stored trial.
    idsCol1 = unique(st.trial_epoch(:,1), 'stable');
    idsCol2 = unique(st.trial_epoch(:,2), 'stable');

    if numel(idsCol1) ~= nTrials || numel(idsCol2) ~= nTrials
        fprintf(['Sub %d: identifier count (%d, %d) does not match stored ' ...
                 'trial count (%d). Positional correspondence is broken ' ...
                 'and must be fixed before joining.\n'], ...
                 subID, numel(idsCol1), numel(idsCol2), nTrials);
        continue;
    end

    % Behaviour table rows for this subject.
    rows  = Tsubj == subID;
    Ttr   = T.Trial(rows);
    Tp    = Tpres(rows);
    Ts    = T.Score(rows);

    agree = nan(1,2);
    found = nan(1,2);
    for cand = 1:2
        if cand == 1, ids = idsCol1; else, ids = idsCol2; end

        [tf, loc] = ismember(ids, Ttr);
        found(cand) = sum(tf);

        % Among identifiers that exist in the table, do pressure and
        % score agree? Score is compared only where the table's value is
        % valid, since zeros were screened out of the table.
        okP = Tp(loc(tf)) == pTrial(tf);
        okS = Ts(loc(tf)) == sTrial(tf) | sTrial(tf) == 0;
        agree(cand) = mean(okP & okS);
    end

    results = [results; subID, nTrials, height(T(rows,:)), ...
               found(1), agree(1), found(2), agree(2)]; %#ok<AGROW>
end

R = array2table(results, 'VariableNames', ...
    {'Subject','EMGtrials','TableRows', ...
     'Col1_found','Col1_agree','Col2_found','Col2_agree'});

fprintf('--- Join diagnostic ---\n');
disp(R);

fprintf('Mean agreement, column 1: %.3f\n', mean(R.Col1_agree, 'omitnan'));
fprintf('Mean agreement, column 2: %.3f\n', mean(R.Col2_agree, 'omitnan'));
fprintf(['\nThe correct identifier should show agreement near 1.00 and a ' ...
         'found count close to the table row count. If neither does, the ' ...
         'two sources cannot be joined on trial number and we need another ' ...
         'route.\n']);







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

clc; 

%% 0. Configuration
% ---------------------------------------------------------------------
cfg = ansymb_config();
addpath(genpath(cfg.code));

load([cfg.derived, filesep, 'behavior_table.mat'], 'T');
% load('EMG_Data_timewarped.mat');            % adjust path if needed

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
disp(ranova(rm));
disp(mauchly(rm));

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
 
% Event label placement. EV_X are cycle percentages. Labels sit above the
% axes box rather than inside it, so they never collide with the curves.
EV_X = [4, 50, 96];
 
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
        text(axc(m), EV_X(e), yTop*1.02, evLabels{e}, ...
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
 
rng(7,'twister');
xJit  = (rand(nSubjE,1) - 0.5) * 0.16;
xCond = 1:nCond;
 
for i = 1:nSubjE
    plot(axc(m), xCond + xJit(i), E_sub(i,:), '-', ...
        'Color', [0.6 0.6 0.6 0.55], 'LineWidth', 0.4);
end
for c = 1:nCond
    scatter(axc(m), xCond(c) + xJit, E_sub(:,c), 9, ...
        'MarkerFaceColor', COL(c,:), 'MarkerEdgeColor','none', ...
        'MarkerFaceAlpha', 0.85);
end
errorbar(axc(m), xCond + 0.26, gM, gSD, 'k-', 'LineWidth', 0.9, ...
    'CapSize', 2.5, 'Marker','o', 'MarkerSize', 3, ...
    'MarkerFaceColor','k', 'MarkerEdgeColor','k');
 
xlim(axc(m), [0.55, nCond + 0.65]);
yl = ylim(axc(m));
% Box off: this is a condition summary, not a cycle plot, so there are no
% event landmarks for a box to anchor.
set(axc(m), 'XTick', xCond, 'XTickLabel', COND_NAMES, ...
    'YTick', ceil(yl(1)):1:floor(yl(2)), ...
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































%% Local functions
% ---------------------------------------------------------------------
function [bf10, bf01] = jzsBayesFactorPaired(d, r)
% JZS Bayes factor for a one-sample (paired) t-test, following
% Rouder et al. (2009). d is the vector of paired differences, r the
% scale of the Cauchy prior on effect size.
    d = d(~isnan(d));
    N  = numel(d);
    nu = N - 1;
    t  = mean(d) / (std(d) / sqrt(N));

    % Marginal likelihood under H1, integrating over the prior on g.
    numer = integral(@(g) ...
        (1 + N.*g).^(-0.5) .* ...
        (1 + t.^2 ./ ((1 + N.*g) .* nu)).^(-(nu+1)/2) .* ...
        (r/sqrt(2*pi)) .* g.^(-1.5) .* exp(-r.^2 ./ (2.*g)), ...
        0, Inf, 'AbsTol', 1e-10, 'RelTol', 1e-8);

    % Marginal likelihood under H0.
    denom = (1 + t.^2 / nu).^(-(nu+1)/2);

    bf10 = numer / denom;
    bf01 = 1 / bf10;
end






















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