function mean_values = OutlierDetection_features(signal)
    
    % Assuming `signal` is a 4 x N matrix
    [rows, cols] = size(signal);
    
    % Define the number of segments
    num_segments = 10;
    
    % Compute the segment size
    segment_size = floor(cols / num_segments);
    
    % Preallocate the result matrix
    mean_values = zeros(rows, num_segments);
    
    % Loop through each segment and compute the mean
    for i = 1:num_segments
        % Define the segment indices
        start_idx = (i - 1) * segment_size + 1;
        
        % Ensure the last segment includes the remaining values
        if i == num_segments
            end_idx = cols;
        else
            end_idx = i * segment_size;
        end
        
        % Compute the mean for each row in the segment
        mean_values(:, i) = mean(signal(:, start_idx:end_idx), 2);
    end

end
