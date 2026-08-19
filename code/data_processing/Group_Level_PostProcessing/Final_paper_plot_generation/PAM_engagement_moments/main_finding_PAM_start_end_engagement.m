clc
clear


%% Add paths
addpath(genpath('D:\Morteza\MyProjects\ANSYMB2024\Code'))
data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
epoched_data_path = [data_path, '6_Trials_Info_and_Epoched_data\'];
force_sensor_data_path = [data_path, '9_EXP_Analysis\'];
current_path = ['D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab', ...
    '\data_processing\Group_Level_PostProcessing\', ...
    'Final_paper_plot_generation\PAM_engagement_moments'];


%% Load the force sensor data and knee angle

% Just these subjects have the force sensor data:
subject_list = [11, 12, 15, 16, 17, 18]; 

inner_struct = struct('time', [], 'force', [], 'angle', [], ...
    'pressure', [], 'score', [], 'trial', [], 'events', []);

Subject_Force_Angle = cell(length(subject_list), 2);
Subject_Force_Angle(:, 1) = arrayfun(@(x) {['S', num2str(x)]}, ...
    subject_list');
Subject_Force_Angle(:, 2) = repmat({inner_struct}, length(subject_list), 1); 

Force_Angle = repmat({inner_struct}, length(subject_list), 1); 

for sub = 1:length(subject_list)
    
    %% Load the epoched experimental data
    folderName = [epoched_data_path, 'sub-', ...
        num2str(subject_list(sub))];
    cd(folderName)
    disp(['Loading EXP data from subject ', num2str(subject_list(sub)), ' ...'])
    load Epochs_FlextoFlex_based.mat
    load Trials_Info.mat
    % extract the EXP_stream
    EXP_data = cellfun(@(x) x.EXP_stream, Epochs_FlextoFlex_based, ...
        'UniformOutput', false);
    % free up the memory
    clear Epochs_FlextoFlex_based
    cd(current_path)


    %% Load the calibrated force sensor data (not timewarped)
    folderName = [force_sensor_data_path, 'sub-', ...
        num2str(subject_list(sub))];
    cd(folderName)
    disp(['Loading force sensor data from subject ', ...
        num2str(subject_list(sub)), ' ...'])
    load calibrated_Force.mat
    force = calibrated_Force.F_cal;
    cd(current_path)


    %% Store the force and knee angle per epoch 
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
        Force_Angle{sub}.time = vertcat( ...
            Force_Angle{sub}.time, ...
            EXP_data{trial}.Times');

        % Force sensor data
        Force_Angle{sub}.force = vertcat( ...
            Force_Angle{sub}.force, ...
            force{trial}');

        % Knee angle
        Force_Angle{sub}.angle = vertcat( ...
            Force_Angle{sub}.angle, ...
            EXP_data{trial}.Encoder_angle');

        % Pressure level
        P = Trials_Info{trial}.General.Pressure;
        Force_Angle{sub}.pressure = cat(1, ...
            Force_Angle{sub}.pressure, ...
            repmat(P, length(EXP_data{trial}.Encoder_angle), 1));

        % Trial number
        Force_Angle{sub}.trial = cat(1, ...
            Force_Angle{sub}.trial, ...
            repmat(trial, length(EXP_data{trial}.Encoder_angle), 1));

        % Trial score
        score = Trials_Info{trial}.General.Score;
        Force_Angle{sub}.score = cat(1, ...
            Force_Angle{sub}.score, ...
            repmat(score, length(EXP_data{trial}.Encoder_angle), 1));

        % Event indexes
        events = [...
        Trials_Info{trial}.Events.EXP_stream.flextoflex_start_indx', ...
        Trials_Info{trial}.Events.EXP_stream.extension_start_indx', ...
        Trials_Info{trial}.Events.EXP_stream.flextoflex_end_indx'] - ...
        repmat(Trials_Info{trial}.Events.EXP_stream.flextoflex_start_indx'-1, ...
               1, 3);
        Force_Angle{sub}.events = cat(1, ...
            Force_Angle{sub}.events, ...
            events);
        

    end
   
end


Subject_Force_Angle(:, 2) = Force_Angle; 


%% Save the data
save(fullfile(current_path, 'Subjects_Force_Angle'), 'Subject_Force_Angle')


%% Time-warping the force and angle data
subject_list = [11, 12, 15, 16, 17, 18]; 
% identifying the warping indeces
warpto_subjects = zeros(length(subject_list), 3);
for sub = 1:length(subject_list)

    epochs_force = Subject_Force_Angle{sub, 2}.force;
    epochs_angle = Subject_Force_Angle{sub, 2}.angle;
    epochs_time  = Subject_Force_Angle{sub, 2}.time;
    epochs_event = Subject_Force_Angle{sub, 2}.events;
    epochs_event = epochs_event(:, 2);
    epochs_event = num2cell(epochs_event, 2);

    epochs_force = cellfun(@(x1, x2) ...
        interp1(x1, x2, linspace(x1(1), x1(end), 3*size(x1, 2)), "linear"), ...
        epochs_time, epochs_force, 'UniformOutput', false);
    Subject_Force_Angle{sub, 2}.force = epochs_force;
    epochs_angle = cellfun(@(x1, x2) ...
        interp1(x1, x2, linspace(x1(1), x1(end), 3*size(x1, 2)), "linear"), ...
        epochs_time, epochs_angle, 'UniformOutput', false);
    Subject_Force_Angle{sub, 2}.angle = epochs_angle;

    epochs_event_time = cellfun(@(x1, x2) x1(x2), ...
        epochs_time, epochs_event, 'UniformOutput', false);

    epochs_time = cellfun(@(x1, x2) ...
        interp1(x1, x2, linspace(x1(1), x1(end), 3*size(x1, 2)), "linear"), ...
        epochs_time, epochs_time, 'UniformOutput', false);
    Subject_Force_Angle{sub, 2}.time = epochs_time;

    [~, epochs_event_2_indx] = cellfun(@(x1, x2) min(abs(x1 - x2)), ...
        epochs_time, epochs_event_time, 'UniformOutput', false);

    epochs_event = cellfun(@(x1, x2) [1, x1, size(x2, 2)], ...
        epochs_event_2_indx, epochs_time, 'UniformOutput', false);
    epochs_event = cell2mat(epochs_event);
    Subject_Force_Angle{sub, 2}.events = epochs_event;


    % mark outliers and remove their data
    outlier_indx1 = isoutlier(epochs_event(:, 2));
    outlier_indx2 = isoutlier(epochs_event(:, 3));
    outlier_indx  = or(outlier_indx1, outlier_indx2);

    Subject_Force_Angle{sub, 2}.time(outlier_indx) = [];
    Subject_Force_Angle{sub, 2}.force(outlier_indx) = [];
    Subject_Force_Angle{sub, 2}.angle(outlier_indx) = [];
    Subject_Force_Angle{sub, 2}.pressure(outlier_indx) = [];
    Subject_Force_Angle{sub, 2}.trial(outlier_indx) = [];
    Subject_Force_Angle{sub, 2}.score(outlier_indx) = [];
    Subject_Force_Angle{sub, 2}.events(outlier_indx, :) = [];

    warpto_subjects(sub, :) = ...
        [1, median(Subject_Force_Angle{sub, 2}.events(:, 2)), ...
            median(Subject_Force_Angle{sub, 2}.events(:, 3))];
end


roundNear = 50; % round numbers to the closest multiple of this value
warpingvalues = round(median(warpto_subjects)/roundNear)*roundNear;
warpingvalues = warpingvalues + [1, 0, 0];
% warpingvalues = [warpingvalues(1:2), warpingvalues(2)*2-1];


%% Do the warping
Flx_L = warpingvalues(2);
Ext_L = warpingvalues(3)-warpingvalues(2);
Subject_Force_Angle_warped = Subject_Force_Angle;
for sub = 1:length(subject_list)
    
    epochs_N     = length(Subject_Force_Angle{sub, 2}.force);
    epochs_force = Subject_Force_Angle{sub, 2}.force;
    epochs_angle = Subject_Force_Angle{sub, 2}.angle;
    epochs_time  = Subject_Force_Angle{sub, 2}.time;
    epochs_event = Subject_Force_Angle{sub, 2}.events;
    
    
    Subject_Force_Angle_warped{sub, 2}.force = [];
    Subject_Force_Angle_warped{sub, 2}.angle = [];
    Subject_Force_Angle_warped{sub, 2}.time  = [];
    for i = 1:epochs_N
        
        t = epochs_time{i};
        % t = t - t(1);
        % t = t/t(end);
        f = epochs_force{i};
        a = epochs_angle{i};
        event = epochs_event(i, :);
       
        t_new_Flx = linspace(t(1), t(event(2)), Flx_L);
        % f_warped_Flx = interp1(t(1:event(2)), f(1:event(2)), ...
        %     t_new_Flx, "linear");

        t_new_Ext = linspace(t(event(2)), t(end), Ext_L+1);
        % f_warped_Ext = interp1(t(event(2)+1:end), f(event(2)+1:end), ...
        %     t_new_Ext, "linear");
        
        t_new     = [t_new_Flx, t_new_Ext(2:end)];

        % f_warped = [f_warped_Flx, f_warped_Ext];
        f_warped = interp1(t, f, t_new, "linear"); 
        a_warped = interp1(t, a, t_new, "linear");
        
        Subject_Force_Angle_warped{sub, 2}.force = cat(1, ...
            Subject_Force_Angle_warped{sub, 2}.force, f_warped);
        Subject_Force_Angle_warped{sub, 2}.angle = cat(1, ...
            Subject_Force_Angle_warped{sub, 2}.angle, a_warped);
        
        
    end

   
    % Subject_Force_Angle_warped{sub, 2}.warpingvalues = [1, ...
    %     warpingvalues(2), warpingvalues(3)];
    Subject_Force_Angle_warped{sub, 2}.warpingvalues = warpingvalues;

end


%% Save the data
save(fullfile(current_path, 'Subjects_Force_Angle_warped'), ...
    'Subject_Force_Angle_warped')


%% Initial look at the data
% -------------------------------------------------------------------------
% ---- Plot force sensor data over time per subject 
% Get monitor information
monitors = get(0, 'MonitorPositions');

fig = figure('name', ['Force data epochs per pressure'], ...
    'InvertHardcopy', 'off', 'PaperType', 'a2', ...
    'PaperOrientation', 'landscape', ...
    'Resize', 'off');


% For second monitor (row 2), add drawnow before setting position
drawnow;  % Let MATLAB finish drawing on primary monitor first
pause(0.1);  % Short pause helps

% Now set position on second monitor
% set(gcf, 'Position', monitors(1, :));  % Use entire second monitor

set(fig, 'Position', [monitors(1,1)+50, monitors(1,2)+600, 1500, 700]);  % Use entire second monitor

P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
colors = [P1_color; P3_color; P6_color];


ax = gobjects(length(subject_list), 1);  % Preallocate axes array
th = gobjects(length(subject_list), 1);  % Preallocate titles 




epochs_line_alpha = 0.1*[1; 1; 1];
epochs_color = [colors, epochs_line_alpha];
pressure_conditions = [1, 3, 6];
for sub = 1:length(subject_list)
    ax(sub) = subplot(2, 3, sub); hold on;
    for p = 1:3

        pressure = Subject_Force_Angle_warped{sub, 2}.pressure;
        signal = Subject_Force_Angle_warped{sub, 2}.force;
        signal = signal(pressure == pressure_conditions(p), :);
        
        % first_data = signal(:, 1);
        % reject_these = first_data > 25; % value of 25 was selected visually
        % signal = signal(~reject_these, :);

        h = plot(1:warpingvalues(3), signal', ...
            'Color', epochs_color(p, :));
       
    end
    th(sub) = title(['Subject ', num2str(subject_list(sub))], ...
        'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 14);
end


ylimit_max = 0;
ylimit_min = 0;
for sub = 1:length(subject_list)
    ylimit = get(ax(sub), 'YLim');
    ylimit_max = max(ylimit_max, ylimit(2));
    ylimit_min = min(ylimit_min, ylimit(1));
end

for sub = 1:length(subject_list)
    set(ax(sub), 'YLim', [ylimit_min, ylimit_max], ...
        'XLim', [warpingvalues(1)+1 warpingvalues(3)]);
    set(ax(sub), 'XTick', warpingvalues + [1, 0, 0], ...
        'XTickLabel', {'0', '50', '100'})
    xlabel(ax(sub), 'Cycle (%)')
    ylabel(ax(sub), 'Force (N)')
    set(ax(sub), 'FontSize', 16)
end


%% For subject 12 the situation is a bit different. It seems that the force
% sensor started malfunctioning from subject 11 and at subject 12 after two
% sessions it stoped working. The horizontal line in the force-cycle plot
% in subject 12 shows the wrong data at sessions 3 and 4. So for subject 12
% only the first two sessions are considered.


% Initial look at the data
% -------------------------------------------------------------------------
% ---- Plot force sensor data over time per subject 
% Get monitor information
monitors = get(0, 'MonitorPositions');
fig = figure('name', ['Cleaned Force data epochs per pressure'], ...
    'InvertHardcopy', 'off', 'PaperType', 'a2', ...
    'PaperOrientation', 'landscape', ...
    'Resize', 'off');

% For second monitor (row 2), add drawnow before setting position
drawnow;  % Let MATLAB finish drawing on primary monitor first
pause(0.1);  % Short pause helps

% Now set position on second monitor
% set(gcf, 'Position', monitors(1, :));  % Use entire second monitor

set(fig, 'Position', [monitors(1,1)+50, monitors(1,2)+600, 1500, 700]);  % Use entire second monitor

P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
colors = [P1_color; P3_color; P6_color];


ax = gobjects(length(subject_list), 1);  % Preallocate axes array
th = gobjects(length(subject_list), 1);  % Preallocate titles 




epochs_line_alpha = 0.1*[1; 1; 1];
epochs_color = [colors, epochs_line_alpha];
pressure_conditions = [1, 3, 6];
for sub = 1:length(subject_list)
    ax(sub) = subplot(2, 3, sub); hold on;
    for p = 1:3

        pressure = Subject_Force_Angle_warped{sub, 2}.pressure;
        signal = Subject_Force_Angle_warped{sub, 2}.force;
        signal = signal(pressure == pressure_conditions(p), :);
        
        first_data = signal(:, 1);
        reject_these = first_data > 25; % value of 25 was selected visually
        signal = signal(~reject_these, :);

        h = plot(warpingvalues(1)+1:warpingvalues(3), signal', ...
            'Color', epochs_color(p, :));
       
    end
    th(sub) = title(['Subject ', num2str(subject_list(sub))], ...
        'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 14);
end


ylimit_max = 0;
ylimit_min = 0;
for sub = 1:length(subject_list)
    ylimit = get(ax(sub), 'YLim');
    ylimit_max = max(ylimit_max, ylimit(2));
    ylimit_min = min(ylimit_min, ylimit(1));
end

for sub = 1:length(subject_list)
    set(ax(sub), 'YLim', [ylimit_min, ylimit_max], ...
        'XLim', [warpingvalues(1)+1 warpingvalues(3)]);
    set(ax(sub), 'XTick', warpingvalues+[1, 0, 0], ...
        'XTickLabel', {'0', '50', '100'})
    xlabel(ax(sub), 'Cycle (%)')
    ylabel(ax(sub), 'Force (N)')
    set(ax(sub), 'FontSize', 16)
end



for sub = 1:length(subject_list)
    axes(ax(sub)); hold on;

    for p = 1:3

        pressure = Subject_Force_Angle_warped{sub, 2}.pressure;
        signal = Subject_Force_Angle_warped{sub, 2}.force;
        signal = signal(pressure == pressure_conditions(p), :);

        first_data = signal(:, 1);
        reject_these = first_data > 25; % value of 25 was selected visually
        signal = signal(~reject_these, :);
        
        median_force = double(median(signal, 1));
        
        plot(warpingvalues(1)+1:warpingvalues(3), median_force, ...
            'Color', colors(p,:)*0.6, 'LineWidth', 2);
    end
end


%% Removing the non-typical epochs and then plotting again the force data
% Initial look at the data
% -------------------------------------------------------------------------
% ---- Plot force sensor data over time per subject 
% Get monitor information
monitors = get(0, 'MonitorPositions');
fig = figure('name', ['Cleaned Force data epochs per pressure'], ...
    'InvertHardcopy', 'off', 'PaperType', 'a2', ...
    'PaperOrientation', 'landscape', ...
    'Resize', 'off');

% For second monitor (row 2), add drawnow before setting position
drawnow;  % Let MATLAB finish drawing on primary monitor first
pause(0.1);  % Short pause helps

% Now set position on second monitor
% set(gcf, 'Position', monitors(1, :));  % Use entire second monitor

set(fig, 'Position', [monitors(1,1)+50, monitors(1,2)+600, 1500, 700]);  % Use entire second monitor

P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
colors = [P1_color; P3_color; P6_color];


ax = gobjects(length(subject_list), 1);  % Preallocate axes array
th = gobjects(length(subject_list), 1);  % Preallocate titles


clean_Force_angle = Subject_Force_Angle_warped;
for sub = 1:length(subject_list)

    clean_Force_angle{sub, 2}.angle = [];
    clean_Force_angle{sub, 2}.force = [];
    clean_Force_angle{sub, 2}.pressure = [];
    clean_Force_angle{sub, 2}.score = [];
    clean_Force_angle{sub, 2}.events = [];
    clean_Force_angle{sub, 2}.trial = [];
    

    ax(sub) = subplot(2, 3, sub); hold on;
    for p = 1:3

        pressure = Subject_Force_Angle_warped{sub, 2}.pressure;
        idx = pressure == pressure_conditions(p);
        
        angle  = Subject_Force_Angle_warped{sub, 2}.angle;
        signal = Subject_Force_Angle_warped{sub, 2}.force;
        signal = signal(idx, :);
        angle  = angle(idx, :);
        
        first_data = signal(:, 1);
        reject_these = first_data > 25; % value of 25 was selected visually
        signal = signal(~reject_these, :);
        angle  = angle(~reject_these, :);

        median_force = double(median(signal, 1));

        rms_err_median = ...
            rms( signal - repmat(median_force, size(signal, 1), 1) , 2);

        rms_outlier = isoutlier(rms_err_median, "mean", ...
            'ThresholdFactor', 3);
        % sum(rms_outlier)
        signal = signal(~rms_outlier, :);
        angle  = angle(~rms_outlier, :);

        min_column = min(signal, [], 2);
        signal = signal - repmat(min_column, 1, size(signal, 2));
        % signal(signal < 5) = 0; %%%%%%% important to zero less than 5N

        % store the cleaned data
        clean_Force_angle{sub, 2}.angle = cat(1, ...
            clean_Force_angle{sub, 2}.angle, signal);
        clean_Force_angle{sub, 2}.force = cat(1, ...
            clean_Force_angle{sub, 2}.force, signal);
        clean_Force_angle{sub, 2}.pressure = cat(1, ...
            clean_Force_angle{sub, 2}.pressure, ...
            repmat(pressure_conditions(p), size(signal, 1), 1));
        % clean_Force_angle{sub, 2}.score = [];
        % clean_Force_angle{sub, 2}.events = [];
        % clean_Force_angle{sub, 2}.trial = [];

        h = plot(warpingvalues(1):warpingvalues(3), signal', ...
            'Color', epochs_color(p, :));
       
    end
    th(sub) = title(['Subject ', num2str(subject_list(sub))], ...
        'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 14);
    
end


ylimit_max = 0;
ylimit_min = 0;
for sub = 1:length(subject_list)
    ylimit = get(ax(sub), 'YLim');
    ylimit_max = max(ylimit_max, ylimit(2));
    ylimit_min = min(ylimit_min, ylimit(1));
end

for sub = 1:length(subject_list)
    set(ax(sub), 'YLim', [ylimit_min, ylimit_max], ...
        'XLim', [warpingvalues(1) warpingvalues(3)]);
    set(ax(sub), 'XTick', warpingvalues, 'XTickLabel', {'0', '50', '100'})
    xlabel(ax(sub), 'Cycle (%)')
    ylabel(ax(sub), 'Force (N)')
    set(ax(sub), 'FontSize', 16)
end


%% Identifying the PAM engagement moments
% Note that due to friction between the force sensor guide device we see
% that force does not drop to zero at the disengagement moment which should
% be the symmetry of PAM engagement to the 50% of the cycle. So I do
% consider this symmetric behaviour as the movement is periodic and is
% designed to be symmetric around the 50% of the cycle. Then, I calculate
% the PAM engament and then for schematic disengagement evevnt I do the
% following:
% disengament_event(%) = 50% + (50% - engagement_event(%))

% for identifying the engagement event I use the numeric differential and
% the first moment we have a possitive diff is the PAM_engage event

monitors = get(0, 'MonitorPositions');
fig = figure('name', ['Cleaned Force data with PAM engagement'], ...
    'InvertHardcopy', 'off', 'PaperType', 'a2', ...
    'PaperOrientation', 'landscape', ...
    'Resize', 'off');

% For second monitor (row 2), add drawnow before setting position
drawnow;  % Let MATLAB finish drawing on primary monitor first
pause(0.1);  % Short pause helps

% Now set position on second monitor
% set(gcf, 'Position', monitors(1, :));  % Use entire second monitor

set(fig, 'Position', [monitors(1,1)+50, monitors(1,2)+600, 1500, 700]);  % Use entire second monitor

P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
colors = [P1_color; P3_color; P6_color];


ax = gobjects(length(subject_list), 1);  % Preallocate axes array
th = gobjects(length(subject_list), 1);  % Preallocate titles


thresholds = [1.5, 2, 1.5, 2, 2, 1.8];
for sub = 1:length(subject_list)
    
    ax(sub) = subplot(2, 3, sub); hold on;
    for p = [1, 2, 3]

        pressure = clean_Force_angle{sub, 2}.pressure;
        idx = pressure == pressure_conditions(p);
       
        signal = clean_Force_angle{sub, 2}.force;
        signal(signal < thresholds(sub)) = 0;
        signal = signal(idx, :);

        x = warpingvalues(1):warpingvalues(3);
        h1 = fill([x, fliplr(x)], ...
             [mean(signal, 1) + std(signal, 0, 1), ...
              fliplr( mean(signal, 1) - std(signal, 0, 1) )], ...
              colors(p, :));
        h1.EdgeColor = "none";
        h1.FaceAlpha = 0.5;

        h = plot(x, mean(signal, 1), ...
            'Color', colors(p, :)*1, 'LineWidth', 3);

    end

    th(sub) = title(['Subject ', num2str(subject_list(sub))], ...
        'FontName', 'Arial', 'FontWeight', 'bold', 'FontSize', 14);
    
end


ylimit_max = 0;
ylimit_min = 0;
for sub = 1:length(subject_list)
    ylimit = get(ax(sub), 'YLim');
    ylimit_max = max(ylimit_max, ylimit(2));
    ylimit_min = min(ylimit_min, ylimit(1));
end

for sub = 1:length(subject_list)
    set(ax(sub), 'YLim', [0, ylimit_max], ...
        'XLim', [warpingvalues(1) warpingvalues(3)]);
    set(ax(sub), 'XTick', warpingvalues, 'XTickLabel', {'0', '50', '100'})
    xlabel(ax(sub), 'Cycle (%)')
    ylabel(ax(sub), 'Force (N)')
    set(ax(sub), 'FontSize', 16)
end



PAM_engagement = zeros(length(subject_list), 3);
for sub = 1:length(subject_list)
    
    axes(ax(sub)); hold on;
    for p = [1, 2, 3]

        pressure = clean_Force_angle{sub, 2}.pressure;
        idx = pressure == pressure_conditions(p);
        
        % forces less than 5 Newton to zero for detecting PAM engagement
        signal = clean_Force_angle{sub, 2}.force;
        signal(signal < thresholds(sub)) = 0;
        
        force_diff = diff(signal(idx, :), [], 2);
        [~, first_pos_idx] = max(force_diff > 0, [], 2);
        first_pos_idx = first_pos_idx(~isoutlier(first_pos_idx, "mean", 1));
        mean_PAM_engagement = mean(first_pos_idx);
        std_PAM_engagement = std(first_pos_idx, 0);
        
        PAM_engagement(sub, p) = mean_PAM_engagement;

        x = [mean_PAM_engagement - std_PAM_engagement, ...
             mean_PAM_engagement + std_PAM_engagement, ...
             mean_PAM_engagement + std_PAM_engagement, ...
             mean_PAM_engagement - std_PAM_engagement];
        y = [ylimit_max, ylimit_max, 0, 0];
        h3 = fill(x, y, colors(p, :));
        h3.EdgeColor = "none";
        h3.FaceAlpha = 0.2;

        xline(mean_PAM_engagement, 'Color', colors(p, :)*0.7, ...
            'LineStyle', '--', 'LineWidth', 0.5)


        % % PAM disengagement
        % x = 100 - ...
        %     [mean_PAM_engagement - std_PAM_engagement, ...
        %      mean_PAM_engagement + std_PAM_engagement, ...
        %      mean_PAM_engagement + std_PAM_engagement, ...
        %      mean_PAM_engagement - std_PAM_engagement];
        % y = [ylimit_max, ylimit_max, 0, 0];
        % h3 = fill(x, y, colors(p, :));
        % h3.EdgeColor = "none";
        % h3.FaceAlpha = 0.2;
        % 
        % xline(100 - mean_PAM_engagement, 'Color', colors(p, :)*0.7, ...
        %     'LineStyle', '--', 'LineWidth', 0.5)

    end

end


for sub = 1:length(subject_list)
    axes(ax(sub)); 
    Line1 = sprintf('P1 PAM engagement at %1.0f%%', ...
        round(PAM_engagement(sub, 1)));
    Line2 = sprintf('P3 PAM engagement at %1.0f%%', ...
        round(PAM_engagement(sub, 2)));
    Line3 = sprintf('P6 PAM engagement at %1.0f%%', ...
        round(PAM_engagement(sub, 3)));

    text(0.99, 0.99, {Line1, Line2, Line3}, ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'right', ...
    'VerticalAlignment', 'top', ...
    'FontSize', 10);
end

% round(mean(PAM_engagement, 1))