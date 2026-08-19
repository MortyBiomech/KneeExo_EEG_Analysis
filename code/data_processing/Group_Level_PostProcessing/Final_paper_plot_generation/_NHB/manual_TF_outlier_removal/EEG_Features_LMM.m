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


% In previous analysis on the ERSP data, we found pressure related changes
% in TF region just within these two brain clusters. 
studyNames = {'Left Prim Motor', 'Right Prim Motor'};



% %% ==============================================
% %  Create "stats" parameter for std_stat function
% %  ==============================================
% stats = create_stats();



%% ========================================================================
%                          Main Loop on Studies
%  ========================================================================

% load the subject-IC pairs for our STUDY
cd(Subject_ICs_in_clusters_path)
load("Subjects_ICs_in_clusters.mat")
tmp = SUBJECTS_ICS;
SUBJECTS_ICS = cell(length(studyNames), 2);
SUBJECTS_ICS(1, 1) = tmp(4, 1); SUBJECTS_ICS(1, 2) = tmp(4, 2);
SUBJECTS_ICS(2, 1) = tmp(8, 1); SUBJECTS_ICS(2, 2) = tmp(8, 2);
cd(current_path)


EEG_features = cell(14, 2); % 14 subjects; L/R M1 clusters
LR = {'Left', 'Right'};
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

        % load ersp_results
        cd(ersp_results_path)
        load([LR{study}, ' Prim Motor ersp_result.mat'])


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
        trials = cellfun(@(x) str2num(x), trials);
        unique_trials = unique(trials);

        % pressure conditions
        conds = {trialinfo.cond};
        conds = cellfun(@(x) str2num(x), conds);
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
            alpha = [8 14];
            beta  = [14 30];
            alpha_idx = find(freqs >= alpha(1) & freqs <= alpha(2));
            beta_idx  = find(freqs > beta(1) & freqs <= beta(2));

            flx_idx = find(new_times > 0 & new_times <= 50);
            ext_idx = find(new_times > 50 & new_times <= 100);
        end


        % EEG features 
        % whole cycle alpha
        mean_alpha = mean(mean(norm_ic(alpha_idx, :, :), 2), 1);
        mean_alpha = squeeze(mean_alpha);
        % whole cycle beta
        mean_beta = mean(mean(norm_ic(beta_idx, :, :), 2), 1);
        mean_beta = squeeze(mean_beta);
        % flexion part alpha
        mean_alpha_flx = mean(mean(norm_ic(alpha_idx, flx_idx, :), 2), 1);
        mean_alpha_flx = squeeze(mean_alpha_flx);
        % flexion part beta
        mean_beta_flx = mean(mean(norm_ic(beta_idx, flx_idx, :), 2), 1);
        mean_beta_flx = squeeze(mean_beta_flx);
        % extension part alpha
        mean_alpha_ext = mean(mean(norm_ic(alpha_idx, ext_idx, :), 2), 1);
        mean_alpha_ext = squeeze(mean_alpha_ext);
        % extension part beta
        mean_beta_ext = mean(mean(norm_ic(beta_idx, ext_idx, :), 2), 1);
        mean_beta_ext = squeeze(mean_beta_ext);
        


        % EEG Feature on the identified ROI from rm-ANOVA 
        mask = pcond_qc{1,1};
        % whole cycle alpha
        maskR = false(size(mask));
        maskR(alpha_idx, :) = mask(alpha_idx, :);  
        mask3 = repmat(maskR, 1, 1, size(norm_ic,3));
        mean_alpha_roi = ...
            mean(reshape(norm_ic(mask3), [], size(norm_ic, 3)), 1);
        % whole cycle beta
        maskR = false(size(mask));
        maskR(beta_idx, :) = mask(beta_idx, :);  
        mask3 = repmat(maskR, 1, 1, size(norm_ic,3));
        mean_beta_roi = ...
            mean(reshape(norm_ic(mask3), [], size(norm_ic, 3)), 1);
        % flexion part alpha
        norm_ic_s = norm_ic(alpha_idx, flx_idx, :);
        maskR = mask(alpha_idx, flx_idx);
        mask3 = repmat(maskR, 1, 1, size(norm_ic,3));
        mean_alpha_flx_roi = ...
            mean(reshape(norm_ic_s(mask3), [], size(norm_ic, 3)), 1);
        % flexion part beta
        norm_ic_s = norm_ic(beta_idx, flx_idx, :);
        maskR = mask(beta_idx, flx_idx);
        mask3 = repmat(maskR, 1, 1, size(norm_ic,3));
        mean_beta_flx_roi = ...
            mean(reshape(norm_ic_s(mask3), [], size(norm_ic, 3)), 1);
        % extension part alpha
        norm_ic_s = norm_ic(alpha_idx, ext_idx, :);
        maskR = mask(alpha_idx, ext_idx);
        mask3 = repmat(maskR, 1, 1, size(norm_ic,3));
        mean_alpha_ext_roi = ...
            mean(reshape(norm_ic_s(mask3), [], size(norm_ic, 3)), 1);
        % extension part beta
        norm_ic_s = norm_ic(beta_idx, ext_idx, :);
        maskR = mask(beta_idx, ext_idx);
        mask3 = repmat(maskR, 1, 1, size(norm_ic,3));
        mean_beta_ext_roi = ...
            mean(reshape(norm_ic_s(mask3), [], size(norm_ic, 3)), 1);
        

        
        mean_alpha_trial = [];
        mean_beta_trial  = [];
        mean_alpha_flx_trial = [];
        mean_alpha_ext_trial = [];
        mean_beta_flx_trial = [];
        mean_beta_ext_trial = [];

        mean_alpha_roi_trial = [];
        mean_beta_roi_trial  = [];
        mean_alpha_flx_roi_trial = [];
        mean_alpha_ext_roi_trial = [];
        mean_beta_flx_roi_trial = [];
        mean_beta_ext_roi_trial = [];

        trial_cond = [];
        for t = 1:length(unique_trials)
            trial_idx = find(trials == unique_trials(t));
            trial_idx_noBad_trial = trial_idx(~trial_bad(trial_idx, 2));
            if isempty(trial_idx_noBad_trial)
                mean_alpha_trial = cat(1, mean_alpha_trial, nan);
                mean_beta_trial = cat(1, mean_beta_trial, nan);
                mean_alpha_flx_trial = cat(1, mean_alpha_flx_trial, nan);
                mean_alpha_ext_trial = cat(1, mean_alpha_ext_trial, nan);
                mean_beta_flx_trial = cat(1, mean_beta_flx_trial, nan);
                mean_beta_ext_trial = cat(1, mean_beta_ext_trial, nan);

                mean_alpha_roi_trial = cat(1, mean_alpha_roi_trial, nan);
                mean_beta_roi_trial = cat(1, mean_beta_roi_trial, nan);
                mean_alpha_flx_roi_trial = cat(1, mean_alpha_flx_roi_trial, nan);
                mean_alpha_ext_roi_trial = cat(1, mean_alpha_ext_roi_trial, nan);
                mean_beta_flx_roi_trial = cat(1, mean_beta_flx_roi_trial, nan);
                mean_beta_ext_roi_trial = cat(1, mean_beta_ext_roi_trial, nan);

            else
                mean_alpha_trial = cat(1, mean_alpha_trial, ...
                    mean(mean_alpha(trial_idx_noBad_trial)));
                mean_beta_trial = cat(1, mean_beta_trial, ...
                    mean(mean_beta(trial_idx_noBad_trial)));
                mean_alpha_flx_trial = cat(1, mean_alpha_flx_trial, ...
                    mean(mean_alpha_flx(trial_idx_noBad_trial)));
                mean_alpha_ext_trial = cat(1, mean_alpha_ext_trial, ...
                    mean(mean_alpha_ext(trial_idx_noBad_trial)));
                mean_beta_flx_trial = cat(1, mean_beta_flx_trial, ...
                    mean(mean_beta_flx(trial_idx_noBad_trial)));
                mean_beta_ext_trial = cat(1, mean_beta_ext_trial, ...
                    mean(mean_beta_ext(trial_idx_noBad_trial)));

                mean_alpha_roi_trial = cat(1, mean_alpha_roi_trial, ...
                    mean(mean_alpha_roi(trial_idx_noBad_trial)));
                mean_beta_roi_trial = cat(1, mean_beta_roi_trial, ...
                    mean(mean_beta_roi(trial_idx_noBad_trial)));
                mean_alpha_flx_roi_trial = cat(1, mean_alpha_flx_roi_trial, ...
                    mean(mean_alpha_flx_roi(trial_idx_noBad_trial)));
                mean_alpha_ext_roi_trial = cat(1, mean_alpha_ext_roi_trial, ...
                    mean(mean_alpha_ext_roi(trial_idx_noBad_trial)));
                mean_beta_flx_roi_trial = cat(1, mean_beta_flx_roi_trial, ...
                    mean(mean_beta_flx_roi(trial_idx_noBad_trial)));
                mean_beta_ext_roi_trial = cat(1, mean_beta_ext_roi_trial, ...
                    mean(mean_beta_ext_roi(trial_idx_noBad_trial)));

            end
            trial_cond = cat(1, trial_cond, conds(trial_idx(1)));
        end

        Subject = repmat(Subjects_sorted(sub), length(unique_trials), 1);
        sub_eeg_table = table(Subject, unique_trials', trial_cond, ...
            10*log10(mean_alpha_trial), 10*log10(mean_beta_trial), ...
            10*log10(mean_alpha_flx_trial), 10*log10(mean_alpha_ext_trial), ...
            10*log10(mean_beta_flx_trial), 10*log10(mean_beta_ext_trial), ...
            10*log10(mean_alpha_roi_trial), 10*log10(mean_beta_roi_trial), ...
            10*log10(mean_alpha_flx_roi_trial), 10*log10(mean_alpha_ext_roi_trial), ...
            10*log10(mean_beta_flx_roi_trial), 10*log10(mean_beta_ext_roi_trial), ...
            'VariableNames', {'Subject', 'Trial', 'Cond', ...
            'Alpha', 'Beta', ...
            'Alpha_Flx', 'Alpha_Ext', ...
            'Beta_Flx', 'Beta_Ext', ...
            'Alpha_roi', 'Beta_roi', ...
            'Alpha_Flx_roi', 'Alpha_Ext_roi', ...
            'Beta_Flx_roi', 'Beta_Ext_roi'});


        EEG_features{Subjects_sorted(sub)-4, study} = sub_eeg_table;

    end

end

save([current_path, '\EEG_features.mat'], "EEG_features");