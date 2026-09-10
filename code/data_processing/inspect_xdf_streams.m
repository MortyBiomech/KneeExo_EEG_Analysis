function inspect_xdf_streams(subject_id, session)
% INSPECT_XDF_STREAMS  Print the stream and channel names inside a raw XDF file.
%
%   inspect_xdf_streams(subject_id)
%   inspect_xdf_streams(subject_id, session)
%
% A diagnostic, not part of the pipeline. Use it when a recording will not
% import, or when setting up a new amplifier or a renamed LSL outlet, to find
% out what the streams are actually called. The names it prints are what
% run_preprocessing expects in eeg_stream_name and what merge_xdf_streams
% expects in its streamNames list.
%
% session defaults to 'S001'.
%
% This used to be a cell inside the import script that ran on every full run.

    if nargin < 2 || isempty(session)
        session = 'S001';
    end

    cfg = kneeexo_config();

    if isempty(cfg.raw)
        error('inspect_xdf_streams:NoRawPath', ...
            'cfg.raw is empty. Set it in config/local_paths.m.');
    end

    % load_xdf ships with FieldTrip as well as with xdf-Matlab.
    ftPath = fileparts(which('ft_defaults'));
    if ~isempty(ftPath)
        addpath(fullfile(ftPath, 'external', 'xdf'));
    end

    xdfPath = fullfile(cfg.source, ['sub-', num2str(subject_id)], ...
        ['ses-', session], 'eeg', ...
        ['sub-', num2str(subject_id), '_ses-', session, ...
         '_task-Default_run-001_eeg.xdf']);

    if ~exist(xdfPath, 'file')
        error('inspect_xdf_streams:NoFile', ...
            'No XDF file at\n  %s', xdfPath);
    end

    fprintf('Reading %s\n\n', xdfPath);
    streams = load_xdf(xdfPath);

    for s = 1:numel(streams)

        info = streams{s}.info;
        name = getfield_or(info, 'name', '(unnamed)');
        type = getfield_or(info, 'type', '(untyped)');

        fprintf('%2d. %-40s type: %-12s %d samples\n', ...
            s, name, type, numel(streams{s}.time_stamps));

        if isfield(info, 'desc') && isstruct(info.desc) && ...
                isfield(info.desc, 'channels')
            labels = cellfun(@(x) x.label, ...
                info.desc.channels.channel, 'UniformOutput', false);
            fprintf('    channels (%d): %s\n', numel(labels), ...
                strjoin(labels(:)', ', '));
        end

        fprintf('\n');
    end

end


% ------------------------------------------------------------------------
function v = getfield_or(s, field, fallback)

    if isfield(s, field) && ~isempty(s.(field))
        v = s.(field);
        if iscell(v), v = v{1}; end
    else
        v = fallback;
    end

end