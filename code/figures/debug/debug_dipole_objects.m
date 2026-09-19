function debug_dipole_objects(data, p)
% DEBUG_DIPOLE_OBJECTS  What are the blue blobs in the dipole panel?
%
%   DEBUG_DIPOLE_OBJECTS(DATA, P)
%
% Runs the SAME dipplot call PLOT_CLUSTER_PAIR_FIGURE's
% EMBED_CLUSTER_DIPOLES makes, then lists every graphics object in the
% resulting axes with the properties that decide how big it draws.
%
% The question this answers: STYLE_DIPOLE_MARKERS restyles solid LINE
% objects that carry a marker, and those are visibly working (the small
% white-edged circles). Something else in the axes is still drawing as a
% large filled blue shape. This prints what that something is -- its
% Type, and for patches and surfaces its FaceColor and vertex count --
% so the fix can target it instead of me guessing a fourth time.
%
% The dipole-collection logic below is deliberately duplicated from
% plot_cluster_pair_figure.m rather than shared: those are local
% functions in that file and not reachable from here, and a debug tool
% that drifts from the real path is worse than one that repeats twenty
% lines of it. If you change how dipoles are collected there, change it
% here too, or this stops being a faithful reproduction.
%
% Leaves the dipplot figures OPEN so you can click objects yourself.

    for bi = 1:numel(data)
        d = data(bi);
        fprintf('\n====================================================================\n');
        fprintf(' %s\n', d.s.name);
        fprintf('====================================================================\n');

        dipoles = local_collect_dipoles(d.STUDY, d.ALLEEG, d.s);
        fprintf('  dipoles assembled: %d (participants: %d)\n', ...
            numel(dipoles), numel(d.s.subjects));
        if isempty(dipoles)
            continue
        end

        opts = local_dipplot_options(d.ALLEEG, p, numel(dipoles));
        fprintf('  dipplot options  : %s\n', opts_to_text(opts));

        figsBefore = findobj(0, 'Type', 'figure');
        figure('Color', [1 1 1], 'Name', ['debug: ' d.s.name]);
        try
            dipplot(dipoles, opts{:});
        catch err
            fprintf('  !! dipplot errored: %s\n', err.message);
            continue
        end
        newFigs = setdiff(findobj(0, 'Type', 'figure'), figsBefore);

        for fi = 1:numel(newFigs)
            axesList = findobj(newFigs(fi), 'Type', 'axes');
            for ai = 1:numel(axesList)
                fprintf('\n  --- figure %d, axes %d ---\n', fi, ai);
                dump_axes_objects(axesList(ai));
            end
        end
    end
    fprintf('\nFigures left open. Close them yourself when done.\n\n');
end

function dump_axes_objects(ax)
% Every child, grouped by Type, with the properties that control size.
    kids = get(ax, 'Children');
    if isempty(kids)
        fprintf('     (empty)\n');
        return
    end
    types = arrayfun(@(h) get(h, 'Type'), kids, 'UniformOutput', false);
    for t = unique(types)'
        sel = strcmp(types, t{1});
        hs  = kids(sel);
        fprintf('     %s x%d\n', t{1}, numel(hs));
        switch t{1}
            case 'line'
                describe_lines(hs);
            case {'patch', 'surface'}
                describe_faces(hs);
        end
    end
end

function describe_lines(hs)
% Split by LineStyle, since the dashed ones are projection guides and the
% rest are dipole bodies/markers.
    styles  = arrayfun(@(h) get(h, 'LineStyle'), hs, 'UniformOutput', false);
    markers = arrayfun(@(h) get(h, 'Marker'),    hs, 'UniformOutput', false);
    for s = unique(styles)'
        sel = strcmp(styles, s{1});
        w   = arrayfun(@(h) get(h, 'LineWidth'), hs(sel));
        fprintf('        LineStyle ''%s'': %d objects, LineWidth %.2f-%.2f\n', ...
            s{1}, sum(sel), min(w), max(w));
        mk = unique(markers(sel));
        for m = mk'
            msel = sel & strcmp(markers, m{1});
            ms   = arrayfun(@(h) get(h, 'MarkerSize'), hs(msel));
            fprintf('           Marker ''%s'': %d, MarkerSize %.1f-%.1f\n', ...
                m{1}, sum(msel), min(ms), max(ms));
        end
    end
end

function describe_faces(hs)
% Patches and surfaces: this is where a "large filled blue shape" would
% live if it is not a marker at all.
    for i = 1:min(numel(hs), 8)
        h = hs(i);
        fc = get(h, 'FaceColor');
        if isnumeric(fc)
            fcTxt = sprintf('[%.2f %.2f %.2f]', fc(1), fc(2), fc(3));
        else
            fcTxt = fc;
        end
        nv = NaN;
        if isprop(h, 'Vertices') && ~isempty(get(h, 'Vertices'))
            nv = size(get(h, 'Vertices'), 1);
        elseif isprop(h, 'XData')
            nv = numel(get(h, 'XData'));
        end
        fprintf('        [%d] FaceColor %s, vertices/points %d\n', i, fcTxt, nv);
    end
    if numel(hs) > 8
        fprintf('        ... and %d more\n', numel(hs) - 8);
    end
end

function txt = opts_to_text(opts)
    parts = cell(1, 0);
    for i = 1:2:numel(opts)-1
        v = opts{i+1};
        if ischar(v)
            parts{end+1} = sprintf('%s=%s', opts{i}, v); %#ok<AGROW>
        elseif isnumeric(v) && numel(v) <= 3
            parts{end+1} = sprintf('%s=[%s]', opts{i}, num2str(v)); %#ok<AGROW>
        else
            parts{end+1} = sprintf('%s=<%s>', opts{i}, class(v)); %#ok<AGROW>
        end
    end
    txt = strjoin(parts, ', ');
end

%% ------------------------------------------------------------------
%  Duplicated from plot_cluster_pair_figure.m -- see the header note
%  ------------------------------------------------------------------
function dipoles = local_collect_dipoles(STUDY, ALLEEG, s)
    dipoles = [];
    for si = 1:numel(s.subjects)
        subjName = sprintf('S%d', s.subjects(si));
        dsIdx = NaN;
        for k = 1:numel(STUDY.datasetinfo)
            if strcmpi(STUDY.datasetinfo(k).subject, subjName)
                dsIdx = k;
                break
            end
        end
        if isnan(dsIdx) || dsIdx > numel(ALLEEG)
            continue
        end
        df = ALLEEG(dsIdx).dipfit;
        if ~isfield(df, 'model') || s.ICs(si) > numel(df.model)
            continue
        end
        m = df.model(s.ICs(si));
        if ~isfield(m, 'posxyz') || isempty(m.posxyz) || all(m.posxyz(:) == 0)
            continue
        end
        entry = struct('posxyz', m.posxyz, 'momxyz', [], 'rv', NaN);
        if isfield(m, 'momxyz'), entry.momxyz = m.momxyz; end
        if isfield(m, 'rv'),     entry.rv     = m.rv;     end
        entry.component = s.ICs(si);
        if isempty(dipoles)
            dipoles = entry;
        else
            dipoles(end+1) = entry; %#ok<AGROW>
        end
    end
end

function opts = local_dipplot_options(ALLEEG, p, nDipole)
    opts = {'projlines', 'on', 'spheres', 'off', 'normlen', 'on', ...
            'view', [1 -1 1], ...
            'color', repmat({p.plot.dipoleColor}, 1, max(nDipole, 1))};
    df = [];
    if isfield(ALLEEG(1), 'dipfit')
        df = ALLEEG(1).dipfit;
    end
    if ~isempty(df)
        if isfield(df, 'mrifile') && ~isempty(df.mrifile)
            opts = [opts, {'mri', df.mrifile}];
        end
        if isfield(df, 'coordformat') && ~isempty(df.coordformat)
            opts = [opts, {'coordformat', df.coordformat}];
        end
    end
    if isfield(p.plot, 'dipplotOptions') && ~isempty(p.plot.dipplotOptions)
        opts = [opts, p.plot.dipplotOptions];
    end
end
