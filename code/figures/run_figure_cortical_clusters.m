%% Supplementary figure and table: the cortical source clusters
%
% run_figure_cortical_clusters.m
%
% One script for the Supplementary Materials subsection "Cortical source
% clusters". Press Run and it writes, into <repo>/figures/FigureS_cortical_clusters/
%
%   figureS_cortical_clusters.pdf/.eps/.svg/.png   the figure
%   tableS_cortical_clusters.tex                   the table, ready to paste
%   tableS_cortical_clusters.csv                   the same numbers, plain
%
% THE FIGURE
%   Two slices of the MNI template in the centre, axial on the left and
%   sagittal on the right, with the equivalent dipole of every component
%   projected onto them and coloured by cluster. Around them, one scalp
%   topography per cluster inside a ring of the cluster colour, with an
%   arrow from the ring to that cluster's dipoles.
%
% THE TABLE
%   Cluster, number of participants, number of components the clustering
%   assigned to the cluster before one component per participant was
%   retained, and the centroid of the dipoles in MNI coordinates.
%
% WHAT IT READS
%   The first run needs the tier 2 data (cfg.raw in config/local_paths.m)
%   and EEGLAB: it opens each region's .study file under
%   cfg.studyEpoched/multiple_clustering, reads the cluster membership, the
%   dipole positions and the scalp projections, and saves them to
%
%       data/derived/cortical_clusters.mat
%
%   Every later run reads that file and needs nothing else except the MNI
%   template MRI, which ships with EEGLAB's DIPFIT plugin. Commit the file
%   (git add -f, because *.mat is gitignored) and the figure reproduces
%   from a fresh clone, like the other analyses that run from data/derived.
%
% WHICH COMPONENTS ARE DRAWN
%   Every component the clustering assigned to a cluster, so the figure
%   shows the clusters as the clustering produced them. The label under
%   each cluster name gives the number of participants and the number of
%   components. The analyses use one component per participant, the pairs
%   in Subjects_ICs_in_clusters.mat. Set opts.dipoleSet and opts.topoSet
%   to 'analysed' to draw only those.
%
% WHILE ITERATING ON THE LAYOUT
%   Run sections 1 to 3 once, then re-run section 5 on its own. Every
%   position in the figure is written in millimetres in FIGURE_GEOMETRY,
%   near the end of this file.
%
% Prerequisites
%   * EEGLAB on the MATLAB path, with the DIPFIT plugin
%   * for the first run only, cfg.raw set in config/local_paths.m

%% 1. Set up --------------------------------------------------------------
clc; clear;
% Locate config/, which is always two levels up from code/<stage>/.
%
% mfilename is empty when these lines are pasted into the command window,
% and reports a temporary helper file when a single %% section is run with
% Ctrl+Enter, so neither case can be trusted. Fall back to this file's own
% name, which resolves whenever the file is runnable at all.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('run_figure_cortical_clusters');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_figure_cortical_clusters.m and ' ...
           'press Run, or make its folder the current folder first. Pasting ' ...
           'the bootstrap into the command window gives MATLAB nothing to ' ...
           'resolve the path from.']);
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);
p   = ersp_params();

%% 2. Choices --------------------------------------------------------------
% One row per cluster. Edit names, colours and positions here and nowhere
% else.
%
%   key       base name of the region's .study file, and the label in
%             Subjects_ICs_in_clusters.mat
%   label     text beside the topography; each cell is one line
%   tableName name in the table. The two Prim_Motor clusters are called
%             sensorimotor, as in Figures 3 and 4
%             (p.plot.clusterDisplayNames).
%   colour    RGB, 0 to 255
%   slot      where the topography sits: L1 L2 left column, T1 T2 above the
%             axial slice, B1 B2 below it, RC the middle of the right
%             column, R1 R2 its upper and lower half when the column
%             holds two maps
%   panel     which slice the arrow points into
%
% The order of the rows is the order of the rows in the table.
%
% The colours of the seven drawn clusters were chosen by a search that
% maximises the smallest difference between any two of them, for normal
% colour vision and for the three common forms of colour blindness
% (difference measured in OKLab). Each cluster is also identified by its
% ring, its arrow and its label, so colour never carries identity alone.
clusterSpec = { ...
    'Left_Prim_Motor',         {'Left sensorimotor'},                          'left sensorimotor',                      [200 141 247], 'T1', 'axial'; ...
    'Right_Prim_Motor',        {'Right sensorimotor'},                         'right sensorimotor',                     [ 63  48 255], 'B1', 'axial'; ...
    'Left_PreMot_SuppMot',     {'Left premotor and', 'supplementary motor'},   'left premotor and supplementary motor',  [ 23 173 131], 'T2', 'axial'; ...
    'Right_PreMot_SuppMot',    {'Right premotor and', 'supplementary motor'},  'right premotor and supplementary motor', [253 186  39], 'B2', 'axial'; ...
    'Left_Parieto_Occipital',  {'Left parieto-occipital'},                     'left parieto-occipital',                 [195 130  20], 'L1', 'axial'; ...
    'Right_Parieto_Occipital', {'Right parieto-occipital'},                    'right parieto-occipital',                [207  27  18], 'L2', 'axial'; ...
    'Left_Dorsal_ACC',         {'Left dorsal', 'anterior cingulate'},          'left dorsal anterior cingulate',         [160  12 167], 'RC', 'sagittal'; ...
    'Prime_Visual',            {'Primary visual'},                             'primary visual',                         [255 105 180], 'R2', 'sagittal'};

spec = struct('key', clusterSpec(:, 1), 'label', clusterSpec(:, 2), ...
    'tableName', clusterSpec(:, 3), 'colour', clusterSpec(:, 4), ...
    'slot', clusterSpec(:, 5), 'panel', clusterSpec(:, 6));
for k = 1:numel(spec)
    spec(k).colour = spec(k).colour / 255;
end

opts = struct();

% 'analysed'  one component per participant, the set every analysis uses
% 'full'      every component the clustering assigned to the cluster
opts.dipoleSet   = 'full';       % the dipoles on the slices
opts.topoSet     = 'full';       % the components averaged into each scalp map
% The set that spread, RV and the MNI centroid under each cluster name are
% computed over. 'full' is every component in the cluster. The printed table
% and the CSV use the same set, so they agree with the figure.
opts.labelSet    = 'full';
opts.centroidSet = opts.labelSet;

% Minus sign for the negative MNI coordinates under each cluster name. A true
% minus sign by default. Set to '-' if an exported file shows a wrong
% character in its place.
opts.minusSign = char(8722);

% A component that sits in two clusters is drawn once in each colour: full
% size in the first cluster and as a smaller dot on top in the second, so
% both colours stay visible. Set to false to draw them at full size, where
% the later cluster hides the earlier one.
opts.showShared = true;

% An independent component's sign is arbitrary. 'peakPositive' flips each
% cluster map so its strongest pole is positive. 'asis' keeps the sign that
% the polarity alignment produces, which is what Figures 3 and 4 show.
opts.topoPolarity = 'peakPositive';

% Small colour scale for the topographies in the bottom right corner.
opts.showColorKey = true;

% Slices of the template shown behind the dipoles, MNI millimetres. Every
% dipole is projected onto them whatever its own depth.
opts.axialZ    = 20;
opts.sagittalX = -4;

% Clusters to leave out, by key. They stay in the derived file, so putting
% one back is a matter of emptying the list.
%   Prime_Visual is not drawn. It shares 7 of its 12 components with
%   Right_Parieto_Occipital and is not part of the trial-level analysis.
opts.excludeFromFigure = {'Prime_Visual'};
opts.excludeFromTable  = {};

% Set to true to re-read the .study files and overwrite the derived file.
opts.rebuildCache = false;

% Leave empty to find the template MRI through the DIPFIT plugin.
opts.mriFile = '';

outputPath = fullfile(cfg.figures, 'FigureS_cortical_clusters');
cacheFile  = fullfile(cfg.derived, 'cortical_clusters.mat');

%% 3. Collect the cluster data, ONCE ----------------------------------------
% Slow the first time, because loading a .study file loads the header of
% every dataset in it. Afterwards this section only reads the derived file.
if isempty(which('eeglab')) && isfield(cfg, 'eeglab') && ~isempty(cfg.eeglab)
    addpath(cfg.eeglab);
end

if exist(cacheFile, 'file') == 2 && ~opts.rebuildCache
    fprintf('Reading the cluster data from %s\n', cacheFile);
    loaded = load(cacheFile, 'C');
    C = loaded.C;
else
    fprintf('Collecting the cluster data from the .study files\n');
    if isempty(which('pop_loadstudy')) && ~isempty(which('eeglab'))
        eeglab('nogui');
    end
    C = collect_cluster_data(cfg, p, {spec.key});
    if ~isfolder(cfg.derived)
        mkdir(cfg.derived);
    end
    save(cacheFile, 'C', '-v7');
    fprintf('Saved %s\n', cacheFile);
end

check_cluster_data(C, cfg, p, {spec.key});

%% 4. The table --------------------------------------------------------------
% Fast. Prints the numbers that also appear under each cluster name on the
% figure, and writes them as CSV and as a LaTeX table. The manuscript no
% longer needs the table, but the files are a record of the numbers.
inTable = ~ismember({spec.key}, opts.excludeFromTable);
tbl = build_cluster_table(C, spec(inTable), opts);
print_cluster_table(tbl, opts);
write_cluster_table_tex(tbl, opts, fullfile(outputPath, 'tableS_cortical_clusters.tex'));
write_cluster_table_csv(tbl, fullfile(outputPath, 'tableS_cortical_clusters.csv'));

%% 5. The figure. RE-RUN THIS SECTION WHILE ITERATING -------------------------
if isempty(opts.mriFile) && isempty(which('dipfitdefs')) && ~isempty(which('eeglab'))
    eeglab('nogui');   % puts the plugins, DIPFIT included, on the path
end
mri = load_template_mri(C, opts);
inFigure = ~ismember({spec.key}, opts.excludeFromFigure);
fig = draw_cluster_figure(C, spec(inFigure), opts, p, mri);
files = save_figure(fig, 'figureS_cortical_clusters', outputPath, p.plot.formats, 'flat');
fprintf('Figure written to %s\n', outputPath);
fprintf('  %s\n', files{:});


%% ========================================================================
%  Local functions
%  ========================================================================

%% ------------------------------------------------------------------------
%  Collecting: .study files to one small struct
%  ------------------------------------------------------------------------
function C = collect_cluster_data(cfg, p, keys)
% Read, for every region, the cluster the clustering selected: who is in it,
% where each dipole is, and each component's scalp projection.
%
% Two sets are kept per cluster.
%   analysed  the (participant, component) pairs in
%             Subjects_ICs_in_clusters.mat, one per participant
%   full      every component in STUDY.cluster(k), the membership the
%             clustering produced before that reduction
%
% Only the first .study file is loaded through pop_loadstudy, which also
% loads the datasets. The other regions cluster the same datasets, so their
% .study files are opened as plain MAT files for the STUDY structure alone.
% The dataset lists are compared, so a region built from other datasets is
% caught here and cannot be read against the wrong ALLEEG.

    if ~isfield(cfg, 'raw') || isempty(cfg.raw)
        error('collect_cluster_data:NoRawData', ...
            ['Building the cluster data needs the .study files. Set cfg.raw ' ...
             'in config/local_paths.m, or commit data/derived/' ...
             'cortical_clusters.mat from a machine that has them.']);
    end
    if isempty(which('pop_loadstudy'))
        error('collect_cluster_data:NoEEGLAB', ...
            'EEGLAB is not on the path. Start EEGLAB and run this again.');
    end

    subjectsIcsFile = fullfile(cfg.derived, p.subjectsIcsFile);
    loaded = load(subjectsIcsFile, 'SUBJECTS_ICS');
    SUBJECTS_ICS = loaded.SUBJECTS_ICS;

    studyRoot = fullfile(cfg.studyEpoched, 'multiple_clustering');

    C = struct();
    C.built       = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    C.subjects    = cfg.subjects;
    C.coordformat = '';
    C.dataset     = struct([]);
    C.cluster     = struct([]);

    ALLEEG = [];
    referenceDatasets = {};
    dsSubject = [];

    for k = 1:numel(keys)

        key = keys{k};
        studyFolder = fullfile(studyRoot, key);
        studyFile   = fullfile(studyFolder, [key '.study']);
        fprintf('  %-26s', key);

        if exist(studyFile, 'file') ~= 2
            error('collect_cluster_data:NoStudy', ...
                'No .study file for %s at\n  %s', key, studyFile);
        end

        if isempty(ALLEEG)
            fprintf('loading the STUDY and its datasets ... ');
            [STUDY, ALLEEG] = pop_loadstudy('filename', [key '.study'], ...
                'filepath', studyFolder);
            referenceDatasets = dataset_signature(STUDY);
            dsSubject = dataset_subject_numbers(STUDY);
            C.dataset = dataset_geometry(ALLEEG, dsSubject);
            if isfield(ALLEEG(1), 'dipfit') && isfield(ALLEEG(1).dipfit, 'coordformat')
                C.coordformat = ALLEEG(1).dipfit.coordformat;
            end
        else
            fprintf('loading the STUDY ... ');
            tmp = load('-mat', studyFile, 'STUDY');
            STUDY = tmp.STUDY;
            if ~isequal(dataset_signature(STUDY), referenceDatasets)
                error('collect_cluster_data:DatasetMismatch', ...
                    ['%s lists different datasets, or lists them in another ' ...
                     'order, than %s. The regions are expected to cluster ' ...
                     'the same datasets.'], key, keys{1});
            end
        end

        if ~isfield(STUDY, 'etc') || ~isfield(STUDY.etc, 'bemobil') || ...
                ~isfield(STUDY.etc.bemobil, 'clustering') || ...
                ~isfield(STUDY.etc.bemobil.clustering, 'cluster_ROI_index')
            error('collect_cluster_data:NoRoiIndex', ...
                ['%s carries no STUDY.etc.bemobil.clustering.cluster_ROI_index, ' ...
                 'so the cluster of interest cannot be identified.'], key);
        end
        ci = STUDY.etc.bemobil.clustering.cluster_ROI_index;
        cl = STUDY.cluster(ci);

        % Full membership, as the clustering left it. keep_one_ic_per_subject
        % replaces STUDY.cluster with the reduced clusters and keeps the
        % originals in STUDY.cluster_og. If a .study file was saved after
        % that step, the originals are the full clusters.
        if isfield(STUDY, 'cluster_og') && numel(STUDY.cluster_og) >= ci && ...
                numel(STUDY.cluster_og(ci).comps) > numel(cl.comps)
            fprintf('(full membership from STUDY.cluster_og) ');
            cl = STUDY.cluster_og(ci);
        end
        fullDataset = double(cl.sets(1, :));
        fullIC      = double(cl.comps(:)).';
        fullSubject = dsSubject(fullDataset);

        % The analysed pairs, one per participant.
        [anSubject, anIC] = analysed_pairs(SUBJECTS_ICS, key, cfg.subjects);
        anDataset = nan(size(anSubject));
        for i = 1:numel(anSubject)
            hit = find(dsSubject == anSubject(i), 1, 'first');
            if isempty(hit)
                error('collect_cluster_data:NoDataset', ...
                    'Participant %d is in %s but has no dataset in the STUDY.', ...
                    anSubject(i), key);
            end
            anDataset(i) = hit;
        end

        C.cluster(k).key        = key;
        C.cluster(k).studyIndex = ci;
        C.cluster(k).analysed   = component_records(ALLEEG, anDataset, anSubject, anIC, key);
        C.cluster(k).full       = component_records(ALLEEG, fullDataset, fullSubject, fullIC, key);

        C.cluster(k).studyCentroid = nan(1, 3);
        if isfield(cl, 'dipole') && isfield(cl.dipole, 'posxyz') && ~isempty(cl.dipole.posxyz)
            C.cluster(k).studyCentroid = double(cl.dipole.posxyz(1, :));
        end

        fprintf('cluster %d, %d participants analysed, %d components in the cluster\n', ...
            ci, numel(anIC), numel(fullIC));

        % The analysed pairs should be members of the cluster they are
        % analysed in. If they are not, the two files describe different
        % clustering runs.
        isMember = ismember([anSubject(:), anIC(:)], [fullSubject(:), fullIC(:)], 'rows');
        if ~all(isMember)
            warning('collect_cluster_data:NotInCluster', ...
                ['%s: %d of the %d analysed components are not members of ' ...
                 'the cluster in the .study file. Subjects_ICs_in_clusters.mat ' ...
                 'and the .study file may come from different clustering runs.'], ...
                key, nnz(~isMember), numel(isMember));
        end
        if numel(unique(fullSubject)) ~= numel(anSubject)
            warning('collect_cluster_data:ParticipantCount', ...
                ['%s: the cluster in the .study file holds components from %d ' ...
                 'participants, the analysed set has %d.'], ...
                key, numel(unique(fullSubject)), numel(anSubject));
        end

    end

end

function sig = dataset_signature(STUDY)
% What identifies the datasets of a STUDY: subject and file name, in order.
    n = numel(STUDY.datasetinfo);
    sig = cell(n, 2);
    for d = 1:n
        sig{d, 1} = char(STUDY.datasetinfo(d).subject);
        sig{d, 2} = char(STUDY.datasetinfo(d).filename);
    end
end

function num = dataset_subject_numbers(STUDY)
% Participant number of every dataset, read from the subject name ('S12').
    n = numel(STUDY.datasetinfo);
    num = nan(1, n);
    for d = 1:n
        tok = regexp(char(STUDY.datasetinfo(d).subject), '\d+', 'match', 'once');
        if ~isempty(tok)
            num(d) = str2double(tok);
        end
    end
    if any(isnan(num))
        error('dataset_subject_numbers:NoNumber', ...
            ['A subject name in the STUDY carries no number. This script ' ...
             'expects names such as S5 to S18.']);
    end
end

function D = dataset_geometry(ALLEEG, dsSubject)
% Polar channel positions of every dataset, for the channels the ICA ran on.
% That is all the topographies need, so the datasets themselves never have
% to be opened again.
    D = struct('subject', {}, 'labels', {}, 'theta', {}, 'radius', {}, 'nosedir', {});
    for d = 1:numel(ALLEEG)
        EEG = ALLEEG(d);
        nRows = size(EEG.icawinv, 1);
        if isfield(EEG, 'icachansind') && numel(EEG.icachansind) == nRows
            idx = EEG.icachansind;
        else
            idx = 1:nRows;
        end
        locs = EEG.chanlocs(idx);
        D(d).subject = dsSubject(d);
        D(d).labels  = {locs.labels};
        D(d).theta   = nan(1, numel(locs));
        D(d).radius  = nan(1, numel(locs));
        for c = 1:numel(locs)
            if ~isempty(locs(c).theta) && ~isempty(locs(c).radius)
                D(d).theta(c)  = double(locs(c).theta);
                D(d).radius(c) = double(locs(c).radius);
            end
        end
        D(d).nosedir = '+X';
        if isfield(EEG, 'chaninfo') && isfield(EEG.chaninfo, 'nosedir') && ...
                ~isempty(EEG.chaninfo.nosedir)
            D(d).nosedir = EEG.chaninfo.nosedir;
        end
    end
end

function [subj, ic] = analysed_pairs(SUBJECTS_ICS, key, nominalSubjects)
% The (participant, component) pairs one cluster contributes to the
% analyses. SUBJECTS_ICS stores positions in the participant list, not
% participant numbers, so the list is passed in. Labels are matched with
% underscores and spaces treated alike, because both spellings exist.
    names = strrep(SUBJECTS_ICS(:, 1), '_', ' ');
    idx = find(strcmp(names, strrep(key, '_', ' ')));
    if numel(idx) ~= 1
        error('analysed_pairs:ClusterLookup', ...
            'Cluster %s matches %d entries in SUBJECTS_ICS.', key, numel(idx));
    end
    entry = SUBJECTS_ICS{idx, 2};
    position = double(entry.Subjects(:));
    if any(position < 1) || any(position > numel(nominalSubjects))
        error('analysed_pairs:SubjectIndex', ...
            ['Cluster %s refers to participant positions outside 1 to %d. ' ...
             'SUBJECTS_ICS was built from another participant list.'], ...
            key, numel(nominalSubjects));
    end
    subj = nominalSubjects(position);
    subj = subj(:);
    ic   = double(entry.ICs(:));
    [subj, order] = sort(subj);
    ic = ic(order);
end

function S = component_records(ALLEEG, dsIdx, subj, ic, key)
% Dipole position, residual variance and scalp projection of each component.
    n = numel(ic);
    S = struct();
    S.subject = double(subj(:));
    S.ic      = double(ic(:));
    S.dataset = double(dsIdx(:));
    S.posxyz  = nan(n, 3);
    S.rv      = nan(n, 1);
    S.map     = cell(n, 1);
    for i = 1:n
        EEG = ALLEEG(dsIdx(i));
        if ~isfield(EEG, 'dipfit') || ~isfield(EEG.dipfit, 'model') || ...
                ic(i) > numel(EEG.dipfit.model) || ...
                isempty(EEG.dipfit.model(ic(i)).posxyz)
            error('component_records:NoDipole', ...
                '%s: participant %d component %d has no dipole model.', ...
                key, subj(i), ic(i));
        end
        model = EEG.dipfit.model(ic(i));
        S.posxyz(i, :) = double(model.posxyz(1, :));
        if isfield(model, 'rv') && ~isempty(model.rv)
            S.rv(i) = double(model.rv);
        end
        S.map{i} = double(EEG.icawinv(:, ic(i)));
    end
end

function check_cluster_data(C, cfg, p, keys)
% The derived file must describe the clusters asked for, and the same
% analysed components that Subjects_ICs_in_clusters.mat lists today. A
% derived file that has gone stale is caught here, not in the figure.
    have = {C.cluster.key};
    missing = setdiff(keys, have);
    if ~isempty(missing)
        error('check_cluster_data:MissingCluster', ...
            ['The derived file has no entry for %s. Set opts.rebuildCache = ' ...
             'true and run again.'], strjoin(missing, ', '));
    end

    if ~isempty(C.coordformat) && ~strcmpi(C.coordformat, 'MNI')
        error('check_cluster_data:NotMNI', ...
            ['The dipoles were fitted in ''%s'' coordinates. This script ' ...
             'draws them on the MNI template and reports MNI centroids.'], ...
            C.coordformat);
    end

    subjectsIcsFile = fullfile(cfg.derived, p.subjectsIcsFile);
    if exist(subjectsIcsFile, 'file') ~= 2
        fprintf('Subjects_ICs_in_clusters.mat not found, staleness not checked.\n');
        return
    end
    loaded = load(subjectsIcsFile, 'SUBJECTS_ICS');
    for k = 1:numel(keys)
        ck = C.cluster(strcmp(have, keys{k}));
        [subj, ic] = analysed_pairs(loaded.SUBJECTS_ICS, keys{k}, cfg.subjects);
        if ~isequal([subj(:), ic(:)], [ck.analysed.subject(:), ck.analysed.ic(:)])
            error('check_cluster_data:Stale', ...
                ['%s: the derived file and Subjects_ICs_in_clusters.mat list ' ...
                 'different components. Set opts.rebuildCache = true and run ' ...
                 'again.'], keys{k});
        end
    end
    fprintf('Derived file built %s, consistent with %s\n', C.built, p.subjectsIcsFile);
end

%% ------------------------------------------------------------------------
%  The table
%  ------------------------------------------------------------------------
function tbl = build_cluster_table(C, spec, opts)
% One row per cluster, in the order of SPEC.
    have = {C.cluster.key};
    tbl = struct('name', {}, 'key', {}, 'nParticipants', {}, 'nComponents', {}, ...
        'centroid', {}, 'centroidAnalysed', {}, 'centroidFull', {}, 'centroidStudy', {}, ...
        'spread', {}, 'meanRV', {});
    for k = 1:numel(spec)
        ck = C.cluster(strcmp(have, spec(k).key));
        tbl(k).name             = spec(k).tableName;
        tbl(k).key              = spec(k).key;
        tbl(k).nParticipants    = numel(unique(ck.analysed.subject));
        tbl(k).nComponents      = numel(ck.full.ic);
        tbl(k).centroidAnalysed = mean(ck.analysed.posxyz, 1);
        tbl(k).centroidFull     = mean(ck.full.posxyz, 1);
        tbl(k).centroidStudy    = ck.studyCentroid;
        if strcmpi(opts.centroidSet, 'full')
            tbl(k).centroid = tbl(k).centroidFull;
        else
            tbl(k).centroid = tbl(k).centroidAnalysed;
        end
        stats = cluster_statistics(pick_set(ck, opts.centroidSet));
        tbl(k).spread = stats.spread;
        tbl(k).meanRV = stats.meanRV;
    end
end

function stats = cluster_statistics(S)
% The three numbers printed under each cluster name, for one set of
% components.
%   centroid  mean dipole position, MNI mm
%   spread    root-mean-square distance of the dipoles from the centroid, in
%             mm. Its square is the normalised spread of the BeMoBIL
%             pipeline (bemobil_dipoles: sum of squared distances from the
%             centroid, divided by the number of components).
%   meanRV    mean residual variance of the dipole fits, in percent
    stats.centroid = mean(S.posxyz, 1);
    offset = S.posxyz - repmat(stats.centroid, size(S.posxyz, 1), 1);
    stats.spread = sqrt(mean(sum(offset.^2, 2)));
    rv = S.rv(isfinite(S.rv));
    if isempty(rv)
        stats.meanRV = NaN;
    else
        stats.meanRV = 100 * mean(rv);
    end
end

function print_cluster_table(tbl, opts)
    fprintf('\nCortical source clusters\n');
    fprintf('Spread, RV and the figure centroid: over the %s components\n', centroid_set_words(opts));
    fprintf('%s\n', repmat('-', 1, 140));
    fprintf('%-40s %4s %4s %10s %7s   %-18s %-18s %-18s\n', 'Cluster', 'n', 'ICs', ...
        'spread mm', 'RV %', 'centroid, figure', 'centroid, retained', 'centroid in STUDY');
    fprintf('%s\n', repmat('-', 1, 140));
    for k = 1:numel(tbl)
        fprintf('%-40s %4d %4d %10.1f %7.1f   %-18s %-18s %-18s\n', tbl(k).name, ...
            tbl(k).nParticipants, tbl(k).nComponents, tbl(k).spread, tbl(k).meanRV, ...
            xyz_text(tbl(k).centroid), xyz_text(tbl(k).centroidAnalysed), ...
            xyz_text(tbl(k).centroidStudy));
    end
    fprintf('%s\n', repmat('-', 1, 140));
    fprintf(['n = participants, ICs = components in the cluster before one per ' ...
             'participant was retained.\nSpread = root-mean-square distance of ' ...
             'the dipoles from the centroid. The first centroid is the one on the figure.\n\n']);
    if all([tbl.nComponents] == [tbl.nParticipants])
        warning('print_cluster_table:NoFullClusters', ...
            ['Every cluster holds exactly one component per participant, so the ' ...
             '"full" clusters are the reduced ones and the figure centroids equal ' ...
             'the retained centroids. The .study files were probably saved after ' ...
             'keep_one_ic_per_subject. Set opts.rebuildCache = true to read the ' ...
             'original clusters from STUDY.cluster_og.']);
    end
end

function words = centroid_set_words(opts)
    if strcmpi(opts.centroidSet, 'full')
        words = 'full-cluster';
    else
        words = 'retained (one per participant)';
    end
end

function t = xyz_text(v)
    if any(isnan(v))
        t = '(not stored)';
    else
        t = sprintf('[%4.0f %4.0f %4.0f]', v(1), v(2), v(3));
    end
end

function write_cluster_table_tex(tbl, opts, texFile)
% The table as LaTeX, in the layout of the other supplementary tables
% (booktabs, bold caption lead). Paste it into the Supplementary Materials.
    if ~isfolder(fileparts(texFile))
        mkdir(fileparts(texFile));
    end
    if strcmpi(opts.centroidSet, 'full')
        centroidSentence = 'The centroid is the mean dipole position over all components of the cluster.';
    else
        centroidSentence = 'The centroid is the mean dipole position over the retained components.';
    end

    fid = fopen(texFile, 'w');
    if fid == -1
        error('write_cluster_table_tex:CannotOpen', 'Cannot write %s', texFile);
    end
    fprintf(fid, '%% Generated by run_figure_cortical_clusters.m. Do not edit the numbers by hand.\n');
    fprintf(fid, '\\begin{table}[htbp]\n');
    fprintf(fid, '\t\\centering\n');
    fprintf(fid, ['\t\\caption{\\textbf{Cortical source clusters.} ' ...
        'Participants is the number of participants with a component in the cluster. ' ...
        'Components is the number of components that the clustering assigned to the cluster, ' ...
        'before one component per participant was retained. ' ...
        '%s Coordinates are in MNI space.}\n'], centroidSentence);
    fprintf(fid, '\t\\label{tab:clusters}\n');
    fprintf(fid, '\t\\begin{tabular}{lrrrrr}\n');
    fprintf(fid, '\t\t\\toprule\n');
    fprintf(fid, '\t\t & & & \\multicolumn{3}{c}{Centroid (mm)} \\\\\n');
    fprintf(fid, '\t\t\\cmidrule(lr){4-6}\n');
    fprintf(fid, '\t\tCluster & Participants & Components & $x$ & $y$ & $z$ \\\\\n');
    fprintf(fid, '\t\t\\midrule\n');
    for k = 1:numel(tbl)
        c = round(tbl(k).centroid);
        fprintf(fid, '\t\t%s & %d & %d & %s & %s & %s \\\\\n', tbl(k).name, ...
            tbl(k).nParticipants, tbl(k).nComponents, ...
            tex_integer(c(1)), tex_integer(c(2)), tex_integer(c(3)));
    end
    fprintf(fid, '\t\t\\bottomrule\n');
    fprintf(fid, '\t\\end{tabular}\n');
    fprintf(fid, '\\end{table}\n');
    fclose(fid);
    fprintf('Table written to %s\n', texFile);
end

function t = tex_integer(v)
% Integer in math mode, so a negative number gets a true minus sign.
    t = sprintf('$%d$', v);
end

function write_cluster_table_csv(tbl, csvFile)
    fid = fopen(csvFile, 'w');
    if fid == -1
        error('write_cluster_table_csv:CannotOpen', 'Cannot write %s', csvFile);
    end
    fprintf(fid, ['cluster,key,participants,components,spread_mm,mean_rv_percent,' ...
        'x_analysed,y_analysed,z_analysed,x_full,y_full,z_full,' ...
        'x_study,y_study,z_study\n']);
    for k = 1:numel(tbl)
        fprintf(fid, '%s,%s,%d,%d,%.2f,%.2f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f\n', ...
            tbl(k).name, tbl(k).key, tbl(k).nParticipants, tbl(k).nComponents, ...
            tbl(k).spread, tbl(k).meanRV, ...
            tbl(k).centroidAnalysed, tbl(k).centroidFull, tbl(k).centroidStudy);
    end
    fclose(fid);
end

%% ------------------------------------------------------------------------
%  The template MRI
%  ------------------------------------------------------------------------
function mri = load_template_mri(C, opts)
% The MNI template that ships with DIPFIT, as a volume with one MNI
% coordinate vector per axis, each in ascending order.
    mriFile = opts.mriFile;
    if isempty(mriFile)
        mriFile = which('standard_mri.mat');
    end
    if isempty(mriFile)
        defs = which('dipfitdefs');
        if ~isempty(defs)
            mriFile = fullfile(fileparts(defs), 'standard_BEM', 'standard_mri.mat');
        end
    end
    if isempty(mriFile) || exist(mriFile, 'file') ~= 2
        error('load_template_mri:NotFound', ...
            ['The MNI template MRI (standard_mri.mat) was not found. It ships ' ...
             'with EEGLAB''s DIPFIT plugin under standard_BEM. Start EEGLAB ' ...
             'first, or set opts.mriFile.']);
    end
    fprintf('Template MRI: %s\n', mriFile);

    tmp = load('-mat', mriFile);
    if isfield(tmp, 'mri')
        m = tmp.mri;
    else
        names = fieldnames(tmp);
        m = tmp.(names{1});
    end

    T = double(m.transform);
    R = T(1:3, 1:3);
    if any(any(abs(R - diag(diag(R))) > 1e-6))
        error('load_template_mri:Oblique', ...
            ['The MRI volume is not aligned with the MNI axes. This script ' ...
             'slices the volume along its own axes and needs an aligned one.']);
    end

    anat = m.anatomy;
    n = size(anat);
    x = R(1, 1) * (1:n(1)) + T(1, 4);
    y = R(2, 2) * (1:n(2)) + T(2, 4);
    z = R(3, 3) * (1:n(3)) + T(3, 4);
    if x(1) > x(end), x = fliplr(x); anat = anat(end:-1:1, :, :); end
    if y(1) > y(end), y = fliplr(y); anat = anat(:, end:-1:1, :); end
    if z(1) > z(end), z = fliplr(z); anat = anat(:, :, end:-1:1); end

    mri = struct('anat', anat, 'x', x, 'y', y, 'z', z, ...
        'maxValue', double(max(anat(:))));
end

%% ------------------------------------------------------------------------
%  The figure
%  ------------------------------------------------------------------------
function G = figure_geometry(p)
% Every position in the figure, in millimetres from the bottom left corner.
% The figure is one invisible axes whose data units ARE millimetres, so a
% number here is a distance on the printed page.
    G.figW = p.plot.figureWidthMM;    % 180 mm, double column
    G.figH = 138;

    % The two slices. Both show the same anterior to posterior range, so the
    % horizontal axis is shared and a dipole sits at the same horizontal
    % position in both.
    G.yRange = [-118 88];             % MNI y, posterior to anterior
    G.xHalf  = 84;                    % axial slice shows MNI x in [-84, 84]
    G.zRange = [-62 106];             % sagittal slice, MNI z
    G.sideColumn  = 32;               % width of the column of maps on each side
    G.panelGap    = 3;
    G.panelLeft   = G.sideColumn;
    G.panelW      = (G.figW - 2 * G.sideColumn - G.panelGap) / 2;
    G.panelBottom = 46;
    G.scale  = G.panelW / diff(G.yRange);          % page mm per MNI mm
    G.panelH = G.scale * 2 * G.xHalf;
    assert(abs(diff(G.zRange) - 2 * G.xHalf) < 1e-9, ...
        'figure_geometry:PanelHeights', ...
        'The two slices need the same vertical extent to share one height.');
    G.mriGamma = 0.8;                 % brightens the template, as dipplot does
    G.mriUpsample = 3;                % the template has 1 mm voxels, which print
                                      % at about 90 dpi here. Interpolating it
                                      % before drawing keeps the vector files
                                      % smooth in every viewer.

    % The topographies.
    G.topoRadius = 9.3;               % radius of the scalp map disc
    G.ringGap    = 0.9;               % white space between the map and its ring
    G.ringWidth  = 1.2;               % coloured ring around it
    G.topoPixels = 241;               % resolution of the interpolated map
    G.headLineWidth = 0.5;            % pt, head outline, nose and ears
    G.topoContours  = 6;              % number of contour levels inside each map,
                                      % topoplot's default. 0 draws none.
    G.contourColor  = [0.3 0.3 0.3];
    G.contourWidth  = 0.25;           % pt

    panelTop = G.panelBottom + G.panelH;
    rowGap   = 4.4;                   % between a slice and the ring above or below
    ringOuter = G.topoRadius + G.ringGap + G.ringWidth;
    topY     = panelTop + rowGap + ringOuter;
    bottomY  = G.panelBottom - rowGap - ringOuter;
    axialX   = G.panelLeft;
    leftX    = G.sideColumn / 2;
    rightX   = G.figW - G.sideColumn / 2;
    midY     = G.panelBottom + G.panelH / 2;
    upperY   = panelTop - 7;
    lowerY   = G.panelBottom + 7;

    % The sensorimotor maps sit over the anterior part of the axial slice
    % and the premotor maps over the start of the sagittal slice, so the
    % two rows spread across the width of the figure.
    %          name   centre x                  centre y   label
    slots = { 'L1',   leftX,                    upperY,    'above'; ...
              'L2',   leftX,                    lowerY,    'below'; ...
              'T1',   axialX + 0.66 * G.panelW, topY,      'above'; ...
              'T2',   axialX + 1.30 * G.panelW, topY,      'above'; ...
              'B1',   axialX + 0.66 * G.panelW, bottomY,   'below'; ...
              'B2',   axialX + 1.30 * G.panelW, bottomY,   'below'; ...
              'RC',   rightX,                   midY,      'above'; ...
              'R1',   rightX,                   upperY,    'above'; ...
              'R2',   rightX,                   lowerY,    'below'};
    G.slot = struct('name', slots(:, 1), 'x', slots(:, 2), 'y', slots(:, 3), ...
        'labelSide', slots(:, 4));
    G.labelGap = 1.2;                 % between the ring and its label
    G.statFontSize = 6;               % pt, the lines of numbers under a cluster name

    % Colour key of the topographies, bottom right corner.
    G.keyW = 22;
    G.keyH = 2;
    G.keyX = rightX - G.keyW / 2;
    G.keyY = 11;

    % Orientation cross in the bottom left corner of each slice.
    G.compassInset = 4.5;             % from the corner to the centre of the cross
    G.compassArm   = 1.2;

    % The arrows.
    G.arrowShaftWidth = 1.1;
    G.arrowHeadLength = 3.2;
    G.arrowHeadWidth  = 3.0;
    G.arrowStartGap   = 0.8;          % between the ring and the arrow's tail
    G.arrowTipGap     = 1.6;          % between the arrow's tip and the nearest dipole
    G.outlineColor    = [0.25 0.25 0.25];
    G.outlineWidth    = 0.25;         % pt, thin dark edge of the map disc and
                                      % of the colour key. Rings and arrows
                                      % carry no edge.

    % The dipoles.
    G.dipoleMarkerSize = 6;           % pt
    G.dipoleEdgeWidth  = 0.3;         % pt
    G.sharedShrink     = 0.5;         % size of the second colour of a shared dipole
end

function fig = draw_cluster_figure(C, spec, opts, p, mri)
    G = figure_geometry(p);
    have = {C.cluster.key};

    widthIn  = G.figW * p.plot.mmToInch;
    heightIn = G.figH * p.plot.mmToInch;
    fig = figure('Name', 'Supplementary figure: cortical clusters', ...
        'Color', [1 1 1], 'Units', 'inches', ...
        'Position', [0 0 widthIn heightIn], ...
        'PaperUnits', 'inches', 'PaperSize', [widthIn heightIn], ...
        'PaperPosition', [0 0 widthIn heightIn]);
    if isfield(p.plot, 'renderer')
        set(fig, 'Renderer', p.plot.renderer);
    end

    % One axes over the whole figure, in millimetres. Objects are drawn in
    % the order they are created, so later calls paint over earlier ones.
    ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0 0 1 1], ...
        'XLim', [0 G.figW], 'YLim', [0 G.figH], 'YDir', 'normal', ...
        'DataAspectRatio', [1 1 1], 'Visible', 'off', 'NextPlot', 'add');
    if isprop(ax, 'SortMethod')
        set(ax, 'SortMethod', 'childorder');
    end
    if isprop(ax, 'Clipping')
        set(ax, 'Clipping', 'off');
    end

    % White page behind everything, exactly the size of the figure.
    % exportgraphics crops a vector file tightly around the drawn objects,
    % and it cut into the lowest label. With this rectangle as the largest
    % object, the crop box is the whole 180 mm wide page and the margins in
    % FIGURE_GEOMETRY are the margins of the PDF.
    patch('Parent', ax, 'XData', [0 G.figW G.figW 0], 'YData', [0 0 G.figH G.figH], ...
        'FaceColor', [1 1 1], 'EdgeColor', 'none');

    % ---- the two slices ---------------------------------------------------
    panel = slice_panels(G);
    fprintf('Drawing the slices: axial z = %g mm, sagittal x = %g mm\n', ...
        opts.axialZ, opts.sagittalX);
    for k = 1:numel(panel)
        draw_slice(ax, panel(k), mri, opts, G, p);
    end

    % ---- the dipoles ------------------------------------------------------
    % Collected first for every cluster, because a component that sits in
    % two clusters has to be recognised before anything is drawn.
    nCluster = numel(spec);
    drawn = cell(nCluster, 1);
    mapped = cell(nCluster, 1);
    cluster = cell(nCluster, 1);
    for k = 1:nCluster
        ck = C.cluster(strcmp(have, spec(k).key));
        drawn{k}   = pick_set(ck, opts.dipoleSet);
        mapped{k}  = pick_set(ck, opts.topoSet);
        cluster{k} = ck;
    end
    repeatRank = shared_component_rank(drawn);

    % Drawn one by one in order of depth, so a dipole nearer to the viewer
    % covers one further away, whatever cluster each belongs to. The axial
    % slice is seen from above, so a higher dipole is drawn later. The
    % sagittal slice has anterior on the right, which is the view from the
    % right side, so a dipole further right is drawn later. The second
    % colour of a shared dipole follows its first colour directly.
    fprintf('Drawing the dipoles (%s set)\n', opts.dipoleSet);
    marks = zeros(0, 5);              % cluster, x, y, z, rank
    for k = 1:nCluster
        rank = repeatRank{k};
        if ~opts.showShared
            rank(:) = 1;
        end
        nRows = size(drawn{k}.posxyz, 1);
        marks = [marks; repmat(k, nRows, 1), drawn{k}.posxyz, rank(:)]; %#ok<AGROW>
    end
    for q = 1:numel(panel)
        if strcmp(panel(q).name, 'axial')
            depth = marks(:, 4);
        else
            depth = marks(:, 2);
        end
        [~, order] = sortrows([depth, marks(:, 5)]);
        [px, py] = project_to_panel(marks(order, 2:4), panel(q), G);
        for i = 1:numel(order)
            k = marks(order(i), 1);
            if marks(order(i), 5) > 1
                markerSize = G.dipoleMarkerSize * G.sharedShrink;
                edgeColor  = 'none';   % the first cluster's dot is its rim
            else
                markerSize = G.dipoleMarkerSize;
                edgeColor  = p.plot.dipoleEdgeColor;
            end
            line(px(i), py(i), 'Parent', ax, 'LineStyle', 'none', 'Marker', 'o', ...
                'MarkerSize', markerSize, 'MarkerFaceColor', spec(k).colour, ...
                'MarkerEdgeColor', edgeColor, 'LineWidth', G.dipoleEdgeWidth);
        end
    end
    nShared = sum(cellfun(@(r) nnz(r > 1), repeatRank));
    if nShared > 0 && opts.showShared
        fprintf(['  %d component(s) sit in more than one cluster and are drawn ' ...
                 'in both colours. Say so in the caption.\n'], nShared);
    elseif nShared > 0
        fprintf(['  %d component(s) sit in more than one cluster. Each is drawn ' ...
                 'at full size in both, so the later cluster hides the earlier.\n'], nShared);
    end

    % ---- the topographies, their rings, arrows and labels -----------------
    cmap = ersp_colormap(256);
    fprintf('Drawing the topographies\n');
    for k = 1:nCluster
        slot = G.slot(strcmp({G.slot.name}, spec(k).slot));
        if isempty(slot)
            error('draw_cluster_figure:UnknownSlot', ...
                'Cluster %s asks for slot %s, which FIGURE_GEOMETRY does not define.', ...
                spec(k).key, spec(k).slot);
        end
        target = panel(strcmp({panel.name}, spec(k).panel));
        if isempty(target)
            error('draw_cluster_figure:UnknownPanel', ...
                'Cluster %s points into panel %s. Use axial or sagittal.', ...
                spec(k).key, spec(k).panel);
        end

        [Z, headFraction] = cluster_scalp_map(C, mapped{k}, opts, p, G.topoPixels);
        draw_topography(ax, Z, cmap, slot, headFraction, G);

        [px, py] = project_to_panel(drawn{k}.posxyz, target, G);
        draw_arrow(ax, [slot.x, slot.y], [px(:), py(:)], spec(k).colour, G);
        draw_ring(ax, slot, spec(k).colour, G);
        draw_label(ax, slot, spec(k), cluster{k}, pick_set(cluster{k}, opts.labelSet), opts, p, G);

        fprintf('  %-26s %2d dipoles, slot %s, arrow into the %s slice\n', ...
            spec(k).key, size(drawn{k}.posxyz, 1), spec(k).slot, spec(k).panel);
    end

    if opts.showColorKey
        draw_color_key(ax, cmap, G, p);
    end
end

function S = pick_set(ck, setName)
    if strcmpi(setName, 'full')
        S = ck.full;
    elseif strcmpi(setName, 'analysed')
        S = ck.analysed;
    else
        error('pick_set:UnknownSet', ...
            'Unknown component set ''%s''. Use ''analysed'' or ''full''.', setName);
    end
end

function rank = shared_component_rank(drawn)
% For every drawn component, how many times the same (participant,
% component) pair has appeared so far, counting this one. 1 means first
% appearance. 2 means an earlier cluster already holds it.
    rank = cell(size(drawn));
    seen = zeros(0, 2);
    for k = 1:numel(drawn)
        pairs = [drawn{k}.subject(:), drawn{k}.ic(:)];
        rank{k} = ones(size(pairs, 1), 1);
        for i = 1:size(pairs, 1)
            rank{k}(i) = 1 + nnz(seen(:, 1) == pairs(i, 1) & seen(:, 2) == pairs(i, 2));
        end
        seen = [seen; pairs]; %#ok<AGROW>
    end
end

function panel = slice_panels(G)
% The two slices as rectangles on the page, each with the MNI range it
% shows. u runs along the page horizontally and v vertically.
%   axial     u = y (anterior to the right), v = -x (left hemisphere up)
%   sagittal  u = y (anterior to the right), v =  z (superior up)
    panel = struct('name', {'axial', 'sagittal'}, ...
        'x0', {G.panelLeft, G.panelLeft + G.panelW + G.panelGap}, ...
        'y0', {G.panelBottom, G.panelBottom}, ...
        'uRange', {G.yRange, G.yRange}, ...
        'vRange', {[-G.xHalf, G.xHalf], G.zRange});
end

function [px, py] = project_to_panel(posxyz, panel, G)
% MNI coordinates to page millimetres inside one slice panel.
    u = posxyz(:, 2);
    if strcmp(panel.name, 'axial')
        v = -posxyz(:, 1);
    else
        v = posxyz(:, 3);
    end
    px = panel.x0 + (u - panel.uRange(1)) * G.scale;
    py = panel.y0 + (v - panel.vRange(1)) * G.scale;
end

function draw_slice(ax, panel, mri, opts, G, p)
% One slice of the template as a true-colour image, so it does not depend
% on the figure colormap, with orientation letters at its edges.
    iy = find(mri.y >= panel.uRange(1) & mri.y <= panel.uRange(2));
    if strcmp(panel.name, 'axial')
        [~, iz] = min(abs(mri.z - opts.axialZ));
        ix = find(mri.x >= -panel.vRange(2) & mri.x <= -panel.vRange(1));
        slice = double(mri.anat(ix, iy, iz));     % rows x, ascending
        slice = slice(end:-1:1, :);               % rows v = -x, ascending
        v = -mri.x(ix(end:-1:1));
        note = sprintf('z = %g mm', mri.z(iz));
        letters = {'L', 'R', 'P', 'A'};           % up, down, left, right
    else
        [~, ixs] = min(abs(mri.x - opts.sagittalX));
        iz = find(mri.z >= panel.vRange(1) & mri.z <= panel.vRange(2));
        slice = double(squeeze(mri.anat(ixs, iy, iz))).';   % rows z, columns y
        v = mri.z(iz);
        note = sprintf('x = %g mm', mri.x(ixs));
        letters = {'S', 'I', 'P', 'A'};
    end
    u = mri.y(iy);

    gray = (slice / mri.maxValue) .^ G.mriGamma;
    if G.mriUpsample > 1
        [nRow, nCol] = size(gray);
        [colQ, rowQ] = meshgrid(linspace(1, nCol, (nCol - 1) * G.mriUpsample + 1), ...
                                linspace(1, nRow, (nRow - 1) * G.mriUpsample + 1));
        gray = interp2(gray, colQ, rowQ, 'cubic');
        gray = min(max(gray, 0), 1);
    end
    rgb  = repmat(gray, [1 1 3]);

    w = diff(panel.uRange) * G.scale;
    h = diff(panel.vRange) * G.scale;
    patch('Parent', ax, 'XData', panel.x0 + [0 w w 0], ...
        'YData', panel.y0 + [0 0 h h], 'FaceColor', [0 0 0], 'EdgeColor', 'none');

    xData = panel.x0 + ([u(1) u(end)] - panel.uRange(1)) * G.scale;
    yData = panel.y0 + ([v(1) v(end)] - panel.vRange(1)) * G.scale;
    hImg = image('Parent', ax, 'XData', xData, 'YData', yData, 'CData', rgb);
    if isprop(hImg, 'Interpolation')
        set(hImg, 'Interpolation', 'bilinear');
    end

    textArgs = {'Parent', ax, 'Color', [1 1 1], 'FontName', p.plot.fontName, ...
        'FontSize', p.plot.tickFontSize, 'Interpreter', 'none'};
    inset = 1.2;

    % Orientation cross in the bottom left corner, where the slice is empty.
    % Letters at the edges of the slice would sit under the arrows.
    cx = panel.x0 + G.compassInset;
    cy = panel.y0 + G.compassInset;
    arm = G.compassArm;
    line(cx + [-arm arm], [cy cy], 'Parent', ax, 'Color', [1 1 1], 'LineWidth', 0.4);
    line([cx cx], cy + [-arm arm], 'Parent', ax, 'Color', [1 1 1], 'LineWidth', 0.4);
    text(cx, cy + arm + 0.3, letters{1}, textArgs{:}, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    text(cx, cy - arm - 0.3, letters{2}, textArgs{:}, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    text(cx - arm - 0.5, cy, letters{3}, textArgs{:}, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
    text(cx + arm + 0.5, cy, letters{4}, textArgs{:}, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
    text(panel.x0 + inset, panel.y0 + h - inset, note, textArgs{:}, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
end

%% ------------------------------------------------------------------------
%  Scalp maps
%  ------------------------------------------------------------------------
function [Z, headFraction] = cluster_scalp_map(C, S, opts, p, nPixels)
% Mean scalp map of one cluster on an NPIXELS square grid, NaN outside the
% plotting disc, and the radius of the head outline as a fraction of the
% disc radius.
%
% Same recipe as the topography panels of Figures 3 and 4: every
% component's sign is arbitrary, so each map is flipped to agree with the
% map of largest norm before the mean is taken. The interpolation and the
% geometry are those of EEGLAB's topoplot: biharmonic spline (griddata
% 'v4') over the polar channel positions, plotted out to the outermost
% electrode, with the head outline at radius p.plot.topoHeadRad.

    % One plotting radius for every dataset, so all maps share a geometry.
    maxRadius = 0;
    for d = 1:numel(C.dataset)
        maxRadius = max(maxRadius, max(C.dataset(d).radius(isfinite(C.dataset(d).radius))));
    end
    plotrad = max(0.5, min(1.0, maxRadius * 1.02));
    if isfield(p.plot, 'topoPlotRad') && ~isempty(p.plot.topoPlotRad)
        plotrad = p.plot.topoPlotRad;
    end
    headFraction = p.plot.topoHeadRad / plotrad;

    used = unique(S.dataset);
    sameMontage = true;
    for d = used(:).'
        if ~isequal(C.dataset(d).labels, C.dataset(used(1)).labels)
            sameMontage = false;
        end
        if ~strcmpi(C.dataset(d).nosedir, '+X')
            warning('cluster_scalp_map:NoseDirection', ...
                ['Participant %d stores nose direction %s. The maps assume ' ...
                 '+X, the EEGLAB default.'], C.dataset(d).subject, C.dataset(d).nosedir);
        end
    end

    if sameMontage
        % Average at the channels, then interpolate once.
        maps = [S.map{:}];
        meanMap = polarity_aligned_mean(maps);
        geo = C.dataset(used(1));
        Z = interpolate_scalp_map(meanMap, geo.theta, geo.radius, plotrad, nPixels);
    else
        % Montages differ, so interpolate each component and average the
        % interpolated maps.
        n = numel(S.map);
        grids = nan(nPixels * nPixels, n);
        for i = 1:n
            geo = C.dataset(S.dataset(i));
            Zi = interpolate_scalp_map(S.map{i}, geo.theta, geo.radius, plotrad, nPixels);
            grids(:, i) = Zi(:);
        end
        inside = all(isfinite(grids), 2);
        meanInside = polarity_aligned_mean(grids(inside, :));
        Z = nan(nPixels, nPixels);
        Z(inside) = meanInside;
    end

    if strcmpi(opts.topoPolarity, 'peakPositive')
        values = Z(isfinite(Z));
        [~, iPeak] = max(abs(values));
        if values(iPeak) < 0
            Z = -Z;
        end
    end
end

function m = polarity_aligned_mean(maps)
% Mean over columns after resolving each column's arbitrary sign. The
% reference is the column with the largest norm. Identical to the function
% of the same name in plot_cluster_pair_figure.m.
    [~, refIdx] = max(sqrt(sum(maps.^2, 1)));
    ref = maps(:, refIdx);
    for i = 1:size(maps, 2)
        if dot(maps(:, i), ref) < 0
            maps(:, i) = -maps(:, i);
        end
    end
    m = mean(maps, 2);
end

function Z = interpolate_scalp_map(values, theta, radius, plotrad, nPixels)
% Channel values to a square grid, in topoplot's geometry. Theta is in
% degrees from the nose, positive towards the right ear. The grid spans
% [-0.5, 0.5] in both directions and 0.5 is the plotting radius. Rows run
% from the back of the head to the nose, columns from left to right.
    values = values(:).';
    ok = isfinite(theta) & isfinite(radius) & isfinite(values);
    th = theta(ok) * pi / 180;
    rd = radius(ok) * (0.5 / plotrad);
    towardsNose  = rd .* cos(th);
    towardsRight = rd .* sin(th);
    v = values(ok);

    g = linspace(-0.5, 0.5, nPixels);
    [H, V] = meshgrid(g, g);
    Z = griddata(towardsRight(:), towardsNose(:), v(:), H, V, 'v4');
    Z(sqrt(H.^2 + V.^2) > 0.5) = NaN;
end

function draw_topography(ax, Z, cmap, slot, headFraction, G)
% The scalp map as a true-colour image in a disc of radius G.topoRadius,
% white outside the disc, with the head outline, nose and ears on top.
    limit = max(abs(Z(isfinite(Z))));
    if isempty(limit) || limit == 0
        limit = 1;
    end
    nColor = size(cmap, 1);
    idx = round((Z + limit) / (2 * limit) * (nColor - 1)) + 1;
    outside = ~isfinite(idx);
    idx(outside) = 1;
    rgb = reshape(cmap(idx(:), :), [size(Z), 3]);
    rgb(repmat(outside, [1 1 3])) = 1;

    R = G.topoRadius;
    n = size(Z, 1);
    halfPixel = R / n;
    hImg = image('Parent', ax, ...
        'XData', slot.x + [-R + halfPixel, R - halfPixel], ...
        'YData', slot.y + [-R + halfPixel, R - halfPixel], 'CData', rgb);
    if isprop(hImg, 'Interpolation')
        set(hImg, 'Interpolation', 'bilinear');
    end

    % Head cartoon, with the proportions topoplot uses. Its coordinates are
    % in units where the plotting radius is 0.5, scaled here to millimetres.
    unit = R / 0.5;
    sf   = headFraction;                       % head radius / plotting radius

    % Contour lines of the map, as topoplot draws them. Vertices outside
    % the disc are dropped, so no line runs past the edge of the map.
    if G.topoContours > 0
        g = linspace(-0.5, 0.5, n);
        Cm = contourc(g, g, Z, G.topoContours);
        k = 1;
        while k < size(Cm, 2)
            nPoints = Cm(2, k);
            cx = Cm(1, k + (1:nPoints));
            cy = Cm(2, k + (1:nPoints));
            outsideDisc = sqrt(cx.^2 + cy.^2) > 0.5;
            cx(outsideDisc) = NaN;
            cy(outsideDisc) = NaN;
            line(slot.x + unit * cx, slot.y + unit * cy, 'Parent', ax, ...
                'Color', G.contourColor, 'LineWidth', G.contourWidth);
            k = k + nPoints + 1;
        end
    end
    lineArgs = {'Parent', ax, 'Color', [0 0 0], 'LineWidth', G.headLineWidth};

    t = linspace(0, 2*pi, 181);
    line(slot.x + unit * 0.5 * sf * cos(t), slot.y + unit * 0.5 * sf * sin(t), lineArgs{:});

    % Edge of the map disc. The ring no longer touches it, so the map needs
    % its own boundary against the white page.
    line(slot.x + R * cos(t), slot.y + R * sin(t), 'Parent', ax, ...
        'Color', G.outlineColor, 'LineWidth', G.outlineWidth);

    base = 0.5 - 0.0046;  basex = 0.18 * 0.5;  tip = 1.15 * 0.5;
    tiphw = 0.04 * 0.5;   tipr = 0.01 * 0.5;
    noseX = [basex, tiphw, 0, -tiphw, -basex] * sf;
    noseY = [base, tip - tipr, tip, tip - tipr, base] * sf;
    line(slot.x + unit * noseX, slot.y + unit * noseY, lineArgs{:});

    q = 0.04;
    earX = [0.497-0.005, 0.510, 0.518, 0.5299, 0.5419, 0.54, 0.547, 0.532, 0.510, 0.489-0.005] * sf;
    earY = [q+0.0555, q+0.0775, q+0.0783, q+0.0746, q+0.0555, -0.0055, -0.0932, -0.1313, -0.1384, -0.1199] * sf;
    line(slot.x + unit * earX, slot.y + unit * earY, lineArgs{:});
    line(slot.x - unit * earX, slot.y + unit * earY, lineArgs{:});
end

%% ------------------------------------------------------------------------
%  Rings, arrows, labels
%  ------------------------------------------------------------------------
function draw_ring(ax, slot, colour, G)
% Coloured ring around the scalp map, separated from it by a white gap. No
% edge line.
    t = linspace(0, 2*pi, 241);
    rIn  = G.topoRadius + G.ringGap;
    rOut = rIn + G.ringWidth;
    x = [rOut * cos(t), rIn * cos(t(end:-1:1))];
    y = [rOut * sin(t), rIn * sin(t(end:-1:1))];
    patch('Parent', ax, 'XData', slot.x + x, 'YData', slot.y + y, ...
        'FaceColor', colour, 'EdgeColor', 'none');
end

function draw_arrow(ax, centre, points, colour, G)
% Arrow from the ring towards the cluster's dipoles. It aims at their
% centroid and stops just short of the nearest dipole along that line, so
% the head never covers a dipole.
    target = mean(points, 1);
    along  = target - centre;
    reach  = sqrt(sum(along.^2));
    if reach < eps
        return
    end
    d = along / reach;
    n = [-d(2), d(1)];

    markerRadius = G.dipoleMarkerSize / 72 * 25.4 / 2;
    nearest = min((points - repmat(centre, size(points, 1), 1)) * d(:));
    tipAt   = nearest - markerRadius - G.arrowTipGap;
    startAt = G.topoRadius + G.ringGap + G.ringWidth + G.arrowStartGap;
    tipAt   = max(tipAt, startAt + G.arrowHeadLength + 1);

    tail = centre + startAt * d;
    tip  = centre + tipAt * d;
    neck = tip - G.arrowHeadLength * d;
    hs = G.arrowShaftWidth / 2;
    hh = G.arrowHeadWidth / 2;
    outline = [tail + hs * n; neck + hs * n; neck + hh * n; tip; ...
               neck - hh * n; neck - hs * n; tail - hs * n];
    patch('Parent', ax, 'XData', outline(:, 1), 'YData', outline(:, 2), ...
        'FaceColor', colour, 'EdgeColor', 'none');
end

function draw_color_key(ax, cmap, G, p)
% Colour scale shared by the topographies. Every map is scaled to its own
% largest absolute value, so the ends carry a sign and no number.
    n = size(cmap, 1);
    strip = repmat(reshape(cmap, [1 n 3]), [2 1 1]);
    image('Parent', ax, ...
        'XData', G.keyX + [G.keyW / (2 * n), G.keyW - G.keyW / (2 * n)], ...
        'YData', G.keyY + [G.keyH / 4, 3 * G.keyH / 4], 'CData', strip);
    line(G.keyX + [0 G.keyW G.keyW 0 0], G.keyY + [0 0 G.keyH G.keyH 0], ...
        'Parent', ax, 'Color', [0 0 0], 'LineWidth', G.outlineWidth);

    textArgs = {'Parent', ax, 'Color', [0 0 0], 'FontName', p.plot.fontName, ...
        'FontSize', p.plot.tickFontSize, 'Interpreter', 'none'};
    text(G.keyX, G.keyY - 0.6, 'negative', textArgs{:}, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
    text(G.keyX + G.keyW / 2, G.keyY - 0.6, '0', textArgs{:}, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    text(G.keyX + G.keyW, G.keyY - 0.6, 'positive', textArgs{:}, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
    text(G.keyX + G.keyW / 2, G.keyY + G.keyH + 0.6, 'Scalp projection (a.u.)', ...
        textArgs{:}, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end

function draw_label(ax, slot, specRow, ck, S, opts, p, G)
% Cluster name and, under it, the numbers that describe the cluster. Black
% text: the ring carries the colour.
%   n       participants with a component in the cluster
%   ICs     components the clustering assigned to the cluster, before one
%           per participant was retained
%   spread  root-mean-square distance of the drawn dipoles from their
%           centroid, mm
%   RV      mean residual variance of their dipole fits, percent
%   MNI     their centroid, x y z in mm
% S is the set chosen in opts.labelSet, every component of the cluster by
% default.
    nParticipants = numel(unique(ck.analysed.subject));
    nComponents   = numel(ck.full.ic);
    stats = cluster_statistics(S);
    c = round(stats.centroid);
    small = sprintf('\\rm\\fontsize{%g}', G.statFontSize);
    statLines = { ...
        sprintf('%s{\\itn} = %d, ICs = %d', small, nParticipants, nComponents), ...
        sprintf('%sspread = %.1f mm, RV = %.1f%%', small, stats.spread, stats.meanRV), ...
        sprintf('%sMNI (%s, %s, %s)', small, signed_integer(c(1), opts), ...
            signed_integer(c(2), opts), signed_integer(c(3), opts))};
    % Name in bold, counts in regular weight, through the TeX
    % interpreter. Characters that TeX would read as commands are escaped.
    nameLines = specRow.label(:).';
    for i = 1:numel(nameLines)
        nameLines{i} = ['\bf' regexprep(nameLines{i}, '([\\_^{}])', '\\$1')];
    end
    lines = [nameLines, statLines];

    offset = G.topoRadius + G.ringGap + G.ringWidth + G.labelGap;
    if strcmp(slot.labelSide, 'above')
        y = slot.y + offset;
        vAlign = 'bottom';
    else
        y = slot.y - offset;
        vAlign = 'top';
    end
    text(slot.x, y, lines, 'Parent', ax, 'Color', [0 0 0], ...
        'FontName', p.plot.fontName, 'FontSize', p.plot.fontSize, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', vAlign, ...
        'Interpreter', 'tex');
end

function t = signed_integer(v, opts)
% Integer as text, with the minus sign chosen in opts.minusSign.
    if v < 0
        t = [opts.minusSign sprintf('%d', abs(v))];
    else
        t = sprintf('%d', v);
    end
end
