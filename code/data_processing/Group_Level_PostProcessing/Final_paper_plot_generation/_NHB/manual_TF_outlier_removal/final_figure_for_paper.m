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

% Colors 
P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255;
cols = [P1_color; P3_color; P6_color];


% add eeglab to the path
eeglabPath = 'D:\Morteza\Toolboxes\EEGLAB\eeglab2025.1.0';
cd(eeglabPath)
eeglab
cd(current_path)

%% ==============================================
%  Create "stats" parameter for std_stat function
%  ==============================================
% stats = create_stats();
% Load "stats" structure
load("stats.mat")



%% ========================================================================
%                          Main Loop on Studies
%  ========================================================================

% load the subject-IC pairs for our STUDY
cd(Subject_ICs_in_clusters_path)
load("Subjects_ICs_in_clusters.mat")
cd(current_path)

for study = 8 % [4, 6, 8] % look at the studyNames 

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

        end
        baseline_qc = mean(mean(cat(3, mean_TF_qc{:}), 3), 2);
        
        % now calculate the ersp and fill the allersp with 10*log10(X)
        for c = 1:3
            [~, trial_c_idx] = find(conds == unique_conds(c));
            ic_c_qc = ic(:, :, trial_c_idx(~qc_all{sub, c}.isBad));
            mean_TF_tmp_qc = mean(ic_c_qc, 3);
            allersp_qc{sub, c} = 10*log10(mean_TF_tmp_qc ./ ...
                repmat(baseline_qc, 1, size(mean_TF_tmp_qc, 2)));

        end


    end


    %% statistical analysis
    % change the allersp shape
    allersp_qc_new = cell(3, 1);
    for c = 1:3
        allersp_qc_new{c, 1} = cat(3, allersp_qc(:, c));
        tmp = allersp_qc_new{c, 1};
        allersp_qc_new{c, 1} = cat(3, tmp{:});
    end

    
    if size(allersp_qc_new{1, 1}, 3) < 9
        stats.fieldtrip.naccu = ...
            prod(repmat(3, 1, size(allersp_qc_new{1, 1}, 3)));
    end
    stats.fieldtrip.alpha = 0.05;     % changing alpha from 0.01 to 0.05
    

    % calling std_stat function
    [pcond_qc, ~,  ~] = std_stat(allersp_qc_new, stats);

    % defining the climit for TF ERSP plots
    data = [];
    for i = 1:size(allersp_qc_new, 1)
        data = [data, reshape(mean(allersp_qc_new{i, 1}, 3).', 1, [])];
    end
    IQR = iqr(data); % interquartile range
    Q1 = quantile(data,0.25);
    myMin = round(Q1-1.5*IQR,1);
    erspdata_clim = [myMin myMin*(-1)];


    % frequency bands indexes 
    freqs = icatimef.freqs;
    theta_idx = freqs >= 4 & freqs < 8;
    alpha_idx = freqs >= 8 & freqs < 14;
    beta_idx  = freqs >= 14 & freqs < 30;
    gamma_idx = freqs >= 30 & freqs < 60;

    % ersp (power (dB)) averages over frequency bands across time
    allersp_qc_theta = cell(3, 1);
    allersp_qc_alpha = cell(3, 1);
    allersp_qc_beta  = cell(3, 1);
    allersp_qc_gamma = cell(3, 1);
    for c = 1:3
        allersp_qc_theta{c, 1} = ...
            mean(allersp_qc_new{c, 1}(theta_idx, :, :), 1);
        allersp_qc_alpha{c, 1} = ...
            mean(allersp_qc_new{c, 1}(alpha_idx, :, :), 1);
        allersp_qc_beta{c, 1}  = ...
            mean(allersp_qc_new{c, 1}(beta_idx, :, :), 1);
        allersp_qc_gamma{c, 1} = ...
            mean(allersp_qc_new{c, 1}(gamma_idx, :, :), 1);
    end

    [pcond_qc_theta, ~,  ~] = std_stat(allersp_qc_theta, stats);
    [pcond_qc_alpha, ~,  ~] = std_stat(allersp_qc_alpha, stats);
    [pcond_qc_beta, ~,  ~]  = std_stat(allersp_qc_beta, stats);
    [pcond_qc_gamma, ~,  ~] = std_stat(allersp_qc_gamma, stats);

    pcond_qc_all = {pcond_qc_theta{1}, pcond_qc_alpha{1}, ...
        pcond_qc_beta{1}, pcond_qc_gamma{1}};



    %% plot the figure 
    numCond = 3;
    alltimes = icatimef.times(1:135);
    freqstoplot = freqs < 71;
    allfreqs = freqs(freqstoplot);

    % select the part data we want to plot 
    allersp_qc_plot = cellfun(@(x) x(freqstoplot, :, :), allersp_qc_new, ...
        'UniformOutput', false);
    pcond_qc_plot = pcond_qc{1,1}(freqstoplot, :);
    
    
    monitors = get(0, 'MonitorPositions');
    studyName = studyNames{study};
    fig = figure('name', ...
        [studyName ,' before/after bad trial removal'], ...
        'InvertHardcopy', 'off', 'PaperType', 'a2', ...
        'PaperOrientation', 'landscape', ...
        'Resize', 'off');
    fig_width = 1.75*(numCond+1); 
    fig_height = 2*fig_width/2.857;

    set(gcf, 'Position', ...
        [monitors(1,1)-200 monitors(1,2)+600 150*fig_width 150*fig_height]);
    clim = erspdata_clim;
   

    % first row: TF ERSP Plots
    for condi = 1:size(allersp_qc_plot, 1) + 1
        fh(1, condi).h = subplot(2, numCond+1, condi);
        
        if condi < numCond+1
            contourf(alltimes, allfreqs, ...
                mean(allersp_qc_plot{condi, 1}, 3), 200, 'linecolor', 'none')
        elseif condi == numCond+1
            contourf(alltimes, allfreqs, ...
                pcond_qc_plot, 200, 'linecolor','none')
        end
   
        hold on;

        set(gca, 'clim', clim, 'xlim', [alltimes(1) alltimes(end)], ...
            'ydir', 'norm', 'ylim', [allfreqs(1) allfreqs(end)], ...
            'yscale', 'log')
        set(gcf, 'Colormap', calldefinedcolormap(), 'Color', [1 1 1]);

        % resize plot to fit title
        pos = fh(1, condi).h.Position;
        fh(1, condi).h.Position = ...
            [pos(1)-0.02 pos(2)-0.05 pos(3) pos(4)*0.8];

    
        % color bar
        if condi == numCond + 1
            pos = fh(1, condi).h.Position;
            c = colorbar('Position', ...
                [pos(1)+pos(3)+0.01  pos(2) 0.01 pos(4)]);
            c.Limits = clim;
            c.Ticks = sort([erspdata_clim(1) 0 erspdata_clim(2)]); 
                c.TickLabels = arrayfun(@(x) sprintf('%.1f', x), ...
                    c.Ticks, 'UniformOutput', false);
            hL = ylabel(c, [{sprintf('Power (dB)')}], ...
                'fontweight', 'bold', 'FontName', 'Arial', ...
                'FontSize', 14);
            % hL.Position(1) = 4;
            % hL.Position(2) = 0;
            % hL.HorizontalAlignment = "center";
            % hL.Rotation = 0;
            
        end
    
        set(gca,'XTick',[alltimes(1) alltimes(68) alltimes(end)],...
            'XTickLabel', {'0', '50', '100'}, ...
            'ytick', [4 8 14 30 60], 'fontsize',10);
        xtickangle(45)
        
    
        % ylabel
        if condi == 1
            ylh1 = ylabel(sprintf(['Frequency (Hz)']), ...
                'fontsize', 16, 'fontweight', 'bold', 'FontName', 'Arial');
            ylh1.Position(1) = ylh1.Position(1)-200; 
        end
    
        
        set(gca,'Fontsize',16);

        % titles
        if  condi == numCond + 1
            T = title('RM-ANOVA (p<0.05)','FontSize',16, ...
                'FontName', 'Arial', 'FontWeight', 'bold', ...
                'FontAngle', 'normal');
            T.Position(2) = T.Position(2)+85;
        else
            T = title(titles{condi}, 'FontSize', 16);
            T.Position(2) = T.Position(2)+85;
        end
    

        % event lines
        evPlotLines_correct = [alltimes(1) alltimes(68) alltimes(end)];
        eventLabels_new = ...
            {sprintf('FlxS'), sprintf('FlxE\nExtS'), sprintf('ExtE')};
        % add event lines from time warp
        if ~isempty(evPlotLines_correct)
            hold on;
            for L = 1:length(evPlotLines_correct)
                if L == 1 || L == length(evPlotLines_correct)
                    v = vline(evPlotLines_correct(L), '-k', ...
                        eventLabels_new{1,L}); % solid line
                    set(v,'LineWidth', 1, 'LineStyle', 'none'); 
                else
                    v = vline(evPlotLines_correct(L), '--k', ...
                        eventLabels_new{1,L}); 
                    set(v,'LineWidth', 1.2);
                end
            end
            
            H = findobj(gcf);
            tb = findobj(H,'Type','text');

            for textbox = 1:3 % 1:size(tb,1)
                if     mod(textbox, 3) == 1
                    pos = tb(textbox).Position;
                    tb(textbox).Position = [pos(1)+30 80 0];
                    set(tb(textbox),'Rotation',90) % rotate 90 degrees
                    set(tb(textbox),'FontSize',10, 'FontWeight', 'bold') 
                elseif mod(textbox, 3) == 2
                    pos = tb(textbox).Position;
                    tb(textbox).Position = [pos(1)-10 80 0];
                    set(tb(textbox),'Rotation',90) % rotate 90 degrees
                    set(tb(textbox),'FontSize',10, 'FontWeight', 'bold') 
                elseif mod(textbox, 3) == 0
                    pos = tb(textbox).Position;
                    tb(textbox).Position = [pos(1)+45 80 0];
                    set(tb(textbox),'Rotation',90) % rotate 90 degrees
                    set(tb(textbox),'FontSize',10, 'FontWeight', 'bold') 
                end
            end
            hold off;
        end
        
        set(gca,'FontName','Arial','box','on','YMinorTick','off');


    end


    mainT = sgtitle([studyName]);
    mainT.FontSize = 20;
    mainT.FontWeight = "bold";
    mainT.FontName = 'Arial';


    %% secod row: ERSP averages over frequency bands

    titles_bands = {'\theta band (4-8 Hz)', ...
                    '\alpha band (8-14 Hz)', ...
                    '\beta band (14-30 Hz)', ...
                    '\gamma band (30-60 Hz)'};
    allHandleVis = {'off', 'off', 'off', 'on'};
    allersp_qc_bands = {allersp_qc_theta, allersp_qc_alpha, ...
        allersp_qc_beta, allersp_qc_gamma};
    ylims = [];
    for bandi = 1:4

        data = allersp_qc_bands{bandi};
        data_mean = cellfun(@(x) mean(x, 3), data, 'UniformOutput', false);
        data_std = cellfun(@(x) std(x, [], 3), data, 'UniformOutput', false);
        data_sem = cellfun(@(x) std(x, [], 3)/sqrt(size(x, 3)), ...
            data, 'UniformOutput', false);

        fh(2, bandi).h = subplot(2, numCond+1, bandi+4);
        hold on


        for condi = 1:3
            y_mean = data_mean{condi, 1};
            y_pos = y_mean + data_sem{condi, 1};
            y_neg = y_mean - data_sem{condi, 1};
            fill([alltimes, fliplr(alltimes)], [y_pos, fliplr(y_neg)], ...
                cols(condi, :), 'FaceColor', cols(condi, :), ...
                'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        end
        for condi = 1:3
            plot(alltimes, data_mean{condi, 1}, ...
                'Color', cols(condi, :), 'LineWidth', 4, ...
                'HandleVisibility', allHandleVis{bandi});
        end
        yline(0, 'LineWidth', 0.5, 'HandleVisibility', 'off');


        set(gca, 'xlim', [alltimes(1) alltimes(end)])
        set(gca,'XTick',[alltimes(1) alltimes(68) alltimes(end)],...
            'XTickLabel', {'0', '50', '100'}, 'fontsize',10);
        xtickangle(45)

        % resize plot to fit title
        pos = fh(2, bandi).h.Position;
        fh(2, bandi).h.Position = ...
            [pos(1)-0.02 pos(2)-0.02 pos(3) pos(4)*0.8];

    
        % % ylabel
        % if bandi == 1
        %     ylh2 = ylabel('Power (dB)', ...
        %         'fontsize', 16, 'fontweight', 'bold', 'FontName', 'Arial');
        %     ylh2.Position(1) = ylh1.Position(1); 
        % end

        % xlabel
        xlh = xlabel('Cycle (%)','Fontsize',16,'fontweight','bold');
        
        set(gca,'Fontsize',16);

        % unifiy the ylimits
        ylimit = get(gca, 'YLim');
        ylims = cat(1, ylims, ylimit);


    end

    myYlim = 1.1*[-max(abs(ylims(:))), max(abs(ylims(:)))];
    for bandi = 1:4

        axes(fh(2, bandi).h)

        set(gca, 'YLim', myYlim)

        % titles
        T = title(titles_bands{bandi}, 'FontSize', 16);
        T.Position(2) = 1.45*T.Position(2);
    

        % event lines
        evPlotLines_correct = [alltimes(1) alltimes(68) alltimes(end)];
        eventLabels_new = ...
            {sprintf('FlxS'), sprintf('FlxE\nExtS'), sprintf('ExtE')};
        % add event lines from time warp
        if ~isempty(evPlotLines_correct)
            hold on;
            for L = 1:length(evPlotLines_correct)
                if L == 1 || L == length(evPlotLines_correct)
                    v = vline(evPlotLines_correct(L), '-k', ...
                        eventLabels_new{1,L}); % solid line
                    set(v,'LineWidth', 0.5);
                    set(v, "LineStyle", "none")
                else
                    v = vline(evPlotLines_correct(L), '--k', ...
                        eventLabels_new{1,L}); 
                    set(v,'LineWidth', 1.2);
                end
            end
            
            H = findobj(gcf);
            tb = findobj(H,'Type','text');

            for textbox = 1:3 % 1:size(tb,1)
                if     mod(textbox, 3) == 1
                    pos = tb(textbox).Position;
                    tb(textbox).Position = [pos(1)+30 myYlim(2)*1.1 0];
                    set(tb(textbox),'Rotation',90) % rotate 90 degrees
                    set(tb(textbox),'FontSize',10, 'FontWeight', 'bold') 
                elseif mod(textbox, 3) == 2
                    pos = tb(textbox).Position;
                    tb(textbox).Position = [pos(1)-10 myYlim(2)*1.1 0];
                    set(tb(textbox),'Rotation',90) % rotate 90 degrees
                    set(tb(textbox),'FontSize',10, 'FontWeight', 'bold') 
                elseif mod(textbox, 3) == 0
                    pos = tb(textbox).Position;
                    tb(textbox).Position = [pos(1)+45 myYlim(2)*1.1 0];
                    set(tb(textbox),'Rotation',90) % rotate 90 degrees
                    set(tb(textbox),'FontSize',10, 'FontWeight', 'bold') 
                end
            end
            hold off;
        end
        set(gca,'FontName','Arial','box','on','YMinorTick','off');


        set(gca, 'XMinorGrid', 'on', 'YMinorGrid', 'on')

    end


    % add significant difference line at the bottom of the plot
    for bandi = 1:4

        axes(fh(2, bandi).h); hold on;
        
        pcond = pcond_qc_all{bandi};

        % Find contiguous true segments
        d = diff([false; pcond(:); false]);
        iStart = find(d == 1);
        iEnd   = find(d == -1) - 1;

        yl = ylim(gca);
        y0 = yl(1) + 0.02*(yl(2)-yl(1));
        % Plot each segment as a black line
        for k = 1:numel(iStart)
            plot(alltimes([iStart(k) iEnd(k)]), [y0 y0], ...
                'k-', 'LineWidth', 4, 'HandleVisibility', 'off');
        end

    end


    axes(fh(2, 4).h); 
    lgd = legend({' Low', ' Medium', ' High'}, "Box", "off", ...
        "FontSize", 14, "FontWeight", "bold", ...
        "Location", "eastoutside");
    lgd.Position(1) = lgd.Position(1) + 0.1;
    lgd_pos = lgd.Position;  
    delete(lgd);

    pause(0.1)

    dy = 2*lgd_pos(4)/3;                 % height per item block
    xL = lgd_pos(1) + 0.2*lgd_pos(3);      % left margin inside box
    xR = lgd_pos(1) + 0.8*lgd_pos(3);      % right end of colored line
    
    % Optional: a background box (comment out if you don't want it)
    % annotation(fig,'rectangle',[lgd_pos(1), lgd_pos(2), lgd_pos(3), 1.5*lgd_pos(4)],'FaceColor','w', ...
    %     'FaceAlpha',0.0,'EdgeColor','none');
    
    labels = {'Low', 'Medium', 'High'};
    for i = 1:3
        % each block from top to bottom
        yTop = lgd_pos(2) + lgd_pos(4) - (i-2)*dy;
    
        % colored line (upper part of the block)
        yLine = yTop-0.5*dy;
        annotation(gcf,'line', [xL xR] - 0.01, [yLine yLine], ...
            'Color', cols(i, :), 'LineWidth', 5);
    
        % % text (below the line)
        % annotation(gcf,'textbox', [lgd_pos(1)-0.01 yTop-1.2*dy lgd_pos(3) dy], ...
        %     'String', labels{i}, 'EdgeColor','none', ...
        %     'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
        %     'FontWeight','bold', 'FontSize', 14);
    end


    %%
    pause(0.1)
    set(gcf, 'Position', ...
        [monitors(1,1)-200 monitors(1,2)+600 150*fig_width 150*fig_height]);
    pause(0.1)
    for i = 1:3
        % each block from top to bottom
        yTop = lgd_pos(2) + lgd_pos(4) - (i-2)*dy;
    
        % % colored line (upper part of the block)
        % yLine = yTop-0.5*dy;
        % annotation(gcf,'line', [xL xR] - 0.01, [yLine yLine], ...
        %     'Color', cols(i, :), 'LineWidth', 5);
    
        % text (below the line)
        annotation(gcf,'textbox', [lgd_pos(1)-0.01 yTop-1.35*dy lgd_pos(3) dy], ...
            'String', labels{i}, 'EdgeColor','none', ...
            'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
            'FontWeight','bold', 'FontSize', 14);
    end

    axes(fh(2, 1).h);
    % ylabel
    ylh2 = ylabel('Power (dB)', ...
        'fontsize', 16, 'fontweight', 'bold', 'FontName', 'Arial');
    ylh2.Position(1) = ylh1.Position(1); 
    ylh2.FontSize = ylh1.FontSize;
    

    %%
    studyName = studyNames{study};
    figname = studyName;
    savePath = [current_path, '\figures\final_figure_paper\'];
    if ~exist("savePath", "dir")
        mkdir(savePath)
    end
    savethisfig(gcf, strcat(figname,'.png'), savePath,'png')
    savethisfig(gcf, strcat(figname,'.fig'), savePath,'fig')
    savethisfig(gcf, strcat(figname,'.svg'), savePath,'svg')

    % close;



end

