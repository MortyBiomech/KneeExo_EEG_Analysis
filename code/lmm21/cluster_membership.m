function [subjects, ics] = cluster_membership(src, clusterName, cfg)
%CLUSTER_MEMBERSHIP  Participants and their component index in one cluster.
%
%  [subjects, ics] = CLUSTER_MEMBERSHIP(src, clusterName, cfg) returns the
%  participant numbers present in that cluster and, for each, the index of
%  the single component used. Both are column vectors of the same length.
%
%  THIS IS THE THIRD ADAPTER. It knows the shape of Subjects_ICs_in_clusters.mat.
%
%  One component per participant. The reduction happens upstream, in
%  oneSubPerCluster, so the stored file already holds exactly one component
%  per participant per cluster. This function performs no selection of its
%  own, and it fails rather than guessing if it finds two entries for the same
%  participant, because a silent pick here would be a selection criterion that
%  appears nowhere in the Methods.
%
%  Participant numbering. Cluster membership is stored with a cluster internal
%  index into the STUDY participant list, so the participant number is
%  cfg.subjectList(index). The original cross correlation code hard coded this
%  as index + 4, which is the same thing only while the participant list
%  happens to start at 5. It is derived here instead.
%
%  Accepted shapes for src, a path to the .mat file or its loaded contents:
%
%    1. struct keyed by cluster name, each with fields Subjects and ICs, where
%       Subjects already holds participant numbers. Preferred.
%    2. cell array, one entry per cluster, each with fields Subjects and ICs,
%       plus a parallel list of cluster names in src.names or in a variable
%       called clusterNames. Subjects is then the cluster internal index.
%
%  See also BUILD_EEG_FEATURE_TABLE.

if ischar(src) || isstring(src)
    f = char(src);
    if exist(f, 'file') ~= 2
        error('cluster_membership:missing', ...
            'Cluster membership file not found: %s', f);
    end
    src = load(f);
end

entry = [];
internalIndex = false;

if isstruct(src) && isfield(src, clusterName)
    entry = src.(clusterName);

elseif isstruct(src) && isscalar(src)
    % A wrapper struct from load(). Look one level down.
    f = fieldnames(src);
    for i = 1:numel(f)
        v = src.(f{i});
        if isstruct(v) && isfield(v, clusterName)
            entry = v.(clusterName);
            break
        end
        if iscell(v)
            [entry, internalIndex] = fromCell(v, src, clusterName);
            if ~isempty(entry), break; end
        end
    end

elseif iscell(src)
    [entry, internalIndex] = fromCell(src, [], clusterName);
end

if isempty(entry)
    error('cluster_membership:notFound', ...
        ['Cluster %s was not found in the membership file. Check that the ' ...
         'names in cfg.clusters match the names used by the clustering ' ...
         'solutions exactly.'], clusterName);
end

if ~isfield(entry, 'Subjects') || ~isfield(entry, 'ICs')
    error('cluster_membership:fields', ...
        ['Cluster %s has fields %s. Subjects and ICs are required.'], ...
        clusterName, strjoin(fieldnames(entry)', ', '));
end

subjects = double(entry.Subjects(:));
ics      = double(entry.ICs(:));

if numel(subjects) ~= numel(ics)
    error('cluster_membership:length', ...
        'Cluster %s has %d participants and %d components.', ...
        clusterName, numel(subjects), numel(ics));
end

% Numbering. This is stated in the configuration and checked here. It is not
% inferred, because a cluster holding only participants 5 to 14 reads the same
% under either convention, and the wrong reading shifts every participant by a
% constant without stopping the run.
asIndices = cfg.clusterSubjectsAreIndices || internalIndex;

if asIndices
    if any(subjects < 1) || any(subjects > numel(cfg.subjectList)) || ...
            any(mod(subjects, 1) ~= 0)
        error('cluster_membership:badIndex', ...
            ['Cluster %s: Subjects is being read as an index into ' ...
             'cfg.subjectList (%d entries) but holds %s. Set ' ...
             'cfg.clusterSubjectsAreIndices to false if the file stores ' ...
             'participant numbers.'], ...
            clusterName, numel(cfg.subjectList), mat2str(subjects(:).'));
    end
    subjects = reshape(cfg.subjectList(subjects), [], 1);
end

bad = ~ismember(subjects, cfg.subjectList);
if any(bad)
    error('cluster_membership:unknownSubject', ...
        ['Cluster %s lists participants %s, which are not in cfg.subjectList. ' ...
         'If the file stores an index rather than a participant number, set ' ...
         'cfg.clusterSubjectsAreIndices to true.'], ...
        clusterName, mat2str(subjects(bad).'));
end

if cfg.verbose
    fprintf('[cluster_membership] %s: participants %s\n', ...
        clusterName, mat2str(subjects(:).'));
end

[u, ~, g] = unique(subjects);
if numel(u) ~= numel(subjects)
    counts = accumarray(g, 1);
    dup = u(counts > 1);
    error('cluster_membership:multipleICs', ...
        ['Cluster %s lists more than one component for participant(s) %s. ' ...
         'The one component per participant reduction should have happened ' ...
         'upstream in oneSubPerCluster. Picking one here would be an ' ...
         'undocumented selection criterion.'], clusterName, mat2str(dup(:).'));
end

subjects = subjects(:);
ics      = ics(:);

end

% =========================================================================
function [entry, internalIndex] = fromCell(c, wrapper, clusterName)
entry = [];
internalIndex = true;

names = [];
if ~isempty(wrapper)
    for f = {'names', 'clusterNames', 'studyNames'}
        if isfield(wrapper, f{1})
            names = wrapper.(f{1});
            break
        end
    end
end

if isempty(names)
    return
end

names = string(names(:));
hit = find(strcmpi(names, clusterName) | ...
           strcmpi(strrep(names, ' ', '_'), clusterName), 1);
if isempty(hit) || hit > numel(c)
    return
end

entry = c{hit};
end
