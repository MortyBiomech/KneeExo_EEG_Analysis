function b = getCoefEitherOrder(lme, a, bname)
% a = eeg feature name (string/char), bname = 'Pressure_cat_3' etc.

cn = string(lme.Coefficients.Name);

cand1 = a + ":" + bname;
cand2 = bname + ":" + a;

ix = find(cn == cand1 | cn == cand2);

if isempty(ix)
    % fallback: find the unique term that contains both tokens and a colon
    ix = find(contains(cn, a) & contains(cn, bname) & contains(cn, ":"));
end

if numel(ix) ~= 1
    error('Could not uniquely identify coefficient for %s and %s. Matches=%d', a, bname, numel(ix));
end

b = lme.Coefficients.Estimate(ix);
end