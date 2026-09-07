function [clust, eta2p] = cluster_perm_1d(C, nPerm, alpha)
% CLUSTER_PERM_1D  Cluster-based permutation, one-way repeated measures,
% along a single continuous axis (cycle time, in this codebase).
%
%   [CLUST, ETA2P] = CLUSTER_PERM_1D(C, NPERM, ALPHA)
%
% Ported verbatim (rmF / clusterMass / the body of clusterTest) from
% RESULTS_BEHAVIOUR.m, which uses this exact test for Figure 2's muscle
% and tracking-error panels. Kept as its own file, rather than copied
% into each figure script, so every panel that needs "the same test as
% Figure 2" actually runs the same code, not a lookalike.
%
% A repeated-measures F is computed at every sample; contiguous
% suprathreshold samples form a cluster; each cluster's summed F ("mass")
% is compared against the null of that same statistic under random
% within-subject relabelling of the condition. This is a different test
% from ERSP_CLUSTER_STATS (the FieldTrip/montecarlo test used on the
% time-frequency ERSPs elsewhere in this pipeline) -- unrelated other than
% both being cluster-based permutation tests.
%
%   C       nSubj x nSamp x nCond
%   NPERM   number of label permutations (Figure 2 used 5000)
%   ALPHA   cluster-forming threshold on the F statistic (Figure 2 used 0.05)
%
%   CLUST   table with StartIdx, EndIdx (sample indices into C's 2nd
%           dimension), StartPct, EndPct (percent of that dimension, for
%           reporting), Mass and p -- an empty table() if no
%           suprathreshold cluster exists at all
%   ETA2P   1 x nSamp partial eta-squared trace

    Y = permute(C, [1 3 2]);                 % nSubj x nCond x nSamp
    [n, k, ns] = size(Y);
    Fcrit = finv(1-alpha, k-1, (n-1)*(k-1));

    [Fobs, eta2p] = rm_F_eta2p(Y);
    [mass, runs] = cluster_mass(Fobs, Fcrit);

    nullMax = zeros(nPerm, 1);
    for pi = 1:nPerm
        Yp = Y;
        for i = 1:n
            Yp(i, :, :) = Y(i, randperm(k), :);
        end
        nullMax(pi) = max([cluster_mass(rm_F_eta2p(Yp), Fcrit); 0]);
    end

    if isempty(mass)
        clust = table();
    else
        pc = arrayfun(@(x) (sum(nullMax >= x)+1)/(nPerm+1), mass);
        clust = table(runs(:,1), runs(:,2), runs(:,1)/ns*100, runs(:,2)/ns*100, ...
            mass(:), pc(:), ...
            'VariableNames', {'StartIdx','EndIdx','StartPct','EndPct','Mass','p'});
        clust = sortrows(clust, 'Mass', 'descend');
    end
end

function [F, eta2p] = rm_F_eta2p(Y)
% Repeated measures F and partial eta squared at every sample.
    [n, k, ~] = size(Y);
    gm = mean(Y, [1 2], 'omitnan'); mc = mean(Y, 1, 'omitnan'); ms = mean(Y, 2, 'omitnan');
    ssCond  = n * sum((mc-gm).^2, 2);
    ssSubj  = k * sum((ms-gm).^2, 1);
    ssTotal = sum((Y-gm).^2, [1 2], 'omitnan');
    ssErr   = ssTotal - ssCond - ssSubj;
    F = squeeze((ssCond/(k-1)) ./ (ssErr/((n-1)*(k-1))))';
    F(~isfinite(F)) = 0;
    eta2p = squeeze(ssCond ./ (ssCond + ssErr))';
    eta2p(~isfinite(eta2p)) = 0;
end

function [mass, runs] = cluster_mass(F, thresh)
    above = F > thresh;
    if ~any(above)
        mass = zeros(0,1); runs = zeros(0,2);
        return
    end
    d = diff([0 above 0]);
    runs = [find(d==1)', (find(d==-1)-1)'];
    mass = arrayfun(@(a,b) sum(F(a:b)), runs(:,1), runs(:,2));
end