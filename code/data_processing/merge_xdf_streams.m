function merged = merge_xdf_streams(stream1, stream2)
% MERGE_XDF_STREAMS  Join two XDF files that belong to the same session.
%
%   merged = merge_xdf_streams(stream1, stream2)
%
% A session that was recorded in more than one file is stitched back together
% here, stream by stream. Only the three streams the analysis uses are joined:
% EEG, the encoder and experiment stream, and EMG. Any other stream keeps
% whatever the first file held.
%
% Samples and timestamps are concatenated in the order the two files are
% passed, so the caller is responsible for passing them in recording order.
% load_xdf_sessions does that by comparing the first EEG timestamp of each
% file.

    merged  = stream1;
    current = stream2;

    % Stream names as they appear in the recordings. A recording made with a
    % different amplifier or a renamed LSL outlet needs these updated.
    streamNames = { ...
        'LiveAmpSN-102108-1125', ...            % EEG
        'Encoder_Pressure_Preference_Force', ... % experiment
        'EMG'};

    % The EEG and EMG streams carry a segments field; the experiment stream
    % does not.
    hasSegments = [true, false, true];

    for s = 1:numel(streamNames)

        k1 = find_stream(merged,  streamNames{s});
        k2 = find_stream(current, streamNames{s});

        if isempty(k1) || isempty(k2)
            warning('merge_xdf_streams:StreamMissing', ...
                ['Stream "%s" is not in both files, so it was left as it ' ...
                 'was in the first one.'], streamNames{s});
            continue
        end

        merged{1, k1}.time_stamps = [merged{1, k1}.time_stamps, ...
                                     current{1, k2}.time_stamps];

        merged{1, k1}.time_series = [merged{1, k1}.time_series, ...
                                     current{1, k2}.time_series];

        if hasSegments(s) && isfield(merged{1, k1}, 'segments')
            merged{1, k1}.segments(end+1) = current{1, k2}.segments;
        end

    end

end


% ------------------------------------------------------------------------
function k = find_stream(streamSet, name)
% Index of the stream with this name, empty if it is not there.

    k = [];
    for i = 1:numel(streamSet)
        if isfield(streamSet{1, i}.info, 'name') && ...
                strcmp(streamSet{1, i}.info.name, name)
            k = i;
            return
        end
    end

end