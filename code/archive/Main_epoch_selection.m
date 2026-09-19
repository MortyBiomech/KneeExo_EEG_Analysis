function Main_epoch_selection(input_streams, EEG, Trials_Info, ...
    EMG_sensor_id, subject_id, data_path)

    % %% Trials_Based epoch selection (takes time to save the mat file!)
    % clc;
    % main_epoch_selection_TrialsBased(input_streams, EEG, Trials_Info, ...
    %     EMG_sensor_id, subject_id, data_path);
    % 
    % 
    % %% Flexion_Based epoch selection (takes time to save the mat file!)
    % clc;
    % main_epoch_selection_FlexionsBased(input_streams, EEG, Trials_Info, ...
    %     EMG_sensor_id, subject_id, data_path);
    % 
    % 
    % %% Extension_Based epoch selection (takes time to save the mat file!)
    % clc;
    % main_epoch_selection_ExtensionsBased(input_streams, EEG, Trials_Info, ...
    %     EMG_sensor_id, subject_id, data_path);
    
    
    %% FlextoFlex_Based epoch selection (takes time to save the mat file!)
    clc;
    main_epoch_selection_FlextoFlexBased(input_streams, EEG, Trials_Info, ...
        EMG_sensor_id, subject_id, data_path);


end