function STUDY = build_stats_study(cfg, p)
% BUILD_STATS_STUDY  A STUDY configured with the statistics parameters
% used for the published analysis.
%
%   STUDY = BUILD_STATS_STUDY(CFG, P)
%
% Generalises create_stats.m from the pre-cleanup codebase: same design,
% same pop_statparams call, but every value comes from P (ersp_params()),
% including P.stats.alpha = 0.05, rather than a hardcoded 0.01 that the
% original overrode ad hoc wherever a figure needed 0.05 in practice.
%
% Loads one ROI STUDY purely for its 3-condition, within-subject design
% (every ROI STUDY carries the same design and pairing; the original
% hardcoded Right_Prim_Motor.study for this, kept here for parity -- any
% ROI would do). ERSP_CLUSTER_STATS reads STUDY.etc.statistics and
% STUDY.design(STUDY.currentdesign).variable directly, for both the
% omnibus and the pairwise tests, so this one STUDY is built once and
% reused, unmodified except for a per-cluster naccu override on small
% clusters, across all 8 ROIs and both kinds of test.
%
% Unlike create_stats.m, this does not call add_anatomical_labels or
% keep_one_ic_per_subject: those affect STUDY.cluster, which nothing here reads
% (the QC pipeline gets its subject/IC assignment from
% Subjects_ICs_in_clusters.mat instead), and STUDY.etc.statistics depends
% only on the design and pairing, not on the clustering.

    referenceStudyFile = p.roiStudyFiles{1};
    referenceStudyName = erase(referenceStudyFile, '.study');
    studyPath = fullfile(cfg.study, 'Epoched_data', 'multiple_clustering');

    [STUDY, ALLEEG] = pop_loadstudy('filename', referenceStudyFile, ...
        'filepath', fullfile(studyPath, referenceStudyName));
    STUDY = std_maketrialinfo(STUDY, ALLEEG);
    STUDY = std_makedesign(STUDY, ALLEEG, 1, ...
        'name', p.design.name, 'delfiles', 'off', 'defaultdesign', 'off', ...
        'variable1', p.design.variable, 'values1', p.design.values, ...
        'vartype1', 'categorical', 'pairing', p.design.pairing);

    STUDY = pop_statparams(STUDY, ...
        'condstats',         p.stats.condStats, ...
        'groupstats',        p.stats.groupStats, ...
        'method',            p.stats.method, ...
        'singletrials',      p.stats.singleTrials, ...
        'mode',              p.stats.mode, ...
        'fieldtripalpha',    p.stats.alpha, ...
        'fieldtripmethod',   p.stats.fieldtripMethod, ...
        'fieldtripmcorrect', p.stats.mcorrect, ...
        'fieldtripnaccu',    p.stats.nRandomisations);
end