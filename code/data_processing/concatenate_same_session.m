function concatenated_stream = concatenate_same_session(stream1, stream2)
    % Function to concatenate two XDF stream structures
    % Customize based on the structure of your XDF streams
    concatenated_stream = stream1; % Initialize with first stream
    current_stream      = stream2;

    % Adding the EEG part
    for i = 1:length(concatenated_stream)
        if strcmp(concatenated_stream{1, i}.info.name, 'LiveAmpSN-102108-1125')
            k1 = i;
        end
    end

    for i = 1:length(current_stream)
        if strcmp(current_stream{1, i}.info.name, 'LiveAmpSN-102108-1125')
            k2 = i;
        end
    end

    concatenated_stream{1, k1}.time_stamps = ...
        [concatenated_stream{1, k1}.time_stamps, ...
        current_stream{1, k2}.time_stamps];

    concatenated_stream{1, k1}.time_series = ...
        [concatenated_stream{1, k1}.time_series, ...
        current_stream{1, k2}.time_series];

    concatenated_stream{1, k1}.segments(end+1) = ...
        current_stream{1, k2}.segments;



    % Adding the EXP part
    for i = 1:length(concatenated_stream)
        if strcmp(concatenated_stream{1, i}.info.name, 'Encoder_Pressure_Preference_Force')
            k1 = i;
        end
    end

    for i = 1:length(current_stream)
        if strcmp(current_stream{1, i}.info.name, 'Encoder_Pressure_Preference_Force')
            k2 = i;
        end
    end

    concatenated_stream{1, k1}.time_stamps = ...
        [concatenated_stream{1, k1}.time_stamps, ...
        current_stream{1, k2}.time_stamps];

    concatenated_stream{1, k1}.time_series = ...
        [concatenated_stream{1, k1}.time_series, ...
        current_stream{1, k2}.time_series];

    

    % Adding the EMG part
    for i = 1:length(concatenated_stream)
        if strcmp(concatenated_stream{1, i}.info.name, 'EMG')
            k1 = i;
        end
    end

    for i = 1:length(current_stream)
        if strcmp(current_stream{1, i}.info.name, 'EMG')
            k2 = i;
        end
    end

    concatenated_stream{1, k1}.time_stamps = ...
        [concatenated_stream{1, k1}.time_stamps, ...
        current_stream{1, k2}.time_stamps];

    concatenated_stream{1, k1}.time_series = ...
        [concatenated_stream{1, k1}.time_series, ...
        current_stream{1, k2}.time_series];

    concatenated_stream{1, k1}.segments(end+1) = ...
        current_stream{1, k2}.segments;


end