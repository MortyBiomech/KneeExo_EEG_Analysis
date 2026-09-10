function report_figure3_stats(data, p, outputPath)
% REPORT_FIGURE3_STATS  Print every number Figure 3's Results text needs.
%
%   REPORT_FIGURE3_STATS(DATA, P)
%   REPORT_FIGURE3_STATS(DATA, P, OUTPUTPATH)
%
% Thin wrapper around REPORT_CLUSTER_PAIR_STATS, which Figure 4
% (parieto-occipital) also calls, so both sections' numbers come out in
% the same format. Kept under its original name so existing scripts keep
% working.

    if nargin < 3
        outputPath = '';
    end
    report_cluster_pair_stats(data, p, outputPath, 'figure3');
end
