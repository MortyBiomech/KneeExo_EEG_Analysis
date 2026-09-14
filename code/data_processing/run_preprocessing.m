% run_preprocessing.m
% Stage 1. Import and preprocessing, following the BeMoBIL pipeline.
%
% XDF  ->  BIDS  ->  EEGLAB .set  ->  events  ->  cleaning  ->  AMICA
%
% The BeMoBIL pipeline itself is not part of this repository. Clone it into
% code/vendor/bemobil-pipeline, or set cfg.bemobil in config/local_paths.m:
%   https://github.com/BeMoBIL/bemobil-pipeline
% See README for the commit used for the published results.
%
% Everything below is driven by the single subject list in the "Subjects"
% cell. That is the only place a participant number is written down, so the
% import loop and the processing loop cannot point at different people.
%
% You do not need to run this file to reproduce the published results. It
% reads the raw recordings, which are not shipped, and with
% rebuild_events = true it stops twice per participant for a human. See
% README, section "Manual steps".
%
% To look at the stream and channel names inside a raw XDF file, use
% inspect_xdf_streams.m instead of running anything here.

clc
clear


%% Paths
% config/ is always two levels up from code/<stage>/, so this works whether
% the file is run with F5 from its own folder or called from elsewhere.
% Locate config/, which is always two levels up from code/<stage>/.
%
% mfilename is empty when these lines are pasted into the command window,
% and reports a temporary helper file when a single %% section is run with
% Ctrl+Enter, so neither case can be trusted. Fall back to this file's own
% name, which resolves whenever the file is runnable at all.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('run_preprocessing');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_preprocessing.m and press Run, ' ...
           'or make its folder the current folder first. Pasting the ' ...
           'bootstrap into the command window gives MATLAB nothing to ' ...
           'resolve the path from.']);
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg, 'bemobil');   % this stage needs the BeMoBIL pipeline

if isempty(cfg.raw)
    error(['This is the import and preprocessing stage: it reads the raw ' ...
           'XDF recordings, which are not shipped with the repository. ' ...
           'Set cfg.raw in config/local_paths.m.']);
end
if isempty(cfg.xdf)
    error(['xdf-Matlab was not found. Add it to the MATLAB path, or set ' ...
           'cfg.xdf in config/local_paths.m.']);
end
addpath(genpath(cfg.xdf));

if ~isempty(cfg.fieldtrip)
    addpath(cfg.fieldtrip);
    addpath(fullfile(cfg.fieldtrip, 'fileio'));
end

% BeMoBIL and the older helpers expect a trailing separator on these two.
study_path   = [cfg.raw, filesep];
rawdata_path = [cfg.source, filesep];

% Channel locations ship with the code. Generated event tables do not; they
% are written under cfg.derived.
chanlocs_file = fullfile(cfg.code, 'data_processing', 'chanlocs.ced');


%% Subjects
% You can split this list across several MATLAB instances if you have the
% CPU and the RAM.
subjects = cfg.subjects;   % 5:18. Set explicitly to process others.

% 1 recomputes everything, ignoring what is already on disk.
force_recompute = 0;

% How add_events gets the experiment events.
%   false : import the published event table from cfg.derived. The two
%           interactive apps stay closed and the raw streams are not even
%           loaded, which is where most of the running time would go. This is
%           the setting for a participant that has already been processed.
%   true  : rebuild the event table from the raw recordings. Needed only for
%           a participant that has never been processed. Stops twice and
%           waits for a human. See the header of add_events.
rebuild_events = false;

sessionNames = {'S001', 'S002', 'S003'};

% Recording constants.
eeg_stream_name    = 'LiveAmpSN-102108-1125';
task_name          = 'KneeSwingingwithExo';
sampling_rate      = 500;          % nominal, Hz
non_eeg_channels   = [65, 66, 67]; % accelerometer channels to drop


%% Initialize EEGLAB and FieldTrip
if ~exist('ALLCOM', 'var')
	eeglab;
end

% Initialize FieldTrip without adding alternative files to the path,
% assuming it is already on the path or was added by the EEGLAB plugin
% manager.
global ft_default
ft_default.toolbox.signal = 'matlab';
ft_default.toolbox.stats  = 'matlab';
ft_default.toolbox.image  = 'matlab';
ft_defaults


%% Import: XDF to BIDS to EEGLAB
% Written to BIDS-folder/sub-XX/ses-XX/eeg/*_eeg.json. See the BIDS EEG
% specification for the full list of fields.
eegInfo = [];
eegInfo.eeg.SamplingFrequency = sampling_rate;

studyFolder = study_path(1:end-1);

for subject = subjects

    disp(['Importing subject #' num2str(subject)]);

    for session = 1:length(sessionNames)

        config = [];
        config.bids_target_folder = fullfile(studyFolder, '1_BIDS_data');

        config.filename = fullfile(rawdata_path, ...
            ['sub-', num2str(subject)], ...
            ['ses-', sessionNames{session}], 'eeg', ...
            ['sub-', num2str(subject), '_ses-', sessionNames{session}, ...
             '_task-Default_run-001_eeg.xdf']);

        config.task            = task_name;
        config.subject         = subject;
        config.session         = sessionNames{session};
        config.overwrite       = 'on';
        config.eeg.stream_name = eeg_stream_name;

        bemobil_xdf2bids(config, 'eeg_metadata', eegInfo);
    end

    fclose all;

    % config still holds this participant's subject and task, which is what
    % carries them into bids2set.
    config.set_folder    = fullfile(studyFolder, '2_raw-EEGLAB');
    config.session_names = sessionNames;

    bemobil_bids2set(config);

end


%% Preprocessing and AMICA
bemobil_config = bemobil_settings(study_path);

for subject = subjects

	disp(['Subject #' num2str(subject)]);

	STUDY = []; CURRENTSTUDY = 0; ALLEEG = []; CURRENTSET = []; EEG = [];

	input_filepath = [bemobil_config.study_folder ...
        bemobil_config.raw_EEGLAB_data_folder ...
        bemobil_config.filename_prefix num2str(subject)];

    % The raw concatenated streams are needed only to rebuild the event
    % table. Importing the published table needs nothing from them.
    if rebuild_events
        output = concatenate_runs(subject, rawdata_path);
    else
        output = [];
    end

    % Load the file that was created from XDF to BIDS to EEGLAB.
    EEG = pop_loadset('filename', ...
        [bemobil_config.filename_prefix num2str(subject) '_' ...
         bemobil_config.merged_filename], 'filepath', input_filepath);

    % Drop the accelerometer channels and load the channel locations.
    EEG = pop_select(EEG, 'rmchannel', non_eeg_channels);
    EEG = pop_chanedit(EEG, 'load', chanlocs_file);

    % Add the experiment events, and get the sample ranges that lie outside
    % the experiment.
    [EEG, removeindices] = add_events(EEG, output, subject, ...
        cfg.derived, study_path, rebuild_events);

    % Reject the non-experimental periods. Strongly recommended: they can
    % contain strong artifacts that confuse channel detection and AMICA.
    EEG = eeg_eegrej(EEG, removeindices);

    % Basic preprocessing, line noise removal, channel interpolation.
	[ALLEEG, EEG_preprocessed, CURRENTSET] = ...
        bemobil_process_all_EEG_preprocessing(subject, bemobil_config, ...
        ALLEEG, EEG, CURRENTSET, force_recompute);

    % AMICA, then DIPFIT and ICLabel inside the same wrapper.
	bemobil_process_all_AMICA(ALLEEG, EEG_preprocessed, CURRENTSET, ...
        subject, bemobil_config, force_recompute);

end

bemobil_copy_plots_in_one(bemobil_config)

fprintf('\nPreprocessing done for subjects %s\n', mat2str(subjects));
