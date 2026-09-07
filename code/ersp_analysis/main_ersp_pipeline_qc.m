%% Cluster ERSPs per anatomical ROI, with per-trial QC (bad-trial removal)
%
% Regenerates the ERSP analysis with the quality-control step that was
% present in the pre-cleanup pipeline (per-subject, per-condition removal
% of outlier trials via TF_QC_BAD_TRIALS) but is missing from
% plot_cluster_ersp.m. For each of the 8 anatomical ROIs, computes:
%   - QC'd single-subject ERSPs per condition (qc/compute_cluster_ersp_qc.m)
%   - the omnibus cluster-based permutation test across the three PAM
%     pressures, and the pairwise tests against the reference condition
%     (P1), both via ersp_cluster_stats.m / cluster_effect_size.m --
%     unchanged from the non-QC'd pipeline
% and saves the result to disk. This IS the full analysis (all 8 ROIs,
% omnibus + pairwise); it is NOT the final paper-figure script. Figure 3
% and Figure 4 will be designed separately from the four clusters (L/R
% primary motor, L/R parieto-occipital) and the .mat files this produces.
% The sanity-check figures below exist only to check the QC'd numbers
% against the earlier non-QC'd run.
%
% Run this file section by section, same as main_ersp_pipeline.m.
%
% Prerequisites
%   * EEGLAB on the path, with the FieldTrip plugin
%   * the .icatimef files from main_ersp_pipeline.m section 2
%   * Subjects_ICs_in_clusters.mat -- confirmed current for these 8 ROIs
%     (i.e. it was built from the same clustering as the .study files
%     main_ersp_pipeline.m uses, not a stale one)
%   * ersp_cluster_stats.m and cluster_effect_size.m already on the path
%     (they ship with the non-QC'd pipeline; reused here unchanged)
%
%% 1. Set up ------------------------------------------------------------
clc; clear;
thisFile = which('main_ersp_pipeline_qc');
if isempty(thisFile)
    error(['Could not locate main_ersp_pipeline_qc.m on the MATLAB path ' ...
        'or in the current folder. cd to the folder containing this ' ...
        'file (or add it to the path) and try again.']);
end
addpath(genpath(fileparts(thisFile)));
addpath(fullfile(fileparts(fileparts(fileparts(thisFile))), 'config'));
cfg = ansymb_config();
p   = ersp_params();

if isempty(cfg.raw)
    error(['Set cfg.raw in config/ansymb_config.m to your copy of the ' ...
        'dataset before running this pipeline.']);
end
if isempty(p.subjectsIcsFile)
    error(['Set p.subjectsIcsFile in ersp_params.m to the path of ' ...
        'Subjects_ICs_in_clusters.mat before running this pipeline.']);
end

icatimefPath = fullfile(cfg.singleSubj, 'timewarp_test', 'Epoched_data');
outputPath   = fullfile(cfg.figures, 'ERSP_QC');
if ~isfolder(outputPath)
    mkdir(outputPath);
end

if ~exist('ALLEEG', 'var')
    eeglab;
end

%% 2. Load the subject/IC assignment per cluster -------------------------
% SUBJECTS_ICS{:,1} are cluster labels matching
% strrep(erase(roiStudyFile,'.study'),'_',' '), e.g. 'Left Prim Motor'.
load([p.subjectsIcsFile, 'SUBJECTS_ICs_in_clusters']);

%% 3. Build the stats STUDY once, shared (with a per-cluster naccu ------
%     override applied inside the loop) across all 8 ROIs and both the
%     omnibus and pairwise tests.
statsSTUDY = build_stats_study(cfg, p);

%% 4. Per ROI: QC, ERSP, omnibus + pairwise stats, save, sanity-check ----
allResults = struct([]);
tStart = tic;

for r = 1:numel(p.roiStudyFiles)
    studyFile    = p.roiStudyFiles{r};
    studyName    = erase(studyFile, '.study');
    clusterLabel = strrep(studyName, '_', ' ');

    fprintf('\n==== %s  (%d of %d) ====\n', clusterLabel, r, numel(p.roiStudyFiles));

    clusterData = compute_cluster_ersp_qc(studyName, SUBJECTS_ICS, icatimefPath, p);
    fprintf('  %d subjects, %d time samples, %d frequencies.\n', ...
        numel(clusterData.subjects), numel(clusterData.allTimes), numel(clusterData.allFreqs));

    s = assemble_cluster_results(clusterLabel, studyFile, clusterData, statsSTUDY, p);

    resultFile = fullfile(outputPath, [studyName '_ersp_qc_results.mat']);
    save(resultFile, 's', '-mat');
    fprintf('  Results written to %s\n', resultFile);

    plot_cluster_qc_sanity(s, p, fullfile(outputPath, 'sanity_check'), studyName);

    if isempty(allResults)
        allResults = s;
    else
        allResults(end+1) = s; %#ok<SAGROW>
    end
end

fprintf('\nAll ROIs finished in %.1f min.\n', toc(tStart)/60);
save(fullfile(outputPath, 'ersp_qc_results_all_ROIs.mat'), 'allResults', '-mat');