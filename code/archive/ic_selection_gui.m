function ic_selection_gui(ALLEEG, ICs, subject_list)
    % Initialize GUI
    fig = figure('Name', 'IC Selection GUI', 'Position', [200, 200, 400, 500], 'NumberTitle', 'off', 'MenuBar', 'none');
    
    % Variables to store selected ICs
    accepted_ICs = cell(length(subject_list), 1);
    rejected_ICs = cell(length(subject_list), 1);
    current_subject_index = 1;
    current_IC_index = 1;
    
    % Subject Selector
    uicontrol(fig, 'Style', 'text', 'String', 'Subject', 'Position', [30, 450, 60, 25]);
    subject_dropdown = uicontrol(fig, 'Style', 'popupmenu', 'String', subject_list, 'Position', [100, 450, 60, 25], 'Callback', @subjectCallback);
    
    % IC Label below Subject Selector
    uicontrol(fig, 'Style', 'text', 'String', 'IC', 'Position', [30, 410, 40, 25]);
    ic_label = uicontrol(fig, 'Style', 'text', 'String', num2str(ICs{current_subject_index, 2}(current_IC_index, 1)), 'Position', [100, 410, 300, 25], 'HorizontalAlignment','left');
    
    % Navigation Buttons aligned as per sketch
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Prev', 'Position', [30, 370, 60, 25], 'Callback', @prevCallback);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Next', 'Position', [100, 370, 60, 25], 'Callback', @nextCallback);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Plot', 'Position', [170, 370, 60, 25], 'Callback', @plotCallback);
    
    % Text Areas for Accepted and Rejected ICs
    uicontrol(fig, 'Style', 'text', 'String', 'Rejected:', 'Position', [30, 320, 100, 25]);
    rejected_text = uicontrol(fig, 'Style', 'listbox', 'Position', [30, 170, 150, 150]);
    
    uicontrol(fig, 'Style', 'text', 'String', 'Accepted:', 'Position', [220, 320, 100, 25]);
    accepted_text = uicontrol(fig, 'Style', 'listbox', 'Position', [220, 170, 150, 150]);
    
    % Action Buttons
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Skip', 'Position', [30, 120, 60, 25], 'Callback', @skipCallback);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Reject', 'Position', [100, 120, 60, 25], 'Callback', @rejectCallback);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Accept', 'Position', [170, 120, 60, 25], 'Callback', @acceptCallback);
    
    % Save and Close Buttons
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Save', 'Position', [240, 70, 60, 25], 'Callback', @saveCallback);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Close', 'Position', [310, 70, 60, 25], 'Callback', @(~,~) close(fig));
    
    % Callback Functions
    function subjectCallback(~, ~)
        current_subject_index = subject_dropdown.Value;
        current_IC_index = 1;
        updateICLabel();
        updateRejectedText();
        updateAcceptedText();
    end
    
    function prevCallback(~, ~)
        if current_IC_index > 1
            current_IC_index = current_IC_index - 1;
            updateICLabel();
        end
    end

    function nextCallback(~, ~)
        if current_IC_index < length(ICs{current_subject_index, 2})
            current_IC_index = current_IC_index + 1;
            updateICLabel();
        end
    end

    function plotCallback(~, ~)
        if ~isempty(ICs{current_subject_index, 2})
            pop_prop_extended(ALLEEG(current_subject_index), 0, ICs{current_subject_index, 2}(current_IC_index, 1), NaN, {'freqrange', [1 60]});
        end
    end

    function skipCallback(~, ~)
        if ~isempty(ICs{current_subject_index, 2})
            % Do nothing, simply close the current plot
            fig_handles = findall(0, 'Type', 'figure');
            if length(fig_handles) > 1
                close(fig_handles(2));
            end
        end
    end

    function rejectCallback(~, ~)
        if ~isempty(ICs{current_subject_index, 2})
            current_subject = subject_list(current_subject_index);
            ic_id = ICs{current_subject_index, 2}(current_IC_index, 1);
            rejected_ICs{current_subject_index} = [rejected_ICs{current_subject_index}; ic_id];
            updateRejectedText();
            % Ensure the subject directory exists before saving
            subject_dir = fullfile(pwd, ['sub-' num2str(current_subject)]);
            if ~exist(subject_dir, 'dir')
                mkdir(subject_dir);
            end
            fig_handles = findall(0, 'Type', 'figure');
            if length(fig_handles) > 1
                saveas(fig_handles(2), fullfile(subject_dir, ['rejected_subject_' num2str(current_subject) '_IC_' num2str(ic_id) '.png']));
                close(fig_handles(2));
            end
        end
    end

    function acceptCallback(~, ~)
        if ~isempty(ICs{current_subject_index, 2})
            current_subject = subject_list(current_subject_index);
            ic_id = ICs{current_subject_index, 2}(current_IC_index, 1);
            accepted_ICs{current_subject_index} = [accepted_ICs{current_subject_index}; ic_id];
            ICs{current_subject_index, 3} = accepted_ICs{current_subject_index}; % Store accepted ICs in the third column of ICs
            updateAcceptedText();
            % Ensure the subject directory exists before saving
            subject_dir = fullfile(pwd, ['sub-' num2str(current_subject)]);
            if ~exist(subject_dir, 'dir')
                mkdir(subject_dir);
            end
            fig_handles = findall(0, 'Type', 'figure');
            if length(fig_handles) > 1
                saveas(fig_handles(2), fullfile(subject_dir, ['accepted_subject_' num2str(current_subject) '_IC_' num2str(ic_id) '.png']));
                close(fig_handles(2));
            end
        end
    end

    function saveCallback(~, ~)
        save_fig = figure('Name', 'Save Confirmation', 'Position', [300, 300, 300, 150], 'NumberTitle', 'off', 'MenuBar', 'none');
        uicontrol(save_fig, 'Style', 'text', 'String', 'You have looked into all potential Brain ICs', 'Position', [20, 80, 260, 40]);
        uicontrol(save_fig, 'Style', 'pushbutton', 'String', 'Wait, I want to make sure', 'Position', [30, 20, 100, 30], 'Callback', @(~, ~) close(save_fig));
        uicontrol(save_fig, 'Style', 'pushbutton', 'String', 'Save Potential Brain ICs', 'Position', [170, 20, 100, 30], 'Callback', @saveBrainICs);
    end

    function saveBrainICs(~, ~)
        current_subject = subject_list(current_subject_index);
        subject_dir = fullfile(pwd, ['sub-' num2str(current_subject)]);
        if ~exist(subject_dir, 'dir')
            mkdir(subject_dir);
        end
        % Save the ICs data (column 1 and column 3) for the current subject
        brain_ICs = {ICs{current_subject_index, 1}, ICs{current_subject_index, 3}};
        save(fullfile(subject_dir, ['Brain_ICs_50percentUp - Accepted_potential_Brain_ICs - sub-' num2str(current_subject) '.mat']), 'brain_ICs');
        assignin('base', 'ICs', ICs); % Assign updated ICs to workspace
        % Reset accepted and rejected lists for current subject
        accepted_ICs{current_subject_index} = [];
        rejected_ICs{current_subject_index} = [];
        updateAcceptedText();
        updateRejectedText();
        close(gcf);
    end

    % Helper Functions
    function updateICLabel()
        if ~isempty(ICs{current_subject_index, 2})
            set(ic_label, 'String', num2str(ICs{current_subject_index, 2}(current_IC_index, 1)));
        else
            set(ic_label, 'String', 'No potential Brain source to investigate!');
        end
    end

    function updateRejectedText()
        set(rejected_text, 'String', cellstr(num2str(rejected_ICs{current_subject_index})));
    end

    function updateAcceptedText()
        set(accepted_text, 'String', cellstr(num2str(accepted_ICs{current_subject_index})));
    end
end
