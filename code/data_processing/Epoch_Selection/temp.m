% TrialsBased

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
Length_Normalization = ...
    struct('Not_Length_Normalized', [], 'Length_Normalized', []);

EEG_Raw_Time_Domain_Structure = struct('Times', [], 'Channels', Length_Normalization);
EEG_Raw_Freq_Domain_Structure = struct('Freqs', [], 'Channels', []);

EEG_Preprocessed_Time_Domain_Structure = ...
    struct('Times', [], 'Channels', Length_Normalization, 'Sources', Length_Normalization);
EEG_Preprocessed_Freq_Domain_Structure = ...
    struct('Freqs', [], 'Channels', [], 'Sources', []);

EEG_stream = ...
    struct('Raw', ...
        struct('Time_Domain', EEG_Raw_Time_Domain_Structure, ...
               'Freq_Domain', EEG_Raw_Freq_Domain_Structure), ...
        'Preprocessed', ...
        struct('Time_Domain', EEG_Preprocessed_Time_Domain_Structure, ...
               'Freq_Domain', EEG_Preprocessed_Freq_Domain_Structure, ...
               'Time_Freq', struct('without_TimeWarping', [], 'with_TimeWarping', [])));

EMG_Structure = ...
    struct('Names', [], ...
           'Times', [], ...
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
for i = 1:length(Trials_Info)
    Epochs_Trial_based{1, i}.General = Trials_Info{1, i}.General;
end


%% Inputs for pwelch method (Power Spectral Density)
Fs = 500; % Sampling frequency
nfft = 2048; % number of FFT points


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

Muscles_names={'Vastus_med_R', 'Rectus_femoris_R', ...
               'Gastrocnemius_R', 'Biceps_femoris_R', ...
               'Vastus_med_L', 'Rectus_femoris_L', ...
               'Gastrocnemius_L', 'Biceps_femoris_L', ...
               'Trapezius_R', 'Trapezius_L'};


%% Select the trials with the same Pressure
P1 = struct();
P1.trials = [];
P1.scores = [];

P3 = struct();
P3.trials = [];
P3.scores = [];

P6 = struct();
P6.trials = [];
P6.scores = [];

for i = 1:length(Trials_Info)
    if strcmp(Trials_Info{1, i}.General.Description, 'Experiment') 
        p = Trials_Info{1, i}.General.Pressure;
        switch p
            case 1
                P1.trials(1, end+1) = i;
                P1.scores(1, end+1) = Trials_Info{1, i}.General.Score;
            case 3
                P3.trials(1, end+1) = i;
                P3.scores(1, end+1) = Trials_Info{1, i}.General.Score;
            case 6
                P6.trials(1, end+1) = i;
                P6.scores(1, end+1) = Trials_Info{1, i}.General.Score;
        end
    end
end


%% Loop over trials 
% EEG: Time Domain (Not_Length_Normalized), Freq Domain)
% EXP: Force sensor, encoder and ref angles
disp('Trials_Based epoch selection: Loop over trials ...')
for i = 1:length(Trials_Info)
    
    if ~endsWith(Trials_Info{1, i}.General.Description, 'Data Loss')
        %% EEG stream
        % % EEG_Raw Time_Domain
        start_indx = ...
            Trials_Info{1, i}.Events.EEG_stream.Raw.Trial_start_indx;
        end_indx = ...
            Trials_Info{1, i}.Events.EEG_stream.Raw.Trial_end_indx;
        Epochs_Trial_based{1, i}.EEG_stream.Raw.Time_Domain.Times = ...
            All_EEG_time(start_indx:end_indx);
        Epochs_Trial_based{1, i}.EEG_stream.Raw.Time_Domain.Channels.Not_Length_Normalized = ...
            All_EEG(:, start_indx:end_indx);
        
        % % EEG_Raw Freq_Domain
        signal = All_EEG(:, start_indx:end_indx);
        % % % Define parameters for the PSD calculation
        window = floor(size(signal,2)/10); % length of each segment
        noverlap = floor(0.9*window); % number of samples to overlap between segments
        [Pxx, freqs] = pwelch(signal', window, noverlap, nfft, Fs);
        Epochs_Trial_based{1, i}.EEG_stream.Raw.Freq_Domain.Freqs = freqs';
        Epochs_Trial_based{1, i}.EEG_stream.Raw.Freq_Domain.Channels = Pxx';
    
    
        % % EEG_Preprocessed Time_Domain
        start_indx = ...
            Trials_Info{1, i}.Events.EEG_stream.Preprocessed.Trial_start_indx;
        end_indx = ...
            Trials_Info{1, i}.Events.EEG_stream.Preprocessed.Trial_end_indx;
        Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Times = ...
            EEG.times(start_indx:end_indx);
        Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Channels.Not_Length_Normalized = ...
            channel_data(:, start_indx:end_indx);
        Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Sources.Not_Length_Normalized = ...
            source_data(:, start_indx:end_indx);
    
        % EEG_Preprocessed Freq_Domain
        % % Channels
        signal = channel_data(:, start_indx:end_indx);
        % % Define parameters for the PSD calculation
        window = floor(size(signal,2)/10); % length of each segment
        noverlap = floor(0.9*window); % number of samples to overlap between segments
        [Pxx, freqs] = pwelch(signal', window, noverlap, nfft, Fs);
        Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Freq_Domain.Freqs = freqs';
        Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Freq_Domain.Channels = Pxx';
        % % Sources
        signal = source_data(:, start_indx:end_indx);
        % % Define parameters for the PSD calculation
        window = floor(size(signal,2)/10); % length of each segment
        noverlap = floor(0.9*window); % number of samples to overlap between segments
        [Pxx, ~] = pwelch(signal', window, noverlap, nfft, Fs);
        Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Freq_Domain.Sources = Pxx';
    
    
        %% EXP stream
        start_indx = ...
            Trials_Info{1, i}.Events.EXP_stream.Trial_start_indx;
        end_indx = ...
            Trials_Info{1, i}.Events.EXP_stream.Trial_end_indx;
        % timing on exp stream
        Epochs_Trial_based{1, i}.EXP_stream.Times = ...
            All_Experiment_time(start_indx : end_indx);
        % Force sensor data
        Epochs_Trial_based{1, i}.EXP_stream.Force = ...
            All_Experiment(5, start_indx : end_indx);
        % encoder angle data
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

%% Loop over trials 
% EMG: raw data, processed data
for i = 1:length(Trials_Info)
    start_indx = ...
        Trials_Info{1, i}.Events.EMG_stream.Trial_start_indx;
    end_indx = ...
        Trials_Info{1, i}.Events.EMG_stream.Trial_end_indx;

    Epochs_Trial_based{1, i}.EMG_stream.Names = ...
        Muscles_names;
    Epochs_Trial_based{1, i}.EMG_stream.Times = ...
        All_EMG_time(start_indx:end_indx);
    Epochs_Trial_based{1, i}.EMG_stream.Sensors_Raw = ...
        All_EMG(EMG_sensor_id, start_indx:end_indx);
    Epochs_Trial_based{1, i}.EMG_stream.Sensors_Preprocessed = ...
        All_EMG_filt(EMG_sensor_id, start_indx:end_indx);
end


%% Calculate Normalized-Length data in Time-Domain
%%% P1
L_P1 = zeros(1, length(P1.trials));
for i = 1:length(P1.trials)
    L_P1(1, i) = length(Epochs_Trial_based{1, P1.trials(i)}.EEG_stream.Raw.Time_Domain.Times);  
end

%%% P3
L_P3 = zeros(1, length(P3.trials));
for i = 1:length(P3.trials)
    L_P3(1, i) = length(Epochs_Trial_based{1, P3.trials(i)}.EEG_stream.Raw.Time_Domain.Times);  
end

%%% P6
L_P6 = zeros(1, length(P6.trials));
for i = 1:length(P6.trials)
    L_P6(1, i) = length(Epochs_Trial_based{1, P6.trials(i)}.EEG_stream.Raw.Time_Domain.Times);  
end

figure()
% Combine the data into a single vector and use a grouping variable
all_lengths = [L_P1, L_P3, L_P6, [L_P1, L_P3, L_P6]];             % Concatenate all data
group = [repmat({'Pressure 1'}, 1, length(L_P1)), ...
    repmat({'Pressure 3'}, 1, length(L_P3)), ...
    repmat({'Pressure 6'}, 1, length(L_P6)), ...
    repmat({'All Pressures'}, 1, length([L_P1, L_P3, L_P6]))];
% Create the box plot using cell array grouping
boxplot(all_lengths, group, 'Whisker', 2);
% Add labels and title
ylabel('Epoch Length');
title('Trial-based epochs length');


%% set the number for interpolating all signals
set_interp_num = median([L_P1, L_P3, L_P6]);


for i = 1:length(Trials_Info)
    if strcmp(Epochs_Trial_based{1, i}.General.Description, 'Experiment')
        % Raw.Time_Domain_Channels
        x_old = Epochs_Trial_based{1, i}.EEG_stream.Raw.Time_Domain.Times;
        x_new = linspace(x_old(1), x_old(end), set_interp_num);
        y_old = Epochs_Trial_based{1, i}.EEG_stream.Raw.Time_Domain.Channels.Not_Length_Normalized;
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Trial_based{1, i}.EEG_stream.Raw.Time_Domain.Channels.Length_Normalized = y_new';


        % Preprocessed.Time_Domain.Channels
        x_old = Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Times;
        x_new = linspace(x_old(1), x_old(end), set_interp_num);
        y_old = Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Channels.Not_Length_Normalized;
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Channels.Length_Normalized = y_new';
    
        % Preprocessed.Time_Domain.Sources
        y_old = Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Sources.Not_Length_Normalized;
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Trial_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Sources.Length_Normalized = y_new';
    end
end

disp('Trials_Based epoch selection: Loop over trials done!')


%% save Epochs_Trial_based structure
disp('Trials_Based epoch selection: Saving the MAT file ...')
save_path = [data_path, '6_Trials_Info_and_Epoched_data\', ...
    'sub-', num2str(subject_id)];
save(fullfile(save_path, 'Epochs_Trial_based.mat'), 'Epochs_Trial_based', '-v7.3');

