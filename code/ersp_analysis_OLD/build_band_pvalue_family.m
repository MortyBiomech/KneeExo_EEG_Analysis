function family = build_band_pvalue_family(cfg, p, clusterStudyNames)
% BUILD_BAND_PVALUE_FAMILY  Run the band-power test for every cluster the
% paper reports and store all p-values in one place.
%
%   FAMILY = BUILD_BAND_PVALUE_FAMILY(CFG, P, CLUSTERSTUDYNAMES)
%
% Writes p.bandStats.familyFile, which BAND_PVALUE_FDR reads to derive the
% single Benjamini-Hochberg cutoff the figures threshold their eta^2 bars
% against.
%
% FAST, because it never loads a .study. COMPUTE_BAND_STATS needs only the
% saved *_ersp_qc_results.mat (s.erspdata.raw and the time axis); STUDY
% and ALLEEG exist solely for the dipole and topography panels. So the
% whole family is built from the result files alone, in one pass, without
% the slow load the figures pay.
%
% CLUSTERSTUDYNAMES MUST list every cluster whose band tests the paper
% reports, and nothing else. That list is the family, and the family size
% m sets the correction. Listing fewer clusters makes the correction too
% lenient; listing clusters you never report makes it needlessly harsh.
% Keeping the list here, in one call, is the point of this function: the
% family is a thing you can read off a single line rather than an
% emergent property of which figures you happened to run.
%
% Re-run this whenever the set of reported clusters changes, or whenever
% the test itself changes (p.bandStats.nPerm, alpha, or the band edges).
% It overwrites the family file completely rather than merging, so the
% file can never hold rows from two different definitions of the test.

    if ~isfield(p.bandStats, 'familyFile') || isempty(p.bandStats.familyFile)
        error('build_band_pvalue_family:NoFamilyFile', ...
            ['p.bandStats.familyFile is not set. Set it in your main script, ' ...
             'e.g. p.bandStats.familyFile = fullfile(cfg.figures, ' ...
             '''band_pvalue_family.mat'');']);
    end

    resultsPath = fullfile(cfg.figures, 'ERSP_QC');
    rows = table();

    fprintf('\nBuilding band p-value family over %d clusters x %d bands = %d tests.\n', ...
        numel(clusterStudyNames), numel(p.plot.bandNames), ...
        numel(clusterStudyNames) * numel(p.plot.bandNames));

    for ci = 1:numel(clusterStudyNames)
        studyName  = clusterStudyNames{ci};
        resultFile = fullfile(resultsPath, [studyName '_ersp_qc_results.mat']);
        if ~isfile(resultFile)
            error('build_band_pvalue_family:MissingResults', ...
                ['No QC results at %s. Run main_ersp_pipeline_qc.m for the %s ' ...
                 'ROI first. Every listed cluster must be present, because a ' ...
                 'missing one silently shrinks the family and weakens the ' ...
                 'correction.'], resultFile, studyName);
        end

        fprintf('  %-26s ', studyName);
        loaded    = load(resultFile, 's');
        bandStats = compute_band_stats(loaded.s, p);

        for bi = 1:numel(bandStats)
            b = bandStats(bi);
            rows = [rows; { string(loaded.s.name), string(clean_band(b.name)), ...
                min_cluster_p(b.clust), n_clusters(b.clust) }]; %#ok<AGROW>
        end
        fprintf('done (%d bands)\n', numel(bandStats));
    end

    rows.Properties.VariableNames = {'cluster', 'band', 'p', 'nClusters'};
    family = sortrows(rows, {'cluster', 'band'});

    % Stored alongside the family so the figures can refuse a family built
    % under a different test. A p-value only means something relative to
    % the test that produced it, and a family silently mixing settings
    % would produce a cutoff that corresponds to no analysis at all.
    settings = band_family_settings(p); %#ok<NASGU>

    folder = fileparts(p.bandStats.familyFile);
    if ~isempty(folder) && ~isfolder(folder)
        mkdir(folder);
    end
    save(p.bandStats.familyFile, 'family', 'settings');

    fprintf('\nFamily written: %d tests -> %s\n', height(family), p.bandStats.familyFile);
    band_pvalue_fdr(p.bandStats.familyFile, p.bandStats.fdrQ);
end

function p = min_cluster_p(clust)
% Smallest p among a band's suprathreshold clusters; 1 when none formed.
%
% Bands with no cluster are still TESTS and must be recorded, because
% they set the family size m. Recording only the bands that produced a
% cluster would shrink m dramatically and make the correction far too
% lenient.
%
% A band with several clusters is entered once, at its smallest p: the
% cluster-based permutation test already controls error across cycle time
% within a band, so the band is the unit the across-band correction
% applies to.
    p = 1;
    if istable(clust) && height(clust) > 0 && ismember('p', clust.Properties.VariableNames)
        p = min(clust.p);
    end
end

function n = n_clusters(clust)
    n = 0;
    if istable(clust)
        n = height(clust);
    end
end

function name = clean_band(name)
    name = strrep(name, '\', '');
end
