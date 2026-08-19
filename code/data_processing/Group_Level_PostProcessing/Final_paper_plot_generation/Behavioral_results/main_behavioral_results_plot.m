clc
clear


%% Add paths
addpath(genpath('D:\Morteza\MyProjects\ANSYMB2024\Code'))
data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
epoched_data_path = [data_path, '6_Trials_Info_and_Epoched_data\'];
current_path = ['D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab', ...
    '\data_processing\Group_Level_PostProcessing\', ...
    'Final_paper_plot_generation\Behavioral_results'];


%% Main Loop
subject_list = 5:18;
Subject_Tracking_Error = cell(length(subject_list), 1);
Subject_Score = cell(length(subject_list), 1);
for sub = 1:length(subject_list)
    
    %% Load the epoched experimental data
    folderName = [epoched_data_path, 'sub-', ...
        num2str(subject_list(sub))];
    cd(folderName)
    disp(['Loading data from subject ', num2str(subject_list(sub)), ' ...'])
    load Epochs_FlextoFlex_based.mat
    load Trials_Info.mat
    % extract the EXP_stream
    EXP_data = cellfun(@(x) x.EXP_stream, Epochs_FlextoFlex_based, ...
        'UniformOutput', false);
    % free up the memory
    clear Epochs_FlextoFlex_based
    cd(current_path)

    %% Calculate the tracking error & Subjective Scores (1-10 scale)
    tracking_error = [];
    P1_tracking_error = [];
    P3_tracking_error = [];
    P6_tracking_error = [];
    P1_scores = [];
    P3_scores = [];
    P6_scores = [];
    for trial = 1:length(EXP_data)
    
        % check if we are at the experimental trial
        if ~strcmp(Trials_Info{trial}.General.Description, 'Experiment')
            continue
        end

        % non-empty trial
        if isempty(EXP_data{trial}.Times)
            continue
        end


        trial_tracking_error = ...
            cellfun(@(x1, x2) rms(x1 - x2), ...
                      EXP_data{trial}.Encoder_angle, ... % x1
                      EXP_data{trial}.Ref_angle, ...     % x2
                      'UniformOutput', false);
        mean_trial_tracking_error = mean(cell2mat(trial_tracking_error));

        tracking_error = [tracking_error, mean_trial_tracking_error];

        P = Trials_Info{trial}.General.Pressure;
        switch  P
            case 1
                P1_tracking_error = [P1_tracking_error, ...
                    mean_trial_tracking_error];
            case 3
                P3_tracking_error = [P3_tracking_error, ...
                    mean_trial_tracking_error];
            case 6
                P6_tracking_error = [P6_tracking_error, ...
                    mean_trial_tracking_error];
        end


        score = Trials_Info{trial}.General.Score;
        P = Trials_Info{trial}.General.Pressure;
        switch  P
            case 1
                P1_scores = [P1_scores, score];
            case 3
                P3_scores = [P3_scores, score];
            case 6
                P6_scores = [P6_scores, score];
        end

    end

    % Saving the tracking errors and trial scores per subject
    Subject_Tracking_Error{sub} = struct('P1_error', P1_tracking_error, ...
                                         'P3_error', P3_tracking_error, ...
                                         'P6_error', P6_tracking_error, ...
                                         'Whole_Exp', tracking_error);

    trial_score = ...
            cellfun(@(x) x.General.Score, ...
                      Trials_Info, ...
                      'UniformOutput', false);
    all_scores = cell2mat(trial_score);

    Subject_Score{sub} = struct('P1_scores', P1_scores, ...
                                'P3_scores', P3_scores, ...
                                'P6_scores', P6_scores, ...
                                'Whole_Exp', all_scores);

end


%% Save the tracking error and subjective scores structures
save(fullfile(current_path, 'Tracking_Errors'), 'Subject_Tracking_Error')
save(fullfile(current_path, 'Subjective_Scores'), 'Subject_Score')


%% Load saved data
load("Tracking_Errors")
load("Subjective_Scores")


%% Remove outliers in the tracking error values
s = 0;
for sub = 1:length(subject_list)

    x = Subject_Tracking_Error{sub}.P1_error;
    x_outlier = isoutlier(x);
    s = s + sum(x_outlier);
    Subject_Tracking_Error{sub}.P1_error = x(~x_outlier);
    Subject_Score{sub}.P1_scores = Subject_Score{sub}.P1_scores(~x_outlier);

    x = Subject_Tracking_Error{sub}.P3_error;
    x_outlier = isoutlier(x);
    s = s + sum(x_outlier);
    Subject_Tracking_Error{sub}.P3_error = x(~x_outlier);
    Subject_Score{sub}.P3_scores = Subject_Score{sub}.P3_scores(~x_outlier);

    x = Subject_Tracking_Error{sub}.P6_error;
    x_outlier = isoutlier(x);
    s = s + sum(x_outlier);
    Subject_Tracking_Error{sub}.P6_error = x(~x_outlier);
    Subject_Score{sub}.P6_scores = Subject_Score{sub}.P6_scores(~x_outlier);

end



%% Main plots
P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
customColors = [P1_color; P3_color; P6_color];

mean_per_subj_error = zeros(length(subject_list), 3);
std_per_subj_error = zeros(length(subject_list), 3);
for sub = 1:length(subject_list)
    mean_per_subj_error(sub, :) = ...
        [mean(Subject_Tracking_Error{sub}.P1_error), ...
         mean(Subject_Tracking_Error{sub}.P3_error), ...
         mean(Subject_Tracking_Error{sub}.P6_error)];
    std_per_subj_error(sub, :) = ...
        [std(Subject_Tracking_Error{sub}.P1_error, 0), ...
         std(Subject_Tracking_Error{sub}.P3_error, 0), ...
         std(Subject_Tracking_Error{sub}.P6_error, 0)];
end

condNames = {'Pressure 1 bar','Pressure 3 bar','Pressure 6 bar'};   % label your conditions

% ---- Compute group summary --------------------------------------------
group_mean_error = mean(mean_per_subj_error, 1);         % 1x3
group_std_error   = std(mean_per_subj_error, 0, 1);      % 1x3  (STD across subjects)

% Insert a blank row (all NaNs) to create a visual gap before the group bars
mean_all_error  = [mean_per_subj_error; nan(1,3); group_mean_error];   % 16x3 (14 + gap + group)
std_all_error   = [std_per_subj_error;   nan(1,3); group_std_error];

% X labels: S1..S14, blank gap, Group
xlabels = [compose("S%d",1:14), "", "Group mean"];






mean_per_subj_score = zeros(length(subject_list), 3);
std_per_subj_score = zeros(length(subject_list), 3);
for sub = 1:length(subject_list)
    mean_per_subj_score(sub, :) = ...
        [mean(Subject_Score{sub}.P1_scores), ...
         mean(Subject_Score{sub}.P3_scores), ...
         mean(Subject_Score{sub}.P6_scores)];
    std_per_subj_score(sub, :) = ...
        [std(Subject_Score{sub}.P1_scores, 0), ...
         std(Subject_Score{sub}.P3_scores, 0), ...
         std(Subject_Score{sub}.P6_scores, 0)];
end

% ---- Compute group summary --------------------------------------------
group_mean_score = mean(mean_per_subj_score, 1);        % 1x3
group_std_score  = std(mean_per_subj_score, 0, 1);      % 1x3  (STD across subjects)

% Insert a blank row (all NaNs) to create a visual gap before the group bars
mean_all_score  = [mean_per_subj_score; nan(1,3); group_mean_score];   % 16x3 (14 + gap + group)
std_all_score   = [std_per_subj_score;   nan(1,3); group_std_score];





%% Statistical Test
% check normality of tracking error and score values per subject
normality_check_error = zeros(length(subject_list), 3);
normality_check_score = zeros(length(subject_list), 3);
for sub = 1:length(subject_list)
    [H, ~, ~] = swtest(Subject_Tracking_Error{sub}.P1_error, 0.05);
    normality_check_error(sub, 1) = H; 
    [H,~, ~] = swtest(Subject_Tracking_Error{sub}.P3_error, 0.05);
    normality_check_error(sub, 2) = H; 
    [H, ~, ~] = swtest(Subject_Tracking_Error{sub}.P6_error, 0.05);
    normality_check_error(sub, 3) = H; 

    if sub == 12
        normality_check_score(sub, 1) = 1; 
    else
        [H, ~, ~] = swtest(Subject_Score{sub}.P1_scores, 0.05);
        normality_check_score(sub, 1) = H; 
    end
    
    [H, ~, ~] = swtest(Subject_Score{sub}.P3_scores, 0.05);
    normality_check_score(sub, 2) = H; 
    [H, ~, ~] = swtest(Subject_Score{sub}.P6_scores, 0.05);
    normality_check_score(sub, 3) = H; 
end



%% Based on data normality choose parametric or non-parametric tests

% Tracking error
p_values_error = zeros(length(subject_list), 3); % column1: P1 vs. P3
                                                 % column2: P1 vs. P6
                                                 % column3: P3 vs. P6
for sub = 1:length(subject_list)
    
    % P1 vs. P3 tracking error
    data1 = Subject_Tracking_Error{sub}.P1_error;
    data2 = Subject_Tracking_Error{sub}.P3_error;
    if normality_check_error(sub, 1) == 0 && ...
            normality_check_error(sub, 2) == 0
        % check for equal variance
        H = vartest2(data1, data2); % H = 0 equal variances 
        if H == 0
            % Unpaired ttest
            [~, p_values_error(sub, 1), ~, ~] = ttest2(data1, data2);
        elseif H == 1
            % Unequal variance - Welch's ttest
            [~, p_values_error(sub, 1), ~, ~] = ...
                ttest2(data1, data2, 'Vartype','unequal');
        end
    else % if one of the either data1 or data2 cannot pass normality test
        % non-parametric test (Wilcoxon rank-sum test)
        [p_values_error(sub, 1), h, stats] = ranksum(data1, data2);
    end


    % P1 vs. P6 tracking error
    data1 = Subject_Tracking_Error{sub}.P1_error;
    data2 = Subject_Tracking_Error{sub}.P6_error;
    if normality_check_error(sub, 1) == 0 && ...
            normality_check_error(sub, 3) == 0
        % check for equal variance
        H = vartest2(data1, data2); % H = 0 equal variances 
        if H == 0
            % Unpaired ttest
            [~, p_values_error(sub, 2), ~, ~] = ttest2(data1, data2);
        elseif H == 1
            % Unequal variance - Welch's ttest
            [~, p_values_error(sub, 2), ~, ~] = ...
                ttest2(data1, data2, 'Vartype','unequal');
        end
    else % if one of the either data1 or data2 cannot pass normality test
        % non-parametric test (Wilcoxon rank-sum test)
        [p_values_error(sub, 2), ~, ~] = ranksum(data1, data2);
    end


    % P3 vs. P6 tracking error
    data1 = Subject_Tracking_Error{sub}.P3_error;
    data2 = Subject_Tracking_Error{sub}.P6_error;
    if normality_check_error(sub, 2) == 0 && ...
            normality_check_error(sub, 3) == 0
        % check for equal variance
        H = vartest2(data1, data2); % H = 0 equal variances 
        if H == 0
            % Unpaired ttest
            [~, p_values_error(sub, 3), ~, ~] = ttest2(data1, data2);
        elseif H == 1
            % Unequal variance - Welch's ttest
            [~, p_values_error(sub, 3), ~, ~] = ...
                ttest2(data1, data2, 'Vartype','unequal');
        end
    else % if one of the either data1 or data2 cannot pass normality test
        % non-parametric test (Wilcoxon rank-sum test)
        [p_values_error(sub, 3), ~, ~] = ranksum(data1, data2);
    end

end


% Across subjects means
p_values_error_group = zeros(1, 3);
normality_check_error_group = zeros(1, 3);

[H, ~, ~] = swtest(mean_per_subj_error(:, 1), 0.05);
normality_check_error_group(1) = H; 
[H, ~, ~] = swtest(mean_per_subj_error(:, 2), 0.05);
normality_check_error_group(2) = H; 
[H, ~, ~] = swtest(mean_per_subj_error(:, 3), 0.05);
normality_check_error_group(3) = H; 

% P1 vs. P3 tracking error
data1 = mean_per_subj_error(:, 1); % P1
data2 = mean_per_subj_error(:, 2); % P3
if normality_check_error_group(1) == 0 && ...
        normality_check_error_group(2) == 0
    % check for equal variance
    H = vartest2(data1, data2); % H = 0 equal variances 
    if H == 0
        % Paired ttest
        [~, p_values_error_group(1), ~, ~] = ttest(data1, data2);
    elseif H == 1
        % Unequal variance - Welch's ttest
        [~, p_values_error_group(1), ~, ~] = ...
            ttest(data1, data2, 'Vartype','unequal');
    end
else % if one of the either data1 or data2 cannot pass normality test
    % non-parametric test (Wilcoxon rank-sum test)
    [p_values_error_group(1), ~, ~] = ranksum(data1, data2);
end

% P1 vs. P6 tracking error
data1 = mean_per_subj_error(:, 1); % P1
data2 = mean_per_subj_error(:, 3); % P6
if normality_check_error_group(1) == 0 && ...
        normality_check_error_group(3) == 0
    % check for equal variance
    H = vartest2(data1, data2); % H = 0 equal variances 
    if H == 0
        % Paired ttest
        [~, p_values_error_group(2), ~, ~] = ttest(data1, data2);
    elseif H == 1
        % Unequal variance - Welch's ttest
        [~, p_values_error_group(2), ~, ~] = ...
            ttest(data1, data2, 'Vartype','unequal');
    end
else % if one of the either data1 or data2 cannot pass normality test
    % non-parametric test (Wilcoxon rank-sum test)
    [p_values_error_group(2), ~, ~] = ranksum(data1, data2);
end

% P3 vs. P6 tracking error
data1 = mean_per_subj_error(:, 2); % P3
data2 = mean_per_subj_error(:, 3); % P6
if normality_check_error_group(2) == 0 && ...
        normality_check_error_group(3) == 0
    % check for equal variance
    H = vartest2(data1, data2); % H = 0 equal variances 
    if H == 0
        % Paired ttest
        [~, p_values_error_group(3), ~, ~] = ttest(data1, data2);
    elseif H == 1
        % Unequal variance - Welch's ttest
        [~, p_values_error_group(3), ~, ~] = ...
            ttest(data1, data2, 'Vartype','unequal');
    end
else % if one of the either data1 or data2 cannot pass normality test
    % non-parametric test (Wilcoxon rank-sum test)
    [p_values_error_group(3), ~, ~] = ranksum(data1, data2);
end

% % Apply FDR Correction for multiple comparisons
% p_values_error_all = [p_values_error(:); p_values_error_group']; % Flatten the matrix
% adj_p = mafdr(p_values_error_all, 'BHFDR', true); % Apply FDR correction
% adj_p_values_error = reshape(adj_p, size(p_values_error) + [1, 0]); % Reshape back to matrix







%% Subjective Scores
p_values_score = zeros(length(subject_list), 3); % column1: P1 vs. P3
                                                 % column2: P1 vs. P6
                                                 % column3: P3 vs. P6
for sub = 1:length(subject_list)
    
    % P1 vs. P3 subjective score
    data1 = Subject_Score{sub}.P1_scores;
    data2 = Subject_Score{sub}.P3_scores;
    if normality_check_score(sub, 1) == 0 && ...
            normality_check_score(sub, 2) == 0
        % check for equal variance
        H = vartest2(data1, data2); % H = 0 equal variances 
        if H == 0
            % Unpaired ttest
            [~, p_values_score(sub, 1), ~, ~] = ttest2(data1, data2);
        elseif H == 1
            % Unequal variance - Welch's ttest
            [~, p_values_score(sub, 1), ~, ~] = ...
                ttest2(data1, data2, 'Vartype','unequal');
        end
    else % if one of the either data1 or data2 cannot pass normality test
        % non-parametric test (Wilcoxon rank-sum test)
        [p_values_score(sub, 1), h, stats] = ranksum(data1, data2);
    end


    % P1 vs. P6 subjective score
    data1 = Subject_Score{sub}.P1_scores;
    data2 = Subject_Score{sub}.P6_scores;
    if normality_check_score(sub, 1) == 0 && ...
            normality_check_score(sub, 3) == 0
        % check for equal variance
        H = vartest2(data1, data2); % H = 0 equal variances 
        if H == 0
            % Unpaired ttest
            [~, p_values_score(sub, 2), ~, ~] = ttest2(data1, data2);
        elseif H == 1
            % Unequal variance - Welch's ttest
            [~, p_values_score(sub, 2), ~, ~] = ...
                ttest2(data1, data2, 'Vartype','unequal');
        end
    else % if one of the either data1 or data2 cannot pass normality test
        % non-parametric test (Wilcoxon rank-sum test)
        [p_values_score(sub, 2), h, stats] = ranksum(data1, data2);
    end


    % P3 vs. P6 subjective score
    data1 = Subject_Score{sub}.P3_scores;
    data2 = Subject_Score{sub}.P6_scores;
    if normality_check_score(sub, 2) == 0 && ...
            normality_check_score(sub, 3) == 0
        % check for equal variance
        H = vartest2(data1, data2); % H = 0 equal variances 
        if H == 0
            % Unpaired ttest
            [~, p_values_score(sub, 3), ~, ~] = ttest2(data1, data2);
        elseif H == 1
            % Unequal variance - Welch's ttest
            [~, p_values_score(sub, 3), ~, ~] = ...
                ttest2(data1, data2, 'Vartype','unequal');
        end
    else % if one of the either data1 or data2 cannot pass normality test
        % non-parametric test (Wilcoxon rank-sum test)
        [p_values_score(sub, 3), h, stats] = ranksum(data1, data2);
    end

end


% Across subjects means
p_values_score_group = zeros(1, 3);
normality_check_score_group = zeros(1, 3);

[H, ~, ~] = swtest(mean_per_subj_score(:, 1), 0.05);
normality_check_score_group(1) = H; 
[H, ~, ~] = swtest(mean_per_subj_score(:, 2), 0.05);
normality_check_score_group(2) = H; 
[H, ~, ~] = swtest(mean_per_subj_score(:, 3), 0.05);
normality_check_score_group(3) = H; 

% P1 vs. P3 tracking error
data1 = mean_per_subj_score(:, 1); % P1
data2 = mean_per_subj_score(:, 2); % P3
if normality_check_score_group(1) == 0 && ...
        normality_check_score_group(2) == 0
    % check for equal variance
    H = vartest2(data1, data2); % H = 0 equal variances 
    if H == 0
        % Paired ttest
        [~, p_values_score_group(1), ~, ~] = ttest(data1, data2);
    elseif H == 1
        % Unequal variance - Welch's ttest
        [~, p_values_score_group(1), ~, ~] = ...
            ttest(data1, data2, 'Vartype','unequal');
    end
else % if one of the either data1 or data2 cannot pass normality test
    % non-parametric test (Wilcoxon rank-sum test)
    [p_values_score_group(1), ~, ~] = ranksum(data1, data2);
end

% P1 vs. P6 tracking error
data1 = mean_per_subj_score(:, 1); % P1
data2 = mean_per_subj_score(:, 3); % P6
if normality_check_score_group(1) == 0 && ...
        normality_check_score_group(3) == 0
    % check for equal variance
    H = vartest2(data1, data2); % H = 0 equal variances 
    if H == 0
        % Paired ttest
        [~, p_values_score_group(2), ~, ~] = ttest(data1, data2);
    elseif H == 1
        % Unequal variance - Welch's ttest
        [~, p_values_score_group(2), ~, ~] = ...
            ttest(data1, data2, 'Vartype','unequal');
    end
else % if one of the either data1 or data2 cannot pass normality test
    % non-parametric test (Wilcoxon rank-sum test)
    [p_values_score_group(2), ~, ~] = ranksum(data1, data2);
end

% P3 vs. P6 tracking error
data1 = mean_per_subj_score(:, 2); % P3
data2 = mean_per_subj_score(:, 3); % P6
if normality_check_score_group(2) == 0 && ...
        normality_check_score_group(3) == 0
    % check for equal variance
    H = vartest2(data1, data2); % H = 0 equal variances 
    if H == 0
        % Paired ttest
        [~, p_values_score_group(3), ~, ~] = ttest(data1, data2);
    elseif H == 1
        % Unequal variance - Welch's ttest
        [~, p_values_score_group(3), ~, ~] = ...
            ttest(data1, data2, 'Vartype','unequal');
    end
else % if one of the either data1 or data2 cannot pass normality test
    % non-parametric test (Wilcoxon rank-sum test)
    [p_values_score_group(3), ~, ~] = ranksum(data1, data2);
end



%% Apply FDR Correction for multiple comparisons on both tracking errors and
% subjective scores
p_values_score_all = [p_values_score(:); p_values_score_group']; % Flatten the matrix
adj_p = mafdr(p_values_score_all, 'BHFDR', true); % Apply FDR correction
adj_p_values_score = reshape(adj_p, size(p_values_score) + [1, 0]); % Reshape back to matrix

p_values_error_all = [p_values_error(:); p_values_error_group']; % Flatten the matrix
adj_p = mafdr(p_values_error_all, 'BHFDR', true); % Apply FDR correction
adj_p_values_error = reshape(adj_p, size(p_values_error) + [1, 0]); % Reshape back to matrix


% p_values_all = [p_values_score_all; p_values_error_all];
% adj_p = mafdr(p_values_all, 'BHFDR', true); % Apply FDR correction
% adj_p_values = reshape(adj_p, ...
%     size(p_values_score, 1) + 1 + ...
%     size(p_values_error, 1) + 1, 3); % Reshape back to matrix
% 
% adj_p_values_score = adj_p_values(1:15, :);
% adj_p_values_error = adj_p_values(16:end, :);





% [H, pValue, W] = swtest(Subject_Tracking_Error{12}.P3_error, 0.05);
% figure(); histogram(Subject_Tracking_Error{12}.P3_error);


%% ---- Plot grouped bars -------------------------------------------------
figure('name', ['Behavioral Results'], 'InvertHardcopy', 'off', ...
    'PaperType', 'a2', 'PaperOrientation', 'landscape');
fig_width = 1.1*(17); 
fig_height = fig_width/2.857;
set(gcf, 'PaperUnits', 'inches', 'Units', 'Inches', ...
    'PaperPositionMode', 'auto','Position',[18 7 fig_width fig_height],'Units','Inches');

tiledlayout(2, 1, "TileSpacing", "compact")

nexttile(1)
% subplot(2, 1, 1)

b_score = bar(mean_all_score,'grouped');    % grouped bar chart (3 bars per x-position)
% ylabel(sprintf('Subjective Score')); 

ylh2 = ylabel(sprintf('Subjective\nScore'), "FontSize", 16, ...
    "FontWeight", "bold", "FontName", 'Arial'); 
ylh2.Position(1) = ylh2.Position(1) - 0.4; 
ylh2.Position(2) = ylh2.Position(2) + 0.2; 

xticks(1:numel(xlabels));
box off;

% a little extra gap around the edges
xlim([0.3, numel(xlabels)+0.7])

% ---- Add error bars at the bar centers --------------------------------
hold on
% For each condition k, draw error bars at the x-positions of those bars
for k = 1:numel(b_score)
    % Bar centers for this condition across all x positions
    x = b_score(k).XEndPoints;
    y = mean_all_score(:,k);
    e = std_all_score(:,k);

    % errorbar automatically skips NaNs (so the blank gap stays blank)
    errorbar(x, y, e, 'k', 'linestyle', 'none', 'CapSize', 6, 'LineWidth', 1);
end

ax = gca;
ax.XMinorTick = 'off';
ax.YMinorTick = 'off';
ax.TickDir = 'none';       % ticks only outside
ax.XTickLabel = [];
ax.Layer = 'top';          % grid behind bars
ax.LineWidth = 1;

% Apply custom colors
for k = 1:numel(b_score)
    b_score(k).FaceColor = customColors(k,:);
    b_score(k).EdgeColor = 'none';   % optional: no border lines
end

set(ax,'Fontsize',16);
hold off






nexttile(2)
% subplot(2, 1, 2)

b_error = bar(mean_all_error,'grouped');    % grouped bar chart (3 bars per x-position)
ylh2 = ylabel(sprintf('Tracking Error RMS\n (degree)'), "FontSize", 16, ...
    "FontWeight", "bold", "FontName", 'Arial'); 
% ylh2_pos = ylh2.Position(2);
% ylh = ylabel(sprintf('Tracking Error RMS\n(degree)'), 'fontsize', 16, ...
%     'fontweight', 'bold', 'FontName', 'Arial');
ylh2.Position(1) = ylh2.Position(1) - 0.4; 
ylh2.Position(2) = ylh2.Position(2) + 1.1; 
% ylh2.Position(2) = ylh2_pos; 



xticks(1:numel(xlabels));
xticklabels(xlabels);
xtickangle(0);
box off;

% a little extra gap around the edges
xlim([0.3, numel(xlabels)+0.7])

% ---- Add error bars at the bar centers --------------------------------
hold on
% For each condition k, draw error bars at the x-positions of those bars
for k = 1:numel(b_error)
    % Bar centers for this condition across all x positions
    x = b_error(k).XEndPoints;
    y = mean_all_error(:,k);
    e = std_all_error(:,k);

    % errorbar automatically skips NaNs (so the blank gap stays blank)
    errorbar(x, y, e, 'k', 'linestyle', 'none', 'CapSize', 6, 'LineWidth', 1);
end

ax = gca;
ax.XMinorTick = 'off';
ax.YMinorTick = 'off';
ax.TickDir = 'none';       % ticks only outside
ax.Layer = 'top';          % grid behind bars
ax.LineWidth = 1;

% Apply custom colors
for k = 1:numel(b_error)
    b_error(k).FaceColor = customColors(k,:);
    b_error(k).EdgeColor = 'none';   % optional: no border lines
end

% Legend
legends = {' Pressure 1 bar',' Pressure 3 bar',' Pressure 6 bar', ...
           '', '', ''};
legend(legends, 'Location', 'northeast', ...
    'Orientation','vertical', 'Box', 'off');

set(gca,'Fontsize',16);
hold off


%% Add horizontal lines for statistically significant differences
% on tracking errors
nexttile(2)
hold on
alpha = 0.05/2;
yOffset = 0.3;    % vertical spacing between levels
lineWidth = 1;

pvals_P1P3 = [adj_p_values_error(1:14, 1); NaN; adj_p_values_error(15, 1)];
pvals_P1P6 = [adj_p_values_error(1:14, 2); NaN; adj_p_values_error(15, 2)];
pvals_P3P6 = [adj_p_values_error(1:14, 3); NaN; adj_p_values_error(15, 3)];

for sub = 1:length(mean_all_error)
    if sub == 15
        continue;
    end

    % x positions of bars for this subject
    xbars = [b_error(1).XEndPoints(sub), b_error(2).XEndPoints(sub), b_error(3).XEndPoints(sub)];
    ybars = [mean_all_error(sub,1), mean_all_error(sub,2), mean_all_error(sub,3)] + ...
        [std_all_error(sub,1), std_all_error(sub,2), std_all_error(sub,3)];
    
    yTop = max(ybars) + yOffset;

    % --- Pair 1: P1 vs P3
    if pvals_P1P3(sub) < alpha
        plot(xbars([1 2]), [1 1]*yTop, 'k', 'LineWidth', lineWidth, ...
            'HandleVisibility','off');
        % plot(mean(xbars([1 2])), yTop + 0.05, '*k', 'MarkerSize', 6);
        yTop = yTop + yOffset;
    end

    % --- Pair 2: P1 vs P6
    if pvals_P1P6(sub) < alpha
        plot(xbars([1 3]), [1 1]*yTop, 'k', 'LineWidth', lineWidth, ...
            'HandleVisibility','off');
        % plot(mean(xbars([1 3])), yTop + 0.05, '*k', 'MarkerSize', 6);
        yTop = yTop + yOffset;
    end

    % --- Pair 3: P3 vs P6
    if pvals_P3P6(sub) < alpha
        plot(xbars([2 3]), [1 1]*yTop, 'k', 'LineWidth', lineWidth, ...
            'HandleVisibility','off');
        % plot(mean(xbars([2 3])), yTop + 0.05, '*k', 'MarkerSize', 6);
    end

end

% on subjective scores
nexttile(1)
hold on
alpha = 0.05/2;
yOffset = 0.3;    % vertical spacing between levels
lineWidth = 1;

pvals_P1P3 = [adj_p_values_score(1:14, 1); NaN; adj_p_values_score(15, 1)];
pvals_P1P6 = [adj_p_values_score(1:14, 2); NaN; adj_p_values_score(15, 2)];
pvals_P3P6 = [adj_p_values_score(1:14, 3); NaN; adj_p_values_score(15, 3)];

for sub = 1:length(mean_all_score)
    if sub == 15
        continue;
    end

    % x positions of bars for this subject
    xbars = [b_score(1).XEndPoints(sub), b_score(2).XEndPoints(sub), b_score(3).XEndPoints(sub)];
    ybars = [mean_all_score(sub,1), mean_all_score(sub,2), mean_all_score(sub,3)] + ...
        [std_all_score(sub,1), std_all_score(sub,2), std_all_score(sub,3)];
    
    yTop = max(ybars) + yOffset;

    % --- Pair 1: P1 vs P3
    if pvals_P1P3(sub) < alpha
        plot(xbars([1 2]), [1 1]*yTop, 'k', 'LineWidth', lineWidth, ...
            'HandleVisibility','off');
        % plot(mean(xbars([1 2])), yTop + 0.05, '*k', 'MarkerSize', 6);
        yTop = yTop + yOffset;
    end

    % --- Pair 2: P1 vs P6
    if pvals_P1P6(sub) < alpha
        plot(xbars([1 3]), [1 1]*yTop, 'k', 'LineWidth', lineWidth, ...
            'HandleVisibility','off');
        % plot(mean(xbars([1 3])), yTop + 0.05, '*k', 'MarkerSize', 6);
        yTop = yTop + yOffset;
    end

    % --- Pair 3: P3 vs P6
    if pvals_P3P6(sub) < alpha
        plot(xbars([2 3]), [1 1]*yTop, 'k', 'LineWidth', lineWidth, ...
            'HandleVisibility','off');
        % plot(mean(xbars([2 3])), yTop + 0.05, '*k', 'MarkerSize', 6);
    end

end




%% Scatter plot for assessing any correlation between Scores & Errors
% Subject_Tracking_Error
X_scatter_P1 = []; X_scatter_P3 = []; X_scatter_P6 = [];
Y_scatter_P1 = []; Y_scatter_P3 = []; Y_scatter_P6 = [];
Subject_IDs_P1  = []; Subject_IDs_P3  = []; Subject_IDs_P6  = []; 
for sub = 1:length(Subject_Tracking_Error)
    X_scatter_P1 = [X_scatter_P1; Subject_Tracking_Error{sub}.P1_error'];
    X_scatter_P3 = [X_scatter_P3; Subject_Tracking_Error{sub}.P3_error'];
    X_scatter_P6 = [X_scatter_P6; Subject_Tracking_Error{sub}.P6_error'];

    Y_scatter_P1 = [Y_scatter_P1; Subject_Score{sub}.P1_scores'];
    Y_scatter_P3 = [Y_scatter_P3; Subject_Score{sub}.P3_scores'];
    Y_scatter_P6 = [Y_scatter_P6; Subject_Score{sub}.P6_scores'];

    Subject_IDs_P1 = [Subject_IDs_P1; repmat(sub, size(Subject_Score{sub}.P1_scores'))];
    Subject_IDs_P3 = [Subject_IDs_P3; repmat(sub, size(Subject_Score{sub}.P3_scores'))];
    Subject_IDs_P6 = [Subject_IDs_P6; repmat(sub, size(Subject_Score{sub}.P6_scores'))];

end

X_scatter_P1(Y_scatter_P1 == 0) = [];
Subject_IDs_P1(Y_scatter_P1 == 0) = [];
Y_scatter_P1(Y_scatter_P1 == 0) = [];

X_scatter_P3(Y_scatter_P3 == 0) = [];
Subject_IDs_P3(Y_scatter_P3 == 0) = [];
Y_scatter_P3(Y_scatter_P3 == 0) = [];

X_scatter_P6(Y_scatter_P6 == 0) = [];
Subject_IDs_P6(Y_scatter_P6 == 0) = [];
Y_scatter_P6(Y_scatter_P6 == 0) = [];



threshold_P1 = round(0.05*length(Y_scatter_P1));
threshold_P3 = round(0.05*length(Y_scatter_P3));
threshold_P6 = round(0.05*length(Y_scatter_P6));
for score = 1:10

    idx = find(Y_scatter_P1 == score);
    if length(idx) < threshold_P1
        X_scatter_P1(idx) = [];
        Y_scatter_P1(idx) = [];
        Subject_IDs_P1(idx) = [];
    end

    idx = find(Y_scatter_P3 == score);
    if length(idx) < threshold_P3
        X_scatter_P3(idx) = [];
        Y_scatter_P3(idx) = [];
        Subject_IDs_P3(idx) = [];
    end

    idx = find(Y_scatter_P6 == score);
    if length(idx) < threshold_P6
        X_scatter_P6(idx) = [];
        Y_scatter_P6(idx) = [];
        Subject_IDs_P6(idx) = [];
    end

end


score_scatter_P1 = Y_scatter_P1;
score_scatter_P3 = Y_scatter_P3;
score_scatter_P6 = Y_scatter_P6;
error_scatter_P1 = X_scatter_P1;
error_scatter_P3 = X_scatter_P3;
error_scatter_P6 = X_scatter_P6;

score_all = [score_scatter_P1; score_scatter_P3; score_scatter_P6];
error_all = [error_scatter_P1; error_scatter_P3; error_scatter_P6];
pressure  = [repmat(1, size(score_scatter_P1)); ...
             repmat(3, size(score_scatter_P3)); ...
             repmat(6, size(score_scatter_P6))];
subject_all = [Subject_IDs_P1; Subject_IDs_P3; Subject_IDs_P6];

% Tables for later LMM analysis
T_error = table(subject_all, pressure, error_all);
T_error.pressure = categorical(T_error.pressure);
T_score = table(subject_all, pressure, score_all);
T_score.pressure = categorical(T_score.pressure);



%% Do LMM for group level tracking error and score

% Score
% Fit LMM: random intercept for subject, fixed effect for pressure
lme_score = fitlme(T_score, 'score_all ~ pressure + (1|subject_all)');

% View results
disp(lme_score);
anova(lme_score); % Type III ANOVA for fixed effect
fe = fixedEffects(lme_score);
ci = coefCI(lme_score);  % Confidence intervals

% Compare Pressure 1 bar and 3 bar
contrast1 = [0 1 0]; % 2nd fixed effect (Pressure_3bar)
pValue13_score = coefTest(lme_score, contrast1);
disp('1 bar vs 3 bar:')
fprintf('Difference = %.3f, 95%% CI = [%.3f, %.3f]\n', fe(2), ci(2,1), ci(2,2));


% Compare Pressure 1 bar and 6 bar
contrast2 = [0 0 1]; % 3rd fixed effect (Pressure_6bar)
pValue16_score = coefTest(lme_score, contrast2);
disp('1 bar vs 6 bar:')
fprintf('Difference = %.3f, 95%% CI = [%.3f, %.3f]\n', fe(3), ci(3,1), ci(3,2));


% Compare Pressure 3 bar and 6 bar
contrast3 = [0 -1 1]; 
pValue36_score = coefTest(lme_score, contrast3);

estimate = fe(3) - fe(2);
covFE = lme_score.CoefficientCovariance;
se_contrast = sqrt(covFE(3,3) + covFE(2,2) - 2*covFE(2,3));
ci_low = estimate - 1.96 * se_contrast;
ci_high = estimate + 1.96 * se_contrast;
fprintf('3 bar vs 6 bar: Difference = %.3f, 95%% CI = [%.3f, %.3f]\n', estimate, ci_low, ci_high);





% Error
% Fit LMM: random intercept for subject, fixed effect for pressure
lme_error = fitlme(T_error, 'error_all ~ pressure + (1|subject_all)');

% View results
disp(lme_error);
anova(lme_error); % Type III ANOVA for fixed effect
fe = fixedEffects(lme_error);
ci = coefCI(lme_error);  % Confidence intervals

% Compare Pressure 1 bar and 3 bar
contrast1 = [0 1 0]; % 2nd fixed effect (Pressure_3bar)
pValue13_error = coefTest(lme_error, contrast1);
disp('1 bar vs 3 bar:')
fprintf('Difference = %.3f, 95%% CI = [%.3f, %.3f]\n', fe(2), ci(2,1), ci(2,2));

% Compare Pressure 1 bar and 6 bar
contrast2 = [0 0 1]; % 3rd fixed effect (Pressure_6bar)
pValue16_error = coefTest(lme_error, contrast2);
disp('1 bar vs 6 bar:')
fprintf('Difference = %.3f, 95%% CI = [%.3f, %.3f]\n', fe(3), ci(3,1), ci(3,2));


% Compare Pressure 3 bar and 6 bar
contrast3 = [0 -1 1]; 
pValue36_error = coefTest(lme_error, contrast3);
estimate = fe(3) - fe(2);
covFE = lme_error.CoefficientCovariance;
se_contrast = sqrt(covFE(3,3) + covFE(2,2) - 2*covFE(2,3));
ci_low = estimate - 1.96 * se_contrast;
ci_high = estimate + 1.96 * se_contrast;
fprintf('3 bar vs 6 bar: Difference = %.3f, 95%% CI = [%.3f, %.3f]\n', estimate, ci_low, ci_high);





% %% -- plot scatter-plot -----
% figure()
% 
% 
% scatter(Y_scatter_P1 + 0.2*(-1 + 2*rand(size(Y_scatter_P1))), X_scatter_P1, ...
%     25, "MarkerEdgeColor", 'k', 'MarkerFaceColor', customColors(1, :), ...
%     'MarkerFaceAlpha', 1, 'LineWidth', 0.5)
% hold on
% scatter(Y_scatter_P3 + 0.2*(-1 + 2*rand(size(Y_scatter_P3))), X_scatter_P3, ...
%     25, "MarkerEdgeColor", 'k', 'MarkerFaceColor', customColors(2, :), ...
%     'MarkerFaceAlpha', 1, 'LineWidth', 0.5)
% scatter(Y_scatter_P6 + 0.2*(-1 + 2*rand(size(Y_scatter_P6))), X_scatter_P6, ...
%     25, "MarkerEdgeColor", 'k', 'MarkerFaceColor', customColors(3, :), ...
%     'MarkerFaceAlpha', 1, 'LineWidth', 0.5)
% xlim([0 11])
% ylim([0 20])



%% -- plot box-plot -----
% Example input variables:
% score: vector of subjective scores (integers 1-10)
% error: vector of tracking error values
% pressure: vector of pressure condition values (e.g., 1, 3, 6 for bar)

scores_unique = 1:10;
pressures_unique = [1 3 6];
fig = figure; hold on;
set(fig, 'InvertHardcopy', 'off', 'PaperType', 'a2', ...
    'PaperOrientation', 'landscape'); 
fig_width = 6; %previously 10 for 7 cond, adjusting to so figure isnt' stretched for 1 condition
fig_height = fig_width/2;
set(gcf, 'PaperUnits', 'inches', 'Units', 'Inches', ...
    'PaperPositionMode', 'auto', ...
    'Position', [17 4 fig_height*2.75 fig_width*1.85], 'Units', 'Inches');

% tiledlayout(1, 5, "TileSpacing", "loose", 'Padding', 'loose')

width = 0.25; % box width
spread = 0.3; % horizontal spread between boxes (tune as needed)


% ax2 = nexttile(3, [1, 3]); hold on
ax2 = subplot(4, 2, [3, 8]); hold on

for i = 1:numel(scores_unique)
    this_score = scores_unique(i);
    % Identify which pressures exist for this score
    score_pressures = pressures_unique(arrayfun(@(p) any((score_all==this_score) & (pressure==p)), pressures_unique));
    n_present = numel(score_pressures);

    % Centered offsets for boxcharts
    if n_present == 1
        offsets = 0;
    elseif n_present == 2
        offsets = [-spread/2 spread/2];
    elseif n_present == 3
        offsets = [-spread, 0, spread];
    end

    for j = 1:n_present
        this_pressure = score_pressures(j);

        idx = (score_all == this_score) & (pressure == this_pressure);
        pos = this_score + offsets(j);

        % Overlay jittered scatter for population density
        rng(0); % reproducibility
        xj = pos + (rand(sum(idx),1)-0.5)*0.11;
        scatter(error_all(idx), xj, 8, ...
            1.1*customColors(pressures_unique == this_pressure,:), ...
            'filled', 'MarkerFaceAlpha',0.8, 'MarkerEdgeAlpha',0.55, ...
            'MarkerEdgeColor', ...
            customColors(pressures_unique == this_pressure,:) ,...
            'HandleVisibility', 'off');

        % Draw the boxchart
        bc = boxchart(ones(sum(idx),1)*pos, error_all(idx), ...
            'BoxWidth', width, ...
            'BoxFaceColor', customColors(pressures_unique==this_pressure,:), ...
            'MarkerStyle', 'none', 'Orientation', 'horizontal');   % No scatter overlay

        % Optional: set Med line color
        bc.LineWidth = 2;
        bc.BoxFaceAlpha = 0.6;
        bc.BoxEdgeColor = 0.7*customColors(pressures_unique==this_pressure,:);
        bc.WhiskerLineColor = bc.BoxEdgeColor;
        % bc.BoxMedianLineColor = 'k';
        

        % % Annotate n on top of box
        % text(pos, min(error_all(idx))-1, sprintf('n = %d',sum(idx)), ...
        %     'HorizontalAlignment','center', 'FontSize',8, ...
        %     'Color',customColors(pressures_unique == this_pressure,:), ...
        %     'Rotation', 90);
   
        
        
    end
end

set(gca,'FontSize',14);
% ax2.Position(3) = 0.8*ax2.Position(3);

% Formatting
yticks(scores_unique);
yticklabels(string(scores_unique));
ylh2 = ylabel('Subjective Score');
ylh2.FontName = 'Arial';
ylh2.FontSize = 16;
ylh2.FontWeight = 'bold';

xlh2 = xlabel(sprintf('Tracking Error (RMS)'));
xlh2.FontName = 'Arial';
xlh2.FontSize = 16;
xlh2.FontWeight = 'bold';


ylim([0.5 10.5])
xlim([0 17])



% %% Panel A
% score_mean = [mean(score_all(pressure == 1)), ...
%     mean(score_all(pressure == 3)), ...
%     mean(score_all(pressure == 6))];
% score_std = [std(score_all(pressure == 1), 0), ...
%     std(score_all(pressure == 3), 0), ...
%     std(score_all(pressure == 6), 0)];
% error_mean = [mean(error_all(pressure == 1)), ...
%     mean(error_all(pressure == 3)), ...
%     mean(error_all(pressure == 6))];
% error_std = [std(error_all(pressure == 1), 0), ...
%     std(error_all(pressure == 3), 0), ...
%     std(error_all(pressure == 6), 0)];
% 
% 
% nexttile(1); hold on
% % idx = pressure == 1;
% % bc1 = boxchart(ones(sum(idx),1)*1, score_all(idx), ...
% %             'BoxWidth', width*2, 'BoxEdgeColor', 'k',...
% %             'BoxFaceColor', customColors(1,:), ...
% %             'MarkerStyle', 'none');   % No scatter overlay
% % bc1.BoxFaceAlpha = 0.6;
% % bc1.LineWidth = 1.3;
% % scatter(1, score_mean(1), 80, customColors(1,:), ...
% %         'filled', 'LineWidth', 1, 'MarkerEdgeColor', 'k');
% idx1 = pressure == 1; idx3 = pressure == 3; idx6 = pressure == 6;
% b1 = bar(1:3, [mean(score_all(idx1)), ...
%     mean(score_all(idx3)), mean(score_all(idx6))], 'grouped');
% % idx = pressure == 3;
% % bc3 = boxchart(ones(sum(idx),1)*2, score_all(idx), ...
% %             'BoxWidth', width*2, 'BoxEdgeColor', 'k',...
% %             'BoxFaceColor', customColors(2,:), ...
% %             'MarkerStyle', 'none');   % No scatter overlay
% % bc3.BoxFaceAlpha = 0.6;
% % bc3.LineWidth = 1.3;
% % scatter(2, score_mean(2), 80, customColors(2,:), ...
% %         'filled', 'LineWidth', 1, 'MarkerEdgeColor', 'k');
% % idx = pressure == 6;
% % bc6 = boxchart(ones(sum(idx),1)*3, score_all(idx), ...
% %             'BoxWidth', width*2, 'BoxEdgeColor', 'k',...
% %             'BoxFaceColor', customColors(3,:), ...
% %             'MarkerStyle', 'none');   % No scatter overlay
% % bc6.BoxFaceAlpha = 0.6;
% % bc6.LineWidth = 1.3;
% % scatter(3, score_mean(3), 80, customColors(3,:), ...
% %         'filled', 'LineWidth', 1, 'MarkerEdgeColor', 'k');
% 
% xticks(1:3); xticklabels({'Low','Medium','High'});
% ylh = ylabel(sprintf('Mean\nSubjective Score'));
% ylh.FontWeight = "bold";
% ylh.FontName = 'Arial';
% ylh.FontSize = 16;
% set(gca,'FontSize',14);
% xlim([0 4])
% 
% 
% 
% nexttile(5); hold on;
% idx = pressure == 1;
% bc1 = boxchart(ones(sum(idx),1)*1, error_all(idx), ...
%             'BoxWidth', width*2, 'BoxEdgeColor', 'k',...
%             'BoxFaceColor', customColors(1,:), ...
%             'MarkerStyle', 'none');   % No scatter overlay
% bc1.BoxFaceAlpha = 0.6;
% bc1.LineWidth = 1.3;
% scatter(1, error_mean(1), 80, customColors(1,:), ...
%         'filled', 'LineWidth', 1, 'MarkerEdgeColor', 'k');
% idx = pressure == 3;
% bc3 = boxchart(ones(sum(idx),1)*2, error_all(idx), ...
%             'BoxWidth', width*2, 'BoxEdgeColor', 'k',...
%             'BoxFaceColor', customColors(2,:), ...
%             'MarkerStyle', 'none');   % No scatter overlay
% bc3.BoxFaceAlpha = 0.6;
% bc3.LineWidth = 1.3;
% scatter(2, error_mean(2), 80, customColors(2,:), ...
%         'filled', 'LineWidth', 1, 'MarkerEdgeColor', 'k');
% idx = pressure == 6;
% bc6 = boxchart(ones(sum(idx),1)*3, error_all(idx), ...
%             'BoxWidth', width*2, 'BoxEdgeColor', 'k',...
%             'BoxFaceColor', customColors(3,:), ...
%             'MarkerStyle', 'none');   % No scatter overlay
% bc6.BoxFaceAlpha = 0.6;
% bc6.LineWidth = 1.3;
% scatter(3, error_mean(3), 80, customColors(3,:), ...
%         'filled', 'LineWidth', 1, 'MarkerEdgeColor', 'k');
% 
% 
% xticks(1:3); xticklabels({'Low','Medium','High'});
% ylh = ylabel(sprintf('Mean\nTracking Error (RMS)'));
% ylh.FontWeight = "bold";
% ylh.FontName = 'Arial';
% ylh.FontSize = 16;
% xlh = xlabel('Pressure Condition');
% xlh.FontWeight = "bold";
% xlh.FontName = 'Arial';
% xlh.FontSize = 16;
% 
% set(gca,'FontSize',14);
% xlim([0 4])
% ylim([0 17])



%% Panel A

% Example data vectors
% score: N×1 continuous variable
% pressure: N×1 categorical or double (1, 3, 6)
% subject: N×1 subject indices
% Make sure pressure is categorical for grouping
pressure = categorical(pressure, [1 3 6], {'Low', 'Medium', 'High'});
pressure_levels = categories(pressure);
n_cond = numel(pressure_levels);
colors = customColors;

%%
% nexttile(1); hold on; % cla; 
ax11 = subplot(4, 2, 1); hold on; 

% Jitter setup for spread
spread = 0.15;
rng(1); % Sets the random seed to 1
% x positions (jittered for clarity)
loc = 1:3;
x_jitter = loc + (rand(14,numel(loc))-0.5)*spread;

subjects_unique = unique(subject_all);
subj_scores = [];
for s = 1:numel(subjects_unique)
    s_idx = subject_all == subjects_unique(s);
    subj_pressures = pressure(s_idx);
    subj_scores_all = score_all(s_idx);
    subj_scores = [subj_scores; ...
        [mean(subj_scores_all(strcmp(cellstr(subj_pressures), 'Low'))), ...
         mean(subj_scores_all(strcmp(cellstr(subj_pressures), 'Medium'))), ...
         mean(subj_scores_all(strcmp(cellstr(subj_pressures), 'High')))] ];
end




for s = 1:numel(subjects_unique)
    x = x_jitter(s, :);
    subj_scores_s = subj_scores(s, :);
    % 3. Paired line for within-subject
    plot(x, subj_scores_s, '-', 'Color', [0.8 0.8 0.8 0.8], 'LineWidth', 0.5);
end


% 1. Box plot layer
for i = 1:n_cond
    
    data = subj_scores(:, i);

    % boxplot(data, ...
    %     'Whisker', 2.5, ...
    %     'Positions', (i)-spread, ...
    %     'BoxStyle', 'outline', ...
    %     'Colors', colors(i, :), ...
    %     '') % Changes the outlier rule to 2.5×IQR

    % Boxplot: use boxchart (R2019b+), else use boxplot
    boxchart(ones(length(data),1)*(i)-spread, data, ...
        'BoxFaceColor', colors(i,:), ...
        'BoxFaceAlpha', 0.6, ...
        'BoxWidth', 0.18, ...
        'MarkerStyle', 'none', 'LineWidth', 2, ...
        'BoxEdgeColor', colors(i,:)*0.7, ...
        'WhiskerLineColor', colors(i,:)*0.7);
end


% 2. Individual data points (jittered scatter)
for s = 1:numel(subjects_unique)
    subj_scores_s = subj_scores(s, :);

    x = x_jitter(s, :);

    % scatter each subject's points
    for j = 1:numel(loc)
        scatter(x(j), subj_scores_s(j), 60, 'MarkerFaceColor', colors(j,:), ...
            'MarkerEdgeColor', colors(j,:), ...
            'MarkerFaceAlpha', 0.4, ...
            'MarkerEdgeAlpha', 0.4, ...
            'LineWidth',0.7);
    end

    % % 3. Paired line for within-subject
    % plot(x_jitter, subj_scores_s, '-', 'Color', [0.8 0.8 0.8 0.8], 'LineWidth', 0.8);
end



% 4. Overlay group means (LMM, or just mean if you prefer)
mu = mean(subj_scores, 1);
x = [1, 2, 3] - repmat(spread, 1, 3);
plot(x, mu, 'LineWidth', 2, 'Color', [0.3 0.3 0.3])



% 5. Add significance bars for group pairs (you must set these based on your analysis)
% Example: ns between 1 vs 3, 1 vs 6, 3 vs 6, at heights y_annot
y_annot = [9 10 11]; % manually tune heights for clarity
x_pair = [1 2; 1 3; 2 3];
sig_label = {'*','*','*'};      % Replace with your actual sig stars

for j = 1:size(x_pair,1)
    plot([x_pair(j,1) x_pair(j,2)], ...
        [y_annot(j) y_annot(j)], 'k-', 'LineWidth',1.3);
    text(mean(x_pair(j,:)), y_annot(j)-0.4, sig_label{j}, ...
        'HorizontalAlignment','center', ...
        'FontSize', 18, 'FontWeight','normal');
end



set(gca, 'XTick', 1:n_cond, 'XTickLabel', pressure_levels);
set(gca,'FontSize', 14); box off;
xlh11 = xlabel('Pressure', 'FontName', 'Arial', 'FontSize', 16, ...
    'FontWeight', 'bold'); 


ylh11 = ylabel('Subjective Score', 'FontName', 'Arial', 'FontSize', 16, ...
    'FontWeight', 'bold'); 

ylim([0 11.5]);
xlim([0.5 3.5])
% grid on;
set(gca, 'YTick', 1:10)
hold off;







%% Error at Group level
% nexttile(2); hold on; % cla; 
ax12 = subplot(4, 2, 2); hold on; 

% Jitter setup for spread
spread = 0.15;
rng(1); % Sets the random seed to 1
% x positions (jittered for clarity)
loc = 1:3;
x_jitter = loc + (rand(14,numel(loc))-0.5)*spread;

subjects_unique = unique(subject_all);
subj_errors = [];
for s = 1:numel(subjects_unique)
    s_idx = subject_all == subjects_unique(s);
    subj_pressures = pressure(s_idx);
    subj_errors_all = error_all(s_idx);
    subj_errors = [subj_errors; ...
        [mean(subj_errors_all(strcmp(cellstr(subj_pressures), 'Low'))), ...
         mean(subj_errors_all(strcmp(cellstr(subj_pressures), 'Medium'))), ...
         mean(subj_errors_all(strcmp(cellstr(subj_pressures), 'High')))] ];
end




for s = 1:numel(subjects_unique)
    x = x_jitter(s, :);
    subj_errors_s = subj_errors(s, :);
    % 3. Paired line for within-subject
    plot(x, subj_errors_s, '-', 'Color', [0.7 0.7 0.7 0.7], 'LineWidth', 0.5);
end


% 1. Box plot layer
for i = 1:n_cond
    
    data = subj_errors(:, i);

    % boxplot(data, ...
    %     'Whisker', 2.5, ...
    %     'Positions', (i)-spread, ...
    %     'BoxStyle', 'outline', ...
    %     'Colors', colors(i, :), ...
    %     '') % Changes the outlier rule to 2.5×IQR

    % Boxplot: use boxchart (R2019b+), else use boxplot
    boxchart(ones(length(data),1)*(i)-spread, data, ...
        'BoxFaceColor', colors(i,:), ...
        'BoxFaceAlpha', 0.6, ...
        'BoxWidth', 0.18, ...
        'MarkerStyle', 'none', 'LineWidth', 2, ...
        'BoxEdgeColor', colors(i,:)*0.7, ...
        'WhiskerLineColor', colors(i,:)*0.7);
end


% 2. Individual data points (jittered scatter)
for s = 1:numel(subjects_unique)
    subj_errors_s = subj_errors(s, :);

    x = x_jitter(s, :);

    % scatter each subject's points
    for j = 1:numel(loc)
        scatter(x(j), subj_errors_s(j), 60, 'MarkerFaceColor', colors(j,:), ...
            'MarkerEdgeColor', colors(j,:), ...
            'MarkerFaceAlpha', 0.4, ...
            'MarkerEdgeAlpha', 0.4, ...
            'LineWidth',0.7);
    end

    % % 3. Paired line for within-subject
    % plot(x_jitter, subj_scores_s, '-', 'Color', [0.8 0.8 0.8 0.8], 'LineWidth', 0.8);
end



% 4. Overlay group means (LMM, or just mean if you prefer)
mu = mean(subj_errors, 1);
x = [1, 2, 3] - repmat(spread, 1, 3);
plot(x, mu, 'LineWidth', 2, 'Color', [0.3 0.3 0.3])



% 5. Add significance bars for group pairs (you must set these based on your analysis)
% Example: ns between 1 vs 3, 1 vs 6, 3 vs 6, at heights y_annot
y_annot = [11 12 13]; % manually tune heights for clarity
x_pair = [1 2; 1 3; 2 3];
sig_label = {'*','*','ns'};      % Replace with your actual sig stars
text_size = [18, 18, 14];

for j = 1:size(x_pair,1)
    plot([x_pair(j,1) x_pair(j,2)], ...
        [y_annot(j) y_annot(j)], 'k-', 'LineWidth',1.3);
    text(mean(x_pair(j,:)), y_annot(j)-0.4, sig_label{j}, ...
        'HorizontalAlignment','center', ...
        'FontSize', text_size(j), 'FontWeight','normal');
end



set(gca, 'XTick', 1:n_cond, 'XTickLabel', pressure_levels);
set(gca,'FontSize', 14); box off
xlh12 = xlabel('Pressure', 'FontName', 'Arial', 'FontSize', 16, ...
    'FontWeight', 'bold', 'VerticalAlignment', 'top'); 
ylh12 = ylabel('Tracking Error (RMS)', 'FontName', 'Arial', 'FontSize', 16, ...
    'FontWeight', 'bold'); % Or 'Tracking error (RMS)'
ylim([2 13.5]);
xlim([0.5 3.5])
grid off;

hold off;



%%
% ax2.Position(1) = ax2.Position(1) + 0.03;
ax2.Position(2) = ax2.Position(2) - 0.03;
% ax2.Position(3) = ax2.Position(3) * 1.1;
ax2.Position(4) = ax2.Position(4) * 0.9;
ax2.FontSize = 18;

xlh2.Units = "inches";
pos = xlh2.Position;
xlh2.Position = [pos(1), xlh2.Position(2) - 0.1, pos(3)];
ylh2.Units = 'inches';
pos = ylh2.Position;
ylh2.Position = [ylh2.Position(1) - 0.1, pos(2), pos(3)];



% ax11.Position(1) = ax11.Position(1) - 0.08;
ax11.Position(2) = ax11.Position(2) - 0.08;
% ax11.Position(3) = ax11.Position(3) * 1.2;
ax11.Position(4) = ax11.Position(4) * 1.8;
ax11.FontSize = 18;

xlh11.Units = 'inches';
xlh11.Position(2) = xlh11.Position(2) - 0.1;
ylh11.Units = 'inches';
pos = ylh11.Position;
ylh11.Position = [ylh11.Position(1)-0.1, pos(2), pos(3)];


% ax12.Position(1) = ax12.Position(1) - 0.03;
ax12.Position(2) = ax12.Position(2) - 0.08;
% ax12.Position(3) = ax12.Position(3) * 1.2;
ax12.Position(4) = ax12.Position(4) * 1.8;
ax12.FontSize = 18;

xlh12.Units = 'inches';
xlh12.Position(2) = xlh12.Position(2) - 0.1;
ylh12.Units = 'inches';
pos = ylh12.Position;
ylh12.Position = [ylh12.Position(1)-0.1, pos(2), pos(3)];


%% correlation analysis 

[rho, pval] = corr(error_all, score_all, 'Type', 'Spearman');


%% Add legend and the annotation for Spearman Corr. Analysis

labels = {' Low Pressure', ...
    '', ' Medium Pressure', ...
    '', '', ...
    '', '', ' High Pressure', ...
    '', '', ...
    '', '', ...
    '', '', ...
    '', '', ''};

% Create example dummy lines for legend (outside data range)
axes(ax2); 
xticks = ax2.XTick;
xlim([0 19])
hold on;

lgd = legend(ax2, labels, 'Location', 'southeast', ...
    'FontSize', 14, 'Box','off', 'Direction', 'reverse');

% Get normalized position of the legend
lgdPos = lgd.Position; % [left bottom width height], normalized to figure




ax = lgd.Parent; % axes handle 
figl = ancestor(ax2, 'figure');

% Figure position in pixels
figPosPixel = figl.Position; 

% Axes position within figure (normalized)
axPosNorm = ax2.Position;

% Axes limits
xLimits = ax2.XLim;
yLimits = ax2.YLim;

% Convert normalized legend figure pos to pixels
posPixel = lgdPos .* [figPosPixel(3), figPosPixel(4), figPosPixel(3), figPosPixel(4)];

% Convert pixels to normalized axes units (relative to axes position)
posNormAxes = [(posPixel(1) - axPosNorm(1)*figPosPixel(3))/ (axPosNorm(3)*figPosPixel(3)), ...
               (posPixel(2) - axPosNorm(2)*figPosPixel(4))/ (axPosNorm(4)*figPosPixel(4)), ...
               posPixel(3) / (axPosNorm(3)*figPosPixel(3)), ...
               posPixel(4) / (axPosNorm(4)*figPosPixel(4))];

% Convert axes normalized units to data units
x0 = xLimits(1) + posNormAxes(1) * (xLimits(2) - xLimits(1));
y0 = yLimits(1) + posNormAxes(2) * (yLimits(2) - yLimits(1));
width = posNormAxes(3) * (xLimits(2) - xLimits(1));
height = posNormAxes(4) * (yLimits(2) - yLimits(1));

fill([x0, x0 + width, x0 + width, x0], [y0, y0, y0 + height, y0 + height], ...
    'w', 'EdgeColor', 'none');

delete(lgd)

lgd = legend(ax2, labels, 'Location', 'southeast', ...
    'FontSize', 14, 'Box','off', 'Direction', 'reverse');



% Format the correlation string
corrStr = sprintf('Spearman Correlation:\n\\rho = %.2f, p < 0.001', rho);

% Position for the text: place above the rectangle currently drawn
textX = x0 + 0.1;          % center horizontally on the rectangle
textY = y0 + height + 0.04*(yLimits(2) - yLimits(1)); % slightly above rectangle

hTxt = text(textX, textY, corrStr, 'HorizontalAlignment', 'left', ...
    'FontSize', 14, 'FontWeight', 'normal', 'BackgroundColor', 'w', 'EdgeColor', 'none');

ax2.XTick = xticks;