function M3 = score_pressure_effort_with_mediation_plot(T_clean, mech)
% 3-panel figure:
%   Panel 1: EffortIndex vs Pressure (boxplots + subject means + trajectories)a
%   Panel 2: Subject means scatter: Score vs EffortIndex (Subject × Pressure)
%   Panel 3: Mediation decomposition (stacked % of total effect; medians from mech)
%
% Requires variables in T_clean:
%   - Score (numeric; perceived difficulty, 1 easy – 10 hard)
%   - EffortIndex (numeric)
%   - Error (numeric)  % only used for mediation stacked bar (PropError fields)
%   - Pressure_cat (categorical / convertible to categorical with levels '1','3','6')
%   - Subject_cat (categorical)
%
% mech must contain (fractions 0..1; each as [low, median, high]):
%   PropEffort_3, PropError_3, PropMediated_3
%   PropEffort_6, PropError_6, PropMediated_6
% (If your mech uses PropEffort_* names exactly as shown in your screenshot, this matches.)

T = T_clean;

% Fit full model (optional; not directly needed for plotting Panels 1–3,
% but useful to return and keep consistent with your analysis pipeline)
M3 = fitlme(T, ...
    'Score ~ 1 + Pressure_cat + Error + EffortIndex + (1 + Pressure_cat | Subject_cat)', ...
    'FitMethod','ML');

%% --- Figure layout
fig = figure('Color','w');
tlo = tiledlayout(fig, 1, 4, 'TileSpacing', 'loose', 'Padding', 'loose');
set(fig, 'Position', [1500, 100, 1200*4/3, 520])

% Colors (same as your error plot)
P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255;
cols = [P1_color; P3_color; P6_color];

% Ensure categorical order
T.Pressure_cat = categorical(string(T.Pressure_cat));
T.Pressure_cat = reordercats(T.Pressure_cat, {'1','3','6'});
pressCats = categories(T.Pressure_cat);
nCond = numel(pressCats);

%% =========================
%  Panel 1: EffortIndex vs Pressure (same style as error figure)
%  =========================
ax1 = nexttile(tlo, 1);
% ax1 = subplot(1, 4, 1);
hold(ax1,'on');

dxBox     = -0.10;   % boxplots shifted left
dxSub     = +0.10;   % subject means shifted right
x         = [1 2 3];
jitterSub = 0.06;
rng(9);

% -------- Layer 1: Boxplots (EffortIndex) --------
for c = 1:nCond
    y = T.EffortIndex(T.Pressure_cat == pressCats{c});
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

    % Styling (same as your plot)
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

% -------- Compute subject means (EffortIndex) --------
subCats = categories(T.Subject_cat);
nSub = numel(subCats);
subjMeanEff = nan(nSub, nCond);

for s = 1:nSub
    for c = 1:nCond
        idx = T.Subject_cat == subCats{s} & ...
              T.Pressure_cat == pressCats{c};
        subjMeanEff(s,c) = mean(T.EffortIndex(idx), 'omitnan');
    end
end

% Jitter for subject points
xJit = (rand(nSub,nCond) - 0.5) * 2 * jitterSub;

% -------- Layer 2: Subject trajectories --------
for s = 1:nSub
    ys = subjMeanEff(s,:);
    valid = ~isnan(ys);
    if nnz(valid) >= 2
        xLine = (x(valid) + dxSub) + xJit(s,valid);
        plot(ax1, xLine, ys(valid), '-', ...
            'Color', 0.6*[1 1 1 0.7], 'LineWidth', 0.5);
    end
end

% -------- Layer 3: Subject mean circles --------
for c = 1:nCond
    ys = subjMeanEff(:,c);
    valid = ~isnan(ys);

    xPts = (x(c) + dxSub) + xJit(valid,c);
    edgeCol = 0.9 * cols(c,:);

    scatter(ax1, xPts, ys(valid), 46, 'o', ...
        'MarkerFaceColor', cols(c,:), ...
        'MarkerEdgeColor', edgeCol, ...
        'MarkerFaceAlpha', 0.4, ...
        'LineWidth', 1);
end

% xlabel ylabel
xlh1 = xlabel(ax1, 'Pressure Condition', 'FontWeight','bold');
ylh1 = ylabel(ax1, 'Effort Index (EMG-based)', 'FontWeight','bold');

set(ax1, 'XTick', x, 'XTickLabel', {'Low','Medium','High'});
set(ax1, 'FontSize', 16, 'Box', 'off');

% Sensible y-limits (robust)
ylo = prctile(T.EffortIndex, 1);
yhi = prctile(T.EffortIndex, 99);
pad = 0.15*(yhi-ylo);
ylim(ax1, [ylo-pad, yhi+pad]);
xlim(ax1, [0.5 nCond+0.5]);

xlh1.Units = "normalized";
xlh1.Position(2) = xlh1.Position(2) - 0.05;
ylh1.Units = "normalized";
ylh1.Position(1) = ylh1.Position(1) - 0.08;


set(ax1, 'PlotBoxAspectRatio', [1.2 1.4 1]);


%% =========================
%  Panel 2: Subject means — Score vs EffortIndex (Subject × Pressure)
%  =========================
ax2 = nexttile(tlo, 2);
% ax2 = subplot(1, 4, 2);
hold(ax2,'on');

subjMeanScore = nan(nSub, nCond);
for s = 1:nSub
    for c = 1:nCond
        idx = T.Subject_cat == subCats{s} & ...
              T.Pressure_cat == pressCats{c};
        subjMeanScore(s,c) = mean(T.Score(idx), 'omitnan');
    end
end

for c = 1:nCond
    xe = subjMeanEff(:,c);      % mean EffortIndex
    ys = subjMeanScore(:,c);    % mean Score
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

lgd2 = legend({' ', ' ','  Subject×Pressure Mean'}, ...
    'Location', 'northeast', 'Orientation', 'horizontal', 'Box', 'off');
lgd2.Position(3) = lgd2.Position(3)*0.4;
lgd2.Position(2) = lgd2.Position(2)*0.94;



% xlabel ylabel
% xlabel(ax2, sprintf('Internal Effort (EMG index)\n(Subject × Pressure)'), 'FontWeight','bold');
% ylabel(ax2, sprintf('Percieved Difficulty\n(Subject × Pressure)'), 'FontWeight','bold');
xlh2 = xlabel(ax2, sprintf('Effort Index (EMG-based)'), 'FontWeight','bold');
ylh2 = ylabel(ax2, sprintf('Subjective Rating'), 'FontWeight','bold');
set(ax2, 'FontSize', 16, 'Box', 'off');

% title(ax2, sprintf('Grouped by Subject × Pressure '))

% Match y-range
ylim(ax2, [0 10]);

% Robust x-limits
% xlo = prctile(T.EffortIndex, 2);
% xhi = prctile(T.EffortIndex, 98);
% pad = 0.08*(xhi-xlo);
xlim(ax2, ax1.YLim);


xlh2.Units = "normalized";
xlh2.Position(2) = xlh2.Position(2) - 0.05;
ylh2.Units = "normalized";
% ylh2.Position(1) = ylh2.Position(1) - 0.01;


set(ax2, 'PlotBoxAspectRatio', [1.2 1.4 1]);




%% =========================
%  Panel 3: Stacked bar plot (mediation proportions; medians from mech)
%  =========================
ax3 = nexttile(tlo, 3);
% ax3 = subplot(1, 4, 3);
hold(ax3,'on');


% Medians (2nd element), convert to percent
pEff3 = 100 * mech.PropEffort_3(2);
pErr3 = 100 * mech.PropError_3(2);
pDir3 = 100 * (1 - mech.PropMediated_3(2));

pEff6 = 100 * mech.PropEffort_6(2);
pErr6 = 100 * mech.PropError_6(2);
pDir6 = 100 * (1 - mech.PropMediated_6(2));

Y = [pEff3, pErr3, pDir3;
     pEff6, pErr6, pDir6];


b = bar(ax3, 1:2, Y, 'stacked', 'LineWidth', 1.2);
b(1).FaceColor = [0.25 0.25 0.25];   % Effort-mediated (dark)
b(2).FaceColor = [0.60 0.60 0.60];   % Error-mediated (mid)
b(3).FaceColor = [0.88 0.88 0.88];   % Direct/Other (light)

for k = 1:numel(b)
    b(k).EdgeColor = 'k';
    b(k).LineWidth = 1.2;
end


% Tick locations you want to label
xEff = 1:2;
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
        'FontSize', 16, 'Rotation', 0);
end



lgd = legend(ax3, {' Indirect via EMG',' Indirect via Error',' Direct / Other'}, ...
    'Location','northeastoutside', 'Orientation','vertical', ...
    'Box', 'off');
lgd.Units = "normalized";
lgd.Position(1) = lgd.Position(1) + 0.02;
lgd.Position(2) = lgd.Position(2) - 0.08;


% Optional labels inside segments (0 decimals; <1% for tiny)
for iBar = 1:size(Y,1)
    cum = 0;
    for iSeg = 1:size(Y,2)
        val = Y(iBar,iSeg);
        if val <= 0, continue; end
        yPos = cum + val/2;
        cum  = cum + val;

        if val < 1
            txt = '<1%';
        else
            txt = sprintf('%.0f%%', val);
        end

        text(ax3, iBar + 1.6*(b(iBar).BarWidth/2)*power(-1, iBar), yPos, txt, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize', 14, 'FontWeight','bold', ...
            'Color', 'k');
    end
end


xlh3 = xlabel(ax3, 'Pressure Contrasts', 'FontWeight','bold')
ylh3 = ylabel(ax3, '% of total pressure effect', 'FontWeight','bold');

ylim(ax3, [0 100]);
xlim(ax3, [1-1 , 2+1])
set(ax3, 'FontSize', 16, 'Box', 'off');


xlh3.Units = "normalized";
xlh3.Position(2) = xlh3.Position(2) - 0.11;
ylh3.Units = "normalized";
% ylh3.Position(1) = ylh3.Position(1) - 0.005;


set(ax3, 'PlotBoxAspectRatio', [1.2 1.4 1]);



end
