function tbl = withinSubjectZ(tbl, subjectVar, varName)
% Z-score varName within each subject (ignoring NaNs).
% Keeps NaNs as NaN (important for missing EEG in clusters).
    if ~ismember(varName, tbl.Properties.VariableNames)
        return;
    end
    x = tbl.(varName);
    if ~isnumeric(x)
        error('withinSubjectZ expects numeric variable: %s', varName);
    end

    subj = tbl.(subjectVar);
    z = nan(size(x));

    cats = categories(subj);
    for i = 1:numel(cats)
        idx = subj == cats{i};
        xi = x(idx);
        mu = mean(xi, 'omitnan');
        sd = std(xi, 0, 'omitnan');
        if sd == 0 || isnan(sd)
            % If constant within subject, just mean-center (or set to 0)
            z(idx) = xi - mu;
        else
            z(idx) = (xi - mu) ./ sd;
        end
    end
    zscored_varnName = [varName, '_z'];
    tbl.(zscored_varnName) = z;
end