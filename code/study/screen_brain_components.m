function ICs = screen_brain_components(subject_list, ALLEEG, STUDY, out_folder)
% SCREEN_BRAIN_COMPONENTS  Decide which components are brain sources.
%
%   ICs = screen_brain_components(subject_list, ALLEEG, STUDY)
%   ICs = screen_brain_components(subject_list, ALLEEG, STUDY, out_folder)
%
% Runs on the components that already survived the dipole screening in
% build_study_files, that is, an equivalent dipole inside the brain volume
% with residual variance at or below 15 percent.
%
% Two tiers, using ICLabel (Pion-Tonachini et al., 2019):
%
%   ICs{i,1}  taken automatically: highest-probability class is Brain, with
%             probability above 0.5
%   ICs{i,2}  the borderline pool, inspected one component at a time: the top
%             class is Brain, Muscle or Other at probability 0.5 or below
%   ICs{i,3}  the borderline components a person accepted
%
% What enters clustering is [ICs{i,1}; ICs{i,3}]. A component that ICLabel
% confidently called muscle, eye, heart, line noise or channel noise never
% reaches the pool at all.
%
% THIS IS THE MANUAL STEP OF THE GROUP STAGE. It opens
% review_components_gui and waits. The result ships as derived data, and
% load_brain_ic_selection reads it back, so you only run this for a
% participant nobody has screened yet.
%
% Rows are indexed by position in ALLEEG, so row 1 is the first participant in
% subject_list, not participant number 1.
%
% Writes <out_folder>/Brain_PotentialBrain_AcceptedPotentialBrain.mat and, per
% participant, the accepted and rejected component images that make the
% decisions auditable.
%
% Renamed from cortical_ICs_indentifier. The previous version passed ICs to
% the GUI by value and then saved its own untouched copy, so the file it wrote
% had an empty third column; the accepted components only reached the base
% workspace through assignin. The GUI now returns them.

    if nargin < 4 || isempty(out_folder)
        cfg = kneeexo_config();
        out_folder = fullfile(cfg.derived, 'brain_ic_selection');
    end

    if ~exist(out_folder, 'dir')
        mkdir(out_folder);
    end

    nSets = numel(ALLEEG);
    if nSets ~= numel(subject_list)
        error('screen_brain_components:ListMismatch', ...
            ['ALLEEG holds %d datasets but subject_list has %d entries. The ' ...
             'rows of ICs are indexed by position, so the two must agree.'], ...
            nSets, numel(subject_list));
    end

    ICs = cell(nSets, 3);


    %% Automatic tier
    % ICLabel classes: 1 Brain, 2 Muscle, 3 Eye, 4 Heart, 5 Line Noise,
    % 6 Channel Noise, 7 Other.
    BRAIN = 1; MUSCLE = 2; OTHER = 7;
    confident = 0.5;

    fprintf('%-8s %8s %10s\n', 'subject', 'ICLabel', 'to review');

    for i = 1:nSets

        if ~isfield(ALLEEG(i).etc, 'ic_classification')
            error('screen_brain_components:NoICLabel', ...
                ['Dataset %d (sub-%d) has no ICLabel classification. Run ' ...
                 'ICLabel before screening.'], i, subject_list(i));
        end

        P = ALLEEG(i).etc.ic_classification.ICLabel.classifications;

        % Only the components that survived the dipole screening.
        surviving = STUDY.datasetinfo(i).comps;
        P = P(surviving, :);

        [pBest, classBest] = max(P, [], 2);

        isBrainConfident = classBest == BRAIN & pBest > confident;
        ICs{i, 1} = surviving(isBrainConfident)';

        % Borderline: the top class is Brain, Muscle or Other but weakly so.
        borderline = ismember(classBest, [BRAIN, MUSCLE, OTHER]) & ...
                     pBest <= confident;
        ICs{i, 2} = surviving(borderline)';

        fprintf('sub-%-4d %8d %10d\n', subject_list(i), ...
            numel(ICs{i, 1}), numel(ICs{i, 2}));

    end


    %% Manual tier
    fprintf(['\nOpening the component review GUI. Go through every ' ...
             'participant, then press Save.\n']);

    ICs = review_components_gui(ALLEEG, ICs, subject_list, out_folder);


    %% Store
    outFile = fullfile(out_folder, ...
        'Brain_PotentialBrain_AcceptedPotentialBrain.mat');
    save(outFile, 'ICs');

    fprintf('\n%-8s %8s %10s %8s\n', 'subject', 'ICLabel', 'accepted', 'total');
    for i = 1:nSets
        n1 = numel(ICs{i, 1});
        n3 = numel(ICs{i, 3});
        fprintf('sub-%-4d %8d %10d %8d\n', subject_list(i), n1, n3, n1 + n3);
    end
    fprintf('\nWritten to %s\n', outFile);

end