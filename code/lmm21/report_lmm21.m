function report_lmm21(results, L, featureAudit)
%REPORT_LMM21  The statistics report, the manuscript numbers, the LaTeX table.
%
%   REPORT_LMM21(RESULTS, L, FEATUREAUDIT) prints and writes everything the
%   manuscript needs from this analysis, so no number is copied by hand:
%
%     lmm21_stats_report.txt         the run, per feature, with intervals
%     lmm21_supplementary_table.tex  the 21 coefficients, by cluster and band
%
%   The placeholders this fills are \ph{value} and \ph{$\approx 0.06$} in the
%   closing Results paragraph, and the exclusion bound in the Discussion. All
%   three come from one run, so they cannot drift apart.
%
%   Rounding happens once, here, and the same rounded values go into the table
%   and into the sentences.
%
%   See also FIT_LMM21_MODELS, RUN_LMM21.
%
%   Part of the KneeExo-EEG analysis code.

if nargin < 3
    featureAudit = table();
end

S = results.summary;
P = results.primary;

[~, meta] = lmm21_feature_names(L);

% ---- the report ---------------------------------------------------------
txt = {};
txt{end+1} = 'Trial-level cortical band power and perceived difficulty';
txt{end+1} = repmat('=', 1, 72);
txt{end+1} = sprintf('Run              %s', ...
    char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
txt{end+1} = sprintf('Primary spec     %s', S.spec);
txt{end+1} = sprintf('Merged trials    %d', results.nTrials);
txt{end+1} = sprintf('Features         %d, of which %d fitted', ...
    S.nFeatures, S.nConverged);
txt{end+1} = sprintf('N per model      median %d, range %d to %d', ...
    S.medianN, S.rangeN(1), S.rangeN(2));
txt{end+1} = sprintf('Clusters         %s', strjoin(L.clusters(:, 1).', ', '));
txt{end+1} = sprintf('Bands            %s', band_summary(L));
txt{end+1} = sprintf('Trial QC         %s', ...
    iff(L.applyErspQC, 'flag_bad_trials, as the published ERSPs', 'none'));
txt{end+1} = sprintf('Baseline         %s', L.baseline);
txt{end+1} = '';

txt{end+1} = 'Numbers for the manuscript';
txt{end+1} = repmat('-', 1, 72);
txt{end+1} = sprintf('  smallest uncorrected p    %.4f', S.minP);
txt{end+1} = sprintf('  smallest q after BH       %.4f', S.minQ);
txt{end+1} = sprintf('  features surviving q<%.2f  %d', L.stats.fdrQ, S.nSurvivingFDR);
txt{end+1} = sprintf('  widest interval end       %.4f rating points per SD', ...
    S.maxAbsCI);
txt{end+1} = '';
txt{end+1} = sprintf(['  Results sentence: "all $q \\geq %.2f$; uncorrected ' ...
    '$p \\geq %.2f$".'], S.minQ, S.minP);
txt{end+1} = sprintf(['  Discussion bound: +/- %.2f rating points per within-' ...
    'participant SD,'], S.maxAbsCI);
txt{end+1} = '  against a demand effect of 5.20 rating points.';
txt{end+1} = '';

if S.nSurvivingFDR > 0
    txt{end+1} = sprintf(['*** %d feature(s) survive the correction. The ' ...
        'Results paragraph as written'], S.nSurvivingFDR);
    txt{end+1} = '    reports a null and would no longer be true. ***';
    txt{end+1} = '';
end

if S.nSingular > 0
    txt{end+1} = sprintf(['WARNING %d of %d primary fits have the participant ' ...
        'variance at the boundary.'], S.nSingular, S.nConverged);
    txt{end+1} = '';
end

if isfield(S, 'randSlopeConverged')
    txt{end+1} = sprintf(['Random slope check: %d of %d models converged. This ' ...
        'is the evidence for the'], S.randSlopeConverged, S.randSlopeTotal);
    txt{end+1} = 'Methods sentence about random slope models, not an assertion.';
    txt{end+1} = '';
end

txt{end+1} = 'Per feature, primary specification, sorted by p';
txt{end+1} = repmat('-', 1, 72);
txt{end+1} = sprintf('%-14s %5s %9s %8s %9s %8s  %s', ...
    'feature', 'N', 'beta', 'SE', 'p', 'q', '95% CI');
for i = 1:height(P)
    if P.Converged(i)
        txt{end+1} = sprintf('%-14s %5d %+9.4f %8.4f %9.4f %8.4f  [%+.3f %+.3f]', ...
            P.Feature(i), P.N(i), P.Estimate(i), P.SE(i), P.pValue(i), ...
            P.q(i), P.Lower(i), P.Upper(i)); %#ok<AGROW>
    else
        txt{end+1} = sprintf('%-14s %5d  did not fit: %s', ...
            P.Feature(i), P.N(i), P.Message(i)); %#ok<AGROW>
    end
end
txt{end+1} = '';
txt{end+1} = ['Units: rating points per within-participant standard deviation ' ...
    'of the feature,'];
txt{end+1} = 'with pressure, tracking error and muscular effort held constant.';

if ~isempty(featureAudit)
    txt{end+1} = '';
    txt{end+1} = 'Feature build audit';
    txt{end+1} = repmat('-', 1, 72);
    txt{end+1} = sprintf('  epochs read         %d', sum(featureAudit.nLoaded));
    txt{end+1} = sprintf('  flagged by QC       %d (%.1f%%)', ...
        sum(featureAudit.nFlaggedQC), ...
        100 * sum(featureAudit.nFlaggedQC) / max(1, sum(featureAudit.nLoaded)));
    txt{end+1} = sprintf('  trials produced     %d', sum(featureAudit.nTrials));
    txt{end+1} = sprintf('  worst match residual %.1f ms', ...
        max(featureAudit.maxResidualMs));
    txt{end+1} = sprintf('  trial numbers disagreeing between the two streams %d', ...
        sum(featureAudit.nTrialNumberDisagree));
end

body = strjoin(txt, newline);
fprintf('\n%s\n', body);

fid = fopen(L.files.report, 'w');
if fid > 0
    fprintf(fid, '%s\n', body);
    fclose(fid);
end

% ---- the supplementary table -------------------------------------------
order = meta.Feature;
[tf, loc] = ismember(order, P.Feature);
Q = P(loc(tf), :);
M = meta(tf, :);

lines = {};
lines{end+1} = '% Supplementary table: trial-level cortical band power and perceived difficulty.';
lines{end+1} = '% Generated by report_lmm21.m. Do not edit by hand.';
lines{end+1} = '\begin{table}[htbp]';
lines{end+1} = '\centering';
lines{end+1} = sprintf(['\\caption{Fixed effect of each cortical feature on ' ...
    'perceived difficulty, over and above imposed pressure, tracking error ' ...
    'and neuromuscular effort. Coefficients are rating points per within-' ...
    'participant standard deviation of the feature. $q$ values are Benjamini ' ...
    'and Hochberg corrected across the %d features.}'], height(Q));
lines{end+1} = '\label{tab:lmm21}';
lines{end+1} = '\begin{tabular}{llrrrrrr}';
lines{end+1} = '\toprule';
lines{end+1} = 'Cluster & Band & $n$ & $\beta$ & SE & 95\% CI & $p$ & $q$ \\';
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
        lines{end+1} = sprintf(...
            '%s & %s & %d & $%+.3f$ & %.3f & $[%+.3f, %+.3f]$ & %.3f & %.3f \\\\', ...
            cell1, bandCell, Q.N(i), Q.Estimate(i), Q.SE(i), ...
            Q.Lower(i), Q.Upper(i), Q.pValue(i), Q.q(i)); %#ok<AGROW>
    else
        lines{end+1} = sprintf(...
            '%s & %s & \\multicolumn{6}{c}{model did not fit} \\\\', ...
            cell1, bandCell); %#ok<AGROW>
    end
end

lines{end+1} = '\bottomrule';
lines{end+1} = '\end{tabular}';
lines{end+1} = '\end{table}';

fid = fopen(L.files.supplement, 'w');
if fid > 0
    fprintf(fid, '%s\n', strjoin(lines, newline));
    fclose(fid);
end

fprintf('\nWrote %s\n', L.files.report);
fprintf('Wrote %s\n', L.files.supplement);

% ---- the Methods facts that have to be stated --------------------------
fprintf('\n---- Methods, the facts this analysis obliges you to state ----\n\n');
fprintf('  Feature set: %d clusters x %d bands = %d features.\n', ...
    size(L.clusters, 1), numel(L.bandNames), L.nFeatures);
fprintf('  Clusters: %s.\n', strjoin(L.clusters(:, 3).', '; '));
fprintf(['  Prime_Visual is the eighth ROI of ersp_params and is excluded: 7 of\n' ...
    '    its 12 components are the same (participant, IC) pairs as\n' ...
    '    Right_Parieto_Occipital, so it is not an independent source and would\n' ...
    '    put the same signal in the family twice.\n']);
fprintf(['  Caveat to state: the clustering solutions are separate runs, so one\n' ...
    '    component can appear in two clusters. Among the seven analysed, this\n' ...
    '    happens once, participant 11 IC 29 in both premotor clusters.\n']);
fprintf('  Bands: %s.\n', band_summary(L));
fprintf(['  Feature: whole-cycle band power, movement cycles averaged within ' ...
    'a trial,\n    referenced to the condition-balanced whole-cycle baseline, ' ...
    'in dB.\n']);
fprintf('  Trial quality control: %s.\n', ...
    iff(L.applyErspQC, 'flag_bad_trials per participant and condition, as the published ERSPs', 'none'));
fprintf('  Scaling: feature %s within participant.\n', L.model.featureMode);
fprintf('  Model: %s, REML, Wald test with Satterthwaite degrees of freedom.\n', ...
    'by-participant random intercept');
if isfield(S, 'randSlopeConverged')
    fprintf(['  Random slope models: %d of %d converged, which is why the ' ...
        'primary model\n    uses a random intercept.\n'], ...
        S.randSlopeConverged, S.randSlopeTotal);
end
fprintf('  Correction: Benjamini and Hochberg across the %d features.\n\n', ...
    L.nFeatures);

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