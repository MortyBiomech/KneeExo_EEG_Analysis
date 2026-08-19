function out = runs_concatenated(subject_id, rawdata_path)

    %% Load XDF files (it takes a while to load all the streams!)
    streams    = xdf_load_matlab(subject_id, rawdata_path);
    
    %% Concatenating Signals
    % Identify the indeces for EEG, EMG, and Encoder(Exp_data) signals
    EEG_indx = [];
    EMG_indx = [];
    Exp_indx = [];
    
    for i = 1:length(streams)
        for j = 1:4 % 4: EEG_trigger_markers, EEG, EMG, Matlabl_signals
            type = streams{1, i}(j).dataset.info.type;
            if strcmp(type, 'EEG')
                EEG_indx = [EEG_indx, j];
            end
            if strcmp(type, 'EMG')
                EMG_indx = [EMG_indx, j];
            end
            if strcmp(type, 'Exp_data')
                Exp_indx = [Exp_indx, j];
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
    
    % Check if the sensor ids are the same in all sessions (just for
    % subject 8 as we had to change the sensors due to battery issues!)
    for i = 2:length(temp_EMG)
        if size(temp_EMG{1, i},1) ~= size(temp_EMG{1, 1},1)
            % Instruction message
            prompt = {sprintf(['New EMG sensors were utilized at ', ...
                'session ', num2str(i), '. Please write down the new ', ...
                'sensor IDs and their corresponding old ones ' ...
                '(e.x. [12 2; 13 3; 14 4; 15 5], this means sensors ', ...
                '12, 13, 14, and 15 were used instead of sensors ', ...
                '2, 3, 4, and 5, respectively):\n'])};
            dlg_title = 'EMG sensors replacement';
            num_lines = 1;
            defaultans = {'[12 2; 13 3; 14 4; 15 5]'};
            
            % Display input dialog
            try 
                answer = ...
                    inputdlg(prompt, dlg_title, num_lines, defaultans);
                answer = str2num(answer{1,1});
                temp_EMG{1, i}(answer(:,2),:) = ...
                    temp_EMG{1, i}(answer(:,1),:);
                temp_EMG{1, i}(answer(:,1),:) = [];
            catch
                disp('No input from user!')
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
