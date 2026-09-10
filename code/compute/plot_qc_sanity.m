function plot_qc_sanity(s, p, outputPath, studyName)
% PLOT_QC_SANITY  Quick-look figures for one cluster's QC'd results.
%
%   PLOT_QC_SANITY(S, P, OUTPUTPATH, STUDYNAME)
%
% Two figures:
%   1. the three condition ERSPs plus the RM-ANOVA (omnibus) significance
%      panel
%   2. each non-reference condition minus the reference condition, with
%      significant clusters outlined
%
% NOT the paper figure -- exists to sanity-check the QC'd numbers before
% Figure 3 / Figure 4 are designed separately from S, which is what's
% saved to disk and carried forward.
%
% LAYOUT. Every axes is placed by an explicit [left bottom width height]
% Position, computed from the named millimetre constants in LAYOUT below;
% nothing here uses subplot(), the default title(), or a bare colorbar()
% call, all of which silently resize or reposition things on their own.
% Total figure WIDTH (p.plot.figureWidthMM, 180 mm to match the earlier
% published figures) and HEIGHT (p.plot.figureHeightMM) are both fixed
% regardless of how many panels a figure has, so the 4-panel conditions
% figure and the 2-panel differences figure for the same cluster come out
% the same overall size; only each panel's own width changes with panel
% count, which follows directly from holding both totals fixed.
%
% Requires p.plot.figureWidthMM, p.plot.figureHeightMM and p.plot.mmToInch
% (the Nat-Comms-oriented plotting block in ersp_params.m). This run used
% figureWidthMM = 180 (not the 183 mm double-column default) to match
% what the earlier published figures used; figureHeightMM is new -- see
% the note where LAYOUT is built, below.
%
% STUDYNAME is used only for output file names; the figure title uses
% S.NAME (e.g. 'Right Prim Motor') instead of STUDYNAME (e.g.
% 'Right_Prim_Motor'), since MATLAB's default text interpreter reads
% underscores as subscript markers.

if ~isfolder(outputPath)
    mkdir(outputPath);
end

L = build_layout(p);
eventTimes = [s.allTimes(1), s.eventTimes(2), s.allTimes(end)];
figTitle = sprintf('%s (n = %d, after QC)', s.name, numel(s.subjects));

% --- Figure 1: conditions + RM-ANOVA -----------------------------------
colorLimits = symmetric_color_limits(s.erspdata.mean, p);
panelTitles = [p.design.legend, {sprintf('RM-ANOVA (p<%g)', s.alpha)}];
panelData   = [s.erspdata.mean(:)', {double(s.condMask{1,1})}];
fig = render_panel_row(panelTitles, panelData, s, eventTimes, colorLimits, ...
    'Baseline-corrected power (dB)', L, p, figTitle);
save_all_formats(fig, fullfile(outputPath, [studyName '_qc_conditions']), p);
close(fig);

% --- Figure 2: pairwise vs. reference -----------------------------------
diffMeans = s.erspDiff.mean(s.compareIdx);
if ~all(cellfun(@isempty, diffMeans))
    colorLimits = symmetric_color_limits(diffMeans, p);
    panelTitles = arrayfun(@(ci) sprintf('%s vs. %s', p.design.legend{ci}, ...
        p.design.legend{s.refIdx}), s.compareIdx, 'UniformOutput', false);
    sigMasks = s.erspDiff.sigMask(s.compareIdx);
    fig = render_panel_row(panelTitles, diffMeans(:)', s, eventTimes, ...
        colorLimits, '\Delta Baseline-corrected power (dB)', L, p, figTitle, sigMasks);
    save_all_formats(fig, fullfile(outputPath, [studyName '_qc_vs_reference']), p);
    close(fig);
end

fprintf('  Sanity-check figures saved to %s\n', outputPath);
end

%% ========================================================================
%  Layout: every dimension named and fixed, in millimetres
%  ========================================================================
function L = build_layout(p)
% All independent of panel count. panelWidthMM (the one dependent
% quantity) is solved per-figure in render_panel_row, from these plus
% however many panels that figure has.
    L.figWidthMM      = p.plot.figureWidthMM;    % 180: matches earlier figures
    L.figHeightMM     = p.plot.figureHeightMM;   % NEW field; fixed regardless
                                                  % of panel count -- add to
                                                  % ersp_params.m, e.g. 70
    L.suptitleRowMM   = 8;    % cluster name + n, above everything
    L.panelTitleRowMM = 6;    % each panel's own title (e.g. 'Low Pressure')
    L.eventLabelRowMM = 9;    % rotated FlxS / FlxE-ExtS / ExtE labels,
                              % directly below the panel title, directly
                              % above the axes box -- its own row, so it
                              % cannot collide with either
% Bottom margin, split into three named rows instead of one flat number,
% so the gap between the x tick numbers and the 'Cycle (%)' axis title is
% its own controllable quantity (p.plot.xLabelGapMM) rather than whatever
% xlabel()'s automatic placement happened to use.
    L.xTickRowMM  = 4;                    % the numeric tick labels themselves
    L.xLabelGapMM = p.plot.xLabelGapMM;    % gap you can tune
    L.xLabelRowMM = 5;                    % the 'Cycle (%)' text itself
    L.marginBottomMM = L.xTickRowMM + L.xLabelGapMM + L.xLabelRowMM;

% Left margin, split the same way for the y axis (panel 1 only -- other
% panels only ever show tick numbers, no axis title, so they use
% yTickRowMM alone via the gutter below).
    L.yTickRowMM  = 6;                    % the numeric tick labels ('120' etc.)
    L.yLabelGapMM = p.plot.yLabelGapMM;    % gap you can tune
    L.yLabelRowMM = 5;                    % the 'Frequency (Hz)' text itself
    L.marginLeftMM = L.yTickRowMM + L.yLabelGapMM + L.yLabelRowMM;

% Gap between adjacent panels: genuine visual spacing (panelGapMM) plus
% room for the next panel's own y-tick numbers (yTickRowMM again -- every
% panel shows these now, drawn OUTSIDE its axes box just to its left, so
% skipping this allowance is what let them print into the previous
% panel's plot box before).
    L.panelGapMM = 2;
    L.gutterMM   = L.panelGapMM + L.yTickRowMM;
    L.colorbarGapMM   = 3;    % gap between last panel and the colorbar
    L.colorbarWidthMM = 3;    % the colorbar itself
    L.colorbarLabelMM = 11;   % colorbar ticks + its axis label

    L.topMarginMM  = L.panelTitleRowMM + L.eventLabelRowMM;
    L.axesHeightMM = L.figHeightMM - L.suptitleRowMM - L.topMarginMM - L.marginBottomMM;
    assert(L.axesHeightMM > 0, 'build_layout:HeightTooSmall', ...
        'figureHeightMM (%.0f) leaves no room for the axes once the fixed rows (%.0f) are subtracted -- increase p.plot.figureHeightMM.', ...
        L.figHeightMM, L.figHeightMM - L.axesHeightMM);
end

%% ========================================================================
%  One figure: a row of panels sharing one colour scale and one colorbar
%  ========================================================================
function fig = render_panel_row(panelTitles, panelData, s, eventTimes, ...
    colorLimits, colorbarLabel, L, p, figTitle, sigMasks)
    if nargin < 10
        sigMasks = [];   % conditions figure has no significance outline
    end
    nPanel = numel(panelTitles);

    panelWidthMM = (L.figWidthMM - L.marginLeftMM - (nPanel-1)*L.gutterMM ...
        - L.colorbarGapMM - L.colorbarWidthMM - L.colorbarLabelMM) / nPanel;
    assert(panelWidthMM > 0, 'render_panel_row:WidthTooSmall', ...
        'figureWidthMM (%.0f) leaves no room for %d panels once the fixed margins are subtracted.', ...
        L.figWidthMM, nPanel);

    widthIn  = L.figWidthMM  * p.plot.mmToInch;
    heightIn = L.figHeightMM * p.plot.mmToInch;
    fig = figure('Name', figTitle, 'Color', [1 1 1], 'Units', 'inches', ...
        'Position', [0 0 widthIn heightIn], ...
        'PaperUnits', 'inches', 'PaperSize', [widthIn heightIn], ...
        'PaperPosition', [0 0 widthIn heightIn]);
    if isfield(p.plot, 'renderer')
        set(fig, 'Renderer', p.plot.renderer);
    end

    % Frequencies are log-spaced (p.ersp.freqscale = 'log'), i.e. evenly
    % spaced in log10 space. IMAGESC places its rows at evenly spaced
    % positions between its YData endpoints -- it does not honour a
    % non-uniform coordinate vector the way CONTOURF did, so we plot
    % log10(freq) on a LINEAR y-axis instead of freq on a log-scaled
    % one. Because the samples are evenly spaced in log10, this gives
    % the exact same row positions CONTOURF + 'YScale','log' did; only
    % the tick labels need converting back to Hz for display.
    logFreqs    = log10(s.allFreqs);
    logFreqTick = log10(p.plot.freqTicks);

    axesHandles = gobjects(1, nPanel);
    for ci = 1:nPanel
        leftMM = L.marginLeftMM + (ci-1)*(panelWidthMM + L.gutterMM);
        pos = mm_box_to_normalized(leftMM, L.marginBottomMM, ...
            panelWidthMM, L.axesHeightMM, L);
        axesHandles(ci) = axes('Parent', fig, 'Units', 'normalized', 'Position', pos);

        % One embedded raster image per panel instead of CONTOURF's ~200
        % stacked vector polygons -- this is what removes the "vectorized
        % content" export warning; axes, ticks, text and the mask outline
        % below stay real vector objects.
        im = imagesc(axesHandles(ci), s.allTimes, logFreqs, panelData{ci});
        set(axesHandles(ci), 'YDir', 'normal');
        % Smooths the hard-edged data cells IMAGESC draws by default,
        % both on screen and in the exported file. 'Interpolation' is an
        % Image-object property from MATLAB R2022a onward; isprop guards
        % older versions so this silently no-ops there instead of
        % erroring -- tell me if you're on an older release and still
        % seeing blockiness, and I'll add a data-upsampling fallback
        % (interp2) that works on any version instead.
        if isprop(im, 'Interpolation')
            im.Interpolation = 'bilinear';
        end
        if ~isempty(sigMasks) && ~isempty(sigMasks{ci})
            hold(axesHandles(ci), 'on');
            outline_significant_regions(axesHandles(ci), sigMasks{ci}, ...
                s.allTimes, logFreqs, p);
        end
        draw_mid_event_line(axesHandles(ci), eventTimes(2), p);
        % IMAGE objects don't reliably respect normal add-order stacking
        % the way CONTOURF's filled patches did -- depending on the
        % renderer, an image can paint over lines added after it even
        % though it was created first. This is what silently hid the
        % significance-mask outline and the mid-event line once CONTOURF
        % was replaced with IMAGESC: uistack forces the image to the
        % back explicitly, instead of relying on add order at all.
        uistack(im, 'bottom');
        format_axes(axesHandles(ci), s, colorLimits, ci == 1, p, logFreqs, logFreqTick);
        draw_x_label(axesHandles(ci), L, p);
        if ci == 1
            draw_y_label(axesHandles(ci), L, p, panelWidthMM);
        end
        draw_panel_title(axesHandles(ci), panelTitles{ci}, L, p);
        draw_event_labels(axesHandles(ci), eventTimes, s.allTimes, L, p);
    end

    add_colorbar(fig, axesHandles(end), panelWidthMM, colorLimits, colorbarLabel, L, p);

    set(fig, 'Colormap', ersp_colormap());
    add_suptitle(fig, figTitle, L, p);
end

function pos = mm_box_to_normalized(leftMM, bottomMM, widthMM, heightMM, L)
% [left bottom width height] in mm -> normalized [0,1] figure units.
    pos = [leftMM/L.figWidthMM, bottomMM/L.figHeightMM, ...
           widthMM/L.figWidthMM, heightMM/L.figHeightMM];
end

%% ========================================================================
%  Per-axes drawing, each in its own reserved row -- nothing auto-placed
%  ========================================================================
function format_axes(ax, s, colorLimits, isLeftmost, p, logFreqs, logFreqTick)
% Y axis is log10(frequency) plotted on a LINEAR scale (see the note in
% render_panel_row on why IMAGESC needs this instead of 'YScale','log'),
% so YTick sits at log10(p.plot.freqTicks) with the original Hz values
% given back as its tick labels. YMinorTick off is kept explicit even
% though a linear axis shows none by default, so this doesn't rely on
% that default. YTickLabel is not cleared for non-leftmost panels, so
% every panel shows its own tick numbers; only the "Frequency (Hz)" axis
% label stays leftmost-only. No FontWeight is set anywhere in this file,
% per your instruction.
    set(ax, 'CLim', colorLimits, ...
        'XLim', [s.allTimes(1) s.allTimes(end)], ...
        'YLim', [logFreqs(1) logFreqs(end)], ...
        'YDir', 'normal', ...
        'YTick', logFreqTick, 'YTickLabel', arrayfun(@(f) sprintf('%g', f), ...
            p.plot.freqTicks, 'UniformOutput', false), ...
        'YMinorTick', 'off', ...
        'XTick', [s.allTimes(1) s.eventTimes(2) s.allTimes(end)], ...
        'XTickLabel', p.plot.cycleTicks, ...
        'FontName', p.plot.fontName, 'FontSize', p.plot.tickFontSize, ...
        'Box', 'on', 'Layer', 'top');
% Axis title text (the 'Cycle (%)' / 'Frequency (Hz)' strings) is drawn
% separately by DRAW_X_LABEL / DRAW_Y_LABEL, not xlabel()/ylabel() --
% those place text at a MATLAB-chosen offset from the tick labels, which
% is exactly the "automatic measurement" you asked not to rely on.
end

function draw_x_label(ax, L, p)
% 'Cycle (%)', placed L.xLabelGapMM below the tick-label row, in its own
% L.xLabelRowMM row -- every distance here is one of the named
% millimetre constants in L, not a MATLAB-chosen default.
    yNorm = -(L.xTickRowMM + L.xLabelGapMM + L.xLabelRowMM/2) / L.axesHeightMM;
    text(ax, 0.5, yNorm, p.plot.xLabel, 'Units', 'normalized', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontName', p.plot.fontName, 'FontSize', p.plot.labelFontSize, ...
        'Clipping', 'off');
end

function draw_y_label(ax, L, p, panelWidthMM)
% 'Frequency (Hz)', rotated 90 degrees, placed L.yLabelGapMM to the left
% of the tick-label column, in its own L.yLabelRowMM column. Needs
% PANELWIDTHMM because this text's normalized X position is relative to
% THIS AXES' own width, not the figure's.
    xNorm = -(L.yTickRowMM + L.yLabelGapMM + L.yLabelRowMM/2) / panelWidthMM;
    text(ax, xNorm, 0.5, 'Frequency (Hz)', 'Units', 'normalized', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'Rotation', 90, 'FontName', p.plot.fontName, ...
        'FontSize', p.plot.labelFontSize, 'Clipping', 'off');
end

function draw_panel_title(ax, titleText, L, p)
% Manually placed text, NOT title(): title() sits at a MATLAB-chosen
% distance above the axes, which is what collided with the event labels
% before. 'Units','normalized' here means normalized to THIS AXES (the
% default for objects parented to an axes), so 1.0 is exactly the axes'
% own top edge and everything above it is this axes' own reserved
% L.topMarginMM, converted to a fraction of the axes' own height.
    yNorm = 1 + (L.eventLabelRowMM + L.panelTitleRowMM/2) / L.axesHeightMM;
    text(ax, 0.5, yNorm, titleText, 'Units', 'normalized', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontName', p.plot.fontName, 'FontSize', p.plot.fontSize, ...
        'Clipping', 'off');
end

function draw_event_labels(ax, eventTimes, allTimes, L, p)
% Own row, directly below the title row, directly above the axes: cannot
% collide with either by construction. Rotated 90 degrees, so each label
% reads bottom-to-top in its own vertical column instead of needing
% horizontal room next to its neighbours.
%
% FlxS (first event) and ExtE (last event) fall exactly at the axes'
% left/right edges (xNorm 0 and 1), which read as flush against the
% panel border. p.plot.eventLabelInsetFrac shifts just their LABEL text
% inward by that fraction of the cycle width -- the FlxS/ExtE ticks and
% underlying data are untouched, only where the text is drawn moves.
% FlxE/ExtS, already inside the axes, is left exactly where it is.
    yNorm = 1 + (L.eventLabelRowMM/2) / L.axesHeightMM;
    xRange = allTimes(end) - allTimes(1);
    nEvt = numel(eventTimes);
    for i = 1:nEvt
        xNorm = (eventTimes(i) - allTimes(1)) / xRange;
        if i == 1
            xNorm = xNorm + p.plot.eventLabelInsetFrac;
        elseif i == nEvt
            xNorm = xNorm - p.plot.eventLabelInsetFrac;
        end
        text(ax, xNorm, yNorm, p.plot.eventLabels{i}, 'Units', 'normalized', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'Rotation', 90, 'FontName', p.plot.fontName, ...
            'FontSize', p.plot.eventFontSize, 'Clipping', 'off');
    end
end

function add_suptitle(fig, titleText, L, p)
% Figure-level text (not sgtitle, which -- like title() -- auto-resizes
% things in a way we're deliberately not using here), placed in its own
% reserved L.suptitleRowMM at the true top of the figure.
    yNorm = 1 - (L.suptitleRowMM/2) / L.figHeightMM;
    annotation(fig, 'textbox', [0 yNorm-0.001 1 0.001], 'String', titleText, ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'FontName', p.plot.fontName, ...
        'FontSize', p.plot.fontSize, 'Interpreter', 'none');
end

function add_colorbar(fig, lastAxes, panelWidthMM, colorLimits, labelText, L, p)
% Its own reserved column (L.colorbarGapMM + L.colorbarWidthMM +
% L.colorbarLabelMM), so adding it never touches lastAxes' Position --
% the plain colorbar(...) call is what shrank the rightmost panel before.
    lastLeftMM = lastAxes.Position(1) * L.figWidthMM;
    cbLeftMM   = lastLeftMM + panelWidthMM + L.colorbarGapMM;
    pos = mm_box_to_normalized(cbLeftMM, L.marginBottomMM, ...
        L.colorbarWidthMM, L.axesHeightMM, L);
    c = colorbar(lastAxes, 'Units', 'normalized', 'Position', pos);
    c.Limits = colorLimits;
    % Only three ticks: the two data-driven extremes and zero (always
    % included since the scale is built symmetric around it -- see
    % symmetric_color_limits), not whatever spacing MATLAB's default
    % automatic ticking would pick.
    c.Ticks = [colorLimits(1), 0, colorLimits(2)];
    % One decimal place on the two data-driven extremes, matching
    % p.plot.climRound (MATLAB's default was showing 4, e.g. '0.7000');
    % zero is special-cased to a bare '0' rather than '0.0'.
    c.TickLabels = arrayfun(@(v) sprintf('%.*f', p.plot.climRound, v), ...
        c.Ticks, 'UniformOutput', false);
    c.TickLabels{c.Ticks == 0} = '0';
    ylabel(c, labelText, 'FontName', p.plot.fontName, ...
        'FontSize', p.plot.labelFontSize, 'Rotation', 90);
    set(c, 'FontName', p.plot.fontName, 'FontSize', p.plot.tickFontSize);
end

function draw_mid_event_line(ax, midEventTime, p)
% Dashed vertical reference line at the FlxE/ExtS transition, spanning
% the full y range (XLINE tracks YLim automatically, including after it
% changes, so this doesn't need YLim passed in). FlxS and ExtE sit
% exactly at the axes' own left/right edges already, so only this
% interior event needs a line to actually be visible against the plot.
    xline(ax, midEventTime, 'LineStyle', '--', 'Color', p.plot.eventLineColor, ...
        'LineWidth', p.plot.eventLineWidth, 'HandleVisibility', 'off');
end

function outline_significant_regions(ax, sigMask, times, freqs, p)
% FREQS here is whatever the caller's y-axis is plotted in -- log10(Hz),
% per render_panel_row -- not Hz itself, so the outline lands on the
% same row positions as the image it traces.
    if isempty(sigMask) || ~any(sigMask(:))
        return
    end
    boundaries = bwboundaries(sigMask);
    for b = 1:numel(boundaries)
        rows = boundaries{b}(:,1);
        cols = boundaries{b}(:,2);
        plot(ax, times(cols), freqs(rows), '-', ...
            'Color', p.plot.maskColor, 'LineWidth', p.plot.maskLineWidth, ...
            'HandleVisibility', 'off');
    end
end

function limits = symmetric_color_limits(dataCells, p)
    parts = cell(1, numel(dataCells));
    for k = 1:numel(dataCells)
        if isempty(dataCells{k})
            continue
        end
        parts{k} = reshape(dataCells{k}.', 1, []);
    end
    values = [parts{:}];
    if isempty(values)
        limits = [-1 1];
        return
    end
    q1    = quantile(values, p.plot.climQuantile);
    lower = round(q1 - p.plot.climIqrScale * iqr(values), p.plot.climRound);
    if ~isfinite(lower) || lower == 0
        lower = -max(abs(values(isfinite(values))));
    end
    limits = sort([lower, -lower]);
end

function save_all_formats(fig, basePathNoExt, p)
% Vector formats (pdf/eps/svg) via EXPORTGRAPHICS/print preserve real text
% and vector line art; png (preview only, see ersp_params.m) is rasterized
% at p.plot.rasterDPI.
    for i = 1:numel(p.plot.formats)
        fmt = p.plot.formats{i};
        outFile = [basePathNoExt '.' fmt];
        switch fmt
            case 'png'
                exportgraphics(fig, outFile, 'Resolution', p.plot.rasterDPI);
            case {'pdf', 'eps'}
                exportgraphics(fig, outFile, 'ContentType', 'vector');
            case 'svg'
                print(fig, basePathNoExt, '-dsvg', '-vector');
            otherwise
                warning('plot_qc_sanity:UnknownFormat', ...
                    'Unrecognised format ''%s'' in p.plot.formats, skipped.', fmt);
        end
    end
end