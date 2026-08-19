function T = create_the_main_table_wholeBrain(allBeh, eegfeatures)

    studyNames = {'Left Dorsal ACC', 'Left Parieto Occipital', ...
        'Left PreMot SuppMot', 'Left Prim Motor', ...
        'Right Parieto Occipital', 'Right PreMot SuppMot', ...
        'Right Prim Motor'};
    studyNames_und = cellfun(@(x) strrep(x, ' ', '_'), studyNames, ...
        'UniformOutput', false);
    fieldNames = eegfeatures{1,1}.Properties.VariableNames;
    fieldNames = fieldNames(1, 4:end);

    S = string(studyNames_und(:));      % 7x1
    B = string(fieldNames(:)).';        % 1x6

    names_mat   = S + "_" + B;      % 7x6 (implicit expansion)
    studyNamesB = cellstr(reshape(names_mat.', 1, []));  % 1x42, ordered per study


    subject_list       = 5:18;

    Trial_all          = [];
    Subject_all        = [];

    Pressure           = [];
    Error              = [];
    VastusMed_all      = [];
    Recfem_all         = [];
    Gastroc_all        = [];
    BicepsFem_all      = [];
    FlexorIndx_all     = [];
    ExtensorIndx_all   = [];
    EffortIndx_all     = [];

    EEG_features_all   = [];

    Score_all          = [];

    for sub = 1:length(subject_list)

        if subject_list(sub) == 10
            continue
        end

        trial_beh = allBeh.Trial(allBeh.SubjectID == ...
            categorical(string(subject_list(sub))));

        idx_nonempty = cellfun(@(x) ~isempty(x), eegfeatures(sub, :));
        idx_nonempty_1 = find(idx_nonempty, 1);
        trial_eeg = eegfeatures{sub, idx_nonempty_1}.Trial;

        [C, i_beh, i_eeg] = intersect(trial_beh, trial_eeg);

        
        Subject_all = cat(1, Subject_all, ...
            repmat(subject_list(sub), length(C), 1));
        Trial_all = cat(1, Trial_all, C);


        subj_idx_beh = find(allBeh.SubjectID == ...
            categorical(string(subject_list(sub))));
        Pressure = cat(1, Pressure, allBeh.Pressure(subj_idx_beh(i_beh)));
        Error = cat(1, Error, allBeh.Error(subj_idx_beh(i_beh)));
        VastusMed_all = cat(1, VastusMed_all, allBeh.VastusMed(subj_idx_beh(i_beh)));
        Recfem_all = cat(1, Recfem_all, allBeh.Recfem(subj_idx_beh(i_beh)));
        Gastroc_all = cat(1, Gastroc_all, allBeh.Gastroc(subj_idx_beh(i_beh)));
        BicepsFem_all = cat(1, BicepsFem_all, allBeh.BicepFem(subj_idx_beh(i_beh)));
        FlexorIndx_all = cat(1, FlexorIndx_all, allBeh.FlexorIndex(subj_idx_beh(i_beh)));
        ExtensorIndx_all = cat(1, ExtensorIndx_all, allBeh.ExtensorIndex(subj_idx_beh(i_beh)));
        EffortIndx_all = cat(1, EffortIndx_all, allBeh.EffortIndex(subj_idx_beh(i_beh)));


        EEG_features_s = [];
        for c = 1:length(idx_nonempty)
            if idx_nonempty(c) == 1
                EEG_features_s = cat(2, EEG_features_s, ...
                    [eegfeatures{sub, c}.Theta(i_eeg), ...
                     eegfeatures{sub, c}.Theta_log(i_eeg), ...
                     eegfeatures{sub, c}.Alpha(i_eeg), ...
                     eegfeatures{sub, c}.Alpha_log(i_eeg), ...
                     eegfeatures{sub, c}.Beta(i_eeg), ...
                     eegfeatures{sub, c}.Beta_log(i_eeg)]);
            else
                EEG_features_s = cat(2, EEG_features_s, ...
                    nan(length(i_eeg), 6));
            end
        end

        EEG_features_all = cat(1, EEG_features_all, EEG_features_s);


        Score_all = cat(1, Score_all, allBeh.Score(subj_idx_beh(i_beh)));
    
    end



    variableNames_all = [{'Subject'}, {'Trial'}, {'Pressure'}, {'Error'}, ...
        {'VastusMed'}, {'RecFem'}, {'Gastroc'}, {'BicepFem'}, ...
        {'FlexorIndex'}, {'ExtensorIndex'}, {'EffortIndex'}, ...
        studyNamesB(:)', ...
        {'Score'}];

    Pressure = str2double(string(Pressure));
    variables = [Subject_all, Trial_all, Pressure, Error, ...
        VastusMed_all, Recfem_all, Gastroc_all, BicepsFem_all, ...
        FlexorIndx_all, ExtensorIndx_all, EffortIndx_all, ...
        EEG_features_all, Score_all];


    T = array2table(variables, 'VariableNames', variableNames_all);
    T.Subject_cat = categorical(T.Subject);
    T.Pressure_cat = categorical(T.Pressure);

end