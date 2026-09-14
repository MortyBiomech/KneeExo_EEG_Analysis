function C = coupling_config(cfg)
%COUPLING_CONFIG  Every setting the coupling analysis uses, in one place.
%
%   C = COUPLING_CONFIG(CFG) returns the settings, the folders and the output
%   file names for the coupling analysis. Both RUN_CROSS_CORRELATION and
%   CHECKS/EPOCH_PAIRING_CHECK read from here, so the two can never disagree
%   about which cluster, which participants or which files they are working on.
%
%   Change the analysis here. The entry point carries only the run-time choices,
%   namely whether to rebuild the cached inputs and whether to reuse a cached
%   result.
%
%   A field of the same name in CFG always wins over the fallback path below, so
%   a deployment that stores the raw data elsewhere needs no edit in this file.
%
%   See also RUN_CROSS_CORRELATION, ENSURE_COUPLING_INPUTS.
%
%   Part of the KneeExo-EEG analysis code.

if nargin < 1 || isempty(cfg)
    cfg = kneeexo_config();
end

C = struct();
C.cfg = cfg;

% ---- what is analysed ---------------------------------------------------

% Which cluster. The clustering STUDY names are also the folder names.
C.cluster = 'Left_Parieto_Occipital';

% Participants, in the order the clustering used. The cluster files store
% positions in this list rather than participant numbers.
C.subjects = 5:18;

% Frequency bands. Lower edge inclusive, upper edge exclusive, so adjacent
% bands do not share a frequency bin.
C.bands = struct('theta', [4 8], 'alpha', [8 14]);

% Pressure conditions, in the plotting order.
C.conditions = [1 3 6];

% ---- how it is analysed -------------------------------------------------

% Largest lag to evaluate, as a percentage of the movement cycle.
%
% Both signals complete two cycles per movement, so their lagged correlation is
% itself periodic with a period of about 50% of the cycle: a lag of 50% aligns
% each bump with the NEXT bump, which returns a correlation as high as the one
% at lag zero. Searching for a peak over a window of plus or minus 50% therefore
% cannot tell a true simultaneity from a whole period of displacement, and the
% reported peak lag can land on the wrong bump. Half a period is the largest
% window in which a lag has one meaning, so 25% is the ceiling here rather than
% a matter of taste.
C.maxLagPct = 25;

% Observation level. Use 'trial' to match the original analysis, in which the
% movement cycles of a trial are averaged before correlating, or 'epoch' to
% treat every cycle as its own observation. The choice decides whether a
% residual is a trial-to-trial or a cycle-to-cycle fluctuation, which is the
% wording the manuscript has to use.
C.aggregate = 'trial';

% Trials with a recorded score of zero were excluded from the original
% analysis. The reason belongs in the Methods, so keep this true only if that
% reason holds.
C.dropZeroScore = true;

% Cycles whose flexion to extension transition sits at an unusual fraction.
% The original flagged them and kept them.
C.dropOutlierCycles = false;

% 'none' or 'divisive'. A Pearson correlation is invariant to rescaling, so a
% divisive baseline can only act through the weighting of frequencies inside a
% band. It is offered for comparison, not because it should change anything.
C.baseline = 'none';

% Permutations and seed.
C.nPerm   = 1000;
C.rngSeed = 42;

% Largest residual accepted when matching an EEG epoch to an experiment epoch,
% in milliseconds. Movement cycles are about a second apart, so a correct match
% is accurate to a few milliseconds.
C.toleranceMs = 50;

% ---- where the raw data live --------------------------------------------
%
% Three folders, spelled out. They sit under cfg.raw, which is the acquisition
% tree rather than this repository. Change them here if the data move.
%
% They are deliberately NOT read from cfg by a generic field name. A name such
% as "epoched" means the single-subject EEG epochs in one part of the project
% and the epoched experiment streams in another, so a config lookup can resolve
% to the wrong folder and the analysis then reads the right file name out of the
% wrong tree. CHECK_PATHS below turns that class of mistake into an immediate
% error naming the folder and the missing file.

C.paths = struct();

% Single-trial time-frequency files, S<n>.icatimef, one per participant.
C.paths.icatimef = fullfile(cfg.raw, '5_single-subject-EEG-analysis', ...
    'Epoched_data');

% Epoched experiment streams, sub-<n>/Epochs_FlextoFlex_based.mat and
% sub-<n>/Trials_Info.mat.
C.paths.epochs = fullfile(cfg.raw, '6_Trials_Info_and_Epoched_data');

% Clustering STUDY files, <cluster>/<cluster>.study.
C.paths.study = fullfile(cfg.raw, '7_STUDY', 'Epoched_data', ...
    'multiple_clustering');

% Cluster to component mapping. In the original project this was
% Subjects_ICs_in_clusters.mat under Final_paper_plot_generation/
% Detailed_Analysis_on_TF_regions/extracting Subjects and ICs in the brain
% clusters. Copy it into data/derived so the analysis ships with it.
C.clusterICFile = fullfile(cfg.derived, 'Subjects_ICs_in_clusters.mat');

% ---- where the outputs go -----------------------------------------------

figureDir = fullfile(cfg.root, 'figures');
if isfield(cfg, 'figures') && ~isempty(cfg.figures)
    figureDir = cfg.figures;
end
if exist(figureDir, 'dir') ~= 7
    mkdir(figureDir);
end

C.files = struct();
C.files.pairing     = fullfile(cfg.derived, 'epoch_pairing_map.mat');
C.files.error       = fullfile(cfg.derived, 'tracking_error_warped.mat');
C.files.precomputed = fullfile(cfg.derived, ...
    sprintf('figure5_coupling_%s.mat', C.cluster));
% One folder per figure, holding every format side by side plus the statistics
% report, which is how Figure4/ is laid out on disk:
%     Figure4/figure4_parieto_occipital.{eps,pdf,png,svg}
%     Figure4/figure4_stats_report.txt
C.files.figureDir     = fullfile(figureDir, 'Figure5');
C.files.figureName    = sprintf('figure5_%s', lower(C.cluster));
C.files.figureFormats = {'eps', 'pdf', 'png', 'svg'};
C.files.statsReport   = fullfile(C.files.figureDir, 'figure5_stats_report.txt');

if exist(C.files.figureDir, 'dir') ~= 7
    mkdir(C.files.figureDir);
end

% ---- the subset that decides whether a cached result is still valid ------

% Bump this whenever the shape of the stored result changes, so a cache written
% by an older version of the code is rebuilt rather than loaded and misread.
% History:
%   1  first version
%   2  peakR is the largest positive correlation rather than the largest
%      absolute one, troughR and nullMax95 added, waveformAll replaces waveform
C.resultVersion = 2;

C.settings = struct('resultVersion', C.resultVersion, ...
    'cluster', C.cluster, 'subjects', C.subjects, ...
    'bands', C.bands, 'conditions', C.conditions, 'maxLagPct', C.maxLagPct, ...
    'aggregate', C.aggregate, 'dropZeroScore', C.dropZeroScore, ...
    'dropOutlierCycles', C.dropOutlierCycles, 'baseline', C.baseline, ...
    'nPerm', C.nPerm, 'rngSeed', C.rngSeed);

% ---- fail now rather than an hour into the run --------------------------

check_paths(C);

end


% ----------------------------------------------------------------------------
function check_paths(C)
%CHECK_PATHS  Verify that every folder holds what this analysis expects.
%
%   Each folder is identified by a file that only that folder has, so a folder
%   that exists but is the wrong one is caught as surely as a missing folder.
%   Every participant is checked, because a single absent sub-<n> folder is
%   otherwise found only when the loop reaches it.

names  = {'icatimef', 'epochs', 'study'};
values = {C.paths.icatimef, C.paths.epochs, C.paths.study};

% A folder that exists but is also one of the others is always a mistake.
for a = 1:numel(names)
    for b = a+1:numel(names)
        if strcmpi(strip_sep(values{a}), strip_sep(values{b}))
            error('coupling_config:DuplicatePath', ...
                ['The "%s" and "%s" folders both point at\n  %s\nThey hold ' ...
                'different data and cannot be the same folder. Fix them in ' ...
                'coupling_config.m.'], names{a}, names{b}, values{a});
        end
    end
end

for k = 1:numel(names)
    if exist(values{k}, 'dir') ~= 7
        error('coupling_config:MissingFolder', ...
            ['Cannot find the "%s" folder at\n  %s\nSet it in ' ...
            'coupling_config.m under "where the raw data live".'], ...
            names{k}, values{k});
    end
end

% Single-trial time-frequency files.
missing = {};
for s = C.subjects
    f = fullfile(C.paths.icatimef, sprintf('S%d.icatimef', s));
    if exist(f, 'file') ~= 2
        missing{end+1} = sprintf('S%d.icatimef', s); %#ok<AGROW>
    end
end
report_missing(missing, 'icatimef', C.paths.icatimef, ...
    'the single-trial time-frequency files');

% Epoched experiment streams.
missing = {};
for s = C.subjects
    d = fullfile(C.paths.epochs, sprintf('sub-%d', s));
    for f = {'Epochs_FlextoFlex_based.mat', 'Trials_Info.mat'}
        if exist(fullfile(d, f{1}), 'file') ~= 2
            missing{end+1} = fullfile(sprintf('sub-%d', s), f{1}); %#ok<AGROW>
        end
    end
end
report_missing(missing, 'epochs', C.paths.epochs, ...
    'the epoched experiment streams');

% The clustering STUDY of the cluster being analysed.
studyFile = fullfile(C.paths.study, C.cluster, [C.cluster '.study']);
if exist(studyFile, 'file') ~= 2
    error('coupling_config:MissingStudy', ...
        ['Cannot find the STUDY for cluster "%s" at\n  %s\nCheck the cluster ' ...
        'name and the "study" folder in coupling_config.m.'], ...
        C.cluster, studyFile);
end

% The cluster to component mapping.
if exist(C.clusterICFile, 'file') ~= 2
    error('coupling_config:MissingClusterICs', ...
        ['Cannot find the cluster to component mapping at\n  %s\nIt is the ' ...
        'file holding SUBJECTS_ICS. Copy it into data/derived, or point ' ...
        'C.clusterICFile at it in coupling_config.m.'], C.clusterICFile);
end

end


% ----------------------------------------------------------------------------
function report_missing(missing, name, folder, what)
%REPORT_MISSING  One error listing everything absent, not one error per file.

if isempty(missing)
    return
end

shown = missing(1:min(6, numel(missing)));
tail  = '';
if numel(missing) > numel(shown)
    tail = sprintf('\n  ... and %d more', numel(missing) - numel(shown));
end

error('coupling_config:WrongFolder', ...
    ['The "%s" folder\n  %s\ndoes not hold %s. Missing:\n  %s%s\n' ...
    'Either the folder is wrong or the data are incomplete. Set it in ' ...
    'coupling_config.m under "where the raw data live".'], ...
    name, folder, what, strjoin(shown, sprintf('\n  ')), tail);

end


% ----------------------------------------------------------------------------
function p = strip_sep(p)
%STRIP_SEP  Drop a trailing separator so two spellings of one folder compare equal.

while ~isempty(p) && (p(end) == '/' || p(end) == '\')
    p(end) = [];
end

end