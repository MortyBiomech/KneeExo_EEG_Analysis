function EMG_subjects = load_emg_data(final_EMG_data_path, current_path)

    cd(final_EMG_data_path)

    load EMG_Data_timewarped.mat EMG_Data_timewarped
    data = EMG_Data_timewarped.data;
    % warpingto = EMG_Data_timewarped.final_warpingto;
    % muscles_name = EMG_Data_timewarped.Muscle_Name;
    % muscles_name = cellfun(@(x) strrep(x, '_', ' '), muscles_name, ...
    %     'UniformOutput', false);
    clear EMG_Data_timewarped
    
    cd(current_path)
    
    % -------------------------------
    % Normalize iEMG data per subject
    % -------------------------------
    subject_list = 5:18;
    inner_struct = struct('pressure', [], 'score', [], ...
        'iEMG_norm', [], 'iEMG_nonNorm', [], ...
        'EMG_norm', [], 'EMG_nonNorm', [], 'trial', []);
    EMG_subjects = repmat({inner_struct}, length(subject_list), 1);
    
    for sub = 1:length(subject_list)
        
        if strcmp(data{sub, 1}, 'Sub 10'), continue; end
    
        disp(['EMG normalization, Subject ', num2str(subject_list(sub))])
        
        pressure = cellfun(@(x) x(1), data{sub, 2}.pressure, ...
            'UniformOutput', false);
        pressure = cell2mat(pressure);
    
        score = cellfun(@(x) x(1), data{sub, 2}.score, ...
            'UniformOutput', false);
        score = cell2mat(score);
    
        trial_epoch = data{sub, 2}.trial_epoch;
        unique_trial_index = unique(trial_epoch(:, 1));
    
        % mark outliers and remove them
        iEMG = cellfun(@(x) mean(x, 1), data{sub, 2}.iEMG, ...
            'UniformOutput', false);
        iEMG = cell2mat(iEMG);
    
        EMG = cellfun(@(x) mean(cat(3, x{:}), 3), data{sub, 2}.EMG, ...
            'UniformOutput', false);
        EMG = cat(3, EMG{:});
    
        [iEMG_p1_indx ~] = find(pressure == 1);
        iEMG_p1 = iEMG(iEMG_p1_indx, :);
        iEMG_outlier_p1 = isoutlier(iEMG_p1, "median", 1, "ThresholdFactor", 3);
        indx_to_remove_p1 = find(any(iEMG_outlier_p1, 2));
        if ~isempty(indx_to_remove_p1)
            trials_to_remove_p1 = iEMG_p1_indx(indx_to_remove_p1);
        else
            trials_to_remove_p1 = [];
        end
        if max(max(iEMG_p1)) > 10
            disp(['subject ', num2str(sub)])
        end
    
        [iEMG_p3_indx ~] = find(pressure == 3);
        iEMG_p3 = iEMG(iEMG_p3_indx, :);
        iEMG_outlier_p3 = isoutlier(iEMG_p3, "median", 1, "ThresholdFactor", 3);
        indx_to_remove_p3 = find(any(iEMG_outlier_p3, 2));
        if ~isempty(indx_to_remove_p3)
            trials_to_remove_p3 = iEMG_p3_indx(indx_to_remove_p3);
        else
            trials_to_remove_p3 = [];
        end
        if max(max(iEMG_p3)) > 10
            disp(['subject ', num2str(sub)])
        end
    
        [iEMG_p6_indx ~] = find(pressure == 6);
        iEMG_p6 = iEMG(iEMG_p6_indx, :);
        iEMG_outlier_p6 = isoutlier(iEMG_p6, "median", 1, "ThresholdFactor", 3);
        indx_to_remove_p6 = find(any(iEMG_outlier_p6, 2));
        if ~isempty(indx_to_remove_p6)
            trials_to_remove_p6 = iEMG_p6_indx(indx_to_remove_p6);
        else
            trials_to_remove_p6 = [];
        end
        if max(max(iEMG_p6)) > 10
            disp(['subject ', num2str(sub)])
        end
    
        trials_to_remove = [trials_to_remove_p1; ...
                            trials_to_remove_p3; ...
                            trials_to_remove_p6];
    
        if ~isempty(trials_to_remove)
            indx_to_remove_trial_epoch = [];
            for t = 1:length(trials_to_remove)
                indx = find(trial_epoch(:, 1) == unique_trial_index(trials_to_remove(t)));
                indx_to_remove_trial_epoch = cat(1, ...
                    indx_to_remove_trial_epoch, indx);
            end
        end
        trial_epoch(indx_to_remove_trial_epoch, :) = [];
    
        iEMG(trials_to_remove, :) = [];
        pressure(trials_to_remove) = [];
        score(trials_to_remove) = [];
        EMG(:, :, trials_to_remove) = [];
    
        EMG_subjects{sub}.pressure = pressure;
        EMG_subjects{sub}.score = score;
    
    
        % normalize the iEMG values to the whole trials mean (all conditions)
        iEMG_mean = mean(iEMG, 1);
        iEMG_norm = iEMG./repmat(iEMG_mean, size(iEMG, 1), 1);
        if max(max(iEMG_norm)) > 10
            disp(['Check! Check! Check! subject ', num2str(sub)])
        end
    
    
        EMG_mean = mean( mean(EMG, 3), 2 );
        EMG_norm = EMG./repmat(EMG_mean, 1, size(EMG, 2), size(EMG, 3));
    
        EMG_subjects{sub}.iEMG_norm = iEMG_norm;
        EMG_subjects{sub}.iEMG_nonNorm = iEMG;
        EMG_subjects{sub}.EMG_norm = EMG_norm;
        EMG_subjects{sub}.EMG_nonNorm = EMG;
        EMG_subjects{sub}.trial = unique(trial_epoch(:, 2));
    
    end

end