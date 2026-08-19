function printRsqIfAvailable(lme)
% Print marginal/conditional R^2 if MATLAB version provides it.
    try
        rsq = lme.Rsquared;
        if isstruct(rsq)
            fprintf('R^2 (marginal)   : %.4f\n', rsq.Marginal);
            fprintf('R^2 (conditional): %.4f\n', rsq.Conditional);
        else
            disp(rsq);
        end
    catch
        % Not available in some versions; do nothing
    end
end