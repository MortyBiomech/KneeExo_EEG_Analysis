function ICs = review_components_gui(ALLEEG, ICs, subject_list, out_folder)
% REVIEW_COMPONENTS_GUI  Accept or reject the borderline components by eye.
%
%   ICs = review_components_gui(ALLEEG, ICs, subject_list, out_folder)
%
% Walks through ICs{i,2}, the components ICLabel was unsure about, one at a
% time. Plot shows the component in pop_prop_extended; Accept or Reject
% records the decision and saves the figure as evidence; Skip leaves it
% undecided. The accepted ones are returned in ICs{i,3}.
%
% The function blocks until the window is closed, and returns the table it
% built. The previous version did not: it edited a local copy and pushed the
% result to the base workspace with assignin, so the caller kept the
% pre-review table and saved that instead. That is why shipped copies of
% Brain_PotentialBrain_AcceptedPotentialBrain.mat can have an empty third
% column.
%
% Per-participant evidence written under out_folder/sub-<N>/:
%   accepted_subject_<N>_IC_<k>.png
%   rejected_subject_<N>_IC_<k>.png
%   Brain_ICs_50percentUp - Accepted_potential_Brain_ICs - sub-<N>.mat
%
% Those images are the audit trail for a decision that cannot be recomputed.
% Keep them with the derived data.

    if nargin < 4 || isempty(out_folder)
        cfg = kneeexo_config();
        out_folder = fullfile(cfg.derived, 'brain_ic_selection');
    end

    nSets = numel(subject_list);

    accepted = cell(nSets, 1);
    rejected = cell(nSets, 1);
    for i = 1:nSets
        accepted{i} = ICs{i, 3};   % may already hold a previous pass
        rejected{i} = [];
    end

    iSub = 1;
    iIC  = 1;

    fig = uifigure('Name', 'Brain component review', ...
        'Position', [200, 200, 460, 520]);

    uilabel(fig, 'Text', 'Participant', 'Position', [25, 470, 80, 22]);
    subjectDropdown = uidropdown(fig, ...
        'Items', arrayfun(@(s) sprintf('sub-%d', s), subject_list, ...
                          'UniformOutput', false), ...
        'Position', [110, 470, 100, 22], ...
        'ValueChangedFcn', @(src, ~) onSubjectChange(src));

    progressLabel = uilabel(fig, 'Text', '', 'Position', [230, 470, 200, 22]);

    uilabel(fig, 'Text', 'Component', 'Position', [25, 435, 80, 22]);
    icLabel = uilabel(fig, 'Text', '', 'Position', [110, 435, 300, 22]);

    uibutton(fig, 'Text', 'Previous', 'Position', [25, 395, 80, 26], ...
        'ButtonPushedFcn', @(~, ~) step(-1));
    uibutton(fig, 'Text', 'Next', 'Position', [115, 395, 80, 26], ...
        'ButtonPushedFcn', @(~, ~) step(+1));
    uibutton(fig, 'Text', 'Plot', 'Position', [205, 395, 80, 26], ...
        'ButtonPushedFcn', @(~, ~) plotCurrent());

    uilabel(fig, 'Text', 'Rejected', 'Position', [25, 355, 100, 22]);
    rejectedList = uilistbox(fig, 'Items', {}, 'Position', [25, 195, 180, 160]);

    uilabel(fig, 'Text', 'Accepted', 'Position', [250, 355, 100, 22]);
    acceptedList = uilistbox(fig, 'Items', {}, 'Position', [250, 195, 180, 160]);

    uibutton(fig, 'Text', 'Reject', 'Position', [25, 145, 90, 30], ...
        'ButtonPushedFcn', @(~, ~) decide(false));
    uibutton(fig, 'Text', 'Skip', 'Position', [125, 145, 90, 30], ...
        'ButtonPushedFcn', @(~, ~) closePlots());
    uibutton(fig, 'Text', 'Accept', 'Position', [225, 145, 90, 30], ...
        'ButtonPushedFcn', @(~, ~) decide(true));

    uibutton(fig, 'Text', 'Save and close', 'Position', [250, 90, 180, 32], ...
        'ButtonPushedFcn', @(~, ~) saveAndClose());

    uilabel(fig, 'Text', ['Save writes one file per participant plus the ' ...
        'accept and reject images.'], 'Position', [25, 30, 410, 50], ...
        'WordWrap', 'on');

    refresh();

    % Block until the window closes, so the caller gets the finished table.
    uiwait(fig);


    % --------------------------------------------------------------------
    function pool = currentPool()
        pool = ICs{iSub, 2};
    end

    function refresh()
        pool = currentPool();

        if isempty(pool)
            icLabel.Text = 'nothing to review for this participant';
            progressLabel.Text = '';
        else
            iIC = min(max(iIC, 1), numel(pool));
            icLabel.Text = sprintf('IC %d', pool(iIC));
            progressLabel.Text = sprintf('%d of %d', iIC, numel(pool));
        end

        rejectedList.Items = numbersToItems(rejected{iSub});
        acceptedList.Items = numbersToItems(accepted{iSub});
    end

    function onSubjectChange(src)
        iSub = find(strcmp(src.Items, src.Value), 1);
        iIC  = 1;
        refresh();
    end

    function step(delta)
        pool = currentPool();
        if isempty(pool), return, end
        iIC = min(max(iIC + delta, 1), numel(pool));
        refresh();
    end

    function plotCurrent()
        pool = currentPool();
        if isempty(pool), return, end
        pop_prop_extended(ALLEEG(iSub), 0, pool(iIC), NaN, ...
            {'freqrange', [1 60]});
    end

    function decide(isAccepted)
        pool = currentPool();
        if isempty(pool), return, end

        ic  = pool(iIC);
        sub = subject_list(iSub);

        if isAccepted
            accepted{iSub} = unique([accepted{iSub}(:); ic]);
            prefix = 'accepted';
        else
            rejected{iSub} = unique([rejected{iSub}(:); ic]);
            prefix = 'rejected';
        end

        saveEvidence(prefix, sub, ic);
        closePlots();

        % Move on, so a full pass is one click per component.
        if iIC < numel(pool)
            iIC = iIC + 1;
        end
        refresh();
    end

    function saveEvidence(prefix, sub, ic)
        subDir = fullfile(out_folder, ['sub-', num2str(sub)]);
        if ~exist(subDir, 'dir')
            mkdir(subDir);
        end

        plots = propertyFigures();
        if isempty(plots), return, end

        saveas(plots(1), fullfile(subDir, ...
            sprintf('%s_subject_%d_IC_%d.png', prefix, sub, ic)));
    end

    function closePlots()
        close(propertyFigures());
    end

    function h = propertyFigures()
        % Every figure except this GUI, which is a uifigure.
        all_figs = findall(0, 'Type', 'figure');
        h = all_figs(all_figs ~= fig);
    end

    function saveAndClose()
        for k = 1:nSets
            ICs{k, 3} = accepted{k};

            subDir = fullfile(out_folder, ['sub-', num2str(subject_list(k))]);
            if ~exist(subDir, 'dir')
                mkdir(subDir);
            end

            brain_ICs = {ICs{k, 1}, ICs{k, 3}}; %#ok<NASGU>
            save(fullfile(subDir, sprintf(...
                'Brain_ICs_50percentUp - Accepted_potential_Brain_ICs - sub-%d.mat', ...
                subject_list(k))), 'brain_ICs');
        end

        closePlots();
        uiresume(fig);
        delete(fig);
    end

end


% ------------------------------------------------------------------------
function items = numbersToItems(v)

    if isempty(v)
        items = {};
    else
        items = arrayfun(@(x) sprintf('IC %d', x), v(:)', ...
            'UniformOutput', false);
    end

end