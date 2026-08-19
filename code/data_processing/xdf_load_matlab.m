function streams = xdf_load_matlab(subject_id, rawdata_path)
    
    files_path = [rawdata_path, 'sub-', num2str(subject_id), filesep];

    %% Find the numbers of sessions and load streams
    % Get the list of all items in the folder
    items = dir(files_path);
    streams = repmat(cell(1,1), 1, length(items));
   
    % Loop through the items and load xdf files
    for k = 1:length(items)
        
        % Check if the item is a directory and not '.' or '..'
        if items(k).isdir && ~strcmp(items(k).name, '.') ...
                && ~strcmp(items(k).name, '..')
            
            streams_path = [files_path, items(k).name, filesep, ...
                'eeg', filesep];
            xdf_files = dir(fullfile(streams_path, '*.xdf'));
            
            if length(xdf_files) > 1
                % Prepare data for GUI
                file_names = {xdf_files.name};
                file_sizes = [xdf_files.bytes];

                % Display GUI for user to select and order files
                [selected_files, order] = show_gui_for_file_selection(file_names, file_sizes);

                % Load and concatenate selected files
                concatenated_stream = [];
                for idx = 1:length(order)
                    if ~strcmpi(selected_files{order(idx)}, 'Do not Load')
                        file_path = fullfile(streams_path, selected_files{order(idx)});
                        current_stream = load_xdf(file_path);
                        if isempty(concatenated_stream)
                            concatenated_stream = current_stream;
                        else
                            concatenated_stream = concatenate_same_session(concatenated_stream, current_stream);
                        end
                    end
                end

                % Save the concatenated stream into the cell array
                streams{1,k} = struct('dataset', concatenated_stream);
            else
                % If only one file, load it directly
                file_path = fullfile(streams_path, xdf_files(1).name);
                streams{1,k} = struct('dataset', load_xdf(file_path));
            end
        end

    end

    %% Remove empty cell members
    % Create a logical array where true indicates an empty cell
    emptyCells = cellfun(@isempty, streams);
    
    % Remove the empty cells
    streams(emptyCells) = [];

end
