function plot_figure3_primary_motor(data, p, outputPath)
% PLOT_FIGURE3_PRIMARY_MOTOR  Paper Figure 3: bilateral primary motor ERSPs.
%
%   PLOT_FIGURE3_PRIMARY_MOTOR(DATA, P, OUTPUTPATH)
%
% Two stacked cluster blocks (Left Prim Motor, Right Prim Motor). Each
% block is:
%   top-left     3D equivalent dipoles (STUDY's own DIPFIT result, via
%                std_dipplot)
%   bottom-left  cluster mean scalp topography (via std_topoplot)
%   top-right    ERSP row: 3 conditions + RM-ANOVA, same rendering
%                convention as plot_cluster_qc_sanity.m's conditions
%                figure (imagesc on log10(freq), manual axis titles)
%   bottom-right band-power-vs-cycle row: theta/alpha/beta/gamma, one
%                panel each -- a main axes (group mean +/- SEM per
%                condition, no per-subject traces) with a partial-eta-
%                squared strip beneath it, exactly mirroring
%                RESULTS_BEHAVIOUR.m's cyclePanel (Figure 2's muscle and
%                tracking-error panels)
%
% The ERSP row and band-power row share one column geometry (BUILD_ROW_SPEC,
% below): same left margin, same inter-panel gutter, same panel width, so
% the two rows' panels line up edge-to-edge -- both rows have 4 panels (3
% conditions + RM-ANOVA; theta/alpha/beta/gamma), and the shared spec is
% sized to the ERSP row's stricter requirement (it alone needs colorbar
% space) so both rows reserve that same width whether or not they draw a
% colorbar into it. Each row's own top/bottom margins (panel title, event
% labels) are still computed per row, since the band row additionally
% carries its own strip axes and neither row's own x axis shows tick
% labels any more (see render_ersp_row / render_band_power_row) -- only
% the eta^2 strip at the bottom of each block does, for the whole column.
% erspRowHeightMM and bandRowHeightMM (build_figure3_layout) need not be
% equal -- ERSP is the figure's focus and gets the taller share.
%
% This is a NEW, independent layout, not an edit to
% plot_cluster_qc_sanity.m -- it exists to embed EEGLAB's own
% dipplot/topoplot output rather than redraw a head cartoon by hand, and
% to fit two clusters' worth of panels into one figure. It duplicates a
% few small pieces of plot_cluster_qc_sanity.m (the mm-to-normalized
% conversion, the event-label/colour-limit/save-formats helpers) on
% purpose, rather than refactoring that already-approved file to share
% code with this one.
%
% DATA is produced by LOAD_FIGURE3_DATA(CFG, P) -- this function does no
% loading of its own on purpose. Loading a .study file pulls in its
% ALLEEG (the actual EEG data), which is slow; keeping that out of this
% function means you can call it over and over while tuning the layout
% below without paying that cost each time. Load DATA once, then re-run
% just this function (or the section in main_figure3_primary_motor.m
% that calls it).
%
% The whole figure is capped at 170 mm tall -- the verified Nature
% Portfolio maximum figure height (their research-figure-guide states
% this explicitly, "to allow space for the figure legend to fit
% underneath"). The ERSP row is the figure's focus, so it gets more of
% that height than the band-power row: 40 mm vs 32 mm, giving a ~31 mm
% ERSP axes and a ~13 mm band-power main axes (plus its 5 mm eta^2
% strip). Neither row carries its own "Cycle (%)" text or numeric x tick
% labels except the eta^2 strip at the very bottom of each block -- the
% ERSP row and the band-power row's main axes both sit directly above
% that one shared x axis and read off it (see render_ersp_row and
% render_band_power_row), and the band row no longer reserves a row for
% event labels (only the ERSP row shows FlxS/FlxE-ExtS/ExtE).
%
% No figure-wide legend is drawn for now -- DRAW_CONDITION_LEGEND is kept
% below, defined but unused, for whenever you want to place one.
%
% NOT YET RUN. embed_cluster_dipoles/embed_cluster_topoplot are still
% flagged below as unverified against your EEGLAB version -- run this,
% look at the output, and tell me what needs fixing.

    L = build_figure3_layout(p);
    widthIn  = L.figWidthMM  * p.plot.mmToInch;
    heightIn = L.figHeightMM * p.plot.mmToInch;
    fig = figure('Name', 'Figure 3: Primary motor clusters', 'Color', [1 1 1], ...
        'Units', 'inches', 'Position', [0 0 widthIn heightIn], ...
        'PaperUnits', 'inches', 'PaperSize', [widthIn heightIn], ...
        'PaperPosition', [0 0 widthIn heightIn]);
    if isfield(p.plot, 'renderer')
        set(fig, 'Renderer', p.plot.renderer);
    end
    set(fig, 'Colormap', ersp_colormap());

    for bi = 1:numel(data)
        blockTopMM = L.blocksStartMM + (bi-1)*(L.blockHeightMM + L.blockGapMM);
        isLastBlock = (bi == numel(data));
        render_cluster_block(fig, L, blockTopMM, bi, isLastBlock, data(bi).s, data(bi).STUDY, ...
            data(bi).ALLEEG, data(bi).clusterIdx, data(bi).bandStats, p);
    end

    if ~isfolder(outputPath)
        mkdir(outputPath);
    end
    save_all_formats(fig, fullfile(outputPath, 'figure3_primary_motor'), p);
    fprintf('Figure 3 saved to %s\n', outputPath);
end

%% ========================================================================
%  Layout: two stacked cluster blocks, each split left (dipole/topo) and
%  right (ERSP row / band-power row), fit exactly inside 170 mm tall
%  ========================================================================
function L = build_figure3_layout(p)
    L.figWidthMM  = p.plot.figureWidthMM;    % 180 mm, Nat Comms double column
    L.figHeightMM = 170;                     % verified Nature Portfolio max
                                              % figure height -- see this
                                              % file's header
    L.marginTopMM   = 4;
    L.blocksStartMM = L.marginTopMM;         % no legend row reserved for
                                              % now -- see draw_condition_legend
    L.legendRowMM = 5;    % NOT included in the budget below; kept only so
                           % draw_condition_legend still has something to
                           % use if you call it later. Adding it back into
                           % blocksStartMM will need shrinking something
                           % else, since figHeightMM is used with zero
                           % slack as it is.

    L.leftColWidthMM  = 32;   % dipole / topoplot column -- smaller than
                               % before (your call), so this no longer
                               % drives the block's overall height (see
                               % below); the freed width goes straight to
                               % the ERSP/band-power panels instead.
    L.colGapMM        = 4;
    L.rightColWidthMM = L.figWidthMM - L.leftColWidthMM - L.colGapMM;

    % Right column sets the block height now: ERSP row above band-power
    % row, ERSP getting the larger share (your earlier call) -- 40 mm vs
    % 32 mm.
    L.erspRowHeightMM = 40;
    L.bandRowHeightMM = 32;
    L.rowGapMM        = 3;
    L.blockHeightMM   = L.erspRowHeightMM + L.rowGapMM + L.bandRowHeightMM;   % 75

    % Left column: dipole plot above topoplot, smaller than the block
    % height they used to define -- render_cluster_block centers this
    % pair vertically inside the block instead of pinning it to the top
    % (your call), so it reads as sitting alongside the row pair rather
    % than stacked above it.
    L.dipoleHeightMM = 18;   % smaller than the topoplot now (your call) --
                              % leftColWidthMM is untouched, so the
                              % topoplot (still height-limited at 25 mm,
                              % well under the 32 mm column width) doesn't
                              % shrink along with it
    L.topoGapMM      = 3;
    L.topoHeightMM   = 25;
    L.leftColContentHeightMM = L.dipoleHeightMM + L.topoGapMM + L.topoHeightMM;   % 46
    assert(L.leftColContentHeightMM <= L.blockHeightMM, ...
        'build_figure3_layout:LeftColumnTallerThanBlock', ...
        'Left column content (%.0f mm) is taller than the block (%.0f mm) it needs to center inside.', ...
        L.leftColContentHeightMM, L.blockHeightMM);

    L.labelRowMM = 5;    % cluster name + n, above each block's content
    L.blockGapMM = 6;    % gap between the two clusters' blocks

    nBlocks = 2;
    totalNeeded = L.blocksStartMM + nBlocks*(L.labelRowMM + L.blockHeightMM) ...
        + (nBlocks-1)*L.blockGapMM;
    assert(totalNeeded <= L.figHeightMM, 'build_figure3_layout:HeightTooSmall', ...
        'Layout needs %.1f mm but figHeightMM is only %.1f (the verified 170 mm max) -- shrink a dimension above.', ...
        totalNeeded, L.figHeightMM);
end

%% ========================================================================
%  Shared column geometry for the ERSP row and the band-power row: same
%  left margin, same inter-panel gutter, same panel width, so panels in
%  both rows line up edge-to-edge. Sized to the ERSP row's requirements
%  (it alone needs colorbar space at the right) -- the band-power row
%  reserves the same width even though it draws no colorbar into it.
%  ========================================================================
function name = display_cluster_name(rawName, p)
% Manuscript wording for RAWNAME via p.plot.clusterDisplayNames. RAWNAME
% is s.name as the QC pipeline saved it, which is derived from the .study
% filename ('Right Prim Motor' from Right_Prim_Motor.study) and is a
% filename artifact rather than anatomy -- see the note on
% p.plot.clusterDisplayNames in ersp_params.m.
%
% Falls back to RAWNAME unchanged when the cluster isn't in the map (or
% the field doesn't exist at all), so adding a third cluster labels
% itself with its internal name rather than erroring -- ugly enough on
% the figure that you'll notice and add it to the map.
    name = rawName;
    if ~isfield(p.plot, 'clusterDisplayNames')
        return
    end
    hit = strcmp(p.plot.clusterDisplayNames(:, 1), rawName);
    if any(hit)
        name = p.plot.clusterDisplayNames{find(hit, 1), 2};
    end
end

function lbl = panel_label(idx, p)
% 'a', 'b', ... (or 'A', 'B', ... if p.plot.panelLabelCase is ever changed
% to 'upper') for the IDX-th cluster block, IDX starting at 1.
    if strcmpi(p.plot.panelLabelCase, 'lower')
        lbl = char('a' + idx - 1);
    else
        lbl = char('A' + idx - 1);
    end
end

function spec = build_row_spec(regionWidthMM, nPanel, p)
    spec.yTickRowMM  = 5;                    % numeric y tick labels
    spec.yLabelGapMM = p.plot.yLabelGapMM;
    spec.yLabelRowMM = 4;                    % the rotated axis-title text
    spec.marginLeftMM = spec.yTickRowMM + spec.yLabelGapMM + spec.yLabelRowMM;

    spec.panelGapMM = 2;                     % visual gap between panels
    spec.gutterMM   = spec.panelGapMM + spec.yTickRowMM;   % + next panel's
                                                            % own y ticks

    spec.colorbarGapMM   = 2;
    spec.colorbarWidthMM = 2.5;
    spec.colorbarLabelMM = 9;

    spec.panelWidthMM = (regionWidthMM - spec.marginLeftMM - (nPanel-1)*spec.gutterMM ...
        - spec.colorbarGapMM - spec.colorbarWidthMM - spec.colorbarLabelMM) / nPanel;
    assert(spec.panelWidthMM > 0, 'build_row_spec:WidthTooSmall', ...
        'Row width (%.0f mm) leaves no room for %d panels once margins and colorbar space are subtracted.', ...
        regionWidthMM, nPanel);
end

%% ========================================================================
%  One cluster's block: dipole + topoplot on the left, ERSP row and
%  band-power row on the right
%  ========================================================================
function render_cluster_block(fig, L, blockTopMM, panelIdx, isLastBlock, s, STUDY, ALLEEG, clusterIdx, bandStats, p)
    labelTopMM = L.figHeightMM - blockTopMM - L.labelRowMM;

    % Panel label (a, b, ... -- p.plot.panelLabelCase/FontSize/FontWeight,
    % same convention as every other Nat Comms subplot label in this
    % codebase), in its own small box to the left of the cluster title so
    % the two never overlap.
    letterWidthMM = 6;
    letterPos = mm_box_to_normalized_fig(0, labelTopMM, letterWidthMM, L.labelRowMM, L);
    annotation(fig, 'textbox', letterPos, 'String', panel_label(panelIdx, p), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', 'FontName', p.plot.fontName, ...
        'FontSize', p.plot.panelLabelFontSize, 'FontWeight', p.plot.panelLabelFontWeight, ...
        'Interpreter', 'none');

    figTitle = sprintf('%s (n = %d)', display_cluster_name(s.name, p), numel(s.subjects));
    titlePos = mm_box_to_normalized_fig(letterWidthMM, labelTopMM, ...
        L.figWidthMM - letterWidthMM, L.labelRowMM, L);
    annotation(fig, 'textbox', titlePos, 'String', figTitle, ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', 'FontName', p.plot.fontName, ...
        'FontSize', p.plot.fontSize, 'FontWeight', 'bold', 'Interpreter', 'none');

    contentTopMM = blockTopMM + L.labelRowMM;

    % --- left column: dipole (top) + topoplot (bottom), centered
    %     vertically inside the block rather than pinned to its top ------
    leftColTopMM = contentTopMM + (L.blockHeightMM - L.leftColContentHeightMM) / 2;
    dipolePos = mm_box_to_normalized_fig(0, ...
        L.figHeightMM - leftColTopMM - L.dipoleHeightMM, ...
        L.leftColWidthMM, L.dipoleHeightMM, L);
    embed_cluster_dipoles(fig, dipolePos, STUDY, ALLEEG, clusterIdx, p);

    topoTopMM = leftColTopMM + L.dipoleHeightMM + L.topoGapMM;
    topoPos = mm_box_to_normalized_fig(0, ...
        L.figHeightMM - topoTopMM - L.topoHeightMM, ...
        L.leftColWidthMM, L.topoHeightMM, L);
    embed_cluster_topoplot(fig, topoPos, STUDY, ALLEEG, clusterIdx, p);

    % --- right column: ERSP row, then band-power row, sharing one column
    %     geometry (build_row_spec) so their panels align ------------------
    rightLeftMM = L.leftColWidthMM + L.colGapMM;
    nPanel = numel(p.design.legend) + 1;   % 3 conditions + RM-ANOVA
    nBand  = numel(p.plot.bandNames);      % theta/alpha/beta/gamma
    assert(nPanel == nBand, 'render_cluster_block:PanelCountMismatch', ...
        ['ERSP row has %d panels and the band-power row has %d -- ' ...
         'build_row_spec assumes both rows share one panel count so their ' ...
         'columns align; reconcile p.design.legend/p.plot.bandNames or give ' ...
         'each row its own spec.'], nPanel, nBand);
    rowSpec = build_row_spec(L.rightColWidthMM, nPanel, p);

    erspRegion = struct('leftMM', rightLeftMM, 'topMM', contentTopMM, ...
        'widthMM', L.rightColWidthMM, 'heightMM', L.erspRowHeightMM);
    render_ersp_row(fig, L, erspRegion, rowSpec, s, p);

    bandRegion = struct('leftMM', rightLeftMM, ...
        'topMM', contentTopMM + L.erspRowHeightMM + L.rowGapMM, ...
        'widthMM', L.rightColWidthMM, 'heightMM', L.bandRowHeightMM);
    bandMainGeom = render_band_power_row(fig, L, bandRegion, rowSpec, s, bandStats, p);

    % The band-power row's panels are sized by the SAME rowSpec as the
    % ERSP row above, so they stop short of the region's right edge by
    % exactly rowSpec.colorbarGapMM + colorbarWidthMM + colorbarLabelMM --
    % the width render_ersp_row's real colorbar occupies directly above
    % this row. render_band_power_row draws nothing into that space, so
    % it sits empty here (your "gap below the color bar"). Condition
    % colours/labels are the same for every cluster, so one legend for
    % the whole figure is enough -- drawn once, in the LAST block's gap
    % (bottom of the figure), so it reads as a shared key for the whole
    % figure rather than something tied to the first cluster.
    if isLastBlock
        draw_band_row_legend(fig, L, bandRegion, bandMainGeom, rowSpec, nPanel, p);
    end
end

function draw_band_row_legend(fig, L, region, mainGeom, rowSpec, nPanel, p)
% Condition colour legend -- a short coloured line above its condition
% name, stacked vertically -- placed in the reserved-but-empty colorbar
% column at the right of REGION (a band-power row's region struct; see
% the caller). Same visual convention as DRAW_CONDITION_LEGEND (line +
% textbox via annotation() at explicit mm coordinates, not legend()),
% just stacked vertically here to fit the narrow gap instead of
% horizontally across the figure.
    labels = strrep(p.design.legend, ' Pressure', '');
    nCond  = numel(labels);

    gapLeftMM  = region.leftMM + rowSpec.marginLeftMM + nPanel*rowSpec.panelWidthMM ...
        + (nPanel-1)*rowSpec.gutterMM;
    gapWidthMM = rowSpec.colorbarGapMM + rowSpec.colorbarWidthMM + rowSpec.colorbarLabelMM;
    xCenterMM  = gapLeftMM + gapWidthMM/2;

    swatchWidthMM = min(8, gapWidthMM - 2);
    lineLeftMM    = xCenterMM - swatchWidthMM/2;
    lineRightMM   = xCenterMM + swatchWidthMM/2;

    % Spacing. Note that annotation textboxes carry a default Margin of 5
    % points (~1.8 mm) of internal padding on every side, on top of
    % whatever box you give them -- 'Margin', 0 below removes it, so the
    % two gaps here are the whole story rather than being added to
    % invisible padding.
    %
    % ITEMGAPMM is deliberately double SWATCHGAPMM: a label has to sit
    % closer to its OWN swatch than to the next condition's, or the eye
    % groups each label with the line beneath it instead of above it.
    % Raise them together if you want it looser still.
    labelHeightMM = 2.6;   % one line of p.plot.fontSize text, no padding
    swatchGapMM   = 0.8;   % swatch line to its own label
    itemHeightMM  = swatchGapMM + labelHeightMM;
    itemGapMM     = 1.6;   % between conditions
    totalHeightMM = nCond*itemHeightMM + (nCond-1)*itemGapMM;

    % Centered on the band-power MAIN axes, not on the whole row region
    % (which also spans the eta^2 strip and the x tick/label rows below
    % it, and would push the stack visibly low). Items are uniform, so
    % centering the whole stack puts the MIDDLE condition's line and
    % label exactly on the main axes' own centre line.
    firstTopMM = mainGeom.topMM + (mainGeom.heightMM - totalHeightMM) / 2;
    for c = 1:nCond
        itemTopMM = firstTopMM + (c-1)*(itemHeightMM + itemGapMM);

        lineStart = mm_box_to_normalized_fig(lineLeftMM, L.figHeightMM - itemTopMM, 0, 0, L);
        lineEnd   = mm_box_to_normalized_fig(lineRightMM, L.figHeightMM - itemTopMM, 0, 0, L);
        annotation(fig, 'line', [lineStart(1) lineEnd(1)], [lineStart(2) lineEnd(2)], ...
            'Color', p.design.colors(c, :), 'LineWidth', 1);   % matches the
                                                                 % condition
                                                                 % line width
                                                                 % in render_
                                                                 % band_power_row

        labelPos = mm_box_to_normalized_fig(gapLeftMM, ...
            L.figHeightMM - (itemTopMM + swatchGapMM + labelHeightMM), ...
            gapWidthMM, labelHeightMM, L);
        annotation(fig, 'textbox', labelPos, 'String', labels{c}, ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'Margin', 0, ...
            'FontName', p.plot.fontName, 'FontSize', p.plot.fontSize, ...
            'Interpreter', 'none');   % standard weight and size, same as
                                       % every other panel title
    end
end

%% ========================================================================
%  Dipole and topography panels: draw with EEGLAB's own STUDY functions,
%  then transplant the resulting axes into the Figure 3 canvas
%  ========================================================================
function embed_cluster_dipoles(targetFig, targetPos, STUDY, ALLEEG, clusterIdx, p)
% std_dipplot always opens its own figure (and, for 3D dipoles, its own
% rotatable axes plus lighting) -- there is no argument to draw into an
% existing target axes, so this copies the resulting axes across into
% TARGETFIG instead (same pattern as embed_cluster_topoplot below).
%
% A rasterize-and-embed version (rendering the source axes to a PNG via
% exportgraphics and displaying that as a plain image()) was tried here
% to fix blocky MRI slices, on the theory that TARGETFIG's forced
% 'painters' renderer was the culprit. It made the panel look WORSE --
% smaller and more pixelated -- so it's reverted; copyobj is back to
% being the whole mechanism. View, lighting and image smoothing are
% applied to the copied axes (not the source) since lighting in
% particular doesn't reliably survive copyobj otherwise.
    figsBefore = findobj(0, 'Type', 'figure');
    std_dipplot(STUDY, ALLEEG, 'clusters', clusterIdx, 'view', nice_3d_view());
    figsAfter = findobj(0, 'Type', 'figure');
    newFigs   = setdiff(figsAfter, figsBefore);
    if isempty(newFigs)
        warning('embed_cluster_dipoles:NoFigure', ...
            'std_dipplot did not open a new figure -- nothing to embed for cluster %d.', ...
            clusterIdx);
        return
    end

    srcAx = largest_axes(newFigs(1));
    newAx = copyobj(srcAx, targetFig);
    set(newAx, 'Units', 'normalized', 'Position', targetPos, ...
        'FontName', p.plot.fontName, 'FontSize', p.plot.tickFontSize);
    view(newAx, nice_3d_view());
    camlight(newAx);
    smooth_images(newAx);
    thin_dashed_lines(newAx, 0.15);   % as thin as still reliably visible;
                                       % the dipole markers/bodies
                                       % themselves are solid lines,
                                       % untouched by this filter
    close(newFigs);
end

function smooth_images(ax)
% Bilinear interpolation on every image object in AX (MRI slices here,
% same idea as render_ersp_row's imagesc smoothing). isprop guards
% MATLAB releases before R2022a, where Interpolation doesn't exist yet --
% silently no-ops there instead of erroring.
    imgs = findobj(ax, 'Type', 'image');
    for i = 1:numel(imgs)
        if isprop(imgs(i), 'Interpolation')
            imgs(i).Interpolation = 'bilinear';
        end
    end
end

function thin_dashed_lines(ax, newWidth)
% Sets LineWidth on every dashed Line object in AX -- dipplot's
% projection guide lines use LineStyle '--', while the dipole bodies
% themselves are solid, so this filter should reach only the guides. If
% your EEGLAB version draws the guides some other way (a different
% LineStyle, or as Patch objects), this will silently do nothing rather
% than touch the wrong thing -- tell me what you see and I'll retarget it.
    dashed = findobj(ax, 'Type', 'line', 'LineStyle', '--');
    if ~isempty(dashed)
        set(dashed, 'LineWidth', newWidth);
    end
end

function v = nice_3d_view()
% A general-purpose oblique 3D camera direction for dipplot's 'view'
% option (and for re-applying to the embedded axes) -- upper-front-right,
% which is what makes a head model actually read as three-dimensional
% instead of a flat top-down slice. Adjust this one place if you'd rather
% see it from a different angle.
    v = [1 -1 1];
end

function embed_cluster_topoplot(targetFig, targetPos, STUDY, ALLEEG, clusterIdx, p)
% Same copyobj pattern as embed_cluster_dipoles, for STUDY's own cluster
% mean scalp topography (std_topoplot). Same "not yet run" caveat.
%
% The odd-looking nose/ears you saw are topoplot()'s head cartoon drawn
% at its usual absolute line width (tuned for a normal-sized ~400-600 px
% MATLAB figure) inside a panel that's now only ~25 mm across -- the
% outline doesn't shrink with the axes, so it reads as chunky/oversized
% on the smaller head circle. CAP_HEAD_CARTOON_LINEWIDTH below caps every
% line/patch edge in the copied axes at a small fixed width instead.
    figsBefore = findobj(0, 'Type', 'figure');
    std_topoplot(STUDY, ALLEEG, 'clusters', clusterIdx);
    figsAfter = findobj(0, 'Type', 'figure');
    newFigs   = setdiff(figsAfter, figsBefore);
    if isempty(newFigs)
        warning('embed_cluster_topoplot:NoFigure', ...
            'std_topoplot did not open a new figure -- nothing to embed for cluster %d.', ...
            clusterIdx);
        return
    end

    srcAx = largest_axes(newFigs(1));
    newAx = copyobj(srcAx, targetFig);
    set(newAx, 'Units', 'normalized', 'Position', targetPos);
    title(newAx, '');   % std_topoplot's own per-cluster title is
                         % redundant with this block's suptitle
    cap_head_cartoon_linewidth(newAx, 0.75);
    close(newFigs);
end

function cap_head_cartoon_linewidth(ax, maxWidth)
% Caps LineWidth at MAXWIDTH on every line/patch-edge object in AX (head
% outline, nose, ears, electrode markers) that's currently thicker than
% that -- topoplot()'s cartoon is drawn at a fixed absolute width meant
% for a normal-sized figure, which reads as oversized once the axes
% shrinks to this panel's ~25 mm. Only ever thins lines, never thickens
% one that's already fine.
    els = findobj(ax, '-property', 'LineWidth');
    for i = 1:numel(els)
        if els(i).LineWidth > maxWidth
            els(i).LineWidth = maxWidth;
        end
    end
end

function ax = largest_axes(fig)
% Picks the axes with the largest on-screen area, in case the source
% figure carries a colorbar or legend axes alongside the main plot.
    candidates = findobj(fig, 'Type', 'axes');
    if isempty(candidates)
        error('largest_axes:NoAxes', 'No axes found in figure to embed.');
    end
    areas = arrayfun(@(a) a.Position(3) * a.Position(4), candidates);
    [~, biggest] = max(areas);
    ax = candidates(biggest);
end

%% ========================================================================
%  ERSP row: 3 conditions + RM-ANOVA, same rendering convention as
%  plot_cluster_qc_sanity.m, fitted into a sub-region instead of the
%  whole figure. Column geometry (left margin, gutter, panel width) comes
%  from ROWSPEC, shared with render_band_power_row so the two rows align.
%  ========================================================================
function render_ersp_row(fig, L, region, rowSpec, s, p)
% RM-ANOVA panel: plotted with the SAME shared colour scale and colormap
% as the three condition panels, exactly as plot_cluster_qc_sanity.m's
% conditions figure already does (see its Figure 1) -- this renders the
% 0/1 significance mask through the diverging dB colormap rather than a
% dedicated black/white one. Replicated here for consistency with the
% sanity check; tell me if the paper figure should treat this panel
% differently.
    % Figure 3's own panel titles drop the "Pressure" suffix that
    % p.design.legend carries for plot_cluster_qc_sanity.m and the
    % QC/stats text elsewhere -- matching Figure 2's convention of just
    % "Low"/"Medium"/"High" (the load itself is the physical-demand
    % manipulation, not a pressure reading the reader needs spelled out
    % here). p.design.legend itself is left untouched since other,
    % already-approved output still needs the full wording.
    panelTitles = [strrep(p.design.legend, ' Pressure', ''), ...
        {sprintf('RM-ANOVA (p<%g)', s.alpha)}];
    panelData   = [s.erspdata.mean(:)', {double(s.condMask{1,1})}];
    colorLimits = symmetric_color_limits(s.erspdata.mean, p);
    nPanel = numel(panelTitles);

    panelTitleRowMM = 4;
    eventLabelRowMM = 5;
    % No x tick numbers and no "Cycle (%)" text here at all (your call) --
    % the eta^2 strip at the bottom of the band-power row, directly below
    % this row in the same column, is this whole column's one shared x
    % axis; the reader reads cycle position off that. marginBottomMM is
    % therefore 0: the axes' bottom edge is the row's bottom edge.
    marginLeftMM   = rowSpec.marginLeftMM;
    gutterMM       = rowSpec.gutterMM;
    panelWidthMM   = rowSpec.panelWidthMM;
    marginBottomMM = 0;
    topMarginMM    = panelTitleRowMM + eventLabelRowMM;
    axesHeightMM   = region.heightMM - topMarginMM - marginBottomMM;
    assert(axesHeightMM > 0, 'render_ersp_row:HeightTooSmall', ...
        'ERSP row region height (%.1f mm) leaves no room for the axes.', region.heightMM);

    % Crop the displayed frequency range to p.plot.ersp3FreqYLimHz (~65 Hz)
    % instead of the full freqTicks range up to 120 Hz -- a YLim/YTick
    % change only, the underlying imagesc data is untouched.
    eventTimes  = [s.allTimes(1), s.eventTimes(2), s.allTimes(end)];
    logFreqs    = log10(s.allFreqs);
    freqTicksHz = p.plot.freqTicks(p.plot.freqTicks <= p.plot.ersp3FreqYLimHz);
    logFreqTick = log10(freqTicksHz);
    logFreqYLimTop = log10(p.plot.ersp3FreqYLimHz);
    bottomMM = L.figHeightMM - (region.topMM + topMarginMM + axesHeightMM);

    axesHandles = gobjects(1, nPanel);
    for ci = 1:nPanel
        leftMM = region.leftMM + marginLeftMM + (ci-1)*(panelWidthMM + gutterMM);
        pos = mm_box_to_normalized_fig(leftMM, bottomMM, panelWidthMM, axesHeightMM, L);
        axesHandles(ci) = axes('Parent', fig, 'Units', 'normalized', 'Position', pos);

        im = imagesc(axesHandles(ci), s.allTimes, logFreqs, panelData{ci});
        set(axesHandles(ci), 'YDir', 'normal');
        if isprop(im, 'Interpolation')
            im.Interpolation = 'bilinear';
        end
        draw_mid_event_line(axesHandles(ci), eventTimes(2), p);
        uistack(im, 'bottom');

        set(axesHandles(ci), 'CLim', colorLimits, ...
            'XLim', [s.allTimes(1) s.allTimes(end)], ...
            'YLim', [logFreqs(1) logFreqYLimTop], 'YDir', 'normal', ...
            'YTick', logFreqTick, 'YTickLabel', arrayfun(@(f) sprintf('%g', f), ...
                freqTicksHz, 'UniformOutput', false), ...
            'YMinorTick', 'off', ...
            'XTick', [s.allTimes(1) s.eventTimes(2) s.allTimes(end)], ...
            'XTickLabel', [], ...   % ticks belong to the eta^2 strip at the bottom of this column
            'FontName', p.plot.fontName, 'FontSize', p.plot.tickFontSize, ...
            'Box', 'on', 'Layer', 'top');

        yNormTitle = 1 + (eventLabelRowMM + panelTitleRowMM/2) / axesHeightMM;
        text(axesHandles(ci), 0.5, yNormTitle, panelTitles{ci}, 'Units', 'normalized', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontName', p.plot.fontName, 'FontSize', p.plot.fontSize, 'Clipping', 'off');

        draw_event_labels(axesHandles(ci), eventTimes, s.allTimes, eventLabelRowMM, axesHeightMM, p);

        if ci == 1
            xNormY = -(rowSpec.yTickRowMM + rowSpec.yLabelGapMM + rowSpec.yLabelRowMM/2) / panelWidthMM;
            text(axesHandles(ci), xNormY, 0.5, 'Frequency (Hz)', 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'Rotation', 90, 'FontName', p.plot.fontName, ...
                'FontSize', p.plot.labelFontSize, 'Clipping', 'off');
        end
    end

    lastLeftMM = region.leftMM + marginLeftMM + (nPanel-1)*(panelWidthMM + gutterMM);
    cbLeftMM   = lastLeftMM + panelWidthMM + rowSpec.colorbarGapMM;
    cbPos = mm_box_to_normalized_fig(cbLeftMM, bottomMM, rowSpec.colorbarWidthMM, axesHeightMM, L);
    c = colorbar(axesHandles(end), 'Units', 'normalized', 'Position', cbPos);
    c.Limits = colorLimits;
    c.Ticks  = [colorLimits(1), 0, colorLimits(2)];
    c.TickLabels = arrayfun(@(v) sprintf('%.*f', p.plot.climRound, v), ...
        c.Ticks, 'UniformOutput', false);
    c.TickLabels{c.Ticks == 0} = '0';
    ylabel(c, 'Baseline-corrected power (dB)', 'FontName', p.plot.fontName, ...
        'FontSize', p.plot.labelFontSize, 'Rotation', 90);
    set(c, 'FontName', p.plot.fontName, 'FontSize', p.plot.tickFontSize);
end

%% ========================================================================
%  Band-power-vs-cycle row: theta/alpha/beta/gamma, each a main axes
%  (group mean +/- SEM) with a partial-eta-squared strip beneath it.
%  Column geometry (left margin, gutter, panel width) comes from ROWSPEC,
%  the SAME spec render_ersp_row uses, so panels in both rows align.
%  ========================================================================
function mainGeom = render_band_power_row(fig, L, region, rowSpec, s, bandStats, p)
% Returns MAINGEOM (.topMM, .heightMM) describing the row's MAIN axes --
% the group mean +/- SEM axes, excluding the eta^2 strip below it and the
% x tick/label rows below that. DRAW_BAND_ROW_LEGEND uses it to center
% the legend on those axes rather than on the whole row region, so the
% middle condition lines up with the middle of the band-power panels
% themselves. Returned rather than recomputed there so the two can't
% drift apart.
% Mirrors RESULTS_BEHAVIOUR.m's cyclePanel exactly (Figure 2's muscle and
% tracking-error panels): a main axes showing group mean +/- SEM per
% condition (no per-subject traces, no x tick labels -- those belong to
% the strip), and a short strip axes below it showing the partial
% eta-squared trace, a dotted p.bandStats.etaThreshold reference line,
% and black bars marking clusters that survive cluster-based permutation
% (p < p.bandStats.alpha). The test itself (CLUSTER_PERM_1D, the same
% RM-ANOVA-F / condition-permutation test as Figure 2's
% clusterTest/rmF/clusterMass) was already run once per band in
% LOAD_FIGURE3_DATA -- BANDSTATS is its output, not recomputed here.
    nBand = numel(bandStats);
    nCond = numel(s.conditionOrder);
    condColors = p.design.colors(1:nCond, :);

    panelTitleRowMM = 4;    % no event-label row here -- FlxS/FlxE-ExtS/ExtE
                             % are only drawn on the ERSP row above (your
                             % call: the band-power row doesn't need them)
    stripGapMM    = 1;      % gap between the main axes and its strip
    stripHeightMM = 5;      % the eta-squared strip, small on purpose --
                             % Figure 2's is about a fifth of its main axes
    xTickRowMM  = 3;
    xLabelGapMM = p.plot.xLabelGapMM;
    xLabelRowMM = 4;

    marginLeftMM   = rowSpec.marginLeftMM;
    gutterMM       = rowSpec.gutterMM;
    panelWidthMM   = rowSpec.panelWidthMM;
    marginBottomMM = xTickRowMM + xLabelGapMM + xLabelRowMM;   % below the strip --
                                                                % the one shared
                                                                % "Cycle (%)" label
                                                                % for this whole column
    topMarginMM    = panelTitleRowMM;                          % above the main axes
    availableHeightMM = region.heightMM - topMarginMM - marginBottomMM;
    mainHeightMM = availableHeightMM - stripGapMM - stripHeightMM;
    assert(mainHeightMM > 0, 'render_band_power_row:HeightTooSmall', ...
        'Band-power row region height (%.1f mm) leaves no room for the main axes.', ...
        region.heightMM);

    % Same y limits on every band panel in this cluster (your request), so
    % the relative size of each band's modulation reads directly off the
    % shared scale instead of each panel silently rescaling itself. Only
    % 3 y ticks (-max, 0, max, at a rounded "nice" value) rather than
    % MATLAB's automatic 5 -- at this axes' height (~13 mm) 5 auto tick
    % labels sit close enough to touch; 3, with headroom in the ylim so
    % they don't sit flush against the box edges, was the actual fix
    % (increasing the ylim's padding alone doesn't change how many ticks
    % MATLAB draws into that same short axes).
    [bandYLim, bandYTick] = shared_band_ylimits(bandStats);

    eventTimes    = [s.allTimes(1), s.eventTimes(2), s.allTimes(end)];
    mainTopMM     = region.topMM + topMarginMM;
    mainBottomMM  = L.figHeightMM - (mainTopMM + mainHeightMM);
    stripTopMM    = mainTopMM + mainHeightMM + stripGapMM;
    stripBottomMM = L.figHeightMM - (stripTopMM + stripHeightMM);

    for bi = 1:nBand
        leftMM = region.leftMM + marginLeftMM + (bi-1)*(panelWidthMM + gutterMM);

        % ---- main axes: group mean +/- SEM ---------------------------
        mainPos = mm_box_to_normalized_fig(leftMM, mainBottomMM, panelWidthMM, mainHeightMM, L);
        axM = axes('Parent', fig, 'Units', 'normalized', 'Position', mainPos);
        hold(axM, 'on');
        for c = 1:nCond
            gm = bandStats(bi).groupMean(:, c);
            ge = bandStats(bi).groupSEM(:, c);
            fill(axM, [s.allTimes, fliplr(s.allTimes)], ...
                [(gm + ge)', fliplr((gm - ge)')], condColors(c, :), ...
                'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
        for c = 1:nCond
            plot(axM, s.allTimes, bandStats(bi).groupMean(:, c), '-', ...
                'Color', condColors(c, :), 'LineWidth', 1, 'HandleVisibility', 'off');
        end
        draw_mid_event_line(axM, eventTimes(2), p);
        set(axM, 'XLim', [s.allTimes(1) s.allTimes(end)], ...
            'XTick', [s.allTimes(1) s.eventTimes(2) s.allTimes(end)], ...
            'XTickLabel', [], ...   % ticks belong to the strip below
            'YLim', bandYLim, 'YTick', bandYTick, ...
            'YTickLabel', arrayfun(@(v) sprintf('%g', v), bandYTick, 'UniformOutput', false), ...
            'FontName', p.plot.fontName, 'FontSize', p.plot.tickFontSize, ...
            'Box', 'on', 'Layer', 'top');

        yNormTitle = 1 + (panelTitleRowMM/2) / mainHeightMM;
        text(axM, 0.5, yNormTitle, bandStats(bi).name, 'Units', 'normalized', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontName', p.plot.fontName, 'FontSize', p.plot.fontSize, 'Clipping', 'off');

        if bi == 1
            xNormY = -(rowSpec.yTickRowMM + rowSpec.yLabelGapMM + rowSpec.yLabelRowMM/2) / panelWidthMM;
            text(axM, xNormY, 0.5, 'Power (dB)', 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'Rotation', 90, 'FontName', p.plot.fontName, ...
                'FontSize', p.plot.labelFontSize, 'Clipping', 'off');
        end

        % ---- strip axes: partial eta-squared + significant clusters ---
        stripPos = mm_box_to_normalized_fig(leftMM, stripBottomMM, panelWidthMM, stripHeightMM, L);
        axS = axes('Parent', fig, 'Units', 'normalized', 'Position', stripPos);
        hold(axS, 'on');
        plot(axS, s.allTimes, bandStats(bi).eta2p, '-', ...
            'Color', [0.25 0.25 0.25], 'LineWidth', 0.7);
        plot(axS, [s.allTimes(1) s.allTimes(end)], ...
            [p.bandStats.etaThreshold p.bandStats.etaThreshold], ':', ...
            'Color', [0.5 0.5 0.5], 'LineWidth', p.plot.axisLineWidth, ...
            'HandleVisibility', 'off');
        draw_mid_event_line(axS, eventTimes(2), p);
        clust = bandStats(bi).clust;
        if ~isempty(clust)
            sig = clust(clust.p < p.bandStats.alpha, :);
            for k = 1:height(sig)
                plot(axS, [s.allTimes(sig.StartIdx(k)) s.allTimes(sig.EndIdx(k))], ...
                    [-0.08 -0.08], 'k-', 'LineWidth', 1.8, 'HandleVisibility', 'off');
            end
        end
        ylim(axS, [-0.16 1]);
        set(axS, 'XLim', [s.allTimes(1) s.allTimes(end)], ...
            'XTick', [s.allTimes(1) s.eventTimes(2) s.allTimes(end)], ...
            'XTickLabel', p.plot.cycleTicks, 'YTick', [0 1], ...
            'FontName', p.plot.fontName, 'FontSize', p.plot.tickFontSize, ...
            'Box', 'off', 'Layer', 'top');

        yNormX = -(xTickRowMM + xLabelGapMM + xLabelRowMM/2) / stripHeightMM;
        text(axS, 0.5, yNormX, p.plot.xLabel, 'Units', 'normalized', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontName', p.plot.fontName, 'FontSize', p.plot.labelFontSize, 'Clipping', 'off');

        if bi == 1
            xNormEta = -(rowSpec.yTickRowMM + rowSpec.yLabelGapMM + rowSpec.yLabelRowMM/2) / panelWidthMM;
            text(axS, xNormEta, 0.5, '\eta^2_p', 'Units', 'normalized', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'Rotation', 90, 'FontName', p.plot.fontName, ...
                'FontSize', p.plot.labelFontSize, 'Clipping', 'off');
        end
    end

    mainGeom = struct('topMM', mainTopMM, 'heightMM', mainHeightMM);
end

%% ========================================================================
%  Condition colour key: one manual legend for the whole figure. NOT
%  called for now (see this file's header) -- kept defined so you have it
%  ready once a placement is decided.
%  ========================================================================
function draw_condition_legend(fig, L, p)
% Drawn ONCE for the whole figure with annotation() at explicit mm
% coordinates, not legend() on any one axes. legend() with an outside
% Location automatically shrinks/repositions its host axes to make room
% for itself -- exactly the kind of automatic placement every other piece
% of text in this figure deliberately avoids, and what broke the
% band-power row's layout in the first draft.
    nCond = size(p.design.colors, 1);
    swatchWidthMM = 6;
    swatchGapMM   = 2;
    labelWidthMM  = 24;
    itemGapMM     = 6;

    totalWidthMM = nCond*(swatchWidthMM + swatchGapMM + labelWidthMM) ...
        + (nCond-1)*itemGapMM;
    xMM = (L.figWidthMM - totalWidthMM) / 2;
    yMM = L.figHeightMM - L.marginTopMM - L.legendRowMM/2;

    for c = 1:nCond
        lineStart = mm_box_to_normalized_fig(xMM, yMM, 0, 0, L);
        lineEnd   = mm_box_to_normalized_fig(xMM + swatchWidthMM, yMM, 0, 0, L);
        annotation(fig, 'line', [lineStart(1) lineEnd(1)], [lineStart(2) lineEnd(2)], ...
            'Color', p.design.colors(c, :), 'LineWidth', 1.5);

        labelLeftMM = xMM + swatchWidthMM + swatchGapMM;
        labelPos = mm_box_to_normalized_fig(labelLeftMM, ...
            yMM - L.legendRowMM/2, labelWidthMM, L.legendRowMM, L);
        annotation(fig, 'textbox', labelPos, 'String', p.design.legend{c}, ...
            'EdgeColor', 'none', 'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle', 'FontName', p.plot.fontName, ...
            'FontSize', p.plot.fontSize);

        xMM = labelLeftMM + labelWidthMM + itemGapMM;
    end
end

%% ========================================================================
%  Small shared helpers (duplicated from plot_cluster_qc_sanity.m on
%  purpose -- see the file header)
%  ========================================================================
function pos = mm_box_to_normalized_fig(leftMM, bottomMM, widthMM, heightMM, L)
    pos = [leftMM/L.figWidthMM, bottomMM/L.figHeightMM, ...
           widthMM/L.figWidthMM, heightMM/L.figHeightMM];
end

function draw_mid_event_line(ax, midEventTime, p)
    xline(ax, midEventTime, 'LineStyle', '--', 'Color', p.plot.eventLineColor, ...
        'LineWidth', p.plot.eventLineWidth, 'HandleVisibility', 'off');
end

function draw_event_labels(ax, eventTimes, allTimes, eventLabelRowMM, axesHeightMM, p)
% Rotated FlxS / FlxE-ExtS / ExtE labels, in their own row directly above
% the axes (below the panel title row) -- same convention as
% plot_cluster_qc_sanity.m's draw_event_labels, parameterised here on the
% caller's own eventLabelRowMM/axesHeightMM instead of a shared L struct,
% since render_ersp_row and render_band_power_row each have their own
% axes height.
%
% FlxS (first event) and ExtE (last event) fall exactly at the axes'
% left/right edges; p.plot.eventLabelInsetFrac shifts just their LABEL
% text inward by that fraction of the cycle width so it doesn't print
% flush against the panel border. FlxE/ExtS, already inside the axes, is
% left exactly where it is.
    yNorm = 1 + (eventLabelRowMM/2) / axesHeightMM;
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

function [limits, ticks] = shared_band_ylimits(bandStats)
% One y limit -- and one set of y ticks -- for every band panel in a
% cluster (main axes only; the eta^2 strip below already uses a fixed
% [-0.16 1] range), symmetric around zero like the ERSP row's colour
% limits. Built from group mean +/- SEM across every band, condition and
% time point, so the shaded error band never clips.
%
% TICKS is [-v 0 v] for V rounded up to the nearest ROUNDSTEP (see
% NICE_ROUND) -- 3 ticks, not MATLAB's automatic 5, which is what
% actually stops the tick labels overlapping on this row's short
% (~13 mm) main axes. LIMITS then extends ONE MORE ROUNDSTEP past that
% tick on each side (e.g. tick at 2 -> limit at 2.5) -- a fixed amount of
% headroom, not a percentage of V, so the ticks/traces never sit flush
% against the box edges regardless of the cluster's own scale. Rounding
% to the nearest 0.5 (rather than jumping to the next 1/2/5/10 "nice"
% step) is deliberate: it stays close to each cluster's own actual data
% range instead of inflating a tighter cluster (e.g. Left Prim Motor,
% whose alpha modulation is real but smaller) up to match a wider one
% (Right Prim Motor), which is what washed out the visible
% between-condition gap in Left's alpha panel in an earlier version.
    roundStep = 0.5;
    vals = [];
    for bi = 1:numel(bandStats)
        gm = bandStats(bi).groupMean;
        ge = bandStats(bi).groupSEM;
        vals = [vals; reshape(gm + ge, [], 1); reshape(gm - ge, [], 1)]; %#ok<AGROW>
    end
    vals = vals(isfinite(vals));
    if isempty(vals)
        ticks  = [-roundStep 0 roundStep];
        limits = [-2*roundStep 2*roundStep];
        return
    end
    v = nice_round(max(abs(vals)), roundStep);
    % Tick LABELS are whole numbers -- floor(v) -- even when V itself
    % (and therefore LIMITS, unchanged below) landed on a half-step, e.g.
    % V = 1.5 labels its tick as 1, not 1.5, while still leaving the same
    % amount of headroom above it. Right Prim Motor's V is already a
    % whole number most of the time, so this doesn't change it. Guard
    % against V < 1 (floor would give 0, an unusable tick set).
    tickVal = floor(v);
    if tickVal == 0
        tickVal = v;
    end
    ticks  = [-tickVal 0 tickVal];
    limits = [-(v + roundStep), (v + roundStep)];
end

function v = nice_round(x, step)
% Rounds X up to the nearest STEP -- close enough to the actual data that
% a tight cluster stays visibly tight (see the note above on why this
% isn't a bigger jump like the nearest {1, 2, 5, 10}).
    if x <= 0
        v = step;
        return
    end
    v = ceil(x / step) * step;
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
                warning('plot_figure3_primary_motor:UnknownFormat', ...
                    'Unrecognised format ''%s'' in p.plot.formats, skipped.', fmt);
        end
    end
end