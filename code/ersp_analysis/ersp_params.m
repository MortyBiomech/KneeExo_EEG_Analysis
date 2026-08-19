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
    p.stats.alpha = 0.01;

    % Reduce each cluster to one IC per subject before testing, so that a
    % subject contributing several components does not count several times.
    p.stats.oneIcPerSubject = true;

    % Subtract a common baseline across conditions, so that the difference
    % between conditions is not absorbed by per-condition baselining.
    p.stats.subtractCommonBaseline = 'on';
    p.stats.subtractSubjectMean    = 'on';

    %% Effect size ---------------------------------------------------------
    p.effect.method = 0;    % peak Cohen's d with a bootstrap 95% CI

    %% Plotting ------------------------------------------------------------
    p.plot.freqRange   = [3 130];      % Hz, y limits
    p.plot.freqTicks   = [4 8 14 30 60 120];
    p.plot.cycleTicks  = {'0', '50', '100'};   % x labels, percent of cycle
    p.plot.xLabel      = 'Cycle (%)';
    p.plot.fontName    = 'Arial';
    p.plot.fontSize    = 16;
    p.plot.labelFontSize = 14;
    p.plot.tickFontSize  = 10;
    p.plot.eventFontSize = 8;

    % Event markers. The epoch is one flexion-to-flexion cycle, so the first
    % and last markers are the same event a cycle apart.
    p.plot.eventLabels = {'FlxS', sprintf('FlxE\nExtS'), 'ExtE'};
    p.plot.eventLabelY = 140;          % Hz, just above the frequency axis

    % Colour limits are derived per figure from the data as
    % [q, -q] with q = round(Q1 - 1.5*IQR, 1), i.e. the lower Tukey fence of
    % all plotted values, mirrored so zero sits at the centre of the map.
    p.plot.climQuantile = 0.25;
    p.plot.climIqrScale = 1.5;
    p.plot.climRound    = 1;           % decimal places

    % Outline drawn around significant regions on the difference plots.
    p.plot.maskColor     = [0.97 0 1];
    p.plot.maskLineWidth = 2;

    p.plot.formats = {'png', 'fig', 'svg'};
end
