function definedcolormap2 = calldefinedcolormap2()
% CALLDEFINEDCOLORMAP2  Compatibility shim -- use ERSP_COLORMAP instead.
%
% Identical to CALLDEFINEDCOLORMAP; the original two files held byte-for-byte
% the same matrix. See CALLDEFINEDCOLORMAP for the details.

    definedcolormap2 = ersp_colormap(256);
end
