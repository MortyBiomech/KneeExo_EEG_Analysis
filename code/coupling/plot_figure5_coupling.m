function fig = plot_figure5_coupling(res, opts)
%PLOT_FIGURE5_COUPLING  Cyclic coupling of band power and tracking error.
%
%   FIG = PLOT_FIGURE5_COUPLING(RES) draws the coupling result as three panels.
%
%   Panel b draws two curves per band, not three. The heavy line is the
%   correlation of single trials as recorded, the dashed line is the same after
%   the condition mean waveform is removed from both signals, and the gap
%   between them is the contribution of the cycle the two signals share. That
%   pair answers the question on its own.
%
%   The third mode, correlating each participant's trial-averaged waveforms, is
%   still computed and still appears in the console table, because it is the
%   number that quantifies panel a directly. It is not drawn by default for two
%   reasons. Averaging over trials removes noise and so inflates the
%   correlation by an amount that depends on how many trials a participant
%   happened to contribute, which makes the value hard to compare across
%   participants and conditions. And it is the one mode with no permutation
%   test, since averaging leaves no trial labels to shuffle. Set cyclicMode to
%   'mean' to draw it instead, or showBothCyclic to draw both.
%
%     a  the mean cyclic waveform of the tracking error above that of each
%        band's power, on separate scales but a shared cycle axis, with the
%        standard error across participants, the peak of each waveform marked
%        and the lead or lag of the power against the error bracketed
%     b  the lagged correlation between them, once for the mean cyclic waveforms
%        and once for the trial-wise residuals, with the pointwise permutation
%        null shaded
%     c  the peak correlation of both, per pressure condition and band, against
%        the null of the maximum, with the permutation p value of each residual
%
%   Why the shape of this figure:
%
%   The per-condition curves are near copies of one another, which is itself a
%   result, so the figure states it once in panel c instead of nine times.
%   Panels a and b therefore show the condition-collapsed curves, and panel c
%   carries the condition dimension, the numbers and the p values.
%
%   Panel a puts the band power on a second y axis by default. A second y scale
%   is normally a bad idea, because the alignment of the two scales is chosen by
%   the author and the chart can be made to show any degree of agreement. Two
%   things keep it defensible here.
%
%   First, the claim the panel makes is about PHASE, namely that both signals
%   peak twice per cycle and where those peaks fall. Rescaling one axis moves no
%   peak sideways, so it cannot manufacture that claim.
%
%   Second, the scales are not chosen by eye. Both are symmetric about zero, so
%   zero coincides and the sign relationship is preserved, and each is set so
%   that its own signal fills the same fraction of the panel. The resulting
%   factor is printed on the right axis label, so a reader can undo it.
%
%   What the second axis does still distort is the apparent depth of modulation:
%   the power varies far less than the tracking error, and the panel hides that.
%   Set combinePanelA to false for two stacked axes with one scale each, which
%   gives up the direct overlay and keeps the amplitudes comparable.
%
%   Two things are deliberately absent. The per-participant peak marker of the
%   original, because a maximum over many lags is positively biased under a true
%   null and a maximum of a signed correlation can never be negative, so it
%   cannot be read as evidence either way. And any per-condition panel, for the
%   reason above.
%
%   The grey band differs between panels b and c by design. Panel b shows a
%   curve, so its band is the pointwise null. Panel c shows a maximum over lags,
%   so its band is the null of that maximum, which is wider. A residual marker
%   inside the panel c band is exactly a residual with p above alpha.
%
%   OPTS fields:
%     conditionNames  labels for the rows of panel c (default Low, Medium, High)
%     bandColours     [nBands x 3] one colour per band
%     errorColour     colour of the tracking error line
%     cyclicMode      which mode stands for the cyclic correspondence, drawn
%                     as the heavy line in panel b and the filled marker in
%                     panel c. 'actual' (default) correlates every trial as
%                     recorded. 'mean' correlates each participant's
%                     trial-averaged waveforms
%     showResidualP   print the permutation p of each residual down the right
%                     of panel c (default true)
%     showBothCyclic  also draw the other of the two as a thin line, to show how
%                     much averaging over trials inflates the correlation
%                     (default false)
%     stretchCycleAxis  label panel a's cycle axis 0 to 100 across the samples
%                     that exist, rather than leaving the margin the
%                     time-frequency window cuts off (default true). See the
%                     note above on what this does and does not misstate
%     combinePanelA   draw panel a as one axes with the band power on a second
%                     y axis (default true), or as two stacked axes with one
%                     scale each (false). See the note above on what the second
%                     axis does and does not distort
%     showOffsets     bracket the lead or lag of the first band against the
%                     error at each peak (default true). The offsets are
%                     descriptive and carry no test, so set this false if that
%                     invites more weight than it can bear
%     outDir          if given, the figure is written there by SAVE_FIGURE,
%                     which puts each format in its own subfolder, the way the
%                     rest of the published figure tree is laid out
%     baseName        file name without extension, required with outDir
%     formats         formats to write, passed to SAVE_FIGURE. Empty means its
%                     default. The figure is written with SAVE_FIGURE's 'flat'
%                     layout, all formats side by side in one folder per
%                     figure, which is how the published figure tree is laid out
%     fontSize        base font size in points (default 8)
%     widthCm         figure width in centimetres (default 18.0, the width the
%                     other figures in this manuscript use)
%     fontName        typeface (default Arial, as the other figures)
%     heightCm        figure height in centimetres (default 7.90)
%
%   Every panel is placed by hand in centimetres, in the geometry block near the
%   top of the function. Nothing reflows, so the figure is the same whatever the
%   legends and tick labels turn out to be.
%
%   See also RUN_CROSS_CORRELATION.
%
%   Part of the KneeExo-EEG analysis code.

arguments
    res (1,1) struct
    opts.conditionNames (1,:) cell = {'Low', 'Medium', 'High'}
    opts.bandColours (:,3) double = [74 58 167; 0 131 0] / 255
    opts.errorColour (1,3) double = [61 61 58] / 255
    opts.cyclicMode (1,:) char {mustBeMember(opts.cyclicMode, {'actual', 'mean'})} = 'actual'
    opts.showBothCyclic (1,1) logical = false
    opts.showResidualP (1,1) logical = true
    opts.combinePanelA (1,1) logical = true
    opts.stretchCycleAxis (1,1) logical = true
    opts.showOffsets (1,1) logical = true
    opts.outDir (1,:) char = ''
    opts.baseName (1,:) char = ''
    opts.formats cell = {}
    opts.fontSize (1,1) double = 8
    opts.widthCm (1,1) double = 18.0
    opts.heightCm (1,1) double = 7.90
    opts.fontName (1,:) char = 'Arial'
end

INK   = [0.04 0.04 0.04];
INK2  = [0.32 0.32 0.31];
AXISC = [0 0 0];                 % rulers, ticks and tick labels
MUTED = [0.74 0.73 0.71];
NULLC = [0.886 0.886 0.871];

bandNames = fieldnames(res.stats.residual);
nBand     = numel(bandNames);
nCond     = numel(res.conditions);
fs        = opts.fontSize;

% One size per role. The legends in panels a and b had drifted apart because
% each carried its own arithmetic on fs.
fsAxis = fs - 0.5;    % tick labels and category labels
fsLeg  = fs - 1.0;    % every legend, in every panel
fsNote = fs - 1.8;    % in panel annotations and printed numbers

if size(opts.bandColours, 1) < nBand
    error('plot_figure5_coupling:TooFewColours', ...
        'There are %d bands but only %d colours.', nBand, size(opts.bandColours, 1));
end

%% ===== geometry ==========================================================
%  Every dimension below is in centimetres and every axes is placed by hand.
%  A managed layout reflows when a legend or a long tick label is added, so the
%  same code gives a different figure depending on the data. Fixed positions do
%  not, which matters for a figure that has to be reproduced at a set width.
%
%  The numbers must satisfy
%     G.left + sum(G.panelW) + sum(G.panelGap) + G.right = opts.widthCm
%  which is checked below, so any one of them can be nudged and the check says
%  whether the rest still fit.

G = struct();
G.left     = 1.40;              % room for the leftmost y label and its ticks
G.right    = 0.35;
G.bottom   = 1.35;              % room for a two line x label
G.top      = 1.15;              % room for the panel letter and its headline
G.panelW   = [3.70, 3.45, 3.45];   % width of panels a, b, c
G.panelGap = [2.85, 2.80];         % gap after panel a, after panel b
%
% The first gap has to hold panel a's right tick labels and its two line right y
% label, then panel b's left tick labels and its y label, which is about 1.95 cm
% of text. The second holds panel c's word tick labels, about 1.2 cm. Both leave
% roughly half a centimetre of clear air on top of that.
G.splitGap = 0.50;              % vertical gap when panel a is drawn stacked
% One offset per panel, because the panel letter has to clear whatever sits to
% the left of that axes: a two line y label in panel a, a one line label in b,
% and in c the rotated band names, which reach further out than either.
G.headDx   = [1.30, 1.20, 1.80];   % panel letter, left of each axes
G.headDy   = 0.48;              % panel letter and headline, above the axes
G.legDx    = 0.15;              % legend, right of the axes left edge
G.legDy    = 0.02;              % legend top, below the axes top edge
G.condDx   = 0.15;              % panel c condition labels, left of the axes
G.bandDx   = 1.35;              % panel c band names, left of the axes

axH  = opts.heightCm - G.bottom - G.top;
used = G.left + sum(G.panelW) + sum(G.panelGap) + G.right;

if abs(used - opts.widthCm) > 0.02
    warning('plot_figure5_coupling:WidthMismatch', ...
        ['The panel widths and gaps add up to %.2f cm but the figure is ' ...
         '%.2f cm wide. Adjust G.panelW, G.panelGap or the margins.'], ...
        used, opts.widthCm);
end
if axH <= 0
    error('plot_figure5_coupling:HeightTooSmall', ...
        ['The margins leave no room for the axes. Increase heightCm above ' ...
         '%.2f cm.'], G.bottom + G.top);
end

panelX = zeros(1, 3);
x      = G.left;
for k = 1:3
    panelX(k) = x;
    if k < 3
        x = x + G.panelW(k) + G.panelGap(k);
    end
end

fig = figure('Name', sprintf('Coupling, %s', strrep(res.cluster, '_', ' ')), ...
    'Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 opts.widthCm opts.heightCm]);

% House style for this manuscript: Arial, 180 mm wide, ticks pointing inward.
set(fig, 'DefaultAxesFontName', opts.fontName, ...
    'DefaultTextFontName', opts.fontName, ...
    'DefaultAxesTickDir', 'in', 'DefaultAxesTickDirMode', 'manual');


%% ===== a. the cyclic waveforms ===========================================
[mErr, sErr] = mean_and_sem(res.waveformAll.error);
peakErr      = cycle_peaks(res.pct, mErr, res.warpFrac);

peakBand = nan(nBand, 2);
mBand    = nan(nBand, numel(res.pct));
sBand    = nan(nBand, numel(res.pct));
for b = 1:nBand
    [mBand(b,:), sBand(b,:)] = mean_and_sem(res.waveformAll.(bandNames{b}));
    peakBand(b,:) = cycle_peaks(res.pct, mBand(b,:), res.warpFrac);
end

% Largest excursion of each signal, standard error included. These set the two
% vertical scales.
Lerr = max(abs([mErr - sErr, mErr + sErr]));
Lpow = 0;
for b = 1:nBand
    Lpow = max(Lpow, max(abs([mBand(b,:) - sBand(b,:), mBand(b,:) + sBand(b,:)])));
end
% Both axes carry the same unit, so the two sets of tick values state the
% magnification themselves and no annotation is needed. It is printed once for
% whoever writes the caption.
expandFactor = Lerr / Lpow;
topFactor    = 1.78;

% The movement cycle runs 0 to 100%, but the time-frequency estimate does not
% reach either end: a wavelet needs samples on both sides of the point it
% describes, so the first and last slivers of the cycle carry no estimate. With
% stretchCycleAxis the axis is labelled 0 to 100 across the samples that do
% exist, which is what a reader expects of a cycle and keeps the panel free of a
% margin that means nothing. The cost is that a tick reading 25 sits a little
% off the true quarter cycle. The distortion is the width of the missing
% slivers, printed below so it can go in the caption, and it moves no peak
% relative to any other: every curve in the panel is on the same axis.
if opts.stretchCycleAxis
    xLimA    = [res.pct(1) res.pct(end)];
    tickA    = res.pct(1) + (0:25:100)/100 * (res.pct(end) - res.pct(1));
    offScale = 100 / (res.pct(end) - res.pct(1));
    fprintf(['Panel a: the cycle axis is labelled 0 to 100%% across the ' ...
        '%.1f to %.1f%% the time-frequency window covers.\n'], ...
        res.pct(1), res.pct(end));
else
    xLimA    = [0 100];
    tickA    = 0:25:100;
    offScale = 1;
end
tickLabA = {'0', '25', '50', '75', '100'};

if opts.combinePanelA

    axErr = new_axes(fig, [panelX(1), G.bottom, G.panelW(1), axH]);
    axPow = axErr;
    hold(axErr, 'on');

    % ---- left axis, the tracking error -------------------------------
    yyaxis(axErr, 'left');
    refA = gobjects(0);
    for k = 1:2
        refA(end+1,1) = ref_line(axErr, 'v', peakErr(k), ':', MUTED, 0.6); %#ok<AGROW>
    end
    refA(end+1,1) = ref_line(axErr, 'v', 100*res.warpFrac, '--', MUTED, 0.7);
    refA(end+1,1) = ref_line(axErr, 'h', 0, '-', MUTED, 0.6);

    hErr = band_line(axErr, res.pct, mErr, sErr, opts.errorColour, 1.8, ...
        'tracking error');
    mark_peaks(axErr, res.pct, mErr, peakErr, opts.errorColour);

    ylim(axErr, [-Lerr, topFactor*Lerr]);
    ylabel(axErr, {'tracking error', '(% of cycle mean)'}, ...
        'Color', INK, 'FontSize', fs);
    axErr.YAxis(1).Color = AXISC;

    % ---- right axis, the band power ----------------------------------
    yyaxis(axErr, 'right');
    hBand = gobjects(nBand, 1);
    labBand = cell(nBand, 1);
    for b = 1:nBand
        hBand(b) = band_line(axErr, res.pct, mBand(b,:), sBand(b,:), ...
            opts.bandColours(b,:), 1.5, sprintf('%s power', bandNames{b}));
        mark_peaks(axErr, res.pct, mBand(b,:), peakBand(b,:), ...
            opts.bandColours(b,:));
        labBand{b} = sprintf('%s power', bandNames{b});
    end

    ylim(axErr, [-Lpow, topFactor*Lpow]);
    ylabel(axErr, {'band power', '(% of cycle mean)'}, ...
        'Color', INK, 'FontSize', fs);
    axErr.YAxis(2).Color = AXISC;

    % Annotations belong on the left side, whose units the y values below are in.
    yyaxis(axErr, 'left');
    xlim(axErr, xLimA);
    set(axErr, 'XTick', tickA, 'XTickLabel', tickLabA, 'FontSize', fsAxis, ...
        'Box', 'off', 'TickDir', 'in', 'XColor', AXISC, 'LineWidth', 0.6);
    xlabel(axErr, 'movement cycle (%)', 'Color', INK, 'FontSize', fs);
    lgdA = legend(axErr, [hErr; hBand], [{'tracking error'}; labBand], ...
        'Box', 'off', 'Orientation', 'vertical', ...
        'FontSize', fsLeg, 'TextColor', INK2);
    place_legend(lgdA, axErr, G.legDx, G.legDy);

    offsetBase = max(mErr) + 0.26*Lerr;
    offsetSpan = Lerr;

    fprintf(['Panel a: the band power axis is expanded %.1f times relative ' ...
        'to the tracking error axis.\n'], expandFactor);

else

    halfH = (axH - G.splitGap) / 2;
    axErr = new_axes(fig, [panelX(1), G.bottom + halfH + G.splitGap, ...
        G.panelW(1), halfH]);
    axPow = new_axes(fig, [panelX(1), G.bottom, G.panelW(1), halfH]);

    refA = gobjects(0);
    for ax = [axErr, axPow]
        hold(ax, 'on');
        for k = 1:2
            refA(end+1,1) = ref_line(ax, 'v', peakErr(k), ':', MUTED, 0.6); %#ok<AGROW>
        end
        refA(end+1,1) = ref_line(ax, 'v', 100*res.warpFrac, '--', MUTED, 0.7); %#ok<AGROW>
        refA(end+1,1) = ref_line(ax, 'h', 0, '-', MUTED, 0.6);                 %#ok<AGROW>
        xlim(ax, xLimA);
        set(ax, 'XTick', tickA, 'XTickLabel', tickLabA, 'FontSize', fsAxis, ...
            'Box', 'off', 'TickDir', 'in', 'XColor', AXISC, 'YColor', AXISC, ...
            'LineWidth', 0.6);
    end

    band_line(axErr, res.pct, mErr, sErr, opts.errorColour, 1.8, 'off');
    mark_peaks(axErr, res.pct, mErr, peakErr, opts.errorColour);
    pad_ylim(axErr, 0.10, 0.10);
    set(axErr, 'XTickLabel', []);
    ylabel(axErr, {'tracking error', '(% of cycle mean)'}, ...
        'Color', INK, 'FontSize', fs);

    for b = 1:nBand
        band_line(axPow, res.pct, mBand(b,:), sBand(b,:), ...
            opts.bandColours(b,:), 1.5, sprintf('%s power', bandNames{b}));
        mark_peaks(axPow, res.pct, mBand(b,:), peakBand(b,:), ...
            opts.bandColours(b,:));
    end
    pad_ylim(axPow, 0.46, 0.34);
    xlabel(axPow, 'movement cycle (%)', 'Color', INK, 'FontSize', fs);
    ylabel(axPow, {'band power', '(% of cycle mean)'}, ...
        'Color', INK, 'FontSize', fs);
    lgdA = legend(axPow, 'Box', 'off', 'Orientation', 'vertical', ...
        'FontSize', fsLeg, 'TextColor', INK2);
    place_legend(lgdA, axPow, G.legDx, G.legDy);

    yl         = ylim(axPow);
    offsetSpan = yl(2) - yl(1);
    offsetBase = yl(2) - 0.11*offsetSpan;

end

fit_ref_lines(refA);

% ---- lead or lag of the first band against the error ---------------------
if opts.showOffsets

    axOff = axPow;
    if opts.combinePanelA
        axOff = axErr;
        yyaxis(axOff, 'left');
    end

    cap = 0.020*offsetSpan;

    for k = 1:2
        x0 = peakBand(1, k);
        x1 = peakErr(k);
        yb = offsetBase;
        plot(axOff, [x0 x1], [yb yb], '-', 'Color', INK2, 'LineWidth', 0.7, ...
            'Marker', 'none', 'HandleVisibility', 'off');
        plot(axOff, [x0 x0], yb + cap*[-1 1], '-', 'Color', INK2, ...
            'LineWidth', 0.7, 'Marker', 'none', 'HandleVisibility', 'off');
        plot(axOff, [x1 x1], yb + cap*[-1 1], '-', 'Color', INK2, ...
            'LineWidth', 0.7, 'Marker', 'none', 'HandleVisibility', 'off');
        text(axOff, (x0+x1)/2, yb + 1.6*cap, ...
            sprintf('%.0f%%', abs(x1-x0) * offScale), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', fsNote, 'Color', INK2);
        if x0 < x1
            word = 'leads';
        else
            word = 'lags';
        end
        text(axOff, (x0+x1)/2, yb - 1.6*cap, word, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
            'FontSize', fsNote, 'Color', INK2);
    end

end


%% ===== b. the lagged correlation =========================================
ax = new_axes(fig, [panelX(2), G.bottom, G.panelW(2), axH]);
hold(ax, 'on');

lagPct = res.stats.residual.(bandNames{1})(1).lags * res.lagPerSample;

nullLo = inf(size(lagPct));
nullHi = -inf(size(lagPct));
nullMx = 0;
for b = 1:nBand
    for c = 1:nCond
        st     = res.stats.residual.(bandNames{b})(c);
        nullLo = min(nullLo, st.nullLo);
        nullHi = max(nullHi, st.nullHi);
        nullMx = max(nullMx, null_max_level(st));
    end
end

hNull = fill(ax, [lagPct, fliplr(lagPct)], [nullLo, fliplr(nullHi)], NULLC, ...
    'EdgeColor', 'none');
refB = [ref_line(ax, 'h', 0, '-',  MUTED, 0.6); ...
        ref_line(ax, 'v', 0, '--', MUTED, 0.7)];

% Two curves per band. Colour says which band, line weight and style say which
% mode, so the legend is built from proxies rather than from every band and mode
% combination.
%
%   cyclicMode  heavy solid   the correlation as it stands, cycle included
%   residual    dashed        condition mean removed from both signals
%
% The pair is a complete decomposition of the question: the heavy line is the
% whole correlation, the dashed line is what survives once the cycle both
% signals follow is taken out, and the gap between them is the cycle's
% contribution. A third curve for the other cyclic mode is available through
% showBothCyclic but is not needed for that argument.
LW = struct('heavy', 1.9, 'thin', 0.9, 'res', 1.2);

otherMode = 'mean';
if strcmp(opts.cyclicMode, 'mean')
    otherMode = 'actual';
end

drawOther = opts.showBothCyclic && isfield(res.stats, otherMode);

for b = 1:nBand
    c = opts.bandColours(b, :);
    plot(ax, lagPct, collapse_conditions(res.stats.(opts.cyclicMode).(bandNames{b})), ...
        '-', 'Color', c, 'LineWidth', LW.heavy, 'Marker', 'none');
    if drawOther
        plot(ax, lagPct, collapse_conditions(res.stats.(otherMode).(bandNames{b})), ...
            '-', 'Color', c, 'LineWidth', LW.thin, 'Marker', 'none');
    end
    plot(ax, lagPct, collapse_conditions(res.stats.residual.(bandNames{b})), ...
        '--', 'Color', c, 'LineWidth', LW.res, 'Marker', 'none');
end

% Legend proxies. NaN data draws nothing and moves no limit.
hLine   = gobjects(0);
labLine = {};
for b = 1:nBand
    hLine(end+1,1) = plot(ax, NaN, NaN, '-', ...
        'Color', opts.bandColours(b,:), 'LineWidth', LW.heavy, ...
        'Marker', 'none'); %#ok<AGROW>
    labLine{end+1,1} = bandNames{b};                            %#ok<AGROW>
end
hLine(end+1,1)   = plot(ax, NaN, NaN, '-', 'Color', INK2, ...
    'LineWidth', LW.heavy, 'Marker', 'none');
labLine{end+1,1} = mode_label(opts.cyclicMode);
if drawOther
    hLine(end+1,1)   = plot(ax, NaN, NaN, '-', 'Color', INK2, ...
        'LineWidth', LW.thin, 'Marker', 'none');
    labLine{end+1,1} = mode_label(otherMode);
end
hLine(end+1,1)   = plot(ax, NaN, NaN, '--', 'Color', INK2, ...
    'LineWidth', LW.res, 'Marker', 'none');
labLine{end+1,1} = mode_label('residual');

xlim(ax, [lagPct(1) lagPct(end)]);
pad_ylim(ax, 0.06, 0.48);
set(ax, 'XTick', [lagPct(1) 0 lagPct(end)], 'FontSize', fsAxis, 'Box', 'off', ...
    'TickDir', 'in', 'XColor', AXISC, 'YColor', AXISC, 'LineWidth', 0.6, ...
    'XTickLabel', {sprintf('%.0f', lagPct(1)), '0', sprintf('+%.0f', lagPct(end))});

lgdB = legend(ax, [hLine; hNull], [labLine; {'pointwise null'}], ...
    'Box', 'off', 'FontSize', fsLeg, 'TextColor', INK2);
place_legend(lgdB, ax, G.legDx, G.legDy);

xlabel(ax, {'lag (% of cycle)', 'power follows error at positive lag'}, ...
    'Color', INK, 'FontSize', fs);
ylabel(ax, 'correlation with tracking error, r', 'Color', INK, 'FontSize', fs);
fit_ref_lines(refB);

axLag = ax;


%% ===== c. per-condition summary ==========================================
ax = new_axes(fig, [panelX(3), G.bottom, G.panelW(3), axH]);
hold(ax, 'on');
axSum = ax;

nRow  = nBand*nCond;
rowY  = zeros(nRow, 1);
rowC  = zeros(nRow, 3);
rowLb = cell(nRow, 1);
meanR = zeros(nRow, 1);
resR  = zeros(nRow, 1);
pRes  = cell(nRow, 1);

k = 0;
for b = 1:nBand
    for c = 1:nCond
        k         = k + 1;
        rowY(k)   = -((b-1)*(nCond+1) + (c-1));
        rowC(k,:) = opts.bandColours(b, :);
        rowLb{k}  = opts.conditionNames{c};
        meanR(k)  = positive_peak(res.stats.(opts.cyclicMode).(bandNames{b})(c));
        st        = res.stats.residual.(bandNames{b})(c);
        resR(k)   = positive_peak(st);
        pRes{k}   = format_p(st.pOmnibus, st.settings.nPerm);
    end
end

xMax = max(meanR) + 0.34*double(opts.showResidualP) + 0.10;
xMin = -0.055;
yTop = max(rowY) + 1.9;
yBot = min(rowY) - 3.3;

% Centimetres per unit of x, so offsets can be given in centimetres like every
% other dimension in this figure.
cmPerX = G.panelW(3) / (xMax - xMin);

patch(ax, nullMx*[-1 1 1 -1], ...
    [min(rowY)-0.6, min(rowY)-0.6, max(rowY)+0.6, max(rowY)+0.6], NULLC, ...
    'EdgeColor', 'none', 'HandleVisibility', 'off');
refC = ref_line(ax, 'v', 0, '-', MUTED, 0.6);

for k = 1:nRow
    plot(ax, [resR(k) meanR(k)], rowY(k)*[1 1], '-', 'Color', rowC(k,:), ...
        'LineWidth', 0.7, 'Marker', 'none');
    plot(ax, meanR(k), rowY(k), 'o', 'MarkerSize', 5, ...
        'MarkerFaceColor', rowC(k,:), 'MarkerEdgeColor', 'w', 'LineWidth', 0.7);
    plot(ax, resR(k), rowY(k), 's', 'MarkerSize', 4.5, ...
        'MarkerFaceColor', 'w', 'MarkerEdgeColor', rowC(k,:), 'LineWidth', 1.1);
    text(ax, meanR(k) + 0.028, rowY(k), sprintf('%.2f', meanR(k)), ...
        'FontSize', fsNote, 'Color', INK2, 'VerticalAlignment', 'middle');
    if opts.showResidualP
        text(ax, xMax, rowY(k), pRes{k}, 'FontSize', fsNote, 'Color', INK2, ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
    end
end

if opts.showResidualP
    text(ax, xMax, max(rowY) + 1.0, 'residual p', 'FontSize', fsNote, ...
        'Color', INK2, 'FontAngle', 'italic', 'HorizontalAlignment', 'right');
end
for b = 1:nBand
    yMid = -((b-1)*(nCond+1) + (nCond-1)/2);
    text(ax, xMin - G.bandDx/cmPerX, yMid, bandNames{b}, 'Rotation', 90, ...
        'FontSize', fsAxis, 'FontWeight', 'bold', ...
        'Color', opts.bandColours(b, :), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', 'Clipping', 'off');
end

% Condition labels are drawn by hand rather than as y ticks, because the y ruler
% is switched off. A ruler would draw a spine down the left of the panel, which
% marks a zero that does not exist: the rows are categories, not a scale.
for k = 1:nRow
    text(ax, xMin - G.condDx/cmPerX, rowY(k), rowLb{k}, ...
        'FontSize', fsAxis, 'Color', AXISC, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
        'Clipping', 'off');
end

yLeg = min(rowY);
plot(ax, 0, yLeg-1.6, 'o', 'MarkerSize', 5, 'MarkerFaceColor', INK2, ...
    'MarkerEdgeColor', 'w', 'LineWidth', 0.7);
text(ax, 0.03, yLeg-1.6, mode_label(opts.cyclicMode), 'FontSize', fsLeg, ...
    'Color', INK2, 'VerticalAlignment', 'middle');
plot(ax, 0, yLeg-2.6, 's', 'MarkerSize', 4.5, 'MarkerFaceColor', 'w', ...
    'MarkerEdgeColor', INK2, 'LineWidth', 1.1);
text(ax, 0.03, yLeg-2.6, mode_label('residual'), 'FontSize', fsLeg, ...
    'Color', INK2, 'VerticalAlignment', 'middle');

xlim(ax, [xMin xMax]);
ylim(ax, [yBot yTop]);
set(ax, 'YTick', [], 'FontSize', fsAxis, 'Box', 'off', 'TickDir', 'in', ...
    'XColor', AXISC, 'YColor', 'none', 'LineWidth', 0.6, ...
    'XTick', 0:0.2:floor(max(meanR)*5)/5);
xlabel(ax, {'correlation r at its positive peak', ...
    'grey: null range for the residual peak'}, 'Color', INK, 'FontSize', fs);
fit_ref_lines(refC);


%% ===== panel letters and headlines =======================================
%  Placed last and in figure units. Panel a sits in a half-height tile while b
%  and c span the full height, so an offset expressed as a fraction of each
%  axes would put a's letter lower than the others. Converting a single figure
%  offset into each axes' own normalised units keeps all three on one line.
panel_head(axErr, 'a', 'Both signals cycle twice per movement', fs, INK, G, 1);
panel_head(axLag, 'b', 'Cycle-locked, not trial-locked',        fs, INK, G, 2);
panel_head(axSum, 'c', 'Pressure changes neither',              fs, INK, G, 3);


%% ===== save ==============================================================
%  Writing goes through SAVE_FIGURE so that this figure lands in the same tree,
%  in the same formats, with the same vector settings as every other figure in
%  the manuscript. Nature Portfolio wants vector with embedded editable fonts,
%  which is what its pdf and svg paths produce.
if ~isempty(opts.outDir)

    if isempty(opts.baseName)
        error('plot_figure5_coupling:NoBaseName', ...
            'outDir was given without baseName, so there is no file name.');
    end
    if exist('save_figure', 'file') ~= 2
        error('plot_figure5_coupling:NoSaveFigure', ...
            ['save_figure is not on the MATLAB path. It lives in ' ...
             'code/figures and is added by add_code_paths.']);
    end

    written = save_figure(fig, opts.baseName, opts.outDir, opts.formats, 'flat');
    written = written(~cellfun(@isempty, written));

    fprintf('Figure written to %s as %s (%s)\n', opts.outDir, ...
        opts.baseName, strjoin(extensions_of(written), ', '));

end

end


% ----------------------------------------------------------------------------
function h = band_line(ax, x, m, s, colour, width, label)
%BAND_LINE  A mean curve with its standard error shaded behind it.

fill(ax, [x, fliplr(x)], [m - s, fliplr(m + s)], colour, ...
    'FaceAlpha', 0.13, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% LineStyle is pinned because an axes with two y rulers carries its own
% LineStyleOrder, which MATLAB cycles across successive plots on the same
% ruler. Without this the second band is drawn dashed.
if strcmp(label, 'off')
    h = plot(ax, x, m, 'Color', colour, 'LineWidth', width, ...
        'LineStyle', '-', 'Marker', 'none', 'HandleVisibility', 'off');
else
    h = plot(ax, x, m, 'Color', colour, 'LineWidth', width, ...
        'LineStyle', '-', 'Marker', 'none', 'DisplayName', label);
end

end


% ----------------------------------------------------------------------------
function p = cycle_peaks(pct, m, warpFrac)
%CYCLE_PEAKS  The highest point in each half of the movement cycle.

p    = nan(1, 2);
edge = 100*warpFrac;

for half = 1:2
    if half == 1
        sel = pct > 5 & pct < edge - 5;
    else
        sel = pct > edge + 5 & pct < 97;
    end
    seg      = m;
    seg(~sel) = -Inf;
    [~, i]   = max(seg);
    p(half)  = pct(i);
end

end


% ----------------------------------------------------------------------------
function mark_peaks(ax, x, m, peaks, colour)
%MARK_PEAKS  A small dot at each cycle peak.

for k = 1:numel(peaks)
    [~, i] = min(abs(x - peaks(k)));
    plot(ax, x(i), m(i), 'o', 'MarkerSize', 3.2, 'MarkerFaceColor', colour, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.6, 'HandleVisibility', 'off');
end

end


% ----------------------------------------------------------------------------
function pad_ylim(ax, below, above)
%PAD_YLIM  Fit the limits to the data, then add room for annotation.

yl   = ylim(ax);
span = yl(2) - yl(1);
ylim(ax, [yl(1) - below*span, yl(2) + above*span]);

end



% ----------------------------------------------------------------------------
function panel_head(ax, letter, line, fs, ink, G, k)
%PANEL_HEAD  Bold panel letter at the left, plain sentence centred above.
%
%   Offsets are in centimetres, the same units the axes are placed in, so the
%   letters sit on one line whatever each panel's height happens to be. With a
%   managed layout this needed a conversion and a DRAWNOW first; with explicit
%   positions the numbers are already known.

p = ax.Position;

text(ax, -G.headDx(k), p(4) + G.headDy, letter, 'Units', 'centimeters', ...
    'FontWeight', 'bold', 'FontSize', fs+2, 'Color', ink, ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
    'Clipping', 'off');
text(ax, p(3)/2, p(4) + G.headDy, line, 'Units', 'centimeters', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', fs, 'Color', ink, 'Clipping', 'off');

end


% ----------------------------------------------------------------------------
function ext = extensions_of(files)
%EXTENSIONS_OF  The formats actually written, for one tidy line of output.

ext = cell(size(files));
for k = 1:numel(files)
    [~, ~, e] = fileparts(files{k});
    ext{k}    = strrep(e, '.', '');
end

end


% ----------------------------------------------------------------------------
function h = ref_line(ax, kind, value, style, colour, lw)
%REF_LINE  A guide line that stays behind everything drawn after it.
%
%   XLINE and YLINE make ConstantLine objects, which MATLAB renders in front of
%   the rest of the axes whatever order they were created in. A guide drawn over
%   the data it is guiding reads as data itself. A plain line obeys the draw
%   order, so calling REF_LINE before anything else puts it at the back.
%
%   The coordinates are placeholders. FIT_REF_LINES stretches each line to the
%   final limits once those are known, which is why they cannot simply be drawn
%   to the limits here.

if kind == 'v'
    h = plot(ax, [value value], [0 0], style, 'Color', colour, ...
        'LineWidth', lw, 'Marker', 'none', 'HandleVisibility', 'off');
else
    h = plot(ax, [0 0], [value value], style, 'Color', colour, ...
        'LineWidth', lw, 'Marker', 'none', 'HandleVisibility', 'off');
end

h.UserData = struct('kind', kind, 'value', value);

end


% ----------------------------------------------------------------------------
function fit_ref_lines(hs)
%FIT_REF_LINES  Stretch each guide line across its axes, limits now being set.

for h = reshape(hs, 1, [])

    if ~isgraphics(h)
        continue
    end

    ax = ancestor(h, 'axes');
    u  = h.UserData;

    if u.kind == 'v'
        set(h, 'XData', [u.value u.value], 'YData', ylim(ax));
    else
        set(h, 'XData', xlim(ax), 'YData', [u.value u.value]);
    end

end

end


% ----------------------------------------------------------------------------
function place_legend(lgd, ax, dxCm, dyCm)
%PLACE_LEGEND  Pin a legend to the top left of its axes, by hand.
%
%   'Location','northwest' leaves MATLAB to choose the inset, which differs with
%   the number of entries and the label lengths. DXCM is measured from the left
%   edge of the axes and DYCM from its top edge down to the top of the legend,
%   so the legend sits in the same place whatever it contains.

ap = ax.Position;

lgd.Units    = 'centimeters';
lp           = lgd.Position;
lgd.Position = [ap(1) + dxCm, ap(2) + ap(4) - dyCm - lp(4), lp(3), lp(4)];

end


% ----------------------------------------------------------------------------
function ax = new_axes(fig, posCm)
%NEW_AXES  An axes placed by hand, in centimetres.
%
%   LineStyleOrder is pinned to a plain solid line. MATLAB cycles that order
%   across successive plots on one axes, and an entry in it can carry a marker
%   as well as a dash pattern, so a curve can come out dashed or studded with
%   circles even though neither was asked for. An axes with two y rulers
%   installs its own order, which is how the band power came out dashed and the
%   tracking error came out as a chain of circles.
%
%   Layer is set to 'top' so the rulers, ticks and tick labels are drawn in
%   front of the data rather than behind it. MATLAB's default is 'bottom', which
%   lets a curve that reaches the edge of its axes paint over the axis line and
%   leave it looking broken.

ax = axes('Parent', fig, 'Units', 'centimeters', 'Position', posCm, ...
    'LineStyleOrder', '-', 'NextPlot', 'add', 'Layer', 'top');

end


% ----------------------------------------------------------------------------
function lab = mode_label(mode)
%MODE_LABEL  What each mode is, in words a caption can reuse.

switch mode
    case 'actual'
        lab = 'every trial, as recorded';
    case 'mean'
        lab = 'trial-averaged waveforms';
    case 'residual'
        lab = 'trial-wise residuals';
    otherwise
        lab = mode;
end

end


% ----------------------------------------------------------------------------
function r = positive_peak(st)
%POSITIVE_PEAK  The largest POSITIVE group mean correlation over lags.
%
%   Derived here rather than read from a stored field, so that the figure can be
%   redrawn from any stored result without rerunning the analysis. Both signals
%   repeat twice per movement cycle, so the correlation curve carries a deep
%   trough half a period from its peak. That trough is a consequence of the
%   periodicity, not a finding, and a peak defined by absolute value lands on it
%   whenever it is the deeper of the two.

r = max(st.groupMean);

end


% ----------------------------------------------------------------------------
function v = null_max_level(st)
%NULL_MAX_LEVEL  The critical value of the maximum statistic under the null.
%
%   Panel c plots a maximum over lags, whose null is wider than the pointwise
%   null drawn in panel b. Derived from the stored null distribution so that no
%   rerun is needed.

v = NaN;

if ~isfield(st, 'nullMax') || isempty(st.nullMax)
    return
end

a = 0.05;
if isfield(st, 'settings') && isfield(st.settings, 'alpha')
    a = st.settings.alpha;
end

v = prctile(st.nullMax, 100*(1 - a));

end


% ----------------------------------------------------------------------------
function y = collapse_conditions(statArray)
%COLLAPSE_CONDITIONS  Mean of the per-condition group curves.

M = vertcat(statArray.groupMean);
y = mean(M, 1, 'omitnan');

end


% ----------------------------------------------------------------------------
function s = format_p(p, nPerm)
%FORMAT_P  A permutation p value, never claiming more precision than it has.

if isnan(p)
    s = '';
elseif p <= 1/(nPerm + 1)
    s = sprintf('< %.3f', 1/(nPerm + 1));
else
    s = sprintf('%.3f', p);
end

end


% ----------------------------------------------------------------------------
function [m, sem] = mean_and_sem(X)
%MEAN_AND_SEM  Column mean and standard error, ignoring missing entries.

valid  = ~isnan(X);
nValid = sum(valid, 1);

Z         = X;
Z(~valid) = 0;
m         = sum(Z, 1) ./ max(nValid, 1);

D         = (X - m) .^ 2;
D(~valid) = 0;
sem       = sqrt(sum(D, 1) ./ max(nValid - 1, 1)) ./ sqrt(max(nValid, 1));

m(nValid == 0)  = NaN;
sem(nValid < 2) = NaN;

end