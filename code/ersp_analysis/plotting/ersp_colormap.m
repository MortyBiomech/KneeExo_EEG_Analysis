function cmap = ersp_colormap(n)
% ERSP_COLORMAP  Diverging blue-white-red colormap used for every ERSP figure.
%
%   CMAP = ERSP_COLORMAP()  returns a 256-by-3 colormap.
%   CMAP = ERSP_COLORMAP(N) returns an N-by-3 colormap.
%
% The map runs dark blue -> blue -> cyan -> near-white -> yellow -> red ->
% dark red, so that zero (no change from baseline) sits on the pale midpoint
% and power increases and decreases are separated by hue rather than by
% brightness alone.
%
% Provenance
% ----------
% The published figures used a colormap that had been captured from a figure
% and pasted into the source as a literal 256-by-3 matrix, duplicated across
% sixteen near-identical files (calldefinedcolormap.m ... calldefinedcolormap16.m,
% about 140 kB in total). Every live call site used the same one of those
% matrices; the rest were only reachable from commented-out code.
%
% That matrix is exactly piecewise-linear through the seven anchors below --
% reconstructing it by interpolation reproduces the original to 5e-7, far
% below one step of 24-bit colour. This function therefore renders exactly
% the published colours, and additionally works at any N.
%
% NOTE: the pale midpoint sits at index 125 of 256, not at 128. It is
% off-centre by design in the original and is kept off-centre here, so
% figures regenerated with this function match the published ones. Because
% of that, a symmetric colour limit does NOT place white exactly at zero --
% white lands slightly below it. Keep this in mind before reading fine
% structure near zero off an ERSP image.

    if nargin < 1 || isempty(n)
        n = 256;
    end
    validateattributes(n, {'numeric'}, {'scalar', 'integer', 'positive'}, ...
        mfilename, 'n');

    % Anchor positions on the original 256-row map, and their colours.
    anchorRow = [1 31 72 125 167 213 256];
    anchorRGB = [0.000000 0.000000 0.515625;   % dark blue
                 0.000000 0.000000 1.000000;   % blue
                 0.017544 1.000000 1.000000;   % cyan
                 0.941176 0.941176 0.941176;   % near-white (zero sits here)
                 1.000000 1.000000 0.000000;   % yellow
                 1.000000 0.000000 0.000000;   % red
                 0.500000 0.000000 0.000000];  % dark red

    if n == 1
        cmap = anchorRGB(4,:);
        return
    end

    query = linspace(anchorRow(1), anchorRow(end), n);
    cmap  = interp1(anchorRow, anchorRGB, query, 'linear');
    cmap  = min(max(cmap, 0), 1);
end
