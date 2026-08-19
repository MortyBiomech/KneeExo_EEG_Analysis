clc
clear


%% Add paths
addpath(genpath('D:\Morteza\MyProjects\ANSYMB2024\Code'))
data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
epoched_data_path = [data_path, '6_Trials_Info_and_Epoched_data\'];
current_path = ['D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab', ...
    '\data_processing\Group_Level_PostProcessing\', ...
    'Final_paper_plot_generation\Tracking_error_across_cycle'];


%% Load the tracking errors and scores 
subject_list = 5:18;

inner_struct = struct('time', [], 'tracking_error', [], 'pressure', [], ...
    'trial', [], 'score', [], 'events', []);
Subject_Tracking_Error = repmat({inner_struct}, length(subject_list), 1); 

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

    %% Store the tracking error per epoch 
    for trial = 1:length(EXP_data)
    
        % check if we are at the experimental trial
        if ~strcmp(Trials_Info{trial}.General.Description, 'Experiment')
            continue
        end

        % non-empty trial
        if isempty(EXP_data{trial}.Times)
            continue
        end


        % Epoch time
        Subject_Tracking_Error{sub}.time = vertcat( ...
            Subject_Tracking_Error{sub}.time, ...
            EXP_data{trial}.Times');

        % Tracking error
        trial_tracking_error = ...
            cellfun(@(x1, x2) abs(x1 - x2), ...
                      EXP_data{trial}.Encoder_angle, ... % x1
                      EXP_data{trial}.Ref_angle, ...     % x2
                      'UniformOutput', false);
        Subject_Tracking_Error{sub}.tracking_error = vertcat( ...
            Subject_Tracking_Error{sub}.tracking_error, ...
            trial_tracking_error');

        % Pressure level
        P = Trials_Info{trial}.General.Pressure;
        Subject_Tracking_Error{sub}.pressure = cat(1, ...
            Subject_Tracking_Error{sub}.pressure, ...
            repmat(P, length(trial_tracking_error), 1));

        % Trial number
        Subject_Tracking_Error{sub}.trial = cat(1, ...
            Subject_Tracking_Error{sub}.trial, ...
            repmat(trial, length(trial_tracking_error), 1));

        % Trial score
        score = Trials_Info{trial}.General.Score;
        Subject_Tracking_Error{sub}.score = cat(1, ...
            Subject_Tracking_Error{sub}.score, ...
            repmat(score, length(trial_tracking_error), 1));

        % Event indexes
        events = [...
        Trials_Info{trial}.Events.EXP_stream.flextoflex_start_indx', ...
        Trials_Info{trial}.Events.EXP_stream.extension_start_indx', ...
        Trials_Info{trial}.Events.EXP_stream.flextoflex_end_indx'] - ...
        repmat(Trials_Info{trial}.Events.EXP_stream.flextoflex_start_indx'-1, ...
               1, 3);
        Subject_Tracking_Error{sub}.events = cat(1, ...
            Subject_Tracking_Error{sub}.events, ...
            events);
        

    end
   
end


%% Save the data on disc
save(fullfile(current_path, 'Subjects_Tracking_Error'), 'Subject_Tracking_Error')


%% Time-warping the tracking error data


subject_list = 5:18;
warpto_subjects = zeros(length(subject_list), 3);
for sub = 1:length(subject_list)


    epochs_error = Subject_Tracking_Error{sub}.tracking_error;
    epochs_time  = Subject_Tracking_Error{sub}.time;
    epochs_event = Subject_Tracking_Error{sub}.events;
    epochs_event = epochs_event(:, 2);
    epochs_event = num2cell(epochs_event, 2);


    epochs_error = cellfun(@(x1, x2) ...
        interp1(x1, x2, linspace(x1(1), x1(end), 3*size(x1, 2)), "linear"), ...
        epochs_time, epochs_error, 'UniformOutput', false);
    Subject_Tracking_Error{sub}.tracking_error = epochs_error;
    
    epochs_event_time = cellfun(@(x1, x2) x1(x2), ...
        epochs_time, epochs_event, 'UniformOutput', false);

    epochs_time = cellfun(@(x1, x2) ...
        interp1(x1, x2, linspace(x1(1), x1(end), 3*size(x1, 2)), "linear"), ...
        epochs_time, epochs_time, 'UniformOutput', false);
    Subject_Tracking_Error{sub}.time = epochs_time;

    [~, epochs_event_2_indx] = cellfun(@(x1, x2) min(abs(x1 - x2)), ...
        epochs_time, epochs_event_time, 'UniformOutput', false);

    epochs_event = cellfun(@(x1, x2) [1, x1, size(x2, 2)], ...
        epochs_event_2_indx, epochs_time, 'UniformOutput', false);
    epochs_event = cell2mat(epochs_event);
    Subject_Tracking_Error{sub}.events = epochs_event;




    % mark outliers and remove their data
    outlier_indx1 = isoutlier(Subject_Tracking_Error{sub}.events(:, 2));
    outlier_indx2 = isoutlier(Subject_Tracking_Error{sub}.events(:, 3));
    outlier_indx  = or(outlier_indx1, outlier_indx2);

    Subject_Tracking_Error{sub}.time(outlier_indx) = [];
    Subject_Tracking_Error{sub}.tracking_error(outlier_indx) = [];
    Subject_Tracking_Error{sub}.pressure(outlier_indx) = [];
    Subject_Tracking_Error{sub}.trial(outlier_indx) = [];
    Subject_Tracking_Error{sub}.score(outlier_indx) = [];
    Subject_Tracking_Error{sub}.events(outlier_indx, :) = [];

    warpto_subjects(sub, :) = ...
        [1, median(Subject_Tracking_Error{sub}.events(:, 2)), ...
            median(Subject_Tracking_Error{sub}.events(:, 3))];
end


roundNear = 50; % round numbers to the closest multiple of this value
warpingvalues = round(median(warpto_subjects)/roundNear)*roundNear;
warpingvalues = warpingvalues + [1, 0, 0];



%% warping
Flx_L = warpingvalues(2);
Ext_L = warpingvalues(3)-warpingvalues(2);
Subject_Tracking_Error_warped = cell(length(subject_list), 1);
for sub = 1:length(subject_list)
    
    epochs_N = length(Subject_Tracking_Error{sub}.tracking_error);
    epochs_error = Subject_Tracking_Error{sub}.tracking_error;
    epochs_time  = Subject_Tracking_Error{sub}.time;
    epochs_event = Subject_Tracking_Error{sub}.events;
    for i = 1:epochs_N
        
        error = epochs_error{i};
        t     = epochs_time{i};
        event = epochs_event(i, :);
       
        t_new_Flx = linspace(t(1), t(event(2)), Flx_L);
        t_new_Ext = linspace(t(event(2)+1), t(end), Ext_L);
        t_new     = [t_new_Flx, t_new_Ext];

        error_warped = interp1(t, error, t_new, "linear");
        Subject_Tracking_Error_warped{sub} = cat(1, ...
            Subject_Tracking_Error_warped{sub}, error_warped);
        
    end

end


%% Devide the tracking errors based on score level and pressure condition
epochs_error_P_S = cell(3, 10, length(subject_list));
Pressures = [1, 3, 6];
for sub = 1:length(subject_list)

    errors   = Subject_Tracking_Error_warped{sub};
    pressure = Subject_Tracking_Error{sub}.pressure;
    score    = Subject_Tracking_Error{sub}.score;

    epochs_count = zeros(3, 10);
    for p = 1:3
        for s = 1:10
            idx = and(pressure == Pressures(p), score == s);
            if sum(idx) > 0
                epochs_error_P_S{p, s, sub} = errors(idx, :);
            end
        end
    end
    
end


for i = 1:size(epochs_error_P_S, 1)
    for j = 1:size(epochs_error_P_S, 2)
        epochs_error_all{i,j} = vertcat(epochs_error_P_S{i,j,:});
    end
end

number_of_epochs = cell2mat(cellfun(@(x) size(x, 1), epochs_error_all, ...
    'UniformOutput', false));
threshold = round(0.05*sum(number_of_epochs, 2));
idx_to_reject = number_of_epochs < threshold;


mean_error_all_subj = cellfun(@(x) mean(x, 1), epochs_error_P_S, ...
    'UniformOutput', false);
mean_error = cell(3, 10);
for i = 1:size(mean_error, 1)
    for j = 1:size(mean_error, 2)
        if idx_to_reject(i, j) == 0
            mean_error{i,j} = vertcat(mean_error_all_subj{i,j,:});
        end
    end
end


report_epoch_nums = cellfun(@(x) size(x, 1), epochs_error_P_S, ...
    'UniformOutput', false);
report_epoch_nums = cell2mat(report_epoch_nums);
report_epoch_nums(report_epoch_nums == 0) = NaN;
mean_epoch_nums = round(mean(report_epoch_nums, 3, "omitmissing"));
std_epoch_nums  = round(std(report_epoch_nums, 0, 3, "omitmissing"));
min_epoch_nums  = nan(size(mean_epoch_nums));
max_epoch_nums  = nan(size(mean_epoch_nums));
subjects_nums   = zeros(size(mean_epoch_nums));
for i = 1:size(report_epoch_nums, 1)
    for j = 1:size(report_epoch_nums, 2)
        tmp = report_epoch_nums(i, j, :);
        subjects_nums(i, j) = length(tmp(~isnan(tmp)));
        if subjects_nums(i, j) == 0, continue; end;
        min_epoch_nums(i, j) = min(tmp(~isnan(tmp)));
        max_epoch_nums(i, j) = max(tmp(~isnan(tmp)));
    end
end


%% print the numbers in a table
% Create data
data = cell(4, 11);
data(1, :) = {'', 'Score 1', 'Score 2', 'Score 3', 'Score 4', 'Score 5', ...
                'Score 6', 'Score 7', 'Score 8', 'Score 9', 'Score 10'};
data(:, 1) = {'', ...
    sprintf(['Low Pressure\nSubjects Count\nEpochs Count: [min, max]']), ...
    sprintf(['Medium Pressure\nSubjects Count\nEpochs Count: [min, max]']), ...
    sprintf(['High Pressure\nSubjects Count\nEpochs Count: [min, max]'])};
for i = 1:size(report_epoch_nums, 1)
    for j = 1:size(report_epoch_nums, 2)
        data{i+1, j+1} = sprintf(['\n', num2str(subjects_nums(i, j)), ...
            '\n', num2str(mean_epoch_nums(i, j)),' %c ', ...
                  num2str(std_epoch_nums(i, j))], 177);
    end
end
fig = figure('Position', [100 100 1600 400]);
axis off;
% Create table in figure
t = uitable(fig, 'Data', data, ...
    'Position', [50 50 1500 300], ...
    'FontSize', 11, ...
    'ColumnWidth', {300, 100, 100, 100, 100, 100, 100, 100, 100, 100, 100}, ...
    'RowStriping', 'off'); 

%% ---- plot the tracking error per score on a 2*5 layout

% Get monitor information
monitors = get(0, 'MonitorPositions');

fig = figure('name', ['Tracking error in time per score levels'], ...
    'InvertHardcopy', 'off', 'PaperType', 'a2', ...
    'PaperOrientation', 'landscape', ...
    'Resize', 'off');


% For second monitor (row 2), add drawnow before setting position
drawnow;  % Let MATLAB finish drawing on primary monitor first
pause(0.1);  % Short pause helps

% Now set position on second monitor
% set(gcf, 'Position', monitors(1, :));  % Use entire second monitor

set(fig, 'Position', [monitors(1,1)+50, monitors(1,2)+600, 2000, 800]);  % Use entire second monitor

P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
colors = [P1_color; P3_color; P6_color];

% new_time = [linspace(0, 50, Flx_L), linspace(50, 100, Ext_L+1)];
% new_time = [new_time(1:Flx_L), new_time(Flx_L+2:end)];
new_time = warpingvalues(1):warpingvalues(3);


ax = gobjects(10, 1);  % Preallocate axes array
% th = gobjects(10, 1);  % Preallocate titles 

for s = 1:10
    ax(s) = subplot(2, 5, s); hold on;
    for p = 1:3
        if ~isempty(mean_error{p, s})
            N = size(mean_error{p, s}, 1);
            M = mean(mean_error{p, s}, 1);
            sem = std(mean_error{p, s}, 0, 1)/sqrt(N);
            fill([new_time, fliplr(new_time)], ...
                 [M + sem, fliplr(M - sem)], colors(p, :), ...
                 'EdgeColor', 'none', 'FaceColor', colors(p, :), ...
                 'FaceAlpha', 0.4, 'HandleVisibility', 'off');
            
            plot(new_time, M, 'Color', 0.7*colors(p, :), 'LineWidth', 2);
        end
    end
   
end


% adjust the ylim
ylimits = [];
for s = 1:10
    ylimits = [ylimits; get(ax(s), 'YLim')];
end

ylimits_max = max(ylimits(:, 2));
for s = 1:10
    set(ax(s), 'YLim', [0, ylimits_max], ...
        'XLim', [warpingvalues(1), warpingvalues(3)]);
    % set(ax(s), 'LineWidth', 1)
end


% change XTick and Font setting
for s = 1:10
    set(ax(s), 'XTick', [1, 50, 100], ...
        'XTickLabel', {'0', '50', '100'}, 'XTickLabelRotation', 0);
end

% Add xlabel
for s = 6:10
    axes(ax(s))
    xlh = xlabel('Cycle (%)', 'FontName', 'Arial', 'FontWeight', 'bold');
    xlh.Position(2) = -40;
end

% Add ylabel
for s = [1, 6]
    axes(ax(s))
    ylh = ylabel(sprintf('Tracking Error\n(degree^2)'), ...
        'FontName', 'Arial', 'FontWeight', 'bold');
    ylh.Position(1) = -25;
end


% change the axes height and move the titles.
for s = 1:10
    set(ax(s), 'FontSize', 18)
end

for s = 1:10
    pos = get(ax(s), 'Position');
    set(ax(s), 'Position', [pos(1:3), pos(4)*0.9]);
end


% Add event lines
for s = 1:10
    
    axes(ax(s)); hold on;
    evPlotLines_correct = warpingvalues;
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
    
    H = findobj(ax(s));
    tb = findobj(H,'Type','text');
    
    K = 255;
    for textbox = 1:3 % 1:size(tb,1)
        text_event = tb(textbox).String;
        if iscell(text_event); text_event = 'FlxE, ExtS'; end;
        switch text_event
            case 'FlxS'
                % pos = tb(textbox).Position;
                tb(textbox).Position = [4 K 0];
                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                set(tb(textbox),'FontSize',10, 'FontWeight', 'normal') 
            case 'FlxE, ExtS'
                % pos = tb(textbox).Position;
                tb(textbox).Position = [50 K 0];
                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                set(tb(textbox),'FontSize',10, 'FontWeight', 'normal')
            case 'ExtE'
                % pos = tb(textbox).Position;
                tb(textbox).Position = [97 K 0];
                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                set(tb(textbox),'FontSize',10, 'FontWeight', 'normal')
        end

        % if     mod(textbox, 3) == 1
        %     pos = tb(textbox).Position;
        %     tb(textbox).Position = [3 K 0];
        %     set(tb(textbox),'Rotation',90) % rotate 90 degrees
        %     set(tb(textbox),'FontSize',10, 'FontWeight', 'normal') 
        % elseif mod(textbox, 3) == 2
        %     pos = tb(textbox).Position;
        %     tb(textbox).Position = [50 K 0];
        %     set(tb(textbox),'Rotation',90) % rotate 90 degrees
        %     set(tb(textbox),'FontSize',10, 'FontWeight', 'normal') 
        % elseif mod(textbox, 3) == 0
        %     pos = tb(textbox).Position;
        %     tb(textbox).Position = [97 K 0];
        %     set(tb(textbox),'Rotation',90) % rotate 90 degrees
        %     set(tb(textbox),'FontSize',10, 'FontWeight', 'normal') 
        % end
        % pos = tb(textbox).Position;
        % tb(textbox).Position = [pos(1) 150 0];
        % set(tb(textbox),'Rotation',90) % rotate 90 degrees
        % set(tb(textbox),'FontSize',8) 
    end

end


% add title
for s = 1:10
    axes(ax(s));
    th = title(['Score ', num2str(s)], ...
        'FontName', 'Arial', 'FontWeight', 'bold');
    % pos = th.Position;
    th.Position(2) = 290;   
    set(ax(s), 'Box', 'on')
end



%% Tracking errors of all subjects across three pressure conditions
pressure_conditions = [1, 3, 6];
tracking_error_all = cell(length(subject_list), 3);
for sub = 1:length(subject_list)
    for p = 1:3
        pressure = Subject_Tracking_Error{sub}.pressure;
        idx = pressure == pressure_conditions(p);
        signal = Subject_Tracking_Error_warped{sub};
        signal = signal(idx, :);

        tracking_error_all{sub, p} = mean(signal, 1);
    end
end




%% ----- plot the group error data

% Get monitor information
monitors = get(0, 'MonitorPositions');

fig = figure('name', ['Group tracking error'], ...
    'InvertHardcopy', 'off', 'PaperType', 'a2', ...
    'PaperOrientation', 'landscape', ...
    'Resize', 'off');


% For second monitor (row 2), add drawnow before setting position
drawnow;  % Let MATLAB finish drawing on primary monitor first
pause(0.1);  % Short pause helps

% Now set position on second monitor
% set(gcf, 'Position', monitors(1, :));  % Use entire second monitor

set(fig, 'Position', [monitors(1,1)+50, monitors(1,2)+600, 1400, 500]);  % Use entire second monitor

P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
colors = [P1_color; P3_color; P6_color];

% new_time = [linspace(0, 50, Flx_L), linspace(50, 100, Ext_L+1)];
% new_time = [new_time(1:Flx_L), new_time(Flx_L+2:end)];
new_time = warpingvalues(1):warpingvalues(3);


ax = gobjects(3, 1);  % Preallocate axes array

for s = 1:3

    ax(s) = subplot(1, 3, s); hold on;
    error = cell2mat(tracking_error_all(:, s));

    x = [new_time, fliplr(new_time)];
    y_mean = mean(error, 1);
    y_std  = std(error, 0, 1);
    y_sem  = std(error, 0, 1) / sqrt(size(error, 1));
    h1 = fill(x, [y_mean - y_sem, fliplr(y_mean + y_sem)], colors(s, :));
    h1.EdgeColor = "none";
    h1.FaceAlpha = 0.4;

    h2 = plot(new_time, y_mean, 'Color', colors(s, :)*0.7, 'LineWidth', 2);
    
end


% adjust the ylim
ylimits = [];
for s = 1:3
    ylimits = [ylimits; get(ax(s), 'YLim')];
end

ylimits_max = max(ylimits(:, 2));
for s = 1:3
    set(ax(s), 'YLim', [0, ylimits_max], ...
        'XLim', [warpingvalues(1), warpingvalues(3)]);
    % set(ax(s), 'LineWidth', 1)
end


% change XTick and Font setting
for s = 1:3
    set(ax(s), 'XTick', [1, 50, 100], ...
        'XTickLabel', {'0', '50', '100'}, 'XTickLabelRotation', 0);
end

% Add xlabel
for s = 1:3
    axes(ax(s))
    xlh = xlabel('Cycle (%)', 'FontName', 'Arial', 'FontWeight', 'bold');
    xlh.Position(2) = -30;
end

% Add ylabel
for s = 1
    axes(ax(s))
    ylh = ylabel(sprintf('Tracking Error\n(degree^2)'), ...
        'FontName', 'Arial', 'FontWeight', 'bold');
    ylh.Position(1) = -25;
end


% change the axes height and move the titles.
for s = 1:3
    set(ax(s), 'FontSize', 18)
end

for s = 1:3
    pos = get(ax(s), 'Position');
    set(ax(s), 'Position', [pos(1:3), pos(4)*0.7]);
    ax(s).Position(2) = ax(s).Position(2) + 0.05;
end


%% Add event lines
event_lines = [1, 50, 100; ...
               1, 50, 100; ...
               1, 50, 100];
event_desc  = {'FlxS', sprintf('FlxE\nExtS'), sprintf('ExtE')};

% event_lines = [1, 33, 50, 50+(50-33), 100; ...
%                1, 23, 50, 50+(50-23), 100; ...
%                1, 20, 50, 50+(50-20), 100];
% event_desc  = ...
%     {'FlxS', sprintf('\\itApprox.\n\\itPAM Eng.'), sprintf('FlxE\nExtS'), ...
%     sprintf('\\itApprox.\n\\itPAM disEng.'), sprintf('ExtE')};
for s = 1:3
    
    axes(ax(s)); hold on;
    evPlotLines_correct = event_lines(s, :);
    eventLabels_new = event_desc;
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
    
    H = findobj(ax(s));
    tb = findobj(H,'Type','text');
    
    K = 185;
    for textbox = 1:5 % 1:size(tb,1)
        text_event = tb(textbox).String;
        if iscell(text_event) 
            if strcmp(text_event{1}, 'FlxE')
                text_event = 'FlxE, ExtS'; 
            elseif strcmp(text_event{1}, '\itApprox.')
                text_event = ['\itApprox.\n', text_event{2}]; 
            end
        end
        switch text_event
            case 'FlxS'
                tb(textbox).Position = [4 K 0];
                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                set(tb(textbox),'FontSize',12, 'FontWeight', 'normal') 
            % case '\itApprox.\n\itPAM Eng.' %'Approx. PAM\nengagement'
            %     tb(textbox).Position = [event_lines(s, 2) K 0];
            %     set(tb(textbox),'Rotation',90) % rotate 90 degrees
            %     set(tb(textbox),'FontSize',10, 'FontWeight', 'normal')
            case 'FlxE, ExtS'
                tb(textbox).Position = [50 K 0];
                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                set(tb(textbox),'FontSize',12, 'FontWeight', 'normal')
            % case '\itApprox.\n\itPAM disEng.' %'Approx. PAM\ndisengagement'
            %     tb(textbox).Position = [event_lines(s, 4) K 0];
            %     set(tb(textbox),'Rotation',90) % rotate 90 degrees
            %     set(tb(textbox),'FontSize',10, 'FontWeight', 'normal')
            case 'ExtE'
                tb(textbox).Position = [97 K 0];
                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                set(tb(textbox),'FontSize',12, 'FontWeight', 'normal')
        end

       
    end

end


% add title
conditions = {'Low', 'Medium', 'High'};
for s = 1:3
    axes(ax(s));
    th = title([conditions{s}, ' Pressure'], ...
        'FontName', 'Arial', 'FontWeight', 'bold');
    % pos = th.Position;
    th.Position(2) = 220;   
    set(ax(s), 'Box', 'on')
end




%% Plot all Tracking errors in one figure (for LokoAssist Poster Feb.2026)

% P1
P1_error = tracking_error_all(:, 1);
P1_error = cell2mat(P1_error);
P1_error_mean = mean(P1_error, 1);
P1_error_std  = std(P1_error, [], 1);
P1_error_sem  = P1_error_std / sqrt(size(P1_error, 1));

% P3
P3_error = tracking_error_all(:, 2);
P3_error = cell2mat(P3_error);
P3_error_mean = mean(P3_error, 1);
P3_error_std  = std(P3_error, [], 1);
P3_error_sem  = P3_error_std / sqrt(size(P3_error, 1));

% P6
P6_error = tracking_error_all(:, 3);
P6_error = cell2mat(P6_error);
P6_error_mean = mean(P6_error, 1);
P6_error_std  = std(P6_error, [], 1);
P6_error_sem  = P6_error_std / sqrt(size(P6_error, 1));


% Get monitor information
monitors = get(0, 'MonitorPositions');
fig = figure('name', ['Group tracking error'], ...
    'InvertHardcopy', 'off', 'PaperType', 'a2', ...
    'PaperOrientation', 'landscape', ...
    'Resize', 'off');

fig_width = 1.75*(3+1); 
fig_height = 2*fig_width/2.857;

set(gcf, 'Position', ...
    [monitors(1,1)+200 monitors(1,2)+600 150*fig_width 150*fig_height]);


P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
colors = [P1_color; P3_color; P6_color];

% new_time = [linspace(0, 50, Flx_L), linspace(50, 100, Ext_L+1)];
% new_time = [new_time(1:Flx_L), new_time(Flx_L+2:end)];
new_time = warpingvalues(1):warpingvalues(3);


x = [new_time, fliplr(new_time)];
signal = [P1_error_mean; P3_error_mean; P6_error_mean];
signal_std = [P1_error_std; P3_error_std; P6_error_std];
signal_sem = [P1_error_sem; P3_error_sem; P6_error_sem];


fh = subplot(2, 4, 4); hold on;

for s = 1:3

    y_mean = signal(s, :);
    y_std  = signal_std(s, :);
    y_sem  = signal_sem(s, :);
    h1 = fill(x, [y_mean - y_sem, fliplr(y_mean + y_sem)], colors(s, :), ...
        'HandleVisibility', 'off');
    h1.EdgeColor = "none";
    h1.FaceAlpha = 0.4;

    h2 = plot(new_time, y_mean, 'Color', colors(s, :), 'LineWidth', 2);
    
end

% resize plot to fit title
pos = fh.Position;
fh.Position = [pos(1)-0.02 pos(2)-0.05 pos(3) pos(4)*0.8];

set(gca, 'XLim', [1, 100], 'YLim', [0 12])
set(gca,'XTick',[1 50 100],...
    'XTickLabel', {'0', '50', '100'}, 'fontsize',10);
xtickangle(45)





thd = title('Tracking Error');
thd.Position(2) = thd.Position(2) + 3;


set(gca,'Fontsize',16);

% ylabel
ylh1 = ylabel(sprintf(['degree']), ...
    'fontsize', 16, 'fontweight', 'bold', 'FontName', 'Arial');
ylh1.Position(1) = ylh1.Position(1) + 7; 



% event lines
evPlotLines_correct = [1 50 100];
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
            tb(textbox).Position = [pos(1)+1 12.5 0];
            set(tb(textbox),'Rotation',90) % rotate 90 degrees
            set(tb(textbox),'FontSize',10, 'FontWeight', 'bold') 
        elseif mod(textbox, 3) == 2
            pos = tb(textbox).Position;
            tb(textbox).Position = [pos(1)-1 12.5 0];
            set(tb(textbox),'Rotation',90) % rotate 90 degrees
            set(tb(textbox),'FontSize',10, 'FontWeight', 'bold') 
        elseif mod(textbox, 3) == 0
            pos = tb(textbox).Position;
            tb(textbox).Position = [pos(1)+4 12.5 0];
            set(tb(textbox),'Rotation',90) % rotate 90 degrees
            set(tb(textbox),'FontSize',10, 'FontWeight', 'bold') 
        end
    end
    hold off;
end

set(gca,'FontName','Arial','box','on','YMinorTick','off');



%%

mainT = sgtitle([studyName]);
mainT.FontSize = 20;
mainT.FontWeight = "bold";
mainT.FontName = 'Arial';