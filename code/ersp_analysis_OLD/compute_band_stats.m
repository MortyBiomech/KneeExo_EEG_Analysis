function bandStats = compute_band_stats(s, p)
% COMPUTE_BAND_STATS  Band-power-vs-cycle permutation test for one cluster.
%
%   BANDSTATS = COMPUTE_BAND_STATS(S, P)
%
% One CLUSTER_PERM_1D call per frequency band (p.plot.bandEdges /
% bandNames): the same RM-ANOVA-F / condition-permutation test Figure 2
% runs on each muscle and on tracking error, run here on each band's
% power-vs-cycle curve instead.
%
% Takes ONLY S (a saved *_ersp_qc_results.mat) and P. It never touches
% STUDY or ALLEEG, which is why BUILD_BAND_PVALUE_FAMILY can assemble the
% whole multiple-comparison family from the result files alone, without
% the slow .study/ALLEEG load that the dipole and topography panels need.
%
% Its own file rather than a local function in LOAD_CLUSTER_PAIR_DATA
% because two callers now need it: that loader, and the family builder.
    % Fixed RNG seed. CLUSTER_PERM_1D draws its null by random relabelling,
    % so without this the same data give slightly different p-values on
    % every run -- and that is not merely a reproducibility nicety here.
    %
    % These p-values are computed TWICE by different callers:
    % BUILD_BAND_PVALUE_FAMILY, whose values set the FDR cutoff, and
    % LOAD_CLUSTER_PAIR_DATA, whose values the figure compares against
    % that cutoff. Unseeded, those are two independent draws, so the
    % figure would test one set of numbers against a threshold derived
    % from another. Seeding here makes both callers produce identical
    % values, which is what lets the family and the figure agree exactly.
    %
    % Set BEFORE the band loop rather than inside it, so each band draws
    % from a different part of one reproducible stream instead of every
    % band reusing the same permutation sequence.
    if isfield(p.bandStats, 'rngSeed') && ~isempty(p.bandStats.rngSeed)
        rng(p.bandStats.rngSeed, 'twister');
    end

    nBand = numel(p.plot.bandNames);
    nCond = numel(s.conditionOrder);
    nSubj = size(s.erspdata.raw{1}, 3);
    nTime = numel(s.allTimes);

    bandStats = struct('name', {}, 'eta2p', {}, 'clust', {}, ...
        'groupMean', {}, 'groupSEM', {});
    for bi = 1:nBand
        freqIdx = s.allFreqs >= p.plot.bandEdges(bi) & s.allFreqs < p.plot.bandEdges(bi+1);

        C = nan(nSubj, nTime, nCond);
        groupMean = nan(nTime, nCond);
        groupSEM  = nan(nTime, nCond);
        for c = 1:nCond
            bandTS = squeeze(mean(s.erspdata.raw{c}(freqIdx, :, :), 1));  % time x nSubj
            if isvector(bandTS)
                bandTS = reshape(bandTS, nTime, []);
            end
            C(:, :, c)      = bandTS';
            groupMean(:, c) = mean(bandTS, 2);
            groupSEM(:, c)  = std(bandTS, 0, 2) / sqrt(size(bandTS, 2));
        end

        [clust, eta2p] = cluster_perm_1d(C, p.bandStats.nPerm, p.bandStats.alpha);

        bandStats(bi).name      = p.plot.bandNames{bi};
        bandStats(bi).eta2p     = eta2p;
        bandStats(bi).clust     = clust;
        bandStats(bi).groupMean = groupMean;
        bandStats(bi).groupSEM  = groupSEM;
    end
end
