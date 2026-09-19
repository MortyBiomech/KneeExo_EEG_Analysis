%% Figure 3: bilateral primary motor ERSPs (paper figure, not sanity check)
%
% Builds Figure 3 from the already-saved QC'd ERSP results
% (Left_Prim_Motor_ersp_qc_results.mat, Right_Prim_Motor_ersp_qc_results.mat,
% written by run_ersp_stats.m) plus each cluster's own .study file
% for dipoles and topography.
%
% Split into a slow, one-time load (section 2) and a fast, repeatable
% plot (section 3), since loading a .study file pulls in its ALLEEG and
% is slow. While iterating on the figure's layout: run sections 1-2 ONCE,
% then re-run section 3 by itself (place the cursor in it and use your
% editor's "Run Section" command) as many times as you like -- it reuses
% figure3Data instead of reloading anything.
%
% plot_cluster_pair_figure.m holds the layout and drawing code, shared
% with Figure 4 so the two cannot diverge; load_cluster_pair_data.m is
% what section 2 loads.
%
% Prerequisites
%   * EEGLAB on the path, with DIPFIT and FieldTrip
%   * run_ersp_stats.m already run for Left_Prim_Motor and
%     Right_Prim_Motor (their *_ersp_qc_results.mat files must exist)
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
    thisFile = which('run_figure3');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_figure3.m and press Run, ' ...
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

%% 2. Load Figure 3 data ONCE -----------------------------------------------
% Slow: loads both clusters' saved results and their .study files
% (ALLEEG included). Do not re-run this section while just tweaking the
% figure's layout -- re-run section 3 instead.
figure3Data = load_cluster_pair_data(cfg, p, ...
    {'Left_Prim_Motor', 'Right_Prim_Motor'});

%% 3. Build and save Figure 3 -- RE-RUN THIS SECTION WHILE ITERATING --------
outputPath = fullfile(cfg.figures, 'Figure3');
plot_cluster_pair_figure(figure3Data, p, outputPath, ...
    'figure3_sensorimotor', 'Figure 3: Sensorimotor clusters');

%% 4. Print every number the Results text needs ------------------------------
% Reads the same figure3Data the figure is drawn from -- per-cluster n and
% dipole centroid, the ERSP RM-ANOVA cluster's frequency and cycle extent,
% each band's significant cycle window with its p, and the condition
% ordering behind the "decreased monotonically with pressure" wording.
% Nothing is recomputed here, so the text cannot drift from the figure.
%
% Also writes figure3_stats_report.txt into outputPath, so the numbers
% outlive a clc. Fast -- re-run it freely.
report_cluster_pair_stats(figure3Data, p, outputPath, 'figure3');
