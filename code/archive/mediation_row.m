%% MEDIATION_ROW
%  Row 3 of Figure 2: the mediation model on the left, the decomposition
%  of the total effect on the right. One panel, two plots: they are a
%  single analysis, and lettering them separately would suggest otherwise.
%
%  THE DIAGRAM IS MONOCHROME. An earlier version shaded each pathway's
%  arrows to match its bar. It did not survive the line weight: three
%  greys read clearly as filled blocks in the bars but not as 0.8 pt
%  strokes on white, where the lightest was hard to distinguish from the
%  box edges. The a and b subscripts already identify each path and the
%  bars are labelled in words, so the shading was solving a problem the
%  labels had solved, through a channel that fails at this size.
%
%  Nothing here uses the condition palette either: blue, amber and maroon
%  mean Low, Medium and High everywhere else in the figure, and reusing
%  them would imply a link to pressure condition that does not exist. The
%  bars keep their three greys, where the encoding works.
%
%  WHY NOT A STACKED BAR. Only the bottom segment of a stack starts at a
%  common baseline, so the other two are judged by comparing edges that
%  both float, which is why the earlier version needed its percentages
%  written on to be readable. Stacking also forces the parts to sum to
%  the whole, leaving nowhere to attach an interval, and the interval on
%  the tracking-error share is the strongest part of this result: not
%  merely small, but bounded near zero.
%
%  Bars run in rating points so the axis shares units with the arrows and
%  a reader can trace a1 times b1 across the panel, with the percentage
%  annotated at each bar end since that is what the paragraph quotes.
%
%  Every label is read from the fitted model, so the panel cannot go
%  stale when a coefficient changes.
%
%  Run results_mediation.m first.
% =====================================================================

clc; clear;

data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
out_path  = [data_path, '7_Master_Tables\'];
fig_path  = [data_path, '8_Figures\'];
if ~exist(fig_path,'dir'), mkdir(fig_path); end

load(fullfile(out_path,'mediation_results.mat'), 'med');

% ---- Style, matching the rows above ---------------------------------
S.font    = 'Arial';
S.fsTick  = 6;
S.fsLab   = 7;
S.fsPanel = 8;
S.fsPath  = 6;
S.fsBox   = 6;
S.lw      = 0.5;
S.xlabPad = 0.18;
S.ylabPad = 0.18;

% White fill so the arrows carry the ink.
S.boxFace = [1 1 1];
S.boxEdge = [0.40 0.40 0.40];
S.arrow   = [0.30 0.30 0.30];   % one weight for every path
S.boxRad  = 0.06;      % cm, corner radius. Set 0 for square corners.

% Arrow head sized in centimetres, so it keeps its shape whatever the
% aspect ratio of the axes. Built in normalised data units on a panel
% twice as wide as it is tall, a symmetric head comes out stretched.
S.headLen = 0.17;
S.headWid = 0.062;
S.pathOff = 0.32;      % cm, perpendicular offset of a path label. Must
                       % exceed half the text height or the line runs
                       % through the label, which is what happened at 0.14.

% Three greys for the bars, where they sit as filled blocks side by side
% and are easy to tell apart.
G.direct = [0.30 0.30 0.30];
G.effort = [0.52 0.52 0.52];
G.error  = [0.72 0.72 0.72];

figW = 18.0; figH = 5.2;
LEFT = 1.30; RIGHT = 17.15;

% The diagram gives up width to the decomposition, which needs room for
% its tick labels, its percentages and a two-line axis label without any
% of them reaching the canvas edge.
xDiag = LEFT;   wDiag = 7.60;
xDec  = 10.90;  wDec  = RIGHT - xDec;
yAx   = 1.30;   hAx   = 3.00;

fig = figure('Units','centimeters','Position',[1 1 figW figH], ...
             'Color','w','PaperPositionMode','auto');


%% Left: the path diagram
% ---------------------------------------------------------------------
axD = axes(fig,'Units','centimeters','Position',[xDiag yAx wDiag hAx]);
hold(axD,'on'); xlim(axD,[0 1]); ylim(axD,[0 1]); axis(axD,'off');

BW = 0.25; BH = 0.22;
xP = 0.140; xM = 0.50; xY = 0.860;
yT = 0.82;  yM = 0.50; yB = 0.18;

drawBox(axD, xP, yM, BW, BH, sprintf('Physical\ndemand'),      S, S.boxEdge);
drawBox(axD, xM, yT, BW, BH, 'Effort index',                   S, S.boxEdge);
drawBox(axD, xM, yB, BW, BH, 'Tracking error',                 S, S.boxEdge);
drawBox(axD, xY, yM, BW, BH, sprintf('Perceived\ndifficulty'), S, S.boxEdge);

% Endpoints. The three paths leave the manipulation at separate points on
% its right edge and arrive at the outcome at separate points on its left
% edge, so neither box has three arrows stacked on one spot. They meet
% the mediators at mid-height, where there is only one arrow to place.
dy = 0.06;
pUp = [xP+BW/2, yM+dy];  pMid = [xP+BW/2, yM];  pLo = [xP+BW/2, yM-dy];
yUp = [xY-BW/2, yM+dy];  yMid = [xY-BW/2, yM];  yLo = [xY-BW/2, yM-dy];
mL  = [xM-BW/2, yT];     mR   = [xM+BW/2, yT];
tL  = [xM-BW/2, yB];     tR   = [xM+BW/2, yB];

drawArrow(axD, pUp,  mL,   S.arrow, S);
drawArrow(axD, mR,   yUp,  S.arrow, S);
drawArrow(axD, pLo,  tL,   S.arrow, S);
drawArrow(axD, tR,   yLo,  S.arrow, S);
drawArrow(axD, pMid, yMid, S.arrow, S);

% Labels are placed on a fixed grid rather than derived from each arrow,
% which is what left them at four different heights. a1 and b1 share a
% row, a2 and b2 share a row, a1 and a2 share a column, b1 and b2 share a
% column. The rows sit level with the mediator boxes, in the open corners
% of the diagram, so no label crosses a line.
xLabA = 0.235; xLabB = 0.765;
pathLabel(axD, xLabA, yT, sprintf('a_1 = %+.2f', med.a1.est), S);
pathLabel(axD, xLabB, yT, sprintf('b_1 = %+.2f', med.b1.est), S);
pathLabel(axD, xLabA, yB, sprintf('a_2 = %+.2f', med.a2.est), S);
pathLabel(axD, xLabB, yB, sprintf('b_2 = %+.2f', med.b2.est), S);
pathLabel(axD, 0.50,  yM+0.085, sprintf('c'' = %+.2f', med.cPrime.est), S);

% Sits at the same height as the axis label opposite, so the row has one
% baseline instead of a filled block on the right and empty space on the
% left.
text(axD, 0.50, -0.20, sprintf(['total effect c = %+.2f rating points ' ...
    'per level of demand'], med.c.est), ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'Clipping','off','FontName',S.font,'FontSize',S.fsPath, ...
    'Color',[0.4 0.4 0.4]);
hold(axD,'off');


%% Right: the decomposition
% ---------------------------------------------------------------------
axB = axes(fig,'Units','centimeters','Position',[xDec yAx wDec hAx]);
hold(axB,'on');

comp = {'Direct',              med.direct, G.direct
        'Via effort',          med.ind1,   G.effort
        'Via tracking error',  med.ind2,   G.error};
n = size(comp,1);

for i = 1:n
    y = n - i + 1;                      % largest at the top
    d = comp{i,2};
    m = median(d); lo = prctile(d,2.5); hi = prctile(d,97.5);

    barh(axB, y, m, 0.5, 'FaceColor', comp{i,3}, 'EdgeColor','none');
    plot(axB, [lo hi], [y y], 'k-', 'LineWidth', 0.7);
    plot(axB, [lo lo], y+[-0.10 0.10], 'k-', 'LineWidth', 0.7);
    plot(axB, [hi hi], y+[-0.10 0.10], 'k-', 'LineWidth', 0.7);

    text(axB, hi + 0.07, y, sprintf('%.0f%%', median(100*d./med.total)), ...
        'FontName',S.font,'FontSize',S.fsTick, ...
        'HorizontalAlignment','left','VerticalAlignment','middle');
end

xlim(axB, [0, med.c.est*1.20]);
ylim(axB, [0.45, n+0.55]);

% Trailing spaces on the tick labels, which are right-aligned against the
% axis, open a gap between the text and the axis line.
set(axB,'YTick',1:n,'YTickLabel',strcat(flip(comp(:,1)), {'   '}), ...
    'XTick',0:0.5:2.5,'FontName',S.font,'FontSize',S.fsTick, ...
    'TickDir','in','Box','off','LineWidth',S.lw);
xlabel(axB, sprintf(['Effect on perceived difficulty\n' ...
    '(rating points per level)']), ...
    'FontName',S.font,'FontSize',S.fsLab);
padLabels(axB, S);
hold(axB,'off');


%% One panel letter for the row
% ---------------------------------------------------------------------
annotation(fig,'textbox',[0.004 (yAx+hAx+0.30)/figH 0.05 0.05], ...
    'String','d','FontName',S.font,'FontSize',S.fsPanel, ...
    'FontWeight','bold','EdgeColor','none', ...
    'HorizontalAlignment','left','VerticalAlignment','middle');

exportgraphics(fig, fullfile(fig_path,'figure2_row3.pdf'), ...
    'ContentType','vector','BackgroundColor','white');
exportgraphics(fig, fullfile(fig_path,'figure2_row3.png'), ...
    'Resolution',600,'BackgroundColor','white');
fprintf('Row 3 written to %s\n', fig_path);


%% Local functions
% ---------------------------------------------------------------------
function drawBox(ax, xc, yc, w, h, label, S, edgeCol)
% Corner radius specified in centimetres rather than through MATLAB's
% Curvature property directly.
%
% Curvature takes a fraction of each side, not a radius, so a single
% value produces an elliptical corner whenever the box is not square on
% screen. Here the box measures about 1.9 cm across and 0.66 cm high, so
% Curvature 0.15 gave a corner nearly three times wider than it was tall.
%
% Solving for equal physical radii: the horizontal semi-axis is
% cx*w/2 data units, which is cx*w*sx/2 centimetres, and likewise for the
% vertical. Setting both to r gives the pair below.
    if S.boxRad > 0
        pos = get(ax,'Position');
        sx  = pos(3)/diff(xlim(ax));
        sy  = pos(4)/diff(ylim(ax));
        cur = min([2*S.boxRad/(w*sx), 2*S.boxRad/(h*sy)], 1);
    else
        cur = [0 0];
    end

    rectangle(ax,'Position',[xc-w/2, yc-h/2, w, h], ...
        'Curvature',cur,'FaceColor',S.boxFace, ...
        'EdgeColor',edgeCol,'LineWidth',0.8);
    text(ax, xc, yc, label, 'HorizontalAlignment','center', ...
        'VerticalAlignment','middle','FontName',S.font,'FontSize',S.fsBox);
end


function drawArrow(ax, from, to, col, S)
% Straight arrow with a head sized in centimetres and converted back to
% data units, so it keeps its shape whatever the aspect ratio of the
% axes. Built directly in normalised data units on a panel wider than it
% is tall, a symmetric head comes out stretched horizontally.

    pos = get(ax,'Position');            % centimetres
    sx  = pos(3)/diff(xlim(ax));         % cm per data unit, x
    sy  = pos(4)/diff(ylim(ax));         % cm per data unit, y

    p1 = [from(1)*sx, from(2)*sy];       % into a metric space
    p2 = [to(1)*sx,   to(2)*sy];
    d  = (p2 - p1) / norm(p2 - p1);
    perp = [-d(2), d(1)];

    base = p2 - S.headLen*d;             % shaft stops where the head starts

    plot(ax, [p1(1) base(1)]/sx, [p1(2) base(2)]/sy, '-', ...
        'Color', col, 'LineWidth', 0.8);

    tri = [p2; base + S.headWid*perp; base - S.headWid*perp];
    patch(ax, tri(:,1)/sx, tri(:,2)/sy, col, 'EdgeColor','none');
end


function pathLabel(ax, x, y, str, S)
    text(ax, x, y, str, 'HorizontalAlignment','center', ...
        'VerticalAlignment','middle','FontName',S.font,'FontSize',S.fsPath);
end


function padLabels(ax, S)
    ylh = get(ax,'YLabel');
    if ~isempty(get(ylh,'String'))
        set(ylh,'Units','centimeters');
        p = get(ylh,'Position'); set(ylh,'Position',[p(1)-S.ylabPad p(2) p(3)]);
    end
    xlh = get(ax,'XLabel');
    if ~isempty(get(xlh,'String'))
        set(xlh,'Units','centimeters');
        p = get(xlh,'Position'); set(xlh,'Position',[p(1) p(2)-S.xlabPad p(3)]);
    end
end
