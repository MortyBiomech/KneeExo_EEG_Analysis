clc
clear


%% Add paths
addpath(genpath('D:\Morteza\MyProjects\ANSYMB2024\Code'))
data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
epoched_data_path = [data_path, '6_Trials_Info_and_Epoched_data\'];
current_path = ['D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab', ...
    '\data_processing\Group_Level_PostProcessing\', ...
    'Final_paper_plot_generation\Detailed_Analysis_on_EMG\'];
strutured_EMG_data_path = [...
'D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab\data_processing', ...
'\EMG_processing\structured_EMG_data\'];


%% Load the structured EMG data
subject_list = 5:18;

Subject_EMG_Data = cell(length(subject_list), 2);
Subject_EMG_Data(:, 1) = arrayfun(@(x) ['Sub ', num2str(x)], ...
    subject_list, 'UniformOutput', false);


for sub = 1:length(subject_list)

    if subject_list(sub) == 10; continue; end; % no EMG data for subject 10
    
    EMG_Data_Structure = struct('time', [], 'EMG', [], 'iEMG', [], ...
        'pressure', [], 'score', [], 'trial_epoch', [], 'events', [], ...
        'time_warp_to', []);

    %% Load the epoched EMG data
    
    disp(['Loading data from subject ', num2str(subject_list(sub)), ' ...'])
    
    folderName = [strutured_EMG_data_path, 'sub-', ...
        num2str(subject_list(sub))];
    cd(folderName)
    load(['sub-', num2str(subject_list(sub)),'_structured_EMG_data.mat'])
    structured_EMG_data = Main_data;
    EMG_time = cellfun(@(x) x.time, Main_data, 'UniformOutput', false);
    clear Main_data
   

    %% Store the data per trial 
    N = length(structured_EMG_data);
    c = 1;
    for trial = 1:N
    
        % check if we are at the experimental trial
        if ~strcmp(structured_EMG_data{trial}.Description, 'Experiment')
            continue
        end

        % % non-empty trial
        % if isempty(EMG_data{trial}.Times)
        %     continue
        % end


        % Epochs time
        EMG_Data_Structure.time = vertcat( ...
            EMG_Data_Structure.time, ...
            {EMG_time{trial}'});

        % Epochs EMG data
        EMG_Data_Structure.EMG = vertcat( ...
            EMG_Data_Structure.EMG, ...
            {structured_EMG_data{trial}.Signal'});

        % Epochs mean(?) iEMG data
        signals = structured_EMG_data{trial}.Signal;
        signals = signals(~cellfun(@(x) isempty(x), signals));
        % signals_iEMG = cellfun(@(x) sum(x, 2)/size(x, 2), signals, ... 
        %     'UniformOutput', false);
        signals_iEMG = cellfun(@(x) sum(x, 2)/2000, signals, ... 
            'UniformOutput', false); % 2000 Hz
        signals_iEMG = cell2mat(signals_iEMG)';
        EMG_Data_Structure.iEMG = vertcat( ...
            EMG_Data_Structure.iEMG, ...
            {signals_iEMG});

        % Pressure level
        P = structured_EMG_data{trial}.Pressure;
        EMG_Data_Structure.pressure = cat(1, ...
            EMG_Data_Structure.pressure, ...
            {repmat(P, length(EMG_time{trial}), 1)});

        % Trial score
        score = structured_EMG_data{trial}.Score;
        EMG_Data_Structure.score = cat(1, ...
            EMG_Data_Structure.score, ...
            {repmat(score, length(EMG_time{trial}), 1)});

        % [Trial Epoch] number
        EMG_Data_Structure.trial_epoch = cat(1, ...
            EMG_Data_Structure.trial_epoch, ...
            [repmat(c, length(EMG_time{trial}), 1), ...
             repmat(trial, length(EMG_time{trial}), 1), ...
             (1:length(EMG_time{trial}))']);

        c = c + 1;

        % Event indexes
        events = structured_EMG_data{trial}.events;
        EMG_Data_Structure.events = cat(1, ...
            EMG_Data_Structure.events, ...
            events);
        

    end
    Subject_EMG_Data{sub, 2} = EMG_Data_Structure;
   
end


%% backup the main structure
% temp_Subject_EMG_Data = Subject_EMG_Data;
% Subject_EMG_Data = temp_Subject_EMG_Data;


%% Perform the Time-Warping procedure
% find the warp_to indeces per subject

warpto_subjects = [];
for sub = 1:length(subject_list)

    if subject_list(sub) == 10; continue; end; % no EMG data for subject 10
    
    events = Subject_EMG_Data{sub, 2}.events;
    outlier1 = isoutlier(events(:, 2), "median", 1, "ThresholdFactor", 3);
    outlier2 = isoutlier(events(:, 3), "median", 1, "ThresholdFactor", 3);
    idx = or(outlier1, outlier2);

    trial_epochs = Subject_EMG_Data{sub, 2}.trial_epoch;
    trial_epochs_outliers = trial_epochs(idx, :);
    unique_trials = unique(trial_epochs_outliers(:, 1));
    for trial = 1:length(unique_trials)
        t = unique_trials(trial);
        epochs_ids = ...
            trial_epochs_outliers(trial_epochs_outliers(:, 1) == t, 3);

        % time, pressure, score
        x = length(Subject_EMG_Data{sub, 2}.time{t});
        ids_to_remove = intersect(1:x, epochs_ids);
        if length(ids_to_remove) == x
            Subject_EMG_Data{sub, 2}.time{t} = {};
            Subject_EMG_Data{sub, 2}.pressure{t} = {};
            Subject_EMG_Data{sub, 2}.score{t} = {};
        else
            Subject_EMG_Data{sub, 2}.time{t}(ids_to_remove) = [];
            Subject_EMG_Data{sub, 2}.pressure{t}(ids_to_remove) = [];
            Subject_EMG_Data{sub, 2}.score{t}(ids_to_remove) = [];
        end

        % EMG 
        x = length(Subject_EMG_Data{sub, 2}.EMG{t});
        ids_to_remove = intersect(1:x, epochs_ids);
        if length(ids_to_remove) == x
            Subject_EMG_Data{sub, 2}.EMG{t} = {};
        else
            Subject_EMG_Data{sub, 2}.EMG{t}(ids_to_remove) = [];
        end

        % iEMG
        x = length(Subject_EMG_Data{sub, 2}.iEMG{t});
        ids_to_remove = intersect(1:x, epochs_ids);
        if length(ids_to_remove) == x
            Subject_EMG_Data{sub, 2}.iEMG{t} = {};
        else
            Subject_EMG_Data{sub, 2}.iEMG{t}(ids_to_remove, :) = [];
        end

    end

    % trial_epochs
    Subject_EMG_Data{sub, 2}.trial_epoch = trial_epochs(~idx, :);
    
    % events
    Subject_EMG_Data{sub, 2}.events = events(~idx, :);
    

    % remove trials which now has less than 4 epochs
    epochs_count = cellfun(@(x) length(x), Subject_EMG_Data{sub, 2}.time);
    idx = epochs_count < 5;
    Subject_EMG_Data{sub, 2}.time(idx) = [];
    Subject_EMG_Data{sub, 2}.pressure(idx) = [];
    Subject_EMG_Data{sub, 2}.score(idx) = [];
    Subject_EMG_Data{sub, 2}.EMG(idx) = [];
    Subject_EMG_Data{sub, 2}.iEMG(idx) = [];

    trials_to_remove = find(idx);
    trial_epochs_to_remove = find(...
        ismember(Subject_EMG_Data{sub, 2}.trial_epoch(:, 1), trials_to_remove));
    Subject_EMG_Data{sub, 2}.trial_epoch(trial_epochs_to_remove, :) = [];
    Subject_EMG_Data{sub, 2}.events(trial_epochs_to_remove, :) = [];


    Subject_EMG_Data{sub, 2}.time_warp_to = ...
        [0, round(median(events(:, 2))), round(median(events(:, 3)))];

    warpto_subjects = cat(1, warpto_subjects, Subject_EMG_Data{sub, 2}.time_warp_to);
end

roundNear = 50; % round numbers to the closest multiple of this value
warpingvalues = round(median(warpto_subjects, 1)/roundNear)*roundNear;



%% Doing the time-warp 
Subject_EMG_Data_timewarped = Subject_EMG_Data;
FlxL = warpingvalues(2);
ExtL = warpingvalues(3) - warpingvalues(2);
for sub = 1:length(subject_list)
    
    if subject_list(sub) == 10; continue; end; % no EMG data for subject 10
    
    N = length(Subject_EMG_Data_timewarped{sub, 2}.time);
    unique_trials = unique(Subject_EMG_Data_timewarped{sub, 2}.trial_epoch(:, 1));
    for trial = 1:N
        signal = Subject_EMG_Data_timewarped{sub, 2}.EMG{trial};

        events_idx = ...
            find(Subject_EMG_Data_timewarped{sub, 2}.trial_epoch(:, 1) == ...
                 unique_trials(trial));
        events = Subject_EMG_Data_timewarped{sub, 2}.events(events_idx, :);
        events = num2cell(events, 2);

        orig_time = Subject_EMG_Data_timewarped{sub, 2}.time{trial};

        new_time_Flx = cellfun(@(x1, x2) linspace(x1(1), x1(x2(2)), FlxL), ...
            orig_time, events, 'UniformOutput', false);
        new_time_Ext = cellfun(@(x1, x2) linspace(x1(x2(2)+1), x1(end), ExtL), ...
            orig_time, events, 'UniformOutput', false);
        new_time = cellfun(@(x1, x2) [x1, x2], new_time_Flx, new_time_Ext, ...
            'UniformOutput', false);

        EMG_timewarped = cellfun(@(x1, x2, x3) ...
            interp1(x1', x2', x3', "linear")', orig_time, signal, new_time, ...
            'UniformOutput', false);

        Subject_EMG_Data_timewarped{sub, 2}.EMG{trial} = EMG_timewarped;

    end

end


%% Save the data
% add final warpingto vector and muscles name
disp('Saving the EMG structure ...')
muscles_names = structured_EMG_data{1}.Names;
EMG_Data_timewarped = struct('Muscle_Name', [], ...
    'final_warpingto', [], 'data', []);
EMG_Data_timewarped.Muscle_Name = muscles_names;
EMG_Data_timewarped.final_warpingto = warpingvalues;
EMG_Data_timewarped.data = Subject_EMG_Data_timewarped;

fileName = 'EMG_Data_timewarped.mat';
filePath = [current_path, fileName];
save(filePath, "EMG_Data_timewarped")