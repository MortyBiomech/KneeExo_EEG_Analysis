%RUN_LMM21  Entry point L1. Does trial-level cortical power predict the rating?
%
%   Question this answers
%   ---------------------
%   Sensorimotor alpha and beta power scale with imposed demand across
%   conditions, and the difficulty participants report is only weakly carried by
%   the periphery. It does not follow that the cortical signal is the trace of
%   the experience. That is a trial-level question: on a trial where a
%   participant's cortical power is unusual for them, is the rating they give
%   also unusual, over and above the pressure, the tracking error and the
%   muscular effort of that same trial?
%
%   THE TEST is one model per cluster, with that cluster's three bands entered
%   together and tested jointly:
%
%     Score ~ 1 + Pressure_ord + EffortIndex_w + Error_w + Error_b + Trial_z
%                + EEG_theta + EEG_alpha + EEG_beta + (1 | Subject_cat)
%
%   Seven tests, one per cluster, Benjamini and Hochberg corrected across the
%   seven. The family is the clusters, not the 21 features. Testing the bands
%   one at a time has little power against an effect spread across them, and
%   the bands of one component are correlated through 1/f structure and
%   spectral leakage anyway. One model over all 21 features is not available:
%   only three participants contribute a component to all seven clusters.
%
%   THE BOUND is one model per feature, the feature alone, reported as an
%   estimate and an interval with no p and no q. That coefficient is a total
%   effect, whereas a band coefficient inside a joint model is adjusted for the
%   other two bands, and "how much could left M1 alpha matter" is naturally a
%   total. The Discussion argument runs on this interval.
%
%   The baseline in both passes is RUN_RESULTS_BEHAVIOUR's mediation model mdlB
%   term for term, which is what the Results sentence "building on the
%   mediation model" claims: pressure ordinal, effort and error split into
%   within- and between-participant components, trial number z scored.
%
%   The feature is centred within participant in the primary specification, so
%   a coefficient is rating points per dB. Specification zfeature repeats it z
%   scored, which is where the standardised bound comes from.
%
%   NO MODEL COMPARISON ANYWHERE. The earlier version of this analysis reported
%   a likelihood ratio and AIC comparison. Those results were a convergence
%   artifact: random slope models were fitting singular, the reported dAIC was
%   impossible, and the likelihood ratio disagreed with the Wald test by orders
%   of magnitude. They must not be used. Specification randslope below re-fits
%   with the random slope and records which fits fail, so the Methods sentence
%   about non-convergence rests on a logged count rather than an assertion.
%
%   Pipeline
%   --------
%     1  BUILD_LMM21_FEATURES  21 trial-level features from the .icatimef files
%     2  join to the behaviour table on SubjectID and RawTrial
%     3  FIT_LMM21_MODELS      seven cluster tests, then 21 single-feature intervals
%     4  REPORT_LMM21          the report, the manuscript numbers, two LaTeX tables
%
%   Step 1 needs tier 2 and takes a few minutes per cluster. Its result is
%   cached in data/derived, so the model runs on a fresh clone with nothing
%   downloaded. See REBUILD_FEATURES below.
%
%   Usage
%   -----
%   Open this file and press Run. The analysis settings live in LMM21_CONFIG,
%   which CHECKS/CHECK_LMM21 reads as well, so the two cannot disagree. Only the
%   run-time choices are below.
%
%   See also LMM21_CONFIG, BUILD_LMM21_FEATURES, CHECK_LMM21,
%            RUN_RESULTS_BEHAVIOUR, RUN_CROSS_CORRELATION.
%
%   Part of the KneeExo-EEG analysis code.

clear
clc

%% ---------------------------------------------------------------------------
%  Bootstrap. Locate config/ relative to this file.
%  ---------------------------------------------------------------------------
%  mfilename is empty when these lines are pasted into the command window, and
%  reports a temporary helper file when a single section is run with
%  Ctrl+Enter, so neither can be trusted on its own.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('run_lmm21');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_lmm21.m and press Run, or make ' ...
           'its folder the current folder first.']);
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);


%% ---------------------------------------------------------------------------
%  Run-time choices. Everything else is in LMM21_CONFIG.
%  ---------------------------------------------------------------------------

% Rebuild the 21 features from the .icatimef files. Needs tier 2. Leave false
% to use the cached table in data/derived, which is what a reproducer does.
REBUILD_FEATURES = false;

L = lmm21_config(cfg);

fprintf('Clusters : %s\n', strjoin(L.clusters(:, 1).', ', '));
fprintf('Bands    : %s\n', strjoin(L.bandNames, ', '));
fprintf('Features : %d\n', L.nFeatures);
fprintf('Behaviour: %s\n', L.files.behaviourSource);


%% ---------------------------------------------------------------------------
%  1. The 21 features
%  ---------------------------------------------------------------------------

if REBUILD_FEATURES || exist(L.files.features, 'file') ~= 2
    if ~REBUILD_FEATURES
        fprintf('\nNo cached feature table, building it.\n');
    end
    [F, featureAudit] = build_lmm21_features(L);
else
    fprintf('\nLoading cached features from %s\n', L.files.features);
    cached = load(L.files.features);
    F = cached.F;
    featureAudit = cached.audit;

    if ~isfield(cached, 'settings') || ...
            cached.settings.featureVersion ~= L.featureVersion
        error('run_lmm21:StaleFeatures', ...
            ['The cached feature table was written by a different version of ' ...
             'the feature definition. Set REBUILD_FEATURES to true.']);
    end
    if ~isequal(sort(cached.settings.clusters), sort(L.clusters(:, 1).'))
        error('run_lmm21:StaleClusters', ...
            ['The cached feature table covers a different set of clusters. ' ...
             'Set REBUILD_FEATURES to true.']);
    end

    fprintf('Built %s by %s, commit %s\n', cached.stamp.written, ...
        cached.stamp.builder, cached.stamp.gitCommit);
end


%% ---------------------------------------------------------------------------
%  2. Join to the behaviour table
%  ---------------------------------------------------------------------------
%  Inner join. A screened-out behavioural trial and an EEG trial with no
%  behavioural counterpart both drop here, and the counts are printed so a large
%  loss is visible rather than absorbed.

loaded = load(L.files.behaviour, 'T');
B = loaded.T;

T = innerjoin(B, F, 'Keys', {'SubjectID', 'RawTrial'});

fprintf(['\nBehaviour %d trials, features %d trials, merged %d trials, ' ...
         '%d participants.\n'], height(B), height(F), height(T), ...
    numel(unique(T.SubjectID)));

if height(T) == 0
    error('run_lmm21:EmptyMerge', ...
        ['The join produced no rows. SubjectID and RawTrial do not line up, ' ...
         'which almost always means one side is keyed on a compacted trial ' ...
         'counter rather than the raw index.']);
end

T.Subject_cat = categorical(T.SubjectID);

% Both pressure codings come from the behaviour table rather than being
% rebuilt here, so this model's condition coding is the coding every other
% model in the paper uses. Pressure_ord is 0, 1, 2 and is what the mediation
% fits; Pressure_cat is Low, Medium, High with Low as the reference level and
% is used only by the sensitivity specification that tests the equal-step
% assumption.
needed = {L.model.ordinal, L.model.categorical, L.model.trial, ...
          L.model.mediators{:}}; %#ok<CCAT>
absent = needed(~ismember(needed, T.Properties.VariableNames));
if ~isempty(absent)
    error('run_lmm21:MissingColumns', ...
        ['The behaviour table has no column for %s. This model is the ' ...
         'mediation model plus a feature, so it needs the same inputs the ' ...
         'mediation uses.'], strjoin(absent, ', '));
end

if ~iscategorical(T.(L.model.categorical))
    error('run_lmm21:NoPressureCat', ...
        '%s is not categorical in the behaviour table.', L.model.categorical);
end

condLevels = categories(T.(L.model.categorical));
fprintf('Pressure: ordinal %s, categorical %s (reference %s)\n', ...
    mat2str(unique(T.(L.model.ordinal)).'), ...
    strjoin(condLevels.', ', '), condLevels{1});


%% ---------------------------------------------------------------------------
%  3. Fit
%  ---------------------------------------------------------------------------

results = fit_lmm21_models(T, L);


%% ---------------------------------------------------------------------------
%  4. Report
%  ---------------------------------------------------------------------------

report_lmm21(results, L, featureAudit);

% The supplementary tables: the sensitivity grid and the build audit, plus the
% intervals of every specification, which is where the standardised bound
% quoted in the manuscript comes from.
report_lmm21_supplement(results, L, featureAudit);

% Three files, one per thing. The cluster tests carry the claim, the feature
% intervals carry the bound, the sensitivity file holds every other
% specification of the cluster tests.
writetable(results.cluster,     L.files.results);
writetable(results.feature,     L.files.intervals);
writetable(results.sensitivity, L.files.sensitivity);

stamp = build_stamp(cfg, struct('analysis', 'lmm21', ...
    'featureVersion', L.featureVersion, ...
    'behaviourSource', L.files.behaviourSource)); %#ok<NASGU>
save(L.files.resultsMat, 'results', 'stamp');

fprintf('\nWritten to %s\n', L.files.outDir);