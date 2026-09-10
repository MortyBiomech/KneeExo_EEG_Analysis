function Trials_Info = build_trial_info(input_streams, EEG, ...
    Trials_encoder_events, subject_id, data_path, sessions_trial_id)
% BUILD_TRIAL_INFO  Locate every trial event in every stream.
%
%   Trials_Info = build_trial_info(input_streams, EEG, ...
%       Trials_encoder_events, subject_id, data_path, sessions_trial_id)
%
% Produces one entry per trial holding, for each stream, the sample index of
% every event of that trial. The streams run at different rates and started
% at different moments, so the same event has a different index in each, and
% this function is the only place those indices are worked out.
%
%   General      description, session, pressure, score, case
%   EEG_stream   .Raw           indices into the concatenated raw EEG stream
%                .Preprocessed  latencies in the cleaned EEGLAB dataset
%   EMG_stream   indices into the concatenated EMG stream
%   EXP_stream   indices into the experiment stream, which is where the
%                encoder events were defined in the first place
%
% Events per trial: trial start and end, pressure change, movement start and
% end, and for every movement cycle the flexion start and end, the extension
% start and end, and the flexion-to-flexion boundaries.
%
% Writes <data_path>/6_Trials_Info_and_Epoched_data/sub-<N>/Trials_Info.mat
%
% The timing of the trial markers changed after participant 9, so every
% marker below branches on subject_id > 9.

    %% Extract data
    All_EEG_time        = input_streams.All_EEG_time;
    All_EMG_time        = input_streams.All_EMG_time;
    All_Experiment      = input_streams.All_Exp;
    All_Experiment_time = input_streams.All_Exp_time;

    if subject_id > 9
        idx = 2;
    else
        idx = 1;
    end


    %% Locate the trial markers in the experiment stream and the raw EEG

    % start_beep event (first single beep)
    start_beep = find(diff(All_Experiment(6, :)) == 1);
    if subject_id > 9
        start_beep = reshape(start_beep, 2, []);
    end
    start_beep_time_Expdata = All_Experiment_time(start_beep(1,:));
    start_beep_indx_All_EEG = ...
        knnsearch(All_EEG_time', start_beep_time_Expdata');

    % pressure_change event: 2 s after the single beep from participant 10
    % on, 2 s before it up to participant 9.
    if subject_id > 9
        pressure_change_time_Expdata = All_Experiment_time(start_beep(1,:)) + 2;
    else
        pressure_change_time_Expdata = All_Experiment_time(start_beep(1,:)) - 2;
    end
    pressure_change_indx_All_EEG = ...
        knnsearch(All_EEG_time', pressure_change_time_Expdata');

    % start_move event (second single beep, 2 s after the pressure change)
    start_move = find(diff(All_Experiment(6, :)) == 1);
    if subject_id > 9
        start_move = reshape(start_move, 2, []);
        start_move_time_Expdata = All_Experiment_time(start_move(2,:));
    else
        start_move_time_Expdata = All_Experiment_time(start_move(1,:));
    end
    start_move_indx_All_EEG = ...
        knnsearch(All_EEG_time', start_move_time_Expdata');

    % finish_beep event (double beep, 20 s after start_move, stop moving)
    if subject_id > 9
        finish_beep = find(diff(All_Experiment(6, :)) == -2);
    else
        finish_beep = find(diff(All_Experiment(6, :)) == -1);
    end
    finish_beep_time_Expdata = All_Experiment_time(finish_beep);
    finish_beep_indx_All_EEG = ...
        knnsearch(All_EEG_time', finish_beep_time_Expdata');

    % score_press event (the experimenter enters the rating)
    if subject_id > 9
        score_press = find(diff(All_Experiment(7, :)) > 0);
    else
        score_press = find(diff(All_Experiment(6, :)) == -1) + 1;
    end
    score_press_time_Expdata = All_Experiment_time(score_press); %#ok<NASGU>
    score_press_indx_All_EEG = ...
        knnsearch(All_EEG_time', All_Experiment_time(score_press)');


    %% Drop trials whose peak selection came out empty
    % Everything above is indexed by the ORIGINAL trial number. Dropping a
    % trial here shortens Trials_encoder_events but not those arrays, so
    % `kept` carries the original trial number of each surviving trial and
    % every lookup below goes through it.
    %
    % Before this was introduced the loops used the new counter directly, so
    % a single dropped trial shifted the trial start, pressure change,
    % movement start and end, and score press of every trial after it by one,
    % silently.
    nTrialsRecorded = numel(Trials_encoder_events);
    isEmptyPeaks = false(1, nTrialsRecorded);
    for i = 1:nTrialsRecorded
        isEmptyPeaks(i) = isempty(Trials_encoder_events{1, i}.high_peaks) || ...
                          isempty(Trials_encoder_events{1, i}.low_peaks);
    end

    kept = find(~isEmptyPeaks);
    Trials_encoder_events = Trials_encoder_events(kept);

    if any(isEmptyPeaks)
        fprintf(['sub-%d: %d of %d trials dropped for empty peak ' ...
                 'selection: %s\n'], subject_id, sum(isEmptyPeaks), ...
                 nTrialsRecorded, mat2str(find(isEmptyPeaks)));
    end

    nTrials = numel(Trials_encoder_events);


    %% Initialize the structure
    structTemplate = struct( ...
        'Trial_start_indx',     [], ...
        'Trial_end_indx',       [], ...
        'Pressure_Change_indx', [], ...
        'Movement_start_indx',  [], ...
        'Movement_end_indx',    [], ...
        'flexion_start_indx',   [], ...
        'flexion_end_indx',     [], ...
        'extension_start_indx', [], ...
        'extension_end_indx',   [], ...
        'flextoflex_start_indx', [], ...
        'flextoflex_end_indx',   []);

    events_on_eeg = struct('Raw', structTemplate, ...
                           'Preprocessed', structTemplate);

    general_info = struct('Description', [], 'Session', [], ...
                          'Pressure', [], 'Score', [], 'Case', []);

    epochs_events = struct('EEG_stream', events_on_eeg, ...
                           'EMG_stream', structTemplate, ...
                           'EXP_stream', structTemplate);

    Trials_Info = repmat({struct('General', general_info, ...
                                 'Events', epochs_events)}, 1, nTrials);


    %% General
    for i = 1:nTrials

        trial = kept(i);   % original trial number

        Trials_Info{1, i}.General.Description = Trials_encoder_events{1, i}.Description;
        Trials_Info{1, i}.General.Pressure    = Trials_encoder_events{1, i}.Pressure;
        Trials_Info{1, i}.General.Score       = Trials_encoder_events{1, i}.Score;
        Trials_Info{1, i}.General.Case        = Trials_encoder_events{1, i}.Case;

        if trial <= sessions_trial_id(1)
            Trials_Info{1, i}.General.Session = 1;
        elseif trial <= sessions_trial_id(2)
            Trials_Info{1, i}.General.Session = 2;
        elseif trial <= sessions_trial_id(3)
            Trials_Info{1, i}.General.Session = 3;
        else
            Trials_Info{1, i}.General.Session = 4;
        end

    end


    %% Events on the raw EEG stream
    parfor i = 1:nTrials

        trial = kept(i);
        enc   = Trials_encoder_events{1, i};

        Trials_Info{1, i}.Events.EEG_stream.Raw.Trial_start_indx = ...
            start_beep_indx_All_EEG(trial);
        Trials_Info{1, i}.Events.EEG_stream.Raw.Trial_end_indx = ...
            score_press_indx_All_EEG(trial);

        Trials_Info{1, i}.Events.EEG_stream.Raw.Pressure_Change_indx = ...
            pressure_change_indx_All_EEG(trial);

        Trials_Info{1, i}.Events.EEG_stream.Raw.Movement_start_indx = ...
            start_move_indx_All_EEG(trial);
        Trials_Info{1, i}.Events.EEG_stream.Raw.Movement_end_indx = ...
            finish_beep_indx_All_EEG(trial);

        Trials_Info{1, i}.Events.EEG_stream.Raw.flexion_start_indx = ...
            to_stream_index(All_EEG_time, All_Experiment_time, enc.Flexion_Start);
        Trials_Info{1, i}.Events.EEG_stream.Raw.flexion_end_indx = ...
            to_stream_index(All_EEG_time, All_Experiment_time, enc.Flexion_End);

        Trials_Info{1, i}.Events.EEG_stream.Raw.extension_start_indx = ...
            to_stream_index(All_EEG_time, All_Experiment_time, enc.Extension_Start);
        Trials_Info{1, i}.Events.EEG_stream.Raw.extension_end_indx = ...
            to_stream_index(All_EEG_time, All_Experiment_time, enc.Extension_End);

        f2f = flextoflex_starts(enc, Trials_Info{1, i}.General.Case, subject_id, trial);
        Trials_Info{1, i}.Events.EEG_stream.Raw.flextoflex_start_indx = ...
            to_stream_index(All_EEG_time, All_Experiment_time, f2f);
        Trials_Info{1, i}.Events.EEG_stream.Raw.flextoflex_end_indx = ...
            to_stream_index(All_EEG_time, All_Experiment_time, enc.Extension_End);

    end


    %% Events on the EMG stream
    parfor i = 1:nTrials

        trial = kept(i);
        enc   = Trials_encoder_events{1, i};

        [~, Trials_Info{1, i}.Events.EMG_stream.Trial_start_indx] = ...
            min(abs(All_EMG_time - All_Experiment_time(start_beep(1, trial))));
        [~, Trials_Info{1, i}.Events.EMG_stream.Trial_end_indx] = ...
            min(abs(All_EMG_time - All_Experiment_time(score_press(1, trial))));

        [~, Trials_Info{1, i}.Events.EMG_stream.Pressure_Change_indx] = ...
            min(abs(All_EMG_time - All_EEG_time(pressure_change_indx_All_EEG(trial))));

        [~, Trials_Info{1, i}.Events.EMG_stream.Movement_start_indx] = ...
            min(abs(All_EMG_time - All_Experiment_time(start_move(idx, trial))));
        [~, Trials_Info{1, i}.Events.EMG_stream.Movement_end_indx] = ...
            min(abs(All_EMG_time - All_Experiment_time(finish_beep(1, trial))));

        Trials_Info{1, i}.Events.EMG_stream.flexion_start_indx = ...
            to_stream_index(All_EMG_time, All_Experiment_time, enc.Flexion_Start);
        Trials_Info{1, i}.Events.EMG_stream.flexion_end_indx = ...
            to_stream_index(All_EMG_time, All_Experiment_time, enc.Flexion_End);

        Trials_Info{1, i}.Events.EMG_stream.extension_start_indx = ...
            to_stream_index(All_EMG_time, All_Experiment_time, enc.Extension_Start);
        Trials_Info{1, i}.Events.EMG_stream.extension_end_indx = ...
            to_stream_index(All_EMG_time, All_Experiment_time, enc.Extension_End);

        f2f = flextoflex_starts(enc, Trials_Info{1, i}.General.Case, subject_id, trial);
        Trials_Info{1, i}.Events.EMG_stream.flextoflex_start_indx = ...
            to_stream_index(All_EMG_time, All_Experiment_time, f2f);
        Trials_Info{1, i}.Events.EMG_stream.flextoflex_end_indx = ...
            to_stream_index(All_EMG_time, All_Experiment_time, enc.Extension_End);

    end


    %% Events on the experiment stream
    % These are the definitions, not conversions: the encoder events were
    % found on this stream in the first place.
    for i = 1:nTrials

        trial = kept(i);
        enc   = Trials_encoder_events{1, i};

        Trials_Info{1, i}.Events.EXP_stream.Trial_start_indx = start_beep(1, trial);
        Trials_Info{1, i}.Events.EXP_stream.Trial_end_indx   = score_press(1, trial);

        [~, Trials_Info{1, i}.Events.EXP_stream.Pressure_Change_indx] = ...
            min(abs(All_Experiment_time - pressure_change_time_Expdata(1, trial)));

        Trials_Info{1, i}.Events.EXP_stream.Movement_start_indx = start_move(idx, trial);
        Trials_Info{1, i}.Events.EXP_stream.Movement_end_indx   = finish_beep(1, trial);

        Trials_Info{1, i}.Events.EXP_stream.flexion_start_indx   = enc.Flexion_Start;
        Trials_Info{1, i}.Events.EXP_stream.flexion_end_indx     = enc.Flexion_End;
        Trials_Info{1, i}.Events.EXP_stream.extension_start_indx = enc.Extension_Start;
        Trials_Info{1, i}.Events.EXP_stream.extension_end_indx   = enc.Extension_End;

        Trials_Info{1, i}.Events.EXP_stream.flextoflex_start_indx = ...
            flextoflex_starts(enc, Trials_Info{1, i}.General.Case, subject_id, trial);
        Trials_Info{1, i}.Events.EXP_stream.flextoflex_end_indx = enc.Extension_End;

    end


    %% Events on the cleaned EEGLAB dataset
    % Matched by event type and by the trial number carried in desc, which is
    % the ORIGINAL trial number, so kept(i) is what has to be matched.
    EEGLAB_event_type = {EEG.event.type};
    EEGLAB_event_desc = {EEG.event.desc};

    desired_types = {'SB_Start_Beep', 'SP_Score_Press', 'PC_Pressure_Change', ...
                     'SM_Start_Move', 'FB_Finish_Beep', ...
                     'FlxS', 'FlxE', 'ExtS', 'ExtE'};
    corresponding_fields = {'Trial_start_indx', 'Trial_end_indx', ...
                     'Pressure_Change_indx', ...
                     'Movement_start_indx', 'Movement_end_indx', ...
                     'flexion_start_indx', 'flexion_end_indx', ...
                     'extension_start_indx', 'extension_end_indx'};

    for i = 1:nTrials

        desc_ending = ['_', num2str(kept(i))];

        for s = 1:numel(desired_types)
            indices = strcmp(EEGLAB_event_type, desired_types{s}) & ...
                      endsWith(EEGLAB_event_desc, desc_ending);
            Trials_Info{1, i}.Events.EEG_stream.Preprocessed.(corresponding_fields{s}) = ...
                [EEG.event(indices).latency];
        end

        flx = Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flexion_start_indx;
        switch Trials_Info{1, i}.General.Case
            case 3
                Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flextoflex_start_indx = flx;
            case 4
                Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flextoflex_start_indx = flx(1:end-1);
            otherwise
                Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flextoflex_start_indx = [];
        end

        Trials_Info{1, i}.Events.EEG_stream.Preprocessed.flextoflex_end_indx = ...
            Trials_Info{1, i}.Events.EEG_stream.Preprocessed.extension_end_indx;

    end


    %% Save
    % Overwrites without asking. Trials_Info is fully determined by its
    % inputs, so there is nothing here that a person curated and could lose.
    % This used to raise a questdlg, which stopped an unattended run.
    save_path = fullfile(data_path, '6_Trials_Info_and_Epoched_data', ...
        ['sub-', num2str(subject_id)]);

    if ~isfolder(save_path)
        mkdir(save_path);
    end

    save(fullfile(save_path, 'Trials_Info.mat'), 'Trials_Info', '-v7.3');
    fprintf('sub-%d: %d trials written to %s\n', ...
        subject_id, nTrials, fullfile(save_path, 'Trials_Info.mat'));

end


% ------------------------------------------------------------------------
function ix = to_stream_index(streamTime, expTime, expIndices)
% Sample indices in streamTime for events given as indices into the
% experiment stream. Empty in, empty out.

    if isempty(expIndices)
        ix = [];
        return
    end

    ix = interp1(streamTime, 1:numel(streamTime), ...
        expTime(expIndices), 'nearest', 'extrap');

end


% ------------------------------------------------------------------------
function f2f = flextoflex_starts(enc, caseNumber, subject_id, trial)
% Flexion starts that open a full flexion-to-flexion cycle.
%
% Case 3 ends on an extension, so every flexion start opens a cycle. Case 4
% ends on a flexion, so the last flexion start has no matching extension end
% and is dropped. Cases 1 and 2 are marked "should not happen" upstream; if
% one appears, say so rather than silently reusing whatever was in the
% variable last, which is what the previous version did.

    switch caseNumber
        case 3
            f2f = enc.Flexion_Start;
        case 4
            f2f = enc.Flexion_Start(1:end-1);
        otherwise
            warning('build_trial_info:UnexpectedCase', ...
                ['sub-%d trial %d has Case %s, which is not 3 or 4. No ' ...
                 'flexion-to-flexion cycles recorded for it.'], ...
                subject_id, trial, mat2str(caseNumber));
            f2f = [];
    end

end