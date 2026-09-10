function [ranked_scores, ranked_solutions] = rank_clustering_solutions( ...
    cluster_multivariate_data, quality_measure_weights)
% RANK_CLUSTERING_SOLUTIONS  Score repeated-clustering solutions against a ROI.
%
%   [ranked_scores, ranked_solutions] = rank_clustering_solutions( ...
%       cluster_multivariate_data, quality_measure_weights)
%
% Each of the repeated k-means solutions contains one cluster that best fits
% the region of interest. This scores those candidate clusters and returns
% them best first, so that run_group_clustering can take the winner.
%
% Six measures, each divided by its own maximum so they are comparable, then
% multiplied by the weights and summed:
%
%   1  number of participants in the cluster           column 1
%   2  components per participant                      column 3
%   3  normalised spread                               column 4
%   4  mean residual variance of the dipole fits       column 5
%   5  distance from the region of interest            column 9
%   6  Mahalanobis distance from the median solution   computed here
%
% Positive weights reward, negative weights penalise. The tuning used for this
% study reads as: as many participants as possible, few components each,
% tight, well fitted, close to the ROI. The exact weights per region are in
% run_group_clustering and in each solution's study_info.txt.
%
% Measure 6 asks how unusual a solution is compared with all the others. A
% large weight on it picks the most typical solution rather than the most
% extreme one, which guards against a single lucky partition winning on noise.
%
% Renamed from clustering_rank_solutions_custom.

    data = cluster_multivariate_data.data;
    nSolutions = size(data, 1);

    if numel(quality_measure_weights) ~= 6
        error('rank_clustering_solutions:WrongWeightCount', ...
            'Six weights are needed, %d were given.', ...
            numel(quality_measure_weights));
    end

    %% Mahalanobis distance of each solution from the median solution
    medianSolution = median(data, 1);
    covariance     = cov(data);

    d_median = zeros(1, nSolutions);
    for s = 1:nSolutions
        delta = data(s, :) - medianSolution;
        d_median(s) = delta / covariance * delta';
    end

    %% Standardise each measure by its own maximum
    standardized = [ ...
        data(:, 1) ./ max(data(:, 1)), ...   % participants
        data(:, 3) ./ max(data(:, 3)), ...   % ICs per participant
        data(:, 4) ./ max(data(:, 4)), ...   % normalised spread
        data(:, 5) ./ max(data(:, 5)), ...   % mean residual variance
        data(:, 9) ./ max(data(:, 9)), ...   % distance from ROI
        d_median(:) ./ max(d_median)];       % Mahalanobis from median

    %% Weight and rank
    weighted = standardized .* quality_measure_weights(:)';
    [ranked_scores, ranked_solutions] = sort(sum(weighted, 2), 'descend');

end