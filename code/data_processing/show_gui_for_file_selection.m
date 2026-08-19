function [selected_files, order] = show_gui_for_file_selection(file_names, file_sizes)
    % Create a uifigure GUI to display file names and sizes and allow user selection
    selected_files = file_names; % Initialize selected files
    order = 1:length(file_names); % Default order

    fig = uifigure('Name', 'File Selection', 'Position', [100 100 600 400]);

    % Add table with editable column for order input
    data = [file_names(:), num2cell(file_sizes(:) / (1e6)), repmat({''}, length(file_names), 1)];
    tbl = uitable(fig, 'Data', data, ...
                 'ColumnName', {'File Name', 'Size (MB)', 'Order/Do not Load'}, ...
                 'ColumnEditable', [false false true], ...
                 'Position', [20 80 560 250]);

    % Add Submit button
    btn = uibutton(fig, 'Text', 'Submit', 'Position', [250 20 100 40], 'ButtonPushedFcn', @(btn, event) submitSelection());

    uiwait(fig);

    function submitSelection()
        table_data = tbl.Data;
        for i = 1:size(table_data, 1)
            input_str = table_data{i, 3};
            if strcmpi(input_str, 'Do not load')
                selected_files{i} = 'Do not load';
            else
                order(i) = str2double(input_str);
            end
        end
        close(fig);
    end
end