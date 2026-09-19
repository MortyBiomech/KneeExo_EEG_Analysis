function report_cluster_pair_stats(data, p, outputPath, baseName)
% REPORT_CLUSTER_PAIR_STATS  Print every number a cluster-pair figure's
% Results text needs.
%
%   REPORT_CLUSTER_PAIR_STATS(DATA, P)
%   REPORT_CLUSTER_PAIR_STATS(DATA, P, OUTPUTPATH)
%   REPORT_CLUSTER_PAIR_STATS(DATA, P, OUTPUTPATH, BASENAME)
%
% Shared by Figure 3 (sensorimotor) and Figure 4 (parieto-occipital), so
% the two sections' numbers are produced and formatted the same way --
% which matters here more than usual, because those two sections make
% opposite claims and a reviewer will compare them directly.
%
% BASENAME names the written report ('figure3' -> figure3_stats_report.txt)
% and defaults to 'figure3'.
%
% DATA is LOAD_CLUSTER_PAIR_DATA's output -- the same variable
% PLOT_CLUSTER_PAIR_FIGURE draws from, so every number printed here is
% by construction the number in the figure, not a re-derivation that
% could drift from it.
%
% Prints to the console and, when OUTPUTPATH is given, also writes
% figure3_stats_report.txt there, so the numbers survive clearing the
% command window.
%
% Nothing here is computed fresh: the 2D ERSP RM-ANOVA
% (ERSP_CLUSTER_STATS, FieldTrip montecarlo) ran in
% RUN_ERSP_STATS and lives in S.condMask / S.permTest; the 1D
% band-power cluster permutation (CLUSTER_PERM_1D) ran in
% LOAD_CLUSTER_PAIR_DATA and lives in BANDSTATS. This function only reads,
% summarises and formats them.
%
% Written to fill the \ph{...} placeholders in the manuscript's
% sensorimotor section: per-cluster n, the RM-ANOVA cluster's frequency
% and cycle extent with its p, each band's significant cycle window with
% its p, and the condition ordering that backs the "decreased
% monotonically with pressure" claim.

    if nargin < 4 || isempty(baseName)
        baseName = 'figure3';
    end

    fids = 1;   % console
    if nargin >= 3 && ~isempty(outputPath)
        if ~isfolder(outputPath)
            mkdir(outputPath);
        end
        reportFile = fullfile(outputPath, [baseName '_stats_report.txt']);
        fid = fopen(reportFile, 'w');
        if fid > 0
            fids(end+1) = fid; %#ok<AGROW>
        else
            warning('report_cluster_pair_stats:CannotWrite', ...
                'Could not open %s for writing -- printing to the console only.', ...
                reportFile);
        end
    end

    emit(fids, '\n');
    emit(fids, '========================================================================\n');
    emit(fids, ' STATISTICS REPORT: %s\n', upper(strrep(baseName, '_', ' ')));
    emit(fids, ' generated %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
    emit(fids, '========================================================================\n');
    emit(fids, ['\n Every number below is read straight out of the same DATA struct\n' ...
                ' the figure is drawn from, so figure and text cannot\n' ...
                ' disagree. The 2D ERSP test uses alpha = %g.\n'], p.stats.alpha);

    % The band-power verdicts must use the SAME threshold the figure's
    % black bars use, or this report will call a cluster significant that
    % the figure correctly leaves unmarked -- and the text would follow
    % the report.
    p = resolve_report_band_threshold(p);
    if p.bandStats.sigThreshold < p.bandStats.alpha
        emit(fids, [' Band-power verdicts use the FDR cutoff p <= %.5g (across every\n' ...
                    ' band and cluster the paper reports), NOT the per-test alpha =\n' ...
                    ' %g. This is the same threshold the figure''s black bars use.\n'], ...
            p.bandStats.sigThreshold, p.bandStats.alpha);
    else
        emit(fids, [' WARNING: band-power verdicts use the UNCORRECTED alpha = %g.\n' ...
                    ' Run run_band_pvalue_family.m so the across-band correction\n' ...
                    ' applies, or this report will disagree with the figure.\n'], ...
            p.bandStats.alpha);
    end

    for bi = 1:numel(data)
        report_one_cluster(fids, data(bi), p);
    end

    report_cross_cluster(fids, data, p);

    emit(fids, '\n');
    emit(fids, '========================================================================\n');
    emit(fids, ' REPORTING NOTES\n');
    emit(fids, '========================================================================\n');
    pFloor = 1 / (p.bandStats.nPerm + 1);
    emit(fids, [' * The band-power test uses %d permutations, so the smallest p it can\n' ...
                '   return is 1/(%d+1) = %.2e. A band printed at that value has simply\n' ...
                '   hit the floor: report it as "p < 0.001", never as a smaller exact\n' ...
                '   value, and state the permutation count in the Methods.\n'], ...
        p.bandStats.nPerm, p.bandStats.nPerm, pFloor);
    emit(fids, [' * "Cycle extent" is percent of the time-warped movement cycle, the\n' ...
                '   same axis the figure''s x axis shows (0%% = FlxS, ~50%% = FlxE/ExtS,\n' ...
                '   100%% = ExtE).\n']);
    emit(fids, [' * The 2D ERSP RM-ANOVA and the 1D band-power test are DIFFERENT tests\n' ...
                '   (FieldTrip montecarlo over the time-frequency plane vs. the\n' ...
                '   Figure 2 rmF/clusterMass test over cycle time). Describe them\n' ...
                '   separately in the Methods; do not present one p as if it came from\n' ...
                '   the other.\n']);
    emit(fids, '\n');

    for f = fids
        if f ~= 1
            fclose(f);
            fprintf('Report also written to %s\n', reportFile);
        end
    end
end

%% ========================================================================
%  One cluster
%  ========================================================================
function report_one_cluster(fids, d, p)
    s = d.s;
    emit(fids, '\n');
    emit(fids, '========================================================================\n');
    emit(fids, ' CLUSTER: %s\n', display_name(s.name, p));
    emit(fids, '   internal label: %s   |   study: %s\n', s.name, d.studyName);
    emit(fids, '========================================================================\n');

    nSubj = numel(s.subjects);
    emit(fids, '  Participants (n) : %d\n', nSubj);
    emit(fids, '  Subject IDs      : %s\n', join_ids(s.subjects));

    % TWO IC counts, and which one the FIGURE shows changed.
    %
    % s.ICs is what the statistics use: compute_cluster_ersp_qc.m walks
    % subjects(si)/ICs(si) as a 1:1 pairing out of
    % Subjects_ICs_in_clusters.mat, so exactly one component per
    % participant enters every ERSP, band trace and permutation test.
    %
    % The dipole and topography panels ALSO use that set now.
    % embed_cluster_dipoles builds its dipole list from those same
    % (subject, IC) pairs and calls dipplot directly, and
    % embed_cluster_topoplot averages icawinv over the same pairs. They
    % used to go through std_dipplot/std_topoplot, which draw the whole
    % cluster -- that is why this report once told you the caption had to
    % explain a mismatch. It no longer does: dipole count equals n.
    %
    % The full cluster size is still printed, because it is a real
    % property of the clustering and belongs in the Methods, but it is no
    % longer what the panel shows.
    if isfield(s, 'ICs')
        emit(fids, '  ICs used everywhere : %d (one per participant -- stats AND panels)\n', ...
            numel(s.ICs));
    end
    nInCluster = cluster_comp_count(d);
    if ~isnan(nInCluster)
        emit(fids, '  ICs in whole cluster: %d (clustering membership, NOT what the panels show)\n', ...
            nInCluster);
        if isfield(s, 'ICs') && nInCluster ~= numel(s.ICs)
            emit(fids, '     -> %d participant(s) contributed more than one component to the\n', ...
                nInCluster - numel(s.ICs));
            emit(fids, '        clustering; one per participant was retained upstream.\n');
            emit(fids, '     -> Methods should state the cluster size and the selection\n');
            emit(fids, '        criterion (which lives in whatever built\n');
            emit(fids, '        Subjects_ICs_in_clusters.mat, NOT in this pipeline).\n');
            emit(fids, '     -> The CAPTION needs no mismatch caveat: the dipole panel plots\n');
            emit(fids, '        %d dipoles, one per participant, matching n.\n', numel(s.ICs));
        end
    end

    report_centroid(fids, d);

    if isfield(s, 'nTrialsTotal') && isfield(s, 'nTrialsBad')
        tot = sum(s.nTrialsTotal(:));
        bad = sum(s.nTrialsBad(:));
        if tot > 0
            emit(fids, '  Trials           : %d total, %d rejected by QC (%.1f%%)\n', ...
                tot, bad, 100*bad/tot);
        end
    end

    report_ersp_anova(fids, s, p);
    report_bands(fids, s, d.bandStats, p);
end

function p = resolve_report_band_threshold(p)
% The FDR cutoff the figure's bars use, so this report's verdicts match
% them. Falls back to the uncorrected alpha when the family is missing;
% the caller prints a warning in that case.
    p.bandStats.sigThreshold = p.bandStats.alpha;
    if ~isfield(p.bandStats, 'familyFile') || isempty(p.bandStats.familyFile)
        return
    end
    q = 0.05;
    if isfield(p.bandStats, 'fdrQ') && ~isempty(p.bandStats.fdrQ)
        q = p.bandStats.fdrQ;
    end
    critP = band_pvalue_fdr(p.bandStats.familyFile, q, false);
    if ~isnan(critP)
        p.bandStats.sigThreshold = critP;
    end
end

function n = cluster_comp_count(d)
% How many components the STUDY says are in this cluster, i.e. how many
% dipoles std_dipplot draws. NaN if the field isn't reachable.
    n = NaN;
    try
        c = d.STUDY.cluster(d.clusterIdx);
        if isfield(c, 'comps') && ~isempty(c.comps)
            n = numel(c.comps);
        end
    catch
        n = NaN;
    end
end

function report_centroid(fids, d)
% Cluster centroid in MNI coordinates, straight from the STUDY's own
% DIPFIT result -- the number that justifies calling this cluster
% sensorimotor at all, so it belongs in the Results or Methods text.
    try
        c = d.STUDY.cluster(d.clusterIdx);
        if isfield(c, 'dipole') && isfield(c.dipole, 'posxyz') && ~isempty(c.dipole.posxyz)
            pos = c.dipole.posxyz(1, :);
            emit(fids, '  Dipole centroid  : MNI [x y z] = [%.0f %.0f %.0f]\n', ...
                pos(1), pos(2), pos(3));
        end
    catch
        emit(fids, '  Dipole centroid  : (not available in this STUDY struct)\n');
    end
end

%% ========================================================================
%  2D ERSP RM-ANOVA (the figure's fourth ERSP panel)
%  ========================================================================
function report_ersp_anova(fids, s, p)
    emit(fids, '\n  -- ERSP RM-ANOVA across conditions (2D cluster permutation) --------\n');

    mask = s.condMask;
    if iscell(mask)
        mask = mask{1, 1};
    end
    mask = logical(mask);

    if ~any(mask(:))
        emit(fids, '     No significant time-frequency cluster (nothing survived).\n');
        return
    end

    freqSel = any(mask, 2);
    timeSel = any(mask, 1);
    fLo = s.allFreqs(find(freqSel, 1, 'first'));
    fHi = s.allFreqs(find(freqSel, 1, 'last'));
    tLo = pct_of_cycle(s.allTimes(find(timeSel, 1, 'first')), s.allTimes);
    tHi = pct_of_cycle(s.allTimes(find(timeSel, 1, 'last')),  s.allTimes);

    emit(fids, '     Frequency extent : %.1f - %.1f Hz\n', fLo, fHi);
    emit(fids, '     Cycle extent     : %.1f - %.1f %% of cycle\n', tLo, tHi);
    emit(fids, '     Plane covered    : %.1f%% of time-frequency bins are significant\n', ...
        100 * nnz(mask) / numel(mask));

    pv = omnibus_pvalues(s);
    if ~isempty(pv)
        inMask = pv(mask);
        inMask = inMask(isfinite(inMask));
        if ~isempty(inMask)
            emit(fids, '     p (in cluster)   : min %.4g, max %.4g\n', ...
                min(inMask), max(inMask));
        end
    end
    emit(fids, ['     NOTE: this mask is what the RM-ANOVA panel plots. Its frequency\n' ...
                '           extent is the honest answer for "which bands showed an\n' ...
                '           effect" -- read it against the band edges rather than\n' ...
                '           assuming the band-power test and this test agree.\n']);
end

function pv = omnibus_pvalues(s)
    pv = [];
    if ~isfield(s, 'permTest') || isempty(s.permTest)
        return
    end
    pv = s.permTest(1).pval;
    if iscell(pv)
        if isempty(pv)
            pv = [];
            return
        end
        pv = pv{1, 1};
    end
end

%% ========================================================================
%  1D band-power cluster permutation (the figure's band-power row)
%  ========================================================================
function report_bands(fids, s, bandStats, p)
    emit(fids, '\n  -- Band power vs cycle (1D cluster permutation, %d perms) ----------\n', ...
        p.bandStats.nPerm);

    condNames = strrep(p.design.legend, ' Pressure', '');

    for bi = 1:numel(bandStats)
        b = bandStats(bi);
        emit(fids, '\n     %s\n', clean_band_name(b.name));

        [peakEta, peakIdx] = max(b.eta2p);
        emit(fids, '        peak eta2p    : %.3f at %.1f%% of cycle\n', ...
            peakEta, pct_of_cycle(s.allTimes(peakIdx), s.allTimes));

        sig = significant_clusters(b.clust, p.bandStats.sigThreshold);
        if isempty(sig)
            emit(fids, '        significant   : NONE (report as n.s.)\n');
        else
            emit(fids, '        significant   : %d cluster(s)\n', height(sig));
            for k = 1:height(sig)
                emit(fids, '           cluster %d  : %.1f - %.1f %% of cycle (width %.1f%%), mass = %.1f, p = %.4g\n', ...
                    k, sig.StartPct(k), sig.EndPct(k), ...
                    sig.EndPct(k) - sig.StartPct(k), sig.Mass(k), sig.p(k));
            end
        end

        % Condition means, which is what backs the "decreased monotonically
        % with pressure" wording. Reported over the widest significant
        % window when there is one (that is the window the claim is about)
        % and over the whole cycle regardless, so the direction can be
        % checked either way.
        if ~isempty(sig)
            idx = sig.StartIdx(1):sig.EndIdx(1);
            report_condition_means(fids, b.groupMean, idx, condNames, ...
                sprintf('over widest significant window (%.1f-%.1f%%)', ...
                    sig.StartPct(1), sig.EndPct(1)));
        end
        report_condition_means(fids, b.groupMean, 1:size(b.groupMean, 1), ...
            condNames, 'over the full cycle');
    end
end

function report_condition_means(fids, groupMean, idx, condNames, whereText)
    m = mean(groupMean(idx, :), 1);
    emit(fids, '        mean power %s (dB):\n', whereText);
    parts = cell(1, numel(m));
    for c = 1:numel(m)
        parts{c} = sprintf('%s = %+.3f', condNames{c}, m(c));
    end
    emit(fids, '           %s\n', strjoin(parts, ',  '));
    if all(diff(m) < 0)
        emit(fids, '           ordering    : monotonic DECREASE with pressure (%s)\n', ...
            strjoin(condNames, ' > '));
    elseif all(diff(m) > 0)
        emit(fids, '           ordering    : monotonic INCREASE with pressure\n');
    else
        emit(fids, '           ordering    : NOT monotonic -- do not write "graded" for this band\n');
    end
    emit(fids, '           %s minus %s: %+.3f dB\n', ...
        condNames{1}, condNames{end}, m(1) - m(end));
end

%% ========================================================================
%  Cross-cluster summary: the comparisons the Results text actually makes
%  ========================================================================
function report_cross_cluster(fids, data, p)
    emit(fids, '\n');
    emit(fids, '========================================================================\n');
    emit(fids, ' CROSS-CLUSTER SUMMARY (the claims the Results text makes)\n');
    emit(fids, '========================================================================\n');

    emit(fids, '\n  Subject counts (the n_L / n_R placeholders):\n');
    for bi = 1:numel(data)
        emit(fids, '     %-28s n = %d\n', ...
            display_name(data(bi).s.name, p), numel(data(bi).s.subjects));
    end

    nBand = numel(data(1).bandStats);
    for bandIdx = 1:nBand
        emit(fids, '\n  %s -- across clusters:\n', ...
            clean_band_name(data(1).bandStats(bandIdx).name));
        for bi = 1:numel(data)
            b   = data(bi).bandStats(bandIdx);
            sig = significant_clusters(b.clust, p.bandStats.sigThreshold);
            nm  = display_name(data(bi).s.name, p);
            if isempty(sig)
                emit(fids, '     %-28s n.s.\n', nm);
            else
                widest = sig.EndPct(1) - sig.StartPct(1);
                m = mean(b.groupMean(sig.StartIdx(1):sig.EndIdx(1), :), 1);
                emit(fids, '     %-28s %.1f-%.1f%% (width %.1f%%), p = %.4g, Low-High = %+.3f dB\n', ...
                    nm, sig.StartPct(1), sig.EndPct(1), widest, sig.p(1), m(1) - m(end));
            end
        end
    end

    emit(fids, ['\n  Read the laterality claim ("most pronounced and most clearly graded\n' ...
                '  in the right cluster") off the alpha row above: compare BOTH the\n' ...
                '  significant window width and the Low-High separation. If they point\n' ...
                '  in different directions, say which one you mean rather than writing\n' ...
                '  "most pronounced" unqualified.\n']);
end

%% ========================================================================
%  Small helpers
%  ========================================================================
function emit(fids, fmt, varargin)
    for f = fids
        fprintf(f, fmt, varargin{:});
    end
end

function sig = significant_clusters(clust, threshold)
% Significant rows of a CLUSTER_PERM_1D table, widest first (the table
% arrives sorted by mass; width is what the text reports, so re-sort).
%
% THRESHOLD is the FDR cutoff, not the per-test alpha, and the comparison
% is <= because that cutoff IS an attained p-value: the largest one that
% survives. A strict < would drop the very cluster that defines it. This
% mirrors RENDER_BAND_POWER_ROW exactly, so report and figure agree.
    sig = [];
    if isempty(clust) || ~istable(clust) || height(clust) == 0
        return
    end
    sig = clust(clust.p <= threshold, :);
    if height(sig) == 0
        sig = [];
        return
    end
    [~, order] = sort(sig.EndPct - sig.StartPct, 'descend');
    sig = sig(order, :);
end

function pct = pct_of_cycle(t, allTimes)
    pct = 100 * (t - allTimes(1)) / (allTimes(end) - allTimes(1));
end

function name = clean_band_name(name)
% Band names carry TeX markup for the figure ('\theta (4-8 Hz)'); strip
% the backslash so the console/text report reads plainly.
    name = strrep(name, '\', '');
end

function name = display_name(rawName, p)
    name = rawName;
    if ~isfield(p.plot, 'clusterDisplayNames')
        return
    end
    hit = strcmp(p.plot.clusterDisplayNames(:, 1), rawName);
    if any(hit)
        name = p.plot.clusterDisplayNames{find(hit, 1), 2};
    end
end

function str = join_ids(ids)
    if iscell(ids)
        parts = cellfun(@num2str_safe, ids, 'UniformOutput', false);
    else
        parts = arrayfun(@num2str_safe, ids, 'UniformOutput', false);
    end
    str = strjoin(parts, ', ');
end

function s = num2str_safe(v)
    if ischar(v) || isstring(v)
        s = char(v);
    else
        s = num2str(v);
    end
end