function cfg = ansymb_config()

    % Single source of truth for every path this analysis needs.
    %
    % In the original working tree each script hardcoded its own absolute
    % paths - 231 of them across 82 files, under two different drive roots.
    % That made the code unrunnable anywhere but one machine. Every script here
    % should call ansymb_config() instead:
    %
    %     cfg = ansymb_config();
    %     load(fullfile(cfg.derived, 'behavior_table.mat'));
    %
    % WHAT YOU NEED TO EDIT
    % ---------------------
    % Only the TOOLBOXES block below, and only if the auto-detection fails.
    % Everything inside the repository is located relative to this file, so a
    % fresh clone works with no editing at all for the analyses that run from
    % the shipped derived data.
    %
    % To re-run the pipeline from raw recordings you must also set cfg.raw to
    % wherever you downloaded the dataset (see README, Data availability).

    thisFile = mfilename('fullpath');
    cfg.root = fileparts(fileparts(thisFile));   % repository root

    %% Repository-internal paths - no editing needed
    cfg.code    = fullfile(cfg.root, 'code');
    cfg.derived = fullfile(cfg.root, 'data', 'derived');
    cfg.figures = fullfile(cfg.root, 'figures');
    cfg.docs    = fullfile(cfg.root, 'docs');

    if ~isfolder(cfg.figures)
        mkdir(cfg.figures);
    end

    %% Raw / intermediate data - NOT shipped with the repository
    % The recordings and the multi-gigabyte intermediates they produce are far
    % too large for a git repository. Point cfg.raw at your download; leave it
    % empty if you are only reproducing figures from the derived tables, which
    % is the common case.
    cfg.raw = '';    % e.g. 'D:\ANSYMB2024_data'

    % The folder numbers ARE the pipeline stages; scripts address them by
    % these literal names. Every stage is listed here, whether or not the
    % analyses shipped in this repository reach it, so that a script never
    % has to build one of these names itself.
    if ~isempty(cfg.raw)
        cfg.source      = fullfile(cfg.raw, '0_source_data');
        cfg.bids        = fullfile(cfg.raw, '1_BIDS_data');
        cfg.rawEEGLAB   = fullfile(cfg.raw, '2_raw-EEGLAB');
        cfg.preprocessed= fullfile(cfg.raw, '3_EEG-preprocessing');
        cfg.spatial     = fullfile(cfg.raw, '4_spatial-filters');
        cfg.singleSubj  = fullfile(cfg.raw, '5_single-subject-EEG-analysis');
        cfg.trialsEvents= fullfile(cfg.raw, '6_0_Trials_Info_and_Events');
        cfg.trialsInfo  = fullfile(cfg.raw, '6_Trials_Info_and_Epoched_data');
        cfg.study       = fullfile(cfg.raw, '7_STUDY');
        cfg.classification = fullfile(cfg.raw, '8_Classification');
        cfg.expAnalysis = fullfile(cfg.raw, '9_EXP_Analysis');
        cfg.timeFreq    = fullfile(cfg.raw, '10_Time_Frequency_Analysis');

        % Per-subject EMG intermediates. The original code wrote these next
        % to the source files, inside the code tree; they are derived,
        % per-subject and large, so they belong with the rest of the data.
        % Written by EMG_processing/main_EMG_processing.m, and by
        % rebuild_EMG_classification_features.m into the _rebuilt variant.
        cfg.structuredEMG        = fullfile(cfg.raw, 'structured_EMG_data');
        cfg.structuredEMGRebuilt = fullfile(cfg.raw, 'structured_EMG_data_rebuilt');
    end

    %% External toolboxes
    % Versions used for the published analysis are listed in the README.
    % Auto-detected if already on the MATLAB path, otherwise set explicitly.
    cfg.eeglab    = locate('eeglab.m',        '');
    cfg.fieldtrip = locate('ft_defaults.m',   '');
    cfg.xdf       = locate('load_xdf.m',      '');
    cfg.bemobil   = locate('bemobil_process_all_EEG_preprocessing.m', ...
                           fullfile(cfg.code, 'data_processing', 'BeMoBIL_Pipeline'));

    %% Experiment constants used across analyses
    cfg.subjects        = 5:18;               % nominal list
    cfg.subjectsEMG     = [5:9 11:18];        % sub-10 has no usable EMG
    cfg.pressures       = [1 3 6];            % bar
    cfg.pressureLabels  = {'P1', 'P3', 'P6'};

    % Fixed across every figure in the manuscript
    cfg.colors.P1 = [1, 115, 178]/255;
    cfg.colors.P3 = [222, 143, 5]/255;
    cfg.colors.P6 = [148, 73, 92]/255;

    cfg.bands.alpha = [8 14];                 % alpha / mu
    cfg.bands.beta  = [14 30];

    cfg.muscles = {'Vastus_med_R', 'Rectus_femoris_R', ...
                   'Gastrocnemius_R', 'Biceps_femoris_R'};

end


function p = locate(sentinelFile, fallback)
    % Find a toolbox by a file that only it provides, else use the fallback.
    w = which(sentinelFile);
    if ~isempty(w)
        p = fileparts(w);
    else
        p = fallback;
    end
end
