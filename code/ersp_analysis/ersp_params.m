function p = ersp_params()
% ERSP_PARAMS  Every analysis choice behind the cluster ERSP figures.
%
%   P = ERSP_PARAMS()
%
% One place for the numbers that define the ERSP analysis, so that they can
% be read, cited and changed without going through the plotting code. In the
% original these were spread over four files and, in the case of the
% significance level, reassigned three times inside the loop that used it.
%
% Paths are NOT here -- those come from ansymb_config().
    %% Regions of interest -------------------------------------------------
% One STUDY file per anatomical ROI, each the result of its own repeated
% k-means clustering run. The ICs are the same in all of them; only the
% clustering differs, so any one of them can be loaded to precompute.
    p.roiStudyFiles = { ...
'Right_Prim_Motor.study', ...
'Right_PreMot_SuppMot.study', ...
'Right_Parieto_Occipital.study', ...
'Prime_Visual.study', ...
'Left_Prim_Motor.study', ...
'Left_PreMot_SuppMot.study', ...
'Left_Parieto_Occipital.study', ...
'Left_Dorsal_ACC.study'};
    %% Time-frequency decomposition ---------------------------------------
% Passed to std_precomp_timewarp as 'erspparams'. Morlet wavelets with a
% cycle count rising from 3 at the lowest frequency, at 0.8 of the
% proportional rate (EEGLAB's [3 0.8] convention), over 250 log-spaced
% frequencies from 3 to 130 Hz.
    p.ersp.cycles     = [3 0.8];
    p.ersp.freqs      = [3 130];
    p.ersp.nfreqs     = 250;
    p.ersp.padratio   = 2;
    p.ersp.alpha      = NaN;      % no per-subject masking at this stage
    p.ersp.freqscale  = 'log';
    p.ersp.savetrials = 'off';
    p.ersp.basenorm   = 'off';    % dB baseline division, not z-score
    p.ersp.trialbase  = 'off';    % baseline the average, not each trial
% 'median latency baseline' is understood by std_precomp_timewarp only:
% the baseline becomes [0 lastEventLatency], i.e. the whole warped
% movement cycle. The task is continuous and cyclical, so there is no
% rest period that could serve as a conventional pre-stimulus baseline.
    p.ersp.baseline = 'median latency baseline';
% Round the group median warp latencies to a multiple of this, in ms.
    p.ersp.warpRoundToMs = 50;
    %% STUDY design --------------------------------------------------------
% Within-subject: every subject performed all three pressures.
    p.design.name      = '3-condition design';
    p.design.variable  = 'cond';
    p.design.values    = {'1', '3', '6'};      % PAM pressure in bar
    p.design.pairing   = 'on';
    p.design.reference = '1';                  % difference ERSPs are vs P1
    p.design.legend    = {'Low Pressure', 'Medium Pressure', 'High Pressure'};
% Locked-in condition colours, in p.design.values order (Low, Medium,
% High). Used wherever a figure needs one colour per condition, e.g. the
% band-power-vs-cycle row in Figure 3.
    p.design.colors    = [1 115 178; 222 143 5; 148 73 92] / 255;
    %% Statistics ----------------------------------------------------------
% Cluster-based permutation test over the time-frequency plane
% (FieldTrip montecarlo). Paired, because the design is within-subject.
    p.stats.mode           = 'fieldtrip';
    p.stats.method         = 'perm';
    p.stats.fieldtripMethod = 'montecarlo';
    p.stats.mcorrect       = 'cluster';
    p.stats.nRandomisations = 10000;
    p.stats.condStats      = 'on';
    p.stats.groupStats     = 'off';
    p.stats.singleTrials   = 'off';
% Significance level, used for BOTH the cluster-forming decision and the
% masks drawn on the difference plots. In the original this was set to
% 0.05 at the top of the plotting function and then reassigned to 0.01
% three separate times inside the cluster loop, with a comment warning
% that it was "hard coded in places". 0.01 is the value that was in force
% for every figure in the paper.
    p.stats.alpha = 0.05;
% Reduce each cluster to one IC per subject before testing, so that a
% subject contributing several components does not count several times.
    p.stats.oneIcPerSubject = true;
% Subtract a common baseline across conditions, so that the difference
% between conditions is not absorbed by per-condition baselining.
    p.stats.subtractCommonBaseline = 'on';
    p.stats.subtractSubjectMean    = 'on';
    %% Effect size ---------------------------------------------------------
    p.effect.method = 0;    % peak Cohen's d with a bootstrap 95% CI
    %% Bad-trial quality control (QC pipeline only) -------------------------
% Per-subject, per-condition outlier-trial rejection, run before
% baselining and averaging. Settings match the pre-cleanup analysis
% (the QC script + tf_qc_bad_trials.m) exactly.
    p.qc.highBand   = [35 80];   % Hz, EMG-contamination band
    p.qc.refBand    = [8 30];    % Hz, reference band for the HF/ref ratio
    p.qc.hotZ       = 5;         % |z| threshold for per-bin "hot pixel" outliers
    p.qc.zThreshold = 3;         % |z| threshold for the four trial-level metrics
    p.qc.corrType   = 'Spearman';
% Subject/IC assignment per cluster (QC pipeline only). Confirmed
% current for these 8 ROIs as of this run -- if the clustering is ever
% redone, this needs rebuilding too.
    p.subjectsIcsFile = 'D:\Morteza\MyProjects\KneeExo_EEG_Analysis\data\derived\';
    %% Plotting --------------------------------------------------------------
    p.plot.freqRange   = [3 130];      % Hz, y limits
    p.plot.freqTicks   = [4 8 14 30 60 120];
% Figure 3's ERSP row crops its y axis to this many Hz (per your request
% to see "up to 60 Hz, so probably the ylimit should go until 65 Hz or
% something") instead of showing the full freqTicks range up to 120 Hz --
% this only affects render_ersp_row's YLim/YTick, not the underlying
% data, and not plot_cluster_qc_sanity.m, which still shows the full range.
    p.plot.ersp3FreqYLimHz = 65;
    p.plot.cycleTicks  = {'0', '50', '100'};   % x labels, percent of cycle
    p.plot.xLabel      = 'Cycle (%)';
% Manuscript wording for each cluster, keyed by the internal label the QC
% pipeline derives from the .study filename (main_ersp_pipeline_qc.m does
% strrep(erase(roiStudyFile,'.study'),'_',' '), giving e.g. 'Right Prim
% Motor'). That internal label is a filename artifact, not anatomy, and
% should not appear on a submitted figure.
%
% "Sensorimotor cortex" rather than "primary motor cortex (M1)" is your
% call and the more defensible one: equivalent-dipole fitting on scalp
% EEG localizes to roughly a centimetre, while M1 and S1 sit on opposite
% banks of the central sulcus, so a cluster centroid near there can't be
% assigned to the precentral gyrus specifically. It also matches how the
% manuscript already frames the interpretation ("Sensorimotor alpha and
% beta power scale with physical demand"). NOTE: the Results text still
% introduces these clusters as "left and right primary motor cortex (M1)"
% and then says "the right M1 cluster" -- that wording needs updating to
% match this figure, or the two will disagree.
%
% Only the printed FIGURE label changes. s.name inside every saved
% *_ersp_qc_results.mat is untouched, so the QC figures, the cluster
% lookup in compute_cluster_ersp_qc.m and all existing .mat files keep
% working off the original keys.
    p.plot.clusterDisplayNames = { ...
        'Left Prim Motor',  'Left sensorimotor cortex'; ...
        'Right Prim Motor', 'Right sensorimotor cortex'};
% Frequency bands for Figure 3's band-power-vs-cycle row (theta through
% gamma). Edges are freqTicks(1:5), not typed out separately, so the
% bands used by the statistics (load_figure3_data.m /
% compute_band_stats) and the bands labelled on the panels
% (plot_figure3_primary_motor.m) can never drift apart.
    p.plot.bandEdges = p.plot.freqTicks(1:5);      % [4 8 14 30 60] Hz
    p.plot.bandNames = {'\theta (4-8 Hz)', '\alpha (8-14 Hz)', ...
        '\beta (14-30 Hz)', '\gamma (30-60 Hz)'};
% Band-power cluster permutation (Figure 3 only). The same test as Figure
% 2's muscle and tracking-error panels (RESULTS_BEHAVIOUR.m's
% clusterTest / rmF / clusterMass), ported to stats/cluster_perm_1d.m and
% run here on each frequency band's power-vs-cycle curve instead of a
% muscle envelope or tracking error.
    p.bandStats.nPerm        = 5000;    % matches Figure 2
    p.bandStats.alpha        = 0.05;    % matches Figure 2
    p.bandStats.etaThreshold = 0.14;    % dotted reference line on the
                                         % strip, matches Figure 2
% Typography. Nat Comms: sans-serif only (Arial or Helvetica), body
% text 5-8 pt at final print size, bold 8 pt lowercase panel labels
% (a, b, c, ...). Text must stay editable (vector export, embedded
% TrueType 2/42 fonts) -- never rasterize a figure with text in it,
% and never convert text to outlines/paths afterward.
    p.plot.fontName          = 'Arial';
    p.plot.fontSize          = 7;    % panel titles / general text
    p.plot.labelFontSize     = 7;    % axis labels (e.g. "Frequency (Hz)")
    p.plot.tickFontSize      = 6;    % tick labels
    p.plot.eventFontSize     = 5;    % small in-panel event labels (FlxS etc.)
    p.plot.panelLabelFontSize   = 8;       % a/b/c/d subplot labels
    p.plot.panelLabelFontWeight = 'bold';
    p.plot.panelLabelCase       = 'lower'; % a, b, c, ... not A, B, C, ...
    p.plot.renderer          = 'painters'; % vector renderer; keeps text and
% lines as real, editable objects
% instead of a rasterized bitmap
% Figure sizing. Nature Portfolio column widths: 89 mm (single column)
% and 183 mm (double column); 170 mm maximum height, leaving room for
% the caption below. This ERSP layout runs 4-5 panels side by side, so
% it needs the full double-column width; a narrower figure (e.g. a
% single comparison panel) should use .single instead.
    p.plot.columnWidthMM    = struct('single', 89, 'double', 180);
    p.plot.maxFigureHeightMM = 170;
    p.plot.figureWidthMM     = p.plot.columnWidthMM.double;
% Total figure HEIGHT, in mm, for PLOT_CLUSTER_QC_SANITY's fully manual
% layout -- fixed regardless of how many panels a figure has (4 for the
% conditions figure, 2 for the differences figure), so both come out the
% same overall size; see build_layout in that file for how the axes
% height is derived from this. NEW field, not yet confirmed against a
% printed figure -- 70 mm is a starting estimate for a 4-panel row at
% figureWidthMM = 180, not a value you have approved. Run the sanity
% check, look at the output, and adjust this number before treating it
% as final.
    p.plot.figureHeightMM    = 70;
    p.plot.mmToInch          = 1 / 25.4;   % so figure code can size in
% inches (what MATLAB's Units
% expects) without a stray
% conversion constant elsewhere
% Line weights. See the note at the top of this block: not a Nat Comms
% number, a hairline convention.
    p.plot.axisLineWidth = 0.5;   % pt, axes and tick marks
    p.plot.maskLineWidth = 0.75;  % pt, significance-cluster outline (was 2,
% far too heavy at print size)
% Colour. Nat Comms: RGB only (production converts to CMYK; never
% author in CMYK yourself); avoid red-green pairings, since these
% become indistinguishable under the most common form of colour
% blindness; no rainbow colormaps; no colored text (use black text
% with colored keylines/boxes instead). The event-marker colour below
% is a magenta, one of the pairings Nat Comms explicitly recommends in
% place of red-green; the diverging ERSP colormap in ersp_colormap.m
% is red-blue, not red-green, which is the safer of the two common
% diverging choices for colour-blind readers, but re-check it through
% a colour-blindness simulator before submission -- this params file
% doesn't touch ersp_colormap.m itself.
    p.plot.colorMode  = 'RGB';
    p.plot.maskColor  = [0.97 0 1];   % magenta, colorblind-safe accent
% Output resolution, for any raster fallback only (quick previews,
% Extended Data). Main figures must stay vector (see formats below);
% 300 dpi is Nat Comms' stated minimum, 450 dpi its stated maximum for
% photographic/halftone images -- resolution above that doesn't
% improve quality, it only inflates file size.
    p.plot.rasterDPI = 300;
% No gridlines, patterns, or decorative elements on graphs (Nat Comms
% explicitly asks these be avoided); kept here as a switch so future
% plotting code doesn't add them by accident.
    p.plot.showGrid = false;
% Event markers (timewarp latencies: FlxS, FlxE/ExtS, ExtE).
    p.plot.eventLabels = {'FlxS', sprintf('FlxE\nExtS'), 'ExtE'};
    p.plot.eventLabelY = 140;          % Hz, just above the frequency axis
% How far PLOT_CLUSTER_QC_SANITY shifts the FlxS/ExtE event LABELS in
% from the left/right axes edges, as a fraction of the full cycle width
% (0.03 = 3 percentage points of cycle). Label position only -- the
% FlxS/ExtE ticks and the underlying data stay exactly where they are.
    p.plot.eventLabelInsetFrac = 0.03;
% Gap, in mm, between each axis's tick-number labels and its axis-title
% text ('Cycle (%)' / 'Frequency (Hz)') in PLOT_CLUSTER_QC_SANITY. Both
% axis titles are now placed by hand at this exact offset (see
% draw_x_label / draw_y_label in that file), not by MATLAB's own
% xlabel()/ylabel() placement.
    p.plot.xLabelGapMM = 0.5;
    p.plot.yLabelGapMM = 0.5;
% Dashed vertical line marking the FlxE/ExtS event inside each panel (see
% draw_mid_event_line in PLOT_CLUSTER_QC_SANITY). Gray rather than the
% magenta used for significance outlines, so it reads as a timing
% reference, not a result.
    p.plot.eventLineColor = [0.4 0.4 0.4];
    p.plot.eventLineWidth = 0.5;   % pt, matches p.plot.axisLineWidth
% Colour limits, derived per figure from the data as [q, -q] with
% q = round(Q1 - 1.5*IQR, 1) -- the lower Tukey fence of all plotted
% values, mirrored so zero sits at the centre of the diverging map.
    p.plot.climQuantile = 0.25;
    p.plot.climIqrScale = 1.5;
    p.plot.climRound    = 1;           % decimal places
% File formats. Nat Comms accepted vector formats: .ai, .eps, .pdf,
% .ps, .svg -- main figures should be one of these, not a raster
% format. png is kept only for a quick on-screen check and must not
% be treated as the submission file.
    p.plot.formats = {'pdf', 'eps', 'svg', 'png'};   % png: preview only
end