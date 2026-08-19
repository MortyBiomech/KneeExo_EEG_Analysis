function tbl = withinSubjectCenter(tbl, subjectVar, varName)
% Mean-center varName within each subject (ignore NaNs).
    x = tbl.(varName);
    subj = tbl.(subjectVar);
    c = nan(size(x));

    cats = categories(subj);
    for i = 1:numel(cats)
        idx = subj == cats{i};
        xi = x(idx);
        mu = mean(xi, 'omitnan');
        c(idx) = xi - mu;
    end
    tbl.(varName) = c;
end