function [STUDY, ALLEEG] = build_study_files(subject_list, ...
    epoched_folder, study_folder, ICs)
% BUILD_STUDY_FILES  Build the two main STUDY files.
%
%   [STUDY, ALLEEG] = build_study_files(subject_list, ...
%                         epoched_folder, study_folder)
%   [STUDY, ALLEEG] = build_study_files(..., ICs)
%
% Writes, into study_folder:
%
%   main_study_all_ICs_RV-15_epochedData.study
%       every component whose equivalent dipole lies inside the brain volume
%       and whose residual variance is at or below 15 percent
%
%   main_study_potential_brain_ICs_RV-15_epochedData.study
%       the subset of those that survived the ICLabel and manual screening
%
% The second file is the one that gets preclustered and clustered.
%
% Component selection, in order
% -----------------------------
%   1. std_editset with 'inbrain','on','dipselect',0.15
%   2. ICLabel: taken automatically when the highest-probability class is
%      Brain with probability above 0.5                        -> ICs{i,1}
%   3. a borderline pool, being everything whose highest-probability class is
%      Brain, Muscle or Other at probability 0.5 or below, each inspected in
%      pop_prop_extended and accepted or rejected by hand       -> ICs{i,3}
%
% Step 3 is a person's judgement and cannot be recomputed, so it ships as
% derived data. Omit the ICs argument and it is read by
% load_brain_ic_selection; pass it to override.
%
% Note on the previous version of this file
% -----------------------------------------
% It referenced ICs without taking it as an input and with the load line
% commented out, so it could only run when ICs happened to be in scope from
% an interactive session. That is why it is an argument now. Related, and
% worth knowing: review_components_gui receives ICs by value, edits its own copy
% and pushes the result to the base workspace with assignin, so the save at
% the end of screen_brain_components writes the table as it was *before* the
% manual inspection. The per-participant files the GUI writes are the
% trustworthy record.

    if nargin < 4
        ICs = load_brain_ic_selection(subject_list);
    end

    if ~exist(study_folder, 'dir')
        mkdir(study_folder);
    end


    %% Load the epoched datasets
    ALLEEG = [];
    for i = 1:numel(subject_list)

        file_name = ['sub-', num2str(subject_list(i)), ...
                     '_cleaned_with_ICA_epoched.set'];

        if ~exist(fullfile(epoched_folder, file_name), 'file')
            error('build_study_files:NoEpochedSet', ...
                ['sub-%d has no epoched dataset:\n  %s\n' ...
                 'Run epoching_timewarp.m first.'], ...
                subject_list(i), fullfile(epoched_folder, file_name));
        end

        EEG = pop_loadset('filename', file_name, 'filepath', epoched_folder);

        if ~isfield(EEG, 'timewarp') || isempty(EEG.timewarp)
            error('build_study_files:NoTimewarp', ...
                ['sub-%d has no EEG.timewarp. The ERSP precompute warps to ' ...
                 'it, so the STUDY is useless without it.'], subject_list(i));
        end

        [ALLEEG, EEG, ~] = eeg_store(ALLEEG, EEG, i); %#ok<ASGLU>
    end


    %% STUDY 1: every component with a brain dipole at RV <= 15 percent
    study_name_all = 'main_study_all_ICs_RV-15_epochedData.study';

    commands = cell(1, numel(subject_list));
    for i = 1:numel(subject_list)
        commands{i} = {'index', i, 'subject', ALLEEG(i).subject, ...
            'inbrain', 'on', 'dipselect', 0.15};
    end

    [STUDY, ALLEEG] = std_editset([], ALLEEG, ...
        'name', study_name_all, ...
        'filepath', study_folder, ...
        'commands', commands, ...
        'updatedat', 'on', 'savedat', 'off');

    [STUDY, ALLEEG] = pop_savestudy(STUDY, ALLEEG, ...
        'filename', study_name_all, 'filepath', study_folder);

    fprintf('\n%s: %d components across %d participants\n', ...
        study_name_all, numel(STUDY.cluster(1).comps), numel(subject_list));


    %% STUDY 2: reduce to the screened brain components
    % Build one keep mask over the whole parent cluster and apply it once.
    % The previous version deleted from STUDY.cluster.sets and .comps inside
    % the participant loop, which is easy to get wrong; this cannot shift
    % indices under itself.
    sets  = STUDY.cluster(1).sets;
    comps = STUDY.cluster(1).comps;
    keep  = false(1, numel(sets));

    setsPresent = unique(sets, 'stable');

    for iSet = setsPresent

        idx  = find(sets == iSet);
        rv15 = comps(idx);

        if iSet > size(ICs, 1)
            error('build_study_files:SelectionTooShort', ...
                ['The brain component selection has %d rows but the STUDY ' ...
                 'has a dataset at index %d.'], size(ICs, 1), iSet);
        end

        accepted = [ICs{iSet, 1}(:); ICs{iSet, 3}(:)];

        if isempty(accepted)
            error('build_study_files:NoAcceptedComponents', ...
                ['No accepted brain component for dataset %d (sub-%d). ' ...
                 'That participant would vanish from every cluster.'], ...
                iSet, subject_list(iSet));
        end

        inSelection = ismember(rv15, accepted);
        keep(idx(inSelection)) = true;

        % Keep datasetinfo consistent with the parent cluster.
        STUDY.datasetinfo(iSet).comps = rv15(inSelection);

        fprintf('  sub-%-3d  %3d of %3d RV<=15%% components kept\n', ...
            subject_list(iSet), sum(inSelection), numel(rv15));
    end

    STUDY.cluster(1).sets  = sets(keep);
    STUDY.cluster(1).comps = comps(keep);


    %% Save STUDY 2
    study_name_brain = 'main_study_potential_brain_ICs_RV-15_epochedData.study';
    STUDY.name = study_name_brain;

    [STUDY, ALLEEG] = pop_savestudy(STUDY, ALLEEG, ...
        'filename', study_name_brain, 'filepath', study_folder);

    fprintf('\n%s: %d components across %d participants\n', ...
        study_name_brain, numel(STUDY.cluster(1).comps), numel(setsPresent));
    fprintf('This is the STUDY to precluster and cluster.\n');

end