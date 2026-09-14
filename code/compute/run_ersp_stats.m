% run_ersp_stats.m
% Stage 6. Cluster ERSPs per region, with per-trial quality control, and the
% permutation tests that go with them.
%
%   .icatimef  ->  <Region>_ersp_qc_results.mat, one per region
%
% For each region this computes:
%   * per-participant ERSPs from the QC-surviving trials, baselined over the
%     whole warped cycle and expressed in dB (compute_cluster_ersp)
%   * the omnibus cluster-based permutation test across the three pressures
%   * the pairwise tests against the reference condition, run only where the
%     omnibus found something
% and writes the result. Figures 3 and 4 are built from these files, not from
% anything here; plot_qc_sanity only draws quick-look panels so the numbers
% can be checked before the paper figures are designed.
%
% Run it in one go, or section by section.
%
% Prerequisites
%   * EEGLAB with the FieldTrip plugin
%   * the .icatimef files from precompute/run_ersp_precompute.m
%   * Subjects_ICs_in_clusters.mat under cfg.derived, built from the SAME
%     clustering as the .study files in p.roiStudyFiles. A stale one is the
%     single easiest way to get quietly wrong results here.

clc
clear


%% Paths and parameters
% config/ is always two levels up from code/<stage>/. Both kneeexo_config
% and ersp_params live there.
% Locate config/, which is always two levels up from code/<stage>/.
%
% mfilename is empty when these lines are pasted into the command window,
% and reports a temporary helper file when a single %% section is run with
% Ctrl+Enter, so neither case can be trusted. Fall back to this file's own
% name, which resolves whenever the file is runnable at all.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('run_ersp_stats');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_ersp_stats.m and press Run, ' ...
           'or make its folder the current folder first. Pasting the ' ...
           'bootstrap into the command window gives MATLAB nothing to ' ...
           'resolve the path from.']);
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);

p = ersp_params();

if isempty(cfg.raw)
    error(['This stage reads the .icatimef files and the STUDY. ' ...
           'Set cfg.raw in config/local_paths.m.']);
end

% Where run_ersp_precompute wrote the .icatimef files.
%
% NOTE ON THE OLD LOCATION: the published files sit under
% 5_single-subject-EEG-analysis/timewarp_test/Epoched_data. cfg.epoched
% points at .../Epoched_data without the timewarp_test level, because that
% folder name is a leftover from an experiment and should not be in a
% published tree. Move the existing files there, or point cfg.epoched at the
% old location in config/local_paths.m.
icatimefPath = cfg.epoched;

if ~isfolder(icatimefPath)
    error('run_ersp_stats:NoIcatimefFolder', ...
        ['No .icatimef folder at\n  %s\nSee the note above this line ' ...
         'about the timewarp_test level.'], icatimefPath);
end

subjectsIcsFile = fullfile(cfg.derived, p.subjectsIcsFile);
if ~exist(subjectsIcsFile, 'file')
    error('run_ersp_stats:NoSubjectIcsFile', ...
        ['The subject-to-component assignment is missing:\n  %s\n\n' ...
         'It records which single component each participant contributes ' ...
         'to each cluster, and it cannot be recomputed here. It ships as ' ...
         'derived data.'], subjectsIcsFile);
end

outputPath = fullfile(cfg.figures, 'ERSP_QC');
if ~isfolder(outputPath)
    mkdir(outputPath);
end

if ~exist('ALLCOM', 'var')
    eeglab;
end


%% Subject and component assignment per cluster
% SUBJECTS_ICS{:,1} holds cluster labels in the form
% strrep(erase(roiStudyFile, '.study'), '_', ' '), e.g. 'Left Prim Motor'.
% SUBJECTS_ICS{:,2}.Subjects are 1-based positions in cfg.subjects, not
% participant numbers.
load(subjectsIcsFile, 'SUBJECTS_ICS');

fprintf('%d participants in the analysis: %s\n', ...
    numel(cfg.subjects), mat2str(cfg.subjects));
fprintf('Significance level for the ERSP tests: alpha = %g\n', p.stats.alpha);
fprintf('Permutations: %d\n\n', p.stats.nRandomisations);


%% Statistics STUDY, built once and shared
% Only its design and its etc.statistics are read. The per-cluster naccu
% override for small clusters is applied to a copy inside the loop, so it
% cannot leak from one region to the next.
statsSTUDY = build_stats_study(cfg, p);


%% Per region: QC, ERSP, omnibus and pairwise tests, save, sanity-check
allResults = struct([]);
tStart = tic;

for r = 1:numel(p.roiStudyFiles)

    studyFile    = p.roiStudyFiles{r};
    studyName    = erase(studyFile, '.study');
    clusterLabel = strrep(studyName, '_', ' ');

    fprintf('\n==== %s  (%d of %d) ====\n', clusterLabel, r, ...
        numel(p.roiStudyFiles));

    clusterData = compute_cluster_ersp(clusterLabel, SUBJECTS_ICS, ...
        icatimefPath, p, cfg.subjects);

    fprintf('  %d participants, %d time samples, %d frequencies\n', ...
        numel(clusterData.subjects), numel(clusterData.allTimes), ...
        numel(clusterData.allFreqs));
    fprintf('  %d of %d trials removed by QC (%.1f%%)\n', ...
        sum(clusterData.nTrialsBad(:)), sum(clusterData.nTrialsTotal(:)), ...
        100 * sum(clusterData.nTrialsBad(:)) / sum(clusterData.nTrialsTotal(:)));

    s = assemble_cluster_results(clusterLabel, studyFile, clusterData, ...
        statsSTUDY, p);

    resultFile = fullfile(outputPath, [studyName '_ersp_qc_results.mat']);
    save(resultFile, 's', '-mat');
    fprintf('  Results written to %s\n', resultFile);

    plot_qc_sanity(s, p, fullfile(outputPath, 'sanity_check'), studyName);

    if isempty(allResults)
        allResults = s;
    else
        allResults(end+1) = s; %#ok<SAGROW>
    end

end

fprintf('\nAll regions finished in %.1f min.\n', toc(tStart) / 60);
save(fullfile(outputPath, 'ersp_qc_results_all_ROIs.mat'), 'allResults', '-mat');

fprintf(['\nNext: figures/run_band_pvalue_family.m, which reads every one ' ...
         'of these files and sets the FDR cutoff the figures use.\n']);
