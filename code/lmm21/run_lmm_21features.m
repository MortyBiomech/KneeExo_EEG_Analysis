function results = run_lmm_21features(cfg, F, B)
%RUN_LMM_21FEATURES  Does trial level cortical band power predict the rating?
%
%  results = RUN_LMM_21FEATURES() runs the whole thing with the settings in
%  lmm21_config: builds or loads the 21 feature table, merges it with the
%  screened behaviour table, fits one model per feature, corrects across the
%  21 with Benjamini and Hochberg, and writes the results, the sensitivity
%  runs and a report.
%
%  results = RUN_LMM_21FEATURES(cfg, F, B) uses a feature table F and a
%  behaviour table B that are already in memory.
%
%  The model, for each feature in turn:
%
%    Score ~ 1 + Pressure_cat + Error + EffortIndex + EEGfeat + (1 | Subject_cat)
%
%  fitted by REML, with the feature z scored inside each participant so the
%  coefficient is rating points per within participant standard deviation.
%  Each feature is judged by its own coefficient, tested by a Wald test with
%  Satterthwaite denominator degrees of freedom. There is no model comparison
%  anywhere in this file, by design.
%
%  What the output supports. Three numbers go into the manuscript:
%    minimum q          the "all q >= ..." in the results paragraph
%    minimum p          the "uncorrected p >= ..." in the same sentence
%    maximum |CI|       the exclusion bound the Discussion sets against the
%                       5.20 rating point demand effect
%  All three come out of this script rather than off a printed table.
%
%  The null is only exclusionary if the intervals are narrow. A large q with a
%  wide interval says nothing was measured; a large q with an interval inside
%  a few tenths of a rating point is a substantive ruling out. The report
%  prints the intervals next to the q values for exactly that reason.
%
%  See also BUILD_EEG_FEATURE_TABLE, FIT_FEATURE_LMM, BH_FDR.

if nargin < 1 || isempty(cfg)
    cfg = lmm21_config();
end

% -------------------------------------------------------------------------
% 1. Inputs
% -------------------------------------------------------------------------
if nargin < 2 || isempty(F)
    cached = fullfile(cfg.paths.out, cfg.out.featureTable);
    if exist(cached, 'file') == 2
        fprintf('[run_lmm_21features] Loading cached features from %s\n', cached);
        S = load(cached);
        F = S.F;
    else
        F = build_eeg_feature_table(cfg);
    end
end

if nargin < 3 || isempty(B)
    B = load_behaviour_table(cfg);
end

featNames = setdiff(F.Properties.VariableNames, {'SubjectID', 'RawTrial'}, 'stable');
if numel(featNames) ~= 21
    error('run_lmm_21features:notTwentyOne', ...
        'The feature table has %d feature columns, expected 21.', numel(featNames));
end

% -------------------------------------------------------------------------
% 2. Merge
% -------------------------------------------------------------------------
% Inner join. A behaviour trial with no EEG epoch and an EEG trial with no
% behaviour row both drop out here, and the counts are printed so a large
% loss is visible rather than absorbed.
T = innerjoin(B, F, 'Keys', {'SubjectID', 'RawTrial'});

fprintf(['[run_lmm_21features] Behaviour %d trials, features %d trials, ' ...
         'merged %d trials, %d participants.\n'], ...
    height(B), height(F), height(T), numel(unique(T.SubjectID)));

if height(T) == 0
    error('run_lmm_21features:emptyMerge', ...
        ['The merge produced no rows. SubjectID and RawTrial do not line up ' ...
         'between the two tables, which almost always means one side is ' ...
         'keyed on the compacted trial counter rather than the raw index.']);
end

T.Subject_cat  = categorical(T.SubjectID);
T.Pressure_cat = categorical(string(T.Pressure), cfg.model.pressureLevels);

if any(isundefined(T.Pressure_cat))
    bad = unique(T.Pressure(isundefined(T.Pressure_cat)));
    error('run_lmm_21features:pressureLevels', ...
        'Pressure values %s are not among cfg.model.pressureLevels.', ...
        mat2str(bad(:).'));
end

% -------------------------------------------------------------------------
% 3. Fit
% -------------------------------------------------------------------------
allRows = {};

for s = 1:numel(cfg.specs)
    spec = cfg.specs(s);

    formula = buildSpecFormula(cfg, spec);
    fprintf('\n=== spec %s ===\n%s\n', spec.key, formula);

    specRows = cell(numel(featNames), 1);

    for k = 1:numel(featNames)
        fname = featNames{k};

        % Complete cases first, then scale. Scaling on the rows that actually
        % enter the model is what makes the coefficient exactly "per within
        % participant SD of the analysed data" rather than per SD of a
        % slightly different set.
        keep = isfinite(T.(fname)) & isfinite(T.(cfg.model.response)) & ...
               ~isundefined(T.Pressure_cat);
        for c = 1:numel(spec.covariates)
            keep = keep & isfinite(T.(spec.covariates{c}));
        end

        W = T(keep, :);

        if height(W) == 0
            r = blankRow(fname, spec, formula);
            specRows{k} = r;
            continue
        end

        W.EEGfeat = within_subject_scale(W.(fname), W.Subject_cat, ...
            spec.featureMode, cfg.scale.minTrials);

        for c = 1:numel(spec.covariates)
            cv = spec.covariates{c};
            W.(cv) = within_subject_scale(W.(cv), W.Subject_cat, ...
                spec.covariateMode, cfg.scale.minTrials);
        end

        r = fit_feature_lmm(W, formula, spec, cfg);
        r.Feature = string(fname);
        specRows{k} = r;

        fprintf('  %-14s  N %4d  b %+7.4f  SE %6.4f  p %8.4f  [%+7.4f %+7.4f]%s\n', ...
            fname, r.N, r.Estimate, r.SE, r.pValue, r.Lower, r.Upper, ...
            ternary(r.Converged, '', '   FIT FAILED'));
    end

    R = vertcat(specRows{:});
    R.q = bh_fdr(R.pValue, cfg.stats.fdrQ);
    allRows{end+1} = R; %#ok<AGROW>
end

results.all = vertcat(allRows{:});
results.all = movevars(results.all, {'Feature', 'Spec'}, 'Before', 1);

isPrimary = results.all.Spec == string(cfg.primarySpec);
results.primary = sortrows(results.all(isPrimary, :), 'pValue');
results.sensitivity = results.all(~isPrimary, :);

% -------------------------------------------------------------------------
% 4. Summary
% -------------------------------------------------------------------------
P = results.primary;
ok = P.Converged;

results.summary = struct();
results.summary.spec          = cfg.primarySpec;
results.summary.nFeatures     = height(P);
results.summary.nConverged    = nnz(ok);
results.summary.minP          = min(P.pValue(ok));
results.summary.minQ          = min(P.q(ok));
results.summary.nSurvivingFDR = nnz(P.q(ok) < cfg.stats.fdrQ);
results.summary.maxAbsCI      = max(P.MaxAbsCI(ok));
results.summary.medianN       = median(P.N(ok));
results.summary.rangeN        = [min(P.N(ok)) max(P.N(ok))];
results.summary.nSingular     = nnz(P.Singular(ok));

rs = results.all(results.all.Spec == "randslope", :);
if ~isempty(rs)
    results.summary.randSlopeConverged = nnz(rs.Converged);
    results.summary.randSlopeTotal     = height(rs);
end

results.cfg = cfg;
results.mergedHeight = height(T);

% -------------------------------------------------------------------------
% 5. Write
% -------------------------------------------------------------------------
if ~isempty(cfg.paths.out)
    if exist(cfg.paths.out, 'dir') ~= 7
        mkdir(cfg.paths.out);
    end
    writetable(results.primary,     fullfile(cfg.paths.out, cfg.out.resultsTable));
    writetable(results.sensitivity, fullfile(cfg.paths.out, cfg.out.sensitivity));
    save(fullfile(cfg.paths.out, cfg.out.results), 'results');
end

printReport(results, cfg);

end

% =========================================================================
function f = buildSpecFormula(cfg, spec)
terms = [{'1'}, {cfg.model.condition}, spec.covariates(:).', {'EEGfeat'}];
f = sprintf('%s ~ %s + %s', cfg.model.response, strjoin(terms, ' + '), spec.random);
end

% -------------------------------------------------------------------------
function r = blankRow(fname, spec, formula)
% No usable row for this feature at all, which happens when a cluster has no
% participants. Return the same shape as a fit so the results table stays
% rectangular and the feature is still counted in the family of 21.
r = fit_feature_lmm();
r.Feature   = string(fname);
r.Spec      = string(spec.key);
r.Formula   = string(formula);
r.FitMethod = string(spec.fitMethod);
r.Message   = "no complete cases for this feature";
end

% -------------------------------------------------------------------------
function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end

% -------------------------------------------------------------------------
function printReport(results, cfg)

S = results.summary;
P = results.primary;

txt = {};
txt{end+1} = 'Trial level cortical band power and perceived difficulty';
txt{end+1} = repmat('=', 1, 60);
txt{end+1} = sprintf('Run            %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')));
txt{end+1} = sprintf('Primary spec   %s', S.spec);
txt{end+1} = sprintf('Merged trials  %d', results.mergedHeight);
txt{end+1} = sprintf('Features       %d, of which %d fitted', S.nFeatures, S.nConverged);
txt{end+1} = sprintf('N per model    median %d, range %d to %d', ...
    S.medianN, S.rangeN(1), S.rangeN(2));
txt{end+1} = '';
txt{end+1} = 'Numbers for the manuscript';
txt{end+1} = repmat('-', 1, 60);
txt{end+1} = sprintf('  smallest uncorrected p     %.4f', S.minP);
txt{end+1} = sprintf('  smallest q after BH        %.4f', S.minQ);
txt{end+1} = sprintf('  features surviving q < %.2f %d', cfg.stats.fdrQ, S.nSurvivingFDR);
txt{end+1} = sprintf('  widest interval end        %.4f rating points per SD', S.maxAbsCI);
txt{end+1} = '';
txt{end+1} = sprintf(['  The results sentence reads "all q >= %.2f; uncorrected ' ...
    'p >= %.2f".'], S.minQ, S.minP);
txt{end+1} = sprintf(['  The Discussion bound is +/- %.2f rating points per ' ...
    'within participant SD,'], S.maxAbsCI);
txt{end+1} = '  set against a demand effect of 5.20 rating points.';
txt{end+1} = '';

if S.nSingular > 0
    txt{end+1} = sprintf(['WARNING %d of %d primary fits have a participant ' ...
        'variance at the boundary.'], S.nSingular, S.nConverged);
    txt{end+1} = '';
end

if isfield(S, 'randSlopeConverged')
    txt{end+1} = sprintf(['Random slope check: %d of %d models converged. ' ...
        'This is the evidence for'], S.randSlopeConverged, S.randSlopeTotal);
    txt{end+1} = 'the Methods sentence about random slope models, not an assertion.';
    txt{end+1} = '';
end

txt{end+1} = 'Per feature, primary specification, sorted by p';
txt{end+1} = repmat('-', 1, 78);
txt{end+1} = sprintf('%-14s %5s %8s %7s %8s %8s  %s', ...
    'feature', 'N', 'beta', 'SE', 'p', 'q', '95% CI');
for i = 1:height(P)
    txt{end+1} = sprintf('%-14s %5d %+8.4f %7.4f %8.4f %8.4f  [%+.3f %+.3f]', ...
        P.Feature(i), P.N(i), P.Estimate(i), P.SE(i), P.pValue(i), P.q(i), ...
        P.Lower(i), P.Upper(i)); %#ok<AGROW>
end

txt{end+1} = '';
txt{end+1} = 'Units: rating points per within participant standard deviation of the';
txt{end+1} = 'feature, with pressure, tracking error and effort held constant.';

body = strjoin(txt, newline);
fprintf('\n%s\n', body);

if ~isempty(cfg.paths.out)
    fid = fopen(fullfile(cfg.paths.out, cfg.out.report), 'w');
    if fid > 0
        fprintf(fid, '%s\n', body);
        fclose(fid);
    end
end

end
