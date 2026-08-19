function plt_save_ERSP_qc(Subjects_sorted, ICs_sorted, allersp_qc, ...
    allersp, new_times, freqs, studyName, current_path)

    %  =========================================================
    %  Plot the Subject IC TF with and without specPCA deniosing
    %  =========================================================

    titles = {'Low Pressure', 'Medium Pressure', 'High Pressure'};

    for sub = 1:size(allersp_qc, 1)


        % find the best climits
        data = [];
        for c = 1:3
            % data = [data, ...
            %     reshape(allersp{sub, c}, 1, [])];
            data = [data, ...
                reshape(allersp_qc{sub, c}, 1, [])];
        end
        IQR = iqr(data); % interquartile range
        Q1 = quantile(data,0.25);
        myMin = round(Q1-1.5*IQR,1);
        erspdata_clim = [myMin myMin*(-1)];



        monitors = get(0, 'MonitorPositions');
        fig = figure('name', ['ERSP with and without Bad trial removal'], ...
            'InvertHardcopy', 'off', 'PaperType', 'a2', ...
            'PaperOrientation', 'landscape', ...
            'Resize', 'off');
        
        % For second monitor (row 2), add drawnow before setting position
        drawnow;  % Let MATLAB finish drawing on primary monitor first
        pause(0.1);  % Short pause helps
        
        set(fig, 'Position', [monitors(1,1)+100, monitors(1,2)+700, 1100, 800]);
        
        for i = 1:3
            fh(1, i).h = subplot(2, 3, i);
            tf = allersp{sub, i};
            contourf(new_times, freqs, tf, 200, ...
                'linecolor','none')
            set(gca,'clim', erspdata_clim, ...
                'xlim', [new_times(1) new_times(end)], ...
                'ydir', 'norm', ...
                'ylim', [freqs(1) freqs(end)], ...
                'yscale','log')
            set(gcf, 'Colormap', calldefinedcolormap(), 'Color', [1 1 1]);
            
            fh(2, i).h = subplot(2, 3, i+3);
            tf = allersp_qc{sub, i};
            contourf(new_times, freqs, tf, 200, ...
                'linecolor','none')
            set(gca, 'clim', erspdata_clim, ...
                'xlim', [new_times(1) new_times(end)], ...
                'ydir', 'norm', ...
                'ylim', [freqs(1) freqs(end)], ...
                'yscale', 'log')
            set(gcf, 'Colormap', calldefinedcolormap(), 'Color', [1 1 1]);
        
            % resize plot to fit title
            pos = fh(1, i).h.Position;
            fh(1, i).h.Position = [pos(1) pos(2)-0.07 pos(3)*.9 pos(4)*.8];
        
            pos = fh(2, i).h.Position;
            fh(2, i).h.Position = [pos(1) pos(2) pos(3)*.9 pos(4)*.8];
        
        
            if i == 3
                for j = 1:2
                    pos = fh(j, i).h.Position;
                    c = colorbar('Position', ...
                        [pos(1)+pos(3)+0.01  pos(2) 0.01 pos(4)]);
                    % c.Limits = erspdata_clim;
                    % % make the Ticks symmetric
                    % maxAbs = max(abs(c.Ticks));
                    % If maxAbs isn't in v, append it to make symmetric
                    % if ~ismember(maxAbs, c.Ticks)
                    c.Ticks = sort([erspdata_clim(1) 0 erspdata_clim(2)]); 
                    c.TickLabels = arrayfun(@(x) sprintf('%.1f', x), ...
                        c.Ticks, 'UniformOutput', false);
                    
                    % end
                    hL = ylabel(c,[{'Power (dB)'}],...
                        'fontweight', 'bold', 'FontName', 'Arial', ...
                        'FontSize', 14, 'Rotation', 90);
                    hL.Position(1) = 4;
                    hL.Position(2) = 0;
                end
            end
        
            
            axes(fh(1, i).h)
            set(gca, ...
                'XTick',[new_times(1) new_times(66) new_times(end)], ...
                'XTickLabel', {'0', '50', '100'}, ...
                'ytick', [4 8 14 30 60 120], ...
                'fontsize',10);
            xtickangle(45)
            set(gca,'Fontsize',16);
            axes(fh(2, i).h)
            set(gca, ...
                'XTick',[new_times(1) new_times(66) new_times(end)], ...
                'XTickLabel', {'0', '50', '100'}, ...
                'ytick', [4 8 14 30 60 120], ...
                'fontsize',10);
            xtickangle(45)
            set(gca,'Fontsize',16);
            
            
            % ylabel
            if i == 1
                axes(fh(1, i).h)
                ylh = ylabel(sprintf(['Before bad trial removal' ...
                    '\n\nFrequency (Hz)']), ...
                    'fontsize', 16, 'fontweight', 'bold', 'FontName', 'Arial');
                ylh.Position(1) = ylh.Position(1); 
        
                axes(fh(2, i).h)
                ylh = ylabel(sprintf(['After bad trial removal' ...
                    '\n\nFrequency (Hz)']), ...
                    'fontsize', 16, 'fontweight', 'bold', 'FontName', 'Arial');
                ylh.Position(1) = ylh.Position(1); 
            end
            
            xlh = xlabel('Cycle (%)','Fontsize',16,'fontweight','bold');
            xlh.Position(2) = 1.5;
        
            % title
            axes(fh(1, i).h)
            T = title(titles{i},'FontSize',16);
            T.Position(2) = T.Position(2) + 160;
        
        
            for j = 1:2
                axes(fh(j, i).h)
                evPlotLines = [new_times(1) new_times(67) new_times(end)];
                eventLabels = ...
                    {sprintf('FlxS'), sprintf('FlxE\nExtS'), sprintf('ExtE')};
                hold on;
                for L = 1:length(evPlotLines)
                    if L == 1 || L == length(evPlotLines)
                        v = vline(evPlotLines(L),'-k', eventLabels{1,L}); 
                        set(v,'LineWidth',1); % solid line
                    else
                        v = vline(evPlotLines(L),':k',eventLabels{1,L}); 
                        set(v,'LineWidth',1.2);
                    end
                end
            
                H = findobj(gca);
                tb = findobj(H,'Type','text');
        
                for textbox = 1:3 % 1:size(tb,1)
                    if     mod(textbox, 3) == 1
                        % Ext End
                        pos = tb(textbox).Position;
                        tb(textbox).Position = [pos(1)+3 150 0];
                        set(tb(textbox),'Rotation',90) % rotate 90 degrees
                        set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                    elseif mod(textbox, 3) == 2
                        pos = tb(textbox).Position;
                        tb(textbox).Position = [pos(1)-1 150 0];
                        set(tb(textbox),'Rotation',90) % rotate 90 degrees
                        set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                    elseif mod(textbox, 3) == 0
                        pos = tb(textbox).Position;
                        tb(textbox).Position = [pos(1)+1 150 0];
                        set(tb(textbox),'Rotation',90) % rotate 90 degrees
                        set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                    end
                end
            end
        
        end
    
        mainT = sgtitle(['S', num2str(Subjects_sorted(sub)), ...
                 ' IC', num2str(ICs_sorted(sub)), ...
                 ' - ', studyName]);
        mainT.FontSize = 18;
        mainT.FontWeight = "bold";
        mainT.FontName = 'Arial';
    
    
        % save the figure
        new_path = [current_path, ...
            '\figures\before and after bad trial removal\'];
        if ~exist(new_path, "dir")
            mkdir(new_path)
        end
        cd(new_path)
        folderName = studyName;
        if ~exist(folderName, "dir")
            mkdir(folderName)
        end

        figname = mainT.String;
        savethisfig(gcf, strcat(figname,'.png'), ...
            [new_path, folderName],'png')
        savethisfig(gcf, strcat(figname,'.fig'), ...
            [new_path, folderName],'fig')
        savethisfig(gcf, strcat(figname,'.svg'), ...
            [new_path, folderName],'svg')

        close;

    end

    cd(current_path)

end