function report_lmm21(results, L, featureAudit)
%REPORT_LMM21  The statistics report, the manuscript numbers, the LaTeX tables.
%
%   REPORT_LMM21(RESULTS, L, FEATUREAUDIT) prints and writes everything the
%   manuscript needs, so that no number is copied by hand:
%
%     lmm21_stats_report.txt          the run, both passes, with intervals
%     lmm21_cluster_table.tex         the seven joint tests
%     lmm21_supplementary_table.tex   the 21 coefficients and their intervals
%
%   THE TWO PASSES ARE PRINTED SEPARATELY AND LABELLED, because they answer
%   different questions and the writing up must not blur them. The seven
%   cluster tests carry the claim. The 21 single-feature intervals carry the
%   precision statement and deliberately have no p and no q beside them.
%
%   Rounding happens once, here, so the tables and the sentences agree.
%
%   See also FIT_LMM21_MODELS, FIT_CLUSTER_LMM, RUN_LMM21.
%
%   Part of the KneeExo-EEG analysis code.

if nargin < 3
    featureAudit = table();
end

S = results.summary;
C = results.cluster;
F = results.feature;

[~, meta] = lmm21_feature_names(L);

txt = {};
txt{end+1} = 'Trial-level cortical activity and perceived difficulty';
txt{end+1} = repmat('=', 1, 74);
txt{end+1} = sprintf('Run              %s', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
txt{end+1} = sprintf('Primary spec     %s', S.spec);
txt{end+1} = sprintf('Merged trials    %d', results.nTrials);
txt{end+1} = sprintf('Clusters         %d, of which %d fitted', ...
    S.nClusters, S.nConverged);
txt{end+1} = sprintf('Features         %d, %d per cluster', ...
    S.nFeatures, numel(L.bandNames));
txt{end+1} = sprintf('N per model      median %d, range %d to %d', ...
    S.medianN, S.rangeN(1), S.rangeN(2));
txt{end+1} = sprintf('Bands            %s', band_summary(L));
txt{end+1} = sprintf('Trial QC         %s', ...
    iff(L.applyErspQC, 'flag_bad_trials, as the published ERSPs', 'none'));
txt{end+1} = '';

% =========================================================================
txt{end+1} = 'THE TEST: does each cluster contribute?';
txt{end+1} = repmat('-', 1, 74);
txt{end+1} = ['A joint Wald test on the three band coefficients of one ' ...
    'cluster, entered'];
txt{end+1} = ['together. Family of seven, Benjamini and Hochberg corrected ' ...
    'across the seven.'];
txt{end+1} = '';
txt{end+1} = sprintf('%-26s %5s %10s %8s %9s %9s', ...
    'cluster', 'N', 'F', 'df', 'p', 'q');
for i = 1:height(C)
    if C.Converged(i)
        txt{end+1} = sprintf('%-26s %5d %10.3f %4d,%-4.0f %9.4f %9.4f', ...
            C.Cluster(i), C.N(i), C.FStat(i), C.DF1(i), C.DF2(i), ...
            C.pValue(i), C.q(i)); %#ok<AGROW>
    else
        txt{end+1} = sprintf('%-26s %5d  did not fit: %s', ...
            C.Cluster(i), C.N(i), C.Message(i)); %#ok<AGROW>
    end
end
txt{end+1} = '';
txt{end+1} = sprintf('  smallest p across the seven   %.4f', S.minP);
txt{end+1} = sprintf('  smallest q after BH           %.4f', S.minQ);
txt{end+1} = sprintf('  clusters surviving q < %.2f    %d', ...
    L.stats.fdrQ, S.nSurvivingFDR);
txt{end+1} = '';

if S.nSurvivingFDR > 0
    txt{end+1} = sprintf(['*** %d cluster(s) survive the correction. The ' ...
        'Results paragraph as written'], S.nSurvivingFDR);
    txt{end+1} = '    reports a null and would no longer be true. ***';
    txt{end+1} = '';
end

% =========================================================================
txt{end+1} = 'THE BOUND: how large could any single feature be?';
txt{end+1} = repmat('-', 1, 74);
txt{end+1} = ['One model per feature, the feature alone, so the coefficient ' ...
    'is a total'];
txt{end+1} = ['effect rather than one adjusted for the other bands of the ' ...
    'same component.'];
txt{end+1} = 'These are intervals, not tests. No p and no q belong beside them.';
txt{end+1} = '';
txt{end+1} = sprintf('%-14s %5s %10s %8s  %s', 'feature', 'N', 'beta', 'SE', '95% CI');
Fs = sortrows(F, 'Feature');
for i = 1:height(Fs)
    if Fs.Converged(i)
        txt{end+1} = sprintf('%-14s %5d %+10.4f %8.4f  [%+.3f %+.3f]', ...
            Fs.Feature(i), Fs.N(i), Fs.Estimate(i), Fs.SE(i), ...
            Fs.Lower(i), Fs.Upper(i)); %#ok<AGROW>
    else
        txt{end+1} = sprintf('%-14s %5d  did not fit: %s', ...
            Fs.Feature(i), Fs.N(i), Fs.Message(i)); %#ok<AGROW>
    end
end
txt{end+1} = '';
txt{end+1} = sprintf('  widest interval end, %-10s %.4f rating points per dB', ...
    S.spec, S.maxAbsCI_dB);
txt{end+1} = sprintf('  widest interval end, %-10s %.4f rating points per SD', ...
    S.boundSpec, S.maxAbsCI);
txt{end+1} = '';

% =========================================================================
txt{end+1} = 'Numbers for the manuscript';
txt{end+1} = repmat('-', 1, 74);
txt{end+1} = sprintf(['  Results: "no cortical cluster contributed ... ' ...
    '(all $q \\geq %.2f$;'], S.minQ);
txt{end+1} = sprintf('  uncorrected $p \\geq %.2f$)".', S.minP);
txt{end+1} = sprintf(['  Discussion: the widest interval reaches +/- %.2f ' ...
    'rating points per'], S.maxAbsCI);
txt{end+1} = '  within-participant SD, against a demand effect of 5.20 rating points.';
txt{end+1} = '';
txt{end+1} = '  The family is the SEVEN CLUSTERS, not 21 features. The Methods';
txt{end+1} = '  sentence has to say so, and the 21 must not be described as tested.';
txt{end+1} = '';
txt{end+1} = ['  The bound is quoted from spec "' char(S.boundSpec) '", where ' ...
    'the feature is z scored,'];
txt{end+1} = '  because a bound in dB has no scale on which to meet 5.20 rating points.';
txt{end+1} = '';
txt{end+1} = '  The bound is on the feature AS MEASURED. Single-trial band power is';
txt{end+1} = '  noisy, and measurement error attenuates a slope towards zero, so the';
txt{end+1} = '  bound on an error-free measure is larger. State it, or divide by the';
txt{end+1} = '  split-half reliability and say which you did.';
txt{end+1} = '';

if S.nSingular > 0
    txt{end+1} = sprintf(['WARNING %d of %d cluster fits have the participant ' ...
        'variance at the boundary.'], S.nSingular, S.nConverged);
    txt{end+1} = '';
end

if isfield(S, 'randSlopeConverged')
    txt{end+1} = sprintf(['Random slope check: %d of %d cluster models ' ...
        'converged. This is the'], S.randSlopeConverged, S.randSlopeTotal);
    txt{end+1} = 'evidence for the Methods sentence, not an assertion.';
    txt{end+1} = '';
end

if ~isempty(featureAudit)
    txt{end+1} = 'Feature build audit';
    txt{end+1} = repmat('-', 1, 74);
    txt{end+1} = sprintf('  epochs read          %d', sum(featureAudit.nLoaded));
    txt{end+1} = sprintf('  flagged by QC        %d (%.1f%%)', ...
        sum(featureAudit.nFlaggedQC), ...
        100 * sum(featureAudit.nFlaggedQC) / max(1, sum(featureAudit.nLoaded)));
    txt{end+1} = sprintf('  trials produced      %d', sum(featureAudit.nTrials));
    txt{end+1} = sprintf('  worst match residual %.1f ms', ...
        max(featureAudit.maxResidualMs));
    txt{end+1} = sprintf('  trial numbers disagreeing between the streams %d', ...
        sum(featureAudit.nTrialNumberDisagree));
    txt{end+1} = '';
end

body = strjoin(txt, newline);
fprintf('\n%s\n', body);

fid = fopen(L.files.report, 'w');
if fid > 0
    fprintf(fid, '%s\n', body);
    fclose(fid);
end

% =========================================================================
%  The cluster table
% =========================================================================
lines = {};
lines{end+1} = '% The seven cluster tests. Generated by report_lmm21.m.';
lines{end+1} = '\begin{table}[htbp]';
lines{end+1} = '\centering';
lines{end+1} = sprintf(['\\caption{Joint test of each cortical cluster''s ' ...
    'contribution to perceived difficulty. The three band-power features of ' ...
    'a cluster were entered together into the mediation model and tested ' ...
    'jointly. $q$ values are Benjamini and Hochberg corrected across the %d ' ...
    'clusters.}'], height(C));
lines{end+1} = '\label{tab:lmm21cluster}';
lines{end+1} = '\begin{tabular}{lrrrr}';
lines{end+1} = '\toprule';
lines{end+1} = 'Cluster & $n$ & $F$ & $p$ & $q$ \\';
lines{end+1} = '\midrule';

labels = containers.Map(L.clusters(:, 1), L.clusters(:, 3));
Cs = sortrows(C, 'Cluster');
for i = 1:height(Cs)
    nm = char(Cs.Cluster(i));
    if Cs.Converged(i)
        lines{end+1} = sprintf('%s & %d & $F(%d, %.0f) = %.2f$ & %.3f & %.3f \\\\', ...
            labels(nm), Cs.N(i), Cs.DF1(i), Cs.DF2(i), Cs.FStat(i), ...
            Cs.pValue(i), Cs.q(i)); %#ok<AGROW>
    else
        lines{end+1} = sprintf('%s & %d & \\multicolumn{3}{c}{did not fit} \\\\', ...
            labels(nm), Cs.N(i)); %#ok<AGROW>
    end
end
lines{end+1} = '\bottomrule';
lines{end+1} = '\end{tabular}';
lines{end+1} = '\end{table}';

write_lines(L.files.clusterTable, lines);

% =========================================================================
%  The supplementary feature table, intervals only
% =========================================================================
order = meta.Feature;
[tf, loc] = ismember(order, F.Feature);
Q = F(loc(tf), :);
M = meta(tf, :);

lines = {};
lines{end+1} = '% The 21 single-feature intervals. Generated by report_lmm21.m.';
lines{end+1} = '% NOTE: intervals, not tests. There is deliberately no p and no q here.';
lines{end+1} = '\begin{table}[htbp]';
lines{end+1} = '\centering';
lines{end+1} = sprintf(['\\caption{Effect of each cortical feature on ' ...
    'perceived difficulty, each added on its own to the mediation model: ' ...
    'imposed pressure, the within- and between-participant components of ' ...
    'neuromuscular effort and tracking error, trial number, and a ' ...
    'by-participant random intercept. Features are centred within ' ...
    'participant, so a coefficient is rating points per dB. These are ' ...
    'estimates and intervals; the statistical test was carried out at the ' ...
    'cluster level (Table~\\ref{tab:lmm21cluster}) across %d clusters, not ' ...
    'across these %d features.}'], height(C), height(Q));
lines{end+1} = '\label{tab:lmm21feature}';
lines{end+1} = '\begin{tabular}{llrrr}';
lines{end+1} = '\toprule';
lines{end+1} = 'Cluster & Band & $n$ & $\beta$ & 95\% CI \\';
lines{end+1} = '\midrule';

lastCluster = '';
for i = 1:height(Q)
    thisCluster = char(M.ClusterLabel(i));
    if strcmp(thisCluster, lastCluster)
        cell1 = '';
    else
        if ~isempty(lastCluster)
            lines{end+1} = '\addlinespace'; %#ok<AGROW>
        end
        cell1 = thisCluster;
        lastCluster = thisCluster;
    end

    bandCell = sprintf('%s (%g--%g\\,Hz)', char(M.BandLabel(i)), ...
        M.LoHz(i), M.HiHz(i));

    if Q.Converged(i)
        lines{end+1} = sprintf('%s & %s & %d & $%+.3f$ & $[%+.3f, %+.3f]$ \\\\', ...
            cell1, bandCell, Q.N(i), Q.Estimate(i), Q.Lower(i), Q.Upper(i)); %#ok<AGROW>
    else
        lines{end+1} = sprintf('%s & %s & \\multicolumn{3}{c}{did not fit} \\\\', ...
            cell1, bandCell); %#ok<AGROW>
    end
end
lines{end+1} = '\bottomrule';
lines{end+1} = '\end{tabular}';
lines{end+1} = '\end{table}';

write_lines(L.files.supplement, lines);

fprintf('\nWrote %s\n', L.files.report);
fprintf('Wrote %s\n', L.files.clusterTable);
fprintf('Wrote %s\n', L.files.supplement);

% =========================================================================
%  Methods
% =========================================================================
fprintf('\n---- Methods, the facts this analysis obliges you to state ----\n\n');
fprintf('  Features: %d clusters x %d bands = %d, whole-cycle band power in dB,\n', ...
    size(L.clusters, 1), numel(L.bandNames), S.nFeatures);
fprintf(['    movement cycles averaged within a trial, referenced to the\n' ...
    '    condition-balanced whole-cycle baseline.\n']);
fprintf('  Clusters: %s.\n', strjoin(L.clusters(:, 3).', '; '));
fprintf(['  Prime_Visual is the eighth ROI of ersp_params and is excluded: 7 of\n' ...
    '    its 12 components are the same (participant, IC) pairs as\n' ...
    '    Right_Parieto_Occipital, so it is not an independent source.\n']);
fprintf(['  Caveat to state: the clustering solutions are separate runs, so one\n' ...
    '    component can appear in two clusters. Among the seven analysed this\n' ...
    '    happens once, participant 11 IC 29 in both premotor clusters.\n']);
fprintf('  Bands: %s.\n', band_summary(L));
fprintf(['  Model: the mediation model plus the cluster''s band power. Pressure\n' ...
    '    enters as an ordinal 0, 1, 2; effort and error are split into within-\n' ...
    '    and between-participant components; trial number enters z scored. This\n' ...
    '    is RUN_RESULTS_BEHAVIOUR mdlB term for term.\n']);
fprintf(['  Test: a joint Wald test on the three band coefficients of each\n' ...
    '    cluster, with Satterthwaite denominator degrees of freedom, corrected\n' ...
    '    across the %d clusters. NOT across the %d features.\n'], ...
    height(C), S.nFeatures);
fprintf(['  Why joint: the bands of one component are correlated through 1/f\n' ...
    '    structure and spectral leakage, and a marginal test per band has\n' ...
    '    little power against an effect spread across them.\n']);
fprintf(['  Why not one model over all clusters: only three participants\n' ...
    '    contribute a component to all seven, so that model is not available.\n']);
fprintf(['  The between-participant effort term is absent because the effort\n' ...
    '    index is normalised within participant, so it has no between-participant\n' ...
    '    variance by construction.\n']);
if isfield(S, 'randSlopeConverged')
    fprintf(['  Random slope models: %d of %d converged, which is why the primary\n' ...
        '    model uses a by-participant random intercept.\n'], ...
        S.randSlopeConverged, S.randSlopeTotal);
end
fprintf('\n');

end


% ----------------------------------------------------------------------------
function write_lines(fname, lines)

fid = fopen(fname, 'w');
if fid > 0
    fprintf(fid, '%s\n', strjoin(lines, newline));
    fclose(fid);
end

end


% ----------------------------------------------------------------------------
function s = band_summary(L)

parts = cell(1, numel(L.bandNames));
for b = 1:numel(L.bandNames)
    e = L.bands.(L.bandNames{b});
    parts{b} = sprintf('%s %g to %g Hz', L.bandLabels{b}, e(1), e(2));
end
s = strjoin(parts, ', ');

end


% ----------------------------------------------------------------------------
function out = iff(c, a, b)

if c, out = a; else, out = b; end

end