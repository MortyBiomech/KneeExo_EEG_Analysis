function files = save_figure(fig, baseName, outDir, formats)
% SAVE_FIGURE  Write one figure to a folder in several formats.
%
%   FILES = SAVE_FIGURE(FIG, BASENAME, OUTDIR)
%   FILES = SAVE_FIGURE(FIG, BASENAME, OUTDIR, FORMATS)
%
%   FIG      figure handle
%   BASENAME file name without extension
%   OUTDIR   destination folder, created if it does not exist
%   FORMATS  cellstr of extensions, default {'png','fig','svg'}
%
%   FILES    cellstr of the full paths written
%
% Each format goes into its own subfolder of OUTDIR (OUTDIR/png, OUTDIR/fig,
% ...), which is how the published figure tree is laid out.
%
% This replaces savethisfig, which changed the working directory to the
% destination with CD and never changed it back, so the caller's working
% directory depended on how many figures had been saved so far. Nothing here
% touches the working directory.

    if nargin < 4 || isempty(formats)
        formats = {'png', 'fig', 'svg'};
    end
    if ischar(formats)
        formats = {formats};
    end

    % Strip characters that are legal in a MATLAB string but not in a
    % Windows file name. Cluster labels come from an atlas and can contain
    % parentheses, commas and slashes.
    baseName = regexprep(char(baseName), '[<>:"/\|?*]', '_');

    files = cell(1, numel(formats));
    for k = 1:numel(formats)
        fmt = formats{k};
        dest = fullfile(outDir, fmt);
        if ~isfolder(dest)
            mkdir(dest);
        end
        files{k} = fullfile(dest, [baseName '.' fmt]);

        if strcmpi(fmt, 'fig')
            savefig(fig, files{k});
        else
            % 'compact' vector output for svg/pdf, bitmap for the rest
            saveas(fig, files{k}, fmt);
        end
    end
end
