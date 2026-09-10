function out = concatenate_runs(subject_id, rawdata_path)
% RUNS_CONCATENATED  Load and concatenate the EEG, EMG and experiment
% streams of all sessions of one participant.
%
%   out = concatenate_runs(subject_id, rawdata_path)
%
% Runs without any user interaction. The two places that used to ask a human
% a question are now driven by tables that ship with the code:
%   - which XDF files to load, and in which order, is decided in
%     load_xdf_sessions from the recording timestamps
%   - which EMG sensors replaced which is looked up in
%     emg_sensor_replacement

    %% Load XDF files (it takes a while to load all the streams!)
    fprintf('Loading raw XDF data of sub-%d\n', subject_id);
    streams = load_xdf_sessions(subject_id, rawdata_path);

    %% Concatenating Signals
    % Identify the indeces for EEG, EMG, and Encoder(Exp_data) signals
    EEG_indx = [];
    EMG_indx = [];
    Exp_indx = [];

    for i = 1:length(streams)
        for j = 1:4 % 4: EEG_trigger_markers, EEG, EMG, Matlabl_signals
            type = streams{1, i}(j).dataset.info.type;
            if strcmp(type, 'EEG')
                EEG_indx = [EEG_indx, j]; %#ok<AGROW>
            end
            if strcmp(type, 'EMG')
                EMG_indx = [EMG_indx, j]; %#ok<AGROW>
            end
            if strcmp(type, 'Exp_data')
                Exp_indx = [Exp_indx, j]; %#ok<AGROW>
            end
        end
    end


    % Initialize cell arrays to store data
    temp_EEG      = cell(1, numel(EEG_indx));
    temp_EEG_time = cell(1, numel(EEG_indx));

    temp_EMG      = cell(1, numel(EMG_indx));
    temp_EMG_time = cell(1, numel(EMG_indx));

    temp_Exp      = cell(1, numel(Exp_indx));
    temp_Exp_time = cell(1, numel(Exp_indx));

    % Loop to collect data into cell arrays
    for i = 1:length(streams)
        temp_EEG{i} = streams{1, i}(EEG_indx(i)).dataset.time_series;
        temp_EEG_time{i} = streams{1, i}(EEG_indx(i)).dataset.time_stamps;

        temp_EMG{i} = streams{1, i}(EMG_indx(i)).dataset.time_series;
        temp_EMG_time{i} = streams{1, i}(EMG_indx(i)).dataset.time_stamps;

        temp_Exp{i} = streams{1, i}(Exp_indx(i)).dataset.time_series;
        temp_Exp_time{i} = streams{1, i}(Exp_indx(i)).dataset.time_stamps;
    end


    % Concatenate cell arrays into final arrays
    All_EEG      = double([temp_EEG{:}]);
    All_EEG_time = [temp_EEG_time{:}];


    %% EMG sensors that were replaced mid recording
    % A session whose EMG stream has a different number of rows than the
    % first session was recorded with replacement sensors. Which sensor
    % replaced which is a property of that recording, so it is looked up
    % rather than typed in. An unlisted mismatch stops the run instead of
    % being silently ignored, because concatenating mismatched sessions
    % would either fail with an unhelpful error or, worse, line up the wrong
    % muscles.
    for i = 2:length(temp_EMG)
        if size(temp_EMG{1, i}, 1) ~= size(temp_EMG{1, 1}, 1)

            replacement = emg_sensor_replacement(subject_id, i);

            if isempty(replacement)
                error('concatenate_runs:UnknownEMGReplacement', ...
                    ['Session %d of sub-%d has %d EMG rows, session 1 has ' ...
                     '%d. That means sensors were replaced during the ' ...
                     'recording, but no substitution is listed for this ' ...
                     'participant.\nAdd an entry to ' ...
                     'emg_sensor_replacement.m of the form ' ...
                     '[new old; new old; ...].'], ...
                    i, subject_id, size(temp_EMG{1, i}, 1), ...
                    size(temp_EMG{1, 1}, 1));
            end

            fprintf(['  sub-%d session %d: EMG sensors %s replaced ' ...
                     'sensors %s\n'], subject_id, i, ...
                     mat2str(replacement(:, 1)'), ...
                     mat2str(replacement(:, 2)'));

            temp_EMG{1, i}(replacement(:, 2), :) = ...
                temp_EMG{1, i}(replacement(:, 1), :);
            temp_EMG{1, i}(replacement(:, 1), :) = [];

            if size(temp_EMG{1, i}, 1) ~= size(temp_EMG{1, 1}, 1)
                error('concatenate_runs:EMGStillMismatched', ...
                    ['After applying the substitution, session %d of ' ...
                     'sub-%d still has %d EMG rows against %d in session ' ...
                     '1. The entry in emg_sensor_replacement.m does not ' ...
                     'describe this recording.'], ...
                    i, subject_id, size(temp_EMG{1, i}, 1), ...
                    size(temp_EMG{1, 1}, 1));
            end

        end
    end

    All_EMG      = double([temp_EMG{:}]);
    All_EMG_time = [temp_EMG_time{:}];

    All_Exp      = double([temp_Exp{:}]);
    All_Exp_time = [temp_Exp_time{:}];


    out = struct('All_EEG', All_EEG, 'All_EEG_time', All_EEG_time, ...
        'All_EMG', All_EMG, 'All_EMG_time', All_EMG_time, ...
        'All_Exp', All_Exp, 'All_Exp_time', All_Exp_time);

end