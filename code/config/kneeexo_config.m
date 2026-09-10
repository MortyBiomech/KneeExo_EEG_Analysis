function cfg = kneeexo_config()
% KNEEEXO_CONFIG  Single source of truth for every path and constant.
%
%   cfg = kneeexo_config();
%   load(fullfile(cfg.derived, 'behavior_table.mat'));
%
% In the original working tree each script hardcoded its own absolute paths,
% 231 of them across 82 files, under two different drive roots. That made the
% code unrunnable anywhere but one machine. No script anywhere in this
% repository should contain a drive letter; they all call this function.
%
% WHAT YOU NEED TO EDIT
% ---------------------
% Nothing, for the analyses that run from the shipped derived data. Everything
% inside the repository is located relative to this file.
%
% To re-run the pipeline from the recordings, copy local_paths_example.m to
% local_paths.m and set cfg.raw there. local_paths.m is gitignored, so your
% machine's paths never enter the repository and never conflict with anyone
% else's.
%
% HOW A SCRIPT REACHES THIS FUNCTION
% ----------------------------------
% Every entry point lives in code/<stage>/, so config/ is always two levels up
% and then across. Each one starts with the same three lines:
%
%     addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'config'));
%     cfg = kneeexo_config();
%     addpath(genpath(cfg.code));
%
% That works whether the script is run with F5 from its own folder or called
% from anywhere else, and it needs no manual addpath beforehand.

    thisFile = mfilename('fullpath');
    cfg.root = fileparts(fileparts(thisFile));   % repository root


    %% Repository-internal paths, no editing needed
    cfg.code    = fullfile(cfg.root, 'code');
    cfg.derived = fullfile(cfg.root, 'data', 'derived');
    cfg.figures = fullfile(cfg.root, 'figures');
    cfg.docs    = fullfile(cfg.root, 'docs');


    %% Machine-specific overrides
    % local_paths.m is optional and gitignored. Any field it returns replaces
    % the default below. Read before anything is built from cfg.raw.
    local = struct();
    if exist('local_paths', 'file') == 2
        local = local_paths();
    end


    %% Raw and intermediate data, NOT shipped with the repository
    % The recordings and the multi-gigabyte intermediates they produce are far
    % too large for a git repository. Leave cfg.raw empty if you are only
    % reproducing figures from the shipped derived data, which is the common
    % case.
    cfg.raw = pick(local, 'raw', '');

    % The folder numbers ARE the pipeline stages, and scripts address them by
    % these literal names. Every stage is listed here, whether or not the
    % analyses in this repository reach it, so that a script never has to
    % build one of these names itself.
    if ~isempty(cfg.raw)
        cfg.source         = fullfile(cfg.raw, '0_source_data');
        cfg.bids           = fullfile(cfg.raw, '1_BIDS_data');
        cfg.rawEEGLAB      = fullfile(cfg.raw, '2_raw-EEGLAB');
        cfg.preprocessed   = fullfile(cfg.raw, '3_EEG-preprocessing');
        cfg.spatial        = fullfile(cfg.raw, '4_spatial-filters');
        cfg.singleSubj     = fullfile(cfg.raw, '5_single-subject-EEG-analysis');
        cfg.trialsEvents   = fullfile(cfg.raw, '6_0_Trials_Info_and_Events');
        cfg.trialsInfo     = fullfile(cfg.raw, '6_Trials_Info_and_Epoched_data');
        cfg.study          = fullfile(cfg.raw, '7_STUDY');
        cfg.classification = fullfile(cfg.raw, '8_Classification');
        cfg.expAnalysis    = fullfile(cfg.raw, '9_EXP_Analysis');
        cfg.timeFreq       = fullfile(cfg.raw, '10_Time_Frequency_Analysis');

        % Epoched datasets carrying EEG.timewarp, written by
        % precompute/epoching_timewarp.m. The ERSP precompute writes each
        % participant's .icatimef file into this same folder, because
        % std_ersp builds its output name from STUDY.datasetinfo.filepath.
        cfg.epoched      = fullfile(cfg.singleSubj, 'Epoched_data');

        % STUDY files and clustering solutions for the epoched data.
        cfg.studyEpoched = fullfile(cfg.study, 'Epoched_data');

        % Per-subject EMG intermediates. The original code wrote these next to
        % the source files, inside the code tree; they are derived, per
        % subject and large, so they belong with the rest of the data.
        cfg.structuredEMG        = fullfile(cfg.raw, 'structured_EMG_data');
        cfg.structuredEMGRebuilt = fullfile(cfg.raw, 'structured_EMG_data_rebuilt');
    end


    %% External toolboxes
    % Auto-detected if already on the MATLAB path, otherwise taken from
    % local_paths.m, otherwise from the fallback. Versions used for the
    % published analysis are listed in the README.
    cfg.eeglab    = pick(local, 'eeglab',    locate('eeglab.m',      ''));
    cfg.fieldtrip = pick(local, 'fieldtrip', locate('ft_defaults.m', ''));
    cfg.xdf       = pick(local, 'xdf',       locate('load_xdf.m',    ''));
    cfg.bemobil   = pick(local, 'bemobil',   locate( ...
        'bemobil_process_all_EEG_preprocessing.m', ...
        fullfile(cfg.code, 'vendor', 'bemobil-pipeline')));


    %% Participants
    % The group analysis runs on 5 to 18. Participants 1 to 4 lost most of
    % their EEG recording and were excluded for that reason, not because of
    % anything found in the data. The preprocessing entry points can still be
    % pointed at them if the surviving segments are ever needed.
    cfg.subjects    = 5:18;
    cfg.subjectsEMG = [5:9, 11:18];   % sub-10 has no usable EMG


    %% Experiment constants
    cfg.pressures      = [1 3 6];     % bar
    cfg.pressureLabels = {'P1', 'P3', 'P6'};
    cfg.conditionNames = {'Low', 'Medium', 'High'};

    % Fixed across every figure in the manuscript.
    cfg.colors.P1 = [1, 115, 178]/255;
    cfg.colors.P3 = [222, 143, 5]/255;
    cfg.colors.P6 = [148, 73, 92]/255;

    % Frequency bands. Defined here once. Anything that needs band edges,
    % ersp_params.m included, should read them from cfg rather than declaring
    % its own, otherwise the FDR family staleness check compares against a
    % second definition that can drift.
    cfg.bands.theta = [4 8];
    cfg.bands.alpha = [8 14];         % alpha / mu
    cfg.bands.beta  = [14 30];
    cfg.bands.gamma = [30 60];

    cfg.muscles = {'Vastus_med_R', 'Rectus_femoris_R', ...
                   'Gastrocnemius_R', 'Biceps_femoris_R'};

end


% ------------------------------------------------------------------------
function v = pick(local, field, fallback)
% Value from local_paths.m if it defines this field and it is not empty,
% otherwise the fallback.

    if isfield(local, field) && ~isempty(local.(field))
        v = local.(field);
    else
        v = fallback;
    end

end


% ------------------------------------------------------------------------
function p = locate(sentinelFile, fallback)
% Find a toolbox by a file that only it provides, else use the fallback.

    w = which(sentinelFile);
    if ~isempty(w)
        p = fileparts(w);
    else
        p = fallback;
    end

end