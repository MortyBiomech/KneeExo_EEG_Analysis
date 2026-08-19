function h = violinPlot(data, opts)
%VIOLINPLOT  Violin plots (kernel-density trace + box plot) for grouped data.
%
%   violinPlot(D) plots one violin per group. D may be:
%       - a cell array of numeric vectors, one per group (groups may differ
%         in length), or
%       - a numeric matrix, in which case each COLUMN is one group.
%
%   h = violinPlot(...) returns a struct of graphics handles.
%
%   Name-value options
%   ------------------
%   'Labels'        string array of x tick labels        (default "Class k")
%   'Width'         max half-width of a violin, in x units      (default 0.35)
%   'Bandwidth'     KDE bandwidth: scalar, per-group vector, or []
%                   for Silverman's rule of thumb                  (default [])
%   'Normalization' "width" | "area" | "count"               (default "width")
%                     width -> every violin has the same max width
%                     area  -> widths are true densities on a common scale
%                     count -> width also reflects the group's n
%   'Clip'          restrict the density trace to [min,max] of the observed
%                   data instead of letting the kernel tails run past it
%                                                              (default true)
%   'ShowData'      overlay the raw observations                (default true)
%   'ShowBox'       overlay median / IQR / 1.5*IQR whiskers      (default true)
%   'Jitter'        horizontal spread of raw points, as a fraction of the
%                   local violin half-width                       (default 0.5)
%   'Colors'        nGroups-by-3 RGB matrix                    (default lines)
%   'Alpha'         face transparency of the violin              (default 0.35)
%   'NPoints'       number of points in the density grid          (default 256)
%   'Parent'        target axes                                  (default gca)
%
%   Example
%   -------
%       A = randn(80,1);  B = 1.5 + 0.6*randn(60,1);  C = [randn(40,1); 4+randn(40,1)];
%       violinPlot({A,B,C}, 'Labels', ["Control","Assisted","Resisted"]);
%
%   If your data live in a long-format vector X with a grouping variable G:
%       D = splitapply(@(v){v}, X, findgroups(G));
%
%   No toolboxes required: the Gaussian KDE and the quantiles are computed
%   locally, so this runs on base MATLAB (R2019b or later, for the
%   arguments block).
%
%   References
%     Hintze & Nelson (1998), Am. Stat. 52(2):181-184.
%     Silverman (1986), Density Estimation for Statistics and Data Analysis,
%       Chapman & Hall, eq. 3.31 (rule-of-thumb bandwidth).

arguments
    data
    opts.Labels string = string.empty
    opts.Width (1,1) double {mustBePositive} = 0.35
    opts.Bandwidth double = []
    opts.Normalization (1,1) string ...
        {mustBeMember(opts.Normalization,["width","area","count"])} = "width"
    opts.Clip (1,1) logical = true
    opts.ShowData (1,1) logical = true
    opts.ShowBox (1,1) logical = true
    opts.Jitter (1,1) double {mustBeNonnegative} = 0.5
    opts.Colors double = []
    opts.Alpha (1,1) double = 0.35
    opts.NPoints (1,1) double = 256
    opts.Parent = []
end

% ---------------------------------------------------------------- input ---
if isnumeric(data)
    if isvector(data)
        data = {data(:)};
    else
        data = num2cell(data, 1);          % each column is a group
    end
elseif ~iscell(data)
    error('violinPlot:badInput', ...
          'DATA must be a numeric matrix or a cell array of numeric vectors.');
end
nG = numel(data);

for k = 1:nG
    v = data{k}(:);
    data{k} = double(v(isfinite(v)));      % drop NaN / Inf
end

labels = opts.Labels;
if isempty(labels)
    labels = "Class " + string(1:nG);
end

col = opts.Colors;
if isempty(col)
    col = lines(nG);
elseif size(col,1) < nG
    col = repmat(col, ceil(nG/size(col,1)), 1);
end

bwIn = opts.Bandwidth;
if isscalar(bwIn), bwIn = repmat(bwIn, 1, nG); end

ax = opts.Parent;
if isempty(ax), ax = gca; end
wasHeld = ishold(ax);
hold(ax, 'on');

% ------------------------------------------- pass 1: estimate densities ---
grid = cell(1,nG);
dens = cell(1,nG);
nObs = zeros(1,nG);

for k = 1:nG
    x = data{k};
    nObs(k) = numel(x);
    if nObs(k) < 2
        grid{k} = []; dens{k} = [];
        continue
    end

    if isempty(bwIn), bw = localBandwidth(x); else, bw = bwIn(k); end

    lo = min(x); hi = max(x);
    if hi - lo < eps(max(abs([lo hi]),1))   % all values identical
        lo = lo - 3*bw;  hi = hi + 3*bw;
    elseif ~opts.Clip
        lo = lo - 3*bw;  hi = hi + 3*bw;
    end

    gy = linspace(lo, hi, opts.NPoints).';
    z  = (gy - x.') ./ bw;                              % NPoints x n
    f  = sum(exp(-0.5*z.^2), 2) ./ (nObs(k)*bw*sqrt(2*pi));

    grid{k} = gy;
    dens{k} = f;
end

% ------------------------------------------------ common width scaling ---
switch opts.Normalization
    case "width"
        scale = cellfun(@(f) maxOr1(f), dens);          % per-group max
    case "area"
        gmax  = max(cellfun(@(f) maxOr1(f), dens));
        scale = repmat(gmax, 1, nG);
    case "count"
        gmax  = max(cellfun(@(f) maxOr1(f), dens));
        scale = gmax .* max(nObs) ./ max(nObs, 1);
end

% --------------------------------------------------------- pass 2: draw ---
h = struct('violin', gobjects(1,nG), 'box', gobjects(1,nG), ...
           'median', gobjects(1,nG), 'points', gobjects(1,nG), 'axes', ax);

for k = 1:nG
    x = data{k};
    if isempty(x), continue, end

    if isempty(dens{k})                                  % n < 2: just a dot
        h.points(k) = plot(ax, repmat(k,size(x)), x, 'o', ...
            'MarkerFaceColor', col(k,:), 'MarkerEdgeColor', 'none');
        continue
    end

    gy = grid{k};
    hw = opts.Width .* dens{k} ./ scale(k);              % half-width profile

    h.violin(k) = patch(ax, [k - hw; flipud(k + hw)], [gy; flipud(gy)], ...
        col(k,:), 'FaceAlpha', opts.Alpha, ...
        'EdgeColor', col(k,:)*0.6, 'LineWidth', 1);

    if opts.ShowData
        hwAt = interp1(gy, hw, x, 'linear', 'extrap');
        xj   = k + (rand(size(x)) - 0.5) .* 2 .* hwAt .* opts.Jitter;
        h.points(k) = plot(ax, xj, x, 'o', 'MarkerSize', 3, ...
            'MarkerFaceColor', col(k,:)*0.7, 'MarkerEdgeColor', 'none');
    end

    if opts.ShowBox
        q1 = localQuantile(x, 0.25);
        q2 = median(x);
        q3 = localQuantile(x, 0.75);
        iqrv = q3 - q1;
        wLo = min(x(x >= q1 - 1.5*iqrv));
        wHi = max(x(x <= q3 + 1.5*iqrv));

        plot(ax, [k k], [wLo wHi], '-', 'Color', [0.15 0.15 0.15], 'LineWidth', 1);
        h.box(k) = plot(ax, [k k], [q1 q3], '-', ...
            'Color', [0.15 0.15 0.15], 'LineWidth', 5);
        h.median(k) = plot(ax, k, q2, 'o', 'MarkerSize', 5, ...
            'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'none');
    end
end

% ---------------------------------------------------------------- axes ---
set(ax, 'XTick', 1:nG, 'XTickLabel', labels, 'XLim', [0.5, nG+0.5], ...
        'TickDir', 'out', 'Box', 'off');
if ~wasHeld, hold(ax, 'off'); end
if nargout == 0, clear h; end
end

% =========================================================================
function bw = localBandwidth(x)
% Silverman's rule of thumb, robustified with the IQR (Silverman 1986, 3.31).
n   = numel(x);
sig = min(std(x), (localQuantile(x,0.75) - localQuantile(x,0.25))/1.349);
if ~isfinite(sig) || sig <= 0
    sig = std(x);
end
bw = 0.9 * sig * n^(-1/5);
if ~isfinite(bw) || bw <= 0
    bw = max(eps, 0.01*max(abs(x)));
end
end

% =========================================================================
function q = localQuantile(x, p)
% Linear interpolation of the empirical CDF at midpoints, matching the
% convention used by MATLAB's QUANTILE (Statistics Toolbox).
xs = sort(x(:));
n  = numel(xs);
if n == 1
    q = repmat(xs, size(p));
    return
end
pos = ((1:n).' - 0.5) / n;
q   = interp1(pos, xs, p(:), 'linear');
q(p(:) < pos(1))   = xs(1);
q(p(:) > pos(end)) = xs(end);
q = reshape(q, size(p));
end

% =========================================================================
function m = maxOr1(f)
m = max(f);
if isempty(m) || ~isfinite(m) || m <= 0, m = 1; end
end