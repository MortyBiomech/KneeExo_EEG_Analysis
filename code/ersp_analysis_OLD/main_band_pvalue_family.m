%% Band-power multiple-comparison family: build it once, before the figures
%
% Runs the 1D band-power permutation test for EVERY cluster the paper
% reports and stores all p-values in one .mat. Figures 3 and 4 read that
% file to get the Benjamini-Hochberg cutoff their eta^2 bars use.
%
% WHY THIS IS ITS OWN SCRIPT, and not a section inside the figure scripts.
% The cluster list below IS the multiple-comparison family: its length
% sets m, m sets the correction, and the correction decides which bars
% appear. If this call lived in both main_figure3 and main_figure4, the
% list would exist twice and could drift, so the family -- and therefore
% the published figures -- would depend on which figure you happened to
% run last. One list, one place, one definition.
%
% FAST, and independent of EEGLAB. compute_band_stats needs only the saved
% *_ersp_qc_results.mat files; STUDY/ALLEEG are loaded by the figure
% scripts solely for the dipole and topography panels. So this does not
% pay the .study cost and can be run on its own.
%
% RE-RUN THIS WHENEVER:
%   * the set of clusters reported in the paper changes
%   * p.bandStats.nPerm or p.bandStats.alpha changes
%   * p.plot.bandEdges / bandNames change
% The figures refuse to use a family built under different settings, so
% they will tell you if you forget.
%
% Prerequisites
%   * main_ersp_pipeline_qc.m already run for every cluster listed below
%
%% 1. Set up --------------------------------------------------------------
clc; clear;
thisFile = which('main_band_pvalue_family');
if isempty(thisFile)
    error(['Could not locate main_band_pvalue_family.m on the MATLAB path ' ...
        'or in the current folder. cd to the folder containing this file ' ...
        '(or add it to the path) and try again.']);
end
addpath(genpath(fileparts(thisFile)));
addpath(find_config_folder(thisFile));
cfg = ansymb_config();
p   = ersp_params();
p.bandStats.familyFile = fullfile(cfg.figures, 'band_pvalue_family.mat');

%% 2. Define the family and build it ---------------------------------------
% EVERY cluster whose band tests the paper reports, and nothing else.
% Listing fewer makes the correction too lenient; listing clusters you
% never report makes it needlessly harsh.
reportedClusters = { ...
    'Left_Prim_Motor', 'Right_Prim_Motor', ...
    'Left_Parieto_Occipital', 'Right_Parieto_Occipital'};

family = build_band_pvalue_family(cfg, p, reportedClusters);

%% 3. What to do with the printout -----------------------------------------
% build_band_pvalue_family prints every test with its p and BH-adjusted q,
% and the critical cutoff. That table is what the Methods and Results need:
%   * quote q alongside p for each significant band
%   * state the family size m and that bands with no suprathreshold
%     cluster were entered as p = 1 (they are still tests, and they set m)
%   * state that this correction sits ON TOP of the within-band cluster
%     correction, which handles multiple comparisons across cycle time
%
% Now run main_figure3_primary_motor.m and main_figure4_parieto_occipital.m
% in any order.

%% Local functions ---------------------------------------------------------
function configDir = find_config_folder(thisFile)
% Walks up from THISFILE's own folder looking for a 'config' sibling.
% Copied from the figure scripts on purpose -- a script-local helper.
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
    error('main_band_pvalue_family:ConfigNotFound', ...
        ['Could not find a ''config'' folder above %s. Add it to the ' ...
         'MATLAB path yourself before running this script.'], thisFile);
end
