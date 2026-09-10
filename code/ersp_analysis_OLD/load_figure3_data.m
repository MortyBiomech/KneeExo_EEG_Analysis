function data = load_figure3_data(cfg, p)
% LOAD_FIGURE3_DATA  Load everything Figure 3 needs, once.
%
%   DATA = LOAD_FIGURE3_DATA(CFG, P)
%
% Thin wrapper around LOAD_CLUSTER_PAIR_DATA, which Figure 4
% (parieto-occipital) also calls, so both cluster pairs are loaded and
% band-analysed by identical code. Kept under its original name so
% existing scripts keep working.
%
% Still slow (it loads each cluster's .study, ALLEEG included, and runs
% the band-power permutation test). Call it ONCE per MATLAB session and
% keep DATA in the workspace -- see LOAD_CLUSTER_PAIR_DATA's header.

    data = load_cluster_pair_data(cfg, p, ...
        {'Left_Prim_Motor', 'Right_Prim_Motor'});
end
