clc
clear


%% Add paths 
addpath(genpath('D:\Morteza\MyProjects\ANSYMB2024\Code'))


%% Load the data
load EMG_Data_timewarped.mat

data = EMG_Data_timewarped.data;
warpingto = EMG_Data_timewarped.final_warpingto;
muscles_name = EMG_Data_timewarped.Muscle_Name;
muscles_name = cellfun(@(x) strrep(x, '_', ' '), muscles_name, ...
    'UniformOutput', false);

clear EMG_Data_timewarped

%% Normalize iEMG data per subject

subject_list = 5:18;
inner_struct = struct('pressure', [], 'score', [], ...
    'iEMG_norm', [], 'iEMG_nonNorm', [], ...
    'EMG_norm', [], 'EMG_nonNorm', []);
EMG_subjects = repmat({inner_struct}, length(subject_list), 1);;

for sub = 1:length(subject_list)
    
    if strcmp(data{sub, 1}, 'Sub 10'), continue; end

    disp(['EMG normalization, Subject ', num2str(subject_list(sub))])
    
    pressure = cellfun(@(x) x(1), data{sub, 2}.pressure, ...
        'UniformOutput', false);
    pressure = cell2mat(pressure);

    score = cellfun(@(x) x(1), data{sub, 2}.score, ...
        'UniformOutput', false);
    score = cell2mat(score);

    % mark outliers and remove them
    iEMG = cellfun(@(x) mean(x, 1), data{sub, 2}.iEMG, ...
        'UniformOutput', false);
    iEMG = cell2mat(iEMG);

    EMG = cellfun(@(x) mean(cat(3, x{:}), 3), data{sub, 2}.EMG, ...
        'UniformOutput', false);
    EMG = cat(3, EMG{:});

    [iEMG_p1_indx ~] = find(pressure == 1);
    iEMG_p1 = iEMG(iEMG_p1_indx, :);
    iEMG_outlier_p1 = isoutlier(iEMG_p1, "median", 1, "ThresholdFactor", 3);
    indx_to_remove_p1 = find(any(iEMG_outlier_p1, 2));
    if ~isempty(indx_to_remove_p1)
        trials_to_remove_p1 = iEMG_p1_indx(indx_to_remove_p1);
    else
        trials_to_remove_p1 = [];
    end
    if max(max(iEMG_p1)) > 10
        disp(['subject ', num2str(sub)])
    end

    [iEMG_p3_indx ~] = find(pressure == 3);
    iEMG_p3 = iEMG(iEMG_p3_indx, :);
    iEMG_outlier_p3 = isoutlier(iEMG_p3, "median", 1, "ThresholdFactor", 3);
    indx_to_remove_p3 = find(any(iEMG_outlier_p3, 2));
    if ~isempty(indx_to_remove_p3)
        trials_to_remove_p3 = iEMG_p3_indx(indx_to_remove_p3);
    else
        trials_to_remove_p3 = [];
    end
    if max(max(iEMG_p3)) > 10
        disp(['subject ', num2str(sub)])
    end

    [iEMG_p6_indx ~] = find(pressure == 6);
    iEMG_p6 = iEMG(iEMG_p6_indx, :);
    iEMG_outlier_p6 = isoutlier(iEMG_p6, "median", 1, "ThresholdFactor", 3);
    indx_to_remove_p6 = find(any(iEMG_outlier_p6, 2));
    if ~isempty(indx_to_remove_p6)
        trials_to_remove_p6 = iEMG_p6_indx(indx_to_remove_p6);
    else
        trials_to_remove_p6 = [];
    end
    if max(max(iEMG_p6)) > 10
        disp(['subject ', num2str(sub)])
    end

    trials_to_remove = [trials_to_remove_p1; ...
                        trials_to_remove_p3; ...
                        trials_to_remove_p6];


    iEMG(trials_to_remove, :) = [];
    pressure(trials_to_remove) = [];
    score(trials_to_remove) = [];
    EMG(:, :, trials_to_remove) = [];

    EMG_subjects{sub}.pressure = pressure;
    EMG_subjects{sub}.score = score;


    % normalize the iEMG values to the whole trials mean (all conditions)
    iEMG_mean = mean(iEMG, 1);
    iEMG_norm = iEMG./repmat(iEMG_mean, size(iEMG, 1), 1);
    if max(max(iEMG_norm)) > 10
        disp(['subject ', num2str(sub)])
    end


    EMG_mean = mean( mean(EMG, 3), 2 );
    EMG_norm = EMG./repmat(EMG_mean, 1, size(EMG, 2), size(EMG, 3));

    EMG_subjects{sub}.iEMG_norm = iEMG_norm;
    EMG_subjects{sub}.iEMG_nonNorm = iEMG;
    EMG_subjects{sub}.EMG_norm = EMG_norm;
    EMG_subjects{sub}.EMG_nonNorm = EMG;

end


%% Store all scores and pressures and EMGs (norm, nonNorm) from all subjects
score_all = [];
pressure_all = [];
subject_all = [];
iEMG_norm_all = [];
EMG_norm_all = [];

for sub = 1:length(subject_list)
    if strcmp(data{sub, 1}, 'Sub 10'), continue; end

    score_all = cat(1, score_all, EMG_subjects{sub}.score);
    pressure_all = cat(1, pressure_all, EMG_subjects{sub}.pressure);
    iEMG_norm_all = cat(1, iEMG_norm_all, EMG_subjects{sub}.iEMG_norm);
    EMG_norm_all = cat(3, EMG_norm_all, EMG_subjects{sub}.EMG_norm);
    subject_all = cat(1, subject_all, ...
        repmat(subject_list(sub), length(EMG_subjects{sub}.score), 1));

end

% remove score 0 lines
idx = score_all == 0;
score_all(idx) = [];
pressure_all(idx) = [];
iEMG_norm_all(idx, :) = [];
EMG_norm_all(:, :, idx) = [];
subject_all(idx) = [];


% total_trials_count_perSub = zeros(1, length(subject_list));
% for sub = 1:length(subject_list)
%     total_trials_count_perSub(sub) = ...
%         sum(subject_all == subject_list(sub));
% end
% threshold_perSub = round(0.04*total_trials_count_perSub);


% create a table showing the number of trials from each subject at each
% score-pressure condition
unique_scores = 1:10;
unique_pressures = [1, 3, 6];
trials_count_table = cell(3, 10);
trials_count_all = zeros(1, 10);
trials_count_pressure_score = zeros(3, 10);
for i = 1:10
    for j = 1:3
        idx = (score_all == unique_scores(i) & ...
            pressure_all == unique_pressures(j));
        unique_subjects = unique(subject_all(idx));

        for s = 1:length(subject_list)
            if ~ismember(subject_list(s), unique_subjects)
                continue
            end
            idx2 = (idx & subject_all == subject_list(s));
            % if sum(idx2) > threshold_perSub(s)
                trials_count_table{j, i} = cat(1, trials_count_table{j, i}, ...
                    [subject_list(s) sum(idx2)]);
                trials_count_all(i) = trials_count_all(i) + sum(idx2);
                trials_count_pressure_score(j, i) = ...
                    trials_count_pressure_score(j, i) + sum(idx2);
            % end
            
        end
    end
end



thresholds_per_score = round(sum(trials_count_all)/30*0.4);
pressure_score_to_keep = trials_count_pressure_score > ...
    repmat(thresholds_per_score, 3, 10);

trials_count_table_new = trials_count_table;
trials_count_table_new(~pressure_score_to_keep) = {[]};

% reconstruct the X_all vectors
score_all_new = [];
pressure_all_new = [];
iEMG_all_new = [];
EMG_all_new = [];
subject_all_new = [];
for i = 1:10
    for j = 1:3
        if isempty(trials_count_table_new{j, i}), continue; end;
        subjects = trials_count_table_new{j, i}(:, 1);
        for s = 1:length(subjects)
            idx = (score_all == i & ...
                   pressure_all == unique_pressures(j) & ...
                   subject_all == subjects(s));
            score_all_new = cat(1, score_all_new, score_all(idx));
            pressure_all_new = cat(1, pressure_all_new, pressure_all(idx));
            iEMG_all_new = cat(1, iEMG_all_new, iEMG_norm_all(idx, :));
            EMG_all_new = cat(3, EMG_all_new, EMG_norm_all(:, :, idx));
            subject_all_new = cat(1, subject_all_new, ...
                repmat(subjects(s), sum(idx), 1));
        end
    end
end




%% Prepare per-subject data for plotting
inner_struct = struct('EMG', [], 'iEMG', []);
EMG_perSubject = repmat({inner_struct}, length(subject_list), 1);
pressure_conditions = [1, 3, 6];
for sub = 1:length(subject_list)
    if strcmp(data{sub, 1}, 'Sub 10'), continue; end
    for p = 1:3
        idx = (subject_all_new == subject_list(sub) & ...
            pressure_all_new == pressure_conditions(p));
        EMG_perSubject{sub}.EMG = cat(3, EMG_perSubject{sub}.EMG, ...
            mean(EMG_all_new(:, :, idx), 3));
        EMG_perSubject{sub}.iEMG = cat(1, EMG_perSubject{sub}.iEMG, ...
            mean(iEMG_all_new(idx, :), 1));
    end
end 
EMG_perSubject(6) = [];


%% -------------------------------------------
%               MAIN PLOT
%  -------------------------------------------

monitors = get(0, 'MonitorPositions');
fig = figure('name', ['EMG Data Representation'], ...
    'InvertHardcopy', 'off', 'PaperType', 'a2', ...
    'PaperOrientation', 'landscape', ...
    'Resize', 'off');

% For second monitor (row 2), add drawnow before setting position
drawnow;  % Let MATLAB finish drawing on primary monitor first
pause(0.1);  % Short pause helps

set(fig, 'Position', [monitors(1,1)+100, monitors(1,2)+365, 1600, 1100]);

ax = gobjects(12, 1);  % Preallocate axes array

P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
colors = [P1_color; P3_color; P6_color];


scores_unique = 1:10;
pressures_unique = [1 3 6];



% plot the muscles EMG_norm per pressure per score

for muscle = 1:4
    
    % ---------------------------------------------------------------------
    % EMG_norm - Cycle(%)
    ax(muscle) = subplot(5, 4, muscle); hold on;
    
    signals = cellfun(@(x) squeeze(x.EMG(muscle, :, :))', EMG_perSubject, ...
        'UniformOutput', false);
    signals = cat(3, signals{:});

    cycle = 1:size(signals, 2);

    signals_mean = mean(signals, 3);
    signals_std  = std(signals, 0, 3);
    signals_sem  = signals_std/sqrt(size(signals, 3));

    for p = 1:3
        fill([cycle, fliplr(cycle)], ...
            [signals_mean(p, :) + signals_sem(p, :), ...
            fliplr(signals_mean(p, :) - signals_sem(p, :))], ...
            colors(p, :), 'EdgeColor', 'none', ...
            'FaceColor', colors(p, :), 'FaceAlpha', 0.4, ...
            'HandleVisibility', 'off');
        plot(cycle, signals_mean(p, :), 'Color', 0.7*colors(p, :), ...
            'LineWidth', 2);
    end
    set(ax(muscle), 'XTick', warpingto + [1, 0, 0], ...
        'XTickLabel', {'0', '50', '100'}, 'XTickLabelRotation', 0);
    set(ax(muscle), 'FontSize', 14, 'Box', 'on')
    xlh = xlabel('Cycle (%)', 'FontName', 'Arial', ...
        'FontWeight', 'bold', 'FontSize', 16);
    


    % ---------------------------------------------------------------------
    % iEMG_norm (each subject as a scatter dot)
    ax(4 + muscle) = subplot(5, 4, 4+muscle); hold on;
    plot_jittered_scatter(subject_list, EMG_perSubject, muscle, colors);


    % ---------------------------------------------------------------------
    % iEMG norm (all trials data) per score and pressure condition
    ax(8 + muscle) = subplot(5, 4, [8+muscle, 16+muscle]); hold on;
    
    width = 0.2; % box width
    spread = 0.3; % horizontal spread between boxes (tune as needed)

    % for reproducible jitter (set once)
    rng(0);
    
    for i = 1:numel(scores_unique)
        this_score = scores_unique(i);
        % Identify which pressures exist for this score
        score_pressures = pressures_unique(arrayfun(@(p) ...
            any((score_all_new == this_score) & ...
                (pressure_all_new == p)), pressures_unique));
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
    
            idx = (score_all_new == this_score) & ...
                (pressure_all_new == this_pressure);
            pos  = this_score + offsets(j);   % y-position (score axis)
            vals = iEMG_all_new(idx, muscle);      % the data for this violin
    
    
            % ---------------------
            % JITTERED SCATTER PLOT
            % ---------------------
            xj = pos + (rand(sum(idx),1)-0.5)*0.11;  % jitter around pos (y-axis)
            scatter(vals, xj, 8, ...
                1.1*colors(pressures_unique == this_pressure,:), ...
                'filled', ...
                'MarkerFaceAlpha', 0.8, ...
                'MarkerEdgeAlpha', 0.55, ...
                'MarkerEdgeColor', colors(pressures_unique == this_pressure,:), ...
                'HandleVisibility', 'off');
    
            hold on
    
            % -------------------------------
            % BOXPLOT ON TOP (same as before)
            % -------------------------------
    
            bc = boxchart(ones(sum(idx),1)*pos, vals, ...
                'BoxWidth',      width, ...
                'BoxFaceColor',  colors(pressures_unique == this_pressure,:), ...
                'MarkerStyle',   'none', ...
                'Orientation',   'horizontal');   % horizontal boxes
            bc.CapWidth = 0.01;
            bc.LineWidth        = 2;
            bc.BoxFaceAlpha     = 0.6;
            bc.BoxEdgeColor     = 0.7*colors(pressures_unique==this_pressure,:);
            bc.WhiskerLineColor = bc.BoxEdgeColor;
    
        end
        
    end
    set(ax(8 + muscle), 'FontSize', 14, 'YTick', scores_unique, ...
        'YTickLabel', string(scores_unique));
    
    ylim([0.5 10.5])

end



%% Performing the statistical analysis on row 2 (Norm. iEMG in pressures)
% prepare iEMG matrix for statistical analysis
subject_list_new = subject_list;
subject_list_new(6) = [];
stat_data = [];
for sub = 1:length(subject_list_new)
    stat_data = cat(3, stat_data, EMG_perSubject{sub}.iEMG');
end

% sending the data to the stat_analysis function
adj_p_values_iEMG = stat_analysis(stat_data);


sig_labels = {'ns', '*', '**', '***'};
j_indx = [1, 2;  1, 3; 2, 3]; % compairing groups


annot_dis_ext = 0.2;
annot_dis_flx = 0.4;

for muscle = 1:4

    if ismember(muscle, [1, 2])
        y_annot = [max(max(stat_data(muscle, :, :)))*[1 1 1] + ...
                   annot_dis_ext*[0 1 2]];
    else
        y_annot = [max(max(stat_data(muscle, :, :)))*[1 1 1] + ...
                   annot_dis_flx*[0 1 2]];
    end
    for j = 1:3
        
        axes(ax(4 + muscle));
        

        % Add significance lines for group pairs 
        pvalue = adj_p_values_iEMG(muscle, j);
        if pvalue > 0.05
            plot([j_indx(j, 1) j_indx(j, 2)], ...
            [y_annot(j) y_annot(j)] + 0.1, 'k-', 'LineWidth', 1.3);
            sig_label = 'ns'; 
            text(mean(j_indx(j,:)), y_annot(j) + 0.2, sig_label, ...
                'HorizontalAlignment','center', ...
                'FontSize', 12, 'FontWeight','normal');
        end

        if pvalue > 0.01 & pvalue < 0.05
            plot([j_indx(j, 1) j_indx(j, 2)], ...
            [y_annot(j) y_annot(j)], 'k-', 'LineWidth', 1.3);
            sig_label = '*';  
            text(mean(j_indx(j,:)), y_annot(j), sig_label, ...
                'HorizontalAlignment','center', ...
                'FontSize', 18, 'FontWeight','normal');
        end

        if pvalue > 0.001 & pvalue < 0.01
            plot([j_indx(j, 1) j_indx(j, 2)], ...
            [y_annot(j) y_annot(j)], 'k-', 'LineWidth', 1.3);
            sig_label = '**'; 
            text(mean(j_indx(j,:)), y_annot(j), sig_label, ...
                'HorizontalAlignment','center', ...
                'FontSize', 18, 'FontWeight','normal');
        end

        if pvalue < 0.001
            plot([j_indx(j, 1) j_indx(j, 2)], ...
            [y_annot(j) y_annot(j)], 'k-', 'LineWidth', 1.3);
            sig_label = '***'; 
            text(mean(j_indx(j,:)), y_annot(j), sig_label, ...
                'HorizontalAlignment','center', ...
                'FontSize', 18, 'FontWeight','normal');
        end
        
        
    end

end



%% get the ylim and ylim data
ylimits1 = [];
ylimits2 = [];
xlimits3 = [];
for muscle = 1:4

    

    % get the ylim
    ylimits1 = cat(1, ylimits1, get(ax(muscle), 'YLim'));

    % get the ylim
    ylimits2 = cat(1, ylimits2, get(ax(4 + muscle), 'YLim'));

    % get the xlim
    xlimits3 = cat(1, xlimits3, get(ax(8 + muscle), 'XLim'));


end



%% Changing some parameters in the figure
ylimits1_extensors = [0, max(ylimits1(1:2, 2))];
ylimits1_flexors  = [0, max(ylimits1(3:4, 2))];
ylimits2_extensors = [min(ylimits2(1:2, 1)), max(ylimits2(1:2, 2))+0.1];
ylimits2_flexors  = [min(ylimits2(3:4, 1)), max(ylimits2(3:4, 2))+0.1];
xlimits3_extensors = [min(xlimits3(1:2, 1)), max(xlimits3(1:2, 2))+1];
xlimits3_flexors  = [min(xlimits3(3:4, 1)), max(xlimits3(3:4, 2))];
for muscle = 1:4

    if muscle == 1 || muscle == 2
        axes(ax(muscle));
        set(ax(muscle), 'YLim', ylimits1_extensors + [0, 1]);
        % title
        axes(ax(muscle));
        th = title(muscles_name{muscle}, ...
            'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 16);
        th.Position(2) = 4;

        % add events lines
        add_event_lines(ax(muscle), warpingto + [1, 0, 0], 3.1, [100, 2000, 3900])

        % YLim 2nd row
        axes(ax(4 + muscle))
        set(ax(4 + muscle), 'YLim', ylimits2_extensors);

        % YLim 3rd row
        axes(ax(8 + muscle))
        set(ax(8 + muscle), 'XLim', xlimits3_extensors);
    end
    

    % ylabel
    if muscle == 1
        axes(ax(8 + muscle));
        ylh = ylabel('Subjective Score');
        ylh.FontName = 'Arial';
        ylh.FontSize = 16;
        ylh.FontWeight = 'bold';
        ylh.Position(1) = -0.72;

        axes(ax(4 + muscle));
        ylh2 = ylabel('Norm. iEMG', 'FontName', 'Arial', 'FontSize', 16, ...
            'FontWeight', 'bold'); % Or 'Tracking error (RMS)'
        ylh2.Position(1) = -0.2;

        axes(ax(muscle));
        ylh3 = ylabel(sprintf('Norm. EMG'), ...
            'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 16);
        ylh3.Position(1) = -940;
    end
    


    if muscle == 3 || muscle == 4
        axes(ax(muscle));
        set(ax(muscle), 'YLim', ylimits1_flexors);
        % title
        axes(ax(muscle));
        th = title(muscles_name{muscle}, ...
            'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 16);
        th.Position(2) = 8;

        % add events lines
        add_event_lines(ax(muscle), warpingto + [1, 0, 0], 6.1, [100, 2000, 3900])

        % YLim 2nd row
        axes(ax(4 + muscle))
        set(ax(4 + muscle), 'YLim', ylimits2_flexors);

        % XLim 3rd row
        axes(ax(8 + muscle))
        set(ax(8 + muscle), 'XLim', xlimits3_flexors);
    end


    % xlabel
    axes(ax(8 + muscle));
    xlh2 = xlabel(sprintf('Norm. iEMG'));
    xlh2.FontName = 'Arial';
    xlh2.FontSize = 16;
    xlh2.FontWeight = 'bold';
    xlh2.Position(2) = -0.4;
    
end





%% correlation analysis 

% For rows each for one muscle
% 1st coloumn: pvalues of correlation analysis in P1
% 2nd coloumn: pvalues of correlation analysis in P3
% 3rd coloumn: pvalues of correlation analysis in P6
% 4th coloumn: pvalues of correlation analysis in whole data
corr_pvals = zeros(4, 4);
corr_rhos  = zeros(4, 4);

for muscle = 1:4
    
    for j = 1:3
       
        % prepare the data for correlation analysis
        idx = pressure_all_new == pressures_unique(j);
        vals = iEMG_all_new(idx, muscle);     
        scores = score_all_new(idx);

        % Spearman Correlation
        [corr_rhos(muscle, j), corr_pvals(muscle, j)] = ...
            corr(vals, scores, 'Type', 'Spearman');

    end

    % on the whole data
    [corr_rhos(muscle, 4), corr_pvals(muscle, 4)] = ...
            corr(iEMG_all_new(:, muscle), score_all_new, 'Type', 'Spearman');
end

p_values_corr_all = corr_pvals(:);  % Flatten the matrix
adj_p = mafdr(p_values_corr_all, 'BHFDR', true); % Apply FDR correction
adj_corr_pvals = reshape(adj_p, size(corr_pvals)); % Reshape back to matrix


%% add text annotations for correlation analysis
corr_strings = cell(4, 4);
preNames = {'Low:', 'Medium:', 'High:', 'All Trials:'};
for muscle = 1:4
    for j = 1:4
        p = adj_corr_pvals(muscle, j);
        if p > 0.05
            corr_strings{muscle, j} = ...
                sprintf([preNames{j}, '\n\\rho = %.2f \np = %.2f'], ...
                corr_rhos(muscle, j), p);
        elseif p < 0.05 & p > 0.01
            corr_strings{muscle, j} = ...
                sprintf([preNames{j}, '\n\\rho = %.2f \np < 0.05'], ...
                corr_rhos(muscle, j));
        elseif p < 0.01 & p > 0.001
            corr_strings{muscle, j} = ...
                sprintf([preNames{j}, '\n\\rho = %.2f \np < 0.01'], ...
                corr_rhos(muscle, j));
        elseif p < 0.001
            corr_strings{muscle, j} = ...
                sprintf([preNames{j}, '\n\\rho = %.2f \np < 0.001'], ...
                corr_rhos(muscle, j));
        end
    end
end

for muscle = 1:4
    
    axes(ax(8 + muscle));
    
    if ismember(muscle, [1, 2])
        corrStr = sprintf('Spearman \nCorrelation');
        text(2, 5+0.1, corrStr, 'HorizontalAlignment', 'left', ...
            'FontSize', 12, 'FontWeight', 'normal', ...
            'BackgroundColor', 'w', 'EdgeColor', 'none', ...
            'Color', 'k', 'FontName', 'Arial');
        for j = 4:-1:1
            % Format the correlation string
            corrStr = corr_strings{muscle, j};
            
            if j == 4, text_color = 'k'; end
            if j ~= 4, text_color = colors(j, :); end

            % Position for the text
            textX = 2;         
            textY = j+0.1; 
            % text annotation
            text(textX, textY, corrStr, 'HorizontalAlignment', 'left', ...
                'FontSize', 12, 'FontWeight', 'normal', ...
                'BackgroundColor', 'w', 'EdgeColor', 'none', ...
                'Color', text_color, 'FontName', 'Arial');
        end
    else
        corrStr = sprintf('Spearman \nCorrelation');
        text(2.7, 5+0.1, corrStr, 'HorizontalAlignment', 'left', ...
            'FontSize', 12, 'FontWeight', 'normal', ...
            'BackgroundColor', 'w', 'EdgeColor', 'none', ...
            'Color', 'k', 'FontName', 'Arial');
        for j = 4:-1:1
            % Format the correlation string
            corrStr = corr_strings{muscle, j};
            
            if j == 4, text_color = 'k'; end
            if j ~= 4, text_color = colors(j, :); end

            % Position for the text
            textX = 2.7;         
            textY = j+0.1; 
            % text annotation
            text(textX, textY, corrStr, 'HorizontalAlignment', 'left', ...
                'FontSize', 12, 'FontWeight', 'normal', ...
                'BackgroundColor', 'w', 'EdgeColor', 'none', ...
                'Color', text_color, 'FontName', 'Arial');
        end
    end
end



