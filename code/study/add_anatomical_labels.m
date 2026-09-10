function STUDY = add_anatomical_labels(STUDY, atlas_file)
% ADD_ANATOMICAL_LABELS  Name each cluster from the AAL atlas.
%
%   STUDY = add_anatomical_labels(STUDY)
%   STUDY = add_anatomical_labels(STUDY, atlas_file)
%
% Looks each cluster centroid up in the Automated Anatomical Labeling atlas
% (Tzourio-Mazoyer et al., 2002) with a 1 mm sphere, and writes the most
% frequent label into STUDY.cluster(CL).label. The full table also goes into
% STUDY.etc.atlas_labels and the centroids into STUDY.etc.centroids.
%
% WHICH COMPONENTS THE CENTROID DESCRIBES
% ---------------------------------------
% This reads STUDY.cluster(CL).dipole.posxyz, the centroid over every
% component in the cluster. If keep_one_ic_per_subject has already run, the
% cluster still carries the FULL-cluster centroid, because that function does
% not recompute it. So the label and the coordinates describe a different set
% of components than the ERSPs do.
%
% Call this before the reduction and describe the coordinates as full-cluster
% centroids, or recompute the centroids afterwards with bemobil_dipoles. Say
% which in the Methods.
%
% Clusters 1 and 2 are skipped: they are the parent and the outlier cluster.
%
% atlas_file defaults to the AAL atlas that ships with the FieldTrip plugin
% inside EEGLAB, or with a standalone FieldTrip.

    %% Locate the atlas
    if nargin < 2 || isempty(atlas_file)
        atlas_file = locate_aal_atlas();
    end

    if ~exist(atlas_file, 'file')
        error('add_anatomical_labels:NoAtlas', ...
            ['The AAL atlas was not found at\n  %s\n\nIt ships with ' ...
             'FieldTrip, under template/atlas/aal/ROI_MNI_V4.nii. Install ' ...
             'the FieldTrip plugin in EEGLAB, or pass the path.'], atlas_file);
    end

    ft_defaults;
    atlas = ft_read_atlas(atlas_file);


    %% Collect the centroids
    firstCluster = 3;
    nClusters = numel(STUDY.cluster);

    STUDY.etc.centroids = [];
    x = 0;
    for CL = firstCluster:nClusters
        x = x + 1;
        STUDY.etc.centroids(x).posxyz = STUDY.cluster(CL).dipole.posxyz;
        STUDY.etc.centroids(x).momxyz = STUDY.cluster(CL).dipole.momxyz;
        STUDY.etc.centroids(x).rv     = STUDY.cluster(CL).dipole.rv;
    end

    coords = reshape([STUDY.etc.centroids.posxyz], 3, [])';


    %% Look each one up
    Atlas_name = cell(size(coords, 1), 2);

    for i = 1:size(coords, 1)

        CL = firstCluster + i - 1;
        Atlas_name{i, 1} = ['CLs ', num2str(CL)];

        try
            cfgLookup            = [];
            cfgLookup.roi        = coords(i, :);
            cfgLookup.output     = 'multiple';
            cfgLookup.atlas      = atlas;
            cfgLookup.inputcoord = 'mni';
            cfgLookup.sphere     = 1;

            labels = ft_volumelookup(cfgLookup, atlas);
            [~, best] = max(labels.count);
            Atlas_name{i, 2} = labels.name(best);

        catch err
            % The previous version swallowed this with a bare try and no
            % catch, which left the table short and made the printing loop
            % below fail with an unrelated error.
            warning('add_anatomical_labels:LookupFailed', ...
                'Cluster %d at %s could not be looked up: %s', ...
                CL, mat2str(round(coords(i, :))), err.message);
            Atlas_name{i, 2} = {'(lookup failed)'};
        end

    end


    %% Report and store
    fprintf('\n%-8s %-18s %s\n', 'Cluster', 'Centroid (MNI)', 'AAL label');
    fprintf('%s\n', repmat('-', 1, 60));

    for i = 1:size(coords, 1)
        CL = firstCluster + i - 1;
        label = cellstr(Atlas_name{i, 2});
        fprintf('%-8d %-18s %s\n', CL, mat2str(round(coords(i, :))), label{1});
        STUDY.cluster(CL).label = label;
    end
    fprintf('\n');

    STUDY.etc.atlas_labels = Atlas_name;

end


% ------------------------------------------------------------------------
function f = locate_aal_atlas()
% Find ROI_MNI_V4.nii in whatever FieldTrip is available.
%
% The previous version searched the EEGLAB plugins folder for a name
% containing 'Fieldtrip', case sensitively. EEGLAB ships the plugin as
% 'Fieldtrip-lite<version>' in some releases and 'fieldtrip' in others, so
% that test could miss a perfectly good installation.

    relative = fullfile('template', 'atlas', 'aal', 'ROI_MNI_V4.nii');

    % A FieldTrip that is already on the path.
    ftDefaults = which('ft_defaults');
    if ~isempty(ftDefaults)
        candidate = fullfile(fileparts(ftDefaults), relative);
        if exist(candidate, 'file')
            f = candidate;
            return
        end
    end

    % A FieldTrip plugin inside EEGLAB, under any capitalisation.
    eeglabFile = which('eeglab');
    if ~isempty(eeglabFile)
        pluginRoot = fullfile(fileparts(eeglabFile), 'plugins');
        listing = dir(pluginRoot);
        listing = listing([listing.isdir]);
        match = contains(lower({listing.name}), 'fieldtrip');
        for k = find(match)
            candidate = fullfile(pluginRoot, listing(k).name, relative);
            if exist(candidate, 'file')
                f = candidate;
                return
            end
        end
    end

    % Nothing found. Return the most likely path so the caller's error names
    % something concrete.
    f = fullfile('<fieldtrip>', relative);

end