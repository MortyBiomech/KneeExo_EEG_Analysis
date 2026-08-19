clc
clear


%% Add necessary paths
main_project_path = 'D:\Morteza\MyProjects\ANSYMB2024\';

addpath(genpath([main_project_path, 'Code']));
addpath(genpath([main_project_path, 'data\7_STUDY\Epoched_data']));

data_path         = [main_project_path, 'data\'];
Code_path         = [main_project_path, 'Code\Matlab\data_processing\'];
all_STUDY_PATH    = [data_path, '7_STUDY\Epoched_data\', ...
                        'multiple_clustering\'];

icatimef_path     = [data_path, '5_single-subject-EEG-analysis\', ...
                        'timewarp_test\Epoched_data'];
epoched_data_path = [data_path, '6_Trials_Info_and_Epoched_data\'];
ersp_data_path    = [data_path, '7_STUDY\Epoched_data\Final_figures', ...
                        '\ERSP\Three Pressure Conditions\', ...
                        'p 0.01 ersp results\'];
Subject_ICs_in_clusters_path = [Code_path, ...
    'Group_Level_PostProcessing\Final_paper_plot_generation\', ...
    'Detailed_Analysis_on_TF_regions\', ...
    'extracting Subjects and ICs in the brain clusters'];

current_path = ['D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab', ...
    '\data_processing\Group_Level_PostProcessing\', ...
    'Final_paper_plot_generation\', ...
    '_NHB\manual_TF_outlier_removal'];

titles = {'Low Pressure', 'Medium Pressure', 'High Pressure'};
studyNames = {'Left Dorsal ACC', 'Left Parieto Occipital', ...
    'Left PreMot SuppMot', 'Left Prim Motor', 'Prime Visual', ...
    'Right Parieto Occipital', 'Right PreMot SuppMot', 'Right Prim Motor'};



%% ==============================================
%  Create "stats" parameter for std_stat function
%  ==============================================
stats = create_stats();



%% ========================================================================
%                          Main Loop on Studies
%  ========================================================================

% load the subject-IC pairs for our STUDY
cd(Subject_ICs_in_clusters_path)
load("Subjects_ICs_in_clusters.mat")
cd(current_path)

for study = [4, 8] %:length(studyNames) % 4 & 8:left & right prime motor

    disp([studyNames{study}, ' ...'])

    idx_cluster = find(cellfun(@(x) strcmp(x, SUBJECTS_ICS{study, 1}), ...
        SUBJECTS_ICS(:, 1)));
    Subjects = SUBJECTS_ICS{idx_cluster, 2}.Subjects + 4;
    [Subjects_sorted, idx_subject_sort] = sort(Subjects, 2, "ascend");

    ICs                    = SUBJECTS_ICS{idx_cluster, 2}.ICs;
    ICs_sorted             = ICs(idx_subject_sort);


    % allersp = cell(3, 1);
    qc_all = cell(length(Subjects_sorted), 3);
    allersp_qc = cell(length(Subjects_sorted), 3);
    allersp = cell(length(Subjects_sorted), 3);
    for sub = 1:length(Subjects_sorted)

        cd(icatimef_path)
        fileExt = '.icatimef';
        
        % load icatime (just load the com_X, times, freqs)
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

        for c = 1:length(unique_conds)
            ic_c_qc = cell(sum(conds == unique_conds(c)), 1);
            [~, trial_c_idx] = find(conds == unique_conds(c));
            ic_tmp = ic(:, :, trial_c_idx);
            for tc = 1:length(ic_c_qc)
                ic_c_qc{tc, 1} = ic_tmp(:, :, tc);
            end

            [qc, isBad] = tf_qc_bad_trials(ic_c_qc, icatimef.freqs, ...
                trials(trial_c_idx)', ...
                'HighBand', [35 80], ...
                'RefBand',  [8 30], ...
                'HotZ', 5, ...
                'Zth', 3, ...
                'CorrType', 'Spearman');

            qc_all{sub, c} = qc; 
        end
        
        

        % calculate allersp with and without QC
        % calculate the baseline per subject/ic
        mean_TF = cell(1, 3);
        mean_TF_qc = cell(1, 3);
        for c = 1:3
            [~, trial_c_idx] = find(conds == unique_conds(c));
            ic_c_qc = ic(:, :, trial_c_idx(~qc_all{sub, c}.isBad));
            mean_TF_qc{1, c} = mean(ic_c_qc, 3);

            ic_c = ic(:, :, trial_c_idx);
            mean_TF{1, c} = mean(ic_c, 3);
        end
        baseline_qc = mean(mean(cat(3, mean_TF_qc{:}), 3), 2);
        baseline = mean(mean(cat(3, mean_TF{:}), 3), 2);
        
        % now calculate the ersp and fill the allersp with 10*log10(X)
        for c = 1:3
            [~, trial_c_idx] = find(conds == unique_conds(c));
            ic_c_qc = ic(:, :, trial_c_idx(~qc_all{sub, c}.isBad));
            mean_TF_tmp_qc = mean(ic_c_qc, 3);
            allersp_qc{sub, c} = 10*log10(mean_TF_tmp_qc ./ ...
                repmat(baseline_qc, 1, size(mean_TF_tmp_qc, 2)));

            ic_c = ic(:, :, trial_c_idx);
            mean_TF_tmp = mean(ic_c, 3);
            allersp{sub, c} = 10*log10(mean_TF_tmp ./ ...
                repmat(baseline, 1, size(mean_TF_tmp, 2)));
        end


    end




    %% Save QC results
    % folderName = [current_path, '\qc_results'];
    % if ~exist("folderName", "dir")
    %     mkdir(folderName)
    % end
    % folderName = [current_path, '\qc_results\', studyNames{study}];
    % save(folderName, 'qc_all')



    %% plot the ERSPs per subject with/without qc assessment and save them
    % plt_save_ERSP_qc(Subjects_sorted, ICs_sorted, ...
    %     allersp_qc, allersp, new_times, icatimef.freqs, ...
    %     studyNames{study}, current_path)
    


    %% statistical analysis with/without bad trial removal
    % change the allersp shape
    allersp_new = cell(3, 1);
    allersp_qc_new = cell(3, 1);
    for c = 1:3
        allersp_new{c, 1} = cat(3, allersp(:, c));
        tmp = allersp_new{c, 1};
        allersp_new{c, 1} = cat(3, tmp{:});

        allersp_qc_new{c, 1} = cat(3, allersp_qc(:, c));
        tmp = allersp_qc_new{c, 1};
        allersp_qc_new{c, 1} = cat(3, tmp{:});
    end

    % % we need to make the stats parameters once
    % if study == 1
    %     stats = create_stats();
    % end
    if size(allersp_new{1, 1}, 3) < 9
        stats.fieldtrip.naccu = ...
            prod(repmat(3, 1, size(allersp_new{1, 1}, 3)));
    end
    stats.fieldtrip.alpha = 0.05;     % changing alpha from 0.01 to 0.05
    
    % make sure about the alpha in the plotting part
    rm_anova_cluster_based(allersp_new, allersp_qc_new, ...
        icatimef.times(1:135), icatimef.freqs, ...
        stats, studyNames{study}, current_path); 



end

