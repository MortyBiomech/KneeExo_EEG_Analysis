function data = load_cluster_pair_data(cfg, p, clusterStudyNames)
% LOAD_CLUSTER_PAIR_DATA  Load everything one left/right cluster pair needs.
%
%   DATA = LOAD_CLUSTER_PAIR_DATA(CFG, P, CLUSTERSTUDYNAMES)
%
% CLUSTERSTUDYNAMES is a cell array of .study base names, in the order
% they should be stacked in the figure, e.g.
%   {'Left_Prim_Motor', 'Right_Prim_Motor'}          (Figure 3)
%   {'Left_Parieto_Occipital', 'Right_Parieto_Occipital'}   (Figure 4)
%
% Shared by Figure 3 and Figure 4 so both pairs are loaded, tested and
% band-analysed by exactly the same code path -- see the note in
% PLOT_CLUSTER_PAIR_FIGURE on why those two figures must not diverge.
%
% Loads the saved QC'd ERSP results (assemble_cluster_results.m output,
% via run_ersp_stats.m) and each cluster's own .study file (giving
% STUDY/ALLEEG, needed by std_dipplot/std_topoplot) for both primary
% motor clusters.
%
% Call this ONCE per MATLAB session and keep DATA in the workspace.
% Loading a .study file pulls in its ALLEEG (the actual EEG data), and
% the band-power cluster permutation test (COMPUTE_BAND_STATS, below)
% runs several thousand permutations per band -- both slow.
% PLOT_CLUSTER_PAIR_FIGURE takes DATA as an argument precisely so it
% can be re-run as many times as you like while iterating on the
% figure's layout, without paying either cost again. If you find
% yourself reloading this often across MATLAB restarts, a
% RESULTS_BEHAVIOUR.m-style disk cache (its RECOMPUTE_CLUSTERS /
% CLUSTER_CACHE pattern) would drop straight into COMPUTE_BAND_STATS --
% not added here since within one session this function already is that
% cache.
%
%   DATA(i).studyName   'Left_Prim_Motor' / 'Right_Prim_Motor'
%   DATA(i).s            saved QC'd ERSP + stats struct for this cluster
%   DATA(i).STUDY        loaded STUDY for this cluster's .study file
%   DATA(i).ALLEEG       loaded ALLEEG for this cluster's .study file
%   DATA(i).clusterIdx   STUDY.etc.bemobil.clustering.cluster_ROI_index
%   DATA(i).bandStats    1 x numel(p.plot.bandNames) struct, from
%                        COMPUTE_BAND_STATS below: .name, .eta2p,
%                        .clust, .groupMean, .groupSEM

    resultsPath = fullfile(cfg.figures, 'ERSP_QC');
    studyPath   = fullfile(cfg.studyEpoched, 'multiple_clustering');

    data = struct('studyName', {}, 's', {}, 'STUDY', {}, 'ALLEEG', {}, ...
        'clusterIdx', {}, 'bandStats', {});
    for bi = 1:numel(clusterStudyNames)
        studyName = clusterStudyNames{bi};
        fprintf('Loading %s (results + .study)...\n', studyName);

        resultFile = fullfile(resultsPath, [studyName '_ersp_qc_results.mat']);
        if ~isfile(resultFile)
            error('load_cluster_pair_data:MissingResults', ...
                ['No QC results at %s. Run run_ersp_stats.m for the ' ...
                 '%s ROI first -- this function only loads what that ' ...
                 'pipeline already wrote, it does not compute it.'], ...
                resultFile, studyName);
        end
        loaded = load(resultFile, 's');

        [STUDY, ALLEEG] = pop_loadstudy('filename', [studyName '.study'], ...
            'filepath', fullfile(studyPath, studyName));

        fprintf('  Running band-power cluster permutation (%d bands, %d perms each)...\n', ...
            numel(p.plot.bandNames), p.bandStats.nPerm);
        bandStats = compute_band_stats(loaded.s, p);

        data(bi).studyName  = studyName;
        data(bi).s          = loaded.s;
        data(bi).STUDY      = STUDY;
        data(bi).ALLEEG     = ALLEEG;
        data(bi).clusterIdx = STUDY.etc.bemobil.clustering.cluster_ROI_index;
        data(bi).bandStats  = bandStats;
    end
    fprintf('Data loaded for %d clusters. Keep this variable around;\n', numel(data));
    fprintf('pass it to plot_cluster_pair_figure as many times as you like.\n');
end