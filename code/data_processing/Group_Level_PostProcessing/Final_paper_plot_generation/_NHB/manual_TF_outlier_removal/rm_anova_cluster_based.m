function rm_anova_cluster_based(allersp, allersp_qc, ...
    alltimes, allfreqs, stats, studyName, current_path)
    
    titles = {'Low Pressure', 'Medium Pressure', 'High Pressure'};

    [pcond, ~, ~] = std_stat(allersp, stats);
    [pcond_qc, ~,  ~] = std_stat(allersp_qc, stats);

    data = [];
    for i = 1:size(allersp, 1)
        data = [data, reshape(mean(allersp_qc{i, 1}, 3).', 1, [])];
    end
    IQR = iqr(data); % interquartile range
    Q1 = quantile(data,0.25);
    myMin = round(Q1-1.5*IQR,1);
    erspdata_clim = [myMin myMin*(-1)];


    
    numCond = 3;
    
    monitors = get(0, 'MonitorPositions');
    
    fig = figure('name', ...
        [studyName ,' before/after bad trial removal'], ...
        'InvertHardcopy', 'off', 'PaperType', 'a2', ...
        'PaperOrientation', 'landscape', ...
        'Resize', 'off');
    fig_width = 1.75*(numCond+1); 
    fig_height = 2*fig_width/2.857;

    set(fig, 'Position', ...
        [monitors(1,1)-200 monitors(1,2)+600 150*fig_width 150*fig_height]);
    clim = erspdata_clim;
   

    all_allersp = {allersp, allersp_qc};
    all_pcond = {pcond, pcond_qc};
    all_ylabels = {'Before bad trial removal', 'After bad trial removal'};
    
    for condi = 1:size(allersp, 1) + 1
        for row = 1:2
            
            ersp = all_allersp{row};
            pcond_row = all_pcond{row};


            fh(row, condi).h = subplot(2, numCond+1, condi + (row-1)*4);
    
            if condi < numCond+1
                contourf(alltimes, allfreqs, ...
                    mean(ersp{condi, 1}, 3), 200, 'linecolor', 'none')
            elseif condi == numCond+1
                contourf(alltimes, allfreqs, ...
                    pcond_row{1, 1}, 200, 'linecolor','none')
            end
            hold on;
    
            set(gca, 'clim', clim, 'xlim', [alltimes(1) alltimes(end)], ...
                'ydir', 'norm', 'ylim', [allfreqs(1) allfreqs(end)], ...
                'yscale', 'log')
            set(gcf, 'Colormap', calldefinedcolormap(), 'Color', [1 1 1]);
    
            % resize plot to fit title
            pos = fh(row, condi).h.Position;
            fh(row, condi).h.Position = ...
                [pos(1) pos(2)+(row-2)*0.08 pos(3) pos(4)*0.85];
    
    
            % color bar
            if condi == numCond + 1
                pos = fh(row, condi).h.Position;
                c = colorbar('Position', ...
                    [pos(1)+pos(3)+0.01  pos(2) 0.01 pos(4)]);
                c.Limits = clim;
                c.Ticks = sort([erspdata_clim(1) 0 erspdata_clim(2)]); 
                    c.TickLabels = arrayfun(@(x) sprintf('%.1f', x), ...
                        c.Ticks, 'UniformOutput', false);
                hL = ylabel(c, [{'Power (dB)'}], ...
                    'fontweight', 'bold', 'FontName', 'Arial', ...
                    'FontSize', 14,'Rotation',90);
                hL.Position(1) = 4;
                hL.Position(2) = 0;
            end
    
            set(gca,'XTick',[alltimes(1) alltimes(66) alltimes(end)],...
                'XTickLabel',{'0', '50', '100'}, ...
                'ytick', [4 8 14 30 60 120],'fontsize',10);
            xtickangle(45)
            h = gca;
            h.XRuler.TickLabelGapOffset = 0; % it was -2
    
            % ylabel
            if condi == 1
                ylh = ylabel(sprintf([all_ylabels{row}, '\n\nFrequency (Hz)']), ...
                    'fontsize', 16, 'fontweight', 'bold', 'FontName', 'Arial');
                ylh.Position(1) = ylh.Position(1)-200; 
            end
    
            % xlabel
            if row == 2
                xlh = xlabel('Cycle (%)','Fontsize',16,'fontweight','bold');
                xlh.Position(2) = 1.5;
            end
            
    
            set(gca,'Fontsize',16);

            % titles
            if row == 1
                if  condi == numCond + 1
                    T = title('RM-ANOVA (p<0.05)','FontSize',16, ...
                        'FontName', 'Arial', 'FontWeight', 'bold', ...
                        'FontAngle', 'normal');
                    T.Position(2) = T.Position(2)+150;
                else
                    T = title(titles{condi}, 'FontSize', 16);
                    T.Position(2) = T.Position(2)+150;
                end
            end
    

            % event lines
            evPlotLines_correct = [alltimes(1) alltimes(66) alltimes(end)];
            eventLabels_new = ...
                {sprintf('FlxS'), sprintf('FlxE\nExtS'), sprintf('ExtE')};
            % add event lines from time warp
            if ~isempty(evPlotLines_correct)
                hold on;
                for L = 1:length(evPlotLines_correct)
                    if L == 1 || L == length(evPlotLines_correct)
                        v = vline(evPlotLines_correct(L), '-k', ...
                            eventLabels_new{1,L}); % solid line
                        set(v,'LineWidth', 1); 
                    else
                        v = vline(evPlotLines_correct(L), ':k', ...
                            eventLabels_new{1,L}); 
                        set(v,'LineWidth', 1.2);
                    end
                end
                
                H = findobj(gcf);
                tb = findobj(H,'Type','text');
    
                for textbox = 1:3 % 1:size(tb,1)
                    if     mod(textbox, 3) == 1
                        pos = tb(textbox).Position;
                        tb(textbox).Position = [pos(1)+30 150 0];
                        set(tb(textbox),'Rotation',90) % rotate 90 degrees
                        set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                    elseif mod(textbox, 3) == 2
                        pos = tb(textbox).Position;
                        tb(textbox).Position = [pos(1)-10 150 0];
                        set(tb(textbox),'Rotation',90) % rotate 90 degrees
                        set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                    elseif mod(textbox, 3) == 0
                        pos = tb(textbox).Position;
                        tb(textbox).Position = [pos(1)+15 150 0];
                        set(tb(textbox),'Rotation',90) % rotate 90 degrees
                        set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                    end
                end
                hold off;
            end
            set(gca,'FontName','Arial','box','on','YMinorTick','off');
        end
    end

    mainT = sgtitle([studyName]);
    mainT.FontSize = 20;
    mainT.FontWeight = "bold";
    mainT.FontName = 'Arial';
  

    

    % set figure settings
    set(gcf, 'Colormap', calldefinedcolormap2(), 'Color', [1 1 1]);

    figname = studyName;
    savePath = [current_path, '\figures\rm_anova\'];
    if ~exist("savePath", "dir")
        mkdir(savePath)
    end
    savethisfig(gcf, strcat(figname,'.png'), savePath,'png')
    savethisfig(gcf, strcat(figname,'.fig'), savePath,'fig')
    savethisfig(gcf, strcat(figname,'.svg'), savePath,'svg')

    close;


    % save the pcond_qc results
    fileName = [studyName, ' ersp_result.mat'];
    if ~exist(fullfile(current_path, '\ersp_results'), "dir")
        mkdir(fullfile(current_path, '\ersp_results'))
    end
    save(fullfile(current_path, '\ersp_results\', fileName), 'pcond_qc')

end