function L = lmm21_config(cfg)
%LMM21_CONFIG  Every setting the trial-level cortical LMM uses, in one place.
%
%   L = LMM21_CONFIG(CFG) returns the settings, the folders and the output file
%   names for the 21-feature analysis. RUN_LMM21, BUILD_LMM21_FEATURES and
%   CHECKS/CHECK_LMM21 all read from here, so they cannot disagree about which
%   clusters, which bands or which participants they are working on.
%
%   No path is written down in this file that is not derived from CFG. Change
%   the analysis here; the entry point carries only the run-time choices.
%
%   See also RUN_LMM21, KNEEEXO_CONFIG, COUPLING_CONFIG.
%
%   Part of the KneeExo-EEG analysis code.

if nargin < 1 || isempty(cfg)
    cfg = kneeexo_config();
end

L = struct();
L.cfg = cfg;

% ---- what is analysed ---------------------------------------------------

% Participants, in the order the clustering used. SUBJECTS_ICS stores
% positions in this list rather than participant numbers, so it must be the
% list the clustering ran on.
L.subjects = cfg.subjects;

% The clusters, and the short prefix each contributes to a feature name.
%
% SEVEN of the eight ROIs, not all eight. Prime_Visual is left out, which is
% the composition the earlier whole-brain table used and the only one that
% gives the 21 features the manuscript states. The exclusion is historical
% rather than principled, so it is a decision to confirm rather than a fact:
% adding Prime_Visual gives 24 features, changes the correction, and means
% changing "21" everywhere in the Results and Methods. Whichever way it goes,
% it has to be stated in the Methods, because a reader comparing this list
% against ersp_params.roiStudyFiles will count eight.
L.clusters = { ...
    'Left_Prim_Motor',         'LM1',   'left primary motor'; ...
    'Right_Prim_Motor',        'RM1',   'right primary motor'; ...
    'Left_PreMot_SuppMot',     'LPM',   'left premotor and supplementary motor'; ...
    'Right_PreMot_SuppMot',    'RPM',   'right premotor and supplementary motor'; ...
    'Left_Parieto_Occipital',  'LPO',   'left parieto-occipital'; ...
    'Right_Parieto_Occipital', 'RPO',   'right parieto-occipital'; ...
    'Left_Dorsal_ACC',         'LdACC', 'left dorsal anterior cingulate'};

% Bands. Read from cfg.bands rather than declared here, so this analysis and
% the FDR family in stage 7 cannot drift apart. Gamma is excluded: it is in
% the Figure 3 family of 16 tests but not in this one, because the demand
% effect is absent from gamma and the manuscript states 21, not 28.
%
% Lower edge inclusive, upper edge exclusive, matching COUPLING_CONFIG, so
% adjacent bands never share a frequency bin. cfg.bands lists them as
% [4 8], [8 14], [14 30], which would otherwise overlap at 8 and 14 Hz.
L.bandNames  = {'theta', 'alpha', 'beta'};
L.bandLabels = {'theta', 'mu and alpha', 'beta'};
L.bands      = struct();
for b = 1:numel(L.bandNames)
    L.bands.(L.bandNames{b}) = cfg.bands.(L.bandNames{b});
end

L.nFeatures = size(L.clusters, 1) * numel(L.bandNames);

% ---- how the feature is built -------------------------------------------

% Trial quality control. The published ERSPs drop trials flagged by
% FLAG_BAD_TRIALS per participant and condition, so the same screen is applied
% here. Turning it off means the null is computed on a different set of trials
% from the figures, which then has to be stated.
L.applyErspQC = true;

% Observation level. Movement cycles are averaged within a trial before
% anything else, which matches the behaviour table, the coupling analysis and
% the level the rating is given at.
L.aggregate = 'trial';

% Baseline. One spectrum per participant and cluster: the mean over the three
% conditions of each condition's mean over QC-surviving trials, averaged over
% the cycle. This is COMPUTE_CLUSTER_ERSP's baseline exactly, so a feature here
% is the same quantity as a pixel of the published ERSP, averaged over a band
% and the cycle rather than over trials.
%
% It must stay condition-balanced. A plain mean over trials would let a
% participant with more trials in one condition shift the reference, and the
% between-condition difference is the effect the figures report.
%
% It must also stay common across trials. A per-trial baseline divides each
% trial by its own power and removes exactly the trial-to-trial variation this
% model exists to test. CHECK_LMM21 asserts both properties.
L.baseline = 'ersp';          % 'ersp', or 'none' for raw log power

% Order of operations. Everything is averaged in linear ratio units and
% converted to dB once, at the end. Converting per epoch and averaging
% afterwards computes a geometric mean across cycles, which is a different
% feature.
L.aggSpace = 'linear';

% ---- the model ----------------------------------------------------------

L.model = struct();
L.model.response   = 'Score';
L.model.condition  = 'Pressure_cat';   % Low / Medium / High, reference Low
L.model.subject    = 'Subject_cat';
L.model.covariates = {'Error', 'EffortIndex'};

% Within-participant scaling of the feature. 'z' makes a coefficient rating
% points per within-participant standard deviation, so its confidence interval
% is directly the exclusion bound the Discussion sets against the 5.20 rating
% point demand effect. 'center' keeps dB.
L.model.featureMode   = 'z';
L.model.covariateMode = 'raw';
L.model.minTrials     = 5;     % per participant, below this the feature is NaN

% Random slope models did not converge, so the primary specification uses a
% by-participant random intercept and tests each feature by its own fixed
% effect coefficient. Specification randslope re-fits with the slope and
% records the failures, so the Methods sentence rests on a logged count.
%
% REML throughout. It is correct here because nothing is compared: every
% feature is judged by a Wald test on its own coefficient. ML would be needed
% only for a likelihood ratio between models with different fixed effects, and
% that comparison was dropped because it was unstable.
L.specs = spec('primary',   'z',      {'Error','EffortIndex'}, 'raw', ...
               '(1 | Subject_cat)', 'primary, reported in the paper');
L.specs(end+1) = spec('centred',   'center', {'Error','EffortIndex'}, 'raw', ...
               '(1 | Subject_cat)', 'feature in dB rather than SD units');
L.specs(end+1) = spec('nocov',     'z',      {},                      'raw', ...
               '(1 | Subject_cat)', 'no effort or error covariate');
L.specs(end+1) = spec('zcov',      'z',      {'Error','EffortIndex'}, 'z', ...
               '(1 | Subject_cat)', 'covariates within participant z scored too');
L.specs(end+1) = spec('randslope', 'z',      {'Error','EffortIndex'}, 'raw', ...
               '(1 + Pressure_cat | Subject_cat)', ...
               'expected to fail, the failure is the result');

L.primarySpec = 'primary';

L.stats = struct();
L.stats.fitMethod = 'REML';
L.stats.dfMethod  = 'satterthwaite';
L.stats.alpha     = 0.05;
L.stats.fdrQ      = 0.05;

% ---- where the inputs are -----------------------------------------------
%
% Spelled out rather than looked up by a generic field name, for the reason
% COUPLING_CONFIG gives: "epoched" means the single-subject EEG epochs in one
% part of the project and the epoched experiment streams in another.

L.paths = struct();
L.paths.icatimef = '';
if ~isempty(cfg.raw)
    L.paths.icatimef = fullfile(cfg.raw, '5_single-subject-EEG-analysis', ...
        'Epoched_data');
end

L.files = struct();
L.files.clusterIC = fullfile(cfg.derived, 'Subjects_ICs_in_clusters.mat');
L.files.pairing   = fullfile(cfg.derived, 'epoch_pairing_map.mat');

% The behaviour table. Prefer the copy the behaviour branch just wrote, fall
% back to the one shipped in data/derived, so the model runs on a fresh clone.
% RUN_RESULTS_BEHAVIOUR reads cfg.masters, so preferring it keeps the null and
% Figure 2 on the same rows, which is the single authoritative source rule.
L.files.behaviour = fullfile(cfg.derived, 'behaviour_table.mat');
L.files.behaviourSource = 'data/derived (shipped)';
if ~isempty(cfg.raw)
    fromMasters = fullfile(cfg.masters, 'behaviour_table.mat');
    if exist(fromMasters, 'file') == 2
        L.files.behaviour = fromMasters;
        L.files.behaviourSource = 'cfg.masters (rebuilt)';
    end
end

% The 21 features, cached. Committed alongside the other derived tables, for
% the same reason figure2_precomputed.mat is: it lets the whole model run
% without tier 2, which is several gigabytes of .icatimef.
L.files.features = fullfile(cfg.derived, 'lmm21_features.mat');

% ---- where the outputs go -----------------------------------------------
% cfg.figures is the output root for figure files and statistics reports, and
% is gitignored. ERSP_QC is laid out the same way.

L.files.outDir = fullfile(cfg.figures, 'LMM21');

L.files.results     = fullfile(L.files.outDir, 'lmm21_results.csv');
L.files.sensitivity = fullfile(L.files.outDir, 'lmm21_sensitivity.csv');
L.files.resultsMat  = fullfile(L.files.outDir, 'lmm21_results.mat');
L.files.report      = fullfile(L.files.outDir, 'lmm21_stats_report.txt');
L.files.supplement  = fullfile(L.files.outDir, 'lmm21_supplementary_table.tex');
L.files.audit       = fullfile(L.files.outDir, 'lmm21_feature_audit.csv');

if exist(L.files.outDir, 'dir') ~= 7
    mkdir(L.files.outDir);
end

% ---- cache validity -----------------------------------------------------
% Bump this whenever the meaning of a stored feature changes, so a cache
% written by an older version is rebuilt rather than loaded and misread.
%   1  first version: 7 clusters, theta/alpha/beta, ERSP baseline, ERSP QC
L.featureVersion = 1;

L.settings = struct('featureVersion', L.featureVersion, ...
    'clusters', {L.clusters(:, 1).'}, 'bandNames', {L.bandNames}, ...
    'bands', L.bands, 'subjects', L.subjects, ...
    'applyErspQC', L.applyErspQC, 'aggregate', L.aggregate, ...
    'baseline', L.baseline, 'aggSpace', L.aggSpace);

% ---- fail now rather than an hour into the run --------------------------

check_config(L);

end


% ----------------------------------------------------------------------------
function s = spec(key, featureMode, covariates, covariateMode, random, note)
%SPEC  One specification. Built singly because struct() with a cell argument
%      turns an empty covariate list into a 0x0 struct array without an error.

s = struct('key', key, 'featureMode', featureMode, ...
    'covariates', {covariates}, 'covariateMode', covariateMode, ...
    'random', random, 'note', note);

end


% ----------------------------------------------------------------------------
function check_config(L)
%CHECK_CONFIG  Catch the mistakes that would otherwise surface as a result.

% The manuscript states 21. A cluster or a band quietly going missing would
% change what the correction is applied across while the run still finished.
if L.nFeatures ~= 21
    error('lmm21_config:FeatureCount', ...
        ['%d clusters by %d bands gives %d features. The manuscript reports ' ...
         '21. Either fix the lists or change the number in the Results, the ' ...
         'Methods and the supplementary table caption.'], ...
        size(L.clusters, 1), numel(L.bandNames), L.nFeatures);
end

abbr = L.clusters(:, 2);
if numel(unique(abbr)) ~= numel(abbr)
    error('lmm21_config:DuplicateAbbreviation', ...
        'Two clusters share a feature prefix: %s.', strjoin(abbr.', ', '));
end

for b = 1:numel(L.bandNames)
    e = L.bands.(L.bandNames{b});
    if numel(e) ~= 2 || e(1) >= e(2)
        error('lmm21_config:BandEdges', ...
            'Band %s has edges %s.', L.bandNames{b}, mat2str(e));
    end
end

% Inputs that must exist whatever is being run.
if exist(L.files.clusterIC, 'file') ~= 2
    error('lmm21_config:MissingClusterICs', ...
        ['Cannot find the cluster to component mapping at\n  %s\nIt holds ' ...
         'SUBJECTS_ICS and ships in data/derived.'], L.files.clusterIC);
end

if exist(L.files.behaviour, 'file') ~= 2
    error('lmm21_config:MissingBehaviour', ...
        ['Cannot find the behaviour table at\n  %s\nRun ' ...
         'behaviour/run_build_masters.m, or use the copy in data/derived.'], ...
        L.files.behaviour);
end

% Inputs needed only when the features are rebuilt. Missing ones are reported
% by BUILD_LMM21_FEATURES, which is where they first matter, so that the model
% still runs from the cached feature table on a machine without tier 2.

end
