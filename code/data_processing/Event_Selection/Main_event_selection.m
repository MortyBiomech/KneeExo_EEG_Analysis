function Trials_Info = Main_event_selection(input_streams, ...
                                            EEG, ...
                                            Trials_encoder_events, ...
                                            subject_id, ...
                                            data_path, ...
                                            sessions_trial_id)


    %% Extract data
    All_EEG_time = input_streams.All_EEG_time;
    All_EMG_time = input_streams.All_EMG_time;
    All_Experiment = input_streams.All_Exp;
    All_Experiment_time = input_streams.All_Exp_time;

    
    %% Extract events on Experiment streams & All_EEG stream (raw EEG data)

    if subject_id > 9
        idx = 2;
    else
        idx = 1;
    end

    if subject_id > 9
        % start_beep event (first single beep)
        start_beep = find(diff(All_Experiment(6, :)) == 1);
        start_beep = reshape(start_beep, 2, []);
        start_beep_time_Expdata = All_Experiment_time(start_beep(1,:));
        start_beep_indx_All_EEG = ...
            knnsearch(All_EEG_time', start_beep_time_Expdata');
    else
        % start_beep event (first single beep)
        start_beep = find(diff(All_Experiment(6, :)) == 1);
        start_beep_time_Expdata = All_Experiment_time(start_beep(1,:));
        start_beep_indx_All_EEG = ...
            knnsearch(All_EEG_time', start_beep_time_Expdata');
    end
    

    % % start_beep event (first single beep)
    % start_beep = find(diff(All_Experiment(6, :)) == 1);
    % start_beep = reshape(start_beep, 2, []);
    % start_beep_time_Expdata = All_Experiment_time(start_beep(1,:));
    % start_beep_indx_All_EEG = ...
    %     interp1(All_EEG_time, 1:length(All_EEG_time), start_beep_time_Expdata', 'nearest', 'extrap');
    %     % knnsearch(All_EEG_time', start_beep_time_Expdata');




    if subject_id > 9
        % pressure_change event (2s after first single beep)
        pressure_change_time_Expdata = All_Experiment_time(start_beep(1,:)) + 2;
        pressure_change_indx_All_EEG = ...
            knnsearch(All_EEG_time', pressure_change_time_Expdata');
    else
        % pressure_change event (2s before single beep)
        pressure_change_time_Expdata = All_Experiment_time(start_beep(1,:)) - 2;
        pressure_change_indx_All_EEG = ...
            knnsearch(All_EEG_time', pressure_change_time_Expdata');
    end

    % % pressure_change event (2s after first single beep)
    % pressure_change_time_Expdata = All_Experiment_time(start_beep(1,:)) + 2;
    % pressure_change_indx_All_EEG = ...
    %     knnsearch(All_EEG_time', pressure_change_time_Expdata');




    if subject_id > 9
        % start_move event (second single beep, 2s after pressure change)
        start_move = find(diff(All_Experiment(6, :)) == 1);
        start_move = reshape(start_move, 2, []);
        start_move_time_Expdata = All_Experiment_time(start_move(2,:));
        start_move_indx_All_EEG = ...
            knnsearch(All_EEG_time', start_move_time_Expdata');
    else
        % start_move event (second single beep, 2s after pressure change)
        start_move = find(diff(All_Experiment(6, :)) == 1);
        start_move_time_Expdata = All_Experiment_time(start_move(1,:));
        start_move_indx_All_EEG = ...
            knnsearch(All_EEG_time', start_move_time_Expdata');
    end

    % % start_move event (second single beep, 2s after pressure change)
    % start_move = find(diff(All_Experiment(6, :)) == 1);
    % start_move = reshape(start_move, 2, []);
    % start_move_time_Expdata = All_Experiment_time(start_move(2,:));
    % start_move_indx_All_EEG = ...
    %     knnsearch(All_EEG_time', start_move_time_Expdata');
    



    if subject_id > 9
        % finish_beep event (20s after start_move event, double beep to stop movement)
        finish_beep = find(diff(All_Experiment(6, :)) == -2);
        finish_beep_time_Expdata = All_Experiment_time(finish_beep);
        finish_beep_indx_All_EEG = ...
            knnsearch(All_EEG_time', finish_beep_time_Expdata');
    else
        % finish_beep event (20s after start_move event, double beep to stop movement)
        finish_beep = find(diff(All_Experiment(6, :)) == -1);
        finish_beep_time_Expdata = All_Experiment_time(finish_beep);
        finish_beep_indx_All_EEG = ...
            knnsearch(All_EEG_time', finish_beep_time_Expdata');
    end

    % % finish_beep event (20s after start_move event, double beep to stop movement)
    % finish_beep = find(diff(All_Experiment(6, :)) == -2);
    % finish_beep_time_Expdata = All_Experiment_time(finish_beep);
    % finish_beep_indx_All_EEG = ...
    %     knnsearch(All_EEG_time', finish_beep_time_Expdata');
    



    if subject_id > 9
        % score_press event (experimenter presses the scores immidiately after subjects evaluate the task)
        score_press = find(diff(All_Experiment(7, :)) > 0);
        score_press_time_Expdata = All_Experiment_time(score_press);
        score_press_indx_All_EEG = ...
            knnsearch(All_EEG_time', score_press_time_Expdata');
    else
        score_press = find(diff(All_Experiment(6, :)) == -1) + 1;
        score_press_time_Expdata = All_Experiment_time(score_press);
        score_press_indx_All_EEG = ...
            knnsearch(All_EEG_time', score_press_time_Expdata');
    end

    % % score_press event (experimenter presses the scores immidiately after subjects evaluate the task)
    % score_press = find(diff(All_Experiment(7, :)) > 0);
    % score_press_time_Expdata = All_Experiment_time(score_press);
    % score_press_indx_All_EEG = ...
    %     knnsearch(All_EEG_time', score_press_time_Expdata');


    
    %% Removing trials which have empty high or low peaks (due to mistake in peak selction!)
    empty_trial_peak_indx = [];
    for i = 1:length(Trials_encoder_events)
        if isempty(Trials_encoder_events{1, i}.high_peaks) || ...
            isempty(Trials_encoder_events{1, i}.low_peaks)
            empty_trial_peak_indx = cat(2, empty_trial_peak_indx, i);
        end
    end
    if ~isempty(empty_trial_peak_indx)
        Trials_encoder_events(empty_trial_peak_indx) = [];
    end
    
    
    %% Initialize the structure template
    structTemplate = ...
        struct('Trial_start_indx', [], ...
               'Trial_end_indx', [], ...
               'Pressure_Change_indx', [], ...
               'Movement_start_indx', [], ...
               'Movement_end_indx', [], ...
               'flexion_start_indx', [], ...
               'flexion_end_indx', [], ...
               'extension_start_indx', [], ...
               'extension_end_indx', [], ...
               'flextoflex_start_indx', [], ...
               'flextoflex_end_indx', []);
    
    events_on_eeg = struct('Raw', structTemplate, ...
        'Preprocessed', structTemplate);
    
    general_info = struct('Description', [], 'Session', [], ...
        'Pressure', [], 'Score', [], 'Case', []);
    
    epochs_events = struct('EEG_stream', events_on_eeg, ...
        'EMG_stream', structTemplate, 'EXP_stream', structTemplate);
    
    final_events_structTemplate = struct('General', general_info, ...
        'Events', epochs_events);
    
    % Create a cell array of size 1xN_trials to store events on all streams
    Trials_Info = repmat({final_events_structTemplate}, ...
        1, length(Trials_encoder_events));


    %% Filling the "General" field
    for i = 1:length(Trials_Info)

        Trials_Info{1, i}.General.Description = Trials_encoder_events{1, i}.Description;
        Trials_Info{1, i}.General.Pressure = Trials_encoder_events{1, i}.Pressure;
        Trials_Info{1, i}.General.Score = Trials_encoder_events{1, i}.Score;
        Trials_Info{1, i}.General.Case = Trials_encoder_events{1, i}.Case;

        if i <= sessions_trial_id(1)
            Trials_Info{1, i}.General.Session = 1;
        elseif (sessions_trial_id(1) < i) && (i <= sessions_trial_id(2))
            Trials_Info{1, i}.General.Session = 2;
        elseif (sessions_trial_id(2) < i) && (i <= sessions_trial_id(3))
            Trials_Info{1, i}.General.Session = 3;
        else
            Trials_Info{1, i}.General.Session = 4;
        end

    end

    
    %% Filling the "Events.EEG_stream.Raw" field (indeces on All_EEG stream)
    parfor i = 1:length(Trials_Info)

        % Trial start & end
        Trials_Info{1, i}.Events.EEG_stream.Raw.Trial_start_indx = ...
            start_beep_indx_All_EEG(i);
        Trials_Info{1, i}.Events.EEG_stream.Raw.Trial_end_indx = ...
            score_press_indx_All_EEG(i);

        % Pressure Change
        Trials_Info{1, i}.Events.EEG_stream.Raw.Pressure_Change_indx = ...
            pressure_change_indx_All_EEG(i);

        % Movement start & end
        Trials_Info{1, i}.Events.EEG_stream.Raw.Movement_start_indx = ...
            start_move_indx_All_EEG(i);
        Trials_Info{1, i}.Events.EEG_stream.Raw.Movement_end_indx = ...
            finish_beep_indx_All_EEG(i);

        % flexion start & end
        Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Flexion_Start);
        Trials_Info{1, i}.Events.EEG_stream.Raw.flexion_start_indx = ...
            interp1(All_EEG_time, 1:length(All_EEG_time), Exp_timing, 'nearest', 'extrap');

        Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Flexion_End);
        Trials_Info{1, i}.Events.EEG_stream.Raw.flexion_end_indx = ...
            interp1(All_EEG_time, 1:length(All_EEG_time), Exp_timing, 'nearest', 'extrap');

        % extension start & end
        Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Extension_Start);
        Trials_Info{1, i}.Events.EEG_stream.Raw.extension_start_indx = ...
            interp1(All_EEG_time, 1:length(All_EEG_time), Exp_timing, 'nearest', 'extrap');

        Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Extension_End);
        Trials_Info{1, i}.Events.EEG_stream.Raw.extension_end_indx = ...
            interp1(All_EEG_time, 1:length(All_EEG_time), Exp_timing, 'nearest', 'extrap');

        % flextoflex start & end
        if Trials_Info{1, i}.General.Case == 3
            Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Flexion_Start(1:end));
        elseif Trials_Info{1, i}.General.Case == 4
            Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Flexion_Start(1:end-1));
        end
        Trials_Info{1, i}.Events.EEG_stream.Raw.flextoflex_start_indx = ...
            interp1(All_EEG_time, 1:length(All_EEG_time), Exp_timing, 'nearest', 'extrap');

        Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Extension_End(1:end));
        Trials_Info{1, i}.Events.EEG_stream.Raw.flextoflex_end_indx = ...
            interp1(All_EEG_time, 1:length(All_EEG_time), Exp_timing, 'nearest', 'extrap');
        

    end
    

    %% Filling the "Events.EMG_stream" field 
    parfor i = 1:length(Trials_Info)
    
        % Trial start & end
        [~, Trials_Info{1, i}.Events.EMG_stream.Trial_start_indx] = ...
            min(abs(All_EMG_time - All_Experiment_time(start_beep(1, i))));
        [~, Trials_Info{1, i}.Events.EMG_stream.Trial_end_indx] = ...
            min(abs(All_EMG_time - All_Experiment_time(score_press(1, i))));

        % Pressure Change
        [~, Trials_Info{1, i}.Events.EMG_stream.Pressure_Change_indx] = ...
            min(abs(All_EMG_time - All_EEG_time(pressure_change_indx_All_EEG(i))));

        % Movement start & end
        [~, Trials_Info{1, i}.Events.EMG_stream.Movement_start_indx] = ...
            min(abs(All_EMG_time - All_Experiment_time(start_move(idx, i))));
        [~, Trials_Info{1, i}.Events.EMG_stream.Movement_end_indx] = ...
            min(abs(All_EMG_time - All_Experiment_time(finish_beep(1, i))));

        % flexion start & end
        Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Flexion_Start);
        Trials_Info{1, i}.Events.EMG_stream.flexion_start_indx = ...
            interp1(All_EMG_time, 1:length(All_EMG_time), Exp_timing, 'nearest', 'extrap');

        Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Flexion_End);
        Trials_Info{1, i}.Events.EMG_stream.flexion_end_indx = ...
            interp1(All_EMG_time, 1:length(All_EMG_time), Exp_timing, 'nearest', 'extrap');

        % extension start & end
        Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Extension_Start);
        Trials_Info{1, i}.Events.EMG_stream.extension_start_indx = ...
            interp1(All_EMG_time, 1:length(All_EMG_time), Exp_timing, 'nearest', 'extrap');

        Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Extension_End);
        Trials_Info{1, i}.Events.EMG_stream.extension_end_indx = ...
            interp1(All_EMG_time, 1:length(All_EMG_time), Exp_timing, 'nearest', 'extrap');

        % flextoflex start & end
        if Trials_Info{1, i}.General.Case == 3
            Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Flexion_Start(1:end));
        elseif Trials_Info{1, i}.General.Case == 4
            Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Flexion_Start(1:end-1));
        end
        Trials_Info{1, i}.Events.EMG_stream.flextoflex_start_indx = ...
            interp1(All_EMG_time, 1:length(All_EMG_time), Exp_timing, 'nearest', 'extrap');

        Exp_timing = All_Experiment_time(Trials_encoder_events{1, i}.Extension_End(1:end));
        Trials_Info{1, i}.Events.EMG_stream.flextoflex_end_indx = ...
            interp1(All_EMG_time, 1:length(All_EMG_time), Exp_timing, 'nearest', 'extrap');

    end


    %% Filling the "Events.EXP_stream" field
    for i = 1:length(Trials_Info)

        % Trial start & end
        Trials_Info{1, i}.Events.EXP_stream.Trial_start_indx = ...
            start_beep(1, i);
        Trials_Info{1, i}.Events.EXP_stream.Trial_end_indx = ...
            score_press(1, i);

        % Pressure Change
        [~, Trials_Info{1, i}.Events.EXP_stream.Pressure_Change_indx] = ...
            min(abs(All_Experiment_time - pressure_change_time_Expdata(1, i)));

        % Movement start & end
        Trials_Info{1, i}.Events.EXP_stream.Movement_start_indx = ...
            start_move(idx, i);
        Trials_Info{1, i}.Events.EXP_stream.Movement_end_indx = ...
            finish_beep(1, i);

        % flexion start & end
        Trials_Info{1, i}.Events.EXP_stream.flexion_start_indx = ...
            Trials_encoder_events{1, i}.Flexion_Start;
        Trials_Info{1, i}.Events.EXP_stream.flexion_end_indx = ...
            Trials_encoder_events{1, i}.Flexion_End;

        % extension start & end
        Trials_Info{1, i}.Events.EXP_stream.extension_start_indx = ...
            Trials_encoder_events{1, i}.Extension_Start;
        Trials_Info{1, i}.Events.EXP_stream.extension_end_indx = ...
            Trials_encoder_events{1, i}.Extension_End;

        % flextoflex start & end
        if Trials_Info{1, i}.General.Case == 3
            Trials_Info{1, i}.Events.EXP_stream.flextoflex_start_indx = ...
                Trials_encoder_events{1, i}.Flexion_Start(1:end);
        elseif Trials_Info{1, i}.General.Case == 4
            Trials_Info{1, i}.Events.EXP_stream.flextoflex_start_indx = ...
                Trials_encoder_events{1, i}.Flexion_Start(1:end-1);
        end
        Trials_Info{1, i}.Events.EXP_stream.flextoflex_end_indx = ...
            Trials_encoder_events{1, i}.Extension_End(1:end);

    end
    

    %% Filling the "Events.EEG_stream.Preprocessed" field (on EEGLAB data after preprocessing)
    EEGLAB_event_type = {EEG.event.type};
    EEGLAB_event_desc = {EEG.event.desc};
    for i = 1:length(Trials_Info)
        desc_ending = ['_', num2str(i)];
    
        desired_types = {'SB_Start_Beep', 'SP_Score_Press', ...
            'PC_Pressure_Change', ...
            'SM_Start_Move', 'FB_Finish_Beep', ...
            'FlxS', 'FlxE', 'ExtS', 'ExtE'};
        corresponding_fields = {'Trial_start_indx', 'Trial_end_indx', ...
            'Pressure_Change_indx', ...
            'Movement_start_indx', 'Movement_end_indx', ...
            'flexion_start_indx', 'flexion_end_indx', ...
            'extension_start_indx', 'extension_end_indx'};

        for s = 1:numel(desired_types)

            indices = strcmp(EEGLAB_event_type, desired_types{s}) & ...
                  endsWith(EEGLAB_event_desc, desc_ending);
            Trials_Info{1, i}.Events.EEG_stream.Preprocessed.(corresponding_fields{s}) = ...
                [EEG.event(indices).latency];

        end
        
        % flextoflex start & end
        if Trials_Info{1, i}.General.Case == 3
            Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flextoflex_start_indx = ...
                Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flexion_start_indx(1:end);
        elseif Trials_Info{1, i}.General.Case == 4
            Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flextoflex_start_indx = ...
                Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flexion_start_indx(1:end-1);
        end
        Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flextoflex_end_indx = ...
            Trials_Info{1, i}.Events.EEG_stream.Preprocessed.extension_end_indx(1:end);

    end


    
    %% Save Trials_Info

    save_path = [data_path, '6_Trials_Info_and_Epoched_data\', ...
        'sub-', num2str(subject_id)];
    fullFilePath = fullfile(save_path, 'Trials_Info.mat');

    if ~isfolder(save_path)
        mkdir(save_path);
        save(fullfile(save_path, 'Trials_Info.mat'), 'Trials_Info', '-v7.3');
        disp(['Trials_Info.mat saved to ', save_path]);
    else
        % Folder exists, check if the Trials_Info already exists
        if exist(fullFilePath, 'file')
            % File exists, ask user for permission to overwrite using a dialog box
            choice = questdlg('Trials_Info.mat already exists. Do you want to overwrite it?', ...
                              'Confirm Overwrite', ...
                              'OK', 'Cancel', 'OK');
            switch choice
                case 'OK'
                    save(fullfile(save_path, 'Trials_Info.mat'), 'Trials_Info', '-v7.3');
                    disp(['Trials_Info.mat overwritten and saved to ', save_path]);
                case 'Cancel'
                    disp('Trials_Info.mat was not saved.');
            end
        else
            % File does not exist, save the Trials_Info.mat
            save(fullfile(save_path, 'Trials_Info.mat'), 'Trials_Info', '-v7.3');
            disp(['Trials_Info.mat saved to ', save_path]);
        end
    end
    

end