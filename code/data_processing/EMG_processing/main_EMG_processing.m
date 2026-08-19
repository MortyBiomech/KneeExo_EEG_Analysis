clc
clear

%% Paths
% Everything comes from the repository config, so this runs from a fresh
% clone. Put config on the path first:  addpath('config')  -- see README.
cfg = ansymb_config();
addpath(genpath(cfg.code));

if isempty(cfg.raw)
    error(['This stage reads the recorded and intermediate data, which is ' ...
           'not shipped with the repository. Set cfg.raw in ' ...
           'config/ansymb_config.m to your copy of the dataset.']);
end

epoched_data_path   = cfg.trialsInfo;
% Per-subject EMG intermediates now live with the data, not in the code tree.
EMG_processing_path = cfg.raw;


%% Load dataset
% subjects_list = [5 6 7 8 9 11 12 13 14 15 16 17 18];
subjects_list = [5 6 7 8 9 11 12 13 14 15 16 17 18];
for i = 1:length(subjects_list)
    disp(['subject ', num2str(subjects_list(i))])

    filename = ['sub-', num2str(subjects_list(i)), '\Epochs_FlextoFlex_based.mat'];
    data = load(fullfile(epoched_data_path, filename));
    name = fieldnames(data);
    data = data.(name{1});

    filename = ['sub-', num2str(subjects_list(i)), '\Trials_Info.mat'];
    Trials_Info = load(fullfile(epoched_data_path, filename));
    name = fieldnames(Trials_Info);
    Trials_Info = Trials_Info.(name{1});


    emg_struct = struct('Names', [], 'events', [], 'time', [], ...
        'Signal', [], 'Signal_TimeWarped', [], ...
        'Flexion_Extension_Lengths', [],'Pressure', [], ...
        'Score', [], 'Description', [], 'Outlier', [], ...
        'Classification_Features', struct('per_trial', [], 'all_epochs', []));

    length_of_trials = cellfun(@(x) length(x.EMG_stream.Sensors_Preprocessed), ...
        data);
    nonzero_trials = sum(length_of_trials ~= 0);
    Main_data = repmat({emg_struct}, 1, nonzero_trials);

    jj = 0;
    for j = 1:length(data)

        if isempty(data{1, j}.EMG_stream.Sensors_Preprocessed)
            continue
        end
        jj = jj + 1;
        
        muscles_names = data{1, j}.General.Muscles_Names;
        % if subjects_list(i) >= 10
        %     muscles_names = data{1, j}.General.Muscles_Names;
        % else
        %     muscles_names = data{1, j}.EMG_stream.Names;
        % end


        kk = 0;
        for k = 1:length(data{1, j}.EMG_stream.Sensors_Preprocessed)

            if size(data{1, j}.EMG_stream.Sensors_Preprocessed{1, k}, 2) < 2000
                continue
            end
            kk = kk + 1;

            % event
            e = [...
                Trials_Info{j}.Events.EMG_stream.flextoflex_start_indx(kk), ...
                Trials_Info{j}.Events.EMG_stream.extension_start_indx(kk), ...
                Trials_Info{j}.Events.EMG_stream.flextoflex_end_indx(kk)] - ...
                repmat(Trials_Info{j}.Events.EMG_stream.flextoflex_start_indx(kk)-1, ...
                       1, 3);
            Main_data{1, jj}.events = cat(1, Main_data{1, jj}.events, e);

            % time
            Main_data{1, jj}.time{1, kk} = data{1, j}.EMG_stream.Times{1, k};

            % Vastus_med_R
            index = strcmp(muscles_names, 'Vastus_med_R');
            Main_data{1, jj}.Signal{1, kk}(1, :) = data{1, j}.EMG_stream.Sensors_Preprocessed{1, k}(index, :);
            Main_data{1, jj}.Names{1, 1} = 'Vastus_med_R';
            % Rectus_femoris_R
            index = strcmp(muscles_names, 'Rectus_femoris_R');
            Main_data{1, jj}.Signal{1, kk}(2, :) = data{1, j}.EMG_stream.Sensors_Preprocessed{1, k}(index, :);
            Main_data{1, jj}.Names{1, 2} = 'Rectus_femoris_R';
            % Gastrocnemius_R
            index = strcmp(muscles_names, 'Gastrocnemius_R');
            Main_data{1, jj}.Signal{1, kk}(3, :) = data{1, j}.EMG_stream.Sensors_Preprocessed{1, k}(index, :);
            Main_data{1, jj}.Names{1, 3} = 'Gastrocnemius_R';
            % Biceps_femoris_R
            index = strcmp(muscles_names, 'Biceps_femoris_R');
            Main_data{1, jj}.Signal{1, kk}(4, :) = data{1, j}.EMG_stream.Sensors_Preprocessed{1, k}(index, :);
            Main_data{1, jj}.Names{1, 4} = 'Biceps_femoris_R';

        end

        % check again so we don't pass an empty cell to the next steps
        if isempty(Main_data{1, jj}.Signal)
            jj = jj - 1;
            continue
        end


        Main_data{1, jj}.Pressure = Trials_Info{1, j}.General.Pressure;
        Main_data{1, jj}.Score = Trials_Info{1, j}.General.Score;
        if subjects_list(i) >= 10
            Main_data{1, jj}.Description = Trials_Info{1, j}.General.Description;
        else
            Main_data{1, jj}.Description = 'Experiment';
        end
        
    end


    %% Applying linear time warp method to have the same length signals
    % events = [];
    % for j = 1:length(Trials_Info)
    % 
    %     if strcmp(Main_data{1, j}.Description, 'Experiment')
    %         L = cellfun(@(x) size(x, 2), data{1, j}.EMG_stream.Sensors_Preprocessed);
    %         Lfine_epochs = L > 2000;
    %     else
    %         continue
    %     end
    % 
    %     e = Trials_Info{1, j}.Events.EMG_stream.flextoflex_start_indx(Lfine_epochs);
    %     flextoflex_start = reshape(e, length(e), 1);
    %     e = Trials_Info{1, j}.Events.EMG_stream.extension_start_indx(Lfine_epochs);
    %     extension_start = reshape(e, length(e), 1);
    %     e = Trials_Info{1, j}.Events.EMG_stream.flextoflex_end_indx(Lfine_epochs);
    %     flextoflex_end = reshape(e, length(e), 1);
    %     events = cat(1, events, [flextoflex_start, extension_start(1:length(flextoflex_start)), flextoflex_end]);
    % end
    % 
    % flexion_lengths   = events(:,2) - events(:,1);
    % extension_lengths = events(:,3) - events(:,2);
    % 
    % median_flexion_length = floor(median(flexion_lengths));
    % median_extension_length = floor(median(extension_lengths));
    % 
    % flexion_lower_lim = median_flexion_length - 3*floor(std(flexion_lengths));
    % flexion_upper_lim = median_flexion_length + 3*floor(std(flexion_lengths));
    % 
    % extension_lower_lim = median_extension_length - 3*floor(std(extension_lengths));
    % extension_upper_lim = median_extension_length + 3*floor(std(extension_lengths));
    % 
    % unnormal_epochs = [];
    % for j = 1:length(Trials_Info)
    %     kk = 0;
    %     for k = 1:length(Main_data{1, j}.Signal)
    % 
    %         if isempty(Main_data{1, j}.Signal{1, k})
    %             continue
    %         end
    % 
    %         Main_data{1, j}.Signal_TimeWarped{1, k} = [];
    % 
    %         L_Flx = Trials_Info{1, j}.Events.EMG_stream.extension_start_indx(k) - ...
    %             Trials_Info{1, j}.Events.EMG_stream.flextoflex_start_indx(k);
    %         L_Ext = Trials_Info{1, j}.Events.EMG_stream.flextoflex_end_indx(k) - ...
    %             Trials_Info{1, j}.Events.EMG_stream.extension_start_indx(k);
    %         constraint1 = and(L_Flx > flexion_lower_lim, L_Flx < flexion_upper_lim);
    %         constraint2 = and(L_Ext > extension_lower_lim, L_Ext < extension_upper_lim);
    % 
    %         if constraint1 && constraint2
    %             kk = kk + 1;
    %             flexion_indexes = 1:L_Flx+1;
    %             extension_indexes = L_Flx+2:L_Flx+L_Ext+1;
    % 
    %             signal_old = Main_data{1, j}.Signal{1, k};
    %             flexion_part_old = signal_old(:, flexion_indexes);
    %             extension_part_old = signal_old(:, extension_indexes);
    % 
    %             new_flexion_part   = interp1(1:L_Flx+1, flexion_part_old', ...
    %                 linspace(1, L_Flx+1, median_flexion_length+1), "linear");
    %             new_extension_part = interp1(1:L_Ext, extension_part_old', ...
    %                 linspace(1, L_Ext, median_extension_length), "linear");
    % 
    %             Main_data{1, j}.Signal_TimeWarped{1, k} = ...
    %                 [new_flexion_part', new_extension_part'];
    % 
    %         else
    %             unnormal_epochs = cat(1, unnormal_epochs, [j,k]);
    %         end
    % 
    % 
    %     end
    %     Main_data{1, j}.Flexion_Extension_Lengths = ...
    %         [median_flexion_length, median_extension_length];
    % end

    


    %% Outlier Detection
    % features = cell(size(Main_data));
    % for j = 1:length(features)
    %     for k = 1:length(Main_data{1, j}.Signal)
    %         if isempty(Main_data{1, j}.Signal{1, k})
    %             continue
    %         end
    % 
    %         signal = Main_data{1, j}.Signal{1, k};
    %         features{1, j}{1, k} = OutlierDetection_features(signal);
    % 
    %     end
    % end
    % 
    % 
    % 
    % features_P1 = [];
    % features_P3 = [];
    % features_P6 = [];
    % 
    % P1_outlier_idx = [];
    % P3_outlier_idx = [];
    % P6_outlier_idx = [];
    % 
    % for j = 1:length(features)
    % 
    %     if isempty(features{1, j})
    %         continue
    %     end
    % 
    %     c = cellfun(@(x) isempty(x), features{1, j});
    %     empty_indexes = find(c == 1);
    %     indexes = setdiff(1:length(features{1, j}), empty_indexes);
    % 
    %     P = Main_data{1, j}.Pressure;
    %     switch P
    %         case 1
    %             features_P1 = cat(3, features_P1, features{1, j}{:});
    %             P1_outlier_idx = cat(2, P1_outlier_idx, ...
    %                 [indexes ; j*ones(size(indexes))]);
    %         case 3
    %             features_P3 = cat(3, features_P3, features{1, j}{:});
    %             P3_outlier_idx = cat(2, P3_outlier_idx, ...
    %                 [indexes ; j*ones(size(indexes))]);
    %         case 6
    %             features_P6 = cat(3, features_P6, features{1, j}{:});
    %             P6_outlier_idx = cat(2, P6_outlier_idx, ...
    %                 [indexes ; j*ones(size(indexes))]);
    %     end
    % 
    % end
    % 
    % outliers_P1 = OutlierDetection_MD_method(features_P1);
    % outliers_P3 = OutlierDetection_MD_method(features_P3);
    % outliers_P6 = OutlierDetection_MD_method(features_P6);



    %% Filling the outlier field in the Main_data structure

    % for j = 1:length(Main_data)
    %     Main_data{1, j}.Outlier = zeros(4, length(Main_data{1, j}.Signal));
    % end
    % 
    % for m = 1:4
    % 
    %     if ~isempty(outliers_P1{m, 1})
    %         for p = 1:length(outliers_P1{m, 1})
    %             trial_index = P1_outlier_idx(2, outliers_P1{m, 1}(p));
    %             epoch_index = P1_outlier_idx(1, outliers_P1{m, 1}(p));
    %             Main_data{1, trial_index}.Outlier(m, epoch_index) = 1;
    %         end
    %     end
    % 
    %     if ~isempty(outliers_P3{m, 1})
    %         for p = 1:length(outliers_P3{m, 1})
    %             trial_index = P3_outlier_idx(2, outliers_P3{m, 1}(p));
    %             epoch_index = P3_outlier_idx(1, outliers_P3{m, 1}(p));
    %             Main_data{1, trial_index}.Outlier(m, epoch_index) = 1;
    %         end
    %     end
    % 
    %     if ~isempty(outliers_P6{m, 1})
    %         for p = 1:length(outliers_P6{m, 1})
    %             trial_index = P6_outlier_idx(2, outliers_P6{m, 1}(p));
    %             epoch_index = P6_outlier_idx(1, outliers_P6{m, 1}(p));
    %             Main_data{1, trial_index}.Outlier(m, epoch_index) = 1;
    %         end
    %     end
    % 
    % end


    %% plot and save figures of muscle activity for three pressure conditions
    % EMG_figures




    %% Extracting the EMG features for later classification
    % % features are basically RMS values of 4 righ leg muscles
    % % (flexion/extension phases) --> 1*8 feature vector
    % 
    % outlier_indicator = 0;
    % 
    % for j = 1:length(Main_data)
    % 
    %     m1_flexion_feaure = [];
    %     m1_extension_feature = [];
    %     m2_flexion_feaure = [];
    %     m2_extension_feature = [];
    %     m3_flexion_feaure = [];
    %     m3_extension_feature = [];
    %     m4_flexion_feaure = [];
    %     m4_extension_feature = [];
    % 
    %     for k = 1:length(Main_data{1, j}.Signal_TimeWarped)
    %         if isempty(Main_data{1, j}.Signal_TimeWarped{1, k})
    %             continue
    %         end
    % 
    %         S = Main_data{1, j}.Signal_TimeWarped{1, k};
    % 
    %         if Main_data{1, j}.Outlier(1, k) == 0
    %             m1_flexion_feaure = cat(2, m1_flexion_feaure, rms(S(1, 1:median_flexion_length+1)'));
    %             m1_extension_feature = cat(2, m1_extension_feature, rms(S(1, median_flexion_length+2:end)'));
    %         end
    % 
    %         if Main_data{1, j}.Outlier(2, k) == 0
    %             m2_flexion_feaure = cat(2, m2_flexion_feaure, rms(S(2, 1:median_flexion_length+1)'));
    %             m2_extension_feature = cat(2, m2_extension_feature, rms(S(2, median_flexion_length+2:end)'));
    %         end
    % 
    %         if Main_data{1, j}.Outlier(3, k) == 0
    %             m3_flexion_feaure = cat(2, m3_flexion_feaure, rms(S(3, 1:median_flexion_length+1)'));
    %             m3_extension_feature = cat(2, m3_extension_feature, rms(S(3, median_flexion_length+2:end)'));
    %         end
    % 
    %         if Main_data{1, j}.Outlier(4, k) == 0
    %             m4_flexion_feaure = cat(2, m4_flexion_feaure, rms(S(4, 1:median_flexion_length+1)'));
    %             m4_extension_feature = cat(2, m4_extension_feature, rms(S(4, median_flexion_length+2:end)'));
    %         end
    % 
    % 
    %     end
    % 
    %     final_features = [mean(m1_flexion_feaure), mean(m1_extension_feature), ...
    %                       mean(m2_flexion_feaure), mean(m2_extension_feature), ...
    %                       mean(m3_flexion_feaure), mean(m3_extension_feature), ...
    %                       mean(m4_flexion_feaure), mean(m4_extension_feature)];
    %     if any(isnan(final_features))
    %         outlier_indicator = outlier_indicator + 1;
    %         continue
    %     end
    % 
    %     Main_data{1, j}.Classification_Features.per_trial = final_features;
    % 
    % end
    % disp([num2str(outlier_indicator), ' trials were rejected in subject', num2str(subjects_list(i))])
    

    %% Saving EMG sructured data 
    if ~isfolder([EMG_processing_path, '\structured_EMG_data\sub-', num2str(subjects_list(i))])
        mkdir([EMG_processing_path, '\structured_EMG_data'], ['sub-', num2str(subjects_list(i))]);
    end

    filepath = [EMG_processing_path, '\structured_EMG_data\sub-', num2str(subjects_list(i))];
    filename = ['sub-', num2str(subjects_list(i)), '_structured_EMG_data.mat'];
    save(fullfile(filepath, filename), 'Main_data', '-v7.3');


    %% Free up the memory
    % clear data Main_data Trials_Info

end