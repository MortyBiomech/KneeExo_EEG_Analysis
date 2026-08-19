function lme = fitStableLME(tbl, fixedFormula, reStruct, fitMethod, subjectVar)
% Fit preferred mixed model; if it fails (singular fit, convergence), fallback to simpler RE.
    % Try preferred RE
    formula1 = sprintf('%s + %s', fixedFormula, reStruct);
    try
        lme = fitlme(tbl, formula1, 'FitMethod', fitMethod);
        return;
    catch ME1
        fprintf('Preferred RE failed: %s\nFalling back to random intercept only.\n', ME1.message);
    end

    % Fallback: random intercept only
    formula2 = sprintf('%s + (1|%s)', fixedFormula, subjectVar); % assumes column is named Subject
    % If user's subjectVar is not literally 'Subject', detect it:
    % We'll patch by finding any categorical column with same unique count as subjectVar was intended.
    % Best effort: use the first categorical column.
    subjCols = tbl.Properties.VariableNames(varfun(@iscategorical, tbl, 'OutputFormat','uniform'));
    if ~isempty(subjCols)
        formula2 = sprintf('%s + (1|%s)', fixedFormula, subjCols{1});
    end

    lme = fitlme(tbl, formula2, 'FitMethod', fitMethod);
end