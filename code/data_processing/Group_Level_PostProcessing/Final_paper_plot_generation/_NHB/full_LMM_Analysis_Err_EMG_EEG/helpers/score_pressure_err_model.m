function M2 = score_pressure_err_model(T_clean)

T = T_clean;
M2 = fitlme(T, ...
    'Score ~ 1 + Pressure_cat + Error + (1 + Pressure_cat | Subject_cat)', ...
    'FitMethod','ML');




%% 3-panel figure: Pressure→Error (A), Error↔Score (B), model effect sizes (C)
% Assumptions:
%   T_clean has variables:
%     - Score (numeric)
%     - Error (numeric)
%     - Pressure_cat (categorical; levels include '1','3','6' or 1,3,6)
%     - Subject_cat (categorical)
%   You already fit M2:
%     M2 = fitlme(T_clean,'Score ~ 1 + Error + Pressure_cat + (1 + Pressure_cat | Subject_cat)','FitMethod','ML');



%% --- Panel C prep: effect sizes from M2 ---
% Extract coefficient table
C = M2.Coefficients;  % table with Estimate/SE/tStat/DF/pValue/Lower/Upper

% Helper to fetch coefficient row by name
getCoef = @(nm) C(strcmp(C.Name, nm), :);

% Names depend on MATLAB's encoding of categorical levels. Commonly:
%   'Pressure_cat_3' and 'Pressure_cat_6' (with '1' as reference)
% If your names differ, inspect: disp(C.Name)
rowP3 = getCoef('Pressure_cat_3');
rowP6 = getCoef('Pressure_cat_6');
rowEr = getCoef('Error');

% Error effect expressed over P90–P10(Error)
p10 = prctile(T.Error, 10);
p90 = prctile(T.Error, 90);
dErr = p90 - p10;

dScoreErr = rowEr.Estimate * dErr;
dScoreErr_CI = [rowEr.Lower, rowEr.Upper] * dErr;  % linear propagation

% Pressure effects are already contrasts vs reference level
dScoreP3 = rowP3.Estimate;  dScoreP3_CI = [rowP3.Lower, rowP3.Upper];
dScoreP6 = rowP6.Estimate;  dScoreP6_CI = [rowP6.Lower, rowP6.Upper];

%% --- Build figure ---
fig = figure('Color','w', 'Units', 'pixels'); %, 'Position', [120 120 1220 520]);
t = tiledlayout(fig, 1, 3, 'TileSpacing','loose', 'Padding','loose');
set(fig, 'Position', [100, 1000, 1200, 520])


% =========================
%  Panel 1: Tracking Error vs Pressure
%  =========================

ax1 = nexttile(t,1);
hold(ax1,'on');

% Colors (same as before)
P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255;
cols = [P1_color; P3_color; P6_color];

% Ensure categorical order
T_clean.Pressure_cat = categorical(string(T_clean.Pressure_cat));
T_clean.Pressure_cat = reordercats(T_clean.Pressure_cat, {'1','3','6'});
pressCats = categories(T_clean.Pressure_cat);

% Layout parameters (same as score plot)
dxBox   = -0.10;   % boxplots shifted left
dxSub   = +0.10;   % subject means shifted right
x       = [1 2 3];
jitterSub = 0.06;
rng(9);

nCond = numel(pressCats);

% -------- Layer 1: Boxplots (tracking error) --------
for c = 1:nCond
    y = T_clean.Error(T_clean.Pressure_cat == pressCats{c});
    y = y(~isnan(y) & isfinite(y));

    xPos = x(c) + dxBox;

    % Store existing handles
    oldBox   = findobj(ax1,'Tag','Box');
    oldMed   = findobj(ax1,'Tag','Median');
    oldOut   = findobj(ax1,'Tag','Outliers');
    oldLW    = findobj(ax1,'Tag','Lower Whisker');
    oldUW    = findobj(ax1,'Tag','Upper Whisker');
    oldLAdj  = findobj(ax1,'Tag','Lower Adjacent Value');
    oldUAdj  = findobj(ax1,'Tag','Upper Adjacent Value');

    % Draw boxplot
    boxplot(y, 'Positions', xPos, ...
        'Widths', 0.2, ...
        'Whisker', 1.0, ...
        'Colors', cols(c,:), ...
        'Symbol', '');

    % Identify new handles
    newBox  = setdiff(findobj(ax1,'Tag','Box'), oldBox);
    newMed  = setdiff(findobj(ax1,'Tag','Median'), oldMed);
    newOut  = setdiff(findobj(ax1,'Tag','Outliers'), oldOut);
    newLW   = setdiff(findobj(ax1,'Tag','Lower Whisker'), oldLW);
    newUW   = setdiff(findobj(ax1,'Tag','Upper Whisker'), oldUW);
    newLAdj = setdiff(findobj(ax1,'Tag','Lower Adjacent Value'), oldLAdj);
    newUAdj = setdiff(findobj(ax1,'Tag','Upper Adjacent Value'), oldUAdj);

    % Styling (identical to score plot)
    whiskCol = 0.9 * cols(c,:);
    lwWhisk  = 2;
    lwBox    = 2;
    lwMed    = 2;

    set(newLW,   'LineStyle','-', 'LineWidth', lwWhisk, 'Color', whiskCol);
    set(newUW,   'LineStyle','-', 'LineWidth', lwWhisk, 'Color', whiskCol);
    set(newLAdj, 'LineStyle','-', 'LineWidth', lwWhisk, 'Color', whiskCol);
    set(newUAdj, 'LineStyle','-', 'LineWidth', lwWhisk, 'Color', whiskCol);
    set(newMed,  'LineWidth', lwMed,  'Color', whiskCol);
    set(newBox,  'LineWidth', lwBox);
    set(newOut,  'Marker', 'none');

    % Manual fill (alpha)
    for k = 1:numel(newBox)
        Xb = get(newBox(k),'XData');
        Yb = get(newBox(k),'YData');
        patch(Xb, Yb, cols(c,:), ...
            'FaceAlpha', 0.4, ...
            'EdgeColor', whiskCol, ...
            'LineWidth', lwBox);
    end
end

% -------- Compute subject means (Error) --------
subCats = categories(T_clean.Subject_cat);
nSub = numel(subCats);
subjMeanErr = nan(nSub, nCond);

for s = 1:nSub
    for c = 1:nCond
        idx = T_clean.Subject_cat == subCats{s} & ...
              T_clean.Pressure_cat == pressCats{c};
        subjMeanErr(s,c) = mean(T_clean.Error(idx), 'omitnan');
    end
end

% Jitter for subject points
xJit = (rand(nSub,nCond) - 0.5) * 2 * jitterSub;

% -------- Layer 2: Subject trajectories --------
for s = 1:nSub
    ys = subjMeanErr(s,:);
    valid = ~isnan(ys);

    if nnz(valid) >= 2
        xLine = (x(valid) + dxSub) + xJit(s,valid);
        plot(ax1, xLine, ys(valid), '-', ...
            'Color', 0.6*[1 1 1 0.7], 'LineWidth', 0.5);
    end
end

% -------- Layer 3: Subject mean circles --------
for c = 1:nCond
    ys = subjMeanErr(:,c);
    valid = ~isnan(ys);

    xPts = (x(c) + dxSub) + xJit(valid,c);
    edgeCol = 0.9 * cols(c,:);

    scatter(ax1, xPts, ys(valid), 46, 'o', ...
        'MarkerFaceColor', cols(c,:), ...
        'MarkerEdgeColor', edgeCol, ...
        'MarkerFaceAlpha', 0.4, ...
        'LineWidth', 1);
end

% Axis formatting (parallel to score plot)
xlim(ax1, [0.5 nCond+0.5]);
ylim([0 15])



xlh1 = xlabel(ax1, 'Pressure Condition', 'FontWeight','bold');
ylh1 = ylabel(ax1, 'Tracking Error (degree)', 'FontWeight','bold');

xlh1.Units = "normalized";
xlh1.Position(2) = xlh1.Position(2) - 0.08;
ylh1.Units = "normalized";
ylh1.Position(1) = ylh1.Position(1) - 0.1;

set(ax1, 'XTick', x, 'XTickLabel', {'Low','Medium','High'});
set(ax1, 'FontSize', 16, 'Box', 'off');



set(ax1, 'PlotBoxAspectRatio', [1 1.4 1]);



%% =========================
%  Panel 2: Subject means — Score vs Tracking Error
%  =========================

ax2 = nexttile(t,2);
hold(ax2,'on');


% Compute subject × pressure means (reuse if already computed)
% subjMeanErr(s,c)   -> mean Error
% subjMeanScore(s,c) -> mean Score

subjMeanScore = nan(nSub, nCond);
for s = 1:nSub
    for c = 1:nCond
        idx = T_clean.Subject_cat == subCats{s} & ...
              T_clean.Pressure_cat == pressCats{c};
        subjMeanScore(s,c) = mean(T_clean.Score(idx), 'omitnan');
    end
end

% Scatter: one circle per subject × pressure
for c = 1:nCond
    xe = subjMeanErr(:,c);      % mean error
    ys = subjMeanScore(:,c);    % mean score
    valid = ~isnan(xe) & ~isnan(ys);

    edgeCol = 0.9 * cols(c,:);

    scatter(ax2, xe(valid), ys(valid), 52, 'o', ...
        'MarkerFaceColor', cols(c,:), ...
        'MarkerEdgeColor', edgeCol, ...
        'MarkerFaceAlpha', 0.4, ...
        'LineWidth', 1, 'HandleVisibility', 'off');
end

% dummy plot for legend
scatter(ax2, -10, -10, 52, 'o', ...
    'MarkerFaceColor', cols(1,:), ...
    'MarkerEdgeColor', cols(1,:)*0.9, ...
    'MarkerFaceAlpha', 0.4, ...
    'LineWidth', 1);
scatter(ax2, -10, -10, 52, 'o', ...
    'MarkerFaceColor', cols(2,:), ...
    'MarkerEdgeColor', cols(2,:)*0.9, ...
    'MarkerFaceAlpha', 0.4, ...
    'LineWidth', 1);
scatter(ax2, -10, -10, 52, 'o', ...
    'MarkerFaceColor', cols(3,:), ...
    'MarkerEdgeColor', cols(3,:)*0.9, ...
    'MarkerFaceAlpha', 0.4, ...
    'LineWidth', 1);

lgd = legend({' ', ' ','  Subject×Pressure Mean'}, ...
    'Location', 'northeast', 'Orientation', 'horizontal', 'Box', 'off');
lgd.Position(3) = lgd.Position(3)*0.4;
lgd.Position(2) = lgd.Position(2)*0.94;


% xlabel ylabel
xlh2 = xlabel(ax2, sprintf('Tracking Error (degree)'), 'FontWeight','bold');
ylh2 = ylabel(ax2, sprintf('Subjective Rating'), 'FontWeight','bold');

xlh2.Units = "normalized";
xlh2.Position(2) = xlh2.Position(2) - 0.08;
ylh2.Units = "normalized";
ylh2.Position(1) = ylh2.Position(1) - 0.05;


set(ax2, 'FontSize', 16, 'Box', 'off');

xlim(ax2, [0 15]);
% ylim(ax2, [0.5 10.5])
ylim(ax2, [0 10])


set(ax2, 'PlotBoxAspectRatio', [1 1.4 1]);




%% =========================
%  Panel 3: Model-derived effect sizes
%  =========================

ax3 = nexttile(t,3);
hold(ax3,'on');

% Effects 
y   = [dScoreP3, dScoreP6, dScoreErr];
ylo = [dScoreP3_CI(1), dScoreP6_CI(1), dScoreErr_CI(1)];
yhi = [dScoreP3_CI(2), dScoreP6_CI(2), dScoreErr_CI(2)];

xEff = 1:3;

errorbar(ax3, xEff, y, y - ylo, yhi - y, 'o', ...
    'Color','k', ...
    'MarkerFaceColor','k', ...
    'MarkerEdgeColor','k', ...
    'LineWidth', 2.0, ...
    'CapSize', 10);

lgd3 = legend(ax3, {'Value \pm 95% CI'}, 'Box', 'off');


% Tick locations you want to label
ax3.XTick = xEff;

% Multi-line labels (use newline or sprintf)
lbl = {sprintf('Medium\nvs. Low'), sprintf('High\nvs. Low'), sprintf('Error\n(P90-P10)')};

% Hide default tick labels
ax3.XTickLabel = {'', '', ''};

% Draw custom labels (one text object per tick)
yl = ax3.YLim;
yText = yl(1) - 0.02*range(yl);   % push labels slightly below axis

for i = 1:numel(xEff)
    text(ax3, xEff(i), yText, lbl{i}, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','cap', 'FontWeight', 'normal', ...
        'FontSize', 13, 'Rotation', 0);
end


xlim(ax3, [0.7-0.2 3.3+0.2]);
ylim(ax3, [0 8])
set(ax3, 'FontSize', 16, 'Box', 'off');

xlh3 = xlabel('Predictors');
xlh3.FontWeight = 'bold';
ylh3 = ylabel(ax3, 'Predicted \DeltaRating', 'FontWeight','bold');

xlh3.Units = "normalized";
xlh3.Position(2) = xlh3.Position(2) - 0.115;
ylh3.Units = "normalized";
ylh3.Position(1) = ylh3.Position(1) - 0.06;

% pos3 = get(gca, 'Position');
set(ax3, 'PlotBoxAspectRatio', [1 1.4 1]);



end