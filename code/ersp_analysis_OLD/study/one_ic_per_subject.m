function STUDY = one_ic_per_subject(STUDY)
% ONE_IC_PER_SUBJECT  Reduce every cluster to at most one IC per subject.
%
%   STUDY = ONE_IC_PER_SUBJECT(STUDY)
%
% A subject can contribute several independent components to the same
% cluster. Averaging over components would then weight that subject more
% heavily than the others, and the cluster-level statistics assume one
% observation per subject. This keeps, for each subject, the component with
% the LOWEST IC index -- ICs are ordered by explained variance, so the lowest
% index is the component that accounts for most of the subject's data -- and
% moves the rest into cluster 2, the outlier cluster.
%
% The original clustering is preserved in STUDY.cluster_og, and the reduced
% one in both STUDY.cluster and STUDY.cluster_lowestIC.
%
% Clusters 1 and 2 are EEGLAB's parent and outlier clusters and are skipped.
%
% Change from the original (oneSubPerCluster): the original kept whichever
% component appeared FIRST in STUDY.cluster(CL).comps, which is the lowest IC
% number only while that list happens to be in ascending order per subject.
% This version selects the minimum explicitly and warns if the two choices
% would have differed, so a silent change of component cannot pass unnoticed.

    OUTLIER_CLUSTER = 2;
    nDiffered = 0;

    clusterReduced = STUDY.cluster;

    for CL = 3:numel(STUDY.cluster)
        sets  = STUDY.cluster(CL).sets;
        comps = STUDY.cluster(CL).comps;
        if isempty(sets)
            continue
        end

        dropIdx = [];
        for subjectSet = unique(sets)
            hits = find(sets == subjectSet);
            if numel(hits) < 2
                continue
            end

            [~, bestOfHits] = min(comps(hits));
            keepIdx = hits(bestOfHits);

            if keepIdx ~= hits(1)
                nDiffered = nDiffered + 1;
            end

            dropIdx = [dropIdx, setdiff(hits, keepIdx)]; %#ok<AGROW>
        end

        if isempty(dropIdx)
            continue
        end

        clusterReduced(OUTLIER_CLUSTER).comps = ...
            [clusterReduced(OUTLIER_CLUSTER).comps, comps(dropIdx)];
        clusterReduced(OUTLIER_CLUSTER).sets = ...
            [clusterReduced(OUTLIER_CLUSTER).sets,  sets(dropIdx)];

        clusterReduced(CL).comps(dropIdx) = [];
        clusterReduced(CL).sets(dropIdx)  = [];
    end

    if nDiffered > 0
        warning('one_ic_per_subject:OrderDiffers', ...
            ['%d subject/cluster pairs kept a different component than the ' ...
             'original first-in-list rule would have. STUDY.cluster(CL).comps ' ...
             'was not in ascending order there.'], nDiffered);
    end

    STUDY.cluster_og      = STUDY.cluster;
    STUDY.cluster_lowestIC = clusterReduced;
    STUDY.cluster          = clusterReduced;

    fprintf(['Clusters reduced to one IC per subject (lowest IC index).\n' ...
             '  reduced clustering : STUDY.cluster, STUDY.cluster_lowestIC\n' ...
             '  original clustering: STUDY.cluster_og\n']);
end
