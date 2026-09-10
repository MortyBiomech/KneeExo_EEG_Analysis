function STUDY = keep_one_ic_per_subject(STUDY)
% KEEP_ONE_IC_PER_SUBJECT  Reduce every cluster to one component per person.
%
%   STUDY = keep_one_ic_per_subject(STUDY)
%
% A participant can contribute more than one component to a cluster. Averaging
% over components rather than over people would weight those participants more
% heavily and would break the assumption of independent observations that the
% repeated-measures tests rest on. So each participant keeps exactly one
% component in each cluster and the rest are moved to the outlier cluster.
%
% Which one is kept: the lowest component index that participant has in the
% cluster. EEGLAB builds cluster membership dataset-major and
% component-ascending, so that is the first entry for them. If the AMICA
% decomposition is sorted by descending projected variance, which is the usual
% convention, the lowest index is also that participant's component explaining
% the most channel-level variance.
%
%   `<Verify that the decomposition really is variance-sorted before writing
%     the Methods sentence that way. See docs/ersp-precompute-provenance.md.>`
%
% The original is kept in STUDY.cluster_og and the reduced version in
% STUDY.cluster_lowestIC, so nothing is lost.
%
% WHAT THIS DOES NOT UPDATE
% -------------------------
% The cluster centroid and everything derived from it. After this runs,
% STUDY.cluster(CL).dipole, .all_diplocs, .topo* and .preclust still describe
% the FULL cluster, while the components that remain are the reduced set. That
% matters because add_anatomical_labels reads .dipole, so anatomical labels
% and MNI coordinates taken after this call describe a different set of
% components than the ERSPs do.
%
% Either call add_anatomical_labels BEFORE this function and say in the
% manuscript that coordinates are full-cluster centroids, or recompute the
% centroids over the reduced set afterwards with bemobil_dipoles. Do not leave
% it ambiguous.
%
% Renamed from oneSubPerCluster. Its docstring said "weighted average across
% components"; it has never averaged anything.

    cluster_lowestIC = STUDY.cluster;

    fprintf('Reducing clusters to one component per participant\n');
    fprintf('%-6s %10s %10s %10s\n', 'CL', 'before', 'after', 'moved');

    % Cluster 1 is the parent, cluster 2 the outliers.
    for CL = 3:numel(STUDY.cluster)

        sets = STUDY.cluster(CL).sets;
        if isempty(sets)
            continue
        end

        surplus = [];
        for iSet = unique(sets, 'stable')
            entries = find(sets == iSet);
            if numel(entries) > 1
                surplus = [surplus, entries(2:end)]; %#ok<AGROW>
            end
        end

        if isempty(surplus)
            fprintf('%-6d %10d %10d %10d\n', CL, numel(sets), numel(sets), 0);
            continue
        end

        % Move the surplus into the outlier cluster.
        cluster_lowestIC(2).comps = [cluster_lowestIC(2).comps, ...
                                     STUDY.cluster(CL).comps(surplus)];
        cluster_lowestIC(2).sets  = [cluster_lowestIC(2).sets, ...
                                     STUDY.cluster(CL).sets(surplus)];

        keep = setdiff(1:numel(sets), surplus);
        cluster_lowestIC(CL).comps = STUDY.cluster(CL).comps(keep);
        cluster_lowestIC(CL).sets  = STUDY.cluster(CL).sets(keep);

        fprintf('%-6d %10d %10d %10d\n', CL, numel(sets), numel(keep), ...
            numel(surplus));

    end

    STUDY.cluster_og       = STUDY.cluster;
    STUDY.cluster_lowestIC = cluster_lowestIC;
    STUDY.cluster          = cluster_lowestIC;

    fprintf(['Original clusters kept in STUDY.cluster_og. Note that ' ...
             'STUDY.cluster(CL).dipole still describes the full cluster.\n']);

end