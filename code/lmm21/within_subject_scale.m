function [xs, info] = within_subject_scale(x, g, mode, minN)
%WITHIN_SUBJECT_SCALE  Centre or z score a variable inside each participant.
%
%  xs = WITHIN_SUBJECT_SCALE(x, g, mode) returns x transformed inside each
%  level of the grouping vector g.
%    mode 'center'  xs = x - mean(x)          , unit unchanged
%    mode 'z'       xs = (x - mean(x)) / std(x), unit is within participant SD
%    mode 'raw'     xs = x                    , returned unchanged
%
%  xs = WITHIN_SUBJECT_SCALE(x, g, mode, minN) sets a participant to NaN when
%  they contribute fewer than minN finite observations. Default 5. A mean and
%  a standard deviation estimated from two or three trials are noise, and a
%  participant scaled that way contributes leverage out of all proportion to
%  the data behind it.
%
%  [xs, info] = ... returns a per participant table of n, mean, std and a
%  flag saying whether the participant was dropped and why.
%
%  Differences from the older withinSubjectZ and withinSubjectCenter helpers,
%  both of which are superseded by this one:
%
%    1. withinSubjectCenter wrote back into the same column while
%       withinSubjectZ created a new one with a _z suffix. Running both in one
%       session therefore destroyed the raw column silently. This function
%       never touches a table, so the caller decides where the result goes.
%    2. withinSubjectZ mean centred when the standard deviation was zero,
%       which returns a column of zeros and no warning. A constant predictor
%       carries no information, so here the participant is set to NaN and
%       recorded in info.
%    3. Neither helper had a minimum count guard.
%    4. Both required g to be categorical. Here any grouping type works.

if nargin < 3 || isempty(mode)
    mode = 'z';
end
if nargin < 4 || isempty(minN)
    minN = 5;
end

mode = lower(char(mode));
if ~ismember(mode, {'raw', 'center', 'z'})
    error('within_subject_scale:mode', ...
        'mode must be raw, center or z, got %s', mode);
end

x = double(x(:));
if numel(g) ~= numel(x)
    error('within_subject_scale:size', ...
        'x has %d elements and g has %d.', numel(x), numel(g));
end

if strcmp(mode, 'raw')
    xs = x;
    if nargout > 1
        info = table();
    end
    return
end

% findgroups accepts categorical, numeric, string and cellstr alike.
[gid, gKey] = findgroups(g(:));
nG = max(gid);

xs = nan(size(x));

n      = zeros(nG, 1);
mu     = nan(nG, 1);
sd     = nan(nG, 1);
dropped = false(nG, 1);
reason  = repmat({''}, nG, 1);

for i = 1:nG
    idx = (gid == i);
    xi  = x(idx);
    ok  = isfinite(xi);

    n(i) = sum(ok);

    if n(i) == 0
        dropped(i) = true;
        reason{i}  = 'no finite observations';
        continue
    end

    mu(i) = mean(xi(ok));
    sd(i) = std(xi(ok), 0);

    if n(i) < minN
        dropped(i) = true;
        reason{i}  = sprintf('fewer than %d observations', minN);
        continue
    end

    switch mode
        case 'center'
            xs(idx) = xi - mu(i);

        case 'z'
            if ~isfinite(sd(i)) || sd(i) <= 0
                dropped(i) = true;
                reason{i}  = 'zero variance within participant';
                continue
            end
            xs(idx) = (xi - mu(i)) ./ sd(i);
    end
end

% Non finite inputs stay non finite whatever the group did.
xs(~isfinite(x)) = NaN;

if nargout > 1
    info = table(gKey, n, mu, sd, dropped, reason, 'VariableNames', ...
        {'Group', 'N', 'Mean', 'SD', 'Dropped', 'Reason'});
end

end
