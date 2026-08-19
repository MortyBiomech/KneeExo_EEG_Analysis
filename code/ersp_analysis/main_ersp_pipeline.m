%% Cluster ERSPs per anatomical ROI
%
% Produces the time-frequency figures in the manuscript: for each anatomical
% ROI, the event-related spectral perturbation of that ROI's IC cluster
% under the three PAM assistance pressures, and the differences between
% them, with cluster-based permutation statistics.
%
% Run this file section by section. Section 2 is the expensive one and only
% has to run once; after that its output sits on disk as .icatimef files and
% section 4 can be re-run on its own.
%
% Prerequisites
%   * EEGLAB on the path, with the FieldTrip and dipfit plugins
%   * the ROI STUDY files from the repeated k-means clustering stage
%   * epoched datasets carrying .timewarp (from the epoching stage)
%
% See README.md in this folder for what each stage does and why.

%% 1. Set up ---------------------------------------------------------------
clc; clear;

thisFile = mfilename('fullpath');
if isempty(thisFile)
    error('Run this as a file, not by pasting into the command window.');
end
addpath(genpath(fileparts(thisFile)));
addpath(fullfile(fileparts(fileparts(fileparts(thisFile))), 'config'));

cfg = ansymb_config();
p   = ersp_params();

if isempty(cfg.raw)
    error(['This analysis reads the epoched EEG and the ROI STUDY files, ' ...
           'which are not shipped with the repository. Set cfg.raw in ' ...
           'config/ansymb_config.m to your copy of the dataset.']);
end

studyPath    = fullfile(cfg.study, 'Epoched_data', 'multiple_clustering');
icatimefPath = fullfile(cfg.singleSubj, 'timewarp_test', 'Epoched_data');
outputPath   = fullfile(cfg.figures, 'ERSP');

if ~isfolder(studyPath)
    error('ROI STUDY folder not found:\n  %s', studyPath);
end

if ~exist('ALLEEG', 'var')
    eeglab;
end

% Keep datasets on disk rather than in memory; there are 14 of them.
pop_editoptions('option_storedisk', 1, 'option_savetwofiles', 1, ...
    'option_single', 1, 'option_memmapdata', 0, ...
    'option_computeica', 1, 'option_scaleicarms', 1, ...
    'option_rememberfolder', 1);


%% 2. Precompute time-warped ERSPs  [SLOW - run once] ----------------------
% Writes one .icatimef file per subject. Hours for the full set.
%
% Any one of the ROI STUDY files can be used here: they differ only in how
% the ICs were clustered, and the set of ICs is the same in all of them.
%
% By default this section runs only when the .icatimef files are missing, so
% that re-running the whole file does not silently spend hours recomputing
% them. To force a recompute, set RECOMPUTE_ERSP = true in the command
% window before running this section.

if ~exist('RECOMPUTE_ERSP', 'var')
    RECOMPUTE_ERSP = isempty(dir(fullfile(icatimefPath, '*.icatimef')));
end

if RECOMPUTE_ERSP

    firstStudy = p.roiStudyFiles{1};
    [STUDY, ALLEEG] = pop_loadstudy( ...
        'filename', firstStudy, ...
        'filepath', fullfile(studyPath, erase(firstStudy, '.study')));
    STUDY = std_maketrialinfo(STUDY, ALLEEG);

    [STUDY, ALLEEG] = precompute_timewarped_ersp(STUDY, ALLEEG, p, 'groupmedian');

end


%% 3. Read back the parameters the ERSPs were computed with ----------------
% The plotting stage is told explicitly which wavelet parameters produced
% the data on disk, rather than trusting whatever is currently stored in the
% STUDY. Any subject's file will do; they were all computed together.

icatimefFiles = dir(fullfile(icatimefPath, '*.icatimef'));
if isempty(icatimefFiles)
    error(['No .icatimef files in:\n  %s\n' ...
           'Run section 2 first.'], icatimefPath);
end

firstIcatimef   = load('-mat', ...
    fullfile(icatimefPath, icatimefFiles(1).name), 'parameters');
erspParamOverride = firstIcatimef.parameters;

fprintf('ERSP parameters read from %s\n', icatimefFiles(1).name);


%% 4. Plot cluster ERSPs, one ROI at a time --------------------------------

allResults = struct([]);
tStart = tic;

for r = 1:numel(p.roiStudyFiles)

    studyFile = p.roiStudyFiles{r};
    studyName = erase(studyFile, '.study');
    studyTitle = strrep(studyName, '_', ' ');

    fprintf('\n==== %s  (%d of %d) ====\n', ...
        studyTitle, r, numel(p.roiStudyFiles));

    [STUDY, ALLEEG] = pop_loadstudy( ...
        'filename', studyFile, ...
        'filepath', fullfile(studyPath, studyName));
    STUDY = std_maketrialinfo(STUDY, ALLEEG);

    [STUDY, ALLEEG, clustersToPlot] = ...
        prepare_study_for_ersp(STUDY, ALLEEG, p, cfg.eeglab);

    fprintf('Subjects in design:\n');
    fprintf('  %s\n', STUDY.design(STUDY.currentdesign).cases.value{:});

    opts = struct( ...
        'studyTitle',        studyTitle, ...
        'outDir',            fullfile(outputPath, studyName), ...
        'erspParamOverride', {erspParamOverride}, ...
        'savePlots',         true);

    results = plot_cluster_ersp(STUDY, ALLEEG, clustersToPlot, p, opts);

    resultFile = fullfile(opts.outDir, [studyName '_ersp_results.mat']);
    if ~isfolder(opts.outDir)
        mkdir(opts.outDir);
    end
    save(resultFile, 'results', '-mat');
    fprintf('Results written to %s\n', resultFile);

    if isempty(allResults)
        allResults = results;
    else
        allResults(end+1) = results; %#ok<SAGROW>
    end
end

fprintf('\nAll ROIs finished in %.1f min.\n', toc(tStart)/60);
save(fullfile(outputPath, 'ersp_results_all_ROIs.mat'), 'allResults', '-mat');
