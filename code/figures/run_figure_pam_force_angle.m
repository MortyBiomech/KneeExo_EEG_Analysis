%% run_figure_pam_force_angle.m
%  PAM force against knee angle, the participants with load cell
%  recordings. Left, normalised force-angle loops, one per imposed
%  pressure, group mean with SEM shading. Right, peak force in newtons per
%  participant and pressure, in the conditionCloud style of Figure 2.
%
%  Belongs in code/figures/. Writes to cfg.figures.
%
%  Data: cfg.expAnalysis/sub-N/KneeTorque_ForceSensor_data.mat
%    one struct per trial, with
%      Force_sensor_TimeWarped   cycles x samples, newtons, positive when
%                                loaded, zero in the slack phase
%      Knee_Angle_TimeWarped     cycles x samples, degrees, 0 at full
%                                extension and NEGATIVE in flexion
%      Flexion_Length            samples of the flexion half after warping
%      Extension_Length          samples of the extension half
%      Pressure, Description
%
%  WARPING
%  The stored cycles are already time-warped, with the flexion end at
%  sample Flexion_Length. Each half is re-stretched onto opt.nHalf samples,
%  so every cycle becomes 2*opt.nHalf - 1 samples with the flexion end at
%  sample opt.nHalf, in every participant. Samples 1 to opt.nHalf are
%  flexion in every cycle and opt.nHalf to the end are extension, so the
%  sample-wise mean never mixes the two halves.
%
%  NORMALISATION, per participant, over all cycles of all pressures. Each
%  scalar is the mean of a per-cycle extreme, not the single most extreme
%  sample, so the mean loop reaches the axis limits.
%    angle   the stored angle, sign as recorded, mapped linearly so that
%            the mean per-cycle minimum is -1 and the mean per-cycle
%            maximum is 0. -1 is therefore peak flexion and 0 full
%            extension, where the force is zero.
%    force   divided by the mean per-cycle peak force at the highest
%            pressure, so the High loop peaks at 1.
%
%  AVERAGING
%  Left panel: per participant, the mean over cycles of each pressure;
%  across participants, the mean and SEM of those participant means.
%  Right panel: per participant and pressure, the peak force of every
%  cycle, then the mean of those peaks. Group summary is mean and SD over
%  participants, as in Figure 2.
%
%  STYLE
%  Geometry, fonts and marker style follow run_results_behaviour.m
%  (Figure 2): 18.0 cm canvas, explicit centimetre axes, Arial, 6 pt ticks,
%  7 pt labels, 0.5 pt axis lines, ticks inward, no box.

clear; clc;

%% ------------------------- configuration -------------------------------
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('run_figure_pam_force_angle.m');
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);

if isempty(cfg.raw)
    error('figurePamForceAngle:needsRaw', ...
        ['This figure reads the per-trial force and angle structures, which ' ...
         'are not shipped in data/derived. Set cfg.raw in local_paths.m.']);
end

% The load cell was worn by six of the fourteen. This list belongs beside
% cfg.subjects and cfg.subjectsEMG in kneeexo_config.
subjectsForce = [11 12 15 16 17 18];

opt.nHalf   = 100;                % samples per half after re-warping
opt.outName = 'fig_pam_force_angle';

% Style, copied from run_results_behaviour.m so the two figures match.
S.col     = [cfg.colors.P1; cfg.colors.P3; cfg.colors.P6];
S.font    = 'Arial';
S.fsTick  = 6;
S.fsLab   = 7;
S.fsPanel = 8;
S.lw      = 0.5;

% Axis titles are placed by hand at a fixed gap from the tick labels, as
% in the ERSP figures (ersp_params.m, p.plot.xLabelGapMM / yLabelGapMM),
% not by xlabel()/ylabel().
S.xLabelGapMM = 2;
S.yLabelGapMM = 2;

% Where the direction arrows sit, as a fraction of each half. The flexion
% arrow is placed past the middle of the half so that it clears the
% extension arrow where the two limbs of the 1 bar loop lie close.
S.arrowFlexFrac = 0.85;
S.arrowExtFrac  = 0.25;

% Geometry in centimetres. Same canvas width and margins as Figure 2.
figW = 18.0; figH = 7.0;
L.left  = 1.30;
L.right = 17.15;
L.y0    = 1.10;                   % axes bottom
L.h     = 5.20;                   % axes height
L.wLoop = 9.60;                   % left panel width
L.gap   = 1.60;
L.wPeak = L.right - L.left - L.wLoop - L.gap;
L.letterUp = 0.35;                % panel letter above the axes top

nS = numel(subjectsForce);
nC = numel(cfg.pressures);
nP = 2*opt.nHalf - 1;
iFlexEnd = opt.nHalf;
condNames = cfg.conditionNames;

angS  = nan(nS, nC, nP);          % participant mean, mapped angle
frcS  = nan(nS, nC, nP);          % participant mean, normalised force
peakN = nan(nS, nC);              % participant mean of per-cycle peaks, N

%% ---------------------------- per subject ------------------------------
fprintf('PAM force-angle figure: %d participants, %d pressures\n', nS, nC);

for s = 1:nS
    sub = subjectsForce(s);
    subDir = ['sub-' num2str(sub)];
    fprintf('  sub-%-3d ', sub);

    TF = loadOne(fullfile(cfg.expAnalysis, subDir, 'KneeTorque_ForceSensor_data.mat'));

    A = repmat({[]},1,nC); F = repmat({[]},1,nC);
    nKeep = 0; nDrop = 0;

    for j = 1:numel(TF)
        if sub == 12 && j > 75, break; end            % kept from the old script
        t = TF{1,j};
        if ~strcmp(t.Description, 'Experiment'), continue; end
        c = find(cfg.pressures == t.Pressure, 1);
        if isempty(c), nDrop = nDrop + 1; continue; end

        ang = double(t.Knee_Angle_TimeWarped);       % sign as stored
        frc = double(t.Force_sensor_TimeWarped);
        Lf = t.Flexion_Length; Le = t.Extension_Length;
        if size(ang,2) ~= Lf + Le || ~isequal(size(ang), size(frc))
            nDrop = nDrop + size(ang,1); continue
        end

        for k = 1:size(ang,1)
            A{c}(end+1,:) = rewarp(ang(k,:), Lf, opt.nHalf); %#ok<SAGROW>
            F{c}(end+1,:) = rewarp(frc(k,:), Lf, opt.nHalf); %#ok<SAGROW>
            nKeep = nKeep + 1;
        end
    end

    if nKeep == 0
        fprintf('no usable cycles, skipped\n');
        continue
    end

    % per-participant scalars, each the mean of a per-cycle extreme,
    % matching the peak-force panel. Angle pools all pressures, since the
    % movement is the same at every pressure. Force uses the highest
    % pressure only, so that the High loop peaks at 1 and the other two sit
    % below it in proportion.
    allA = vertcat(A{:});
    aMin = mean(min(allA, [], 2), 'omitnan');        % mean of per-cycle minima
    aMax = mean(max(allA, [], 2), 'omitnan');        % mean of per-cycle maxima
    fMax = mean(max(F{nC}, [], 2), 'omitnan');       % mean of per-cycle peaks at High

    for c = 1:nC
        if isempty(A{c}), continue; end
        am = (A{c} - aMax)./(aMax - aMin);           % [-1, 0]
        fm = F{c} ./ fMax;                           % [0, 1]
        angS(s,c,:) = mean(am, 1, 'omitnan');
        frcS(s,c,:) = mean(fm, 1, 'omitnan');
        peakN(s,c)  = mean(max(F{c}, [], 2), 'omitnan');  % mean of per-cycle peaks
    end

    fprintf('%5d cycles (%d dropped), angle %.1f to %.1f deg, mean cycle peak %.0f / %.0f / %.0f N\n', ...
            nKeep, nDrop, aMin, aMax, peakN(s,:));
end

% group statistics over participants
mA  = squeeze(mean(angS, 1, 'omitnan'));            % nC x nP
mF  = squeeze(mean(frcS, 1, 'omitnan'));
nOk = squeeze(sum(~isnan(frcS), 1));
sF  = squeeze(std(frcS, 0, 1, 'omitnan')) ./ sqrt(nOk);

fprintf('  peak force, mean (SD) over participants: %s N\n', ...
        strjoin(compose('%.0f (%.0f)', [mean(peakN,1,'omitnan'); std(peakN,0,1,'omitnan')]'), ' / '));

%% -------------------------------- plot ---------------------------------
fig = figure('Units','centimeters','Position',[1 1 figW figH], ...
             'Color','w','PaperPositionMode','auto');

% ---- a: loops --------------------------------------------------------
ax1 = axes(fig,'Units','centimeters','Position',[L.left L.y0 L.wLoop L.h]);
hold(ax1,'on');
% limits first: the arrowheads are sized in centimetres from them
set(ax1,'XLim',[-1.05 0.05],'YLim',[0 1.15],'XTick',-1:0.25:0,'YTick',0:0.2:1, ...
    'FontName',S.font,'FontSize',S.fsTick,'TickDir','in','Box','off','LineWidth',S.lw);

iF = 1:iFlexEnd; iE = iFlexEnd:nP;                  % flexion, extension
h = gobjects(1,nC);
for c = 1:nC
    col = S.col(c,:);
    % SEM above the flexion limb, SEM below the extension limb, so the two
    % bands sit on the outside of the loop and do not cover each other.
    okF = iF(~isnan(mF(c,iF)) & ~isnan(sF(c,iF)));
    okE = iE(~isnan(mF(c,iE)) & ~isnan(sF(c,iE)));
    patch(ax1, [mA(c,okF) fliplr(mA(c,okF))], ...
               [mF(c,okF) fliplr(mF(c,okF)+sF(c,okF))], col, ...
               'FaceAlpha',0.22, 'EdgeColor','none');
    patch(ax1, [mA(c,okE) fliplr(mA(c,okE))], ...
               [mF(c,okE) fliplr(mF(c,okE)-sF(c,okE))], col, ...
               'FaceAlpha',0.22, 'EdgeColor','none');
    h(c) = plot(ax1, mA(c,iF), mF(c,iF), '-',  'Color',col, 'LineWidth',0.9);
           plot(ax1, mA(c,iE), mF(c,iE), '--', 'Color',col, 'LineWidth',0.9);
    arrowAt(ax1, mA(c,:), mF(c,:), round(S.arrowFlexFrac*iFlexEnd));             % flexion
    arrowAt(ax1, mA(c,:), mF(c,:), iFlexEnd + round(S.arrowExtFrac*opt.nHalf));  % extension
end
hF = plot(ax1, nan, nan, '-',  'Color',[0.4 0.4 0.4], 'LineWidth',0.9);
hE = plot(ax1, nan, nan, '--', 'Color',[0.4 0.4 0.4], 'LineWidth',0.9);

axisTitles(ax1, 'Knee angle (normalised, -1 peak flexion, 0 full extension)', ...
                'PAM force (normalised to participant peak at High)', S);
lg = legend(ax1,[h hF hE],[condNames {'flexion','extension'}],'Location','northeast');
set(lg,'Box','off','FontName',S.font,'FontSize',S.fsTick);

% ---- b: peak force, conditionCloud style -----------------------------
ax2 = axes(fig,'Units','centimeters','Position',[L.left+L.wLoop+L.gap L.y0 L.wPeak L.h]);
hold(ax2,'on');
conditionCloud(ax2, peakN, S.col, nC);
yTop = 1.10*max(peakN(:));
set(ax2,'XTick',1:nC,'XTickLabel',condNames,'YLim',[0 yTop], ...
    'FontName',S.font,'FontSize',S.fsTick,'TickDir','in','Box','off','LineWidth',S.lw);
axisTitles(ax2, 'Physical demand', 'Peak PAM force (N)', S);

% ---- panel letters ---------------------------------------------------
yLet = (L.y0 + L.h + L.letterUp) / figH;
letterAt(fig, (L.left-1.10)/figW,                 yLet, 'a', S);
letterAt(fig, (L.left+L.wLoop+L.gap-1.10)/figW,   yLet, 'b', S);

if ~exist(cfg.figures,'dir'), mkdir(cfg.figures); end
exportgraphics(fig, fullfile(cfg.figures,[opt.outName '.pdf']), ...
    'ContentType','vector','BackgroundColor','white');
exportgraphics(fig, fullfile(cfg.figures,[opt.outName '.png']), ...
    'Resolution',600,'BackgroundColor','white');
fprintf('written to %s\n', fullfile(cfg.figures, [opt.outName '.pdf']));

%% ----------------------------- functions -------------------------------
function v = loadOne(f)
    S = load(f); n = fieldnames(S); v = S.(n{1});
end

function y = rewarp(x, Lf, nHalf)
% x is one warped cycle with the flexion end at sample Lf. Stretch x(1:Lf)
% onto nHalf samples and x(Lf:end) onto nHalf samples, sharing sample Lf.
    x = x(:)';
    xf = x(1:Lf); xe = x(Lf:end);
    yf = interp1(linspace(0,1,numel(xf)), xf, linspace(0,1,nHalf), 'linear');
    ye = interp1(linspace(0,1,numel(xe)), xe, linspace(0,1,nHalf), 'linear');
    y = [yf, ye(2:end)];
end

function arrowAt(ax, x, y, i)
% Black arrow on the curve at sample i, pointing along the curve. Drawn as
% a line shaft plus a patch head, both sized in centimetres, so every
% arrow is the same size on paper whatever the local slope or the axes
% aspect. The arrow is centred on the sample.
    shaftLen = 0.28;                    % cm, tail to head base
    headLen  = 0.14;                    % cm, head base to tip
    headWid  = 0.10;                    % cm, head base width

    i = max(2, min(numel(x)-1, i));
    pos = get(ax,'Position');           % [x y w h] in cm (axes set in cm)
    kx = pos(3) / range(xlim(ax));      % cm per data unit
    ky = pos(4) / range(ylim(ax));
    dx = (x(i+1) - x(i-1)) * kx;  dy = (y(i+1) - y(i-1)) * ky;
    n = hypot(dx, dy);
    if n == 0, return; end
    u = [dx dy]/n;                      % unit tangent, cm
    p = [-u(2) u(1)];                   % unit normal, cm

    c    = [x(i)*kx, y(i)*ky];          % centre, cm
    half = (shaftLen + headLen)/2;
    tail = c - u*half;
    tip  = c + u*half;
    base = tip - u*headLen;

    plot(ax, [tail(1) base(1)]/kx, [tail(2) base(2)]/ky, 'k-', ...
         'LineWidth',0.8, 'HandleVisibility','off');
    v = [tip; base + p*headWid/2; base - p*headWid/2];
    patch(ax, v(:,1)/kx, v(:,2)/ky, 'k', 'EdgeColor','none', ...
          'HandleVisibility','off');
end

function axisTitles(ax, xStr, yStr, S)
% Axis titles placed by hand, S.xLabelGapMM below the x tick labels and
% S.yLabelGapMM left of the y tick labels, as draw_x_label / draw_y_label
% do in plot_qc_sanity.m. xlabel()/ylabel() would put them at a
% MATLAB-chosen distance instead. TightInset gives the extent of the tick
% labels beyond the axes box; the axes are in centimetres, so it is too.
    drawnow;
    pos = get(ax,'Position');           % [x y w h], cm
    ti  = get(ax,'TightInset');         % [left bottom right top], cm
    xNorm = -(ti(1) + S.yLabelGapMM/10) / pos(3);
    yNorm = -(ti(2) + S.xLabelGapMM/10) / pos(4);
    text(ax, 0.5, yNorm, xStr, 'Units','normalized', ...
        'HorizontalAlignment','center', 'VerticalAlignment','top', ...
        'FontName',S.font, 'FontSize',S.fsLab, 'Clipping','off');
    text(ax, xNorm, 0.5, yStr, 'Units','normalized', 'Rotation',90, ...
        'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
        'FontName',S.font, 'FontSize',S.fsLab, 'Clipping','off');
end

function conditionCloud(ax, D, COL, nCond)
% Copied from run_results_behaviour.m so the two figures share one style.
% Individual traces, per-condition points, and the group summary. The
% traces carry within-subject consistency, the summary carries magnitude.
% A white marker edge separates overlapping points that transparency
% alone cannot, which matters where a condition's distribution is tight.
    n = size(D,1);
    rng(7,'twister');
    jit = (rand(n,1)-0.5)*0.24;
    xc  = 1:nCond;  xcl = xc - 0.05;

    for i = 1:n
        plot(ax, xcl + jit(i), D(i,:), '-', ...
            'Color',[0.65 0.65 0.65 0.45],'LineWidth',0.4);
    end
    for c = 1:nCond
        scatter(ax, xcl(c)+jit, D(:,c), 12, ...
            'MarkerFaceColor',COL(c,:),'MarkerFaceAlpha',0.55, ...
            'MarkerEdgeColor','w','LineWidth',0.35);
    end
    errorbar(ax, xc+0.28, mean(D,1,'omitnan'), std(D,0,1,'omitnan'), 'k-', ...
        'LineWidth',0.9,'CapSize',2.5,'Marker','o','MarkerSize',3, ...
        'MarkerFaceColor','k','MarkerEdgeColor','k');
    xlim(ax,[0.55 nCond+0.65]);
end

function letterAt(fig, x, y, letter, S)
% Panel letter in normalised figure units, bold, as in Figure 2.
    annotation(fig,'textbox',[x y 0.03 0.03],'String',letter, ...
        'FontName',S.font,'FontSize',S.fsPanel,'FontWeight','bold', ...
        'EdgeColor','none','Margin',0,'VerticalAlignment','bottom');
end