clc
clear

%% Add and Define Necessary Paths
main_project_folder = 'D:\Morteza\MyProjects\ANSYMB2024';
addpath(genpath(main_project_folder)); % main folder containing all codes and data

data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
processed_data_path = [data_path, '5_single-subject-EEG-analysis\'];
study_folder = [data_path, '7_STUDY\Epoched_data'];



%% Run EEGLAB
current_path = pwd;
cd('D:\Morteza\Toolboxes\EEGLAB\eeglab2026.0.0')
if ~exist('ALLCOM','var')
    eeglab;
end
cd(current_path)


%% Create and save main STUDY Files. 
% If Studies are created before just "Load existing study" with EEGLAB GUI
% (1) main_study_all_ICs_RV-15.study
% (2) main_study_brain_ICs_RV-15.study

% Define subjects
subject_list = 5:18;  % List of subject IDs


%% calling function to create and save the main study files
% create_and_save_main_study_files(subject_list, data_path, processed_data_path, ALLEEG)

% Note:
%      - load the existing Study (main_study_potential_brain_ICs_RV-15) or
%      - load the existing Study (main_study_potential_brain_ICs_RV-15_epochedData)




% %% Compute the pre-cluster
% clustering_weights = struct();
% clustering_weights.dipoles = 3;
% clustering_weights.scalp = 1;
% 
% clustering_weights.spec = 0;
% freqrange = [1 70];
% timewindow = [];
% 
% out_filename = [STUDY.name(1:end-6), '_preclustered'];
% out_filepath = study_folder;
% 
% 
% % --- Precompute ICA measures: TOPOGRAPHIES ONLY ---
% % This is the bit that creates files like: sub-XX_... .icatopo
[STUDY, ALLEEG] = std_precomp( ...
    STUDY, ALLEEG, ...
    'components', ...        % work on ICs (not channels)
    'scalp', 'on', ...             % compute IC topographies  -> creates *.icatopo
    'recompute', 'on');            % set 'off' to skip files that already exist
% 
% 
% [STUDY, ALLEEG, EEG] = ...
%     bemobil_precluster(STUDY, ALLEEG, EEG, clustering_weights, ...
%     freqrange, timewindow, out_filename, out_filepath);


%% Important Note
% Load the preclust_epoched STUDY in EEGLAB GUI


%% Implementing the repeated clustering

% all_study_names = {'Right_Prim_Motor', ...
%                    'Right_PreMot_SuppMot', ...
%                    'Right_Parieto_Occipital', ...
%                    'Prime_Visual', ...
%                    'Left_Prim_Motor', ...
%                    'Left_PreMot_SuppMot', ...
%                    'Left_Parieto_Occipital', ...
%                    'Left_Dorsal_ACC'};
all_study_names = {'Prime_Visual'};

% all_regions_of_interest = {[43, -27, 41], ...
%                            [15, 15, 60], ...
%                            [35, -65, 40], ...
%                            [0, -85, 5], ...
%                            [-38, -28, 59], ...
%                            [-15, 15, 60], ...
%                            [-35, -65, 40], ...
%                            [20, 57, -10]};
all_regions_of_interest = {[0, -85, 0]};

% all_N_clusters = [12, 13, 8, 9, 13, 10, 9, 11];
all_N_clusters = [12];

% quality_measure_weights: vector of weights for quality measures (6 entries): 
%                          - subjects, 
%                          - ICs/subjects, 
%                          - normalized spread, 
%                          - mean RV, 
%                          - distance from ROI, 
%                          - mahalanobis distance from median of multivariate distribution
%                            (put this very high to get the most "normal" solution)
% all_quality_measure_weights = {[1000  -900  -900   -10  -100  -100], ...
%                                [1000  -900  -900   -10  -100  -100], ...
%                                [2000  -300  -500   -10  -400  -100], ...
%                                [1000  -200  -100   -10  -500  -100], ...
%                                [2000  -300  -500   -10  -400  -100], ...
%                                [1100  -900  -1200   -10  -100  -100], ...
%                                [2000  -200  -500   -10  -300  -100], ...
%                                [700 -1200  -900   -10 -1000  -100]};
all_quality_measure_weights = {[1000  -200  -50   -10  -1000  -100]};

% standard deviations boundary for outlier detection
outlier_sigma = 3; 
% number of iterations to be performed for repeated clustering
n_iterations = 200;
% whether or not the clustering should be done (it takes a lot of time).
do_clustering = 1;
% whether or not the creation of the multivariate dataset should be done.
do_multivariate_data = 1;


for S = 1:length(all_study_names)
    
    % select the region of interest (ROI) - MNI Coordinates:
    % ref: https://bioimagesuiteweb.github.io/webapp/mni2tal.html
    
    ROI = all_regions_of_interest{S};
    cluster_ROI_name  = all_study_names{S};
    cluster_ROI_MNI.x = ROI(1);
    cluster_ROI_MNI.y = ROI(2);
    cluster_ROI_MNI.z = ROI(3);
   
    % Number of clusters for K-means
    N_cluster = all_N_clusters(S);
    
    
    quality_measure_weights = all_quality_measure_weights{S};

    
    % filepath where the new STUDY should be saved
    filepath_STUDY = [study_folder, '\multiple_clustering\', cluster_ROI_name];
    if ~exist(filepath_STUDY, "dir")
        mkdir(filepath_STUDY)
    end


    % Define the file name
    filename   = fullfile(filepath_STUDY, 'study_info.txt');
    % Open file for writing (will overwrite if it already exists)
    fid = fopen(filename, 'w');
    % Check if file opened successfully
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    % Write the lines
    fprintf(fid, ['STUDY Name = ', cluster_ROI_name, '\n']);
    fprintf(fid, ['Region of Interest = ', num2str(ROI), '\n']);
    fprintf(fid, ['Number of Clusters = ', num2str(N_cluster), '\n']);
    fprintf(fid, ['Quality Measure Weights = ', num2str(quality_measure_weights), '\n']);
    % Close the file
    fclose(fid);


    % filename of the new STUDY
    filename_STUDY = cluster_ROI_name;
    
    % filepath where the clustering solutions should be saved
    filepath_clustering_solutions = [filepath_STUDY, '\clustering_solutions'];
    % filename of the repeated clustering solutions' data set
    filename_clustering_solutions = [cluster_ROI_name, '_clustering_solutions'];
    
    % filepath where the multivariate data should be saved
    filepath_multivariate_data = [filepath_STUDY, '\multivariate_data'];
    % filename of the multivariate data set
    filename_multivariate_data = [cluster_ROI_name, '_multivariate_data'];
    

    % R = 1000; % number of iterations to be performed for repeated clustering
    R = 200;
    [STUDY, ALLEEG, EEG] = ...
        bemobil_repeated_clustering_and_evaluation(STUDY, ALLEEG, EEG, ...
        outlier_sigma, N_cluster, R, cluster_ROI_MNI, ...
        quality_measure_weights, do_clustering, do_multivariate_data, ...
        filepath_STUDY, filename_STUDY, ...
        filepath_clustering_solutions, filename_clustering_solutions, ...
        filepath_multivariate_data, filename_multivariate_data);


end



% %% Finding the best N (Number of clusters)
% N = floor(size(STUDY.etc.preclust.preclustdata, 1) / size(subject_list, 2));
% number_of_clusters = N-3:N+3;
% score_NCluster = zeros(length(number_of_clusters),2);
% 
% for i = 1:numel(number_of_clusters)
% 
%     n_clust = number_of_clusters(i);
% 
%     [STUDY, ALLEEG, EEG] = ...
%         repeated_clustering_and_evaluation_custom(STUDY, ALLEEG, EEG, ...
%         outlier_sigma, n_clust, n_iterations, cluster_ROI_MNI, ...
%         quality_measure_weights, do_clustering, do_multivariate_data, ...
%         filepath_STUDY, filename_STUDY, ...
%         filepath_clustering_solutions, filename_clustering_solutions, ...
%         filepath_multivariate_data, filename_multivariate_data);
% 
% 
%     cd([study_folder, '\multiple_clustering\', cluster_ROI_name, '\clustering_solutions'])
%     load([cluster_ROI_name, '_multivariate_data'])
% 
%     [ranked_scores, ranked_solutions] = clustering_rank_solutions_custom(cluster_multivariate_data,quality_measure_weights);
% 
%     score_NCluster(i, :) = [ranked_scores(1), n_clust];
% 
% end
% 
% [~, N_idx] = max(score_NCluster(:, 1));
% N = score_NCluster(N_idx, 2);
% [STUDY, ALLEEG, EEG] = ...
%     bemobil_repeated_clustering_and_evaluation(STUDY, ALLEEG, EEG, ...
%     outlier_sigma, N, 500, cluster_ROI_MNI, ...
%     quality_measure_weights, do_clustering, do_multivariate_data, ...
%     filepath_STUDY, filename_STUDY, ...
%     filepath_clustering_solutions, filename_clustering_solutions, ...
%     filepath_multivariate_data, filename_multivariate_data);
% 
% 
% sound(sin(2*pi*700*(0:1/44100:0.7)), 44100);
% 
% % %% End of code - Remove the folder and its subfolders from the MATLAB path
% % rmpath(genpath(main_project_folder));
