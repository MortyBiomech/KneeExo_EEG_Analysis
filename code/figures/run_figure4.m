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
%   * run_ersp_stats.m already run for Left_Parieto_Occipital and
%     Right_Parieto_Occipital (their *_ersp_qc_results.mat must exist;
%     load_cluster_pair_data errors by name if one is missing)
%
%% 1. Set up --------------------------------------------------------------
clc; clear;
% Locate config/, which is always two levels up from code/<stage>/.
%
% mfilename is empty when these lines are pasted into the command window,
% and reports a temporary helper file when a single %% section is run with
% Ctrl+Enter, so neither case can be trusted. Fall back to this file's own
% name, which resolves whenever the file is runnable at all.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('run_figure4');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_figure4.m and press Run, ' ...
           'or make its folder the current folder first. Pasting the ' ...
           'bootstrap into the command window gives MATLAB nothing to ' ...
           'resolve the path from.']);
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);
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
