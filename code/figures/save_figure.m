function files = save_figure(fig, baseName, outDir, formats, layout)
% SAVE_FIGURE  Write one figure to a folder in several formats.
%
%   FILES = SAVE_FIGURE(FIG, BASENAME, OUTDIR)
%   FILES = SAVE_FIGURE(FIG, BASENAME, OUTDIR, FORMATS)
%   FILES = SAVE_FIGURE(FIG, BASENAME, OUTDIR, FORMATS, LAYOUT)
%
%   FIG      figure handle
%   BASENAME file name without extension
%   OUTDIR   destination folder, created if it does not exist
%   FORMATS  cellstr of extensions, default p.plot.formats via the caller,
%            otherwise {'pdf','svg','png','fig'}
%   LAYOUT   'bytype' (default) puts each format in its own subfolder of
%            OUTDIR. 'flat' writes them all straight into OUTDIR.
%
%   FILES    cellstr of the full paths written
%
% The two layouts exist because the published figure folders on disk are flat:
% Figure4/ holds figure4_parieto_occipital.eps, .pdf, .png and .svg side by
% side, together with figure4_stats_report.txt. The default is kept as 'bytype'
% so that existing callers are unaffected, but a caller matching the published
% tree should pass 'flat'.
%
% This replaces savethisfig, which changed the working directory to the
% destination with CD and never changed it back, so the caller's working
% directory depended on how many figures had been saved so far. Nothing here
% touches the working directory.
%
% Vector formats go through EXPORTGRAPHICS with ContentType 'vector', not
% SAVEAS. SAVEAS writes a PDF as a full page with large margins, which is
% not a submittable figure, and it does not guarantee that text stays as
% text. Nature Portfolio requires vector figures with editable, embedded
% fonts, so the raster path is for previews only.

    if nargin < 4 || isempty(formats)
        formats = {'pdf', 'svg', 'png', 'fig'};
    end
    if ischar(formats)
        formats = {formats};
    end
    if nargin < 5 || isempty(layout)
        layout = 'bytype';
    end
    if ~ismember(lower(layout), {'bytype', 'flat'})
        error('save_figure:UnknownLayout', ...
            'LAYOUT must be ''bytype'' or ''flat'', got ''%s''.', layout);
    end

    % Strip characters that are legal in a MATLAB string but not in a
    % Windows file name. Cluster labels come from an atlas and can contain
    % parentheses, commas and slashes.
    baseName = regexprep(char(baseName), '[<>:"/\|?*]', '_');

    files = cell(1, numel(formats));
    for k = 1:numel(formats)
        fmt = formats{k};
        if strcmpi(layout, 'flat')
            dest = outDir;
        else
            dest = fullfile(outDir, fmt);
        end
        if ~isfolder(dest)
            mkdir(dest);
        end
        files{k} = fullfile(dest, [baseName '.' fmt]);

        switch lower(fmt)
            case 'fig'
                savefig(fig, files{k});
            case {'pdf', 'eps'}
                exportgraphics(fig, files{k}, 'ContentType', 'vector');
            case 'svg'
                print(fig, fullfile(dest, baseName), '-dsvg', '-vector');
            case {'png', 'tif', 'tiff', 'jpg'}
                exportgraphics(fig, files{k}, 'Resolution', 300);
            otherwise
                warning('save_figure:UnknownFormat', ...
                    'Unrecognised format ''%s'', skipped.', fmt);
                files{k} = '';
        end
    end
end