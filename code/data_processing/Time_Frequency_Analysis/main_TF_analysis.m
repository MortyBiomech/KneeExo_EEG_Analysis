clc
clear

%% Add and Define Necessary Paths
main_project_folder = 'D:\Morteza\MyProjects\ANSYMB2024';
addpath(genpath(main_project_folder)); % main folder containing all codes and data

data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
epoched_data_path = [data_path, '6_Trials_Info_and_Epoched_data\'];
ROIs_feature_path = [data_path, '8_Classification\ROIs_features\'];


%% Load ROI with subjects and ICs in each brain region
filename = 'ROIs_1_FlextoFlex_all_epochs.mat';
data = load(fullfile(ROIs_feature_path, filename));
name = fieldnames(data);
ROIs = data.(name{1});


%% Loop into the brain regions to extract the time-frequency content

% parameters for Morlet wavelet computation
fs = 500; % sampling frequency (Hz)
low_freq = 0; % lower frequency for extracting the TF content
upp_freq = 50; % upper frequency for extractign the TF content
VoicesPerOctave = 40; 


% % parameters for manual coding of Morlet transform
% f_min = 1; % Minimale Frequenz in Hz
% f_max = 50; % Maximale Frequenz in Hz
% num_frequencies = 250; % Anzahl der Frequenzbänder
% frequencies = logspace(log10(f_min), log10(f_max), num_frequencies); % Logarithmisch verteilte Frequenzen
% % width = linspace(30, 10, num_frequencies); % Breite des Morlet Wavelets (Zyklen)
% width = 5*ones(1, num_frequencies);


N = fieldnames(ROIs);
% for i = 1:length(N)
i = 1;
    %%
    region_name = N{i};
    region_data = cell(size(ROIs.(region_name)));

    % Subject IDs
    region_data(:, 1) = ROIs.(region_name)(:, 1);
    % ICs IDs
    region_data(:, 2) = ROIs.(region_name)(:, 2);
    
    for j = 1:length(region_data(:,1))
        
        disp(['sub-', num2str(region_data{j, 1}), ', IC ', num2str(region_data{j, 2})]);
        filename = ['sub-', num2str(region_data{j, 1}),'\Epochs_FlextoFlex_based.mat'];
        data = load(fullfile(epoched_data_path, filename));
        name = fieldnames(data);
        main_data = data.(name{1});

        filename = ['sub-', num2str(region_data{j, 1}),'\Trials_Info.mat'];
        data = load(fullfile(epoched_data_path, filename));
        name = fieldnames(data);
        Trials_Info = data.(name{1});

        ic_id = region_data{j, 2};

        if region_data{j, 1} >= 10 % different saving structure for subject 10 and above
            all_ICs = cellfun(@(x) x.EEG_stream.Preprocessed.Sources, main_data, 'UniformOutput', false);
            
            inside_structure = struct('Signal', [], 'Pressure', [], 'Description', []);
            region_data{j, 3} = repmat({inside_structure}, size(all_ICs));
            for k = 1:length(all_ICs)
                region_data{j, 3}{1, k}.Pressure = Trials_Info{1, k}.General.Pressure;
                region_data{j, 3}{1, k}.Description = Trials_Info{1, k}.General.Description;
                if ~isempty(all_ICs{1, k})
                    region_data{j, 3}{1, k}.Signal = cellfun(@(x) ...
                        x(ic_id, :), all_ICs{1, k}, 'UniformOutput', false);
                end
            end
        else
            all_ICs = cellfun(@(x) ...
                x.EEG_stream.Preprocessed.Time_Domain.Sources.Not_Length_Normalized, ...
                main_data, 'UniformOutput', false);
            
            inside_structure = struct('Signal', [], 'Pressure', [], 'Description', []);
            region_data{j, 3} = repmat({inside_structure}, size(all_ICs));
            for k = 1:length(all_ICs)
                region_data{j, 3}{1, k}.Pressure = Trials_Info{1, k}.General.Pressure;
                region_data{j, 3}{1, k}.Description = 'Experiment';
                if ~isempty(all_ICs{1, k})
                    region_data{j, 3}{1, k}.Signal = cellfun(@(x) ...
                        x(ic_id, :), all_ICs{1, k}, 'UniformOutput', false);
                end
            end
        end


        % Compute the Morlet Wavelet of each signal and store it in the 4th
        % column of region_data
        inside_structure = struct('TF_content_beforTimeWarp', [], ...
            'Frequencies', [],'Event_indx', [], 'TF_content_afterTimeWarp', []);
        region_data{j, 4} = repmat({inside_structure}, size(all_ICs));
        for k = 1:length(all_ICs)
            if ~isempty(region_data{j, 3}{1, k}.Signal) && ...
                    strcmp(region_data{j, 3}{1, k}.Description, 'Experiment')
                [cwt_coeffs, freqs] = ...
                    cellfun(@(x) cwt(x, 'amor', fs, 'FrequencyLimits', [1 50], 'VoicesPerOctave', 30), ...
                    region_data{j, 3}{1, k}.Signal, 'UniformOutput', false); 
                
                % [cwt_coeffs, freqs, ~] = ...
                %     cellfun(@(x) morlet_transform(x, fs, frequencies, width), ...
                %     region_data{j, 3}{1, k}.Signal, 'UniformOutput', false); 
                 
                region_data{j, 4}{1, k}.TF_content_beforTimeWarp = ...
                    cellfun(@(x) abs(x).^2, cwt_coeffs, 'UniformOutput', false);
                region_data{j, 4}{1, k}.Frequencies = ...
                    cellfun(@(x) x, freqs, 'UniformOutput', false);
            end
        end
        
        
        % filling the event indexes to perform time-warping afterward
        for k = 1:length(region_data{j,3})
            if ~isempty(region_data{j, 3}{1, k}.Signal) && ...
                    strcmp(region_data{j, 3}{1, k}.Description, 'Experiment')
                a = Trials_Info{1, k}.Events.EEG_stream.Preprocessed.flextoflex_start_indx;
                b = Trials_Info{1, k}.Events.EEG_stream.Preprocessed.extension_start_indx; 
                b = b(1:length(a));
                c = Trials_Info{1, k}.Events.EEG_stream.Preprocessed.flextoflex_end_indx;
                region_data{j, 4}{1, k}.Event_indx = [a(:) b(:) c(:)];
            end
        end
    
        % memory issue!
        clear data main_data Trials_Info all_ICs
    end

%%
    % Performing the linear time-warping 
    % first step: finding the median of flexion and extension segments
    events_vector = [];
    for j = 1:length(region_data(:,1))
        for k = 1:length(region_data{j,3})
            if ~isempty(region_data{j, 3}{1, k}.Signal) && ...
                    strcmp(region_data{j, 3}{1, k}.Description, 'Experiment')
                events_vector = cat(1, events_vector, ...
                    region_data{j, 4}{1, k}.Event_indx);
            end
        end
    end

    flexion_length = events_vector(:,2) - events_vector(:,1);
    extension_length = events_vector(:,3) - events_vector(:,2);
    flexion_part_median = median(flexion_length);
    extension_part_median = median(extension_length);

    S = 3; % median +- S*(Standard Deviation)
    upperlim_flexion_length = flexion_part_median + S*std(flexion_length);
    lowerlim_flexion_length = flexion_part_median - S*std(flexion_length);
    upperlim_extension_length = extension_part_median + S*std(extension_length);
    lowerlim_extension_length = extension_part_median - S*std(extension_length);

    clear events_vector flexion_length extension_length

    %%
    for j = 1:length(region_data(:,1))
        for k = 1:length(region_data{j,3})
            if ~isempty(region_data{j, 3}{1, k}.Signal) && ...
                    strcmp(region_data{j, 3}{1, k}.Description, 'Experiment')
                for c = 1:length(region_data{j, 4}{1, k}.TF_content_beforTimeWarp)
                    events = region_data{j, 4}{1, k}.Event_indx(c, :);
                    constraint1 = and(events(2) - events(1) > lowerlim_flexion_length, ...
                        events(2) - events(1) < upperlim_flexion_length);
                    constraint2 = and(events(3) - events(2) > lowerlim_extension_length, ...
                        events(3) - events(2) < upperlim_extension_length);
                    if constraint1 && constraint2
                        TF_matrix = region_data{j, 4}{1, k}.TF_content_beforTimeWarp{1, c};
                        
                        flexion_segment = TF_matrix(:, 1:events(2)-events(1)+1);
                        X = 1:size(flexion_segment,2);
                        Xq = linspace(1, size(flexion_segment,2), flexion_part_median);
                        flexion_segment_TimeWarped = interp1(X', flexion_segment', Xq', "linear");
                        flexion_segment_TimeWarped = flexion_segment_TimeWarped';


                        extension_segment = TF_matrix(:, size(flexion_segment,2)+1:end);
                        X = 1:size(extension_segment,2);
                        Xq = linspace(1, size(extension_segment,2), extension_part_median);
                        extension_segment_segment_TimeWarped = interp1(X', extension_segment', Xq', "linear");
                        extension_segment_segment_TimeWarped = extension_segment_segment_TimeWarped';

                        region_data{j, 4}{1, k}.TF_content_afterTimeWarp{1, c} = ...
                            [flexion_segment_TimeWarped, extension_segment_segment_TimeWarped];
                    end
                end
            end
        end
    end

    clear TF_matrix flexion_segment flexion_segment_TimeWarped 
    clear extension_segment extension_segment_segment_TimeWarped

    %%
    
    cycle_time = linspace(0, 100, flexion_part_median + extension_part_median);

    frequency_vector_lenghts = [];
    frequency_vector_epochs = [];
    frequency_vector_trials = [];
    frequency_vector_ICs = [];
    for j = 1:length(region_data(:,1))
        for k = 1:length(region_data{j,3})
            if ~isempty(region_data{j, 3}{1, k}.Signal) && ...
                    strcmp(region_data{j, 3}{1, k}.Description, 'Experiment')
                
                freq_vector_length = cellfun(@(x) size(x,1), region_data{j, 4}{1, k}.TF_content_afterTimeWarp);
                frequency_vector_lenghts = cat(2, frequency_vector_lenghts, freq_vector_length);
                frequency_vector_epochs = cat(2, frequency_vector_epochs, 1:length(freq_vector_length));
                frequency_vector_trials = cat(2, frequency_vector_trials, k*ones(1, length(freq_vector_length)));
                frequency_vector_ICs = cat(2, frequency_vector_ICs, j*ones(1, length(freq_vector_length)));

            end
        end
    end

    v = frequency_vector_lenghts;
    v( v == 0) = v( v == 0) + 1000;
    [min_freq_vector_length, min_freq_vector_length_indx] = ...
        min(v);
    j = frequency_vector_ICs(min_freq_vector_length_indx);
    k = frequency_vector_trials(min_freq_vector_length_indx);
    c = frequency_vector_epochs(min_freq_vector_length_indx);
    
    frequency_vector = region_data{j, 4}{1, k}.Frequencies{1, c};

    clear frequency_vector_lenghts frequency_vector_epochs
    clear frequency_vector_trials frequency_vector_ICs

    %%
    P1 = 0;
    P3 = 0;
    P6 = 0;
    for j = 12%:length(region_data(:,1))
        for k = 1:length(region_data{j,3})
            if ~isempty(region_data{j, 3}{1, k}.Signal) && ...
                    strcmp(region_data{j, 3}{1, k}.Description, 'Experiment')

                % Identify non-empty cells
                nonEmptyIdx = ~cellfun(@isempty, region_data{j, 4}{1, k}.TF_content_afterTimeWarp);
                
                P = region_data{j, 3}{1, k}.Pressure;
                switch P
                    case 1
                        P1 = P1 + length(nonEmptyIdx);
                    case 3
                        P3 = P3 + length(nonEmptyIdx);
                    case 6
                        P6 = P6 + length(nonEmptyIdx);
                end
            end
        end
    end


%%

    TF_TimeWarped_P1 = single(zeros(min_freq_vector_length, ...
        flexion_part_median + extension_part_median, P1));
    TF_TimeWarped_P3 = single(zeros(min_freq_vector_length, ...
        flexion_part_median + extension_part_median, P3));
    TF_TimeWarped_P6 = single(zeros(min_freq_vector_length, ...
        flexion_part_median + extension_part_median, P6));
    
    % Track the number of elements added
    countP1 = 0;
    countP3 = 0;
    countP6 = 0;

    for j = 12%:length(region_data(:,1))
        for k = 1:length(region_data{j,3})
            
            if isempty(region_data{j, 3}{1, k}.Signal) || ...
                    ~strcmp(region_data{j, 3}{1, k}.Description, 'Experiment')
                continue
            end

            % Identify non-empty cells
            nonEmptyIdx = ~cellfun(@isempty, region_data{j, 4}{1, k}.TF_content_afterTimeWarp);
            % Extract first N rows from non-empty matrices
            extractedCells = cellfun(@(x) x(1:min_freq_vector_length, :), ...
                region_data{j, 4}{1, k}.TF_content_afterTimeWarp(nonEmptyIdx), ...
                'UniformOutput', false);
            % Convert to a 3D matrix (only for non-empty cells)
            resultMatrix = cat(3, extractedCells{:});
            % Find number of new slices
            numSlices = size(resultMatrix, 3);

            P = region_data{j, 3}{1, k}.Pressure;
            switch P
                case 1
                    TF_TimeWarped_P1(:,:,countP1+(1:numSlices)) = single(resultMatrix);
                    countP1 = countP1 + numSlices;
                case 3
                    TF_TimeWarped_P3(:,:,countP3+(1:numSlices)) = single(resultMatrix);
                    countP3 = countP3 + numSlices;
                case 6
                    TF_TimeWarped_P6(:,:,countP6+(1:numSlices)) = single(resultMatrix);
                    countP6 = countP6 + numSlices;
            end
            
        end
    end


    %%
    % Define extreme colors
    synch_color = [214, 40, 40]/255; % Replace with your desired RGB value for the maximum
    desynch_color = [58, 134, 255]/255;  % Replace with your desired RGB value for the minimum
    
    % Define the number of colors for the colormap
    num_colors = 256;
    
    % Create a gradient for the negative side (red to white)
    neg_colors = [linspace(desynch_color(1), 1, num_colors/2)', ...
                  linspace(desynch_color(2), 1, num_colors/2)', ...
                  linspace(desynch_color(3), 1, num_colors/2)'];
    
    % Create a gradient for the positive side (white to blue)
    pos_colors = [linspace(1, synch_color(1), num_colors/2)', ...
                  linspace(1, synch_color(2), num_colors/2)', ...
                  linspace(1, synch_color(3), num_colors/2)'];
    
    % Combine the gradients to create the full colormap
    custom_cmap = [neg_colors; pos_colors];


    %%

    P_ref = mean(TF_TimeWarped_P6, 2);
    TF_TimeWarped_norm = TF_TimeWarped_P6 - P_ref;


    %%
    figure()
    imagesc(cycle_time, flipud(frequency_vector), flipud(mean(TF_TimeWarped_norm, 3)))
    colormap(custom_cmap)
    axis xy
    axis square
    xline(cycle_time(flexion_part_median), 'LineStyle', '--', 'LineWidth', 2);
    % title(['Left PreMot SuppMot', ', P1'])
    title(['Left PreMot SuppMot', ', P6', ', Subject ', num2str(region_data{j,1})])
    ylabel('Frequency [Hz]')
    xlabel('Cycle [%]')

    % Calculate the global range for all heatmaps
    global_min = min(min(mean(TF_TimeWarped_norm, 3)));
    global_max = max(max(mean(TF_TimeWarped_norm, 3)));
    % Set symmetric limits around zero for consistent colormap
    global_limit = max(abs([global_min, global_max]));

    clim([-global_limit, global_limit])

    %%
    
    

%%

% end


% %% load one data for generating sample code
% subject = 11;
% cd([epoched_data_path, 'sub-', num2str(subject)])
% 
% data = load("Epochs_FlextoFlex_based.mat");
% name = fieldnames(data);
% data = data.(name{1});
% 
% 
% %% Extract the TF content using Morlet Wavelet 
% fs = 500; % sampling frequency
% trial = 20;
% ic = 5;
% 
% epoch = 1;
% signal1 = data{1, trial}.EEG_stream.Preprocessed.Sources{1, epoch}(ic, :);
% % time = data{1, trial}.EEG_stream.Preprocessed.Times{1, epoch};
% epoch = 2;
% signal2 = data{1, trial}.EEG_stream.Preprocessed.Sources{1, epoch}(ic, :);
% 
% epoch = 3;
% signal3 = data{1, trial}.EEG_stream.Preprocessed.Sources{1, epoch}(ic, :);
% 
% epoch = 4;
% signal4 = data{1, trial}.EEG_stream.Preprocessed.Sources{1, epoch}(ic, :);
% 
% epoch = 5;
% signal5 = data{1, trial}.EEG_stream.Preprocessed.Sources{1, epoch}(ic, :);
% 
% epoch = 6;
% signal6 = data{1, trial}.EEG_stream.Preprocessed.Sources{1, epoch}(ic, :);
% 
% %% From EEGLAB Functions --> [tf, freqs, times] = timefreq(data, srate);
% % [tf, freqs, times]  = timefreq(signal', fs, ...
% %     'cycles', 2);
% % tf = abs(tf).^2;
% 
% %% From Matlab built-in function cwtfilterbank
% % Create a filter bank with the length of the first signal
% fb1 = cwtfilterbank('Wavelet', 'amor', 'SamplingFrequency', fs, ...
%                    'FrequencyLimits', [0 50], 'VoicesPerOctave', 30, ...
%                    'SignalLength', length(signal1));
% % Compute the wavelet transform
% [WT, frequencies] = fb1.wt(signal1);
% 
% % For the second signal, adjust the filter bank or create a new one if lengths differ
% fb2 = cwtfilterbank('Wavelet', 'amor', 'SamplingFrequency', fs, ...
%                    'FrequencyLimits', [0 50], 'VoicesPerOctave', 30, ...
%                    'SignalLength', length(signal2));
% [WT2, frequencies2] = fb2.wt(signal2);
% 
% fb3 = cwtfilterbank('Wavelet', 'amor', 'SamplingFrequency', fs, ...
%                    'FrequencyLimits', [1 50], 'VoicesPerOctave', 30, ...
%                    'SignalLength', length(signal3));
% [WT3, frequencies3] = fb3.wt(signal3);
% 
% fb4 = cwtfilterbank('Wavelet', 'amor', 'SamplingFrequency', fs, ...
%                    'FrequencyLimits', [1 50], 'VoicesPerOctave', 30, ...
%                    'SignalLength', length(signal4));
% [WT4, frequencies4] = fb4.wt(signal4);
% 
% fb5 = cwtfilterbank('Wavelet', 'amor', 'SamplingFrequency', fs, ...
%                    'FrequencyLimits', [1 50], 'VoicesPerOctave', 30, ...
%                    'SignalLength', length(signal5));
% [WT5, frequencies5] = fb5.wt(signal5);
% 
% fb6 = cwtfilterbank('Wavelet', 'amor', 'SamplingFrequency', fs, ...
%                    'FrequencyLimits', [1 50], 'VoicesPerOctave', 30, ...
%                    'SignalLength', length(signal6));
% [WT6, frequencies6] = fb6.wt(signal6);
% 
% %% 
% figure()
% plot(region_data{1, 4}{1, 17}.Frequencies{1, 1}, 'Marker', 'o', 'MarkerSize', 8)
% hold on
% plot(region_data{1, 4}{1, 17}.Frequencies{1, 2}, 'Marker', '*', 'MarkerSize', 6)
% plot(region_data{1, 4}{1, 16}.Frequencies{1, 3}, 'Marker', 'v', 'MarkerSize', 7)
% 
% 
% %% 
% figure()
% plot(frequencies, 'Marker', 'o', 'MarkerSize', 8)
% 
% 
% 
% %% Compute the Continuous Wavelet Transform using Morlet Wavelets
% % [cwt_coeffs, frequencies] = ...
% %     cwt(signal, 'amor', fs, 'FrequencyLimits', [1 50], 'VoicesPerOctave', 20); 
% 
% % Compute power (magnitude squared of coefficients)
% power = abs(cwt_coeffs).^2;
% 
% % Calculate mean power across time for each frequency
% mean_power_per_frequency = mean(power, 2); % Average across time (rows)
% 
% % Normalize power using decibel scale
% normalized_power_db = 10 * log10(bsxfun(@rdivide, power, mean_power_per_frequency));
% 
% 
% %%
% figure;
% surf(time, frequencies, power - mean_power_per_frequency, 'EdgeColor', 'none');
% 
% axis tight;
% view(2);
% 
% xlabel('Time (s)');
% ylabel('Frequency (Hz)');
% title('Normalized Time-Frequency Plot (dB)');
% colorbar;
% colormap jet;
% % clim([-20 20]); % Adjust color limits if needed
% 
% 
% %%
% % Parameters
% Fs = 500; % Sampling rate in Hz
% t = -2:1/Fs:2; % Time vector for Morlet wavelet
% f_min = 1; % Minimum frequency in Hz
% f_max = 50; % Maximum frequency in Hz
% num_frequencies = 250; % Number of frequency bands
% frequencies = logspace(log10(f_min), log10(f_max), num_frequencies); % Log-spaced frequencies
% width = linspace(4, 10, num_frequencies); % Width of the Morlet wavelet (number of cycles)
% 
% % Example EEG signal
% EEG_signal = signal; 
% 
% % Preallocate output
% power = zeros(num_frequencies, length(EEG_signal));
% 
% % Morlet wavelet transform
% for fi = 1:num_frequencies
%     freq = frequencies(fi);
%     w = width(fi);
% 
%     % Create Morlet wavelet
%     sigma_t = w / (2 * pi * freq); % Temporal standard deviation
%     wavelet = exp(2 * 1i * pi * freq * t) .* exp(-t.^2 / (2 * sigma_t^2)); % Complex Morlet wavelet
%     wavelet = wavelet / sqrt(sum(abs(wavelet).^2)); % Normalize wavelet
% 
%     % Convolve wavelet with EEG signal
%     convolution = conv(EEG_signal, wavelet, 'same');
% 
%     % Compute power
%     power(fi, :) = abs(convolution).^2;
% end
% 
% % Calculate mean power across time for each frequency
% mean_power_per_frequency = mean(power, 2); % Average across time (rows)
% 
% % Normalize power using decibel scale
% normalized_power_db = 10 * log10(bsxfun(@rdivide, power, mean_power_per_frequency));
% 
% 
% % Subtract baseline from power
% ERSP = power - mean_power_per_frequency;
% 
% %% Time-frequency plot
% figure;
% imagesc(time, frequencies, ERSP);
% axis xy;
% xlabel('Time (s)');
% ylabel('Frequency (Hz)');
% title('Time-Frequency Representation');
% 
% 
% 
% % % Define extreme colors
% % synch_color = [214, 40, 40]/255; 
% % desynch_color = [58, 134, 255]/255;  
% % 
% % % Define the number of colors for the colormap
% % num_colors = 256;
% % 
% % % Create a gradient for the negative side (red to white)
% % neg_colors = [linspace(desynch_color(1), 1, num_colors/2)', ...
% %               linspace(desynch_color(2), 1, num_colors/2)', ...
% %               linspace(desynch_color(3), 1, num_colors/2)'];
% % 
% % % Create a gradient for the positive side (white to blue)
% % pos_colors = [linspace(1, synch_color(1), num_colors/2)', ...
% %               linspace(1, synch_color(2), num_colors/2)', ...
% %               linspace(1, synch_color(3), num_colors/2)'];
% % 
% % % Combine the gradients to create the full colormap
% % custom_cmap = [neg_colors; pos_colors];
% 
% % Define extreme colors
% synch_color = [214, 40, 40]/255; % Red (positive side)
% desynch_color = [58, 134, 255]/255; % Blue (negative side)
% 
% % Define the number of colors for the colormap
% num_colors = 256;
% 
% % Create a gradient for the negative side (blue to white) using logspace
% neg_colors = [logspace(log10(desynch_color(1)), log10(1), num_colors/2)', ...
%               logspace(log10(desynch_color(2)), log10(1), num_colors/2)', ...
%               logspace(log10(desynch_color(3)), log10(1), num_colors/2)'];
% 
% % Create a gradient for the positive side (white to red) using logspace
% pos_colors = [logspace(log10(1), log10(synch_color(1)), num_colors/2)', ...
%               logspace(log10(1), log10(synch_color(2)), num_colors/2)', ...
%               logspace(log10(1), log10(synch_color(3)), num_colors/2)'];
% 
% % Combine the gradients to create the full colormap
% custom_cmap = [neg_colors; pos_colors];
% 
% colormap(custom_cmap)
% % Adjust the color axis to center around zero
% clim([-max(abs(ERSP(:))), max(abs(ERSP(:)))]);
% 
% colorbar;
% 
% % figure;
% % imagesc(time, frequencies, ERSP);
% % axis xy;
% % xlabel('Time (s)');
% % ylabel('Frequency (Hz)');
% % title('Time-Frequency Representation (Morlet Wavelet) - subtraction');
% % colorbar;
% % 
% % figure;
% % imagesc(time, frequencies, normalized_power_db);
% % axis xy;
% % xlabel('Time (s)');
% % ylabel('Frequency (Hz)');
% % title('Time-Frequency Representation (Morlet Wavelet) - dB');
% % colorbar;
% % clim([-1 1])
