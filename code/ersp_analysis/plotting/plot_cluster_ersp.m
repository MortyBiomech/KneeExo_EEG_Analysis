function results = plot_cluster_ersp(STUDY, ALLEEG, clustersToPlot, p, opts)
% PLOT_CLUSTER_ERSP  Cluster ERSPs by condition, with cluster-based statistics.
%
%   RESULTS = PLOT_CLUSTER_ERSP(STUDY, ALLEEG, CLUSTERSTOPLOT, P, OPTS)
%
%   CLUSTERSTOPLOT  cluster indices to process
%   P               parameter struct from ersp_params()
%   OPTS            struct:
%     .studyTitle        name used in titles and file names
%     .outDir            folder to write figures into
%     .erspParamOverride ERSP parameters as a key/value cell array, read
%                        from one of the .icatimef files, so that the plot
%                        is described by the parameters the data were
%                        actually computed with. [] to use the STUDY's own.
%     .savePlots         true (default) or false
%
%   RESULTS  struct with one .data element per cluster, holding the ERSPs,
%            the condition means, the difference ERSPs, the significance
%            masks, the cluster p-value maps and the effect sizes.
%
% Two figures per cluster:
%   1. one panel per condition (P1/P3/P6) plus a panel showing where the
%      omnibus test across conditions is significant
%   2. one panel per condition difference against the reference condition,
%      with significant clusters outlined
%
% Both use a log frequency axis and an x axis running over one time-warped
% flexion-to-flexion movement cycle, labelled 0-100 %.
%
% Origin: my_plotERSPSfromSTUDY, in turn from plotERSPSfromSTUDY by
% Noelle Jacobsen (University of Florida), adapted for this study.
%
% -------------------------------------------------------------------------
% What changed relative to my_plotERSPSfromSTUDY
% -------------------------------------------------------------------------
% The FIGURES are unchanged: same data, same statistics, same layout. The
% changes are to code that was either dead, or that wrote fields of the
% results struct which the figures never read.
%
%  1. SIGNIFICANCE MASK POLARITY. With an alpha set, std_stat returns PCOND
%     as a logical mask in which 1 means SIGNIFICANT. Three places treated
%     it as a p-value and tested "pcond < alpha", which selects the
%     complement:
%       - erspDiff.masked kept the non-significant pixels and zeroed the
%         significant ones, the opposite of its name;
%       - pval(pcond==1) = 1 blanked the p-values of significant pixels, so
%         the effect sizes computed next described non-significant regions;
%       - the stored cluster_perm_test.pval was inverted the same way.
%     The plotted difference figures were never affected: they draw the
%     unmasked difference and outline significance with BWBOUNDARIES on the
%     mask itself, which is correct. Nor did it reach the manuscript, whose
%     figures recompute their statistics in rm_anova_cluster_based.m. All
%     three are corrected here, so the effect sizes and the masked fields
%     in RESULTS are now meaningful.
%
%  2. ALPHA was set to 0.05 at the top and then reassigned to 0.01 three
%     times inside the loop. It is now one value, p.stats.alpha.
%
%  3. ERSP PARAMETER OVERRIDE was converted from cell array to struct
%     INSIDE the cluster loop, overwriting the cell array it read from. A
%     second cluster in the same call would have errored on the struct.
%     This survived only because each ROI selects exactly one cluster. The
%     conversion now happens once, before the loop.
%
%  4. DEAD CODE removed: the catch block began with RETHROW, so its recovery
%     code could never run; three local functions (plot1cond, formatFig,
%     updateTransparency) were left over from the gait study this was forked
%     from and were never called; a local erspStats shadowed an identical
%     file of the same name.
%
%  5. Figures are saved through SAVE_FIGURE, which does not change the
%     working directory, and event markers through DRAW_TIMEWARP_EVENTS,
%     which places labels directly instead of fishing text objects out of
%     the figure and nudging them by index.
% -------------------------------------------------------------------------

    if ~isfield(opts, 'savePlots') || isempty(opts.savePlots)
        opts.savePlots = true;
    end
    if ~isfield(opts, 'erspParamOverride')
        opts.erspParamOverride = [];
    end

    design = STUDY.currentdesign;
    conditionValues = STUDY.design(design).variable(1).value;

    refIdx = find(strcmp(p.design.reference, conditionValues), 1);
    if isempty(refIdx)
        error('plot_cluster_ersp:NoReference', ...
            'Reference condition ''%s'' is not in the STUDY design.', ...
            p.design.reference);
    end

    % Warp-event latencies, used both for the statistics time range and for
    % the event markers drawn on every panel.
    eventTimes = group_median_warpto(ALLEEG, p.ersp.warpRoundToMs);
    assert(numel(eventTimes) == numel(p.plot.eventLabels), ...
        'plot_cluster_ersp:EventLabelMismatch', ...
        ['The epochs carry %d time-warp events but p.plot.eventLabels has ' ...
         '%d entries.'], numel(eventTimes), numel(p.plot.eventLabels));

    % Convert the override once, not once per cluster.
    erspParamStruct = [];
    if ~isempty(opts.erspParamOverride)
        erspParamStruct = keyvalue_to_struct(opts.erspParamOverride);
    end

    STUDY = apply_stat_params(STUDY, p, eventTimes);

    results = struct();
    results.name           = opts.studyTitle;
    results.design         = design;
    results.design_name    = STUDY.design(design).name;
    results.variable       = STUDY.design(design).variable;
    results.conditionOrder = p.design.values;
    results.alpha          = p.stats.alpha;

    for k = 1:numel(clustersToPlot)
        CL = clustersToPlot(k);
        label = cluster_label(STUDY, CL);
        fprintf('\nCluster %d (%s)\n', CL, label);

        s = process_one_cluster(STUDY, ALLEEG, CL, p, erspParamStruct, refIdx);
        s.CL_num = CL;
        s.label  = label;

        if opts.savePlots
            plot_conditions_figure(s, p, opts, CL, label, eventTimes);
            plot_differences_figure(s, p, opts, CL, label, eventTimes);
        end

        results.data(k) = s;
    end
end


%% ========================================================================
%  Per-cluster computation
%  ========================================================================
function s = process_one_cluster(STUDY, ALLEEG, CL, p, erspParamStruct, refIdx)

    % --- read the ERSPs and the omnibus test across conditions ------------
    if isempty(erspParamStruct)
        [~, allersp, allTimes, allFreqs, ~, condMask] = std_erspplot( ...
            STUDY, ALLEEG, 'clusters', CL, 'logfreq', 'on', ...
            'subtractsubjectmean', p.stats.subtractSubjectMean);
    else
        [~, allersp, allTimes, allFreqs, ~, condMask] = std_erspplot_myparams( ...
            STUDY, ALLEEG, erspParamStruct, 'clusters', CL, 'logfreq', 'on', ...
            'subtractsubjectmean', p.stats.subtractSubjectMean);
    end
    close(gcf);   % std_erspplot draws as a side effect; we redraw below

    % condMask{1,g} is a logical mask over [freq x time]: 1 means the three
    % conditions differ significantly at that pixel.
    condMask = to_logical_masks(condMask);

    % --- one observation per subject --------------------------------------
    allersp = consolidate_by_subject(STUDY, CL, allersp);

    nCond  = size(allersp, 1);
    nGroup = size(allersp, 2);

    % --- condition means ---------------------------------------------------
    ersp.raw  = cell(nCond, nGroup);
    ersp.mean = cell(nCond, nGroup);
    for ci = 1:nCond
        for gi = 1:nGroup
            ersp.raw{ci,gi}  = allersp{ci,gi};
            ersp.mean{ci,gi} = mean(allersp{ci,gi}, 3);
        end
    end

    % --- difference ERSPs against the reference condition -------------------
    compareIdx = setdiff(1:nCond, refIdx);
    erspDiff.raw     = cell(nCond, nGroup);
    erspDiff.mean    = cell(nCond, nGroup);
    erspDiff.masked  = cell(nCond, nGroup);
    erspDiff.sigMask = cell(nCond, nGroup);

    permTest = struct('name', {}, 'freqrange', {}, 'pval', {}, ...
                      'sigMask', {}, 'effect', {});
    permTest(1).name      = 'omnibus across conditions';
    permTest(1).freqrange = p.plot.freqRange;
    permTest(1).sigMask   = condMask;
    permTest(1).pval      = [];
    permTest(1).effect    = [];

    anySignificant = any(cellfun(@(m) any(m(:)), condMask));
    conditionNames = STUDY.design(STUDY.currentdesign).variable(1).value;

    for ci = compareIdx
        for gi = 1:nGroup
            testErsp = allersp{ci,gi};
            refErsp  = allersp{refIdx,gi};

            erspDiff.raw{ci,gi}  = testErsp - refErsp;
            erspDiff.mean{ci,gi} = mean(testErsp - refErsp, 3);

            if ~strcmpi(p.stats.condStats, 'on') || ~anySignificant
                % No omnibus effect anywhere, so the pairwise tests are not
                % run -- as in the original, which gated on the same thing.
                erspDiff.sigMask{ci,gi} = false(size(erspDiff.mean{ci,gi}));
                erspDiff.masked{ci,gi}  = zeros(size(erspDiff.mean{ci,gi}));
                continue
            end

            [pairMask, ~, ~, pairPval] = ersp_cluster_stats( ...
                STUDY, {testErsp; refErsp});

            sigMask = logical(pairMask{1,1});
            pvalMap = pairPval;
            if iscell(pvalMap)
                pvalMap = pvalMap{1,1};
            end

            % FIX (1): keep the p-values INSIDE significant clusters and
            % blank everything else. The original did the reverse.
            pvalMap(~sigMask) = 1;

            erspDiff.sigMask{ci,gi} = sigMask;
            erspDiff.masked{ci,gi}  = erspDiff.mean{ci,gi} .* sigMask;

            entry = numel(permTest) + 1;
            permTest(entry).name = sprintf('%s vs %s', ...
                conditionNames{ci}, conditionNames{refIdx});
            permTest(entry).freqrange = p.plot.freqRange;
            permTest(entry).pval      = pvalMap;
            permTest(entry).sigMask   = sigMask;

            if any(pvalMap(:) < p.stats.alpha)
                permTest(entry).effect = cluster_effect_size( ...
                    {testErsp; refErsp}, pvalMap, allTimes, allFreqs, ...
                    p.effect.method);
            else
                permTest(entry).effect = [];
            end
        end
    end

    % --- put the conditions in the order the figures use --------------------
    order = zeros(1, numel(p.design.values));
    for ci = 1:numel(p.design.values)
        hit = find(strcmp(p.design.values{ci}, conditionNames), 1);
        if isempty(hit)
            error('plot_cluster_ersp:UnknownCondition', ...
                'Condition ''%s'' is not in the STUDY design.', p.design.values{ci});
        end
        order(ci) = hit;
    end

    s.allTimes   = allTimes;
    s.allFreqs   = allFreqs;
    s.condMask   = condMask;
    s.allersp    = allersp(order, :);
    s.erspdata   = reorder_struct(ersp,     order, {'mean', 'raw'});
    s.erspDiff   = reorder_struct(erspDiff, order, ...
                                  {'raw', 'mean', 'masked', 'sigMask'});
    s.refIdx     = find(order == refIdx, 1);
    s.compareIdx = setdiff(1:numel(order), s.refIdx);
    s.permTest   = permTest;
end


%% ========================================================================
%  Figure 1: one panel per condition, plus the omnibus significance panel
%  ========================================================================
function plot_conditions_figure(s, p, opts, CL, label, eventTimes)

    for gi = 1:size(s.erspdata.mean, 2)
        nCond = size(s.erspdata.mean, 1);
        colorLimits = symmetric_color_limits(s.erspdata.mean(:,gi), p);

        fig = new_ersp_figure(sprintf('Cls %d %s', CL, label), nCond + 1);
        axesHandles = gobjects(1, nCond + 1);

        for ci = 1:nCond + 1
            axesHandles(ci) = subplot(1, nCond + 1, ci);

            if ci <= nCond
                panelData  = s.erspdata.mean{ci,gi};
                panelTitle = p.design.legend{ci};
            else
                panelData  = double(s.condMask{1,gi});
                panelTitle = sprintf('RM-ANOVA (p<%g)', p.stats.alpha);
            end

            contourf(s.allTimes, s.allFreqs, panelData, 200, 'linecolor', 'none');
            format_ersp_axes(axesHandles(ci), s, p, colorLimits, eventTimes, ci == 1);
            add_panel_title(panelTitle, p);

            if ci == nCond + 1
                add_colorbar(axesHandles(ci), colorLimits, ...
                    'Baseline-Corrected Power (dB)', p);
            end
        end

        set(fig, 'Colormap', ersp_colormap(), 'Color', [1 1 1]);

        figName = sprintf('%s_ERSP_CL%d_%s_%s_a%g_%s_%s', ...
            opts.studyTitle, CL, label, p.stats.method, p.stats.alpha, ...
            p.stats.mcorrect, p.stats.mode);
        save_figure(fig, figName, fullfile(opts.outDir, 'all_cond'), p.plot.formats);
        close(fig);
    end
end


%% ========================================================================
%  Figure 2: difference against the reference condition
%  ========================================================================
function plot_differences_figure(s, p, opts, CL, label, eventTimes)

    for gi = 1:size(s.erspDiff.mean, 2)
        diffMeans = s.erspDiff.mean(s.compareIdx, gi);
        if all(cellfun(@isempty, diffMeans))
            continue
        end
        colorLimits = symmetric_color_limits(diffMeans, p);

        nPanel = numel(s.compareIdx);
        fig = new_ersp_figure(sprintf('Cls %d %s condVsRef', CL, label), nPanel);
        axesHandles = gobjects(1, nPanel);

        for k = 1:nPanel
            ci = s.compareIdx(k);
            axesHandles(k) = subplot(1, nPanel, k);

            contourf(s.allTimes, s.allFreqs, s.erspDiff.mean{ci,gi}, 200, ...
                'linecolor', 'none');
            hold on;
            outline_significant_regions(s.erspDiff.sigMask{ci,gi}, ...
                s.allTimes, s.allFreqs, p);

            format_ersp_axes(axesHandles(k), s, p, colorLimits, eventTimes, k == 1);
            add_panel_title(sprintf('%s vs. %s', ...
                p.design.legend{ci}, p.design.legend{s.refIdx}), p);

            if k == nPanel
                add_colorbar(axesHandles(k), colorLimits, ...
                    '\Delta Baseline-Corrected Power (dB)', p);
            end
        end

        set(fig, 'Colormap', ersp_colormap(), 'Color', [1 1 1]);

        figName = sprintf('%s_ERSP_CL%d_%s_condVsRef_%s_a%g_%s_%s', ...
            opts.studyTitle, CL, label, p.stats.method, p.stats.alpha, ...
            p.stats.mcorrect, p.stats.mode);
        save_figure(fig, figName, fullfile(opts.outDir, 'cond_vs_ref'), p.plot.formats);
        close(fig);
    end
end


%% ========================================================================
%  Plotting helpers
%  ========================================================================
function fig = new_ersp_figure(name, nPanels)
    figWidth  = 1.75 * (nPanels + 1);
    figHeight = figWidth / 2.857;
    fig = figure('Name', name, 'InvertHardcopy', 'off', ...
        'PaperType', 'a2', 'PaperOrientation', 'landscape', ...
        'PaperUnits', 'inches', 'Units', 'inches', ...
        'PaperPositionMode', 'auto', ...
        'Position', [0 0 figWidth*2 figHeight*2]);
end


function format_ersp_axes(ax, s, p, colorLimits, eventTimes, isLeftmost)
    set(ax, 'CLim', colorLimits, ...
        'XLim', [s.allTimes(1) s.allTimes(end)], ...
        'YLim', [s.allFreqs(1) s.allFreqs(end)], ...
        'YDir', 'normal', ...
        'YScale', 'log', ...
        'YTick', p.plot.freqTicks, ...
        'XTick', [s.allTimes(1) eventTimes(2) s.allTimes(end)], ...
        'XTickLabel', p.plot.cycleTicks, ...
        'FontName', p.plot.fontName, ...
        'FontSize', p.plot.fontSize, ...
        'Box', 'on', 'YMinorTick', 'off', 'Layer', 'top');
    xtickangle(ax, 45);
    ax.XRuler.TickLabelGapOffset = -2;

    % Give the panels room for the titles and the x label.
    pos = ax.Position;
    ax.Position = [pos(1)-0.04, pos(2)*1.8, pos(3), pos(4)*0.7];

    if isLeftmost
        ylabel(ax, sprintf('Frequency\n(Hz)'), ...
            'FontSize', p.plot.fontSize, 'FontWeight', 'bold', ...
            'FontName', p.plot.fontName);
    else
        set(ax, 'YTickLabel', []);
    end

    xlabel(ax, p.plot.xLabel, 'FontSize', p.plot.fontSize, 'FontWeight', 'bold');

    draw_timewarp_events( ...
        [s.allTimes(1) eventTimes(2) s.allTimes(end)], ...
        p.plot.eventLabels, p.plot.eventLabelY);
end


function add_panel_title(titleText, p)
    t = title(titleText, 'FontSize', p.plot.fontSize, ...
        'FontName', p.plot.fontName, 'FontWeight', 'bold', ...
        'FontAngle', 'normal');
    t.Units = 'normalized';
    t.Position(2) = 1.04;
end


function add_colorbar(ax, colorLimits, labelText, p)
    pos = ax.Position;
    c = colorbar('Position', [pos(1)+pos(3)+0.01, pos(2), 0.012, pos(4)]);
    c.Limits = colorLimits;

    % Make the ticks symmetric about zero.
    maxAbs = max(abs(c.Ticks));
    if ~ismember(maxAbs, c.Ticks)
        c.Ticks = sort([c.Ticks maxAbs]);
    end

    ylabel(c, labelText, 'FontWeight', 'bold', ...
        'FontName', p.plot.fontName, 'FontSize', p.plot.labelFontSize, ...
        'Rotation', 90);
end


function outline_significant_regions(sigMask, times, freqs, p)
% Trace the outline of each significant cluster onto the current axes.
    if isempty(sigMask) || ~any(sigMask(:))
        return
    end
    boundaries = bwboundaries(sigMask);
    for b = 1:numel(boundaries)
        rows = boundaries{b}(:,1);   % frequency
        cols = boundaries{b}(:,2);   % time
        plot(times(cols), freqs(rows), '-', ...
            'Color', p.plot.maskColor, 'LineWidth', p.plot.maskLineWidth, ...
            'HandleVisibility', 'off');
    end
end


function limits = symmetric_color_limits(dataCells, p)
% Lower Tukey fence of all plotted values, mirrored about zero.
%
% A robust fence rather than min/max keeps a handful of extreme pixels from
% flattening the image, and mirroring keeps zero at the centre of the
% diverging colormap.
    parts = cell(1, numel(dataCells));
    for k = 1:numel(dataCells)
        if isempty(dataCells{k})
            continue
        end
        panel = mean(dataCells{k}, 3);
        parts{k} = reshape(panel.', 1, []);
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


%% ========================================================================
%  Data helpers
%  ========================================================================
function STUDY = apply_stat_params(STUDY, p, eventTimes)
% Statistics and ERSP display parameters, set once for the whole run.
    STUDY = pop_statparams(STUDY, ...
        'condstats',          p.stats.condStats, ...
        'groupstats',         p.stats.groupStats, ...
        'method',             p.stats.method, ...
        'singletrials',       p.stats.singleTrials, ...
        'mode',               p.stats.mode, ...
        'fieldtripalpha',     p.stats.alpha, ...
        'fieldtripmethod',    p.stats.fieldtripMethod, ...
        'fieldtripmcorrect',  p.stats.mcorrect, ...
        'fieldtripnaccu',     p.stats.nRandomisations);

    STUDY = pop_erspparams(STUDY, ...
        'subbaseline', p.stats.subtractCommonBaseline, ...
        'timerange',   [eventTimes(1) eventTimes(end)], ...
        'freqrange',   p.plot.freqRange);
end


function allersp = consolidate_by_subject(STUDY, CL, allersp)
% Keep one ERSP per subject in each cluster.
%
% STUDY.cluster has normally already been reduced by ONE_IC_PER_SUBJECT, in
% which case this is a no-op. It is kept so the function is also correct
% when called on an unreduced STUDY.
    design = STUDY.currentdesign;
    designSubjects = STUDY.design(design).cases.value;
    [~, notInDesign] = setdiff({STUDY.datasetinfo.subject}, designSubjects);

    clusterSets = STUDY.cluster(CL).sets;
    clusterSets = clusterSets(~ismember(clusterSets, notInDesign));
    uniqueSubjects = unique(clusterSets);

    for i = 1:numel(allersp)
        source  = allersp{i};
        reduced = zeros(size(source,1), size(source,2), numel(uniqueSubjects), ...
            'like', source);
        for u = 1:numel(uniqueSubjects)
            hits = find(clusterSets == uniqueSubjects(u));
            reduced(:,:,u) = source(:,:,hits(1));
        end
        allersp{i} = reduced;
    end
end


function masks = to_logical_masks(pcond)
% std_stat returns a 0/1 mask when an alpha is set: 1 means SIGNIFICANT.
    masks = pcond;
    for i = 1:numel(masks)
        if ~isempty(masks{i})
            masks{i} = logical(masks{i});
        end
    end
end


function out = reorder_struct(in, order, fields)
    out = in;
    for f = 1:numel(fields)
        name = fields{f};
        src  = in.(name);
        dst  = cell(size(src));
        for ci = 1:numel(order)
            for gi = 1:size(src, 2)
                dst{ci,gi} = src{order(ci),gi};
            end
        end
        out.(name) = dst;
    end
end


function s = keyvalue_to_struct(kv)
% {'key1',v1,'key2',v2,...} -> struct('key1',v1,'key2',v2,...)
    if isstruct(kv)
        s = kv;
        return
    end
    assert(mod(numel(kv), 2) == 0, 'plot_cluster_ersp:BadParamCell', ...
        'ERSP parameter override must have an even number of elements.');
    s = cell2struct(kv(2:2:end), kv(1:2:end), 2);
end


function label = cluster_label(STUDY, CL)
    raw = STUDY.cluster(CL).label;
    if iscell(raw)
        label = char(raw{1});
    else
        label = char(raw);
    end
end


function warpingValues = group_median_warpto(ALLEEG, roundToMs)
    nEvents = numel(ALLEEG(1).timewarp.warpto);
    warps = zeros(numel(ALLEEG), nEvents);
    for i = 1:numel(ALLEEG)
        warps(i,:) = ALLEEG(i).timewarp.warpto;
    end
    warpingValues = round(median(warps, 1) / roundToMs) * roundToMs;
end
