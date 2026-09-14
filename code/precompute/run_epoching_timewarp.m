% run_epoching_timewarp.m
% Stage 3. Cut each participant's cleaned dataset into movement cycles and
% build the time-warp matrix that the ERSP precompute warps to.
%
%   cleaned continuous .set  ->  epochs locked to FlxS, with EEG.timewarp
%
% One epoch is one knee movement cycle. Epochs run from 0.5 s before the
% flexion start to 3.5 s after it, and each epoch carries three warp events:
%
%   FlxS   flexion start   (the time-locking event)
%   ExtS   extension start (also the flexion end)
%   ExtE   extension end
%
% make_timewarp rejects epochs whose event latencies are more than 3 SD from
% the mean, in absolute terms and relative to the epoch, and those epochs are
% dropped from the dataset. What survives is stored in EEG.etc.badepochs so
% the rejection is auditable afterwards.
%
% EEG.timewarp.warpto is this participant's median event latency vector. The
% ERSP precompute takes the median of those across participants, rounded to
% the nearest 50 ms, and warps every participant onto it.
%
% Runs unattended over the subject list. No file picker, no cd, no hardcoded
% toolbox path.

clc
clear


%% Paths
% config/ is always two levels up from code/<stage>/.
% Locate config/, which is always two levels up from code/<stage>/.
%
% mfilename is empty when these lines are pasted into the command window,
% and reports a temporary helper file when a single %% section is run with
% Ctrl+Enter, so neither case can be trusted. Fall back to this file's own
% name, which resolves whenever the file is runnable at all.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('run_epoching_timewarp');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_epoching_timewarp.m and press Run, ' ...
           'or make its folder the current folder first. Pasting the ' ...
           'bootstrap into the command window gives MATLAB nothing to ' ...
           'resolve the path from.']);
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);

if isempty(cfg.raw)
    error(['This stage reads the cleaned single-subject datasets. ' ...
           'Set cfg.raw in config/local_paths.m.']);
end


%% What to run
subjects = cfg.subjects;   % 5:18. Set explicitly to process others.

% Where the cleaned continuous datasets are, and how they are named. %d is
% the participant number.
input_folder   = fullfile(cfg.singleSubj, 'sub-%d');
input_pattern  = 'sub-%d_cleaned_with_ICA.set';

% Where the epoched datasets go. This is also where the ERSP precompute will
% write the .icatimef files, because std_ersp names its output from
% STUDY.datasetinfo.filepath.
output_folder  = cfg.epoched;
output_pattern = 'sub-%d_cleaned_with_ICA_epoched.set';

% Skip a participant whose epoched dataset is already on disk.
force_recompute = false;

% Epoching and time warping.
warp_events   = {'FlxS', 'ExtS', 'ExtE'};   % in cycle order
lock_event    = 'FlxS';                     % time-locking event
epoch_window  = [-0.5 3.5];                 % seconds
max_std_abs   = 3;
max_std_rel   = 3;


%% Initialize EEGLAB
if ~exist('ALLCOM', 'var')
    eeglab;
end

if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end


%% Processing loop
failed  = {};
summary = struct('subject', {}, 'nEpochs', {}, 'nRejected', {}, 'warpto', {});

for subject = subjects

    fprintf('\n================ Subject %d ================\n', subject);

    try

        in_path = sprintf(input_folder, subject);
        in_file = sprintf(input_pattern, subject);
        out_file = sprintf(output_pattern, subject);

        if ~force_recompute && exist(fullfile(output_folder, out_file), 'file')
            disp('Epoched dataset already on disk, skipping.');
            continue
        end

        if ~exist(fullfile(in_path, in_file), 'file')
            error('run_epoching_timewarp:NoInput', ...
                'sub-%d has no cleaned dataset:\n  %s', ...
                subject, fullfile(in_path, in_file));
        end

        EEG = pop_loadset('filename', in_file, 'filepath', in_path);
        EEG = eeg_checkset(EEG);

        % STUDY does not accept a bare number as a subject code.
        EEG.subject = ['S', num2str(subject)];


        %% Keep only the movement-cycle events
        present = unique({EEG.event.type});
        missing = setdiff(warp_events, present);
        if ~isempty(missing)
            error('run_epoching_timewarp:MissingEvents', ...
                ['sub-%d has no %s events. The event table was not ' ...
                 'imported, or it was imported after the non-experimental ' ...
                 'segments were cut.'], subject, strjoin(missing, ', '));
        end

        EEG = pop_selectevent(EEG, 'type', warp_events, 'deleteevents', 'on');
        EEG = eeg_checkset(EEG, 'eventconsistency');


        %% Carry the trial number and the condition into the event structure
        % desc was written by Main_add_events as
        % <previous pressure>_<current pressure>_<trial>, so the condition is
        % the second field and the trial is the last.
        for e = 1:length(EEG.event)
            if strcmp(EEG.event(e).type, 'boundary')
                EEG.event(e).trial = 'none';
                EEG.event(e).cond  = 'none';
            else
                nums = str2double(strsplit(EEG.event(e).desc, '_')).';
                EEG.event(e).trial = nums(end);
                EEG.event(e).cond  = nums(2);
            end
        end


        %% Epoching
        EEG = pop_epoch(EEG, {lock_event}, epoch_window, ...
            'newname', 'FlxStartEvents epochs', 'epochinfo', 'yes');
        EEG = eeg_checkset(EEG);
        EEG.setname = [EEG.subject, ' Epoched'];

        nEpochsBefore = length(EEG.epoch);


        %% Time warping
        timewarp = make_timewarp(EEG, warp_events, ...
            'baselineLatency', 0, ...
            'maxSTDForAbsolute', max_std_abs, ...
            'maxSTDForRelative', max_std_rel);

        % This participant's own warp target. The group median of these,
        % rounded, is what the ERSP precompute warps everyone onto.
        timewarp.warpto = median(timewarp.latencies);
        EEG.timewarp = timewarp;
        EEG.timewarp.medianlatency = median(timewarp.latencies(:, end));


        %% Drop the epochs make_timewarp rejected
        goodepochs = sort(timewarp.epochs);
        badepochs  = setdiff(1:nEpochsBefore, goodepochs);
        EEG.etc.badepochs = badepochs;

        if ~isempty(badepochs)
            EEG = pop_select(EEG, 'notrial', badepochs);
        end
        EEG = eeg_checkset(EEG);

        fprintf('  %d epochs, %d rejected, %d kept\n', ...
            nEpochsBefore, numel(badepochs), EEG.trials);
        fprintf('  warpto: %s ms\n', mat2str(round(EEG.timewarp.warpto)));


        %% Save
        EEG = pop_saveset(EEG, 'filename', out_file, 'filepath', output_folder);

        summary(end+1) = struct('subject', subject, ...
                                'nEpochs', EEG.trials, ...
                                'nRejected', numel(badepochs), ...
                                'warpto', EEG.timewarp.warpto); %#ok<SAGROW>

        clear EEG

    catch err
        failed{end+1} = struct('subject', subject, 'error', err); %#ok<SAGROW>
        warning('run_epoching_timewarp:SubjectFailed', ...
            'Subject %d failed: %s', subject, err.message);
        fprintf('%s\n', getReport(err, 'extended', 'hyperlinks', 'off'));
    end

end


%% Summary
fprintf('\nRequested subjects: %s\n', mat2str(subjects));

if ~isempty(summary)
    fprintf('\n%-8s %8s %10s   %s\n', 'subject', 'epochs', 'rejected', 'warpto (ms)');
    for k = 1:numel(summary)
        fprintf('sub-%-4d %8d %10d   %s\n', summary(k).subject, ...
            summary(k).nEpochs, summary(k).nRejected, ...
            mat2str(round(summary(k).warpto)));
    end

    % The value the ERSP precompute will warp everyone onto, shown here so a
    % participant with an odd cycle duration is visible before the precompute
    % runs for hours.
    warps = vertcat(summary.warpto);
    roundNear = 50;
    fprintf('\nGroup median warpto, rounded to %d ms: %s\n', roundNear, ...
        mat2str(round(median(warps, 1) / roundNear) * roundNear));
end

if isempty(failed)
    disp('EPOCHING AND TIME WARPING DONE, all requested subjects completed.');
else
    fprintf('%d subject(s) failed:\n', numel(failed));
    for k = 1:numel(failed)
        fprintf('  sub-%d: %s\n', failed{k}.subject, failed{k}.error.message);
    end
end
