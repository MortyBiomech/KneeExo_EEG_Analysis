function main_epoch_selection_TrialsBased(input_streams, ...
                                          EEG, ...
                                          Trials_Info, ...
                                          EMG_sensor_id, ...
                                          subject_id, ...
                                          data_path)
    
    %% Extract data
    All_EEG = input_streams.All_EEG;
    All_EEG_time = input_streams.All_EEG_time;
    All_EMG = input_streams.All_EMG;
    All_EMG_time = input_streams.All_EMG_time;
    All_Experiment = input_streams.All_Exp;
    All_Experiment_time = input_streams.All_Exp_time;


    %% EEG Preprocessed data
    channel_data = EEG.data;
    source_data = EEG.icaact;


    %% Initialize the structures
    EEG_Raw_Time_Domain_Structure = struct('Times', [], 'Channels', []);
    
    EEG_Preprocessed_Time_Domain_Structure = ...
        struct('Times', [], 'Channels', [], 'Sources', []);
    
    EEG_stream = struct('Raw', EEG_Raw_Time_Domain_Structure, ...
        'Preprocessed', EEG_Preprocessed_Time_Domain_Structure);
    
    EMG_Structure = ...
        struct('Times', [], ...
               'Sensors_Raw', [], ...
               'Sensors_Preprocessed', []);
    
    EXP_structure = ...
        struct('Times', [], ...
               'Force', [], ...
               'Encoder_angle', [], ...
               'Ref_angle', []);
    
    Final_based_Structure = ...
        struct('General', [], ...
               'EEG_stream', EEG_stream, ...
               'EMG_stream', EMG_Structure, ...
               'EXP_stream', EXP_structure);
    
    Epochs_Trial_based = repmat({Final_based_Structure}, ...
        1, length(Trials_Info));


    %% Filling the General field
    Muscles_names={'Vastus_med_R', 'Rectus_femoris_R', ...
                   'Gastrocnemius_R', 'Biceps_femoris_R', ...
                   'Trapezius_R', 'Trapezius_L'};
    for i = 1:length(Trials_Info)
        Epochs_Trial_based{1, i}.General = Trials_Info{1, i}.General;
        Epochs_Trial_based{1, i}.General.Muscles_Names = Muscles_names;
    end
   

    %% Processing EMG stream
    % (1) Bandpass filter 20-450 Hz
    Fs_EMG = 2000;  % Sampling frequency
    Fn     = Fs_EMG/2;  % Nyquist frequency is 1/2 sampling frequency
    low_freq  = 20;
    high_freq = 450;
    order     = 4;
    % determine filter coefficients
    [b,a] = butter(order, ([low_freq high_freq]/Fn)); 
    All_EMG_filt = filtfilt(b, a, All_EMG'); 
    
    % (2) rectification
    All_EMG_rect = abs(All_EMG_filt);
    
    % (3) Lowpass filter
    fc    = 4; % Cut-off frequency (Hz)
    order = 2; % Filter order
    [b,a] = butter(order, fc/Fn);
    All_EMG_filt = filtfilt(b, a, All_EMG_rect); 
    All_EMG_filt = All_EMG_filt';
    
    
   

    %% Loop over trials 
    % EEG: Time Domain, Raw (Channels) & Preprocessed (Channels, Sources)
    % EMG: Muscle Names, Sensor Raw and Processed data
    % EXP: Force sensor, encoder and ref angles
    disp('Trials_Based epoch selection: Loop over trials ...')
    for i = 1:length(Trials_Info)
        
        if ~endsWith(Trials_Info{1, i}.General.Description, 'Data Loss')
            
            %% EEG_stream.Raw.Time_Domain
            start_indx = ...
                Trials_Info{1, i}.Events.EEG_stream.Raw.Trial_start_indx;
            end_indx = ...
                Trials_Info{1, i}.Events.EEG_stream.Raw.Trial_end_indx;
            Epochs_Trial_based{1, i}.EEG_stream.Raw.Times = ...
                All_EEG_time(start_indx:end_indx);
            Epochs_Trial_based{1, i}.EEG_stream.Raw.Channels = ...
                All_EEG(:, start_indx:end_indx);
            
        
            %% EEG_stream.Preprocessed.Time_Domain
            start_indx = ...
                Trials_Info{1, i}.Events.EEG_stream.Preprocessed.Trial_start_indx;
            end_indx = ...
                Trials_Info{1, i}.Events.EEG_stream.Preprocessed.Trial_end_indx;
            Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Times = ...
                EEG.times(start_indx:end_indx);
            Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Channels = ...
                channel_data(:, start_indx:end_indx);
            Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Sources = ...
                source_data(:, start_indx:end_indx);
        

            %% EMG_stream
            start_indx = ...
                Trials_Info{1, i}.Events.EMG_stream.Trial_start_indx;
            end_indx = ...
                Trials_Info{1, i}.Events.EMG_stream.Trial_end_indx;
            Epochs_Trial_based{1, i}.EMG_stream.Times = ...
                All_EMG_time(start_indx:end_indx);
            Epochs_Trial_based{1, i}.EMG_stream.Sensors_Raw = ...
                All_EMG(EMG_sensor_id, start_indx:end_indx);
            Epochs_Trial_based{1, i}.EMG_stream.Sensors_Preprocessed = ...
                All_EMG_filt(EMG_sensor_id, start_indx:end_indx);
            
        
            %% EXP stream
            start_indx = ...
                Trials_Info{1, i}.Events.EXP_stream.Trial_start_indx;
            end_indx = ...
                Trials_Info{1, i}.Events.EXP_stream.Trial_end_indx;
            Epochs_Trial_based{1, i}.EXP_stream.Times = ...
                All_Experiment_time(start_indx : end_indx);
            Epochs_Trial_based{1, i}.EXP_stream.Force = ...
                All_Experiment(5, start_indx : end_indx);
            Epochs_Trial_based{1, i}.EXP_stream.Encoder_angle = ...
                All_Experiment(1, start_indx : end_indx);
            % adjust for demonstration change of time (5 seconds in Encoder.m file)
            [~, start_indx_ref] = min(abs(All_Experiment_time - ...
                (All_Experiment_time(start_indx) - 5)));
            % refrence angle data
            Epochs_Trial_based{1, i}.EXP_stream.Ref_angle = ...
                All_Experiment(2, start_indx_ref : start_indx_ref + (end_indx - start_indx));
        
           
        end

    end

    disp('Trials_Based epoch selection: Loop over trials done!')
    
    %% save Epochs_Trial_based structure
    disp('Trials_Based epoch selection: Saving the MAT file ...')
    save_path = [data_path, '6_Trials_Info_and_Epoched_data\', ...
        'sub-', num2str(subject_id)];
    save(fullfile(save_path, 'Epochs_Trial_based.mat'), 'Epochs_Trial_based', '-v7.3');
    
end