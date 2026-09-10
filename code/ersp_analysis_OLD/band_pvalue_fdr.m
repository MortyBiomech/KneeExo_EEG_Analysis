function [critP, family] = band_pvalue_fdr(familyFile, q, verbose)
% BAND_PVALUE_FDR  Benjamini-Hochberg over the band-power test family.
%
%   [CRITP, FAMILY] = BAND_PVALUE_FDR(FAMILYFILE, Q)
%   [CRITP, FAMILY] = BAND_PVALUE_FDR(FAMILYFILE, Q, VERBOSE)
%
% Reads the family written by SAVE_BAND_PVALUES and returns CRITP, the
% single p-value cutoff that reproduces the BH decision: reject exactly
% those tests with p <= CRITP. BH is a step-up procedure, so its outcome
% always collapses to one cutoff -- which is what lets the figures apply
% it with a plain comparison instead of carrying adjusted p-values
% around.
%
% CRITP is 0 when nothing survives, so "p <= critP" correctly rejects
% nothing (p-values are strictly positive here).
%
% FAMILY comes back with an added q column (BH-adjusted p), sorted by p,
% for reporting. Adjusted values are enforced monotone, as BH requires.
%
% Returns critP = NaN and warns if the family file is missing, so callers
% can fall back deliberately rather than silently drawing uncorrected
% results.

    if nargin < 2 || isempty(q)
        q = 0.05;
    end
    if nargin < 3
        verbose = true;
    end

    critP  = NaN;
    family = table();
    if ~isfile(familyFile)
        warning('band_pvalue_fdr:NoFamily', ...
            ['No band p-value family at %s. Run build_band_pvalue_family once, ' ...
             'listing every cluster the paper reports, BEFORE plotting -- the ' ...
             'figures cannot apply the across-band correction without it.'], ...
            familyFile);
        return
    end

    loaded = load(familyFile, 'family');
    family = sortrows(loaded.family, 'p');
    m      = height(family);
    if m == 0
        warning('band_pvalue_fdr:EmptyFamily', 'Family file %s is empty.', familyFile);
        return
    end

    p    = family.p(:);
    rank = (1:m)';
    pass = p <= (rank / m) * q;
    kMax = find(pass, 1, 'last');
    if isempty(kMax)
        critP = 0;
    else
        critP = p(kMax);
    end

    % BH-adjusted p-values, made monotone from the bottom up.
    adj = min(1, p .* m ./ rank);
    for i = m-1:-1:1
        adj(i) = min(adj(i), adj(i+1));
    end
    family.q = adj;

    if verbose
        fprintf('\n--- Band-power FDR (Benjamini-Hochberg, q < %.3g) ---\n', q);
        fprintf('Family: %d tests over %d clusters x %d bands\n', ...
            m, numel(unique(family.cluster)), numel(unique(family.band)));
        fprintf('Critical p (reject if p <= this): %.5g\n', critP);
        fprintf('%-32s %-16s %10s %10s  %s\n', 'CLUSTER', 'BAND', 'p', 'q', 'survives');
        for i = 1:m
            if family.p(i) >= 1
                continue   % no cluster formed; listed only to set m
            end
            fprintf('%-32s %-16s %10.5g %10.4f  %s\n', ...
                char(family.cluster(i)), char(family.band(i)), ...
                family.p(i), family.q(i), yesno(family.p(i) <= critP));
        end
        nNull = sum(family.p >= 1);
        fprintf('(%d of the %d tests produced no suprathreshold cluster and enter as p = 1)\n', ...
            nNull, m);
        fprintf('-------------------------------------------------------\n\n');
    end
end

function s = yesno(tf)
    if tf
        s = 'yes';
    else
        s = 'NO';
    end
end
