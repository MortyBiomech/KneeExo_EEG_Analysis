%% ACCEPTANCE_TEST
%  Verifies that the rebuilt masters reproduce the values already
%  validated from the old pipeline. Nothing should be built on the
%  masters until this passes.
%
%  WHY THIS MATTERS. The rebuild rests on a claim: that the old numbers
%  were correct and only the plumbing was fragile. If the new pipeline
%  reproduces them, the claim holds and the manuscript text stands. If it
%  does not, one of the two is wrong and we need to know which before
%  either reaches the paper.
%
%  TARGETS (across-subject means of per-subject condition means)
%    Perceived difficulty   Low 1.80  Med 4.23  High 6.99   effect 5.20
%    Tracking error (deg)   Low 5.73  Med 6.06  High 6.19
%      NB this is a MEAN ABSOLUTE error, not the root-mean-square the
%      manuscript describes. Per-epoch RMS runs 1.216 times larger and
%      gives 7.01, 7.49, 7.63. The numbers in the paper are right; the
%      label is not.
%    Effort index           Low 2.96  Med 3.96  High 5.02   n = 13
%    Fold change High/Low   VM 1.24   RF 1.03   GM 2.64   BF 2.70
%
%  THE SCREENS THE OLD PIPELINE APPLIED, now explicit rather than baked
%  in. Writing them down is half the value of this script.
%    1. Experimental trials only.
%    2. EMG epochs of at least 2000 samples.
%    3. Epochs whose event timing was an outlier within subject, by
%       median absolute deviation with a threshold factor of 3, applied
%       to the extension-start and extension-end indices.
%    4. Trials left with fewer than five epochs after step 3.
%    5. iEMG outliers within subject and condition, again 3 MAD.
%    6. Ratings outside 1 to 10.
%  Steps 3 to 5 are analysis choices, not data properties, which is
%  exactly why they now live here rather than inside a builder.
% =====================================================================

clc
clear

%% 0. Configuration
% ---------------------------------------------------------------------
% config/ is three levels up from code/<stage>/checks/.
%
% mfilename is empty at the command prompt and reports a temporary helper
% file when a single %% section is run, so fall back to this file's name.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('acceptance_test');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open acceptance_test.m and press Run, ' ...
           'or make its folder the current folder first.']);
end
addpath(fullfile(fileparts(fileparts(fileparts(thisFile))), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);

if isempty(cfg.raw)
    error(['This reads the master tables written by run_build_masters.m. ' ...
           'Set cfg.raw in config/local_paths.m.']);
end

out_path = cfg.masters;     % masters and the behaviour table

LEVELS     = [1 3 6];
COND_NAMES = {'Low','Medium','High'};
MUSCLE_COLS = {'iEMG_VM','iEMG_RF','iEMG_GM','iEMG_BF'};
MUSCLE_NAMES = {'Vastus med','Rectus fem','Gastrocnemius','Biceps fem'};

TARGET.rating  = [1.80 4.23 6.99];
TARGET.error   = [5.73 6.06 6.19];
TARGET.effort  = [2.96 3.96 5.02];
TARGET.fold    = [1.24 1.03 2.64 2.70];
% Tolerance, per measure rather than one global number. A difference is
% only meaningful relative to how much that measure varies between
% participants, so each is set at roughly a tenth of its own
% between-subject SD (ratings ~0.83, tracking ~1.41, effort ~0.31). A
% single absolute tolerance would be lenient for the effort index and
% punitive for tracking error.
TOL.rating = 0.08;
TOL.error  = 0.14;
TOL.effort = 0.04;
TOL.fold   = 0.05;

load(fullfile(out_path,'emg_master_index.mat'), 'masterIndex');
E = masterIndex;
load(fullfile(out_path,'trk_master_index.mat'), 'masterIndex');
X = masterIndex;
clear masterIndex


%% 1. Screen the EMG master
% ---------------------------------------------------------------------
% SignalHasVariance is what excludes subject 10, whose EMG stream exists
% but contains only zeros. Previously that subject survived this screen
% and was removed later only because dividing zeros by their zero mean
% produced NaN. Relying on NaN propagation for an exclusion is not a
% state to leave a pipeline in.
keepE = E.IsExperiment & E.EpochHasSignal & E.EpochLongEnough & ...
        E.EventsValid & E.AllMusclesFound & E.ScoreValid & ...
        ismember(E.Pressure, LEVELS);

if ismember('SignalHasVariance', E.Properties.VariableNames)
    keepE = keepE & E.SignalHasVariance;
else
    warning(['SignalHasVariance is missing from the master. Rerun ' ...
             'build_emg_master.m, or subject 10 will pass this screen.']);
end
fprintf('EMG epochs after basic flags: %d of %d\n', sum(keepE), height(E));

% Event-timing outliers, within subject, as the old pipeline did.
subsE = unique(E.SubjectID);
for i = 1:numel(subsE)
    s = E.SubjectID == subsE(i) & keepE;
    o1 = false(height(E),1); o2 = false(height(E),1);
    o1(s) = isoutlier(E.ExtStart(s), 'median', 'ThresholdFactor', 3);
    o2(s) = isoutlier(E.ExtEnd(s),   'median', 'ThresholdFactor', 3);
    keepE = keepE & ~(o1 | o2);
end
fprintf('EMG epochs after event-timing outliers: %d\n', sum(keepE));

% Trials left with fewer than five epochs.
[gT, tKey] = findgroups(E(keepE, {'SubjectID','RawTrial'}));
cnt = splitapply(@numel, find(keepE), gT);
thin = tKey(cnt < 5, :);
if ~isempty(thin)
    isThin = ismember(E(:, {'SubjectID','RawTrial'}), thin);
    keepE = keepE & ~isThin;
end
fprintf('EMG epochs after dropping trials with under five epochs: %d\n', sum(keepE));


%% 2. Epochs to trials, then normalise within subject
% ---------------------------------------------------------------------
% iEMG is stored unnormalised, so normalisation happens here. Each
% muscle is divided by that subject's own mean across retained trials,
% which is what the old pipeline did and what makes amplitudes
% comparable between participants. Being a scalar divide per muscle, it
% leaves condition ratios untouched, so the fold changes are unaffected.

Ek = E(keepE, :);
[g, trialKey] = findgroups(Ek(:, {'SubjectID','RawTrial'}));

Tt = trialKey;
Tt.Pressure = splitapply(@(x) x(1), Ek.Pressure, g);
Tt.Score    = splitapply(@(x) x(1), Ek.Score,    g);
for m = 1:numel(MUSCLE_COLS)
    Tt.(MUSCLE_COLS{m}) = splitapply(@mean, Ek.(MUSCLE_COLS{m}), g);
end

% iEMG outliers within subject and condition.
drop = false(height(Tt),1);
for i = 1:numel(subsE)
    for c = 1:numel(LEVELS)
        s = Tt.SubjectID == subsE(i) & Tt.Pressure == LEVELS(c);
        if sum(s) < 3, continue; end
        o = false(sum(s),1);
        for m = 1:numel(MUSCLE_COLS)
            o = o | isoutlier(Tt.(MUSCLE_COLS{m})(s), 'median', 'ThresholdFactor', 3);
        end
        idx = find(s);
        drop(idx(o)) = true;
    end
end
Tt = Tt(~drop, :);
fprintf('Trials after iEMG outlier removal: %d\n', height(Tt));

% Per-subject normalisation and the effort index.
for i = 1:numel(subsE)
    s = Tt.SubjectID == subsE(i);
    for m = 1:numel(MUSCLE_COLS)
        Tt.(MUSCLE_COLS{m})(s) = Tt.(MUSCLE_COLS{m})(s) / mean(Tt.(MUSCLE_COLS{m})(s));
    end
end
Tt.EffortIndex = sum(Tt{:, MUSCLE_COLS}, 2);


%% 3. Screen the tracking master and aggregate
% ---------------------------------------------------------------------
% SCREENING POLICY. The intersection: a trial counts only if it survives
% both the tracking and the EMG screens. The mediation and the integration
% model need a rating, an EMG value and a tracking value on the same
% trial, so they run on the intersection whatever we do here. Reporting
% behavioural means from a larger set would leave the paragraph and the
% models quoting numbers that do not reconcile.
%
% This costs data. Screening tracking on EMG quality is not justified on
% its own terms, and the tracking-only set holds 1953 trials against the
% intersection's 1732. Any analysis not feeding the mediation could
% legitimately use the larger set, provided the Methods states both
% counts.
%
% ERROR DEFINITION. MeanAbsError, not RMSError. The two differ by a
% factor of 1.216 and the published values match the mean absolute
% figure: the manuscript's description of the measure as
% root-mean-square is wrong and needs correcting, but the numbers stand.
% Per-epoch values are averaged into a trial, matching how the EMG
% aggregates.

keepX = X.IsExperiment & X.EpochHasSignal & X.LengthsMatch & ...
        X.EventsValid & X.ScoreValid & ismember(X.Pressure, LEVELS);
Xk = X(keepX, :);
[gx, xKey] = findgroups(Xk(:, {'SubjectID','RawTrial'}));

Tx = xKey;
Tx.Pressure = splitapply(@(x) x(1), Xk.Pressure, gx);
Tx.Score    = splitapply(@(x) x(1), Xk.Score,    gx);
Tx.Error    = splitapply(@mean, Xk.MeanAbsError, gx);
Tx.RMSError = splitapply(@mean, Xk.RMSError,     gx);
fprintf('Tracking trials after flags: %d\n', height(Tx));

% Intersect with the EMG-surviving trials.
Tx = innerjoin(Tx, Tt(:, {'SubjectID','RawTrial'}), ...
               'Keys', {'SubjectID','RawTrial'});
fprintf('Tracking trials after intersecting with EMG: %d\n', height(Tx));

% Subject 10 has no EMG at all, so the intersection would drop it
% entirely. Its trials are reinstated on the tracking screen alone, which
% is what the old behaviour table did: the column was NaN rather than the
% subject being excluded.
noEMGsubs = setdiff(unique(X.SubjectID), unique(Tt.SubjectID));
if ~isempty(noEMGsubs)
    extra = Xk(ismember(Xk.SubjectID, noEMGsubs), :);
    [ge, eKey] = findgroups(extra(:, {'SubjectID','RawTrial'}));
    Te = eKey;
    Te.Pressure = splitapply(@(x) x(1), extra.Pressure, ge);
    Te.Score    = splitapply(@(x) x(1), extra.Score,    ge);
    Te.Error    = splitapply(@mean, extra.MeanAbsError, ge);
    Te.RMSError = splitapply(@mean, extra.RMSError,     ge);
    Tx = [Tx; Te];
    fprintf('Reinstated %d trials from %d subject(s) without EMG: %s\n', ...
        height(Te), numel(noEMGsubs), mat2str(noEMGsubs'));
end
fprintf('Tracking trials analysed: %d\n', height(Tx));


%% 4. Subject-level condition means
% ---------------------------------------------------------------------
% Per-subject means, then across subjects, matching how every number in
% the manuscript was computed. Trial counts differ by design between the
% early and late subjects, so pooling would weight them unequally.

subsAll = unique([Tt.SubjectID; Tx.SubjectID]);

R = nan(numel(subsAll), 3);      % ratings
Q = nan(numel(subsAll), 3);      % tracking error
F = nan(numel(subsAll), 3);      % effort index
M = nan(numel(subsAll), 3, 4);   % per muscle

for i = 1:numel(subsAll)
    for c = 1:numel(LEVELS)
        se = Tt.SubjectID == subsAll(i) & Tt.Pressure == LEVELS(c);
        sx = Tx.SubjectID == subsAll(i) & Tx.Pressure == LEVELS(c);

        % Ratings come from the tracking side, which retains all 14
        % subjects; the EMG master is missing one.
        if any(sx)
            R(i,c) = mean(Tx.Score(sx));
            Q(i,c) = mean(Tx.Error(sx));
        end
        if any(se)
            F(i,c) = mean(Tt.EffortIndex(se));
            for m = 1:4
                M(i,c,m) = mean(Tt.(MUSCLE_COLS{m})(se));
            end
        end
    end
end


%% 5. Compare against the targets
% ---------------------------------------------------------------------
fprintf('\n%s\n', repmat('=', 1, 64));
fprintf('ACCEPTANCE TEST\n');
fprintf('%s\n', repmat('=', 1, 64));

pass = true;
pass = report('Perceived difficulty', mean(R,1,'omitnan'), TARGET.rating, TOL.rating) && pass;
fprintf('   demand effect: %.2f (target 5.20)\n', ...
    mean(R(:,3),'omitnan') - mean(R(:,1),'omitnan'));

pass = report('Tracking error (deg)', mean(Q,1,'omitnan'), TARGET.error, TOL.error) && pass;
fprintf('   High minus Low: %.2f deg\n', ...
    mean(Q(:,3),'omitnan') - mean(Q(:,1),'omitnan'));
pass = report('Effort index',         mean(F,1,'omitnan'), TARGET.effort, TOL.effort) && pass;

fold = nan(1,4);
for m = 1:4
    fold(m) = mean(M(:,3,m),'omitnan') / mean(M(:,1,m),'omitnan');
end
pass = report('Fold change High/Low', fold, TARGET.fold, TOL.fold) && pass;

fprintf('\nSubjects contributing: ratings %d, tracking %d, EMG %d\n', ...
    sum(any(~isnan(R),2)), sum(any(~isnan(Q),2)), sum(any(~isnan(F),2)));

fprintf('\n%s\n', repmat('-', 1, 64));
if pass
    fprintf(['PASS. The rebuild reproduces the validated values, so the\n' ...
             'old numbers were sound and only the plumbing was fragile.\n' ...
             'The manuscript text stands and the masters can be built on.\n']);
else
    fprintf(['FAIL. Do not build on either version yet. A discrepancy here\n' ...
             'means one pipeline is wrong, and which one has to be settled\n' ...
             'before any of these numbers reach the paper. Compare the\n' ...
             'screening counts above against the old pipeline first: the\n' ...
             'likeliest cause is a screen applied in a different order or\n' ...
             'at a different level.\n']);
end
fprintf('%s\n', repmat('-', 1, 64));


%% Local functions
% ---------------------------------------------------------------------
function ok = report(label, got, want, tol)
    d  = got - want;
    ok = all(abs(d) <= tol);
    if ok, mark = 'pass'; else, mark = 'FAIL'; end
    fprintf('\n%-22s %s\n', label, mark);
    fprintf('   got    %s\n', num2str(got,  '%8.2f'));
    fprintf('   target %s\n', num2str(want, '%8.2f'));
    fprintf('   diff   %s\n', num2str(d,    '%+8.2f'));
end
