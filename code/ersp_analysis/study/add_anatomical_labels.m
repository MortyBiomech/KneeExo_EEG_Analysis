function STUDY = add_anatomical_labels(STUDY, eeglabPath)
% ADD_ANATOMICAL_LABELS  Label each cluster with an AAL anatomical region.
%
%   STUDY = ADD_ANATOMICAL_LABELS(STUDY, EEGLABPATH)
%
% Looks up each cluster's dipole centroid in the AAL atlas (ROI_MNI_V4.nii,
% shipped with the FieldTrip plugin inside EEGLAB) and writes the most
% frequently hit region name into STUDY.cluster(k).label. The centroids are
% also collected into STUDY.etc.centroids and the label table into
% STUDY.etc.atlas_labels.
%
% Clusters 1 and 2 are EEGLAB's parent and outlier clusters and are skipped.
%
% Changes from the original:
%   * the per-cluster lookup was wrapped in a TRY with an empty CATCH, so a
%     failed lookup left that cluster's entry undefined and the failure
%     invisible. Failures are now caught, reported, and labelled 'unknown'.
%   * an ERROR was followed by an unreachable RETURN.
%   * paths were built by string concatenation with backslashes; they now go
%     through FULLFILE.
%   * the FieldTrip plugin folder was matched case-sensitively.

    FIRST_REAL_CLUSTER = 3;

    nClusters = numel(STUDY.cluster);
    if nClusters < FIRST_REAL_CLUSTER
        warning('add_anatomical_labels:NoClusters', ...
            'STUDY has no clusters beyond parent and outlier; nothing to label.');
        return
    end

    clusterIdx = FIRST_REAL_CLUSTER:nClusters;

    STUDY.etc.centroids = [];
    for k = 1:numel(clusterIdx)
        dip = STUDY.cluster(clusterIdx(k)).dipole;
        STUDY.etc.centroids(k).posxyz = dip.posxyz;
        STUDY.etc.centroids(k).momxyz = dip.momxyz;
        STUDY.etc.centroids(k).rv     = dip.rv;
    end

    ft_defaults;

    ftPath = locate_fieldtrip_plugin(eeglabPath);
    atlasFile = fullfile(ftPath, 'template', 'atlas', 'aal', 'ROI_MNI_V4.nii');
    if ~isfile(atlasFile)
        error('add_anatomical_labels:NoAtlas', ...
            'AAL atlas not found at:\n  %s', atlasFile);
    end
    atlas = ft_read_atlas(atlasFile);

    centroidMNI = reshape([STUDY.etc.centroids.posxyz], 3, [])';

    atlasNames = cell(size(centroidMNI, 1), 2);
    for k = 1:size(centroidMNI, 1)
        atlasNames{k,1} = sprintf('CLs %d', clusterIdx(k));
        try
            cfg = [];
            cfg.roi        = centroidMNI(k,:);
            cfg.output     = 'multiple';
            cfg.atlas      = atlas;
            cfg.inputcoord = 'mni';
            cfg.sphere     = 1;

            hits = ft_volumelookup(cfg, atlas);
            [nHits, best] = max(hits.count);

            if nHits == 0
                atlasNames{k,2} = {'unknown'};
            else
                atlasNames{k,2} = hits.name(best);
            end
        catch ME
            warning('add_anatomical_labels:LookupFailed', ...
                'Atlas lookup failed for cluster %d (%s); labelling ''unknown''.', ...
                clusterIdx(k), ME.message);
            atlasNames{k,2} = {'unknown'};
        end
    end

    fprintf('\nCluster \t\t Label\n');
    fprintf('________________________\n');
    for k = 1:size(centroidMNI, 1)
        label = cellstr(atlasNames{k,2});
        fprintf('%s\t\t%s\n', atlasNames{k,1}, label{1});
        STUDY.cluster(clusterIdx(k)).label = label;
    end

    STUDY.etc.atlas_labels = atlasNames;
end


function ftPath = locate_fieldtrip_plugin(eeglabPath)
% Find the FieldTrip plugin folder inside an EEGLAB installation.
    pluginRoot = fullfile(eeglabPath, 'plugins');
    if ~isfolder(pluginRoot)
        error('add_anatomical_labels:NoPluginFolder', ...
            'No plugins folder under:\n  %s', eeglabPath);
    end

    entries = dir(pluginRoot);
    entries = entries([entries.isdir]);
    match = find(contains({entries.name}, 'fieldtrip', 'IgnoreCase', true), 1);

    if isempty(match)
        error('add_anatomical_labels:NoFieldtrip', ...
            ['The FieldTrip plugin is not installed in EEGLAB.\n' ...
             'Looked in: %s\n' ...
             'Install it from the EEGLAB plugin manager.'], pluginRoot);
    end

    ftPath = fullfile(pluginRoot, entries(match).name);
end
