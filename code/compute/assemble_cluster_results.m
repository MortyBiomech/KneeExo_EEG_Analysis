function s = assemble_cluster_results(clusterLabel, studyFile, clusterData, statsSTUDY, p)
% ASSEMBLE_CLUSTER_RESULTS  Omnibus + pairwise cluster-based permutation
% tests on QC'd ERSPs, assembled into the same result-struct shape
% PLOT_CLUSTER_ERSP produces for the non-QC'd pipeline (allTimes,
% allFreqs, condMask, erspdata, refIdx, compareIdx, erspDiff, permTest),
% plus the QC-specific fields (qc, nTrialsTotal, nTrialsBad, eventTimes).
% Keeping the shape identical means downstream code, including the future
% paper-figure script, can treat QC'd and non-QC'd results the same way.
%
%   S = ASSEMBLE_CLUSTER_RESULTS(CLUSTERLABEL, STUDYFILE, CLUSTERDATA, ...
%       STATSSTUDY, P)
%
%   CLUSTERDATA  from COMPUTE_CLUSTER_ERSP
%   STATSSTUDY   from BUILD_STATS_STUDY (its STUDY.etc.statistics and
%                design are read by ERSP_CLUSTER_STATS; a per-cluster copy
%                is made here so the small-sample naccu override below
%                doesn't leak into the next cluster's test)
%
% The pairwise logic (including the significance-mask polarity, which was
% wrong in the version of this analysis that predates plot_cluster_ersp.m,
% and the p<alpha gate on computing an effect size at all) is copied
% verbatim from plot_cluster_ersp.m's process_one_cluster, since that is
% the already-reviewed, already-fixed version of this exact computation --
% only the source of allersp (QC'd, per this module, vs. STUDY-derived,
% per the non-QC'd pipeline) differs.

    conditionNames = p.design.values;      % {'1','3','6'}, the order
                                            % compute_cluster_ersp's
                                            % ersp.raw is already in
    nCond      = numel(conditionNames);
    refIdx     = find(strcmp(p.design.reference, conditionNames), 1);
    compareIdx = setdiff(1:nCond, refIdx);
    nSubjects  = numel(clusterData.subjects);

    clusterSTUDY = statsSTUDY;
    if nSubjects < 9
        clusterSTUDY.etc.statistics.fieldtrip.naccu = 3^nSubjects;
        fprintf('  %d subjects: naccu reduced to %d.\n', ...
            nSubjects, clusterSTUDY.etc.statistics.fieldtrip.naccu);
    end

    allersp = clusterData.ersp.raw;   % nCond x 1 cell, freq x time x nSubjects

    % --- omnibus test across all conditions --------------------------------
    [condMask, ~, ~, condClusterPval] = ersp_cluster_stats(clusterSTUDY, allersp);
    condMask = to_logical_mask(condMask);

    permTest = struct('name', {}, 'freqrange', {}, 'pval', {}, ...
        'sigMask', {}, 'effect', {});
    permTest(1).name      = 'omnibus across conditions';
    permTest(1).freqrange = p.plot.freqRange;
    permTest(1).sigMask   = condMask;
    permTest(1).pval      = condClusterPval;
    permTest(1).effect    = [];

    % --- condition means -----------------------------------------------------
    erspdata.raw  = allersp;
    erspdata.mean = cellfun(@(x) mean(x, 3), allersp, 'UniformOutput', false);

    % --- pairwise vs. reference, gated on the omnibus result ------------------
    erspDiff.raw     = cell(nCond, 1);
    erspDiff.mean    = cell(nCond, 1);
    erspDiff.masked  = cell(nCond, 1);
    erspDiff.sigMask = cell(nCond, 1);

    anySignificant = any(cellfun(@(m) any(m(:)), condMask));

    for ci = compareIdx
        testErsp = allersp{ci};
        refErsp  = allersp{refIdx};
        erspDiff.raw{ci}  = testErsp - refErsp;
        erspDiff.mean{ci} = mean(testErsp - refErsp, 3);

        if ~strcmpi(p.stats.condStats, 'on') || ~anySignificant
            % No omnibus effect anywhere, so the pairwise test is not run,
            % as in plot_cluster_ersp.m and the original it was fixed from.
            erspDiff.sigMask{ci} = false(size(erspDiff.mean{ci}));
            erspDiff.masked{ci}  = zeros(size(erspDiff.mean{ci}));
            continue
        end

        [pairMask, ~, ~, pairPval] = ersp_cluster_stats( ...
            clusterSTUDY, {testErsp; refErsp});
        sigMask = logical(pairMask{1,1});
        pvalMap = pairPval;
        if iscell(pvalMap)
            pvalMap = pvalMap{1,1};
        end
        % Keep p-values INSIDE significant clusters, blank everything
        % else (the polarity plot_cluster_ersp.m corrected).
        pvalMap(~sigMask) = 1;

        erspDiff.sigMask{ci} = sigMask;
        erspDiff.masked{ci}  = erspDiff.mean{ci} .* sigMask;

        entry = numel(permTest) + 1;
        permTest(entry).name = sprintf('%s vs %s', ...
            p.design.legend{ci}, p.design.legend{refIdx});
        permTest(entry).freqrange = p.plot.freqRange;
        permTest(entry).pval      = pvalMap;
        permTest(entry).sigMask   = sigMask;
        if any(pvalMap(:) < p.stats.alpha)
            permTest(entry).effect = cluster_effect_size( ...
                {testErsp; refErsp}, pvalMap, clusterData.allTimes, ...
                clusterData.allFreqs, p.effect.method);
        else
            permTest(entry).effect = [];
        end
    end

    s = struct();
    s.name           = clusterLabel;
    s.studyFile       = studyFile;
    s.design_name     = p.design.name;
    s.conditionOrder  = conditionNames;
    s.legend          = p.design.legend;
    s.subjects        = clusterData.subjects;
    s.ICs             = clusterData.ICs;
    s.alpha           = p.stats.alpha;
    s.stats           = clusterSTUDY.etc.statistics;
    s.allTimes        = clusterData.allTimes;
    s.allFreqs        = clusterData.allFreqs;
    s.eventTimes      = clusterData.eventTimes;
    s.qc              = clusterData.qc;
    s.nTrialsTotal    = clusterData.nTrialsTotal;
    s.nTrialsBad      = clusterData.nTrialsBad;
    s.condMask        = condMask;
    s.erspdata        = erspdata;
    s.refIdx          = refIdx;
    s.compareIdx      = compareIdx;
    s.erspDiff        = erspDiff;
    s.permTest        = permTest;
end

function mask = to_logical_mask(pcond)
% std_stat / std_stat_clusterpval return a 0/1 mask when an alpha is set:
% 1 means SIGNIFICANT.
    mask = pcond;
    for i = 1:numel(mask)
        if ~isempty(mask{i})
            mask{i} = logical(mask{i});
        end
    end
end