function main_epoch_selection_FlextoFlexBased(input_streams, ...
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
    
    Epochs_FlextoFlex_based = repmat({Final_based_Structure}, ...
        1, length(Trials_Info));
    
    
    %% Filling the General field
    Muscles_names={'Vastus_med_R', 'Rectus_femoris_R', ...
                   'Gastrocnemius_R', 'Biceps_femoris_R', ...
                   'Trapezius_R', 'Trapezius_L'};
    for i = 1:length(Trials_Info)
        Epochs_FlextoFlex_based{1, i}.General = Trials_Info{1, i}.General;
        Epochs_FlextoFlex_based{1, i}.General.Muscles_Names = Muscles_names;
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
    disp('FlextoFlex_Based epoch selection: Loop over trials ...')

    % Helper function to extract data for each epoch
    extract_epoch_data = @(data, start_idx, end_idx) data(:, start_idx:end_idx);
    
    for i = 1:length(Trials_Info)
        
        if isempty(Trials_Info{1, i}.Events.EEG_stream.Raw.flextoflex_start_indx); continue; end
        
        if ~contains(Trials_Info{1, i}.General.Description, 'Reject')
            %% EEG_stream
            % Define indices
            raw_start_indices = Trials_Info{1, i}.Events.EEG_stream.Raw.flextoflex_start_indx;
            raw_end_indices = Trials_Info{1, i}.Events.EEG_stream.Raw.flextoflex_end_indx;
            pre_start_indices = Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flextoflex_start_indx;
            pre_end_indices = Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flextoflex_end_indx;
        
            % Preallocate the EEG_stream structure
            Epochs_FlextoFlex_based{1, i}.EEG_stream.Raw = struct();
            Epochs_FlextoFlex_based{1, i}.EEG_stream.Preprocessed = struct();
        
            % Use arrayfun to fill in Raw Time Domain data
            Epochs_FlextoFlex_based{1, i}.EEG_stream.Raw.Times = ...
                arrayfun(@(s, e) All_EEG_time(s:e), ...
                raw_start_indices, raw_end_indices, 'UniformOutput', false);
        
            Epochs_FlextoFlex_based{1, i}.EEG_stream.Raw.Channels = ...
                arrayfun(@(s, e) extract_epoch_data(All_EEG, s, e), ...
                raw_start_indices, raw_end_indices, 'UniformOutput', false);
        
            % Use arrayfun to fill in Preprocessed Time Domain data
            Epochs_FlextoFlex_based{1, i}.EEG_stream.Preprocessed.Times = ...
                arrayfun(@(s, e) EEG.times(s:e), ...
                pre_start_indices, pre_end_indices, 'UniformOutput', false);
        
            Epochs_FlextoFlex_based{1, i}.EEG_stream.Preprocessed.Channels = ...
                arrayfun(@(s, e) extract_epoch_data(channel_data, s, e), ...
                pre_start_indices, pre_end_indices, 'UniformOutput', false);
        
            Epochs_FlextoFlex_based{1, i}.EEG_stream.Preprocessed.Sources = ...
                arrayfun(@(s, e) extract_epoch_data(source_data, s, e), ...
                pre_start_indices, pre_end_indices, 'UniformOutput', false);
        
    
            %% EXP_stream
            % Define indices
            start_indices = Trials_Info{1, i}.Events.EXP_stream.flextoflex_start_indx;
            end_indices = Trials_Info{1, i}.Events.EXP_stream.flextoflex_end_indx;
        
            % Preallocate the EXP_stream structure
            Epochs_FlextoFlex_based{1, i}.EXP_stream = struct();
        
            % Use arrayfun to fill in Times, Forces, Encoder_angle, and Ref_angle
            Epochs_FlextoFlex_based{1, i}.EXP_stream.Times = ...
                arrayfun(@(s, e) All_Experiment_time(s:e), ...
                start_indices, end_indices, 'UniformOutput', false);
        
            Epochs_FlextoFlex_based{1, i}.EXP_stream.Forces = ...
                arrayfun(@(s, e) All_Experiment(5, s:e), ...
                start_indices, end_indices, 'UniformOutput', false);
        
            Epochs_FlextoFlex_based{1, i}.EXP_stream.Encoder_angle = ...
                arrayfun(@(s, e) All_Experiment(1, s:e), ...
                start_indices, end_indices, 'UniformOutput', false);
        
            Epochs_FlextoFlex_based{1, i}.EXP_stream.Ref_angle = ...
                arrayfun(@(s, e) ...
                extract_ref_angle(s, e, All_Experiment_time, All_Experiment), ...
                start_indices, end_indices, 'UniformOutput', false);
        
    
            %% EMG_stream
            % Define indices
            start_indices = Trials_Info{1, i}.Events.EMG_stream.flextoflex_start_indx;
            end_indices = Trials_Info{1, i}.Events.EMG_stream.flextoflex_end_indx;
        
            % Preallocate the EMG_stream structure
            Epochs_FlextoFlex_based{1, i}.EMG_stream = struct();
        
            % Use arrayfun to populate Times, Sensors_Raw, and Sensors_Preprocessed
            Epochs_FlextoFlex_based{1, i}.EMG_stream.Times = ...
                arrayfun(@(s, e) All_EMG_time(s:e), ...
                start_indices, end_indices, 'UniformOutput', false);
        
            Epochs_FlextoFlex_based{1, i}.EMG_stream.Sensors_Raw = ...
                arrayfun(@(s, e) All_EMG(EMG_sensor_id, s:e), ...
                start_indices, end_indices, 'UniformOutput', false);
        
            Epochs_FlextoFlex_based{1, i}.EMG_stream.Sensors_Preprocessed = ...
                arrayfun(@(s, e) All_EMG_filt(EMG_sensor_id, s:e), ...
                start_indices, end_indices, 'UniformOutput', false);
        
        end

    end
    
    disp('FlextoFlex_Based epoch selection: Loop over trials done!')


    %% save Epochs_Trial_based structure
    disp('FlextoFlex_Based epoch selection: Saving the MAT file ...')
    save_path = [data_path, '6_Trials_Info_and_Epoched_data\', ...
        'sub-', num2str(subject_id)];
    save(fullfile(save_path, 'Epochs_FlextoFlex_based.mat'), 'Epochs_FlextoFlex_based', '-v7.3');
    
end


% Helper function to calculate Ref_angle with time shift
function ref_angle = extract_ref_angle(start_indx, end_indx, All_Experiment_time, All_Experiment)
    % Adjust for demonstration change of time (5 seconds in Encoder.m file)
    [~, start_indx_ref] = min(abs(All_Experiment_time - (All_Experiment_time(start_indx) - 5)));
    % Reference angle data
    ref_angle = All_Experiment(2, start_indx_ref : start_indx_ref + (end_indx - start_indx));
end