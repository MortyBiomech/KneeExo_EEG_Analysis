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
% DOCUMENTATION ONLY -- no code reads this field, so changing it changes
% nothing. Each cluster is already reduced to one IC per subject UPSTREAM
% of this pipeline, when Subjects_ICs_in_clusters.mat is built: the
% component kept is the one explaining the larger variance of the
% channel-level data. compute_cluster_ersp_qc.m simply walks
% subjects(si)/ICs(si) as a 1:1 pairing and performs no selection of its
% own, so every ERSP, band trace and permutation test here uses exactly
% one component per participant.
%
% Left in place as a flag rather than deleted because it names a real
% property of the data, but do NOT read it as an enforced setting.
%
% The dipole and topography panels in Figures 3 and 4 use this same
% one-per-participant set: embed_cluster_dipoles builds its dipole list
% from those (subject, IC) pairs and calls dipplot directly, and
% embed_cluster_topoplot averages icawinv over them. They used to go
% through std_dipplot/std_topoplot, which draw the whole cluster, so the
% panels once showed more components than the analysis used -- that is no
% longer true and the captions need no caveat about it. Methods must
% still state the full cluster sizes and the selection criterion above,
% since the criterion lives outside this codebase entirely.
    p.stats.oneIcPerSubject = true;   % descriptive, not enforced
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
% Dipole-panel rendering, passed straight through to EEGLAB's dipplot by
% plot_cluster_pair_figure.m's embed_cluster_dipoles. Set EXPLICITLY on
% purpose: left to dipplot's own defaults, these resolve per .study file,
% and the parieto-occipital clusters (a different clustering run than the
% sensorimotor ones) came out drawn as plain spheres with no projection
% lines while the sensorimotor clusters showed them. Figures 3 and 4 only
% work as a comparison if they are rendered identically, so the rendering
% cannot be left to whatever each .study happens to carry.
%
%   projlines  dashed lines dropping each dipole onto the three MRI slice
%              planes -- what makes the 3D position readable
%   spheres    MUST BE 'off'. These two options are mutually exclusive in
%              dipplot: asking for both makes it print "projections
%              cannot be plotted for 3-D sphere" once per dipole and drop
%              the projection lines. Spheres look nicer in isolation, but
%              the projection lines are what let a reader judge where in
%              the head the cluster actually sits, so the lines win.
%   normlen    all dipole moment lines the same length, rather than
%              scaled by moment magnitude (which makes clusters with
%              weaker moments look sparser than they are)
%
% NOT VERIFIED against your EEGLAB version: older std_dipplot releases do
% not forward unrecognised options to dipplot. embed_cluster_dipoles
% tries these, and on failure warns loudly and falls back to the bare
% call. If you see that warning, check the names in your dipplot.m.
    p.plot.dipplotOptions = {'projlines', 'on', 'spheres', 'off', 'normlen', 'on'};
% Width of dipplot's dashed projection guide lines once embedded, in pt.
% Was 0.15, which is below Nature Portfolio's 0.25 pt minimum line width
% and thin enough that whether it renders at all depends on the renderer.
    p.plot.dipoleGuideLineWidth = 0.25;
% Cap on dipole marker size, in pt. With 'spheres','off' dipplot sizes
% dipole markers in POINTS for a full-size figure, and points do not
% shrink when the axes does -- uncapped, they render as blobs covering
% the whole brain in this ~18 mm panel. Same class of problem as
% topoplot's head cartoon (p.plot.* has no equivalent knob for that; see
% cap_head_cartoon_linewidth). Raise if the dipoles are too faint to
% see, lower if they crowd each other.
    p.plot.dipoleMarkerSize = 3;
% Thin light edge around each dipole marker. Without it, a dozen tightly
% clustered filled markers fuse into one angular mass at panel size --
% the edge is what keeps them readable as individual dipoles.
    p.plot.dipoleEdgeColor = [1 1 1];
% Whether to draw the dipole MOMENT line (the orientation stick from each
% dipole) at all. FALSE hides them and leaves only the location dots.
%
% They are hidden by default because 'normlen','on' gives every stick the
% same length, so they encode orientation and nothing else, and at this
% panel's ~18 mm orientation is not legible. They are also what made the
% panel unreadable: dipplot draws them at LineWidth 4, sized for a
% full-size figure, which rendered as thick blue blobs swamping the
% cluster (measured with debug_dipole_objects -- one solid, marker-less
% line per dipole).
%
% Set true to bring them back; dipoleMomentLineWidth then applies. Note
% that dipoleMomentLineWidth is a WIDTH IN POINTS and must stay numeric:
% to hide the sticks use this flag, not a width of 'off'.
    p.plot.showDipoleMoment      = false;
    p.plot.dipoleMomentLineWidth = 0.5;   % only used when the flag is true
% Scalp-map radii for the topography panel, passed to topoplot.
%
% HEADRAD is where the head cartoon is drawn. 0.5 is topoplot's standard:
% it marks the 10-20 equator, a reference line, NOT the edge of the head.
%
% PLOTRAD is how far out the map is interpolated. LEAVE THIS EMPTY. Empty
% means the option is not passed and topoplot uses its own default, which
% is the radius of the outermost electrode (floored at 0.5). That is the
% honest setting: colour appears between real electrodes and stops at the
% furthest one, so nothing is extrapolated and no measured channel is
% hidden. With a cap carrying electrodes below the equator, the map then
% extends past the head circle -- that spill is data, not an artifact.
%
% Pinning this to 0.5 was tried and reverted: it made the map end neatly
% on the head outline by discarding every electrode outside it, which is
% a cosmetic gain paid for with real channels. Set a number here only if
% you deliberately want that crop, and say so in the Methods if you do.
    p.plot.topoHeadRad = 0.5;
    p.plot.topoPlotRad = [];   % empty = topoplot's data-driven default
% One colour for every dipole in a cluster. dipplot otherwise gives each
% dipole its own colour from a cycling palette, which reads as though the
% colours mean something; they do not, since these are interchangeable
% members of one cluster.
    p.plot.dipoleColor = [0 0 0.8];
    p.plot.clusterDisplayNames = { ...
        'Left Prim Motor',         'Left sensorimotor cortex'; ...
        'Right Prim Motor',        'Right sensorimotor cortex'; ...
        'Left Parieto Occipital',  'Left parieto-occipital cortex'; ...
        'Right Parieto Occipital', 'Right parieto-occipital cortex'};
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
    p.bandStats.alpha        = 0.05;    % cluster-forming threshold, and the
                                         % per-test level -- NOT what the
                                         % figure's bars use; see fdrQ below
% Across-band, across-cluster correction. The cluster-based permutation
% test already controls error across cycle time WITHIN a band, but
% nothing corrects across the 4 bands x however many clusters the paper
% reports. With 16 tests at alpha = 0.05 the chance of at least one false
% positive is about 19%, which is exactly the regime a marginal result
% lands in.
%
% Benjamini-Hochberg over that family, at this q. FDR rather than
% Bonferroni because the bands are not independent (spectral leakage,
% broadband and 1/f structure couple them), so Bonferroni would be
% needlessly conservative; and because the manuscript already uses FDR
% for the LMM features, so this keeps one correction scheme throughout.
%
% The family itself lives in a .mat, written by build_band_pvalue_family
% (one fast pass over the *_ersp_qc_results.mat files, no .study load)
% and read by band_pvalue_fdr. Set p.bandStats.familyFile in your main script
% (it needs cfg, which this file does not have), e.g.
%   p.bandStats.familyFile = fullfile(cfg.figures, 'band_pvalue_family.mat');
% Without it the figures fall back to the uncorrected alpha and warn.
    p.bandStats.fdrQ         = 0.05;
    p.bandStats.familyFile   = '';      % set in the main script
% Fixed RNG seed for the band-power permutation test. Two reasons, and
% the second is not optional.
%
% 1. Reproducibility: the test resamples, so unseeded it returns a
%    slightly different p on every run (we saw 0.0334 and 0.0302 for the
%    same cluster). A published p-value a reviewer cannot reproduce from
%    your code is a problem.
%
% 2. Internal consistency: COMPUTE_BAND_STATS is called by BOTH
%    build_band_pvalue_family (whose p-values set the FDR cutoff) and
%    load_cluster_pair_data (whose p-values the figure compares against
%    that cutoff). Unseeded those are independent draws, so the figure
%    would test one set of numbers against a threshold derived from
%    another. Seeded, both callers produce identical values.
%
% Change it only if you want a different draw, and rebuild the family
% afterwards. State the seed and the permutation count in the Methods.
    p.bandStats.rngSeed      = 20260909;
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
    p.plot.xLabelGapMM = 2;
    p.plot.yLabelGapMM = 2;
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
