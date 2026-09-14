function [names, meta] = lmm21_feature_names(L)
%LMM21_FEATURE_NAMES  The 21 feature column names, in cluster then band order.
%
%   NAMES = LMM21_FEATURE_NAMES(L) returns a cell array of the 21 names,
%   <abbr>_<band>, ordered by cluster and then by band. Every file that needs
%   the names calls this one, so the feature table, the models and the
%   supplementary table cannot end up in different orders.
%
%   [NAMES, META] = ... also returns a table with the cluster name, the
%   manuscript label for the cluster, the band name and the band label for each
%   feature, which is what the supplementary table prints.
%
%   The order is deliberately cluster by band and not by p value. A
%   supplementary table sorted by significance invites being read as a ranking.
%
%   See also LMM21_CONFIG, REPORT_LMM21.
%
%   Part of the KneeExo-EEG analysis code.

if nargin < 1 || isempty(L)
    L = lmm21_config();
end

nCl = size(L.clusters, 1);
nB  = numel(L.bandNames);

names = cell(1, nCl * nB);

cluster      = strings(nCl * nB, 1);
clusterLabel = strings(nCl * nB, 1);
band         = strings(nCl * nB, 1);
bandLabel    = strings(nCl * nB, 1);
loHz         = nan(nCl * nB, 1);
hiHz         = nan(nCl * nB, 1);

k = 0;
for c = 1:nCl
    for b = 1:nB
        k = k + 1;
        names{k}        = sprintf('%s_%s', L.clusters{c, 2}, L.bandNames{b});
        cluster(k)      = string(L.clusters{c, 1});
        clusterLabel(k) = string(L.clusters{c, 3});
        band(k)         = string(L.bandNames{b});
        bandLabel(k)    = string(L.bandLabels{b});
        e               = L.bands.(L.bandNames{b});
        loHz(k)         = e(1);
        hiHz(k)         = e(2);
    end
end

if nargout > 1
    meta = table(string(names(:)), cluster, clusterLabel, band, bandLabel, ...
        loHz, hiHz, 'VariableNames', {'Feature', 'Cluster', 'ClusterLabel', ...
        'Band', 'BandLabel', 'LoHz', 'HiHz'});
end

end
