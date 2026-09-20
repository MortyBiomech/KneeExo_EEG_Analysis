function extract_epochs(input_streams, EEG, Trials_Info, EMG_sensor_id, ...
    subject_id, data_path, basis, muscle_names)
% EXTRACT_EPOCHS  Cut EEG, EMG and the experiment stream into epochs.
%
%   extract_epochs(input_streams, EEG, Trials_Info, EMG_sensor_id, ...
%       subject_id, data_path)
%   extract_epochs(..., basis)
%   extract_epochs(..., basis, muscle_names)
%
% basis chooses what one epoch is. Default 'flextoflex'.
%
%   'flextoflex'  one full movement cycle, flexion start to the next flexion
%                 start. THIS IS THE ONE THE ANALYSIS USES.
%   'flexion'     flexion start to flexion end
%   'extension'   extension start to extension end
%   'trial'       the whole trial, start beep to score press
%
% The first three cut many epochs out of each trial, so their fields hold a
% cell per cycle. 'trial' cuts one epoch per trial, so its fields hold the
% data directly. That difference is inherited from the original four files
% and is preserved here, because downstream code depends on the shape.
%
% Writes <data_path>/6_Trials_Info_and_Epoched_data/sub-<N>/Epochs_<Basis>_based.mat
% holding one variable of the same name, as before.
%
% What each epoch carries
%   EEG_stream.Raw            times and channels from the concatenated raw EEG
%   EEG_stream.Preprocessed   times, channels and IC activations from the
%                             cleaned EEGLAB dataset
%   EMG_stream                times, raw sensors, and the linear envelope
%   EXP_stream                times, force, knee angle, and reference angle
%
% This replaces main_epoch_selection_TrialsBased, _FlexionsBased,
% _ExtensionsBased and _FlextoFlexBased, which were four copies of the same
% 200 lines differing only in which index field they read.

    if nargin < 7 || isempty(basis)
        basis = 'flextoflex';
    end

    % Six sensors were worn. cfg.muscles names the four the analyses use.
    if nargin < 8 || isempty(muscle_names)
        muscle_names = {'Vastus_med_R', 'Rectus_femoris_R', ...
                        'Gastrocnemius_R', 'Biceps_femoris_R', ...
                        'Trapezius_R', 'Trapezius_L'};
    end

    spec = basis_spec(basis);

    fprintf('sub-%d: extracting %s epochs\n', subject_id, spec.label);


    %% Extract data
    All_EEG             = input_streams.All_EEG;
    All_EEG_time        = input_streams.All_EEG_time;
    All_EMG             = input_streams.All_EMG;
    All_EMG_time        = input_streams.All_EMG_time;
    All_Experiment      = input_streams.All_Exp;
    All_Experiment_time = input_streams.All_Exp_time;

    channel_data = EEG.data;
    source_data  = EEG.icaact;


    %% EMG linear envelope
    % Bandpass 20 to 450 Hz, rectify, lowpass at 4 Hz.
    All_EMG_env = emg_envelope(All_EMG, 2000);


    %% Initialize
    nTrials = numel(Trials_Info);

    template = struct( ...
        'General',    [], ...
        'EEG_stream', struct('Raw', struct('Times', [], 'Channels', []), ...
                             'Preprocessed', struct('Times', [], ...
                                                    'Channels', [], ...
                                                    'Sources', [])), ...
        'EMG_stream', struct('Times', [], 'Sensors_Raw', [], ...
                             'Sensors_Preprocessed', []), ...
        'EXP_stream', struct('Times', [], 'Force', [], ...
                             'Encoder_angle', [], 'Ref_angle', []));

    Epochs = repmat({template}, 1, nTrials);

    for i = 1:nTrials
        Epochs{1, i}.General = Trials_Info{1, i}.General;
        Epochs{1, i}.General.Muscles_Names = muscle_names;
    end


    %% Loop over trials
    nSkipped = 0;

    for i = 1:nTrials

        ev = Trials_Info{1, i}.Events;

        % Trials the editor marked as unusable. Note that add_events only
        % ever writes 'Experiment', 'No_PAM' or 'Familiarizattion' into
        % Description, so this test only does anything if the flexion editor
        % rewrote it.
        if contains(Trials_Info{1, i}.General.Description, spec.rejectWord)
            nSkipped = nSkipped + 1;
            continue
        end

        % A trial with no cycle of this kind, which happens for the
        % flexion-to-flexion basis when the case is neither 3 nor 4.
        if isempty(ev.EEG_stream.Raw.(spec.startField))
            nSkipped = nSkipped + 1;
            continue
        end

        %% EEG stream
        Epochs{1, i}.EEG_stream.Raw.Times = slice_by( ...
            All_EEG_time, ev.EEG_stream.Raw.(spec.startField), ...
            ev.EEG_stream.Raw.(spec.endField), spec.perCycle);

        Epochs{1, i}.EEG_stream.Raw.Channels = slice_by( ...
            All_EEG, ev.EEG_stream.Raw.(spec.startField), ...
            ev.EEG_stream.Raw.(spec.endField), spec.perCycle);

        Epochs{1, i}.EEG_stream.Preprocessed.Times = slice_by( ...
            EEG.times, ev.EEG_stream.Preprocessed.(spec.startField), ...
            ev.EEG_stream.Preprocessed.(spec.endField), spec.perCycle);

        Epochs{1, i}.EEG_stream.Preprocessed.Channels = slice_by( ...
            channel_data, ev.EEG_stream.Preprocessed.(spec.startField), ...
            ev.EEG_stream.Preprocessed.(spec.endField), spec.perCycle);

        Epochs{1, i}.EEG_stream.Preprocessed.Sources = slice_by( ...
            source_data, ev.EEG_stream.Preprocessed.(spec.startField), ...
            ev.EEG_stream.Preprocessed.(spec.endField), spec.perCycle);

        %% EMG stream
        s = ev.EMG_stream.(spec.startField);
        e = ev.EMG_stream.(spec.endField);

        Epochs{1, i}.EMG_stream.Times = slice_by(All_EMG_time, s, e, spec.perCycle);
        Epochs{1, i}.EMG_stream.Sensors_Raw = slice_by( ...
            All_EMG(EMG_sensor_id, :), s, e, spec.perCycle);
        Epochs{1, i}.EMG_stream.Sensors_Preprocessed = slice_by( ...
            All_EMG_env(EMG_sensor_id, :), s, e, spec.perCycle);

        %% Experiment stream
        s = ev.EXP_stream.(spec.startField);
        e = ev.EXP_stream.(spec.endField);

        Epochs{1, i}.EXP_stream.Times = slice_by(All_Experiment_time, s, e, spec.perCycle);
        Epochs{1, i}.EXP_stream.Force = slice_by(All_Experiment(5, :), s, e, spec.perCycle);
        Epochs{1, i}.EXP_stream.Encoder_angle = slice_by(All_Experiment(1, :), s, e, spec.perCycle);

        if spec.perCycle
            Epochs{1, i}.EXP_stream.Ref_angle = arrayfun( ...
                @(a, b) reference_angle(a, b, All_Experiment_time, All_Experiment), ...
                s, e, 'UniformOutput', false);
        else
            Epochs{1, i}.EXP_stream.Ref_angle = ...
                reference_angle(s, e, All_Experiment_time, All_Experiment);
        end

    end

    if nSkipped > 0
        fprintf('  %d of %d trials skipped\n', nSkipped, nTrials);
    end


    %% Save
    save_path = fullfile(data_path, '6_Trials_Info_and_Epoched_data', ...
        ['sub-', num2str(subject_id)]);
    if ~isfolder(save_path)
        mkdir(save_path);
    end

    % Saved under the same variable name as before, so anything that already
    % loads these files keeps working.
    out.(spec.varName) = Epochs;
    outFile = fullfile(save_path, [spec.varName, '.mat']);

    fprintf('  writing %s (this takes a while)\n', outFile);
    save(outFile, '-struct', 'out', '-v7.3');

end


% ------------------------------------------------------------------------
function spec = basis_spec(basis)
% What one epoch is, for each basis.

    switch lower(basis)

        case 'flextoflex'
            spec.label      = 'flexion-to-flexion cycle';
            spec.startField = 'flextoflex_start_indx';
            spec.endField   = 'flextoflex_end_indx';
            spec.varName    = 'Epochs_FlextoFlex_based';
            spec.perCycle   = true;
            spec.rejectWord = 'Reject';

        case 'flexion'
            spec.label      = 'flexion';
            spec.startField = 'flexion_start_indx';
            spec.endField   = 'flexion_end_indx';
            spec.varName    = 'Epochs_Flexion_based';
            spec.perCycle   = true;
            spec.rejectWord = 'Reject';

        case 'extension'
            spec.label      = 'extension';
            spec.startField = 'extension_start_indx';
            spec.endField   = 'extension_end_indx';
            spec.varName    = 'Epochs_Extension_based';
            spec.perCycle   = true;
            spec.rejectWord = 'Reject';

        case 'trial'
            spec.label      = 'whole trial';
            spec.startField = 'Trial_start_indx';
            spec.endField   = 'Trial_end_indx';
            spec.varName    = 'Epochs_Trial_based';
            spec.perCycle   = false;
            spec.rejectWord = 'Data Loss';

        otherwise
            error('extract_epochs:UnknownBasis', ...
                ['basis must be flextoflex, flexion, extension or trial. ' ...
                 'Got "%s".'], basis);

    end

end


% ------------------------------------------------------------------------
function out = slice_by(data, startIdx, endIdx, perCycle)
% data(:, s:e) for each start and end. Returns a cell per cycle when
% perCycle is true, otherwise the single slice directly.

    if perCycle
        out = arrayfun(@(s, e) data(:, s:e), startIdx, endIdx, ...
            'UniformOutput', false);
    else
        out = data(:, startIdx:endIdx);
    end

end


% ------------------------------------------------------------------------
function ref = reference_angle(startIdx, endIdx, expTime, expData)
% The reference angle the participant was tracking, taken 5 s earlier.
%
% The reference trace is the participant's own demonstration movement,
% replayed with a 5 s offset that is set in Encoder.m during the experiment.
% Row 2 of the experiment stream holds it.

    [~, refStart] = min(abs(expTime - (expTime(startIdx) - 5)));

    refEnd = refStart + (endIdx - startIdx);

    if refEnd > size(expData, 2)
        warning('extract_epochs:ReferenceAngleTruncated', ...
            ['The reference angle window runs past the end of the ' ...
             'experiment stream. Returning what exists.']);
        refEnd = size(expData, 2);
    end

    ref = expData(2, refStart:refEnd);

end


% ------------------------------------------------------------------------
function env = emg_envelope(rawEMG, fs)
% Linear envelope: bandpass 20 to 450 Hz, rectify, lowpass at 8 Hz.
% Zero phase throughout, so the envelope is not shifted relative to the
% events.
%
% The 8 Hz is the design cutoff of the Butterworth, which is what the
% Methods section states. FILTFILT then applies that filter twice, so the
% effective magnitude response is squared and its own 3 dB point sits near
% 0.80 of the design cutoff, about 6.4 Hz. That is the usual meaning of
% "8 Hz, 2nd order, zero phase" and no compensation is applied here.

    nyq = fs / 2;

    [b, a] = butter(4, [20 450] / nyq);
    x = filtfilt(b, a, rawEMG');

    x = abs(x);

    [b, a] = butter(2, 8 / nyq);
    env = filtfilt(b, a, x)';

end