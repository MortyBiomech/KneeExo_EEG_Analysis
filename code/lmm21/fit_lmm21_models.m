function results = fit_lmm21_models(T, L)
%FIT_LMM21_MODELS  One model per cortical feature, corrected across the 21.
%
%   RESULTS = FIT_LMM21_MODELS(T, L) fits, for each feature in turn,
%
%     Score ~ 1 + Pressure_cat + Error + EffortIndex + EEGfeat + (1 | Subject_cat)
%
%   by REML, with the feature z scored inside each participant, and tests the
%   coefficient by a Wald test with Satterthwaite denominator degrees of
%   freedom. The 21 p values are then corrected with Benjamini and Hochberg.
%
%   T must be the behaviour table joined to the feature table, carrying the
%   response, the condition, the covariates and the 21 feature columns.
%
%   RESULTS fields:
%     all          every specification, one row per feature
%     primary      the reported specification, sorted by p
%     sensitivity   the rest
%     summary      the numbers the manuscript needs
%
%   THREE NUMBERS GO INTO THE PAPER, and all three come from here rather than
%   off a printed table:
%     minQ        fills "all q >= ..." in the Results
%     minP        fills "uncorrected p >= ..." in the same sentence
%     maxAbsCI    the exclusion bound the Discussion sets against the 5.20
%                 rating point demand effect
%
%   HOW TO READ THE RESULT. The null is exclusionary only if the intervals are
%   narrow. A large q with a wide interval says nothing was measured; a large q
%   with an interval inside a few tenths of a rating point is a substantive
%   ruling out. The report prints the intervals beside the q values for exactly
%   that reason.
%
%   There is no model comparison anywhere in this file, by design.
%
%   See also FIT_FEATURE_LMM, BH_FDR, RUN_LMM21.
%
%   Part of the KneeExo-EEG analysis code.

arguments
    T table
    L (1,1) struct
end

featNames = lmm21_feature_names(L);

missing = featNames(~ismember(featNames, T.Properties.VariableNames));
if ~isempty(missing)
    error('fit_lmm21_models:MissingFeatures', ...
        'The merged table has no column for %s.', strjoin(missing, ', '));
end

allRows = {};

for s = 1:numel(L.specs)

    spec = L.specs(s);
    formula = build_formula(L, spec);

    fprintf('\n=== specification %s ===\n%s\n', spec.key, formula);

    specRows = cell(numel(featNames), 1);

    for k = 1:numel(featNames)

        fname = featNames{k};

        % Complete cases first, then scale. Scaling on the rows that actually
        % enter the model is what makes a coefficient exactly "per within
        % participant standard deviation of the analysed data" rather than per
        % standard deviation of a slightly different set.
        keep = isfinite(T.(fname)) & isfinite(T.(L.model.response)) & ...
               ~isundefined(T.(L.model.condition));
        for c = 1:numel(spec.covariates)
            keep = keep & isfinite(T.(spec.covariates{c}));
        end

        if ~any(keep)
            r = fit_feature_lmm();
            r.Feature = string(fname);
            r.Spec    = string(spec.key);
            r.Formula = string(formula);
            r.Message = "no complete cases for this feature";
            specRows{k} = r;
            continue
        end

        W = T(keep, :);

        W.EEGfeat = within_subject_scale(W.(fname), W.(L.model.subject), ...
            spec.featureMode, L.model.minTrials);

        for c = 1:numel(spec.covariates)
            cv = spec.covariates{c};
            W.(cv) = within_subject_scale(W.(cv), W.(L.model.subject), ...
                spec.covariateMode, L.model.minTrials);
        end

        r = fit_feature_lmm(W, formula, spec, L);
        r.Feature = string(fname);
        specRows{k} = r;

        fprintf('  %-14s N %4d  b %+7.4f  SE %6.4f  p %7.4f  [%+6.3f %+6.3f]%s\n', ...
            fname, r.N, r.Estimate, r.SE, r.pValue, r.Lower, r.Upper, ...
            iff(r.Converged, '', '   FIT FAILED'));
    end

    R = vertcat(specRows{:});
    R.q = bh_fdr(R.pValue, L.stats.fdrQ);
    allRows{end+1} = R; %#ok<AGROW>
end

results = struct();
results.all = vertcat(allRows{:});
results.all = movevars(results.all, {'Feature', 'Spec'}, 'Before', 1);

isPrimary           = results.all.Spec == string(L.primarySpec);
results.primary     = sortrows(results.all(isPrimary, :), 'pValue');
results.sensitivity = results.all(~isPrimary, :);

% ---- summary -----------------------------------------------------------
P  = results.primary;
ok = P.Converged;

S = struct();
S.spec          = L.primarySpec;
S.nFeatures     = height(P);
S.nConverged    = nnz(ok);
S.minP          = min_or_nan(P.pValue(ok));
S.minQ          = min_or_nan(P.q(ok));
S.nSurvivingFDR = nnz(P.q(ok) < L.stats.fdrQ);
S.maxAbsCI      = max_or_nan(P.MaxAbsCI(ok));
S.medianN       = median(P.N(ok));
S.rangeN        = [min_or_nan(P.N(ok)) max_or_nan(P.N(ok))];
S.nSingular     = nnz(P.Singular(ok));

rs = results.all(results.all.Spec == "randslope", :);
if ~isempty(rs)
    S.randSlopeConverged = nnz(rs.Converged);
    S.randSlopeTotal     = height(rs);
end

results.summary = S;
results.L       = L;
results.nTrials = height(T);

end


% ----------------------------------------------------------------------------
function f = build_formula(L, spec)

terms = [{'1'}, {L.model.condition}, spec.covariates(:).', {'EEGfeat'}];
f = sprintf('%s ~ %s + %s', L.model.response, strjoin(terms, ' + '), spec.random);

end


% ----------------------------------------------------------------------------
function out = iff(c, a, b)

if c, out = a; else, out = b; end

end


% ----------------------------------------------------------------------------
function v = min_or_nan(x)

if isempty(x), v = NaN; else, v = min(x); end

end


% ----------------------------------------------------------------------------
function v = max_or_nan(x)

if isempty(x), v = NaN; else, v = max(x); end

end
