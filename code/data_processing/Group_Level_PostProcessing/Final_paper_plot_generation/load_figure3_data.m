function data = load_figure3_data(cfg, p)
% LOAD_FIGURE3_DATA  Load everything Figure 3 needs, once.
%
%   DATA = LOAD_FIGURE3_DATA(CFG, P)
%
% Loads the saved QC'd ERSP results (assemble_cluster_results.m output,
% via main_ersp_pipeline_qc.m) and each cluster's own .study file (giving
% STUDY/ALLEEG, needed by std_dipplot/std_topoplot) for both primary
% motor clusters.
%
% Call this ONCE per MATLAB session and keep DATA in the workspace.
% Loading a .study file pulls in its ALLEEG (the actual EEG data), and
% the band-power cluster permutation test (COMPUTE_BAND_STATS, below)
% runs several thousand permutations per band -- both slow.
% PLOT_FIGURE3_PRIMARY_MOTOR takes DATA as an argument precisely so it
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

    clusterStudyNames = {'Left_Prim_Motor', 'Right_Prim_Motor'};
    resultsPath = fullfile(cfg.figures, 'ERSP_QC');
    studyPath   = fullfile(cfg.study, 'Epoched_data', 'multiple_clustering');

    data = struct('studyName', {}, 's', {}, 'STUDY', {}, 'ALLEEG', {}, ...
        'clusterIdx', {}, 'bandStats', {});
    for bi = 1:numel(clusterStudyNames)
        studyName = clusterStudyNames{bi};
        fprintf('Loading %s (results + .study)...\n', studyName);

        resultFile = fullfile(resultsPath, [studyName '_ersp_qc_results.mat']);
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
    fprintf('Figure 3 data loaded for %d clusters. Keep this variable around;\n', numel(data));
    fprintf('pass it to plot_figure3_primary_motor as many times as you like.\n');
end

function bandStats = compute_band_stats(s, p)
% One CLUSTER_PERM_1D call per frequency band (p.plot.bandEdges /
% bandNames): the same RM-ANOVA-F / condition-permutation test Figure 2
% runs on each muscle and on tracking error, run here on each band's
% power-vs-cycle curve instead. Deliberately done here (the slow,
% once-per-session load step) rather than in the plotting function -- see
% this file's header.
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