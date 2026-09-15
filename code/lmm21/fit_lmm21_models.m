function results = fit_lmm21_models(T, L)
%FIT_LMM21_MODELS  Does any cortical cluster contribute to perceived difficulty?
%
%   RESULTS = FIT_LMM21_MODELS(T, L) runs two passes over the same data, which
%   answer two different questions and must not be confused with each other.
%
%   THE TEST, one model per cluster, all three of its bands entered together:
%
%     Score ~ 1 + Pressure_ord + EffortIndex_w + Error_w + Error_b + Trial_z
%                + EEG_theta + EEG_alpha + EEG_beta + (1 | Subject_cat)
%
%   with a joint Wald test on the three band coefficients. Seven tests, one per
%   cluster, corrected with Benjamini and Hochberg across the seven. This is
%   the inferential claim: no cluster contributes to the rating beyond imposed
%   pressure, effort, tracking error and trial number.
%
%   THE BOUND, one model per feature, the feature alone:
%
%     Score ~ 1 + ... + EEGfeat + (1 | Subject_cat)
%
%   Twenty-one fits, reported as estimates and confidence intervals with NO p
%   and NO q attached. These are the precision statement the Discussion needs,
%   not decisions. The coefficient here is a total effect, whereas the band
%   coefficients inside a joint model are partial effects adjusted for the
%   other two bands and therefore have wider intervals. "How much could left
%   M1 alpha matter" is naturally a total, which is why the bound comes from
%   this pass and the test comes from the other one.
%
%   WHY NOT 21 TESTS. Twenty-one marginal tests ask whether any single feature
%   is detectable on its own, which has little power against an effect spread
%   across the bands of a region, and the bands of one component are correlated
%   through 1/f structure and spectral leakage anyway. The cluster-level
%   question is also the one the manuscript actually asks.
%
%   WHY NOT ONE MODEL WITH ALL 21. Only three participants contribute a
%   component to all seven clusters, so that model would run on three people.
%   The per-cluster structure is forced by the clustering, not chosen.
%
%   RESULTS fields:
%     cluster       the seven joint tests, with q. THE TEST
%     clusterBands  the partial band coefficients inside those models
%     feature       the 21 single-feature fits, estimates and intervals. THE BOUND
%     all           every specification of the cluster tests
%     summary       the numbers the manuscript needs
%
%   There is no model comparison anywhere in this file, by design.
%
%   See also FIT_CLUSTER_LMM, FIT_FEATURE_LMM, LMM21_DERIVE_TERMS, BH_FDR.
%
%   Part of the KneeExo-EEG analysis code.

arguments
    T table
    L (1,1) struct
end

[featNames, meta] = lmm21_feature_names(L);

missing = featNames(~ismember(featNames, T.Properties.VariableNames));
if ~isempty(missing)
    error('fit_lmm21_models:MissingFeatures', ...
        'The merged table has no column for %s.', strjoin(missing, ', '));
end

% The predictor names inside a cluster model. Constant across clusters, so the
% formula string is constant too and the coefficients are found by exact name.
bandVars = cellfun(@(b) ['EEG_' b], L.bandNames, 'UniformOutput', false);

clusterRows = {};
bandRowsAll = {};
featureRows = {};

for s = 1:numel(L.specs)

    spec    = L.specs(s);
    condVar = condition_variable(L, spec);

    % ---- the test, per cluster -----------------------------------------
    fprintf('\n=== %s : cluster tests ===\n', spec.key);
    printed = false;
    theseClusters = cell(size(L.clusters, 1), 1);

    for c = 1:size(L.clusters, 1)

        clusterName = L.clusters{c, 1};
        cols = meta.Feature(meta.Cluster == string(clusterName));
        cols = cellstr(cols);

        keep = base_mask(T, L, spec, condVar);
        for b = 1:numel(cols)
            keep = keep & isfinite(T.(cols{b}));
        end

        if ~any(keep)
            r = fit_cluster_lmm();
            r.Cluster = string(clusterName);
            r.Spec    = string(spec.key);
            r.Message = "no complete cases for this cluster";
            theseClusters{c} = r;
            continue
        end

        W = T(keep, :);
        [W, terms] = lmm21_derive_terms(W, L);

        for b = 1:numel(cols)
            W.(bandVars{b}) = within_subject_scale(W.(cols{b}), ...
                W.(L.model.subject), spec.featureMode, L.model.minTrials);
        end

        formula = build_formula(L, spec, terms, condVar, bandVars);
        if ~printed
            fprintf('%s\n', formula);
            printed = true;
        end

        [r, br] = fit_cluster_lmm(W, formula, bandVars, clusterName, spec, L);
        theseClusters{c} = r;
        bandRowsAll{end+1} = br; %#ok<AGROW>

        fprintf('  %-24s N %4d  F(%d,%.0f) %7.3f  p %7.4f%s\n', ...
            clusterName, r.N, r.DF1, r.DF2, r.FStat, r.pValue, ...
            iff(r.Converged, '', '   FIT FAILED'));
    end

    C = vertcat(theseClusters{:});
    C.q = bh_fdr(C.pValue, L.stats.fdrQ);
    clusterRows{end+1} = C; %#ok<AGROW>

    % ---- the bound, per feature ----------------------------------------
    % Estimates and intervals only. No q is computed here, deliberately: the
    % family is the seven clusters, and a q column beside these rows would
    % invite the reader to treat them as 21 tests.
    fprintf('\n=== %s : single-feature intervals (no test) ===\n', spec.key);
    theseFeatures = cell(numel(featNames), 1);

    for k = 1:numel(featNames)

        fname = featNames{k};

        keep = base_mask(T, L, spec, condVar) & isfinite(T.(fname));

        if ~any(keep)
            r = fit_feature_lmm();
            r.Feature = string(fname);
            r.Spec    = string(spec.key);
            r.Message = "no complete cases for this feature";
            theseFeatures{k} = r;
            continue
        end

        W = T(keep, :);
        [W, terms] = lmm21_derive_terms(W, L);
        W.EEGfeat = within_subject_scale(W.(fname), W.(L.model.subject), ...
            spec.featureMode, L.model.minTrials);

        formula = build_formula(L, spec, terms, condVar, {'EEGfeat'});
        r = fit_feature_lmm(W, formula, spec, L);
        r.Feature = string(fname);
        theseFeatures{k} = r;

        fprintf('  %-14s N %4d  b %+7.4f  [%+6.3f %+6.3f]%s\n', ...
            fname, r.N, r.Estimate, r.Lower, r.Upper, ...
            iff(r.Converged, '', '   FIT FAILED'));
    end

    featureRows{end+1} = vertcat(theseFeatures{:}); %#ok<AGROW>
end

% ---- assemble ----------------------------------------------------------
results = struct();

allClusters = vertcat(clusterRows{:});
allFeatures = vertcat(featureRows{:});

% The p value column stays on the feature rows for the record, but it is not
% corrected and is not what the paper reports. Renamed so that nobody lifts it
% into a table by accident.
allFeatures.Properties.VariableNames{strcmp( ...
    allFeatures.Properties.VariableNames, 'pValue')} = 'pValue_uncorrected_notReported';

results.all          = allClusters;
results.cluster      = sortrows(allClusters(allClusters.Spec == string(L.primarySpec), :), 'pValue');
results.clusterBands = vertcat(bandRowsAll{:});
results.featureAll   = allFeatures;
results.feature      = allFeatures(allFeatures.Spec == string(L.primarySpec), :);
results.sensitivity  = allClusters(allClusters.Spec ~= string(L.primarySpec), :);

% ---- summary -----------------------------------------------------------
C  = results.cluster;
ok = C.Converged;

S = struct();
S.spec          = L.primarySpec;
S.nClusters     = height(C);
S.nConverged    = nnz(ok);
S.minP          = min_or_nan(C.pValue(ok));
S.minQ          = min_or_nan(C.q(ok));
S.nSurvivingFDR = nnz(C.q(ok) < L.stats.fdrQ);
S.medianN       = median(C.N(ok));
S.rangeN        = [min_or_nan(C.N(ok)) max_or_nan(C.N(ok))];
S.nSingular     = nnz(C.Singular(ok));

% The bound: the widest single-feature interval, from the z scored
% specification so that it is in rating points per within-participant standard
% deviation and can be set against the 5.20 rating point demand effect.
Fb = allFeatures(allFeatures.Spec == string(L.boundSpec) & allFeatures.Converged, :);
S.boundSpec = L.boundSpec;
S.maxAbsCI  = max_or_nan(Fb.MaxAbsCI);

Fp = allFeatures(allFeatures.Spec == string(L.primarySpec) & allFeatures.Converged, :);
S.maxAbsCI_dB = max_or_nan(Fp.MaxAbsCI);
S.nFeatures   = height(Fp);

rs = allClusters(allClusters.Spec == "randslope", :);
if ~isempty(rs)
    S.randSlopeConverged = nnz(rs.Converged);
    S.randSlopeTotal     = height(rs);
end

results.summary = S;
results.L       = L;
results.nTrials = height(T);

end


% ----------------------------------------------------------------------------
function keep = base_mask(T, L, spec, condVar)
%BASE_MASK  Complete cases on everything except the EEG predictors.

keep = isfinite(T.(L.model.response));

if iscategorical(T.(condVar))
    keep = keep & ~isundefined(T.(condVar));
else
    keep = keep & isfinite(T.(condVar));
end

if ~strcmp(spec.mediatorMode, 'none')
    for m = 1:numel(L.model.mediators)
        keep = keep & isfinite(T.(L.model.mediators{m}));
    end
end

if spec.trialTerm
    keep = keep & isfinite(T.(L.model.trial));
end

end


% ----------------------------------------------------------------------------
function v = condition_variable(L, spec)

switch spec.condition
    case 'ordinal',     v = L.model.ordinal;
    case 'categorical', v = L.model.categorical;
    otherwise
        error('fit_lmm21_models:Condition', ...
            'spec.condition must be ordinal or categorical, got %s', spec.condition);
end

end


% ----------------------------------------------------------------------------
function f = build_formula(L, spec, terms, condVar, eegVars)
%BUILD_FORMULA  The mediation model's fixed effects, plus the EEG predictors.
%
%  eegVars is one name for a single-feature fit and three for a cluster fit.
%  A between term that LMM21_DERIVE_TERMS found to have no variance is not in
%  terms.between, so it never reaches the formula.

fixed = {'1', condVar};

switch spec.mediatorMode
    case 'split'
        fixed = [fixed, terms.within, terms.between];
    case 'raw'
        fixed = [fixed, L.model.mediators];
    case 'none'
        % nothing
    otherwise
        error('fit_lmm21_models:MediatorMode', ...
            'spec.mediatorMode must be split, raw or none, got %s', ...
            spec.mediatorMode);
end

if spec.trialTerm
    fixed = [fixed, terms.trial];
end

fixed = [fixed, eegVars];

f = sprintf('%s ~ %s + %s', L.model.response, strjoin(fixed, ' + '), spec.random);

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