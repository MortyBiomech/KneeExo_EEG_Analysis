function [q, crit, nRej] = bh_fdr(p, alpha)
%BH_FDR  Benjamini and Hochberg step up adjusted p values.
%
%  q = BH_FDR(p) returns the adjusted p value for every entry of p, in the
%  input order. NaN entries stay NaN and are excluded from the family, so a
%  feature that could not be fitted does not inflate the correction.
%
%  [q, crit, nRej] = BH_FDR(p, alpha) also returns the largest p value that
%  is declared significant at level alpha (NaN when nothing is), and the
%  number of rejections.
%
%  Why this exists rather than mafdr. mafdr needs the Bioinformatics Toolbox,
%  which the rest of this analysis does not, and the Benjamini Hochberg values
%  quoted in the Figure 5 results paragraph were computed by hand. One tested
%  helper used everywhere removes both problems.
%
%  Definition, Benjamini and Hochberg 1995. With m tests and p sorted
%  ascending, q(i) = min over k >= i of min(1, m/k * p(k)). The running
%  minimum from the largest p downwards is what enforces monotonicity, so an
%  adjusted value is never smaller than the adjusted value below it.
%
%  Reference
%    Benjamini, Y. and Hochberg, Y. (1995). Controlling the false discovery
%    rate: a practical and powerful approach to multiple testing. Journal of
%    the Royal Statistical Society B, 57(1), 289 to 300.

if nargin < 2 || isempty(alpha)
    alpha = 0.05;
end

validateattributes(p, {'numeric'}, {'real'}, mfilename, 'p');

sz = size(p);
pv = p(:);

q = nan(size(pv));

ok = ~isnan(pv);
if ~any(ok)
    q = reshape(q, sz);
    crit = NaN;
    nRej = 0;
    return
end

if any(pv(ok) < 0 | pv(ok) > 1)
    error('bh_fdr:range', 'p values must lie in [0, 1].');
end

pOk = pv(ok);
m   = numel(pOk);

[ps, order] = sort(pOk, 'ascend');
ranks       = (1:m)';

adj = min(1, ps .* m ./ ranks);

% Running minimum from the top down enforces monotonicity.
for i = m-1:-1:1
    if adj(i) > adj(i+1)
        adj(i) = adj(i+1);
    end
end

qOk         = nan(m, 1);
qOk(order)  = adj;
q(ok)       = qOk;
q           = reshape(q, sz);

% Critical value and rejection count at the requested level.
below = find(ps <= ranks ./ m .* alpha, 1, 'last');
if isempty(below)
    crit = NaN;
    nRej = 0;
else
    crit = ps(below);
    nRej = below;
end

end
