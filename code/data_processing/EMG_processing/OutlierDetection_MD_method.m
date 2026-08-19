function outliers = OutlierDetection_MD_method(data)

    % Assuming `data` is a 4x10x1000 matrix (4 muscles, 10 features, 1000 cycles)
    [num_muscles, num_features, num_cycles] = size(data);
    
    % Initialize storage for Mahalanobis distances and outliers
    md_values = zeros(num_muscles, num_cycles);
    outliers = cell(num_muscles, 1);  % Store outlier indices per muscle
    
    % Confidence level for chi-square test (99.9% confidence)
    alpha = 0.999;
    chi_threshold = chi2inv(alpha, num_features);  % Chi-square threshold for 10 variables
    
    % Loop over each muscle
    for m = 1:num_muscles
        % Extract data for the current muscle across all cycles 
        muscle_data = squeeze(data(m, :, :))';  
        
        % Compute robust mean and covariance matrix using MCD
        [robust_cov, robust_mu] = robustcov(muscle_data);
        
        % Compute Mahalanobis Distance for each cycle
        for c = 1:num_cycles
            diff = muscle_data(c, :) - robust_mu;  % Difference from mean
            md_values(m, c) = sqrt(diff * (robust_cov \ diff')); % Compute MD
        end
        
        % Identify outliers (MD greater than threshold)
        outliers{m} = find(md_values(m, :) > chi_threshold);  % Outlier indices per muscle
    end
    

end