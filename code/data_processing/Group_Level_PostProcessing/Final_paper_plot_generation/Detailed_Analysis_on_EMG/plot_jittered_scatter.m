function plot_jittered_scatter(subject_list, EMG_perSubject, muscle, colors)

    subjects = subject_list;
    subjects(6) = [];

    % Jitter setup for spread
    spread = 0.15;
    rng(1); % Sets the random seed to 1
    % x positions (jittered for clarity)
    loc = 1:3;
    x_jitter = loc + (rand(14,numel(loc))-0.5)*spread;
    
    subjects_unique = unique(subjects);
    subj_val = [];
    for i = 1:length(EMG_perSubject)
        subj_val = cat(1, subj_val, EMG_perSubject{i}.iEMG(:, muscle)');
    end
    
    for s = 1:numel(subjects_unique)
        x = x_jitter(s, :);
        subj_val_s = subj_val(s, :);
        % Paired line for within-subject
        plot(x, subj_val_s, '-', 'Color', [0.7 0.7 0.7 0.7], 'LineWidth', 0.5);
    end
    
    n_cond = 3;
    % Box plot layer
    for i = 1:n_cond
        
        data = subj_val(:, i);
    
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
    
    
    % Individual data points (jittered scatter)
    for s = 1:numel(subjects_unique)
        subj_val_s = subj_val(s, :);
    
        x = x_jitter(s, :);
    
        % scatter each subject's points
        for j = 1:numel(loc)
            scatter(x(j), subj_val_s(j), 60, 'MarkerFaceColor', colors(j,:), ...
                'MarkerEdgeColor', colors(j,:), ...
                'MarkerFaceAlpha', 0.4, ...
                'MarkerEdgeAlpha', 0.4, ...
                'LineWidth',0.7);
        end
    
    end
    
    
    
    % Overlay group means (LMM, or just mean if you prefer)
    mu = mean(subj_val, 1);
    x = [1, 2, 3] - repmat(spread, 1, 3);
    plot(x, mu, 'LineWidth', 2, 'Color', [0.3 0.3 0.3])


    pressure_levels = {'Low', 'Medium', 'High'};
    
    set(gca, 'XTick', 1:n_cond, 'XTickLabel', pressure_levels);
    set(gca,'FontSize', 14); box off
    xlabel('Pressure', 'FontName', 'Arial', 'FontSize', 16, ...
        'FontWeight', 'bold', 'VerticalAlignment', 'top'); 
    % if muscle == 1
    %     ylabel('Norm. iEMG', 'FontName', 'Arial', 'FontSize', 16, ...
    %         'FontWeight', 'bold'); % Or 'Tracking error (RMS)'
    % end
    % ylim([2 13.5]);
    xlim([0.5 3.5])


end