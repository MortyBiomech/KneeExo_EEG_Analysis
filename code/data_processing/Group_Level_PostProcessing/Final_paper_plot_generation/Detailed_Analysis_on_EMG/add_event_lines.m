function add_event_lines(ax, evPlotLines_correct, K, M)
        
    axes(ax); 
    eventLabels_new = {sprintf('FlxS'), sprintf('FlxE\nExtS'), sprintf('ExtE')};

    % add event lines from time warp
    for L = 1:length(evPlotLines_correct)
        if L == 1 || L == length(evPlotLines_correct)
            %v = vline(evPlotLines(L),'-k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1); %solid line
            v = vline(evPlotLines_correct(L),'-k', eventLabels_new{1,L}); 
            set(v,'LineWidth', 1, 'Color', 'none'); %solid line
        else
            %v = vline(evPlotLines(L),':k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1.2);
            v = vline(evPlotLines_correct(L),'--k',eventLabels_new{1,L}); 
            set(v,'LineWidth', 1);
        end
    end
    
    H = findobj(ax);
    tb = findobj(H,'Type','text');
    
    
    for textbox = 1:3 % 1:size(tb,1)
        text_event = tb(textbox).String;
        if iscell(text_event); text_event = 'FlxE, ExtS'; end;
        switch text_event
            case 'FlxS'
                tb(textbox).Position = [M(1) K 0];
                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                set(tb(textbox),'FontSize',10, 'FontWeight', 'normal') 
            case 'FlxE, ExtS'
                tb(textbox).Position = [M(2) K 0];
                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                set(tb(textbox),'FontSize',10, 'FontWeight', 'normal')
            case 'ExtE'
                tb(textbox).Position = [M(3) K 0];
                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                set(tb(textbox),'FontSize',10, 'FontWeight', 'normal')
        end
    end



end