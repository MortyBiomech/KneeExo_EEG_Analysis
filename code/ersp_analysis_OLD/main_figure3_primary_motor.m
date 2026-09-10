%% Figure 3: bilateral primary motor ERSPs (paper figure, not sanity check)
%
% Builds Figure 3 from the already-saved QC'd ERSP results
% (Left_Prim_Motor_ersp_qc_results.mat, Right_Prim_Motor_ersp_qc_results.mat,
% written by main_ersp_pipeline_qc.m) plus each cluster's own .study file
% for dipoles and topography.
%
% Split into a slow, one-time load (section 2) and a fast, repeatable
% plot (section 3), since loading a .study file pulls in its ALLEEG and
% is slow. While iterating on the figure's layout: run sections 1-2 ONCE,
% then re-run section 3 by itself (place the cursor in it and use your
% editor's "Run Section" command) as many times as you like -- it reuses
% figure3Data instead of reloading anything.
%
% See plotting/plot_figure3_primary_motor.m for the actual layout and
% drawing code, and load_figure3_data.m for what section 2 loads.
%
% Prerequisites
%   * EEGLAB on the path, with DIPFIT and FieldTrip
%   * main_ersp_pipeline_qc.m already run for Left_Prim_Motor and
%     Right_Prim_Motor (their *_ersp_qc_results.mat files must exist)
%
%% 1. Set up --------------------------------------------------------------
clc; clear;
thisFile = which('main_figure3_primary_motor');
if isempty(thisFile)
    error(['Could not locate main_figure3_primary_motor.m on the MATLAB path ' ...
        'or in the current folder. cd to the folder containing this ' ...
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

%% 2. Load Figure 3 data ONCE -----------------------------------------------
% Slow: loads both clusters' saved results and their .study files
% (ALLEEG included). Do not re-run this section while just tweaking the
% figure's layout -- re-run section 3 instead.
figure3Data = load_figure3_data(cfg, p);

%% 3. Build and save Figure 3 -- RE-RUN THIS SECTION WHILE ITERATING --------
outputPath = fullfile(cfg.figures, 'Figure3');
plot_figure3_primary_motor(figure3Data, p, outputPath);

%% 4. Print every number the Results text needs ------------------------------
% Reads the same figure3Data the figure is drawn from -- per-cluster n and
% dipole centroid, the ERSP RM-ANOVA cluster's frequency and cycle extent,
% each band's significant cycle window with its p, and the condition
% ordering behind the "decreased monotonically with pressure" wording.
% Nothing is recomputed here, so the text cannot drift from the figure.
%
% Also writes figure3_stats_report.txt into outputPath, so the numbers
% outlive a clc. Fast -- re-run it freely.
report_figure3_stats(figure3Data, p, outputPath);

%% Local functions ---------------------------------------------------------
function configDir = find_config_folder(thisFile)
% Walks up from THISFILE's own folder looking for a 'config' sibling, so
% this does not depend on how many folders deep this script happens to
% sit under the repo root (config is a top-level folder next to code/,
% not nested inside it -- a fixed fileparts(fileparts(fileparts(...)))
% count, copied from main_ersp_pipeline_qc.m, assumed the wrong depth for
% wherever this file ended up).
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
    error('main_figure3_primary_motor:ConfigNotFound', ...
        ['Could not find a ''config'' folder above %s. Add it to the ' ...
         'MATLAB path yourself before running this script.'], thisFile);
end
