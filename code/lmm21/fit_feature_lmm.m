function row = fit_feature_lmm(tbl, formula, spec, L)
%FIT_FEATURE_LMM  One feature, one specification, one row of results.
%
%   ROW = FIT_FEATURE_LMM(TBL, FORMULA, SPEC, L) fits FORMULA to TBL and returns
%   a one-row table describing the coefficient of the predictor named EEGfeat.
%
%   ROW = FIT_FEATURE_LMM() returns the empty template, so a caller can keep its
%   results table rectangular when a feature has no data at all.
%
%   The predictor always carries the same name whatever feature is in it, so the
%   formula string is constant across the 21 fits and the coefficient is found
%   by an exact name match rather than by position or by a search that could
%   pick up an interaction term.
%
%   INFERENCE. A Wald test on the coefficient, with Satterthwaite denominator
%   degrees of freedom, and an interval computed the same way. This replaces the
%   earlier likelihood ratio and AIC comparison, which was a convergence
%   artifact: the random slope models were fitting singular, the reported dAIC
%   was impossible, and the likelihood ratio disagreed with the Wald test by
%   orders of magnitude.
%
%   NO AIC OR BIC IS RETURNED. Under REML those numbers are not comparable
%   across models with different fixed effects, and the point of moving to a per
%   coefficient test was to stop comparing models. Returning the columns would
%   invite the comparison back.
%
%   A FAILED FIT IS A RESULT. The Methods claim that random slope models did not
%   converge, and specification randslope exists to produce the evidence, so a
%   failure is recorded with its message rather than thrown.
%
%   See also RUN_LMM21, BH_FDR.
%
%   Part of the KneeExo-EEG analysis code.

row = empty_row();

if nargin == 0
    return
end

row.Spec    = string(spec.key);
row.Formula = string(formula);

% Complete cases, computed here so N and the participant count are exact rather
% than inferred from whatever fitlme decided to drop.
vars = model_variables(formula, tbl);
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
row.nSubjects = numel(unique(tbl.(L.model.subject)(ok)));

if row.N < 30 || row.nSubjects < 3
    row.Message = sprintf('too few usable rows: N = %d over %d participants', ...
        row.N, row.nSubjects);
    return
end

W = tbl(ok, :);

% Drop participant levels that no longer occur. An unused categorical level
% makes the design matrix rank deficient, and fitlme's response to that is not
% always an error.
W.(L.model.subject) = removecats(W.(L.model.subject));

% A predictor that carries no information in this subset makes the design rank
% deficient, and fitlme's response to that is not always an error. Every
% predictor the formula names is checked rather than one named here, because
% the pressure coding is categorical in one specification and numeric in the
% others, and the mediation's between-participant terms come and go with the
% subset.
for i = 1:numel(vars)

    name = vars{i};
    if strcmp(name, L.model.response) || strcmp(name, L.model.subject)
        continue
    end
    v = W.(name);

    if iscategorical(v)
        n = countcats(v);
        if any(n == 0)
            names = categories(v);
            row.Message = sprintf('%s level %s has no rows in this subset', ...
                name, strjoin(names(n == 0).', ', '));
            return
        end
        if nnz(n > 0) < 2
            row.Message = sprintf('%s has only one level in this subset', name);
            return
        end

    elseif isnumeric(v)
        vf = v(isfinite(v));
        if numel(vf) < 2 || std(vf) <= 0
            row.Message = sprintf('%s is constant in this subset', name);
            return
        end
    end
end

% Warnings stay on deliberately. A convergence warning during one of these fits
% is information, and lastwarn cannot capture a warning that has been switched
% off.
lastwarn('');

try
    lme = fitlme(W, formula, 'FitMethod', L.stats.fitMethod);
catch ME
    row.Message = string(ME.message);
    return
end

[wmsg, ~] = lastwarn;

names = lme.Coefficients.Name;
ix = find(strcmp(names, 'EEGfeat'), 1);
if isempty(ix)
    row.Message = sprintf('EEGfeat is not among the coefficients: %s', ...
        strjoin(names.', ', '));
    return
end

row.Converged = true;
row.Estimate  = lme.Coefficients.Estimate(ix);
row.SE        = lme.Coefficients.SE(ix);
row.tStat     = row.Estimate / row.SE;

H = zeros(1, numel(names));
H(ix) = 1;
try
    [pv, ~, ~, df2] = coefTest(lme, H, 0, 'DFMethod', L.stats.dfMethod);
    row.pValue = pv;
    row.DF     = df2;
catch ME
    % Satterthwaite can fail on a degenerate covariance. Fall back to the
    % residual denominator and say so, rather than reporting nothing.
    row.pValue  = lme.Coefficients.pValue(ix);
    row.DF      = lme.Coefficients.DF(ix);
    row.Message = string(['satterthwaite failed, residual DF used: ' ME.message]);
end

row.pResidualDF = lme.Coefficients.pValue(ix);

try
    CI = coefCI(lme, 'DFMethod', L.stats.dfMethod, 'Alpha', L.stats.alpha);
catch
    CI = coefCI(lme, 'Alpha', L.stats.alpha);
end
row.Lower = CI(ix, 1);
row.Upper = CI(ix, 2);

% The larger end of the interval in absolute value. This is the quantity the
% Discussion quotes as the exclusion bound, so it is computed rather than read
% off a printed table.
row.MaxAbsCI = max(abs([row.Lower, row.Upper]));

try
    [psi, mse] = covarianceParameters(lme);
    row.SubjectSD  = sqrt(psi{1}(1, 1));
    row.ResidualSD = sqrt(mse);
    row.Singular   = row.SubjectSD < 1e-6 * row.ResidualSD;
catch
    row.SubjectSD  = NaN;
    row.ResidualSD = NaN;
end

row.LogLikelihood = lme.LogLikelihood;

if strlength(row.Message) == 0
    row.Message = string(wmsg);
end

end


% ----------------------------------------------------------------------------
function row = empty_row()
%EMPTY_ROW  The shape every result has, fitted or not.

row = table(string(""), string(""), string(""), false, 0, 0, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, false, NaN, string(""), ...
    'VariableNames', {'Feature', 'Spec', 'Formula', 'Converged', 'N', ...
    'nSubjects', 'Estimate', 'SE', 'tStat', 'DF', 'pValue', 'pResidualDF', ...
    'Lower', 'Upper', 'MaxAbsCI', 'SubjectSD', 'ResidualSD', 'Singular', ...
    'LogLikelihood', 'Message'});

end


% ----------------------------------------------------------------------------
function vars = model_variables(formula, tbl)
%MODEL_VARIABLES  The names in TBL that FORMULA actually refers to.

f = char(formula);
f = regexprep(f, '[~+*:|()]', ' ');
tok = regexp(f, '[A-Za-z]\w*', 'match');
vars = intersect(unique(tok), tbl.Properties.VariableNames, 'stable');

end