function plot_figure3_primary_motor(data, p, outputPath)
% PLOT_FIGURE3_PRIMARY_MOTOR  Paper Figure 3: bilateral sensorimotor ERSPs.
%
%   PLOT_FIGURE3_PRIMARY_MOTOR(DATA, P, OUTPUTPATH)
%
% Thin wrapper. All of the drawing lives in PLOT_CLUSTER_PAIR_FIGURE,
% which Figure 4 (parieto-occipital) also calls, so the two figures are
% guaranteed to be drawn identically -- that identity is what makes the
% regional dissociation they jointly show readable. Change the layout
% there, not here.
%
% Kept under its original name so existing scripts and habits keep
% working. The file name still says "primary motor" while the figure now
% says "sensorimotor"; the printed labels come from
% p.plot.clusterDisplayNames, not from this name.

    plot_cluster_pair_figure(data, p, outputPath, ...
        'figure3_primary_motor', 'Figure 3: Sensorimotor clusters');
end
