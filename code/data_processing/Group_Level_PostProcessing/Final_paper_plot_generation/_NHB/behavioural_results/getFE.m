% Helper to get a specific fixed effect by name
function beta = getFE(lme, name)
    names = lme.CoefficientNames;
    fe    = fixedEffects(lme);
    idx   = strcmp(names, name);
    beta  = fe(idx);
end