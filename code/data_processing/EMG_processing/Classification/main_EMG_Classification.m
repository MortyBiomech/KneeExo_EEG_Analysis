clc
clear

%% Add and Define Necessary Paths
main_project_folder = 'C:\Morteza\MyProjects\ANSYMB2024';
addpath(genpath(main_project_folder)); % main folder containing all codes and data

data_path = 'C:\Morteza\MyProjects\ANSYMB2024\data\';
EMG_features_path = [main_project_folder, ...
    '\Code\Matlab\data_processing\EMG_processing\structured_EMG_data'];


%% Load EMG Features

subjects_list = [5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18];
for i = 1:numel(subjects_list)
    disp(['subject ', num2str(subjects_list(i))])

    filename = ['sub-', num2str(subjects_list(i)), '\sub-', num2str(subjects_list(i)),'_structured_EMG_data.mat'];
    data = load(fullfile(EMG_features_path, filename));
    name = fieldnames(data);
    data = data.(name{1});


    %% identify the conditions
    condition_per = 2; % 1 = pressure_based; 2 = score_based
    if condition_per == 1
        condition_indices = condition_indices_identifier_EMG(data);
    elseif condition_per == 2
        % other function that labels the data based on score clustering
        condition_indices = condition_indices_identifier_EMG_ScoreBased(data, subjects_list(i));
    end

    %% Creating the tables for classification

    per_trial_or_all_epochs = 'per_trial';
    type = 'FlextoFlex'; % 'FlextoFlex' 'Extension' 'Flexion'
    classes = 'S1S2S3'; % 'P1P3P6' 'P1P6' 'P1P3' 'P3P6'; 'S1S2S3' 'S1S2' 'S1S3' 'S2S3'

    % P1_count = 0;
    % P3_count = 0;
    % P6_count = 0;
    % P1_features = [];
    % P3_features = [];
    % P6_features = [];

    S1_count = 0;
    S2_count = 0;
    S3_count = 0;
    S1_features = [];
    S2_features = [];
    S3_features = [];

    for j = 1:length(data)
        if isempty(data{1, j}.Classification_Features.per_trial)
            continue
        end

        if ismember(j, condition_indices.S1) % condition_indices.P1
            % P1_features = cat(1, P1_features, data{1, j}.Classification_Features.per_trial);
            % P1_count = P1_count + 1;
            S1_features = cat(1, S1_features, data{1, j}.Classification_Features.per_trial);
            S1_count = S1_count + 1;
        elseif ismember(j, condition_indices.S2) % condition_indices.P3
            % P3_features = cat(1, P3_features, data{1, j}.Classification_Features.per_trial);
            % P3_count = P3_count + 1;
            S2_features = cat(1, S2_features, data{1, j}.Classification_Features.per_trial);
            S2_count = S2_count + 1;
        elseif ismember(j, condition_indices.S3) % condition_indices.P6
            % P6_features = cat(1, P6_features, data{1, j}.Classification_Features.per_trial);
            % P6_count = P6_count + 1;
            S3_features = cat(1, S3_features, data{1, j}.Classification_Features.per_trial);
            S3_count = S3_count + 1;
        end
        
    end

    % all_features = [P1_features; P3_features; P6_features];
    all_features = [S1_features; S2_features; S3_features];
    % Three-class labels (P1, P3, P6)
    % classLabels = [repmat({'P1'}, P1_count, 1); ...
    %                repmat({'P3'}, P3_count, 1); ...
    %                repmat({'P6'}, P6_count, 1)];
    classLabels = [repmat({'S1'}, S1_count, 1); ...
                   repmat({'S2'}, S2_count, 1); ...
                   repmat({'S3'}, S3_count, 1)];
    classLabels = categorical(classLabels); % Convert to categorical

    % table columns
    columnNames = {'Vastus_med_R_Flexsion_RMS', 'Vastus_med_R_Extension_RMS', ...
                   'Rectus_femoris_R_Flexsion_RMS', 'Rectus_femoris_R_Extension_RMS', ...
                   'Gastrocnemius_R_Flexsion_RMS', 'Gastrocnemius_R_Extension_RMS', ...
                   'Biceps_femoris_R_Flexsion_RMS', 'Biceps_femoris_R_Extension_RMS', ...
                   'Label'};

    % Create the table for the current subject
    subjectTable = array2table(all_features, 'VariableNames', columnNames(1:end-1));
    subjectTable.Label = classLabels; % Add the 'Pressure' column with categorical labels

    % Store the table in the workspace dynamically
    assignin('base', ['Subject_', num2str(subjects_list(i)), '_', type, '_classes_', classes, '_', per_trial_or_all_epochs], subjectTable);
    % assignin('base', ['Subject_', num2str(subjects_list(i)), '_classes_count'], [P1_count, P3_count, P6_count]);
    assignin('base', ['Subject_', num2str(subjects_list(i)), '_classes_count'], [S1_count, S2_count, S3_count]);


end