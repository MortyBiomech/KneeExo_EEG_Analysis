function output_peaks = detect_encoder_peaks(output, subject_id)
% DETECT_ENCODER_PEAKS  Find candidate flexion and extension turning points.
%
%   output_peaks = detect_encoder_peaks(output, subject_id)
%
% Runs findpeaks on the knee angle channel of the experiment stream and keeps
% the peaks that fall between the movement start and the finish beep of each
% trial. High peaks are the maximally flexed positions, low peaks the
% maximally extended ones.
%
% This is automatic and deterministic. It does NOT select anything: the
% output is a list of candidates plus an empty Trials_encoder_events template
% for the app to fill in. A person then discards the false detections in
% find_flexion_extension_events.mlapp, and that is the step whose result
% ships as derived data.
%
% The old name, find_peaks_and_select_events, implied this function did the
% selecting, which sent people looking for the manual step in the wrong file.
%
% Returns
%   XLimits                  nTrials x 2, the movement window of each trial
%                            in experiment-stream time
%   trial_pks_high_peaks     values and indices of the accepted candidates,
%   trial_locs_high_peaks    concatenated across trials
%   trial_pks_low_peaks
%   trial_locs_low_peaks
%   N_Trials
%   Trials_encoder_events    1 x nTrials cell of empty templates
%
% The trigger scheme changed after participant 9, so the movement start and
% the finish beep are read differently on either side of that.

    All_Experiment      = output.All_Exp;
    All_Experiment_time = output.All_Exp_time;

    % Channel 1 of the experiment stream is the knee encoder.
    knee_angle = All_Experiment(1, :);

    if subject_id > 9
        idx = 2;
    else
        idx = 1;
    end


    %% Movement window of each trial
    % start_move: the second single beep, 2 s after the pressure change.
    start_move = find(diff(All_Experiment(6, :)) == 1);
    if subject_id > 9
        start_move = reshape(start_move, 2, []);
        start_move_time_Expdata = All_Experiment_time(start_move(2, :));
    else
        start_move_time_Expdata = All_Experiment_time(start_move);
    end

    % finish_beep: the double beep 20 s later that ends the movement.
    if subject_id > 9
        finish_beep = find(diff(All_Experiment(6, :)) == -2);
    else
        finish_beep = find(diff(All_Experiment(6, :)) == -1);
    end
    finish_beep_time_Expdata = All_Experiment_time(finish_beep);

    XLimits = [start_move_time_Expdata', finish_beep_time_Expdata'];

    nTrials = size(XLimits, 1);
    if numel(finish_beep) ~= size(start_move, 2)
        warning('detect_encoder_peaks:UnbalancedTrialMarkers', ...
            ['sub-%d has %d movement starts against %d finish beeps. The ' ...
             'trial windows below are built from the shorter of the two.'], ...
            subject_id, size(start_move, 2), numel(finish_beep));
    end


    %% Candidate turning points over the whole recording
    [pks_high_peaks, locs_high_peaks] = findpeaks(knee_angle);
    [pks_low_peaks,  locs_low_peaks]  = findpeaks(-knee_angle);
    pks_low_peaks = -pks_low_peaks;


    %% Keep the ones inside a movement window
    trial_pks_high_peaks  = [];
    trial_locs_high_peaks = [];
    trial_pks_low_peaks   = [];
    trial_locs_low_peaks  = [];

    for i = 1:nTrials

        from = start_move(idx, i);
        to   = finish_beep(1, i);

        inWindowHigh = locs_high_peaks >= from & locs_high_peaks <= to;
        inWindowLow  = locs_low_peaks  >= from & locs_low_peaks  <= to;

        trial_locs_high_peaks = [trial_locs_high_peaks, locs_high_peaks(inWindowHigh)]; %#ok<AGROW>
        trial_pks_high_peaks  = [trial_pks_high_peaks,  pks_high_peaks(inWindowHigh)];  %#ok<AGROW>

        trial_locs_low_peaks  = [trial_locs_low_peaks,  locs_low_peaks(inWindowLow)];   %#ok<AGROW>
        trial_pks_low_peaks   = [trial_pks_low_peaks,   pks_low_peaks(inWindowLow)];    %#ok<AGROW>

    end

    fprintf('sub-%d: %d trials, %d high and %d low candidate peaks\n', ...
        subject_id, nTrials, numel(trial_locs_high_peaks), ...
        numel(trial_locs_low_peaks));


    %% Empty template for the editor to fill
    Trials_encoder_events = repmat( ...
        {struct('Description', [], 'Pressure', [], 'Score', [], ...
                'high_peaks', [], 'low_peaks', [], 'Case', [], ...
                'Flexion_Start', [], 'Flexion_End', [], ...
                'Extension_Start', [], 'Extension_End', [])}, 1, nTrials);


    %% Output
    output_peaks.XLimits               = XLimits;
    output_peaks.trial_pks_high_peaks  = trial_pks_high_peaks;
    output_peaks.trial_locs_high_peaks = trial_locs_high_peaks;
    output_peaks.trial_pks_low_peaks   = trial_pks_low_peaks;
    output_peaks.trial_locs_low_peaks  = trial_locs_low_peaks;
    output_peaks.N_Trials              = nTrials;
    output_peaks.Trials_encoder_events = Trials_encoder_events;

end