%% Figure 4: bilateral parieto-occipital ERSPs (paper figure)
%
% The regional-dissociation counterpart to Figure 3. Same layout, same
% tests, same code (plot_cluster_pair_figure / load_cluster_pair_data /
% report_cluster_pair_stats), pointed at the parieto-occipital cluster
% pair instead of the sensorimotor one.
%
% That identity is the point, not a convenience: the Results section
% argues that demand graded sensorimotor power and left parieto-occipital
% power unchanged. A null shown in a different format from the positive
% result invites the suspicion that the display was chosen to flatter the
% null. Drawn by the same function, the two figures can be compared
% panel for panel. Do not "improve" this figure on its own -- any layout
% change belongs in plot_cluster_pair_figure.m, where it reaches both.
%
% What to expect, if the Results text is right: the three condition ERSP
% panels look alike, the RM-ANOVA panel is empty (it prints "no
% significant clusters" rather than rendering as a blank rectangle), the
% band-power traces show strong twice-per-cycle structure with the three
% conditions superimposed, and the eta-squared strips carry no black
% bars. The within-cycle modulation being large while the between-
% condition difference is absent is exactly the claim.
%
% Split into a slow load (section 2) and a fast plot (section 3), same as
% Figure 3: run sections 1-2 ONCE, then re-run section 3 while iterating.
%
% Prerequisites
%   * EEGLAB on the path, with DIPFIT and FieldTrip
%   * main_ersp_pipeline_qc.m already run for Left_Parieto_Occipital and
%     Right_Parieto_Occipital (their *_ersp_qc_results.mat must exist;
%     load_cluster_pair_data errors by name if one is missing)
%
%% 1. Set up --------------------------------------------------------------
clc; clear;
thisFile = which('main_figure4_parieto_occipital');
if isempty(thisFile)
    error(['Could not locate main_figure4_parieto_occipital.m on the MATLAB ' ...
        'path or in the current folder. cd to the folder containing this ' ...
        'file (or add it to the path) and try again.']);
end
addpath(genpath(fileparts(thisFile)));
addpath(find_config_folder(thisFile));
cfg = ansymb_config();
p   = ersp_params();
p.bandStats.familyFile = fullfile(cfg.figures, 'band_pvalue_family.mat');

if ~exist('ALLEEG', 'var')
    eeglab;
end

%% 2. Load Figure 4 data ONCE -----------------------------------------------
% Slow: loads both parieto-occipital clusters' saved results and their
% .study files (ALLEEG included), then runs the band-power permutation
% test. Do not re-run while just tweaking the layout.
figure4Data = load_cluster_pair_data(cfg, p, ...
    {'Left_Parieto_Occipital', 'Right_Parieto_Occipital'});

%% 3. Build and save Figure 4 -- RE-RUN THIS SECTION WHILE ITERATING --------
outputPath = fullfile(cfg.figures, 'Figure4');
plot_cluster_pair_figure(figure4Data, p, outputPath, ...
    'figure4_parieto_occipital', 'Figure 4: Parieto-occipital clusters');

%% 4. Print every number the Results text needs ------------------------------
% Same report as Figure 3's section 4, so the two sections' numbers are
% directly comparable. For this figure the numbers that matter are the
% ones that should come back NULL: the per-band "significant: NONE"
% lines and the RM-ANOVA "no significant time-frequency cluster" line
% are what fill the \ph{all p > ...} placeholder.
%
% Note that the report prints each band's condition means and their
% ordering regardless of significance. A monotonic ordering printed for a
% NON-significant band is not a result and must not be written up as a
% trend -- the cluster test is the arbiter here, exactly as in Figure 3.
report_cluster_pair_stats(figure4Data, p, outputPath, 'figure4');

%% Local functions ---------------------------------------------------------
function configDir = find_config_folder(thisFile)
% Walks up from THISFILE's own folder looking for a 'config' sibling.
% Copied from main_figure3_primary_motor.m on purpose -- a script-local
% helper, not shared code.
    searchDir = fileparts(thisFile);
    while true
        candidate = fullfile(searchDir, 'config');
        if isfolder(candidate)
            configDir = candidate;
            return
        end
        parent = fileparts(searchDir);
        if strcmp(parent, searchDir)
            break   % reached the filesystem root without finding it
        end
        searchDir = parent;
    end
    error('main_figure4_parieto_occipital:ConfigNotFound', ...
        ['Could not find a ''config'' folder above %s. Add it to the ' ...
         'MATLAB path yourself before running this script.'], thisFile);
end
