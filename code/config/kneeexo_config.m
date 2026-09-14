function cfg = kneeexo_config()
% KNEEEXO_CONFIG  Single source of truth for every path and constant.
%
%   cfg = kneeexo_config();
%   load(fullfile(cfg.derived, 'behaviour_table.mat'));
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
% and then across. Each one starts with the same block:
%
%     thisFile = mfilename('fullpath');
%     if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
%         thisFile = which('<this file''s name>');
%     end
%     addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
%     cfg = kneeexo_config();
%     add_code_paths(cfg);
%
% The guard matters. mfilename returns empty at the command prompt, and the
% path of a temporary helper file when a single %% section is run with
% Ctrl+Enter, so neither can be trusted on its own.
%
% That works whether the script is run with F5 from its own folder or called
% from anywhere else, and it needs no manual addpath beforehand.
%
% add_code_paths adds code/ minus archive/, which must never be on the path.
% The two stages that need the BeMoBIL pipeline ask for it explicitly, with
% add_code_paths(cfg, 'bemobil').

    % This file is at <repo>/code/config/kneeexo_config.m, so the code folder
    % is one level up and the repository root is two. Derive both from the
    % file rather than counting fileparts calls by hand, which is how an
    % earlier version ended up treating the code folder as the root and
    % looking for external/ inside it.
    thisFile = mfilename('fullpath');
    cfg.code = fileparts(fileparts(thisFile));   % <repo>/code
    cfg.root = fileparts(cfg.code);              % <repo>


    %% Repository-internal paths, no editing needed
    % Note the two different "figures": cfg.figures is where figure FILES are
    % written, at the repository root. The code that writes them is in
    % code/figures, which is inside cfg.code. Outputs never go in the code
    % tree.
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
        % precompute/run_epoching_timewarp.m. The ERSP precompute writes each
        % participant's .icatimef file into this same folder, because
        % std_ersp builds its output name from STUDY.datasetinfo.filepath.
        cfg.epoched      = fullfile(cfg.singleSubj, 'Epoched_data');

        % STUDY files and clustering solutions for the epoched data.
        cfg.studyEpoched = fullfile(cfg.study, 'Epoched_data');

        % Master tables for the behaviour branch: one row per raw epoch for
        % EMG and for tracking, plus the trial-level behaviour table built
        % from them. Written by code/behaviour/run_build_masters.m.
        cfg.masters = fullfile(cfg.raw, '7_Master_Tables');

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

    % BeMoBIL is a git submodule under external/, NOT a copy in vendor/. Only
    % the one function we modified lives in vendor/; the rest of the pipeline
    % runs unmodified, so it is pinned by commit instead of duplicated. The
    % folder sits outside code/ on purpose: add_code_paths calls
    % genpath(cfg.code), and a toolbox tree inside that would be added to the
    % path in every stage whether or not the stage uses it.
    %
    % An empty folder means the submodule was never checked out:
    %     git submodule update --init
    cfg.bemobil = pick(local, 'bemobil', locate_bemobil(cfg));


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
function p = locate_bemobil(cfg)
% Find BeMoBIL, but never accept a copy that lives inside the analysis code.
%
% Plain which() is not safe here. If a copy of the pipeline sits somewhere
% under code/, which() finds it, cfg.bemobil then points at it, and
% add_code_paths puts the whole tree on the path in the two stages that ask
% for BeMoBIL. That is the situation the external/ placement exists to
% prevent, and it is easy to create by accident: an in-tree copy is added by
% genpath(cfg.code) in EVERY stage, whether or not the stage wanted it, and
% it shadows the submodule.

    fallback = fullfile(cfg.root, 'external', 'bemobil-pipeline');

    w = which('bemobil_process_all_EEG_preprocessing');
    if isempty(w)
        p = fallback;
        return
    end

    found = fileparts(w);

    if startsWith(lower(found), lower(cfg.code))
        warning('kneeexo_config:BemobilInsideCode', ...
            ['A copy of the BeMoBIL pipeline is inside the analysis code:\n' ...
             '  %s\nIt is being ignored in favour of\n  %s\n\nCompare the ' ...
             'two and delete the in-tree copy. While it is there it goes on ' ...
             'the path in every stage and shadows the pinned submodule, so ' ...
             'which() can disagree with what the repository claims to use.'], ...
            found, fallback);
        p = fallback;
        return
    end

    p = found;

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
