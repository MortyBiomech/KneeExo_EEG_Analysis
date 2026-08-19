function res = tost_paired(x, y, delta, alpha)

    % Two one-sided tests (TOST) for equivalence of two paired samples.
    % Lakens (2017), Soc Psychol Personal Sci 8(4):355-362.
    %
    % Equivalence is claimed only if BOTH one-sided tests reject, which is the
    % same as the (1-2*alpha) confidence interval of the mean difference lying
    % entirely inside (-delta, +delta).
    %
    % delta is a REQUIRED input and has no default on purpose. The equivalence
    % bound is the smallest effect still considered meaningful, and it must be
    % justified from the measurement or the task before the data are seen.
    % Choosing it afterwards, so that it happens to clear the observed interval,
    % turns an equivalence test into a foregone conclusion.
    %
    % Inputs:
    %   x, y  - paired observations, one row per subject (same length)
    %   delta - equivalence bound in the units of x and y, scalar > 0.
    %           Bounds are taken as symmetric, -delta to +delta.
    %   alpha - one-sided alpha for each test (default 0.05, giving a 90% CI)
    %
    % Output struct res:
    %   .meanDiff, .sd, .se, .n, .df
    %   .ci            - [lo hi], the (1-2*alpha) interval that TOST inspects
    %   .tLower/.pLower - test of H0: diff <= -delta
    %   .tUpper/.pUpper - test of H0: diff >= +delta
    %   .pTOST         - max(pLower, pUpper), the TOST p value
    %   .equivalent    - true if pTOST < alpha
    %   .pDiff         - two-sided paired t-test p, the ordinary difference test
    %   .dz            - Cohen's dz for the paired difference
    %   .minDelta      - the smallest symmetric bound that this data would
    %                    have declared equivalent, reported for transparency,
    %                    NOT to be adopted as delta after the fact

    arguments
        x     (:,1) double
        y     (:,1) double
        delta (1,1) double {mustBePositive}
        alpha (1,1) double {mustBePositive} = 0.05
    end

    if numel(x) ~= numel(y)
        error('tost_paired:LengthMismatch', ...
            'x and y must be the same length (paired); got %d and %d.', numel(x), numel(y));
    end

    d = x - y;
    d = d(~isnan(d));
    n = numel(d);
    if n < 3
        error('tost_paired:TooFewPairs', 'Need at least 3 complete pairs, got %d.', n);
    end

    df       = n - 1;
    meanDiff = mean(d);
    sd       = std(d);
    se       = sd / sqrt(n);

    % Two one-sided tests
    tLower = (meanDiff + delta) / se;    % H0: diff <= -delta
    pLower = 1 - tcdf(tLower, df);
    tUpper = (meanDiff - delta) / se;    % H0: diff >= +delta
    pUpper = tcdf(tUpper, df);

    pTOST = max(pLower, pUpper);

    tcrit = tinv(1 - alpha, df);
    ci    = [meanDiff - tcrit*se, meanDiff + tcrit*se];

    [~, pDiff] = ttest(d);

    res = struct( ...
        'n', n, 'df', df, 'meanDiff', meanDiff, 'sd', sd, 'se', se, ...
        'delta', delta, 'alpha', alpha, 'ci', ci, ...
        'tLower', tLower, 'pLower', pLower, ...
        'tUpper', tUpper, 'pUpper', pUpper, ...
        'pTOST', pTOST, 'equivalent', pTOST < alpha, ...
        'pDiff', pDiff, 'dz', meanDiff / sd, ...
        'minDelta', max(abs(ci)));

end
