function [EEG, removeindices] = add_events(EEG, output, ...
    subject_id, derived_folder, study_path, rebuild_events)
% MAIN_ADD_EVENTS  Put the experiment events into a participant's dataset
% and report which parts of the recording are outside the experiment.
%
%   [EEG, removeindices] = add_events(EEG, output, subject_id, ...
%                              derived_folder, study_path)
%   [EEG, removeindices] = add_events(..., rebuild_events)
%
% ------------------------------------------------------------------------
% READ THIS BEFORE YOU RUN ANYTHING
% ------------------------------------------------------------------------
% Everything this function computes ends up in one small tab separated text
% file per participant:
%
%   Events/sub-<N>/events_with_FlxExt.txt      type <tab> latency <tab> desc
%
% That file is published with this repository, in
% derived_data/Events/sub-<N>/. With the default rebuild_events = false the
% function simply imports it, works out the non-experimental segments from
% it, and returns. Nothing else runs: not the latency computation, not the
% raw stream concatenation, and above all not the two interactive apps. The
% output argument is not even looked at, so you may pass [].
%
% Set rebuild_events = true only if you are adding a participant that has
% never been processed. That path rebuilds the file from the raw streams and
% it will stop once and wait for a human:
%
%   detect_encoder_peaks           finds candidate encoder turning points,
%                                  automatic and deterministic
%   find_flexion_extension_events  the app where a person discards the false
%                                  detections. This is the manual step.
%
% Two people driving that app do not make the same selections, so running
% it again would not reproduce the published events. It is here so the
% procedure is auditable, not so that it can be repeated.
%
% ------------------------------------------------------------------------
% WHAT THE EVENTS ARE
% ------------------------------------------------------------------------
% Seven events mark every trial, in this order:
%
%   TS  Trial Start        one sample before the first marker of the trial
%   SB  Start Beep         first single beep
%   PC  Pressure Change    2 s from the start beep
%   SM  Start Move         second single beep, 2 s after the pressure change
%   FB  Finish Beep        double beep, 20 s after start move, stop moving
%   SP  Score Press        experimenter enters the participant's rating
%   TE  Trial End          one sample after the score press
%
% Four more events mark every movement cycle inside a trial:
%
%   FlxS FlxE              knee flexion start and end
%   ExtS ExtE              knee extension start and end
%
% The desc field carries the previous and current pressure level and the
% trial number, and for SP additionally the previous and current score.
%
% The timing of the first six event types changed after participant 9, so
% every latency computation below branches on subject_id > 9.
%
% ------------------------------------------------------------------------
% Note on the signature: an earlier version took eight inputs
%   (EEG, output, subject, subject_id, processing_path, input_filepath, ...
%    bemobil_config, study_path)
% Three were unused and one, subject against subject_id, was a second place
% where a participant number could be written down.
% Three were unused and one, subject against subject_id, was a second place
% where a participant number could be written down. They were removed on
% 01/04/2026 and run_preprocessing.m now passes a single participant number.

    if nargin < 6 || isempty(rebuild_events)
        rebuild_events = false;
    end


    %% Import the published event table and stop there
    if ~rebuild_events

        eventFile = resolve_derived_file('Events', subject_id, ...
            'events_with_FlxExt.txt', derived_folder);

        if isempty(eventFile)
            error('add_events:NoEventFile', ...
                ['sub-%d has no event table.\nLooked in\n' ...
                 '  %s\nand in the repository derived data folder.\n\n' ...
                 'This file is published with the repository because ' ...
                 'rebuilding it needs the raw recordings and two ' ...
                 'interactive apps. Copy events_with_FlxExt.txt into ' ...
                 'either location, or set rebuild_events = true to build ' ...
                 'it yourself. See README.'], ...
                subject_id, fullfile(derived_folder, 'Events', ...
                ['sub-', num2str(subject_id)]));
        end

        fprintf('Importing the published events of sub-%d:\n  %s\n', ...
            subject_id, eventFile);

        EEG = import_event_file(EEG, eventFile);
        removeindices = non_experimental_segments(EEG);
        return

    end


    %% Rebuild the event table from the raw streams
    % From here on the raw concatenated streams are needed and the two apps
    % will open.
    if isempty(output)
        error('add_events:NoRawStreams', ...
            ['rebuild_events is true, so the raw concatenated streams are ' ...
             'needed. Pass the output of concatenate_runs instead of [].']);
    end

    if subject_id > 9
        idx = 2;
    else
        idx = 1;
    end

    All_Experiment = output.All_Exp;
    All_Experiment_time = output.All_Exp_time;
    All_EEG_time = output.All_EEG_time;

    %% Compute the latency of the six trial markers
    % Every branch below exists because the trigger scheme changed after
    % participant 9.

    if subject_id > 9
        % start_beep event (first single beep)
        start_beep = find(diff(All_Experiment(6, :)) == 1);
        start_beep = reshape(start_beep, 2, []);
        start_beep_time_Expdata = All_Experiment_time(start_beep(1,:));
        start_beep_indx_EEG = ...
            knnsearch(All_EEG_time', start_beep_time_Expdata');
        start_beep_latency_EEG = EEG.times(start_beep_indx_EEG); % time unit: milisecond
    else
        % start_beep event (first single beep)
        start_beep = find(diff(All_Experiment(6, :)) == 1);
        start_beep_time_Expdata = All_Experiment_time(start_beep(1,:));
        start_beep_indx_EEG = ...
            knnsearch(All_EEG_time', start_beep_time_Expdata');
        start_beep_latency_EEG = EEG.times(start_beep_indx_EEG); % time unit: milisecond
    end


    if subject_id > 9
        % pressure_change event (2s after first single beep)
        pressure_change_time_Expdata = All_Experiment_time(start_beep(1,:)) + 2;
        pressure_change_indx_EEG = ...
            knnsearch(All_EEG_time', pressure_change_time_Expdata');
        pressure_change_latency_EEG = EEG.times(pressure_change_indx_EEG); % time unit: milisecond
    else
        % pressure_change event (2s before single beep)
        pressure_change_time_Expdata = All_Experiment_time(start_beep(1,:)) - 2;
        pressure_change_indx_EEG = ...
            knnsearch(All_EEG_time', pressure_change_time_Expdata');
        pressure_change_latency_EEG = EEG.times(pressure_change_indx_EEG); % time unit: milisecond
    end


    if subject_id > 9
        % start_move event (second single beep, 2s after pressure change)
        start_move = find(diff(All_Experiment(6, :)) == 1);
        start_move = reshape(start_move, 2, []);
        start_move_time_Expdata = All_Experiment_time(start_move(2,:));
        start_move_indx_EEG = ...
            knnsearch(All_EEG_time', start_move_time_Expdata');
        start_move_latency_EEG = EEG.times(start_move_indx_EEG); % time unit: milisecond
    else
        % start_move event (second single beep, 2s after pressure change)
        start_move = find(diff(All_Experiment(6, :)) == 1);
        start_move_time_Expdata = All_Experiment_time(start_move(1,:));
        start_move_indx_EEG = ...
            knnsearch(All_EEG_time', start_move_time_Expdata');
        start_move_latency_EEG = EEG.times(start_move_indx_EEG); % time unit: milisecond
    end


    if subject_id > 9
        % finish_beep event (20s after start_move event, double beep to stop movement)
        finish_beep = find(diff(All_Experiment(6, :)) == -2);
        finish_beep_time_Expdata = All_Experiment_time(finish_beep);
        finish_beep_indx_EEG = ...
            knnsearch(All_EEG_time', finish_beep_time_Expdata');
        finish_beep_latency_EEG = EEG.times(finish_beep_indx_EEG); % time unit: milisecond
    else
        % finish_beep event (20s after start_move event, double beep to stop movement)
        finish_beep = find(diff(All_Experiment(6, :)) == -1);
        finish_beep_time_Expdata = All_Experiment_time(finish_beep);
        finish_beep_indx_EEG = ...
            knnsearch(All_EEG_time', finish_beep_time_Expdata');
        finish_beep_latency_EEG = EEG.times(finish_beep_indx_EEG); % time unit: milisecond
    end


    if subject_id > 9
        % score_press event (experimenter presses the scores immidiately after subjects evaluate the task)
        score_press = find(diff(All_Experiment(7, :)) > 0);
        score_press_time_Expdata = All_Experiment_time(score_press);
        score_press_indx_EEG = ...
            knnsearch(All_EEG_time', score_press_time_Expdata');
        score_press_latency_EEG = EEG.times(score_press_indx_EEG); % time unit: milisecond
    else
        score_press = find(diff(All_Experiment(6, :)) == -1) + 1;
        score_press_time_Expdata = All_Experiment_time(score_press);
        score_press_indx_EEG = ...
            knnsearch(All_EEG_time', score_press_time_Expdata');
        score_press_latency_EEG = EEG.times(score_press_indx_EEG) + 2; % time unit: milisecond
    end


    %% Trial descriptions
    % Protocol variations per participant, in one table instead of a chain
    % of ifs that left the variables undefined for the participants that
    % were not listed.
    [no_PAM_trials, familiarization_trials] = trial_protocol(subject_id);

    % Import Trials information
    Trials = cell(1, size(start_beep,2));
    for i = 1:numel(Trials)
        if ismember(i, no_PAM_trials)
            Trials{1, i}.Description = 'No_PAM';
        elseif ismember(i, familiarization_trials)
            Trials{1, i}.Description = 'Familiarizattion';
        else
            Trials{1, i}.Description = 'Experiment';
        end
        Trials{1, i}.Pressure = All_Experiment(3, start_beep(idx, i));
        if i ~= numel(Trials)
            Trials{1, i}.Score = All_Experiment(4, start_beep(idx, i+1));
        else
            Trials{1, i}.Score = All_Experiment(4, end);
        end
    end


    % make events description
    desc1 = cell(1, numel(pressure_change_latency_EEG)); % {P(i-1), P(i), Trial}
    for i = 1:length(desc1)
        if i~=1
            desc1{1, i} = {Trials{1, i-1}.Pressure, Trials{1, i}.Pressure, i};
        else
            indx_temp = knnsearch(All_Experiment_time', pressure_change_time_Expdata(1) - 1);
            desc1{1, 1} = {All_Experiment(3, indx_temp), Trials{1, i}.Pressure, i};
        end
    end


    % Add start beep events
    type = repmat({'SB_Start_Beep'}, 1, size(start_beep,2));
    latency = start_beep_latency_EEG;
    desc = desc1;

    % Add pressure change events
    type = cat(2, type, repmat({'PC_Pressure_Change'}, 1, numel(pressure_change_latency_EEG)));
    latency = cat(2, latency, pressure_change_latency_EEG);
    desc = cat(2, desc, desc1);

    % Add start move events
    type = cat(2, type, repmat({'SM_Start_Move'}, 1, size(start_beep,2)));
    latency = cat(2, latency, start_move_latency_EEG);
    desc = cat(2, desc, desc1);

    % Add finish beep events
    type = cat(2, type, repmat({'FB_Finish_Beep'}, 1, numel(finish_beep)));
    latency = cat(2, latency, finish_beep_latency_EEG);
    desc = cat(2, desc, desc1);

    % New description including the scores of current and previous trials
    desc2 = cell(1, numel(score_press_latency_EEG)); % {P(i-1), P(i), Trial}
    for i = 1:length(desc2)
        if i~=1
            desc2{1, i} = {Trials{1, i-1}.Pressure, Trials{1, i}.Pressure, Trials{1, i-1}.Score, Trials{1, i}.Score, i};
        else
            indx_temp = knnsearch(All_Experiment_time', pressure_change_time_Expdata(1) - 1);
            desc2{1, 1} = {All_Experiment(3, indx_temp), Trials{1, i}.Pressure, All_Experiment(4, indx_temp), Trials{1, i}.Score, i};
        end
    end

    % Add score press events
    type = cat(2, type, repmat({'SP_Score_Press'}, 1, numel(score_press_latency_EEG)));
    latency = cat(2, latency, score_press_latency_EEG);
    desc = cat(2, desc, desc2);

    if subject_id > 9
        % Add Trial Start events
        type = cat(2, type, repmat({'TS_Trial_Start'}, 1, numel(start_beep_latency_EEG)));
        latency = cat(2, latency, start_beep_latency_EEG - 2); % 2ms before (one sample)
        desc = cat(2, desc, desc1);
    else
        % Add Trial Start events
        type = cat(2, type, repmat({'TS_Trial_Start'}, 1, numel(pressure_change_latency_EEG)));
        latency = cat(2, latency, pressure_change_latency_EEG - 2); % 2ms before (one sample)
        desc = cat(2, desc, desc1);
    end

    % Add Trial End events
    type = cat(2, type, repmat({'TE_Trial_End'}, 1, numel(score_press_latency_EEG)));
    latency = cat(2, latency, score_press_latency_EEG + 2); % 2ms after (one sample)
    desc = cat(2, desc, desc1);


    %% Write events_basic.txt
    % The seven trial markers only. The flexion and extension events are
    % appended to a copy of this file further down.

    folder = fullfile(derived_folder, 'Events', ['sub-', num2str(subject_id)]);

    % Ensure the folder exists, if not, create it
    if ~exist(folder, 'dir')
        mkdir(folder);
    end

    % File name
    filename = fullfile(folder, 'events_basic.txt');

    % Open the file for writing
    fileID = fopen(filename, 'w');

    % Check if the file was opened successfully
    if fileID == -1
        error('Cannot open file for writing: %s', filename);
    end

    % Write the header
    fprintf(fileID, 'type\tlatency\tdesc\n');

    % Write the data
    for i = 1:numel(type)
        % Convert the nested cell array in desc to a string with underline separator
        desc_str = strjoin(cellfun(@num2str, desc{i}, 'UniformOutput', false), '_');
        fprintf(fileID, '%s\t%d\t%s\n', type{i}, latency(i), desc_str);
    end

    % Close the file
    fclose(fileID);

    % Notify the user
    fprintf('File saved successfully: \n%s\n', filename);


    %% Flexion and extension events
    % Important note: the flexion and extension events must be added before
    % the non-experimental segments are rejected, because their latencies
    % refer to the uncut recording.
    %
    % These are the two manual steps. See the header of this file.

    encoder_folder = fullfile(study_path, '6_0_Trials_Info_and_Events', ...
        ['sub-', num2str(subject_id)]);
    encoder_file = fullfile(encoder_folder, ...
        ['sub-', num2str(subject_id), '_Trials_encoder_events.mat']);

    if ~exist(encoder_folder, 'dir')
        mkdir(encoder_folder);
    end

    % Use the peak selection app to find the flexion and extension start
    % events.
    output_peaks = detect_encoder_peaks(output, subject_id);

    start_beep_row = start_beep(1, :);
    if subject_id > 9
        start_move_row = start_move(2, :);
    else
        start_move_row = start_beep_row;
    end
    XLimits = output_peaks.XLimits;

    trial_pks_high_peaks  = output_peaks.trial_pks_high_peaks;
    trial_locs_high_peaks = output_peaks.trial_locs_high_peaks;

    trial_pks_low_peaks  = output_peaks.trial_pks_low_peaks;
    trial_locs_low_peaks = output_peaks.trial_locs_low_peaks;

    Trials_encoder_events = output_peaks.Trials_encoder_events;

    for i = 1:numel(Trials_encoder_events)
        Trials_encoder_events{1, i}.Description = Trials{1, i}.Description;
        Trials_encoder_events{1, i}.Pressure    = Trials{1, i}.Pressure;
        Trials_encoder_events{1, i}.Score       = Trials{1, i}.Score;
    end

    % Run the app that discards the peaks the detector got wrong. It writes
    % Trials_encoder_events.mat itself.
    app = find_flexion_extension_events;
    app.initializeApp(subject_id, All_Experiment_time, ...
                      All_Experiment, start_beep_row, ...
                      pressure_change_time_Expdata, start_move_row, ...
                      finish_beep, score_press_time_Expdata, ...
                      XLimits, trial_pks_high_peaks, trial_locs_high_peaks, ...
                      trial_pks_low_peaks, trial_locs_low_peaks, ...
                      Trials_encoder_events);

    % Wait for the app to close
    waitfor(app.UIFigure);

    if ~exist(encoder_file, 'file')
        error('add_events:NoEncoderEvents', ...
            ['The flexion and extension editor closed without writing\n' ...
             '  %s\nNothing downstream can be built without that file.'], ...
            encoder_file);
    end

    loaded = load(encoder_file);
    Trials_encoder_events = loaded.Trials_encoder_events;


    %% Turn the curated peaks into flexion and extension indexes
    % Indexes refer to the experiment stream, not to the EEG.
    %
    % Cases 1 and 2 delete the first low peak, so this must not run twice on
    % the same file. A file that already carries Flexion_Start has been
    % through it.
    already_derived = ~isempty(Trials_encoder_events) && ...
        isfield(Trials_encoder_events{1, 1}, 'Flexion_Start');

    if already_derived

        disp('Flexion and extension indexes are already derived, keeping them.');

    else

        for i = 1:length(Trials_encoder_events)
            if length(Trials_encoder_events{1, i}.high_peaks.index) > 1
                if Trials_encoder_events{1, i}.high_peaks.index(1) > ...
                        Trials_encoder_events{1, i}.low_peaks.index(1)
                    flag1 = 1;
                else
                    flag1 = 0;
                end

                if Trials_encoder_events{1, i}.high_peaks.index(end) > ...
                        Trials_encoder_events{1, i}.low_peaks.index(end)
                    flag2 = 1;
                else
                    flag2 = 0;
                end


                if flag1 == 1 && flag2 == 1 % case 1 - should not happen!

                    Trials_encoder_events{1, i}.Case = 1;

                    Trials_encoder_events{1, i}.low_peaks.index(1) = [];
                    Trials_encoder_events{1, i}.low_peaks.time(1) = [];
                    Trials_encoder_events{1, i}.low_peaks.value(1) = [];

                    Trials_encoder_events{1, i}.Flexion_Start = Trials_encoder_events{1, i}.high_peaks.index(1:end-1);
                    Trials_encoder_events{1, i}.Flexion_End   = Trials_encoder_events{1, i}.low_peaks.index;

                    Trials_encoder_events{1, i}.Extension_Start = Trials_encoder_events{1, i}.low_peaks.index;
                    Trials_encoder_events{1, i}.Extension_End   = Trials_encoder_events{1, i}.high_peaks.index(2:end);

                elseif flag1 == 1 && flag2 == 0 % case 2 - should not happen!

                    Trials_encoder_events{1, i}.Case = 2;

                    Trials_encoder_events{1, i}.low_peaks.index(1) = [];
                    Trials_encoder_events{1, i}.low_peaks.time(1) = [];
                    Trials_encoder_events{1, i}.low_peaks.value(1) = [];

                    Trials_encoder_events{1, i}.Flexion_Start = Trials_encoder_events{1, i}.high_peaks.index;
                    Trials_encoder_events{1, i}.Flexion_End   = Trials_encoder_events{1, i}.low_peaks.index;

                    Trials_encoder_events{1, i}.Extension_Start = Trials_encoder_events{1, i}.low_peaks.index(1:end-1);
                    Trials_encoder_events{1, i}.Extension_End   = Trials_encoder_events{1, i}.high_peaks.index(2:end);

                elseif flag1 == 0 && flag2 == 1 % case 3

                    Trials_encoder_events{1, i}.Case = 3;

                    Trials_encoder_events{1, i}.Flexion_Start = Trials_encoder_events{1, i}.high_peaks.index(1:end-1);
                    Trials_encoder_events{1, i}.Flexion_End   = Trials_encoder_events{1, i}.low_peaks.index;

                    Trials_encoder_events{1, i}.Extension_Start = Trials_encoder_events{1, i}.low_peaks.index;
                    Trials_encoder_events{1, i}.Extension_End   = Trials_encoder_events{1, i}.high_peaks.index(2:end);


                elseif flag1 == 0 && flag2 == 0 % case 4

                    Trials_encoder_events{1, i}.Case = 4;

                    Trials_encoder_events{1, i}.Flexion_Start = Trials_encoder_events{1, i}.high_peaks.index;
                    Trials_encoder_events{1, i}.Flexion_End   = Trials_encoder_events{1, i}.low_peaks.index;

                    Trials_encoder_events{1, i}.Extension_Start = Trials_encoder_events{1, i}.low_peaks.index(1:end-1);
                    Trials_encoder_events{1, i}.Extension_End   = Trials_encoder_events{1, i}.high_peaks.index(2:end);

                end
            end
        end

        save(encoder_file, 'Trials_encoder_events', '-v7.3')

    end


    %% Append the flexion and extension events to the text file
    n_trials = length(Trials_encoder_events);
    event_types = {'FlxS', 'FlxE', 'ExtS', 'ExtE'};
    event_fields = {'Flexion_Start', 'Flexion_End', 'Extension_Start', 'Extension_End'};

    % Pre-calculate total number of events to preallocate arrays
    total_events = 0;
    for i = 1:n_trials
        for j = 1:numel(event_fields)
            if isfield(Trials_encoder_events{1, i}, event_fields{j})
                total_events = total_events + numel(Trials_encoder_events{1, i}.(event_fields{j}));
            end
        end
    end

    % Preallocate arrays for efficiency
    all_event_times_Expdata = zeros(total_events, 1);
    all_event_labels = cell(total_events, 1);
    all_descs = cell(total_events, 1);
    trial_indices = zeros(total_events, 1);

    idx = 1;
    for i = 1:n_trials
        for j = 1:numel(event_fields)
            event_field = event_fields{j};
            event_label = event_types{j};

            if ~isfield(Trials_encoder_events{1, i}, event_field)
                continue
            end

            event_times = All_Experiment_time(Trials_encoder_events{1, i}.(event_field));
            n_events = numel(event_times);

            if n_events > 0
                range = idx:(idx + n_events - 1);
                all_event_times_Expdata(range) = event_times';
                all_event_labels(range) = repmat({event_label}, n_events, 1);
                all_descs(range) = repmat({desc1{1, i}}, n_events, 1);
                trial_indices(range) = i;
                idx = idx + n_events;
            end
        end
    end

    % Trim arrays to actual number of events
    all_event_times_Expdata = all_event_times_Expdata(1:idx-1);
    all_event_labels = all_event_labels(1:idx-1);
    all_descs = all_descs(1:idx-1);

    % Map event times to EEG indices using interp1 for efficiency
    all_event_indx_EEG = interp1(All_EEG_time, 1:length(All_EEG_time), ...
        all_event_times_Expdata, 'nearest', 'extrap');
    all_event_latency_EEG = EEG.times(all_event_indx_EEG);

    % Define the file paths
    original_filename = fullfile(folder, 'events_basic.txt');
    new_filename      = fullfile(folder, 'events_with_FlxExt.txt');

    % Read the existing content of the original file
    existing_lines = {};
    fid = fopen(original_filename, 'r');
    if fid ~= -1
        while ~feof(fid)
            line = fgetl(fid);
            existing_lines{end + 1} = line; %#ok<SAGROW> % Add each line to the cell array
        end
        fclose(fid);
    else
        error('Failed to open the original file for reading.');
    end

    event_labels  = all_event_labels;
    event_latency = all_event_latency_EEG';
    event_descs   = all_descs;

    % Process event_descs to create a cell array of strings
    event_descs_str = cell(size(event_descs));
    for i = 1:length(event_descs)
        desc_numbers = event_descs{i};
        desc_strings = cellfun(@num2str, desc_numbers, 'UniformOutput', false);
        event_descs_str{i} = strjoin(desc_strings, '_');
    end

    % Append the new lines to the existing lines
    for i = 1:length(event_latency)
        new_line = sprintf('%s\t%f\t%s', event_labels{i}, event_latency(i), event_descs_str{i});
        existing_lines{end + 1} = new_line; %#ok<SAGROW>
    end

    % Write the combined content to a new file
    fid = fopen(new_filename, 'w');
    if fid == -1
        error('Failed to open the new file for writing.');
    end

    for i = 1:length(existing_lines)
        fprintf(fid, '%s\n', existing_lines{i});
    end

    fclose(fid);

    fprintf(['File saved successfully: \n%s\n' ...
             'This is the file to publish as derived data. Everything ' ...
             'above this line exists only to produce it.\n'], new_filename);


    %% Import the rebuilt table
    EEG = import_event_file(EEG, new_filename);
    removeindices = non_experimental_segments(EEG);

end


% ------------------------------------------------------------------------
function EEG = import_event_file(EEG, filename)
% Read a tab separated event table into the dataset, replacing whatever
% events were there. Latencies in the file are in milliseconds.

    [EEG, ~] = pop_importevent(EEG, 'event', filename, ...
        'fields', {'type', 'latency', 'desc'}, ...
        'append', 'no', 'align', NaN, 'skipline', 1, 'timeunit', 1E-3);

end


% ------------------------------------------------------------------------
function removeindices = non_experimental_segments(EEG)
% Sample ranges that lie outside the experiment: before the first trial,
% between the end of one trial and the start of the next, and after the last
% trial. Removing them is strongly recommended, because they can contain
% strong artifacts that confuse channel detection and AMICA.
%
% This used to index the event list arithmetically, as EEG.event(7*i) and
% EEG.event(7*i+1), which held only while the list contained exactly the
% seven trial markers and nothing else. Pairing the events by type gives the
% same latencies and also works once the flexion and extension events are in
% the list, which is what lets the published event table be imported in one
% step.

    ts = find(strcmp({EEG.event.type}, 'TS_Trial_Start'));
    te = find(strcmp({EEG.event.type}, 'TE_Trial_End'));

    if isempty(ts) || isempty(te)
        error('add_events:NoTrialMarkers', ...
            ['The event list carries no TS_Trial_Start or no TE_Trial_End ' ...
             'events, so the non-experimental segments cannot be found.']);
    end

    if numel(ts) ~= numel(te)
        error('add_events:UnbalancedTrialMarkers', ...
            ['%d TS_Trial_Start events against %d TE_Trial_End events. ' ...
             'The event table is inconsistent.'], numel(ts), numel(te));
    end

    nTrials = numel(ts);
    removeindices = zeros(nTrials + 1, 2);

    % From the start of the recording to the first event.
    removeindices(1, :) = [0, EEG.event(1).latency - 1];

    % Between trials. Add more rows here for pauses or interruptions of the
    % experiment if they have markers or you know their indices in the data.
    for i = 1:nTrials - 1
        removeindices(i + 1, :) = [EEG.event(te(i)).latency + 1, ...
                                   EEG.event(ts(i + 1)).latency - 1];
    end

    % From the last event to the end of the recording.
    removeindices(end, :) = [EEG.event(end).latency + 1, EEG.pnts];

end


% ------------------------------------------------------------------------
function [no_PAM_trials, familiarization_trials] = trial_protocol(subject_id)
% Trials that were recorded without PAM assistance, and the familiarization
% trials, per participant. Both are trial indices into the trial sequence of
% that participant.
%
% Before 01/04/2026 these two variables were assigned only for
% subject_id == 13 and subject_id < 10, so every other participant hit an
% undefined variable a few lines later. They are listed explicitly here so
% that a missing entry is visible rather than fatal.

    no_PAM_trials          = [];
    familiarization_trials = [];

    switch subject_id
        case num2cell(1:9)
            % Protocol before the change: no no-PAM and no familiarization
            % trials were recorded.
            no_PAM_trials          = [];
            familiarization_trials = [];

        case 13
            no_PAM_trials = [1:3, 40:42, 43:45, 76:78, 79:81, ...
                             112:114, 115:117, 148:150];
            familiarization_trials = 4:9;

        otherwise
            % TODO: fill in the trial indices for this participant. Until
            % then every trial is labelled 'Experiment', which is only
            % correct if this participant really had no no-PAM and no
            % familiarization trials.
            warning('add_events:NoProtocolEntry', ...
                ['No no-PAM / familiarization trial list is recorded for ' ...
                 'sub-%d. Every trial will be labelled ''Experiment''. ' ...
                 'Add an entry in trial_protocol() if that is wrong.'], ...
                subject_id);
    end
end