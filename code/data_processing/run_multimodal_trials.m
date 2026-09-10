% run_multimodal_trials.m
% Stage 2. Cut every recorded modality into trials.
%
% Builds Trials_Info from the curated encoder events, then splits the EEG,
% the EMG and the experiment stream (encoder, pressure, preference, force)
% into per-trial data using it. This is the dataset behind the behavioural
% and EMG analyses, and it is the only place where the three modalities are
% carried together.
%
% Runs after run_preprocessing.m has produced sub-<N>_cleaned_with_ICA.set,
% and needs that participant's curated flexion and extension events.
%
% NOT the epoching that feeds the ERSP analysis. That is
% precompute/epoching_timewarp.m, which cuts movement cycles out of the EEG
% alone and builds the time-warp matrix. The two are independent: neither
% reads the other's output.

clc
clear


%% Paths
% Everything comes from the repository config, so this runs from a fresh
% clone. config/ is always two levels up from code/<stage>/.
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'config'));
cfg = kneeexo_config();
addpath(genpath(cfg.code));

if isempty(cfg.raw)
    error(['This stage reads the raw XDF recordings, which are not ' ...
           'shipped with the repository. Set cfg.raw in ' ...
           'config/local_paths.m.']);
end
if isempty(cfg.xdf)
    error(['xdf-Matlab was not found. Add it to the MATLAB path, or set ' ...
           'cfg.xdf in config/kneeexo_config.m.']);
end
addpath(genpath(cfg.xdf));

% Downstream helpers concatenate onto these, so keep the trailing separator.
data_path    = [cfg.raw, filesep];
rawdata_path = [cfg.source, filesep];


%% What to run
% Edit this line and nothing else to choose which participants to process.
subjects = cfg.subjects;   % 5:18. Set explicitly to process others.

% Delsys sensor ids that carried muscle activity. Six sensors were worn;
% cfg.muscles names the four that the analyses use.
EMG_sensor_id = [2, 3, 4, 5, 6, 7];

% Trial ids of the four sessions. The values themselves do not matter.
sessions_trial_id = [10, 20, 30, 40];

% What one epoch is. 'flextoflex' is one full movement cycle, flexion start
% to the next flexion start, and it is what the analysis uses. The other
% three ('flexion', 'extension', 'trial') were tried and set aside; see the
% header of extract_epochs.
epoch_basis = 'flextoflex';


%% Initialize EEGLAB
if ~exist('ALLCOM', 'var')
    eeglab;
end


%% Processing loop
failed = {};

for subject = subjects

    fprintf('\n================ Subject %d ================\n', subject);

    try

        % All signals of all sessions concatenated (this takes time).
        output = concatenate_runs(subject, rawdata_path);

        % Load the cleaned dataset (.set).
        set_filename = ['sub-', num2str(subject), '_cleaned_with_ICA.set'];
        set_filepath = fullfile(cfg.singleSubj, ...
            ['sub-', num2str(subject)]);

        if ~exist(fullfile(set_filepath, set_filename), 'file')
            error('run_multimodal_trials:NoCleanedSet', ...
                ['sub-%d has no cleaned dataset yet:\n  %s\n' ...
                 'Run run_preprocessing.m for this participant first.'], ...
                subject, fullfile(set_filepath, set_filename));
        end

        EEG = pop_loadset('filename', set_filename, 'filepath', set_filepath);

        % Load the curated flexion/extension events. They come from two
        % interactive apps and are shipped as derived data, so the study
        % folder is checked first and the repository second.
        encoder_file = resolve_derived_file('6_0_Trials_Info_and_Events', ...
            subject, ['sub-', num2str(subject), '_Trials_encoder_events.mat'], ...
            cfg.raw);

        if isempty(encoder_file)
            error('run_multimodal_trials:NoEncoderEvents', ...
                ['sub-%d has no curated encoder events, in the study folder ' ...
                 'or in the repository derived data folder. Copy ' ...
                 'sub-%d_Trials_encoder_events.mat into one of them, or run ' ...
                 'run_preprocessing.m for this participant with ' ...
                 'rebuild_events = true. See README.'], subject, subject);
        end

        loaded = load(encoder_file);
        Trials_encoder_events = loaded.Trials_encoder_events;

        % Build the per-trial description: condition, scores, and the
        % boundaries of each trial in every stream.
        Trials_Info = build_trial_info(output, EEG, ...
            Trials_encoder_events, subject, data_path, sessions_trial_id);

        % Cut EEG, EMG and the experiment stream into epochs using it.
        extract_epochs(output, EEG, Trials_Info, EMG_sensor_id, ...
            subject, data_path, epoch_basis);

    catch err
        % One broken participant should not end a batch that runs overnight.
        failed{end+1} = struct('subject', subject, 'error', err); %#ok<SAGROW>
        warning('run_multimodal_trials:SubjectFailed', ...
            'Subject %d failed: %s', subject, err.message);
        fprintf('%s\n', getReport(err, 'extended', 'hyperlinks', 'off'));
    end

end


%% Summary
fprintf('\nRequested subjects: %s\n', mat2str(subjects));
if isempty(failed)
    disp('MULTIMODAL TRIAL EXTRACTION DONE, all requested subjects completed.');
else
    fprintf('%d subject(s) failed:\n', numel(failed));
    for k = 1:numel(failed)
        fprintf('  sub-%d: %s\n', failed{k}.subject, failed{k}.error.message);
    end
end