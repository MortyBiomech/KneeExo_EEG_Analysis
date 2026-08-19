function T = create_the_main_table(allBeh, eegfeatures)

    x = str2double(string(allBeh.SubjectID));
    allBeh.Subject = x;
    
    subject_list       = 5:18;
    Subject            = [];
    Trial              = [];
    Pressure           = [];
    
    Error              = [];
    VastusMed_all      = [];
    Recfem_all         = [];
    Gastroc_all        = [];
    BicepsFem_all      = [];
    FlexorIndx_all     = [];
    ExtensorIndx_all   = [];
    EffortIndx_all     = [];
    
    Alpha_LM1_all      = [];
    Beta_LM1_all       = [];
    Alpha_flx_LM1_all  = [];
    Alpha_ext_LM1_all  = [];
    Beta_flx_LM1_all   = [];
    Beta_ext_LM1_all   = [];
    Alpha_RM1_all      = [];
    Beta_RM1_all       = [];
    Alpha_flx_RM1_all  = [];
    Alpha_ext_RM1_all  = [];
    Beta_flx_RM1_all   = [];
    Beta_ext_RM1_all   = [];

    Alpha_roi_LM1_all      = [];
    Beta_roi_LM1_all       = [];
    Alpha_flx_roi_LM1_all  = [];
    Alpha_ext_roi_LM1_all  = [];
    Beta_flx_roi_LM1_all   = [];
    Beta_ext_roi_LM1_all   = [];
    Alpha_roi_RM1_all      = [];
    Beta_roi_RM1_all       = [];
    Alpha_flx_roi_RM1_all  = [];
    Alpha_ext_roi_RM1_all  = [];
    Beta_flx_roi_RM1_all   = [];
    Beta_ext_roi_RM1_all   = [];
    
    Score_all          = [];
    
    for sub = 1:length(subject_list)
    
        if subject_list(sub) == 10
            continue
        end
    
        sub_idx_Beh = find(allBeh.Subject == subject_list(sub));
        
        sub_Beh_table = allBeh(sub_idx_Beh, :);
        trials_Beh = allBeh.Trial(sub_idx_Beh);
        if isempty(eegfeatures{sub, 1}) && isempty(eegfeatures{sub, 2})
            % fill the main table based on Behaviour features
            % this subject has no EEG features
            trials_EEG = trials_Beh;
            flag = 11;
        else
            % fill the main table based on the intersection of Behaviour
            % and EEG features
            if ~isempty(eegfeatures{sub, 1}) && isempty(eegfeatures{sub, 2})
                % this subject just has the left M1 EEG features
                trials_EEG = eegfeatures{sub, 1}.Trial;
                flag = 121;
            elseif isempty(eegfeatures{sub, 1}) && ~isempty(eegfeatures{sub, 2})
                % this subject just has the right M1 EEG features
                trials_EEG = eegfeatures{sub, 2}.Trial;
                flag = 122;
            else
                % this subject just both left and right M1 EEG features
                trials_EEG = eegfeatures{sub, 1}.Trial;
                flag = 123;
            end
        end
        [C, i_beh, i_eeg] = intersect(trials_Beh, trials_EEG);
        
        
        % filling the behavior columns
        if flag == 11
            rows = 1:size(sub_Beh_table, 1);
        else
            rows = i_beh;
        end
        Cond = str2double(string(sub_Beh_table.Pressure(rows)));
        err  = sub_Beh_table.Error(rows);
        vastusMed = sub_Beh_table.VastusMed(rows);
        recfem = sub_Beh_table.Recfem(rows);
        gastroc = sub_Beh_table.Gastroc(rows);
        bicepsFem = sub_Beh_table.BicepFem(rows);
        flexorIndx = sub_Beh_table.FlexorIndex(rows);
        extensorIndx = sub_Beh_table.ExtensorIndex(rows);
        effortIndx = sub_Beh_table.EffortIndex(rows);
        
        
        % filling the EEG part
        switch flag
            case 11
                % Left M1
                alpha_LM1 = nan(length(i_eeg), 1);
                beta_LM1 = nan(length(i_eeg), 1);
                alpha_flx_LM1 = nan(length(i_eeg), 1);
                alpha_ext_LM1 = nan(length(i_eeg), 1);
                beta_flx_LM1 = nan(length(i_eeg), 1);
                beta_ext_LM1 = nan(length(i_eeg), 1);
                % Rigth M1
                alpha_RM1 = nan(length(i_eeg), 1);
                beta_RM1 = nan(length(i_eeg), 1);
                alpha_flx_RM1 = nan(length(i_eeg), 1);
                alpha_ext_RM1 = nan(length(i_eeg), 1);
                beta_flx_RM1 = nan(length(i_eeg), 1);
                beta_ext_RM1 = nan(length(i_eeg), 1);

                % Left M1 ROI
                alpha_roi_LM1 = nan(length(i_eeg), 1);
                beta_roi_LM1 = nan(length(i_eeg), 1);
                alpha_flx_roi_LM1 = nan(length(i_eeg), 1);
                alpha_ext_roi_LM1 = nan(length(i_eeg), 1);
                beta_flx_roi_LM1 = nan(length(i_eeg), 1);
                beta_ext_roi_LM1 = nan(length(i_eeg), 1);
                % Rigth M1 ROI
                alpha_roi_RM1 = nan(length(i_eeg), 1);
                beta_roi_RM1 = nan(length(i_eeg), 1);
                alpha_flx_roi_RM1 = nan(length(i_eeg), 1);
                alpha_ext_roi_RM1 = nan(length(i_eeg), 1);
                beta_flx_roi_RM1 = nan(length(i_eeg), 1);
                beta_ext_roi_RM1 = nan(length(i_eeg), 1);
            case 121
                % this subject just has the left M1 EEG features
                % Left M1
                alpha_LM1 = eegfeatures{sub, 1}.Alpha(i_eeg);
                beta_LM1 = eegfeatures{sub, 1}.Beta(i_eeg);
                alpha_flx_LM1 = eegfeatures{sub, 1}.Alpha_Flx(i_eeg);
                alpha_ext_LM1 = eegfeatures{sub, 1}.Alpha_Ext(i_eeg);
                beta_flx_LM1 = eegfeatures{sub, 1}.Beta_Flx(i_eeg);
                beta_ext_LM1 = eegfeatures{sub, 1}.Beta_Ext(i_eeg);
                % Rigth M1
                alpha_RM1 = nan(length(i_eeg), 1);
                beta_RM1 = nan(length(i_eeg), 1);
                alpha_flx_RM1 = nan(length(i_eeg), 1);
                alpha_ext_RM1 = nan(length(i_eeg), 1);
                beta_flx_RM1 = nan(length(i_eeg), 1);
                beta_ext_RM1 = nan(length(i_eeg), 1);

                % Left M1 ROI
                alpha_roi_LM1 = eegfeatures{sub, 1}.Alpha_roi(i_eeg);
                beta_roi_LM1 = eegfeatures{sub, 1}.Beta_roi(i_eeg);
                alpha_flx_roi_LM1 = eegfeatures{sub, 1}.Alpha_Flx_roi(i_eeg);
                alpha_ext_roi_LM1 = eegfeatures{sub, 1}.Alpha_Ext_roi(i_eeg);
                beta_flx_roi_LM1 = eegfeatures{sub, 1}.Beta_Flx_roi(i_eeg);
                beta_ext_roi_LM1 = eegfeatures{sub, 1}.Beta_Ext_roi(i_eeg);
                % Rigth M1 ROI
                alpha_roi_RM1 = nan(length(i_eeg), 1);
                beta_roi_RM1 = nan(length(i_eeg), 1);
                alpha_flx_roi_RM1 = nan(length(i_eeg), 1);
                alpha_ext_roi_RM1 = nan(length(i_eeg), 1);
                beta_flx_roi_RM1 = nan(length(i_eeg), 1);
                beta_ext_roi_RM1 = nan(length(i_eeg), 1);
            case 122
                % this subject just has the right M1 EEG features
                % Left M1
                alpha_LM1 = nan(length(i_eeg), 1);
                beta_LM1 = nan(length(i_eeg), 1);
                alpha_flx_LM1 = nan(length(i_eeg), 1);
                alpha_ext_LM1 = nan(length(i_eeg), 1);
                beta_flx_LM1 = nan(length(i_eeg), 1);
                beta_ext_LM1 = nan(length(i_eeg), 1);
                % Rigth M1
                alpha_RM1 = eegfeatures{sub, 2}.Alpha(i_eeg);
                beta_RM1 = eegfeatures{sub, 2}.Beta(i_eeg);
                alpha_flx_RM1 = eegfeatures{sub, 2}.Alpha_Flx(i_eeg);
                alpha_ext_RM1 = eegfeatures{sub, 2}.Alpha_Ext(i_eeg);
                beta_flx_RM1 = eegfeatures{sub, 2}.Beta_Flx(i_eeg);
                beta_ext_RM1 = eegfeatures{sub, 2}.Beta_Ext(i_eeg);

                % Left M1 ROI
                alpha_roi_LM1 = nan(length(i_eeg), 1);
                beta_roi_LM1 = nan(length(i_eeg), 1);
                alpha_flx_roi_LM1 = nan(length(i_eeg), 1);
                alpha_ext_roi_LM1 = nan(length(i_eeg), 1);
                beta_flx_roi_LM1 = nan(length(i_eeg), 1);
                beta_ext_roi_LM1 = nan(length(i_eeg), 1);
                % Rigth M1 ROI
                alpha_roi_RM1 = eegfeatures{sub, 2}.Alpha_roi(i_eeg);
                beta_roi_RM1 = eegfeatures{sub, 2}.Beta_roi(i_eeg);
                alpha_flx_roi_RM1 = eegfeatures{sub, 2}.Alpha_Flx_roi(i_eeg);
                alpha_ext_roi_RM1 = eegfeatures{sub, 2}.Alpha_Ext_roi(i_eeg);
                beta_flx_roi_RM1 = eegfeatures{sub, 2}.Beta_Flx_roi(i_eeg);
                beta_ext_roi_RM1 = eegfeatures{sub, 2}.Beta_Ext_roi(i_eeg);
            case 123
                % this subject just both left and right M1 EEG features
                % Left M1
                alpha_LM1 = eegfeatures{sub, 1}.Alpha(i_eeg);
                beta_LM1 = eegfeatures{sub, 1}.Beta(i_eeg);
                alpha_flx_LM1 = eegfeatures{sub, 1}.Alpha_Flx(i_eeg);
                alpha_ext_LM1 = eegfeatures{sub, 1}.Alpha_Ext(i_eeg);
                beta_flx_LM1 = eegfeatures{sub, 1}.Beta_Flx(i_eeg);
                beta_ext_LM1 = eegfeatures{sub, 1}.Beta_Ext(i_eeg);
                % Rigth M1
                alpha_RM1 = eegfeatures{sub, 2}.Alpha(i_eeg);
                beta_RM1 = eegfeatures{sub, 2}.Beta(i_eeg);
                alpha_flx_RM1 = eegfeatures{sub, 2}.Alpha_Flx(i_eeg);
                alpha_ext_RM1 = eegfeatures{sub, 2}.Alpha_Ext(i_eeg);
                beta_flx_RM1 = eegfeatures{sub, 2}.Beta_Flx(i_eeg);
                beta_ext_RM1 = eegfeatures{sub, 2}.Beta_Ext(i_eeg);

                % Left M1 ROI
                alpha_roi_LM1 = eegfeatures{sub, 1}.Alpha_roi(i_eeg);
                beta_roi_LM1 = eegfeatures{sub, 1}.Beta_roi(i_eeg);
                alpha_flx_roi_LM1 = eegfeatures{sub, 1}.Alpha_Flx_roi(i_eeg);
                alpha_ext_roi_LM1 = eegfeatures{sub, 1}.Alpha_Ext_roi(i_eeg);
                beta_flx_roi_LM1 = eegfeatures{sub, 1}.Beta_Flx_roi(i_eeg);
                beta_ext_roi_LM1 = eegfeatures{sub, 1}.Beta_Ext_roi(i_eeg);
                % Rigth M1 ROI
                alpha_roi_RM1 = eegfeatures{sub, 2}.Alpha_roi(i_eeg);
                beta_roi_RM1 = eegfeatures{sub, 2}.Beta_roi(i_eeg);
                alpha_flx_roi_RM1 = eegfeatures{sub, 2}.Alpha_Flx_roi(i_eeg);
                alpha_ext_roi_RM1 = eegfeatures{sub, 2}.Alpha_Ext_roi(i_eeg);
                beta_flx_roi_RM1 = eegfeatures{sub, 2}.Beta_Flx_roi(i_eeg);
                beta_ext_roi_RM1 = eegfeatures{sub, 2}.Beta_Ext_roi(i_eeg);
        end
        
        score = sub_Beh_table.Score(rows);
        
        % filling the main table
        Subject = cat(1, Subject, repmat(subject_list(sub), length(C), 1));
        Trial = cat(1, Trial, C);
        Pressure = cat(1, Pressure, Cond);
        
        Error = cat(1, Error, err);
        VastusMed_all = cat(1, VastusMed_all, vastusMed);
        Recfem_all = cat(1, Recfem_all, recfem);
        Gastroc_all = cat(1, Gastroc_all, gastroc);
        BicepsFem_all = cat(1, BicepsFem_all, bicepsFem);
        FlexorIndx_all = cat(1, FlexorIndx_all, flexorIndx);
        ExtensorIndx_all = cat(1, ExtensorIndx_all, extensorIndx);
        EffortIndx_all = cat(1, EffortIndx_all, effortIndx);
        
        
        Alpha_LM1_all = cat(1, Alpha_LM1_all, alpha_LM1);
        Beta_LM1_all = cat(1, Beta_LM1_all, beta_LM1);
        Alpha_flx_LM1_all = cat(1, Alpha_flx_LM1_all, alpha_flx_LM1);
        Alpha_ext_LM1_all = cat(1, Alpha_ext_LM1_all, alpha_ext_LM1);
        Beta_flx_LM1_all = cat(1, Beta_flx_LM1_all, beta_flx_LM1);
        Beta_ext_LM1_all = cat(1, Beta_ext_LM1_all, beta_ext_LM1);
        Alpha_RM1_all = cat(1, Alpha_RM1_all, alpha_RM1);
        Beta_RM1_all = cat(1, Beta_RM1_all, beta_RM1);
        Alpha_flx_RM1_all = cat(1, Alpha_flx_RM1_all, alpha_flx_RM1);
        Alpha_ext_RM1_all = cat(1, Alpha_ext_RM1_all, alpha_ext_RM1);
        Beta_flx_RM1_all = cat(1, Beta_flx_RM1_all, beta_flx_RM1);
        Beta_ext_RM1_all = cat(1, Beta_ext_RM1_all, beta_ext_RM1);
        

        % ROI
        Alpha_roi_LM1_all = cat(1, Alpha_roi_LM1_all, alpha_roi_LM1);
        Beta_roi_LM1_all = cat(1, Beta_roi_LM1_all, beta_roi_LM1);
        Alpha_flx_roi_LM1_all = cat(1, Alpha_flx_roi_LM1_all, alpha_flx_roi_LM1);
        Alpha_ext_roi_LM1_all = cat(1, Alpha_ext_roi_LM1_all, alpha_ext_roi_LM1);
        Beta_flx_roi_LM1_all = cat(1, Beta_flx_roi_LM1_all, beta_flx_roi_LM1);
        Beta_ext_roi_LM1_all = cat(1, Beta_ext_roi_LM1_all, beta_ext_roi_LM1);
        Alpha_roi_RM1_all = cat(1, Alpha_roi_RM1_all, alpha_roi_RM1);
        Beta_roi_RM1_all = cat(1, Beta_roi_RM1_all, beta_roi_RM1);
        Alpha_flx_roi_RM1_all = cat(1, Alpha_flx_roi_RM1_all, alpha_flx_roi_RM1);
        Alpha_ext_roi_RM1_all = cat(1, Alpha_ext_roi_RM1_all, alpha_ext_roi_RM1);
        Beta_flx_roi_RM1_all = cat(1, Beta_flx_roi_RM1_all, beta_flx_roi_RM1);
        Beta_ext_roi_RM1_all = cat(1, Beta_ext_roi_RM1_all, beta_ext_roi_RM1);
        

        Score_all = cat(1, Score_all, score);
        
    end

    variableNames_all = {'Subject', 'Trial', 'Pressure', 'Error', ...
        'VastusMed', 'RecFem', 'Gastroc', 'BicepFem', ...
        'FlexorIndex', 'ExtensorIndex', 'EffortIndex', ...
        'Alpha_LM1', 'Beta_LM1', ...
        'Alpha_Flx_LM1', 'Alpha_Ext_LM1', 'Beta_Flx_LM1', 'Beta_Ext_LM1', ...
        'Alpha_RM1', 'Beta_RM1', ...
        'Alpha_Flx_RM1', 'Alpha_Ext_RM1', 'Beta_Flx_RM1', 'Beta_Ext_RM1', ...
        'Alpha_roi_LM1', 'Beta_roi_LM1', ...
        'Alpha_Flx_roi_LM1', 'Alpha_Ext_roi_LM1', 'Beta_Flx_roi_LM1', 'Beta_Ext_roi_LM1', ...
        'Alpha_roi_RM1', 'Beta_roi_RM1', ...
        'Alpha_Flx_roi_RM1', 'Alpha_Ext_roi_RM1', 'Beta_Flx_roi_RM1', 'Beta_Ext_roi_RM1', ...
        'Score'};

    T = table(Subject, Trial, Pressure, ...
        Error, VastusMed_all, Recfem_all, Gastroc_all, BicepsFem_all, ...
        FlexorIndx_all, ExtensorIndx_all, EffortIndx_all, ...
        Alpha_LM1_all, Beta_LM1_all, ...
        Alpha_flx_LM1_all, Alpha_ext_LM1_all, ...
        Beta_flx_LM1_all, Beta_ext_LM1_all, ...
        Alpha_RM1_all, Beta_RM1_all, ...
        Alpha_flx_RM1_all, Alpha_ext_RM1_all, ...
        Beta_flx_RM1_all, Beta_ext_RM1_all, ...
        Alpha_roi_LM1_all, Beta_roi_LM1_all, ...
        Alpha_flx_roi_LM1_all, Alpha_ext_roi_LM1_all, ...
        Beta_flx_roi_LM1_all, Beta_ext_roi_LM1_all, ...
        Alpha_roi_RM1_all, Beta_roi_RM1_all, ...
        Alpha_flx_roi_RM1_all, Alpha_ext_roi_RM1_all, ...
        Beta_flx_roi_RM1_all, Beta_ext_roi_RM1_all, ...
        Score_all, ...
        'VariableNames', variableNames_all);

end