function beta = getCoef(lme, name)
    fe = fixedEffects(lme);
    idx = strcmp(lme.CoefficientNames, name);

    if ~any(idx)
        error('Coefficient "%s" not found.', name);
    end

    beta = fe(idx);
end