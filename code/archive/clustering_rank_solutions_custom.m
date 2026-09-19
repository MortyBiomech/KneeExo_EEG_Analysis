function [ranked_scores, ranked_solutions] = clustering_rank_solutions_custom(cluster_multivariate_data,quality_measure_weights)

    clustering_solutions_multivariate_median = median(cluster_multivariate_data.data,1);
    clustering_solutions_multivariate_covariance = cov(cluster_multivariate_data.data);
    
    % find mahalanobis distance from median for each solution
    % d_mean = mahal(cluster_multivariate_data.data,cluster_multivariate_data.data);
    for solution = 1:size(cluster_multivariate_data.data,1)
       
        d_median(solution) = (cluster_multivariate_data.data(solution,:)-clustering_solutions_multivariate_median)*inv(clustering_solutions_multivariate_covariance)*(cluster_multivariate_data.data(solution,:)-clustering_solutions_multivariate_median)';
        
    end
    
    % create standardized measures
    standardized_quality_measures(:,1) = cluster_multivariate_data.data(:,1) ./ max(cluster_multivariate_data.data(:,1)); % subjects
    standardized_quality_measures(:,2) = cluster_multivariate_data.data(:,3) ./ max(cluster_multivariate_data.data(:,3)); % ICs/subjects
    standardized_quality_measures(:,3) = cluster_multivariate_data.data(:,4) ./ max(cluster_multivariate_data.data(:,4)); % normalized spread
    standardized_quality_measures(:,4) = cluster_multivariate_data.data(:,5) ./ max(cluster_multivariate_data.data(:,5)); % mean RV
    standardized_quality_measures(:,5) = cluster_multivariate_data.data(:,9) ./ max(cluster_multivariate_data.data(:,9)); % distance from ROI
    standardized_quality_measures(:,6) = d_median ./ max(d_median);                                                       % mahal distance from median
    
    weighted_scores = standardized_quality_measures .* quality_measure_weights;
    sum_of_weighted_scores = sum(weighted_scores,2);
    [ranked_scores, ranked_solutions] = sort(sum_of_weighted_scores,'descend');

end