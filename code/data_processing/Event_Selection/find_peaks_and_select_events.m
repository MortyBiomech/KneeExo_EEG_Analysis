function output_peaks = find_peaks_and_select_events(output, subject_id)


    %% Extract the data
    All_Experiment = output.All_Exp;
    All_Experiment_time = output.All_Exp_time;
    

    %% find start and end of trials and movements
    % start_move event (second single beep, 2s after pressure change)
    if subject_id > 9
        start_move = find(diff(All_Experiment(6, :)) == 1);
        start_move = reshape(start_move, 2, []);
        start_move_time_Expdata = All_Experiment_time(start_move(2,:));
    else
        start_move = find(diff(All_Experiment(6, :)) == 1);
        start_move_time_Expdata = All_Experiment_time(start_move);
    end

    % finish_beep event (20s after start_move event, double beep to stop movement)
    if subject_id > 9
        finish_beep = find(diff(All_Experiment(6, :)) == -2);
        finish_beep_time_Expdata = All_Experiment_time(finish_beep);
    else
        finish_beep = find(diff(All_Experiment(6, :)) == -1);
        finish_beep_time_Expdata = All_Experiment_time(finish_beep);
    end

    
    %% find start and finish beep moments
    XLimits = [start_move_time_Expdata' finish_beep_time_Expdata'];
    [pks_high_peaks, locs_high_peaks] = findpeaks(All_Experiment(1, :));
    [pks_low_peaks, locs_low_peaks] = findpeaks((-1)*All_Experiment(1, :));
    pks_low_peaks = -pks_low_peaks;
    

    %% find peaks between single and double beep sounds
    trial_pks_high_peaks  = [];
    trial_locs_high_peaks = [];
    
    trial_pks_low_peaks   = [];
    trial_locs_low_peaks  = [];
    
    if subject_id > 9
        idx = 2;
    else
        idx = 1;
    end

    for i = 1:length(start_move_time_Expdata)
        trial_locs_high_peaks = cat(2 , trial_locs_high_peaks, ...
            locs_high_peaks(1, ...
            start_move(idx, i) <= locs_high_peaks & ...
            locs_high_peaks <= finish_beep(1, i)));
        trial_pks_high_peaks = cat(2, trial_pks_high_peaks, ...
            pks_high_peaks(1, ...
            start_move(idx, i) <= locs_high_peaks & ...
            locs_high_peaks <= finish_beep(1, i)));
    
        trial_locs_low_peaks = cat(2, trial_locs_low_peaks, ...
            locs_low_peaks(1, ...
            start_move(idx, i) <= locs_low_peaks & ...
            locs_low_peaks <= finish_beep(1, i)));
        trial_pks_low_peaks = cat(2, trial_pks_low_peaks, ...
            pks_low_peaks(1, ...
            start_move(idx, i) <= locs_low_peaks & ...
            locs_low_peaks <= finish_beep(1, i)));
    end


    %% Number of Trials
    N_Trials = size(XLimits, 1);
    

    %% Initialize Trials information
    Trials_encoder_events = ...
        repmat({struct('Description', [], 'Pressure', [], 'Score', [], ...
        'high_peaks', [], 'low_peaks', [], 'Case', [], ...
        'Flexion_Start', [], 'Flexion_End', [], ...
        'Extension_Start', [], 'Extension_End', [])}, ...
        1, size(XLimits,1));


    %% make the output
    output_peaks.XLimits = XLimits;

    output_peaks.trial_pks_high_peaks = trial_pks_high_peaks;
    output_peaks.trial_locs_high_peaks = trial_locs_high_peaks;

    output_peaks.trial_pks_low_peaks = trial_pks_low_peaks;
    output_peaks.trial_locs_low_peaks = trial_locs_low_peaks;

    output_peaks.N_Trials = N_Trials;

    output_peaks.Trials_encoder_events = Trials_encoder_events;


end