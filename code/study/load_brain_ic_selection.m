function ICs = load_brain_ic_selection(subject_list, selection_folder)
% LOAD_BRAIN_IC_SELECTION  Read the curated brain component selection.
%
%   ICs = load_brain_ic_selection(subject_list)
%   ICs = load_brain_ic_selection(subject_list, selection_folder)
%
% Returns an nSets x 3 cell array, indexed by position in subject_list:
%
%   ICs{i,1}  components ICLabel called Brain with probability above 0.5
%   ICs{i,2}  the borderline pool that was inspected by hand
%   ICs{i,3}  the borderline components that were accepted
%
% The set that enters clustering is [ICs{i,1}; ICs{i,3}].
%
% Why this function exists
% ------------------------
% Column 3 is produced by review_components_gui, one component at a time, by a
% person looking at pop_prop_extended. It cannot be recomputed. It is
% therefore treated the same way as the flexion and extension events: the
% decisions are shipped as derived data and read back from disk.
%
% Two layouts are accepted, in this order:
%
%   1. one combined file
%        <folder>/Brain_PotentialBrain_AcceptedPotentialBrain.mat   variable ICs
%   2. one file per participant, as review_components_gui writes them
%        <folder>/sub-<N>/Brain_ICs_50percentUp - Accepted_potential_Brain_ICs - sub-<N>.mat
%      each holding brain_ICs = { column1, column3 }
%
% If selection_folder is omitted, the repository's
% derived_data/brain_ic_selection/ is used.

    if nargin < 2 || isempty(selection_folder)
        cfgFile = which('kneeexo_config');
        if isempty(cfgFile)
            error('load_brain_ic_selection:NoConfig', ...
                ['config/kneeexo_config.m is not on the MATLAB path, so the ' ...
                 'repository root cannot be found. Pass selection_folder ' ...
                 'explicitly.']);
        end
        repoRoot = fileparts(fileparts(cfgFile));
        selection_folder = fullfile(repoRoot, 'derived_data', 'brain_ic_selection');
    end

    nSets = numel(subject_list);
    ICs = cell(nSets, 3);

    %% Layout 1: one combined file
    combined = fullfile(selection_folder, ...
        'Brain_PotentialBrain_AcceptedPotentialBrain.mat');

    if exist(combined, 'file')
        loaded = load(combined, 'ICs');
        ICs = loaded.ICs;

        if size(ICs, 1) < nSets
            error('load_brain_ic_selection:TooFewRows', ...
                ['%s holds %d rows but %d participants were requested.'], ...
                combined, size(ICs, 1), nSets);
        end

        if size(ICs, 2) < 3 || all(cellfun(@isempty, ICs(1:nSets, 3)))
            error('load_brain_ic_selection:EmptyAcceptedColumn', ...
                ['%s has an empty third column, so it was saved before the ' ...
                 'manual inspection was applied. See the note in ' ...
                 'review_components_gui: the GUI edits its own copy and pushes ' ...
                 'the result to the base workspace, so a save made by the ' ...
                 'calling function stores the pre-inspection table. Rebuild ' ...
                 'the combined file from the per-participant files instead.'], ...
                combined);
        end

        report(ICs, subject_list, combined);
        return
    end

    %% Layout 2: one file per participant
    found = 0;
    for i = 1:nSets
        sub = subject_list(i);
        f = fullfile(selection_folder, ['sub-', num2str(sub)], ...
            ['Brain_ICs_50percentUp - Accepted_potential_Brain_ICs - sub-', ...
             num2str(sub), '.mat']);

        if ~exist(f, 'file')
            continue
        end

        loaded = load(f, 'brain_ICs');
        ICs{i, 1} = loaded.brain_ICs{1}(:);
        ICs{i, 3} = loaded.brain_ICs{2}(:);
        found = found + 1;
    end

    if found == 0
        error('load_brain_ic_selection:NothingFound', ...
            ['No brain component selection found under\n  %s\n\n' ...
             'This selection was made by hand, one component at a time, and ' ...
             'cannot be recomputed. It ships as derived data. Copy it into ' ...
             'that folder, or pass selection_folder. See README.'], ...
            selection_folder);
    end

    if found < nSets
        missing = subject_list(cellfun(@isempty, ICs(:,1)) & ...
                               cellfun(@isempty, ICs(:,3)));
        error('load_brain_ic_selection:IncompleteSelection', ...
            ['Selection found for %d of %d participants. Missing: %s\n' ...
             'Running with a partial selection would silently drop those ' ...
             'participants from every cluster.'], ...
            found, nSets, mat2str(missing));
    end

    report(ICs, subject_list, selection_folder);

end


% ------------------------------------------------------------------------
function report(ICs, subject_list, src)
% Print what was loaded, so a truncated or stale selection is visible before
% hours of clustering rather than after.

    fprintf('Brain component selection read from\n  %s\n', src);
    fprintf('%-8s %8s %10s %8s\n', 'subject', 'ICLabel', 'accepted', 'total');
    for i = 1:numel(subject_list)
        n1 = numel(ICs{i,1});
        n3 = numel(ICs{i,3});
        fprintf('sub-%-4d %8d %10d %8d\n', subject_list(i), n1, n3, n1 + n3);
    end
    total = sum(cellfun(@numel, ICs(1:numel(subject_list), 1))) + ...
            sum(cellfun(@numel, ICs(1:numel(subject_list), 3)));
    fprintf('%-8s %8s %10s %8d\n', 'all', '', '', total);

end