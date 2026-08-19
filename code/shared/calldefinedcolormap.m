function definedcolormap = calldefinedcolormap()
% CALLDEFINEDCOLORMAP  Compatibility shim -- use ERSP_COLORMAP instead.
%
% The published figure scripts under _NHB/manual_TF_outlier_removal call
% calldefinedcolormap() and calldefinedcolormap2(). Both originally were
% 9 kB files holding the same 256-by-3 matrix pasted in as a numeric
% literal, among sixteen such files.
%
% They now delegate to ERSP_COLORMAP, which generates that matrix from its
% seven anchor colours and reproduces it to 5e-7 -- far below one step of
% 24-bit colour, so the figures are unchanged.
%
% New code should call ERSP_COLORMAP directly.

    definedcolormap = ersp_colormap(256);
end
