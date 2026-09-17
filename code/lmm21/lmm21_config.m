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
% SEVEN of the eight ROIs, not all eight. Prime_Visual is excluded because it
% is not an independent source: 7 of its 12 components are the same
% (participant, IC) pairs that Right_Parieto_Occipital already contributes.
%
% The eight clustering solutions are separate runs over the same component
% set, each seeded at its own ROI, so one component can land in more than one
% of them. A family of tests carrying the same signal twice is not 24 tests of
% 24 sources; it is 21 sources with three of them counted twice, and the
% Benjamini and Hochberg correction would then describe a family the data do
% not have. Adding a redundant cluster makes the correction look stricter
% while adding no new evidence.
%
% Prime_Visual shares nothing with Left_Parieto_Occipital, so the redundancy
% is specifically with the right-hemisphere cluster.
%
% One overlap survives among the seven kept here: participant 11's IC 29 sits
% in both Left_PreMot_SuppMot and Right_PreMot_SuppMot, one of eight
% components in each. A single equivalent dipole cannot be in both
% hemispheres, so this is a near-midline component that two differently
% seeded runs both claimed. At one in eight it is a caveat for the Methods
% rather than a reason to drop a cluster.
%
% CHECKS/CHECK_LMM21 recomputes every overlap on each run and prints it, so
% these numbers cannot go stale in a comment.
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
%
% THIS IS THE MEDIATION MODEL PLUS ONE TERM, and it has to stay that way.
% The Results sentence opens "Building on the mediation model, we added each
% cortical cluster's whole-cycle band power", so the baseline here is
% RUN_RESULTS_BEHAVIOUR's mdlB, line 435:
%
%     Y ~ Xord + M1w + M2w + Tz + [M1b + M2b] + (1 | Subject)
%
% Three consequences, each of which this file got wrong in its first version.
%
% PRESSURE IS ORDINAL, 0 1 2, not a three-level categorical. The mediation
% fits Xord and uses the categorical coding only once, as an equal-step check
% that the ordinal assumption holds. Specification 'categorical' below carries
% the two-degree-of-freedom version as a sensitivity run, which is also the
% check that the null does not depend on the linearity assumption.
%
% EFFORT AND ERROR ARE SPLIT within and between participant, not entered raw.
% With only a random intercept, a raw trial-level covariate conflates the
% within-participant slope with the between-participant one, and the mediation
% separates them deliberately. The between-participant effort term is
% structurally zero, because the effort index is normalised within participant
% so every participant's mean is four by construction; LMM21_DERIVE_TERMS
% detects that rather than assuming it.
%
% TRIAL NUMBER IS A COVARIATE. The learning effect on tracking error is large,
% about -0.45 degrees per standard deviation of trial number, so leaving it in
% the residual widens every interval and therefore weakens the exclusion bound
% the Discussion rests on.
%
% The within and between terms are computed on the rows entering each model,
% not once on the widest set. A within-participant term centred on rows the
% model does not see is not centred on the data it is fitted to, and carries a
% between-participant residue, which is exactly what the split exists to
% remove.

L.model = struct();
L.model.response  = 'Score';
L.model.ordinal   = 'Pressure_ord';    % 0 1 2, built by BUILD_BEHAVIOUR_TABLE
L.model.categorical = 'Pressure_cat';  % Low / Medium / High, for the sensitivity
L.model.subject   = 'Subject_cat';
L.model.mediators = {'EffortIndex', 'Error'};
L.model.trial     = 'RawTrial';        % becomes Trial_z
L.model.minTrials = 5;     % per participant, below this the feature is NaN

% Scaling of the feature. The prose says "within-subject centred", which is
% what the mediation does to its own trial-level terms, so 'center' is the
% consistent primary and keeps the coefficient in rating points per dB.
% Specification 'zfeature' repeats it z scored, which is where the
% standardised exclusion bound comes from, in rating points per
% within-participant standard deviation.
L.model.featureMode = 'center';

% The primary specification uses a by-participant random intercept because that
% is the random-effects structure of the mediation model these cortical terms
% are added to. Keeping it makes the cluster test an addition to the model the
% manuscript already reports rather than a different model.
%
% It is NOT because the random slope fails. It does not: specification
% randslope fits all seven clusters without a singular fit, and it does not
% agree with the primary about what survives correction. That disagreement is
% a result and is reported in the Results and in the supplement. Do not
% promote randslope to primary on the strength of it, and do not let any
% version of the old sentence, that random slope models did not converge,
% return to the Methods. It was true of the superseded analysis and is false
% of this one.
%
% REML throughout. It is correct here because nothing is compared: every
% feature is judged by a Wald test on its own coefficient. ML would be needed
% only for a likelihood ratio between models with different fixed effects, and
% that comparison was dropped because it was unstable.
%
% spec(key, featureMode, condition, mediatorMode, trialTerm, random, note)
L.specs = spec('primary', 'center', 'ordinal', 'split', true, ...
    '(1 | Subject_cat)', 'the mediation model plus the feature, reported');

L.specs(end+1) = spec('zfeature', 'z', 'ordinal', 'split', true, ...
    '(1 | Subject_cat)', 'feature in SD units, source of the standardised bound');

L.specs(end+1) = spec('categorical', 'center', 'categorical', 'split', true, ...
    '(1 | Subject_cat)', 'pressure with 2 df, tests the linearity assumption');

L.specs(end+1) = spec('notrial', 'center', 'ordinal', 'split', false, ...
    '(1 | Subject_cat)', 'without the trial-number covariate');

L.specs(end+1) = spec('rawcov', 'center', 'ordinal', 'raw', true, ...
    '(1 | Subject_cat)', 'effort and error entered raw, not split');

L.specs(end+1) = spec('nocov', 'center', 'ordinal', 'none', true, ...
    '(1 | Subject_cat)', 'no effort or error covariate at all');

L.specs(end+1) = spec('randslope', 'center', 'ordinal', 'split', true, ...
    '(1 + Pressure_ord | Subject_cat)', ...
    'the random slope for pressure, which converges and changes the answer');

L.primarySpec = 'primary';

% The specification whose interval is quoted as the standardised bound.
L.boundSpec = 'zfeature';

% THE FAMILY IS THE SEVEN CLUSTERS, not the 21 features.
%
% Each cluster is tested once, by a joint Wald test on its three band
% coefficients entered together, and the correction runs across those seven
% tests. The 21 single-feature fits still run, but they are reported as
% estimates and intervals with no p and no q, because they are the precision
% statement the Discussion needs rather than decisions.
%
% Two reasons for testing at the cluster level. Twenty-one marginal tests have
% little power against an effect spread across the bands of a region, and the
% bands of one component are correlated through 1/f structure and spectral
% leakage in any case. And it is the question the manuscript asks, which is
% about regions rather than about individual features.
%
% One model containing all 21 features is not an option: only three
% participants contribute a component to all seven clusters.
L.stats = struct();
L.stats.family    = 'cluster';
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

L.files.results     = fullfile(L.files.outDir, 'lmm21_cluster_tests.csv');
L.files.intervals   = fullfile(L.files.outDir, 'lmm21_feature_intervals.csv');
L.files.sensitivity = fullfile(L.files.outDir, 'lmm21_sensitivity.csv');
L.files.resultsMat  = fullfile(L.files.outDir, 'lmm21_results.mat');
L.files.report      = fullfile(L.files.outDir, 'lmm21_stats_report.txt');
L.files.clusterTable = fullfile(L.files.outDir, 'lmm21_cluster_table.tex');
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
function s = spec(key, featureMode, condition, mediatorMode, trialTerm, ...
    random, note)
%SPEC  One specification.
%
%  condition     'ordinal' or 'categorical'
%  mediatorMode  'split' for the within and between terms the mediation uses,
%                'raw' for the trial-level values as they stand, 'none' to
%                leave effort and error out
%  trialTerm     include the z scored trial number

s = struct('key', key, 'featureMode', featureMode, 'condition', condition, ...
    'mediatorMode', mediatorMode, 'trialTerm', trialTerm, ...
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