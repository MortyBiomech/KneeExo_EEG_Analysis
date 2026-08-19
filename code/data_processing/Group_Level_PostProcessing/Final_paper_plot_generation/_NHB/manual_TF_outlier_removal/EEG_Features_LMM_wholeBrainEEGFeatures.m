clc
clear


%% Add necessary paths
main_project_path = 'D:\Morteza\MyProjects\ANSYMB2024\';

addpath(genpath([main_project_path, 'Code']));
addpath(genpath([main_project_path, 'data\7_STUDY\Epoched_data']));

data_path         = [main_project_path, 'data\'];
Code_path         = [main_project_path, 'Code\Matlab\data_processing\'];
                        

icatimef_path     = [data_path, '5_single-subject-EEG-analysis\', ...
                        'timewarp_test\Epoched_data'];

Subject_ICs_in_clusters_path = [Code_path, ...
    'Group_Level_PostProcessing\Final_paper_plot_generation\', ...
    'Detailed_Analysis_on_TF_regions\', ...
    'extracting Subjects and ICs in the brain clusters'];


current_path = ['D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab', ...
    '\data_processing\Group_Level_PostProcessing\', ...
    'Final_paper_plot_generation\', ...
    '_NHB\manual_TF_outlier_removal'];

ersp_results_path = [current_path, '\ersp_results'];


studyNames = {'Left Dorsal ACC', 'Left Parieto Occipital', ...
    'Left PreMot SuppMot', 'Left Prim Motor', ...
    'Right Parieto Occipital', 'Right PreMot SuppMot', 'Right Prim Motor'};



%% ========================================================================
%                          Main Loop on Studies
%  ========================================================================

% load the subject-IC pairs for our STUDY
cd(Subject_ICs_in_clusters_path)
load("Subjects_ICs_in_clusters.mat")
idx_pv = cellfun(@(x) strcmp(x, 'Prime_Visual'), ...
        SUBJECTS_ICS(:, 1));
SUBJECTS_ICS = SUBJECTS_ICS(~idx_pv, :);
cd(current_path)

% 14 subjects, 7 IC clusters
EEG_features_wholeBrain = cell(14, length(studyNames)); 

for study = 1:length(studyNames)

    disp([studyNames{study}, ' ...'])

    idx_cluster = find(cellfun(@(x) strcmp(x, SUBJECTS_ICS{study, 1}), ...
        SUBJECTS_ICS(:, 1)));
    Subjects = SUBJECTS_ICS{idx_cluster, 2}.Subjects + 4;
    [Subjects_sorted, idx_subject_sort] = sort(Subjects, 2, "ascend");

    ICs                    = SUBJECTS_ICS{idx_cluster, 2}.ICs;
    ICs_sorted             = ICs(idx_subject_sort);


    %% Load QC Results (contains the quallity control assesments)
    qc = load([current_path, '\qc_results\', ...
        studyNames{study}, '.mat']);
    qc = qc.qc_all;


    %% Loop over subjects in the cluster
    
    for sub = 1:length(Subjects_sorted)

        
        % load icatime (just load the com_X, times, freqs)
        cd(icatimef_path)
        fileExt = '.icatimef';

        fileBaseName = ['S', num2str(Subjects_sorted(sub))];
        chanList = ['comp', num2str(ICs_sorted(sub))];
        disp(['Loading S', num2str(Subjects_sorted(sub)),'.icatimef ...']);
        icatimef = load('-mat', [ fileBaseName fileExt ], chanList, ...
            'times', 'freqs', 'trialinfo', 'parameters');
        trialinfo = icatimef.trialinfo;
        ic = icatimef.(['comp', num2str(ICs_sorted(sub))]);
        ic = ic.*conj(ic);
        % crop the ic data based on the timewarpms 
        idx = find(strcmp(icatimef.parameters, 'timewarpms'));
        timewarpms = icatimef.parameters{1, idx+1};
        times = icatimef.times;
        idx_to_keep = times < timewarpms(end);
        ic = ic(:, idx_to_keep, :);
        new_times = 100*(times(idx_to_keep)/timewarpms(end));
        cd(current_path)

        
        % unique trials
        trials = {trialinfo.trial};
        trials = cellfun(@(x) str2double(x), trials);
        unique_trials = unique(trials);

        % pressure conditions
        conds = {trialinfo.cond};
        conds = cellfun(@(x) str2double(x), conds);
        unique_conds = unique(conds);


        % calculate the baseline per subject/ic
        mean_TF_qc = cell(1, 3);
        for c = 1:3
            [~, trial_c_idx] = find(conds == unique_conds(c));
            ic_c_qc = ic(:, :, trial_c_idx(~qc{sub, c}.isBad));
            mean_TF_qc{1, c} = mean(ic_c_qc, 3);
        end
        baseline_qc = mean(mean(cat(3, mean_TF_qc{:}), 3), 2);
        

        trial_bad = zeros(length(trials), 2);
        trial_bad(:, 1) = trials;
        for c = 1:3
            [~, trial_c_idx] = find(conds == unique_conds(c));
            trial_bad(qc{sub, c}.isBad, 2) = 1;
        end

        % baseline correction
        norm_ic = ic ./ repmat(baseline_qc, 1, size(ic, 2), size(ic, 3));


        % bands index 
        if sub == 1
            freqs = icatimef.freqs;
            theta = [4 8];
            alpha = [8 14];
            beta  = [14 30];
            theta_idx = find(freqs >= theta(1) & freqs <= theta(2));
            alpha_idx = find(freqs >= alpha(1) & freqs <= alpha(2));
            beta_idx  = find(freqs > beta(1) & freqs <= beta(2));
        end


        % EEG features 
        % whole cycle theta
        mean_theta = mean(mean(norm_ic(theta_idx, :, :), 2), 1);
        mean_theta = squeeze(mean_theta);
        % whole cycle alpha
        mean_alpha = mean(mean(norm_ic(alpha_idx, :, :), 2), 1);
        mean_alpha = squeeze(mean_alpha);
        % whole cycle beta
        mean_beta = mean(mean(norm_ic(beta_idx, :, :), 2), 1);
        mean_beta = squeeze(mean_beta);
        

        mean_theta_trial = [];
        mean_alpha_trial = [];
        mean_beta_trial  = [];
        
        trial_cond = [];
        for t = 1:length(unique_trials)
            trial_idx = find(trials == unique_trials(t));
            trial_idx_noBad_trial = trial_idx(~trial_bad(trial_idx, 2));
            if isempty(trial_idx_noBad_trial)
                mean_theta_trial = cat(1, mean_theta_trial, nan);
                mean_alpha_trial = cat(1, mean_alpha_trial, nan);
                mean_beta_trial = cat(1, mean_beta_trial, nan);
            else
                mean_theta_trial = cat(1, mean_theta_trial, ...
                    mean(mean_theta(trial_idx_noBad_trial)));
                mean_alpha_trial = cat(1, mean_alpha_trial, ...
                    mean(mean_alpha(trial_idx_noBad_trial)));
                mean_beta_trial = cat(1, mean_beta_trial, ...
                    mean(mean_beta(trial_idx_noBad_trial)));
            end
            trial_cond = cat(1, trial_cond, conds(trial_idx(1)));
        end

        Subject = repmat(Subjects_sorted(sub), length(unique_trials), 1);
        sub_eeg_table = table(Subject, unique_trials', trial_cond, ...
            mean_theta_trial, 10*log10(mean_theta_trial), ...
            mean_alpha_trial, 10*log10(mean_alpha_trial), ...
            mean_beta_trial, 10*log10(mean_beta_trial), ...
            'VariableNames', {'Subject', 'Trial', 'Cond', ...
            'Theta', 'Theta_log', ...
            'Alpha', 'Alpha_log', ...
            'Beta', 'Beta_log'});


        EEG_features_wholeBrain{Subjects_sorted(sub)-4, study} = sub_eeg_table;

    end

end

save([current_path, '\EEG_features_wholeBrain.mat'], "EEG_features_wholeBrain");