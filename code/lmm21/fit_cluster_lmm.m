function [row, bandRows] = fit_cluster_lmm(tbl, formula, bandVars, cluster, spec, L)
%FIT_CLUSTER_LMM  Does one cortical cluster contribute to the rating?
%
%   [ROW, BANDROWS] = FIT_CLUSTER_LMM(TBL, FORMULA, BANDVARS, CLUSTER, SPEC, L)
%   fits FORMULA, which carries all of this cluster's band-power predictors at
%   once, and tests them jointly.
%
%   ROW = FIT_CLUSTER_LMM() returns the empty template.
%
%   ROW        one row: the joint test for the cluster
%   BANDROWS   one row per band: the partial coefficient of that band inside
%              the joint model, adjusted for the other bands
%
%   WHY A JOINT TEST. Theta, alpha and beta from the same independent component
%   are correlated through 1/f structure and spectral leakage. That inflates
%   each coefficient's standard error while leaving a joint test unaffected, so
%   a block of correlated predictors is exactly what a joint test is for. It
%   also matches the question the manuscript asks, which is about regions
%   rather than about individual band-power features, and it is agnostic about
%   the sign pattern across bands.
%
%   WHAT IT REPLACES. Testing the three bands one at a time and correcting.
%   That has little power against an effect spread across bands, and it invites
%   the temptation to combine the bands with signs chosen after seeing the
%   coefficients, which is what the earlier EEGIndex did and is not defensible.
%
%   WHAT IT COSTS. The BANDROWS coefficients are partial effects, each adjusted
%   for the other two bands, so their intervals are wider than the single
%   feature ones. They are therefore NOT the right source for the exclusion
%   bound; FIT_LMM21_MODELS takes that from the single-feature fits, where the
%   coefficient is a total effect. Keeping the two apart is the point of the
%   design: the joint test carries the claim, the single-feature intervals
%   carry the precision statement.
%
%   The test is a Wald test on the joint contrast, with Satterthwaite
%   denominator degrees of freedom, the same machinery FIT_FEATURE_LMM uses for
%   one coefficient.
%
%   See also FIT_FEATURE_LMM, FIT_LMM21_MODELS, BH_FDR.
%
%   Part of the KneeExo-EEG analysis code.

row      = empty_row();
bandRows = empty_band_rows();

if nargin == 0
    return
end

row.Cluster = string(cluster);
row.Spec    = string(spec.key);
row.Formula = string(formula);
row.nBands  = numel(bandVars);

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
W.(L.model.subject) = removecats(W.(L.model.subject));

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
    elseif isnumeric(v)
        vf = v(isfinite(v));
        if numel(vf) < 2 || std(vf) <= 0
            row.Message = sprintf('%s is constant in this subset', name);
            return
        end
    end
end

lastwarn('');

try
    lme = fitlme(W, formula, 'FitMethod', L.stats.fitMethod);
catch ME
    row.Message = string(ME.message);
    return
end

[wmsg, ~] = lastwarn;

names = lme.Coefficients.Name;
ix = nan(1, numel(bandVars));
for b = 1:numel(bandVars)
    hit = find(strcmp(names, bandVars{b}), 1);
    if isempty(hit)
        row.Message = sprintf('%s is not among the coefficients: %s', ...
            bandVars{b}, strjoin(names.', ', '));
        return
    end
    ix(b) = hit;
end

row.Converged = true;

% ---- the joint test ----------------------------------------------------
% One row of H per band, each selecting that band's coefficient, tested
% against a vector of zeros. This asks whether the cluster's band power adds
% anything at all, in any combination of bands.
H = zeros(numel(bandVars), numel(names));
for b = 1:numel(bandVars)
    H(b, ix(b)) = 1;
end

try
    [pv, F, df1, df2] = coefTest(lme, H, zeros(numel(bandVars), 1), ...
        'DFMethod', L.stats.dfMethod);
    row.pValue = pv;
    row.FStat  = F;
    row.DF1    = df1;
    row.DF2    = df2;
catch ME
    try
        [pv, F, df1, df2] = coefTest(lme, H, zeros(numel(bandVars), 1));
        row.pValue = pv;
        row.FStat  = F;
        row.DF1    = df1;
        row.DF2    = df2;
        row.Message = string(['satterthwaite failed, residual DF used: ' ME.message]);
    catch ME2
        row.Converged = false;
        row.Message = string(ME2.message);
        return
    end
end

% ---- the partial coefficients, for description only ---------------------
try
    CI = coefCI(lme, 'DFMethod', L.stats.dfMethod, 'Alpha', L.stats.alpha);
catch
    CI = coefCI(lme, 'Alpha', L.stats.alpha);
end

nB = numel(bandVars);
bandRows = table( ...
    repmat(string(cluster), nB, 1), ...
    repmat(string(spec.key), nB, 1), ...
    string(bandVars(:)), ...
    lme.Coefficients.Estimate(ix(:)), ...
    lme.Coefficients.SE(ix(:)), ...
    CI(ix(:), 1), ...
    CI(ix(:), 2), ...
    repmat(row.N, nB, 1), ...
    'VariableNames', {'Cluster', 'Spec', 'Band', 'Estimate', 'SE', ...
    'Lower', 'Upper', 'N'});

row.MaxAbsPartialCI = max(abs([bandRows.Lower; bandRows.Upper]));

try
    [psi, mse] = covarianceParameters(lme);
    row.SubjectSD  = sqrt(psi{1}(1, 1));
    row.ResidualSD = sqrt(mse);
    row.Singular   = row.SubjectSD < 1e-6 * row.ResidualSD;
catch
    row.SubjectSD  = NaN;
    row.ResidualSD = NaN;
end

if strlength(row.Message) == 0
    row.Message = string(wmsg);
end

end


% ----------------------------------------------------------------------------
function row = empty_row()

row = table(string(""), string(""), string(""), false, 0, 0, 0, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, false, string(""), ...
    'VariableNames', {'Cluster', 'Spec', 'Formula', 'Converged', 'N', ...
    'nSubjects', 'nBands', 'FStat', 'DF1', 'DF2', 'pValue', ...
    'MaxAbsPartialCI', 'SubjectSD', 'ResidualSD', 'Singular', 'Message'});

end


% ----------------------------------------------------------------------------
function rows = empty_band_rows()
%EMPTY_BAND_ROWS  Zero rows, not one row of NaNs.
%
%  A cluster whose model failed contributes no band coefficients. Returning a
%  placeholder row instead would put a line of NaNs into the band table and,
%  worse, into MaxAbsPartialCI.

rows = table('Size', [0 8], ...
    'VariableTypes', {'string', 'string', 'string', 'double', 'double', ...
                      'double', 'double', 'double'}, ...
    'VariableNames', {'Cluster', 'Spec', 'Band', 'Estimate', 'SE', ...
    'Lower', 'Upper', 'N'});

end


% ----------------------------------------------------------------------------
function vars = model_variables(formula, tbl)

f = char(formula);
f = regexprep(f, '[~+*:|()]', ' ');
tok = regexp(f, '[A-Za-z]\w*', 'match');
vars = intersect(unique(tok), tbl.Properties.VariableNames, 'stable');

end