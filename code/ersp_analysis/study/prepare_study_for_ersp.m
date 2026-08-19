function [STUDY, ALLEEG, clustersToPlot] = prepare_study_for_ersp(STUDY, ALLEEG, p, eeglabPath)
% PREPARE_STUDY_FOR_ERSP  Put a loaded ROI STUDY into the state the plots assume.
%
%   [STUDY, ALLEEG, CLUSTERSTOPLOT] = ...
%       PREPARE_STUDY_FOR_ERSP(STUDY, ALLEEG, P, EEGLABPATH)
%
%   P               parameter struct from ersp_params()
%   EEGLABPATH      EEGLAB installation root, needed to find the AAL atlas
%   CLUSTERSTOPLOT  cluster indices selected by the repeated k-means run
%
% Four steps, in order:
%   1. build the within-subject 3-condition design (P1/P3/P6)
%   2. label each cluster with its AAL anatomical region
%   3. reduce clusters to one IC per subject
%   4. read out which clusters the ROI clustering selected
%
% Step 3 must follow step 2: the labels are attached to cluster indices, and
% reducing the clusters rewrites STUDY.cluster.
%
% This was inline in the middle of the old main.m, repeated per ROI.

    STUDY = std_makedesign(STUDY, ALLEEG, 1, ...
        'name',         p.design.name, ...
        'delfiles',     'off', ...
        'defaultdesign', 'off', ...
        'variable1',    p.design.variable, ...
        'values1',      p.design.values, ...
        'vartype1',     'categorical', ...
        'pairing',      p.design.pairing);

    STUDY = add_anatomical_labels(STUDY, eeglabPath);

    if p.stats.oneIcPerSubject
        STUDY = one_ic_per_subject(STUDY);
    end

    if ~isfield(STUDY.etc, 'bemobil') || ...
       ~isfield(STUDY.etc.bemobil, 'clustering') || ...
       ~isfield(STUDY.etc.bemobil.clustering, 'cluster_ROI_index')
        error('prepare_study_for_ersp:NoRoiIndex', ...
            ['STUDY.etc.bemobil.clustering.cluster_ROI_index is missing. ' ...
             'This STUDY did not come from the repeated k-means ROI ' ...
             'clustering stage.']);
    end
    clustersToPlot = STUDY.etc.bemobil.clustering.cluster_ROI_index;
end
