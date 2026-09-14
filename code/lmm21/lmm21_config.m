function cfg = lmm21_config()
%LMM21_CONFIG  Every setting of the 21 feature cortical LMM analysis.
%
%  This is the only file in the set that contains a path, a participant
%  number, a band edge, a cluster name or a model formula. Nothing else needs
%  editing when the analysis moves to another machine.
%
%  Lines marked TODO are the assumptions this code makes about the rebuilt
%  pipeline. Check each one before the first run.
%
%  The 21 features are 7 clusters x 3 bands. The manuscript states the number
%  explicitly, so BUILD_EEG_FEATURE_TABLE asserts it rather than trusting the
%  loop to produce it.
%
%  See also BUILD_EEG_FEATURE_TABLE, RUN_LMM_21FEATURES.

% -------------------------------------------------------------------------
% 1. Paths
% -------------------------------------------------------------------------
% TODO check every path below against the rebuilt repository.
cfg.paths.root      = 'D:\Morteza\MyProjects\ANSYMB2024\';
cfg.paths.icatimef  = fullfile(cfg.paths.root, 'data', ...
                        '5_single-subject-EEG-analysis', 'Epoched_data');
cfg.paths.behaviour = fullfile(cfg.paths.root, 'data', 'master_tables');
cfg.paths.clusters  = fullfile(cfg.paths.root, 'data', ...
                        '6_group-level-EEG-analysis', 'Subjects_ICs_in_clusters.mat');
cfg.paths.pairing   = fullfile(cfg.paths.root, 'data', ...
                        '6_group-level-EEG-analysis', 'epoch_pairing_map.mat');
cfg.paths.out       = fullfile(cfg.paths.root, 'results', 'lmm21');

% File name pattern for one participant's time frequency file.
% TODO confirm. The old pipeline wrote S5.icatimef, S6.icatimef and so on.
cfg.paths.icatimefPattern = 'S%d.icatimef';

% -------------------------------------------------------------------------
% 2. Participants
% -------------------------------------------------------------------------
% The STUDY runs over participants 5 to 18, which is the 14 analysed people.
% Cluster membership is stored with a cluster internal index, so participant
% number is subjectList(clusterInternalIndex). Do not hard code the offset.
cfg.subjectList = 5:18;

% How the Subjects field of the cluster membership file is numbered.
%   false  it holds participant numbers, 5 to 18
%   true   it holds an index into cfg.subjectList, 1 to 14
% There is no safe way to detect this: a cluster containing only participants
% 5 to 14 looks identical under both readings, and guessing wrong shifts every
% participant by a constant while the analysis still runs to completion. So it
% is stated here and checked, never inferred.
% TODO open Subjects_ICs_in_clusters.mat and look.
cfg.clusterSubjectsAreIndices = false;

% Participant 10 has an all zero EMG stream, so EffortIndex is missing for
% every one of their trials. They drop out of any model that contains
% EffortIndex, which is why the behavioural effort numbers are n = 13. This is
% handled by the flags in the screened table, not by a list here.

% -------------------------------------------------------------------------
% 3. Clusters
% -------------------------------------------------------------------------
% name   : the name used by the clustering solutions and by study_info.txt
% abbr   : the prefix of the feature column, so LM1_alpha and so on
% label  : the anatomical name for the supplementary table
%
% TODO confirm the names match the folder names of the published clustering
% solutions exactly. The clusters come from seven separate clustering runs,
% each with its own k, so the name is the only reliable key.
cfg.clusters = struct( ...
    'name',  {'Left_Prim_Motor', 'Right_Prim_Motor', ...
              'Left_PreMot_SuppMot', 'Right_PreMot_SuppMot', ...
              'Left_Parieto_Occipital', 'Right_Parieto_Occipital', ...
              'Left_Dorsal_ACC'}, ...
    'abbr',  {'LM1', 'RM1', 'LPM', 'RPM', 'LPO', 'RPO', 'dACC'}, ...
    'label', {'Left primary motor', 'Right primary motor', ...
              'Left premotor and supplementary motor', ...
              'Right premotor and supplementary motor', ...
              'Left parieto occipital', 'Right parieto occipital', ...
              'Dorsal anterior cingulate'});

% -------------------------------------------------------------------------
% 4. Bands
% -------------------------------------------------------------------------
% TODO copy these edges from ersp_params.m. They must be identical to the
% edges used for Figure 3, otherwise the paper describes one quantity in the
% figure and a different one in the null.
cfg.bands = struct( ...
    'name',  {'theta', 'alpha', 'beta'}, ...
    'label', {'theta', 'mu and alpha', 'beta'}, ...
    'edges', {[4 8], [8 13], [13 30]});

% -------------------------------------------------------------------------
% 5. Feature definition
% -------------------------------------------------------------------------
% Whole cycle window, in the warped time axis of the .icatimef file.
%   'timewarp'  take the first and last time warp landmark from the file, so
%               the window is exactly the movement cycle the ERSPs show
%   'explicit'  use cfg.feature.cycleWindowMs instead
cfg.feature.cycleSource   = 'timewarp';
cfg.feature.cycleWindowMs = [];        % used only when cycleSource is explicit

% Baseline. The ERSP pipeline used 'median latency baseline', which
% mod_std_precomp_v_forEEGlabv2021 resolves to [0 medianLatency].
%   'fromfile'  read the resolved window out of the file parameters
%   'explicit'  use cfg.feature.baselineWindowMs
%   'none'      no baseline, features are raw log power
cfg.feature.baselineSource   = 'fromfile';
cfg.feature.baselineWindowMs = [];

% Common baseline means one baseline spectrum per participant and cluster,
% averaged over every epoch. This is required here. A single trial baseline
% divides each epoch by its own baseline and therefore removes exactly the
% trial to trial variance this analysis is trying to model.
cfg.feature.trialBaseline = false;

% Order of operations for the scalar feature. 'linear' averages the power
% ratio over band, over cycle time and over the epochs of a trial, then takes
% 10*log10 once. This is the mean then log definition the earlier pipeline
% called option 2. 'db' converts each epoch first and averages in dB.
cfg.feature.aggSpace = 'linear';

% Observation level. 'trial' averages the movement cycles of a trial, which
% matches the observation level of the behavioural variables and of the
% coupling analysis. 'epoch' keeps cycles as rows and needs a second random
% effect, which is not what the manuscript describes.
cfg.feature.aggregate = 'trial';

% -------------------------------------------------------------------------
% 6. Within participant scaling
% -------------------------------------------------------------------------
% Primary specification z scores each feature inside each participant, so a
% coefficient is rating points per within participant standard deviation and
% the confidence interval is directly the exclusion bound quoted in the
% Discussion. Centring keeps the dB unit and is carried as a sensitivity run.
cfg.scale.featureMode   = 'z';      % primary, 'z' or 'center'
cfg.scale.minTrials     = 5;        % fewer trials than this, participant set to NaN
cfg.scale.covariateMode = 'raw';    % 'raw', 'center' or 'z' for Error and EffortIndex

% -------------------------------------------------------------------------
% 7. Model
% -------------------------------------------------------------------------
cfg.model.response   = 'Score';
cfg.model.condition  = 'Pressure_cat';
cfg.model.subject    = 'Subject_cat';
cfg.model.covariates = {'Error', 'EffortIndex'};
cfg.model.pressureLevels = {'1', '3', '6'};   % reference level first

% Random slope models did not converge, so the primary specification uses a
% by participant random intercept and tests each feature by its fixed effect
% coefficient. Specification RS below re fits with the random slope and
% records the failure, so the Methods sentence rests on a logged result
% rather than on an assertion.
% Built one at a time rather than through struct() with cell arguments,
% because an empty cell in that argument list is a well known way to end up
% with a 0 by 0 struct array and no error.
cfg.specs = spec('primary', 'z', {'Error','EffortIndex'}, 'raw', ...
    '(1 | Subject_cat)', 'REML', 'primary, reported in the paper');

cfg.specs(end+1) = spec('centred', 'center', {'Error','EffortIndex'}, 'raw', ...
    '(1 | Subject_cat)', 'REML', 'feature in dB rather than SD units');

cfg.specs(end+1) = spec('nocov', 'z', {}, 'raw', ...
    '(1 | Subject_cat)', 'REML', 'no effort or error covariate');

cfg.specs(end+1) = spec('zcov', 'z', {'Error','EffortIndex'}, 'z', ...
    '(1 | Subject_cat)', 'REML', 'covariates also within participant z scored');

cfg.specs(end+1) = spec('randslope', 'z', {'Error','EffortIndex'}, 'raw', ...
    '(1 + Pressure_cat | Subject_cat)', 'REML', ...
    'random slope, expected to fail, the failure is the result');

cfg.primarySpec = 'primary';

% REML is correct here because every feature is tested by a Wald test on its
% own coefficient. ML is only needed when two models with different fixed
% effects are compared, and that comparison was dropped because it was
% unstable.

% -------------------------------------------------------------------------
% 8. Inference
% -------------------------------------------------------------------------
cfg.stats.dfMethod = 'satterthwaite';
cfg.stats.alpha    = 0.05;
cfg.stats.fdrQ     = 0.05;

% -------------------------------------------------------------------------
% 9. Output
% -------------------------------------------------------------------------
cfg.out.featureTable   = 'eeg_features_21.mat';
cfg.out.featureAudit   = 'eeg_features_21_audit.csv';
cfg.out.resultsTable   = 'lmm21_results.csv';
cfg.out.sensitivity    = 'lmm21_sensitivity.csv';
cfg.out.results        = 'lmm21_results.mat';
cfg.out.report         = 'lmm21_report.txt';
cfg.out.supplementTex  = 'lmm21_supplementary_table.tex';

cfg.verbose = true;

end

% =========================================================================
function s = spec(key, featureMode, covariates, covariateMode, random, ...
    fitMethod, note)
s = struct('key', key, 'featureMode', featureMode, ...
    'covariates', {covariates}, 'covariateMode', covariateMode, ...
    'random', random, 'fitMethod', fitMethod, 'note', note);
end
