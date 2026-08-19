clc
clear

% Tracking-error analysis for the manuscript's "performance is preserved" claim:
% difference tests first, then equivalence (TOST) and a complementary Bayes
% factor, per the Methods section "Behavioural statistics".
%
% Two deliberate choices:
%
% 1. Source is Subjects_Tracking_Error.mat, not behavior_table.mat.
%    behavior_table.mat intersects error trials with EMG trials
%    (main_data_table.m:44-73), which drops sub-10 entirely and removes trials
%    that have perfectly good tracking data. Tracking error does not need EMG,
%    so restricting it to the EMG subset needlessly costs a subject and power.
%    This script therefore uses all 14 subjects. The mediation analysis, which
%    genuinely needs both, keeps using the intersected table.
%
% 2. EQUIV_BOUND_DEG is set at the top and must be justified from the task or
%    the measurement, not from the result. A sensitivity curve is printed so
%    the reader can see the decision for every bound, which is honest; adopting
%    whichever bound happens to clear the observed interval is not.

%% Paths
% All paths come from the repository config, so this runs from a fresh clone.
% It must be on the MATLAB path first:   addpath('config')   -- see README.
cfg = ansymb_config();
current_path    = fileparts(mfilename('fullpath'));
error_data_path = cfg.derived;
addpath(current_path);   % tost_paired, bayesFactorPairedT live alongside

% -------------------------------------------------------------------------
% PRE-SPECIFY THE EQUIVALENCE BOUND, IN DEGREES, BEFORE READING THE RESULT.
% Nothing below chooses it. See the sensitivity table for context.
EQUIV_BOUND_DEG = 1.0;
ALPHA = 0.05;                 % one-sided per test, i.e. a 90% CI
% -------------------------------------------------------------------------

subject_list = 5:18;
pressures = [1 3 6];


%% Load and reduce to one trial RMSE per trial
S = load(fullfile(error_data_path, 'Subjects_Tracking_Error.mat'));
S = S.(subject_list_fieldname(S));

% Per-cycle RMS then averaged within trial, matching main_data_table.m:66-69
rmse = nan(numel(subject_list), 3);
nTrials = zeros(numel(subject_list), 3);

for i = 1:numel(subject_list)
    sub = S{i, 1};
    trials = unique(sub.trial);

    for k = 1:3
        vals = [];
        for tIdx = 1:numel(trials)
            rows = find(sub.trial == trials(tIdx));
            if isempty(rows) || sub.pressure(rows(1)) ~= pressures(k)
                continue
            end
            perCycle = cellfun(@(x) sqrt(mean(x, 2)), sub.tracking_error(rows));
            vals(end+1, 1) = mean(perCycle, 'omitnan'); %#ok<SAGROW>
        end
        rmse(i, k) = mean(vals, 'omitnan');
        nTrials(i, k) = numel(vals);
    end
end

fprintf('Trial RMSE, subject-level means (n = %d subjects)\n', size(rmse,1));
fprintf('%-8s %8s %8s %8s   %s\n', 'subject', 'P1', 'P3', 'P6', 'trials P1/P3/P6');
for i = 1:numel(subject_list)
    fprintf('sub-%-4d %8.3f %8.3f %8.3f   %d/%d/%d\n', subject_list(i), ...
        rmse(i,1), rmse(i,2), rmse(i,3), nTrials(i,1), nTrials(i,2), nTrials(i,3));
end
fprintf('%-8s %8.3f %8.3f %8.3f\n\n', 'MEAN', mean(rmse(:,1)), mean(rmse(:,2)), mean(rmse(:,3)));


%% Difference tests first - equivalence is only meaningful alongside these
fprintf('=== DIFFERENCE TESTS ===\n');
pFried = friedman(rmse, 1, 'off');
fprintf('Friedman (omnibus)          p = %.4f\n', pFried);

tbl = simple_rmanova(rmse);
fprintf('RM-ANOVA  F(%d,%d) = %.3f, p = %.4f, eta_p^2 = %.3f\n\n', ...
    tbl.df1, tbl.df2, tbl.F, tbl.p, tbl.etaSq);

pairs = [2 1; 3 1; 3 2];
pairNames = {'P3 - P1', 'P6 - P1', 'P6 - P3'};
pRaw = nan(1,3);
for k = 1:3
    [~, pRaw(k)] = ttest(rmse(:,pairs(k,1)), rmse(:,pairs(k,2)));
end
pHolm = holm_bonferroni(pRaw);


%% Equivalence + Bayes factor
fprintf('=== EQUIVALENCE (TOST), bound = +/- %.2f deg, alpha = %.2f ===\n', ...
    EQUIV_BOUND_DEG, ALPHA);
fprintf('%-9s %9s %8s %8s %20s %9s %9s %8s\n', ...
    'pair', 'mean diff', 'p_diff', 'p_holm', sprintf('%d%% CI', round(100*(1-2*ALPHA))), ...
    'p_TOST', 'equival.', 'BF01');

results = struct([]);
for k = 1:3
    r = tost_paired(rmse(:, pairs(k,1)), rmse(:, pairs(k,2)), EQUIV_BOUND_DEG, ALPHA);
    BF01 = bayesFactorPairedT(rmse(:, pairs(k,1)) - rmse(:, pairs(k,2)));

    fprintf('%-9s %+9.3f %8.4f %8.4f   [%+6.3f %+6.3f] %9.4f %9s %8.2f\n', ...
        pairNames{k}, r.meanDiff, pRaw(k), pHolm(k), r.ci(1), r.ci(2), ...
        r.pTOST, string(r.equivalent), BF01);

    results(k).pair = pairNames{k};
    results(k).tost = r;
    results(k).BF01 = BF01;
    results(k).pHolm = pHolm(k);
end


%% Sensitivity: which bounds would and would not yield equivalence
fprintf('\n=== SENSITIVITY OF THE EQUIVALENCE CLAIM TO THE BOUND ===\n');
fprintf('(printed so the chosen bound can be judged in context, not so one can be picked)\n');
candidateBounds = 0.25:0.25:2.0;
fprintf('%-9s', 'bound');
fprintf('%8.2f', candidateBounds); fprintf('\n');
for k = 1:3
    fprintf('%-9s', pairNames{k});
    for b = candidateBounds
        rr = tost_paired(rmse(:, pairs(k,1)), rmse(:, pairs(k,2)), b, ALPHA);
        if rr.equivalent, fprintf('%8s', 'yes'); else, fprintf('%8s', '-'); end
    end
    fprintf('   (min bound %.3f deg)\n', results(k).tost.minDelta);
end

fprintf('\nmean RMSE across conditions: %.2f deg\n', mean(rmse(:)));
fprintf('bound of %.2f deg is %.1f%% of typical tracking error\n', ...
    EQUIV_BOUND_DEG, 100*EQUIV_BOUND_DEG/mean(rmse(:)));

save(fullfile(cfg.figures, 'tracking_error_equivalence_results.mat'), ...
    'results', 'rmse', 'subject_list', 'EQUIV_BOUND_DEG', 'ALPHA', 'pFried', 'tbl');


%% ------------------------------------------------------------------------
function name = subject_list_fieldname(S)
    f = fieldnames(S);
    name = f{1};
end

function pAdj = holm_bonferroni(p)
    [ps, ord] = sort(p);
    m = numel(p);
    adj = cummax(ps .* (m:-1:1));
    pAdj = nan(size(p));
    pAdj(ord) = min(adj, 1);
end

function out = simple_rmanova(Y)
    % One-way repeated-measures ANOVA on an nSubjects x nConditions matrix.
    [n, k] = size(Y);
    grand = mean(Y(:));
    ssCond = n * sum((mean(Y, 1) - grand).^2);
    ssSubj = k * sum((mean(Y, 2) - grand).^2);
    ssTot  = sum((Y(:) - grand).^2);
    ssErr  = ssTot - ssCond - ssSubj;
    df1 = k - 1;
    df2 = (n - 1) * (k - 1);
    F = (ssCond/df1) / (ssErr/df2);
    out = struct('F', F, 'df1', df1, 'df2', df2, ...
        'p', 1 - fcdf(F, df1, df2), 'etaSq', ssCond / (ssCond + ssErr));
end
