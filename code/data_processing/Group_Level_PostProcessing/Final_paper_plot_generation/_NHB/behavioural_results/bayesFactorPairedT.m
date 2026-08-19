function [BF01, BF10] = bayesFactorPairedT(d, r)

    % JZS Bayes factor for a paired / one-sample t-test.
    % Rouder, Speckman, Sun, Morey & Iverson (2009), Psychon Bull Rev 16:225-237.
    %
    % Complements the TOST in tost_paired.m: TOST asks whether the effect is
    % small enough to call equivalent to a pre-set bound, the Bayes factor asks
    % how much the data favour the null over a default alternative without
    % needing a bound at all. They answer different questions and disagreeing
    % is informative, not a bug.
    %
    % Inputs:
    %   d - paired differences, one per subject
    %   r - Cauchy prior scale on effect size (default 0.707, the JZS default)
    %
    % Outputs:
    %   BF01 - evidence for the null relative to the alternative.
    %          >3 is usually read as moderate evidence for the null,
    %          >10 as strong. BF01 near 1 means the data are uninformative,
    %          which is NOT the same as evidence of no effect.
    %   BF10 - 1/BF01

    arguments
        d (:,1) double
        r (1,1) double {mustBePositive} = 0.707
    end

    d = d(~isnan(d));
    n = numel(d);
    if n < 3
        error('bayesFactorPairedT:TooFewPairs', 'Need at least 3 values, got %d.', n);
    end

    nu = n - 1;
    t  = mean(d) / (std(d) / sqrt(n));

    % Marginal likelihood under H0 (up to a constant that cancels)
    null = (1 + t^2/nu) ^ (-(nu+1)/2);

    % Marginal likelihood under H1, integrating g out against the
    % inverse-gamma(1/2, r^2/2) prior implied by the Cauchy on effect size
    integrand = @(g) (1 + n.*g).^(-0.5) ...
        .* (1 + t^2 ./ ((1 + n.*g) .* nu)).^(-(nu+1)/2) ...
        .* (r ./ sqrt(2*pi)) .* g.^(-1.5) .* exp(-r^2 ./ (2.*g));

    alt = integral(integrand, 0, Inf, 'AbsTol', 1e-12, 'RelTol', 1e-10);

    BF10 = alt / null;
    BF01 = 1 / BF10;

end
