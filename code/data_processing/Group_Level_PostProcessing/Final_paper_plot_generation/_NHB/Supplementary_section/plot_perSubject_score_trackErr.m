clc
clear


%% Add paths
addpath(genpath('D:\Morteza\MyProjects\ANSYMB2024\Code'))
addpath(genpath('D:\Morteza\LSL\xdf-Matlab-master'));

EEGLAB_path = 'D:\Morteza\Toolboxes\EEGLAB\eeglab2026.0.0';
data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
trials_epoched_path = [data_path, '6_Trials_Info_and_Epoched_data\'];
exp_analysis_path = [data_path, '9_EXP_Analysis\'];

%processing_path = 'D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab\data_processing\';
%rawdata_path = [data_path, '0_source_data\'];
%rawEEGLAB_path = [data_path, '2_raw-EEGLAB\']; 
%epoched_EEG_path = [data_path, '5_single-subject-EEG-analysis\', ...
    % 'timewarp_test\Epoched_data'];
%cleanedICA_EEG_path = [data_path, '5_single-subject-EEG-analysis\'];


% %% check - number of trials in Trials_Info and epoched structure should be the same
% subject_list = 5:18;
% subjects_need_review = [];
% for i = 1:numel(subject_list)
%     subject = subject_list(i);
%     cd([trials_epoched_path, 'sub-', num2str(subject)])
%     load("Epochs_Trial_based.mat");
%     N_epoched = numel(Epochs_Trial_based);
%     load("Trials_Info.mat");
%     N_TrialsInfo = numel(Trials_Info);
% 
%     if N_epoched ~= N_TrialsInfo
%         subjects_need_review = [subjects_need_review, subject_list(i)]
%     end
% 
% end



%% Create the data structure holding the percieved difficulty scores per trial
subject_list = 5:18;

%%% Note:
%        runnig this code takes a while. Just load the saved
%        All_scores_trackErr.mat file instead!

% All_scores_trackErr = struct('P1', [], 'P3', [], 'P6', []);
% 
% for i = 1:numel(subject_list)
%     subject = subject_list(i);
% 
%     cd([exp_analysis_path, 'sub-', num2str(subject)])
%     load("KneeTorque_ForceSensor_data.mat");
% 
%     scores = cellfun(@(x) x.Score, Knee_Torque_Force_Sensor, 'UniformOutput', true);
%     pressures = cellfun(@(x) x.Pressure, Knee_Torque_Force_Sensor, 'UniformOutput', true);
% 
% 
%     cd([trials_epoched_path, 'sub-', num2str(subject)])
%     load("Epochs_Trial_based.mat")
% 
% 
%     if numel(Epochs_Trial_based) == numel(pressures)
%         encoder_angle = cellfun(@(x) x.EXP_stream.Encoder_angle, ...
%             Epochs_Trial_based, 'UniformOutput', false);
%         ref_angle = cellfun(@(x) x.EXP_stream.Ref_angle, ...
%             Epochs_Trial_based, 'UniformOutput', false);
%         trackErr_RMSE = cellfun(@(x,y) rmse(x, y), encoder_angle, ref_angle, ...
%             'UniformOutput', true);
%     end
% 
% 
%     pressures(scores == 0) = [];
%     encoder_angle(scores == 0) = [];
%     ref_angle(scores == 0) = [];
%     trackErr_RMSE(scores == 0) = [];
%     scores(scores == 0) = [];
% 
%     All_scores_trackErr(i).P1.score = scores(pressures == 1);
%     All_scores_trackErr(i).P1.encoder_angle = encoder_angle(pressures == 1);
%     All_scores_trackErr(i).P1.ref_angle = ref_angle(pressures == 1);
%     All_scores_trackErr(i).P1.trackErr_RMSE = trackErr_RMSE(pressures == 1);
% 
%     All_scores_trackErr(i).P3.score = scores(pressures == 3);
%     All_scores_trackErr(i).P3.encoder_angle = encoder_angle(pressures == 3);
%     All_scores_trackErr(i).P3.ref_angle = ref_angle(pressures == 3);
%     All_scores_trackErr(i).P3.trackErr_RMSE = trackErr_RMSE(pressures == 3);
% 
%     All_scores_trackErr(i).P6.score = scores(pressures == 6);
%     All_scores_trackErr(i).P6.encoder_angle = encoder_angle(pressures == 6);
%     All_scores_trackErr(i).P6.ref_angle = ref_angle(pressures == 6);
%     All_scores_trackErr(i).P6.trackErr_RMSE = trackErr_RMSE(pressures == 6);
% 
% end
% save("All_scores_trackErr.mat", "All_scores_trackErr", '-mat');

load("All_scores_trackErr.mat")

% change the RMSE to Mean Absolute Error


%% Main plot section
allData = All_scores_trackErr;

%% ---------------------- 2. CONFIG --------------------------------------
conds       = {'P1','P3','P6'};
vars        = {'score','trackErr_RMSE'};
plotType    = {'countgrid','violin'};
xLabels     = {'Perceived difficulty score', 'Tracking error RMSE (deg)'};
blockTitles = {'Perceived difficulty', 'Tracking error'};
fileName    = 'Fig_score_trackErr_combined.pdf';
 
ratingVals  = 1:10;             % full rating scale
xTickVals   = {1:3:10, []};     % per variable; [] -> automatic
 
P1_color = [  1 115 178]/255;
P3_color = [222 143   5]/255;
P6_color = [148  73  92]/255;
condColors = [P1_color; P3_color; P6_color];
 
showCondYTicks = false;   % true -> P1/P3/P6 as y tick labels, first column
                          %         of each block (raise marginL/blockGap)
 
% --- figure size --------------------------------------------------------
% Portrait. Nature Communications: 180 mm max width, 170 mm max height.
figWidth_cm  = 17.0;
figHeight_cm = 16.0;
fontSize     = 6;
fontName     = 'Arial';
 
% --- LAYOUT: fractions of the figure ------------------------------------
nRowsG   = 7;      % subject rows
nColsB   = 2;      % columns per block
nBlocks  = numel(vars);
marginL  = 0.048;  % no numeric y ticks now, so this can be tight
marginR  = 0.010;
marginT  = 0.055;  % block headers
marginB  = 0.135;  % x tick labels + axis label + key
gapH     = 0.022;  % between columns inside a block
gapV     = 0.038;  % between subject rows
blockGap = 0.070;  % between the two blocks
 
% --- appearance ---------------------------------------------------------
maxMarkerArea  = 34;    % points^2; x spacing between ratings is the limit
showMedianLink = true;
medianLinkCol  = [0.60 0.60 0.60];
titleGap_pt    = 2;
halfWidth      = 0.34;  % violin half-thickness, in condition-slot units
violinAlpha    = 0.45;
extendTails    = false;
xPadFrac       = 0.05;
 
nSub = numel(allData);
axW  = (1 - marginL - marginR - blockGap - nBlocks*(nColsB-1)*gapH) ...
       / (nBlocks*nColsB);
axH  = (1 - marginT - marginB - (nRowsG-1)*gapV) / nRowsG;
blockW = nColsB*axW + (nColsB-1)*gapH;
 
fig = figure('Units','centimeters', ...
             'Position',[2 2 figWidth_cm figHeight_cm], ...
             'Color','w');
 
%% ---------------------- 3. BLOCKS --------------------------------------
for v = 1:nBlocks
 
    isGrid    = strcmp(plotType{v}, 'countgrid');
    blockLeft = marginL + (v-1)*(blockW + blockGap);
 
    % --- scale shared across ALL subjects in this block -----------------
    if isGrid
        maxProp = 0;
        for s = 1:nSub
            for k = 1:numel(conds)
                y = allData(s).(conds{k}).(vars{v});
                y = y(isfinite(y));
                if isempty(y), continue; end
                cnt = histcounts(y, [ratingVals-0.5, ratingVals(end)+0.5]);
                maxProp = max(maxProp, max(cnt)/sum(cnt));
            end
        end
        xLim = [ratingVals(1)-0.7, ratingVals(end)+0.7];
    else
        pooled = [];
        for s = 1:nSub
            for k = 1:numel(conds)
                y = allData(s).(conds{k}).(vars{v});
                pooled = [pooled; y(:)];                             %#ok<AGROW>
            end
        end
        pooled = pooled(isfinite(pooled));
        pad    = xPadFrac * range(pooled);
        xLim   = [min(pooled)-pad, max(pooled)+pad];
    end
 
    % --- block header ---------------------------------------------------
    annotation(fig, 'textbox', ...
        [blockLeft, 1-marginT+0.012, blockW, 0.035], ...
        'String', blockTitles{v}, 'FontName', fontName, ...
        'FontSize', fontSize+1, 'FontWeight','bold', 'EdgeColor','none', ...
        'HorizontalAlignment','center', 'VerticalAlignment','middle');
 
    % --- shared x axis label, centred under the block -------------------
    annotation(fig, 'textbox', ...
        [blockLeft, marginB-0.075, blockW, 0.030], ...
        'String', xLabels{v}, 'FontName', fontName, ...
        'FontSize', fontSize, 'EdgeColor','none', ...
        'HorizontalAlignment','center', 'VerticalAlignment','middle');
 
    % --- panels ---------------------------------------------------------
    for s = 1:nSub
 
        j = ceil(s / nRowsG);            % column within the block
        r = s - (j-1)*nRowsG;            % row, 1-based from the top
 
        pos = [ blockLeft + (j-1)*(axW + gapH), ...
                1 - marginT - r*axH - (r-1)*gapV, ...
                axW, axH ];
 
        ax = subplot('Position', pos);
        hold(ax,'on');
 
        med = nan(1, numel(conds));
 
        for k = 1:numel(conds)
            y = allData(s).(conds{k}).(vars{v});
            y = y(:);
            y = y(isfinite(y));
            if isempty(y), continue; end
 
            if isGrid
                localCountGridH(ax, k, y, condColors(k,:), ratingVals, ...
                                maxProp, maxMarkerArea);
            else
                localViolinH(ax, k, y, condColors(k,:), halfWidth, ...
                             extendTails, violinAlpha);
            end
            med(k) = median(y);
        end
 
        if isGrid && showMedianLink
            plot(ax, med, 1:numel(conds), '-', ...
                 'Color', medianLinkCol, 'LineWidth', 0.4);
            plot(ax, med, 1:numel(conds), '|', ...
                 'Color', [0.25 0.25 0.25], 'MarkerSize', 3.5, 'LineWidth', 0.7);
        end
 
        xlim(ax, xLim);
        ylim(ax, [0.4 numel(conds)+0.6]);
        % ax.YDir = 'reverse';             % P1 at the top, P6 at the bottom
 
        if ~isempty(xTickVals{v}), ax.XTick = xTickVals{v}; end
        ax.FontName   = fontName;
        ax.FontSize   = fontSize;
        ax.LineWidth  = 0.5;
        ax.TickDir    = 'out';
        ax.TickLength = [0.035 0.035];
        box(ax,'off');
 
        % x tick labels: bottom row of the block only
        if r ~= nRowsG
            ax.XTickLabel = {};
        end
 
        % conditions on y: labelled only if requested, first column only
        if showCondYTicks && j == 1
            ax.YTick      = 1:numel(conds);
            ax.YTickLabel = conds;
        else
            ax.YTick = [];
        end
 
        th = title(ax, sprintf('S%d', s), 'FontWeight','bold', ...
                   'FontName', fontName, 'FontSize', fontSize);
        th.Units = 'points';
        th.Position(2) = th.Position(2) + titleGap_pt;
    end
end
 
%% ---------------------- 4. KEY -----------------------------------------
axK = subplot('Position', [marginL 0.008 (1-marginL-marginR) 0.040]);
hold(axK,'on');

text(axK, 0.00, 1, 'Marker area = share of that condition''s trials', ...
     'HorizontalAlignment','left', 'FontName', fontName, ...
     'FontSize', fontSize, 'Color',[0.30 0.30 0.30]);

text(axK, 0.615, 1, 'Pressure:', 'HorizontalAlignment','left', ...
     'FontName', fontName, 'FontSize', fontSize, 'Color',[0.30 0.30 0.30]);

dotX = [0.740 0.845 0.950];
for k = 1:numel(conds)
    scatter(axK, dotX(k), 1, 22, 'MarkerFaceColor', condColors(k,:), ...
            'MarkerEdgeColor','none');
    text(axK, dotX(k)+0.020, 1, conds{k}, 'HorizontalAlignment','left', ...
         'FontName', fontName, 'FontSize', fontSize, 'Color',[0.30 0.30 0.30]);
end

xlim(axK,[0 1]); ylim(axK,[0.5 1.5]); axis(axK,'off');
 
%% ---------------------- 5. EXPORT --------------------------------------
exportgraphics(fig, fileName, 'ContentType','vector', ...
               'BackgroundColor','white');
 
 
%% ======================= LOCAL FUNCTIONS ===============================
 
function localCountGridH(ax, yCenter, y, col, vals, maxProp, maxArea)
% A row of bubbles at y = yCenter, one per rating value that occurred.
% scatter's SizeData is marker AREA in points^2, so making it proportional
% to the share of trials gives an area encoding directly. Fully opaque:
% the markers sit on a lattice and never overlap, and transparency would
% trigger the vector-export warning for nothing.
 
    cnt  = histcounts(y, [vals-0.5, vals(end)+0.5]);
    p    = cnt / sum(cnt);
    keep = p > 0;
    if ~any(keep), return; end
 
    sz = p(keep) / maxProp * maxArea;
    scatter(ax, vals(keep), yCenter*ones(1, sum(keep)), sz, ...
            'MarkerFaceColor', col, 'MarkerEdgeColor', 'none');
end
 
 
function localViolinH(ax, yCenter, y, col, halfWidth, extendTails, alph)
% Horizontal violin centred on y = yCenter, with median marker and IQR bar.
% Continuous data only. Fill colour is pre-blended onto white rather than
% drawn with FaceAlpha: identical on the page, no transparency in the PDF.
 
    if numel(y) < 3
        if ~isempty(y)
            plot(ax, y, yCenter*ones(size(y)), '.', 'Color', col, ...
                 'MarkerSize', 4);
        end
        return
    end
 
    [f, xi] = localKDE(y, extendTails);
    if max(f) > 0
        f = f / max(f) * halfWidth;
    end
 
    fillCol = alph*col + (1-alph)*[1 1 1];
    patch(ax, [xi, fliplr(xi)], [yCenter + f, fliplr(yCenter - f)], fillCol, ...
          'FaceAlpha', 1, 'EdgeColor', col, 'LineWidth', 0.5);
 
    q  = localQuantile(y, [0.25 0.50 0.75]);
    gr = [0.25 0.25 0.25];
    plot(ax, [min(y) max(y)], [yCenter yCenter], '-', 'Color', gr, 'LineWidth', 0.4);
    plot(ax, q([1 3]),        [yCenter yCenter], '-', 'Color', gr, 'LineWidth', 1.6);
    plot(ax, q(2), yCenter, 'o', 'MarkerSize', 2.2, 'MarkerFaceColor','w', ...
         'MarkerEdgeColor', gr, 'LineWidth', 0.4);
end
 
 
function [f, xi] = localKDE(y, extendTails)
% Gaussian KDE, Silverman's rule-of-thumb bandwidth (Silverman 1986, eq 3.31).
% xi is the evaluation grid along the VALUE axis, which is x here.
 
    y = y(:);
    n = numel(y);
 
    sd  = std(y);
    iqr = diff(localQuantile(y, [0.25 0.75]));
    sig = min(sd, iqr/1.349);
    if ~isfinite(sig) || sig <= 0, sig = sd;  end
    if ~isfinite(sig) || sig <= 0, sig = eps; end
 
    h = 0.9 * sig * n^(-1/5);
 
    if extendTails
        lo = min(y) - 1.5*h;   hi = max(y) + 1.5*h;
    else
        lo = min(y);           hi = max(y);
    end
    if hi <= lo, hi = lo + eps; end
 
    xi = linspace(lo, hi, 200);
    f  = zeros(size(xi));
    for k = 1:n
        f = f + exp(-0.5*((xi - y(k))/h).^2);
    end
    f = f / (n * h * sqrt(2*pi));
end
 
 
function q = localQuantile(y, p)
% Linear-interpolation quantiles, matching MATLAB's quantile() convention.
 
    y = sort(y(:));
    n = numel(y);
    if n == 1
        q = repmat(y, size(p));
        return
    end
    pos = ((1:n) - 0.5) / n;
    q   = interp1(pos, y, p, 'linear');
    q(p < pos(1))   = y(1);
    q(p > pos(end)) = y(end);
end