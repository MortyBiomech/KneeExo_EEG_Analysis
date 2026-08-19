function [EEG, removeindices] = Main_add_events(EEG, output, ...
    subject_id, processing_path, study_path)    

% old version changed at 01/04/2026:
% [EEG, removeindices] = Main_add_events(EEG, output, ...
%     subject, subject_id, processing_path, input_filepath, bemobil_config, study_path)    


    if subject_id > 9
        idx = 2;
    else
        idx = 1;
    end
    
    All_Experiment = output.All_Exp;
    All_Experiment_time = output.All_Exp_time;
    All_EEG_time = output.All_EEG_time;

    %% Define and Add events
    % Compute latency values
    
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

    
    %% Define and Add Events
    if subject_id == 13
        no_PAM_trials = [1:3, 40:42, 43:45, 76:78, 79:81, 112:114, 115:117, 148:150];
        familiarization_trials = 4:9;
    end
    if subject_id < 10
        no_PAM_trials = [];
        familiarization_trials = [];
    end
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

    

    %% Write the TS_SB_PC_SM_FB_SP_TE_event.txt file
    % TS: Trial Start
    % SB: Start Beep
    % after 2s 
    % PC: Pressure Change
    % after 2s
    % SM: Start Move
    % after 20s
    % FB: Finish Beep
    % SP: Score Press
    % TE: Trial End

    folder = [processing_path, 'Events', ...
        filesep, 'sub-', num2str(subject_id)];

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
    
    
    %% Add Events to the EEG file 
    [EEG, eventnumbers] = pop_importevent(EEG, 'event', ...
              filename, 'fields', {'type', 'latency','desc' }, ...
              'append', 'no', 'align', NaN, 'skipline', 1, 'timeunit', 1E-3);


    %% individual EEG processing to remove non-exp segments
    % it is stongly recommended to remove these segments because they may contain strong artifacts that confuse channel
    % detection and AMICA
    removeindices = zeros(size(start_beep,2)+1 ,2);
    % remove from start to first event
    removeindices(1, :) = [0 EEG.event(1).latency-1]; 

    % add more removeIndices here for pauses or itnerruptions of the 
    % experiment if they have markers or you know their indices in the data

    start_beep_EEGLABevent = find(strcmp({EEG.event.type}, 'SB_Start_Beep'));
    for i = 1:size(start_beep_EEGLABevent,2)-1
        removeindices(i+1, :) = [EEG.event(7*i).latency+1 EEG.event(7*i+1).latency-1]; % this should be changed based on the subject
    end
    removeindices(end, :) = [EEG.event(end).latency+1 EEG.pnts]; % remove from last event to the end
    
    

    %%
    % % filter for plot
    % EEG_plot = pop_eegfiltnew(EEG, 'locutoff',0.5, 'hicutoff', 40,'plotfreqz',0);
    % 
    % % plot
    % fig1 = figure; set(gcf,'Color','w','InvertHardCopy','off', 'units','normalized','outerposition',[0 0 1 1])
    % plot(normalize(EEG_plot.data') + [1:10:10*EEG_plot.nbchan], 'color', [78 165 216]/255)
    % yticks([])
    % 
    % xlim([0 EEG.pnts])
    % ylim([-10 10*EEG_plot.nbchan+10])
    % 
    % hold on
    % 
    % % plot lines for valid times
    % 
    % for i = 1:size(removeindices,1)
    %     plot([removeindices(i,1) removeindices(i,1)],ylim,'k', 'LineStyle','-')
    %     plot([removeindices(i,2) removeindices(i,2)],ylim,'k', 'LineStyle','--')
    % end
    % title(['Subject ', num2str(subject), ', Non-Exp Segments: From Solid Line to Next Dashed Line on the Right'])
    % 
    % % save plot
    % print(gcf,fullfile(input_filepath,[bemobil_config.filename_prefix num2str(subject) '_raw-full_EEG.png']),'-dpng')
    % close




    %% Add other flexion/extension start/end events
    % Important Note: before rejecting the non-exp segments you must add
    % the flexion/Extension start events

    % Note on 01/04/2026
    % For any new subject we need to make Trials_encoder_events structure.
    % But we should not run all the code again on the processed subjects. 

    % Use peak selection app to find the flexion and extension start events
    output_peaks = find_peaks_and_select_events(output, subject_id);

    start_beep = start_beep(1, :);
    if subject_id > 9
        start_move = start_move(2, :); %#ok<NASGU>
    else
        start_move = start_beep; %#ok<NASGU>
    end
    XLimits = output_peaks.XLimits;

    trial_pks_high_peaks = output_peaks.trial_pks_high_peaks;
    trial_locs_high_peaks = output_peaks.trial_locs_high_peaks;

    trial_pks_low_peaks = output_peaks.trial_pks_low_peaks;
    trial_locs_low_peaks = output_peaks.trial_locs_low_peaks;

    N_Trials = output_peaks.N_Trials;

    Trials_encoder_events = output_peaks.Trials_encoder_events;

    for i = 1:numel(Trials_encoder_events)
        Trials_encoder_events{1, i}.Description = Trials{1, i}.Description;
        Trials_encoder_events{1, i}.Pressure = Trials{1, i}.Pressure;
        Trials_encoder_events{1, i}.Score = Trials{1, i}.Score;
    end


    %% run the app to select unwanted peaks 

    app = find_flexion_extension_events;
    app.initializeApp(subject_id, All_Experiment_time, ...
                      All_Experiment, start_beep, ...
                      pressure_change_time_Expdata, start_move, ...
                      finish_beep, score_press_time_Expdata, ...
                      XLimits, trial_pks_high_peaks, trial_locs_high_peaks, ...
                      trial_pks_low_peaks, trial_locs_low_peaks, ...
                      Trials_encoder_events);


    % Wait for the app to close
    waitfor(app.UIFigure);

    Trials_encoder_events = load([study_path, '6_0_Trials_Info_and_Events\sub-', ...
        num2str(subject_id), filesep, 'sub-', num2str(subject_id), ...
        '_Trials_encoder_events.mat']);
    Trials_encoder_events = Trials_encoder_events.Trials_encoder_events;


    %% Add flexion and extension indexes to Trials_encoder_events structure (based on Exp stream indexes)
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


    save([study_path, '6_0_Trials_Info_and_Events\sub-', ...
        num2str(subject_id), filesep, 'sub-', num2str(subject_id), ...
        '_Trials_encoder_events.mat'], 'Trials_encoder_events', '-v7.3')


    %% Add events to the text file to import them in EEG data (EEGLAB)
    % Initialize variables
    
    n_trials = length(Trials_encoder_events);
    event_types = {'FlxS', 'FlxE', 'ExtS', 'ExtE'};
    event_fields = {'Flexion_Start', 'Flexion_End', 'Extension_Start', 'Extension_End'};
    
    % Pre-calculate total number of events to preallocate arrays
    total_events = 0;
    for i = 1:n_trials
        for j = 1:numel(event_fields)
            total_events = total_events + numel(Trials_encoder_events{1, i}.(event_fields{j}));
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
    trial_indices = trial_indices(1:idx-1);
    
    % Map event times to EEG indices using interp1 for efficiency
    all_event_indx_EEG = interp1(All_EEG_time, 1:length(All_EEG_time), all_event_times_Expdata, 'nearest', 'extrap');
    all_event_latency_EEG = EEG.times(all_event_indx_EEG);
    
    % Organize data back into per-trial cell arrays
    type_extended = cell(1, n_trials);
    latency_extended = cell(1, n_trials);
    desc_extended = cell(1, n_trials);
    
    for i = 1:n_trials
        idx_trial = (trial_indices == i);
        type_extended{i} = all_event_labels(idx_trial)';
        latency_extended{i} = all_event_latency_EEG(idx_trial)';
        desc_extended{i} = all_descs(idx_trial)';
    end
    

    %% Appending to the text file
    % Define the file paths
    original_filename = [processing_path, 'Events\sub-', ...
        num2str(subject_id), filesep, 'events_basic.txt'];
    new_filename = [processing_path, 'Events\sub-', ...
        num2str(subject_id), filesep, 'events_with_FlxExt.txt'];
    
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



    % Ensure your data arrays are column vectors
    event_labels = all_event_labels;          % Cell array of strings, size (9730 x 1)
    event_latency = all_event_latency_EEG';   % Numeric array, transpose to (9730 x 1)
    event_descs = all_descs;                  % Cell array of cell arrays, size (9730 x 1)
    
    % Process event_descs to create a cell array of strings
    event_descs_str = cell(size(event_descs));  % Initialize cell array for descriptions
    for i = 1:length(event_descs)
        % Extract the cell array of numbers for the current event
        desc_numbers = event_descs{i};  % This is a 1x3 cell array of numbers
    
        % Convert each number to a string
        desc_strings = cellfun(@num2str, desc_numbers, 'UniformOutput', false);
    
        % Combine the strings with underscores
        desc_str = strjoin(desc_strings, '_');
    
        % Store the resulting string
        event_descs_str{i} = desc_str;
    end


    % Append the new lines to the existing lines
    for i = 1:length(event_latency)
        new_line = sprintf('%s\t%f\t%s', event_labels{i}, event_latency(i), event_descs_str{i});
        existing_lines{end + 1} = new_line; %#ok<SAGROW> % Add each new line to the cell array
    end
    
    % Write the combined content to a new file
    fid = fopen(new_filename, 'w');
    if fid == -1
        error('Failed to open the new file for writing.');
    end
    
    for i = 1:length(existing_lines)
        fprintf(fid, '%s\n', existing_lines{i});
    end
    
    % Close the new file
    fclose(fid);
    
    

    %% Add Events with Flexion & Extension to the EEG file 
    [EEG, ~] = pop_importevent(EEG, 'event', ...
              new_filename, 'fields', {'type', 'latency','desc' }, ...
              'append', 'no', 'align', NaN, 'skipline', 1, 'timeunit', 1E-3);

end