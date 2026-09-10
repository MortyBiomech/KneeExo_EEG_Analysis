function debug_dipplot_contents(data, p)
% DEBUG_DIPPLOT_CONTENTS  Why does one cluster's dipole panel show
% projection lines and the other's not?
%
%   DEBUG_DIPPLOT_CONTENTS(DATA, P)
%
% Calls std_dipplot exactly as PLOT_CLUSTER_PAIR_FIGURE's
% EMBED_CLUSTER_DIPOLES does, then reports what the resulting figure
% actually contains, WITHOUT copying anything into a target figure.
%
% That separation is the whole point. Two very different faults produce
% the same symptom:
%
%   (1) dipplot never drew the lines for this cluster (a data or option
%       problem: no moment vectors, projlines resolved off, all dipoles
%       coincident, ...). Then the counts below are low IN THE SOURCE
%       FIGURE, and the fix is upstream of our layout code.
%
%   (2) dipplot drew them and our copyobj step lost them (they live in a
%       second axes that LARGEST_AXES did not pick, or they are objects
%       copyobj does not carry). Then the source figure has plenty of
%       lines and the fix is in EMBED_CLUSTER_DIPOLES.
%
% Run this and compare the two clusters' output line by line. Leaves the
% dipplot figures OPEN on purpose so you can rotate them and look.

    fprintf('\n');
    fprintf('====================================================================\n');
    fprintf(' DIPPLOT SOURCE-FIGURE CONTENTS\n');
    fprintf('====================================================================\n');

    for bi = 1:numel(data)
        d = data(bi);
        fprintf('\n--------------------------------------------------------------------\n');
        fprintf(' %s   (study: %s, cluster index %d)\n', ...
            d.s.name, d.studyName, d.clusterIdx);
        fprintf('--------------------------------------------------------------------\n');

        report_cluster_dipole_fields(d);

        figsBefore = findobj(0, 'Type', 'figure');
        opts = {};
        if isfield(p.plot, 'dipplotOptions')
            opts = p.plot.dipplotOptions;
        end
        usedOpts = true;
        try
            std_dipplot(d.STUDY, d.ALLEEG, 'clusters', d.clusterIdx, ...
                'view', [1 -1 1], opts{:});
        catch err
            usedOpts = false;
            fprintf('  !! std_dipplot REJECTED p.plot.dipplotOptions: %s\n', err.message);
            fprintf('  !! Falling back to the bare call. This alone would explain\n');
            fprintf('  !! the two panels differing, since each .study then supplies\n');
            fprintf('  !! its own defaults.\n');
            std_dipplot(d.STUDY, d.ALLEEG, 'clusters', d.clusterIdx, 'view', [1 -1 1]);
        end
        fprintf('  dipplotOptions applied : %s\n', bool_str(usedOpts));

        figsAfter = findobj(0, 'Type', 'figure');
        newFigs   = setdiff(figsAfter, figsBefore);
        fprintf('  new figures opened     : %d\n', numel(newFigs));
        if isempty(newFigs)
            continue
        end

        for fi = 1:numel(newFigs)
            axesList = findobj(newFigs(fi), 'Type', 'axes');
            fprintf('  figure %d: %d axes\n', fi, numel(axesList));
            areas = arrayfun(@(a) a.Position(3)*a.Position(4), axesList);
            [~, biggest] = max(areas);
            for ai = 1:numel(axesList)
                marker = '   ';
                if fi == 1 && ai == biggest
                    marker = ' ->';   % the one largest_axes would copy
                end
                fprintf('%s   axes %d (area %.3f)\n', marker, ai, areas(ai));
                report_axes_contents(axesList(ai));
            end
        end
        fprintf('  (the -> axes is the ONLY one embed_cluster_dipoles copies)\n');
    end

    fprintf('\nFigures left open deliberately. Close them yourself when done.\n\n');
end

function report_cluster_dipole_fields(d)
% A dipole with no moment vector has no orientation line to draw, and a
% cluster whose components are all at one location has nothing to
% project. Both show up here before any plotting happens.
    try
        c = d.STUDY.cluster(d.clusterIdx);
    catch
        fprintf('  (could not read STUDY.cluster(%d))\n', d.clusterIdx);
        return
    end

    if isfield(c, 'comps')
        fprintf('  components in cluster  : %d\n', numel(c.comps));
    end
    fprintf('  ICs used by the ERSPs  : %d (one per participant)\n', numel(d.s.ICs));

    if ~isfield(c, 'alldipoles') || isempty(c.alldipoles)
        fprintf('  alldipoles             : MISSING or empty\n');
        return
    end

    nd = numel(c.alldipoles);
    fprintf('  alldipoles entries     : %d\n', nd);
    fprintf('  fields                 : %s\n', strjoin(fieldnames(c.alldipoles(1))', ', '));

    hasMom  = 0;
    nonzero = 0;
    pos     = [];
    for i = 1:nd
        dp = c.alldipoles(i);
        if isfield(dp, 'momxyz') && ~isempty(dp.momxyz)
            hasMom = hasMom + 1;
            if any(dp.momxyz(:) ~= 0)
                nonzero = nonzero + 1;
            end
        end
        if isfield(dp, 'posxyz') && ~isempty(dp.posxyz)
            pos = [pos; dp.posxyz(1, :)]; %#ok<AGROW>
        end
    end
    fprintf('  with momxyz            : %d of %d (%d non-zero)\n', hasMom, nd, nonzero);
    if ~isempty(pos)
        fprintf('  position spread (mm)   : x %.1f, y %.1f, z %.1f\n', ...
            range_or_zero(pos(:,1)), range_or_zero(pos(:,2)), range_or_zero(pos(:,3)));
    end
end

function report_axes_contents(ax)
% Object census for one axes, split the way the symptom demands: solid
% vs dashed lines, since the projection guides are the dashed ones and
% the dipole moment vectors are the solid ones.
    kids = get(ax, 'Children');
    if isempty(kids)
        fprintf('        (empty)\n');
        return
    end
    types = arrayfun(@(h) get(h, 'Type'), kids, 'UniformOutput', false);
    uT = unique(types);
    parts = cell(1, numel(uT));
    for i = 1:numel(uT)
        parts{i} = sprintf('%s x%d', uT{i}, sum(strcmp(types, uT{i})));
    end
    fprintf('        %s\n', strjoin(parts, ',  '));

    lines = findobj(ax, 'Type', 'line');
    if isempty(lines)
        fprintf('        lines: none\n');
        return
    end
    styles = arrayfun(@(h) get(h, 'LineStyle'), lines, 'UniformOutput', false);
    widths = arrayfun(@(h) get(h, 'LineWidth'), lines);
    uS = unique(styles);
    for i = 1:numel(uS)
        sel = strcmp(styles, uS{i});
        fprintf('        lines LineStyle ''%s'': %d  (LineWidth %.2f to %.2f)\n', ...
            uS{i}, sum(sel), min(widths(sel)), max(widths(sel)));
    end
end

function r = range_or_zero(v)
    if isempty(v)
        r = 0;
    else
        r = max(v) - min(v);
    end
end

function s = bool_str(tf)
    if tf
        s = 'yes';
    else
        s = 'NO (fell back to defaults)';
    end
end
