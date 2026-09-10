function settings = band_family_settings(p)
% BAND_FAMILY_SETTINGS  The analysis choices a band p-value family depends on.
%
%   SETTINGS = BAND_FAMILY_SETTINGS(P)
%
% BUILD_BAND_PVALUE_FAMILY stores this next to the family; the figures
% compare it against their own P and refuse a mismatch. One function so
% the writer and the checker can never disagree about which fields matter.
%
% These are exactly the settings that change what a p-value MEANS:
% permutation count and cluster-forming threshold define the test, and the
% band edges/names define what was tested. Change any of them and the
% stored p-values describe an analysis you are no longer running, so the
% family has to be rebuilt.
%
% Deliberately NOT included: fdrQ. Changing the false-discovery rate
% changes the cutoff derived FROM the family, not the family itself, so it
% needs no rebuild.
% rngSeed IS included: it selects which draw of the null the p-values
% come from, so a family built under a different seed holds different
% numbers from the ones the figure will compute, and the cutoff would no
% longer correspond to the values being compared against it.
    seed = [];
    if isfield(p.bandStats, 'rngSeed')
        seed = p.bandStats.rngSeed;
    end
    settings = struct( ...
        'nPerm',     p.bandStats.nPerm, ...
        'alpha',     p.bandStats.alpha, ...
        'rngSeed',   seed, ...
        'bandEdges', p.plot.bandEdges, ...
        'bandNames', {p.plot.bandNames});
end
