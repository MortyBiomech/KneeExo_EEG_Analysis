function row = fit_feature_lmm(tbl, formula, spec, cfg)
%FIT_FEATURE_LMM  One feature, one model, one row of results.
%
%  row = FIT_FEATURE_LMM(tbl, formula, spec, cfg) fits formula to tbl and
%  returns a single row table describing the coefficient of the predictor
%  named EEGfeat.
%
%  The predictor always carries the same name, whatever feature is in it, so
%  the formula string is constant across the 21 fits and the coefficient is
%  located by an exact name match rather than by position or by a search that
%  could pick up an interaction term.
%
%  Inference. The coefficient is tested by a Wald test with Satterthwaite
%  denominator degrees of freedom, and the interval is computed the same way.
%  This replaces the earlier likelihood ratio and AIC comparison, which was a
%  convergence artifact: random slope models were fitting singular, the
%  reported dAIC was impossible, and the likelihood ratio test disagreed with
%  the Wald test by orders of magnitude.
%
%  No AIC or BIC is returned. Under REML those numbers are not comparable
%  across models with different fixed effects, and the whole point of moving
%  to a per coefficient test was to stop comparing models. Returning the
%  columns would invite the comparison back.
%
%  A failed fit is a result, not an exception. The Methods claim that random
%  slope models did not converge, and specification randslope exists to
%  produce the evidence for that sentence, so a failure is recorded with its
%  message rather than thrown.
%
%  See also RUN_LMM_21FEATURES, BH_FDR.

row = emptyRow();

% Called with no arguments this returns the empty template, which the caller
% uses to keep the results table rectangular when a feature has no data.
if nargin == 0
    return
end

row.Spec     = string(spec.key);
row.Formula  = string(formula);
row.FitMethod = string(spec.fitMethod);

% Complete cases, computed here so N and the participant count are exact
% rather than inferred from whatever fitlme decided to drop.
vars = modelVariables(formula, tbl);
ok = true(height(tbl), 1);
for i = 1:numel(vars)
    v = tbl.(vars{i});
    if isnumeric(v)
        ok = ok & isfinite(v);
    elseif iscategorical(v)
        ok = ok & ~isundefined(v);
    end
end

row.N         = nnz(ok);
row.nSubjects = numel(unique(tbl.(cfg.model.subject)(ok)));

if row.N < 30 || row.nSubjects < 3
    row.Converged = false;
    row.Message = sprintf('too few usable rows: N = %d over %d participants', ...
        row.N, row.nSubjects);
    return
end

W = tbl(ok, :);

% Drop participant levels that no longer occur. An unused categorical level
% makes the design matrix rank deficient, and fitlme's response to that is
% not always an error.
W.(cfg.model.subject) = removecats(W.(cfg.model.subject));

emptyLevel = countcats(W.(cfg.model.condition)) == 0;
if any(emptyLevel)
    cats = categories(W.(cfg.model.condition));
    row.Converged = false;
    row.Message = sprintf('pressure level %s has no rows in this subset', ...
        strjoin(cats(emptyLevel)', ', '));
    return
end

% Warnings are left on deliberately. A convergence warning during one of
% these fits is information, and lastwarn cannot capture a warning that has
% been switched off.
lastwarn('');

try
    lme = fitlme(W, formula, 'FitMethod', spec.fitMethod);
catch ME
    row.Converged = false;
    row.Message = string(ME.message);
    return
end

[wmsg, ~] = lastwarn;

names = lme.Coefficients.Name;
ix = find(strcmp(names, 'EEGfeat'), 1);

if isempty(ix)
    row.Converged = false;
    row.Message = sprintf('EEGfeat is not among the coefficients: %s', ...
        strjoin(names', ', '));
    return
end

row.Converged = true;
row.Estimate  = lme.Coefficients.Estimate(ix);
row.SE        = lme.Coefficients.SE(ix);
row.tStat     = row.Estimate / row.SE;

% Wald test with Satterthwaite denominator degrees of freedom.
H = zeros(1, numel(names));
H(ix) = 1;
try
    [p, ~, ~, df2] = coefTest(lme, H, 0, 'DFMethod', cfg.stats.dfMethod);
    row.pValue = p;
    row.DF     = df2;
catch ME
    % Satterthwaite can fail on a degenerate covariance. Fall back to the
    % residual denominator and say so rather than reporting nothing.
    row.pValue  = lme.Coefficients.pValue(ix);
    row.DF      = lme.Coefficients.DF(ix);
    row.Message = string(['satterthwaite failed, residual DF used: ' ME.message]);
end

row.pResidualDF = lme.Coefficients.pValue(ix);

try
    CI = coefCI(lme, 'DFMethod', cfg.stats.dfMethod, 'Alpha', cfg.stats.alpha);
catch
    CI = coefCI(lme, 'Alpha', cfg.stats.alpha);
end
row.Lower = CI(ix, 1);
row.Upper = CI(ix, 2);

% Largest absolute end of the interval. This is the quantity the Discussion
% quotes as the exclusion bound, so it is computed once here rather than read
% off a printed table.
row.MaxAbsCI = max(abs([row.Lower, row.Upper]));

% Variance components, for spotting a singular fit.
try
    [psi, mse] = covarianceParameters(lme);
    row.SubjectSD  = sqrt(psi{1}(1, 1));
    row.ResidualSD = sqrt(mse);
    row.Singular   = row.SubjectSD < 1e-6 * row.ResidualSD;
catch
    row.SubjectSD  = NaN;
    row.ResidualSD = NaN;
    row.Singular   = false;
end

row.LogLikelihood = lme.LogLikelihood;

if strlength(row.Message) == 0
    row.Message = string(wmsg);
end

end

% =========================================================================
function row = emptyRow()
row = table(string(""), string(""), string(""), string(""), ...
    false, 0, 0, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, false, NaN, ...
    'VariableNames', {'Feature', 'Spec', 'Formula', 'FitMethod', ...
    'Converged', 'N', 'nSubjects', 'Estimate', 'SE', 'tStat', 'DF', ...
    'pValue', 'pResidualDF', 'Lower', 'Upper', 'MaxAbsCI', ...
    'SubjectSD', 'Singular', 'ResidualSD'});
row.LogLikelihood = NaN;
row.Message = string("");
end

% -------------------------------------------------------------------------
function vars = modelVariables(formula, tbl)
%MODELVARIABLES  Names in tbl that the formula actually refers to.
f = char(formula);
f = regexprep(f, '[~+*:|()]', ' ');
tok = regexp(f, '[A-Za-z]\w*', 'match');
vars = intersect(unique(tok), tbl.Properties.VariableNames, 'stable');
end
