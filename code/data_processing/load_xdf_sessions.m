function streams = load_xdf_sessions(subject_id, rawdata_path, eeg_stream_name)
% XDF_LOAD_MATLAB  Load every session of one participant from the raw XDF
% recordings.
%
%   streams = load_xdf_sessions(subject_id, rawdata_path)
%   streams = load_xdf_sessions(subject_id, rawdata_path, eeg_stream_name)
%
% Returns a 1 x nSessions cell array. Each element is a struct array with a
% single field, dataset, holding the LSL streams of that session, which is
% the shape concatenate_runs expects.
%
% Sessions are taken in alphabetical order of the session folders, that is
% ses-S001, ses-S002, ses-S003.
%
% When a session was recorded into more than one XDF file, all of them are
% loaded and concatenated in recording order. The order is decided by the
% first timestamp of the EEG stream in each file, not by the file name and
% not by a human, so the result does not depend on who runs the code.
%
% This function used to open show_gui_for_file_selection so that the
% experimenter could pick the files to load and put them in order. That is
% gone. The published raw dataset contains only the files that belong to the
% analysis, so there is nothing left to select. If you record new sessions
% and some files should be dropped, drop them from the folder rather than
% from a dialog.

    if nargin < 3 || isempty(eeg_stream_name)
        eeg_stream_name = 'LiveAmpSN-102108-1125';
    end

    files_path = fullfile(rawdata_path, ['sub-', num2str(subject_id)]);
    if ~exist(files_path, 'dir')
        error('load_xdf_sessions:NoSubjectFolder', ...
            'No raw data folder for sub-%d:\n  %s', subject_id, files_path);
    end

    %% Find the session folders
    items = dir(files_path);
    items = items([items.isdir]);
    items = items(~ismember({items.name}, {'.', '..'}));

    if isempty(items)
        error('load_xdf_sessions:NoSessions', ...
            'No session folders under:\n  %s', files_path);
    end

    [~, alphabetical] = sort({items.name});
    items = items(alphabetical);

    %% Load the sessions
    streams = cell(1, numel(items));
    loaded_ok = false(1, numel(items));

    for k = 1:numel(items)

        session_path = fullfile(files_path, items(k).name, 'eeg');
        xdf_files = dir(fullfile(session_path, '*.xdf'));

        if isempty(xdf_files)
            warning('load_xdf_sessions:EmptySession', ...
                'No XDF file in %s, skipping this session.', session_path);
            continue
        end

        if numel(xdf_files) == 1

            fprintf('  %s: %s\n', items(k).name, xdf_files(1).name);
            streams{k} = struct('dataset', ...
                load_xdf(fullfile(session_path, xdf_files(1).name)));

        else

            % Load every file first, then put them in recording order.
            nFiles = numel(xdf_files);
            loaded = cell(1, nFiles);
            t0 = nan(1, nFiles);

            for f = 1:nFiles
                loaded{f} = load_xdf(fullfile(session_path, xdf_files(f).name));
                t0(f) = first_eeg_timestamp(loaded{f}, eeg_stream_name);
            end

            if any(isnan(t0))
                warning('load_xdf_sessions:NoEEGTimestamps', ...
                    ['Could not read an EEG timestamp from every file in ' ...
                     '%s. Falling back to alphabetical file order.'], ...
                    session_path);
                order = 1:nFiles;
            else
                [~, order] = sort(t0);
            end

            fprintf('  %s: %d files, concatenated in this order:\n', ...
                items(k).name, nFiles);
            for f = 1:nFiles
                fprintf('    %d. %s\n', f, xdf_files(order(f)).name);
            end

            concatenated_stream = loaded{order(1)};
            for f = 2:nFiles
                concatenated_stream = merge_xdf_streams( ...
                    concatenated_stream, loaded{order(f)});
            end

            streams{k} = struct('dataset', concatenated_stream);

        end

        loaded_ok(k) = true;

    end

    %% Drop the sessions that had no data
    streams = streams(loaded_ok);

    if isempty(streams)
        error('load_xdf_sessions:NothingLoaded', ...
            'No XDF data was loaded for sub-%d.', subject_id);
    end

end


% ------------------------------------------------------------------------
function t = first_eeg_timestamp(stream_set, eeg_stream_name)
% First LSL timestamp of the EEG stream of one XDF file. Falls back to the
% stream whose type is EEG, and then to the earliest timestamp of any
% stream. Returns NaN when the file carries no timestamps at all.

    t = NaN;

    % By stream name, which is the unambiguous case.
    for i = 1:numel(stream_set)
        if isfield(stream_set{i}.info, 'name') && ...
                strcmp(stream_set{i}.info.name, eeg_stream_name) && ...
                ~isempty(stream_set{i}.time_stamps)
            t = min(stream_set{i}.time_stamps);
            return
        end
    end

    % By stream type.
    for i = 1:numel(stream_set)
        if isfield(stream_set{i}.info, 'type') && ...
                strcmp(stream_set{i}.info.type, 'EEG') && ...
                ~isempty(stream_set{i}.time_stamps)
            t = min(stream_set{i}.time_stamps);
            return
        end
    end

    % Anything with timestamps.
    for i = 1:numel(stream_set)
        if ~isempty(stream_set{i}.time_stamps)
            t = min([t, min(stream_set{i}.time_stamps)]);
        end
    end

end