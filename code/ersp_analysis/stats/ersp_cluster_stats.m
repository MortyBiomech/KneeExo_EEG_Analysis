function [pcond, pgroup, pinter, clusterPval] = ersp_cluster_stats(STUDY, erspData)
% ERSP_CLUSTER_STATS  Cluster-based permutation test across conditions.
%
%   [PCOND, PGROUP, PINTER, CLUSTERPVAL] = ERSP_CLUSTER_STATS(STUDY, ERSPDATA)
%
%   ERSPDATA     {nConditions x nGroups} cell array; each cell is
%                [freq x time x subject]
%   PCOND        {1 x nGroups} condition mask, 1 where NOT significant
%   PGROUP       {1 x nConditions} group mask (empty for a single group)
%   PINTER       interaction masks (unused in this analysis, see the fork
%                notice in std_stat_clusterpval)
%   CLUSTERPVAL  the raw cluster p-value map behind PCOND
%
% The test itself is FieldTrip's Monte-Carlo cluster-based permutation test.
% Its settings -- paired/unpaired, alpha, number of randomisations, the
% multiple-comparison method -- are read from STUDY.etc.statistics, which
% POP_STATPARAMS fills in; pairing comes from the STUDY design.
%
% A single channel/component is assumed, so the FieldTrip channel-neighbour
% structure is empty and clusters form over the time-frequency plane only.
%
% Changes from the original (erspStats): the original carried a large branch
% for averaging over a time/frequency window before testing, guarded by
% params.plottf, which was hardcoded empty two lines above the guard. The
% branch was therefore unreachable -- fortunate, since it referenced three
% variables (allfreqs, alltimes, ALLEEG) that are not in scope in that
% function and it would have errored had it ever run. It is removed here. To
% test a restricted window, average ERSPDATA before calling this.
%
% The original also existed twice: as erspStats.m and as a local function of
% the plotting script, where the local copy shadowed the file.

    stats = STUDY.etc.statistics;

    % one component or channel, so there are no neighbours to cluster over
    stats.fieldtrip.channelneighbor = struct([]);

    designVariables = STUDY.design(STUDY.currentdesign).variable;
    if isempty(designVariables)
        stats.paired = {};
    else
        stats.paired = {designVariables(:).pairing};
    end

    [pcond, pgroup, pinter, ~, ~, ~, clusterPval] = ...
        std_stat_clusterpval(erspData, stats);

    % A STUDY with one subject collapses the tested dimension to a vector;
    % nothing meaningful can be tested, so return empty rather than a
    % degenerate mask.
    if is_degenerate(pcond) || is_degenerate(pgroup)
        pcond = {};
        pgroup = {};
        pinter = {};
        clusterPval = {};
        disp('No statistics possible for a single-subject STUDY.');
    end
end


function tf = is_degenerate(p)
    tf = ~isempty(p) && (size(p{1}, 1) == 1 || size(p{1}, 2) == 1);
end
