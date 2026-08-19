
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
               'Freq_Domain', EEG_Preprocessed_Freq_Domain_Structure));

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
    struct('EEG_stream', EEG_stream, ...
           'EMG_stream', EMG_Structure, ...
           'EXP_stream', EXP_structure);

Epochs_Extension_based = repmat({Final_based_Structure}, ...
    1, length(Trials_Info));

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

%% Loop over trials 
% EEG: Time Domain (Not_Length_Normalized), Freq Domain)
% EXP: Force sensor, encoder and ref angles
disp('Extension_Based epoch selection: Loop over trials ...')
for i = 1:length(Trials_Info)

    %% EEG stream
    Q = length(Trials_Info{1, i}.Events.EEG_stream.Raw.extension_start_indx);
    % Initialized cells
    Epochs_Extension_based{1, i}.EEG_stream.Raw.Time_Domain.Times = cell(1, Q);
    Epochs_Extension_based{1, i}.EEG_stream.Raw.Time_Domain.Channels.Not_Length_Normalized = cell(1, Q);
    Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Times = cell(1, Q);
    Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Channels.Not_Length_Normalized = cell(1, Q);
    Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Sources.Not_Length_Normalized = cell(1, Q);

    for j = 1:Q
        % % EEG_Raw Time_Domain
        start_indx = ...
            Trials_Info{1, i}.Events.EEG_stream.Raw.extension_start_indx(j);
        end_indx = ...
            Trials_Info{1, i}.Events.EEG_stream.Raw.extension_end_indx(j);
        Epochs_Extension_based{1, i}.EEG_stream.Raw.Time_Domain.Times{1, j} = ...
            All_EEG_time(start_indx:end_indx);
        Epochs_Extension_based{1, i}.EEG_stream.Raw.Time_Domain.Channels.Not_Length_Normalized{1, j} = ...
            All_EEG(:, start_indx:end_indx);

        % % EEG_Raw Freq_Domain
        signal = All_EEG(:, start_indx:end_indx);
        % % % Define parameters for the PSD calculation
        window = floor(size(signal,2)/2); % length of each segment
        noverlap = floor(0.9*window); % number of samples to overlap between segments
        [Pxx, freqs] = pwelch(signal', window, noverlap, nfft, Fs);
        if j == 1; Epochs_Extension_based{1, i}.EEG_stream.Raw.Freq_Domain.Freqs = freqs'; end
        Epochs_Extension_based{1, i}.EEG_stream.Raw.Freq_Domain.Channels(:, :, end + 1) = Pxx';

        % % EEG_Preprocessed Time_Domain
        start_indx = ...
            Trials_Info{1, i}.Events.EEG_stream.Preprocessed.extension_start_indx(j);
        end_indx = ...
            Trials_Info{1, i}.Events.EEG_stream.Preprocessed.extension_end_indx(j);
        Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Times{1, j} = ...
            EEG.times(start_indx:end_indx);
        Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Channels.Not_Length_Normalized{1, j} = ...
            channel_data(:, start_indx:end_indx);
        Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Time_Domain.Sources.Not_Length_Normalized{1, j} = ...
            source_data(:, start_indx:end_indx);

        % EEG_Preprocessed Freq_Domain
        % % Channels
        signal = channel_data(:, start_indx:end_indx);
        % % Define parameters for the PSD calculation
        window = floor(size(signal,2)/2); % length of each segment
        noverlap = floor(0.9*window); % number of samples to overlap between segments
        [Pxx, freqs] = pwelch(signal', window, noverlap, nfft, Fs);
        if j == 1; Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Freq_Domain.Freqs = freqs'; end
        Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Freq_Domain.Channels(:, :, end + 1) = Pxx';
        % % Sources
        signal = source_data(:, start_indx:end_indx);
        % % Define parameters for the PSD calculation
        window = floor(size(signal,2)/2); % length of each segment
        noverlap = floor(0.9*window); % number of samples to overlap between segments
        [Pxx, ~] = pwelch(signal', window, noverlap, nfft, Fs);
        Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Freq_Domain.Sources(:, :, end + 1) = Pxx';

    end

    Epochs_Extension_based{1, i}.EEG_stream.Raw.Freq_Domain.Channels(:, :, 1) = [];
    Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Freq_Domain.Channels(:, :, 1) = [];
    Epochs_Extension_based{1, i}.EEG_stream.Preprocessed.Freq_Domain.Sources(:, :, 1) = [];

    %% EXP stream
    Q = length(Trials_Info{1, i}.Events.EXP_stream.extension_start_indx);
    % Initialize cells
    Epochs_Extension_based{1, i}.EXP_stream.Times = cell(1, Q);
    Epochs_Extension_based{1, i}.EXP_stream.Force = cell(1, Q);
    Epochs_Extension_based{1, i}.EXP_stream.Encoder_angle = cell(1, Q);
    Epochs_Extension_based{1, i}.EXP_stream.Ref_angle = cell(1, Q);
    for j = 1:Q
        start_indx = ...
            Trials_Info{1, i}.Events.EXP_stream.extension_start_indx(j);
        end_indx = ...
            Trials_Info{1, i}.Events.EXP_stream.extension_end_indx(j);
        % timing on exp stream
        Epochs_Extension_based{1, i}.EXP_stream.Times{1, j} = ...
            All_Experiment_time(start_indx : end_indx);
        % Force sensor data
        Epochs_Extension_based{1, i}.EXP_stream.Force{1, j} = ...
            All_Experiment(5, start_indx : end_indx);
        % encoder angle data
        Epochs_Extension_based{1, i}.EXP_stream.Encoder_angle{1, j} = ...
            All_Experiment(1, start_indx : end_indx);
        % adjust for demonstration change of time (5 seconds in Encoder.m file)
        [~, start_indx_ref] = min(abs(All_Experiment_time - ...
            (All_Experiment_time(start_indx) - 5)));
        % refrence angle data
        Epochs_Extension_based{1, i}.EXP_stream.Ref_angle{1, j} = ...
            All_Experiment(2, start_indx_ref : start_indx_ref + (end_indx - start_indx));
    end
   
   
end

%% Loop over trials 
% EMG: raw data, processed data
for i = 1:length(Trials_Info)

    Q = length(Trials_Info{1, i}.Events.EMG_stream.extension_start_indx);
    % Initialize cells
    Epochs_Extension_based{1, i}.EMG_stream.Times = cell(1, Q);
    Epochs_Extension_based{1, i}.EMG_stream.Sensors_Raw = cell(1, Q);
    Epochs_Extension_based{1, i}.EMG_stream.Sensors_Preprocessed = cell(1, Q);
    for j = 1:Q
        start_indx = ...
            Trials_Info{1, i}.Events.EMG_stream.extension_start_indx(j);
        end_indx = ...
            Trials_Info{1, i}.Events.EMG_stream.extension_end_indx(j);

        if j == 1
        Epochs_Extension_based{1, i}.EMG_stream.Names = ...
            Muscles_names;
        end
        Epochs_Extension_based{1, i}.EMG_stream.Times{1, j} = ...
            All_EMG_time(start_indx:end_indx);
        Epochs_Extension_based{1, i}.EMG_stream.Sensors_Raw{1, j} = ...
            All_EMG(EMG_sensor_id, start_indx:end_indx);
        Epochs_Extension_based{1, i}.EMG_stream.Sensors_Preprocessed{1, j} = ...
            All_EMG_filt(EMG_sensor_id, start_indx:end_indx);
    end

end


%% Calculate Normalized-Length data in Time-Domain
%% EEG Raw Time Domain Channel Length_Normalized
%%% P1
L_P1 = zeros(1, length(P1.trials));
for i = 1:length(P1.trials)
    l = cellfun("length", Epochs_Extension_based{1, P1.trials(i)}.EEG_stream.Raw.Time_Domain.Times);
    L_P1(1, i) = max(l);
end
[max_L_P1, ~] = max(L_P1);

for i = 1:length(P1.trials)
    Q = length(Epochs_Extension_based{1, P1.trials(i)}.EEG_stream.Raw.Time_Domain.Times);
    for j = 1:Q
        x_old = Epochs_Extension_based{1, P1.trials(i)}.EEG_stream.Raw...
            .Time_Domain.Times{1, j};
        x_new = linspace(x_old(1), x_old(end), max_L_P1);
        y_old = Epochs_Extension_based{1, P1.trials(i)}.EEG_stream.Raw...
            .Time_Domain.Channels.Not_Length_Normalized{1, j};
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Extension_based{1, P1.trials(i)}.EEG_stream.Raw...
            .Time_Domain.Channels.Length_Normalized(:, :, end + 1) = y_new';
    end
    Epochs_Extension_based{1, P1.trials(i)}.EEG_stream.Raw...
        .Time_Domain.Channels.Length_Normalized(:, :, 1) = [];
end

%%% P3
L_P3 = zeros(1, length(P3.trials));
for i = 1:length(P3.trials)
    l = cellfun("length", Epochs_Extension_based{1, P3.trials(i)}.EEG_stream.Raw.Time_Domain.Times);
    L_P3(1, i) = max(l);
end
[max_L_P3, ~] = max(L_P3);

for i = 1:length(P3.trials)
    Q = length(Epochs_Extension_based{1, P3.trials(i)}.EEG_stream.Raw.Time_Domain.Times);
    for j = 1:Q
        x_old = Epochs_Extension_based{1, P3.trials(i)}.EEG_stream.Raw...
            .Time_Domain.Times{1, j};
        x_new = linspace(x_old(1), x_old(end), max_L_P3);

        y_old = Epochs_Extension_based{1, P3.trials(i)}.EEG_stream.Raw...
            .Time_Domain.Channels.Not_Length_Normalized{1, j};
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Extension_based{1, P3.trials(i)}.EEG_stream.Raw...
            .Time_Domain.Channels.Length_Normalized(:, :, end + 1) = y_new';
    end
    Epochs_Extension_based{1, P3.trials(i)}.EEG_stream.Raw...
        .Time_Domain.Channels.Length_Normalized(:, :, 1) = [];
end

%%% P6
L_P6 = zeros(1, length(P6.trials));
for i = 1:length(P6.trials)
    l = cellfun("length", Epochs_Extension_based{1, P6.trials(i)}.EEG_stream.Raw.Time_Domain.Times);
    L_P6(1, i) = max(l);
end
[max_L_P6, ~] = max(L_P6);

for i = 1:length(P6.trials)
    Q = length(Epochs_Extension_based{1, P6.trials(i)}.EEG_stream.Raw.Time_Domain.Times);
    for j = 1:Q
        x_old = Epochs_Extension_based{1, P6.trials(i)}.EEG_stream.Raw...
            .Time_Domain.Times{1, j};
        x_new = linspace(x_old(1), x_old(end), max_L_P6);

        y_old = Epochs_Extension_based{1, P6.trials(i)}.EEG_stream.Raw...
            .Time_Domain.Channels.Not_Length_Normalized{1, j};
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Extension_based{1, P6.trials(i)}.EEG_stream.Raw...
            .Time_Domain.Channels.Length_Normalized(:, :, end + 1) = y_new';
    end
    Epochs_Extension_based{1, P6.trials(i)}.EEG_stream.Raw...
        .Time_Domain.Channels.Length_Normalized(:, :, 1) = [];
end


%% EEG Preprocessed Time Domain Channel & Source Length_Normalized
%%% P1
L_P1 = zeros(1, length(P1.trials));
for i = 1:length(P1.trials)
    l = cellfun("length", Epochs_Extension_based{1, P1.trials(i)}...
        .EEG_stream.Preprocessed.Time_Domain.Times);
    L_P1(1, i) = max(l);
end
[max_L_P1, ~] = max(L_P1);

for i = 1:length(P1.trials)
    Q = length(Epochs_Extension_based{1, P1.trials(i)}.EEG_stream...
        .Preprocessed.Time_Domain.Times);
    for j = 1:Q
        % Channels
        x_old = Epochs_Extension_based{1, P1.trials(i)}.EEG_stream...
            .Preprocessed.Time_Domain.Times{1, j};
        x_new = linspace(x_old(1), x_old(end), max_L_P1);

        y_old = Epochs_Extension_based{1, P1.trials(i)}.EEG_stream...
            .Preprocessed.Time_Domain.Channels.Not_Length_Normalized{1, j};
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Extension_based{1, P1.trials(i)}.EEG_stream.Preprocessed...
            .Time_Domain.Channels.Length_Normalized(:, :, end + 1) = y_new';
    
        % Sources
        y_old = Epochs_Extension_based{1, P1.trials(i)}.EEG_stream...
            .Preprocessed.Time_Domain.Sources.Not_Length_Normalized{1, j};
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Extension_based{1, P1.trials(i)}.EEG_stream.Preprocessed...
            .Time_Domain.Sources.Length_Normalized(:, :, end + 1) = y_new';
    end

    Epochs_Extension_based{1, P1.trials(i)}.EEG_stream.Preprocessed...
        .Time_Domain.Channels.Length_Normalized(:, :, 1) = [];
    Epochs_Extension_based{1, P1.trials(i)}.EEG_stream.Preprocessed...
        .Time_Domain.Sources.Length_Normalized(:, :, 1) = [];
end


%%% P3
L_P3 = zeros(1, length(P3.trials));
for i = 1:length(P3.trials)
    l = cellfun("length", Epochs_Extension_based{1, P3.trials(i)}...
        .EEG_stream.Preprocessed.Time_Domain.Times);
    L_P3(1, i) = max(l);
end
[max_L_P3, ~] = max(L_P3);

for i = 1:length(P3.trials)
    Q = length(Epochs_Extension_based{1, P3.trials(i)}.EEG_stream...
        .Preprocessed.Time_Domain.Times);
    for j = 1:Q
        % Channels
        x_old = Epochs_Extension_based{1, P3.trials(i)}.EEG_stream...
            .Preprocessed.Time_Domain.Times{1, j};
        x_new = linspace(x_old(1), x_old(end), max_L_P3);

        y_old = Epochs_Extension_based{1, P3.trials(i)}.EEG_stream...
            .Preprocessed.Time_Domain.Channels.Not_Length_Normalized{1, j};
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Extension_based{1, P3.trials(i)}.EEG_stream.Preprocessed...
            .Time_Domain.Channels.Length_Normalized(:, :, end + 1) = y_new';
    
        % Sources
        y_old = Epochs_Extension_based{1, P3.trials(i)}.EEG_stream...
            .Preprocessed.Time_Domain.Sources.Not_Length_Normalized{1, j};
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Extension_based{1, P3.trials(i)}.EEG_stream.Preprocessed...
            .Time_Domain.Sources.Length_Normalized(:, :, end + 1) = y_new';
    end

    Epochs_Extension_based{1, P3.trials(i)}.EEG_stream.Preprocessed...
        .Time_Domain.Channels.Length_Normalized(:, :, 1) = [];
    Epochs_Extension_based{1, P3.trials(i)}.EEG_stream.Preprocessed...
        .Time_Domain.Sources.Length_Normalized(:, :, 1) = [];
end


%%% P6
L_P6 = zeros(1, length(P6.trials));
for i = 1:length(P6.trials)
    l = cellfun("length", Epochs_Extension_based{1, P6.trials(i)}...
        .EEG_stream.Preprocessed.Time_Domain.Times);
    L_P6(1, i) = max(l);
end
[max_L_P6, ~] = max(L_P6);

for i = 1:length(P6.trials)
    Q = length(Epochs_Extension_based{1, P6.trials(i)}.EEG_stream...
        .Preprocessed.Time_Domain.Times);
    for j = 1:Q
        % Channels
        x_old = Epochs_Extension_based{1, P6.trials(i)}.EEG_stream...
            .Preprocessed.Time_Domain.Times{1, j};
        x_new = linspace(x_old(1), x_old(end), max_L_P6);

        y_old = Epochs_Extension_based{1, P6.trials(i)}.EEG_stream...
            .Preprocessed.Time_Domain.Channels.Not_Length_Normalized{1, j};
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Extension_based{1, P6.trials(i)}.EEG_stream.Preprocessed...
            .Time_Domain.Channels.Length_Normalized(:, :, end + 1) = y_new';
    
        % Sources
        y_old = Epochs_Extension_based{1, P6.trials(i)}.EEG_stream...
            .Preprocessed.Time_Domain.Sources.Not_Length_Normalized{1, j};
        y_new = interp1(x_old', y_old', x_new', "spline");
    
        Epochs_Extension_based{1, P6.trials(i)}.EEG_stream.Preprocessed...
            .Time_Domain.Sources.Length_Normalized(:, :, end + 1) = y_new';
    end

    Epochs_Extension_based{1, P6.trials(i)}.EEG_stream.Preprocessed...
        .Time_Domain.Channels.Length_Normalized(:, :, 1) = [];
    Epochs_Extension_based{1, P6.trials(i)}.EEG_stream.Preprocessed...
        .Time_Domain.Sources.Length_Normalized(:, :, 1) = [];
end

disp('Extensions_Based epoch selection: Loop over trials done!')


%% save Epochs_Trial_based structure
disp('Extensions_Based epoch selection: Saving the MAT file ...')
save_path = [data_path, '6_Trials_Info_and_Epoched_data\', ...
    'sub-', num2str(subject_id)];
save(fullfile(save_path, 'Epochs_Extension_based.mat'), 'Epochs_Extension_based', '-v7.3');

