% Rebuild the EMG classification features into a SEPARATE folder.
%
% Why this script exists
% ----------------------
% Every sub-N_structured_EMG_data.mat on disk has empty Signal_TimeWarped,
% Flexion_Extension_Lengths, Outlier and Classification_Features. Only the raw
% per-cycle Signal survives. In main_EMG_processing.m the four stages that
% produce those fields (:114 time warp, :194 outlier detection, :252 outlier
% field, :293 feature extraction) are all commented out, while the save at :355
% is live - so any run of that script rewrites every subject's .mat with the
% derived fields blanked. That is how the features were lost.
%
% This script reproduces those four stages and writes to
% structured_EMG_data_rebuilt\, leaving main_EMG_processing.m and the existing
% structured_EMG_data\ untouched.
%
% One necessary correction, not a discretionary change
% ----------------------------------------------------
% Main_data holds only trials whose EMG_stream.Sensors_Preprocessed is non-empty,
% while Trials_Info holds every trial. The two index spaces coincide for 9 of the
% 13 subjects but NOT for sub-9, sub-11, sub-12 and sub-18. The commented time
% warp block pairs Main_data{1,j} with Trials_Info{1,j} directly, so for those
% subjects it would index past the end of Main_data and, for every trial after
% the first dropped one, pair a trial's EMG with a different trial's event
% indices. This script therefore records an explicit Main_data -> Trials_Info
% map during stage 0 and uses it everywhere downstream.
%
% Likewise, stage 0 in the original indexes the Trials_Info event arrays with the
% compacted within-trial counter kk, while the time warp block indexes the same
% arrays with a logical mask over all epochs. Those disagree whenever an epoch is
% dropped for being shorter than the sample threshold. One retained-epoch mask is
% built here and reused everywhere, so Signal and its events cannot drift apart.
% The original also used "< 2000" to drop and "> 2000" to keep, which disagree at
% exactly 2000 samples; the drop rule (keep >= 2000) is the one used here because
% it is what actually built Signal.
%
% Diagnostics are printed per subject and collected in rebuild_report.
% Nothing is written outside structured_EMG_data_rebuilt\.

clc
clear

%% Add and Define Necessary Paths
% Everything comes from the repository config, so this runs from a fresh
% clone. Put config on the path first:  addpath('config')  -- see README.
cfg = ansymb_config();
addpath(genpath(cfg.code));

if isempty(cfg.raw)
    error(['This stage reads per-subject intermediates that are not ' ...
           'shipped with the repository. Set cfg.raw in ' ...
           'config/ansymb_config.m to your copy of the dataset.']);
end

epoched_data_path = cfg.trialsInfo;
output_root       = cfg.structuredEMGRebuilt;
if ~isfolder(output_root)
    mkdir(output_root);
end

MIN_EPOCH_SAMPLES = 2000;   % an epoch shorter than this never entered Signal

subjects_list = [5 6 7 8 9 11 12 13 14 15 16 17 18];  % sub-10 has no EMG file

rebuild_report = table('Size', [numel(subjects_list) 9], ...
    'VariableTypes', {'double','double','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'Subject','nTrialsInfo','nMainData','nTrialsDropped', ...
                      'nEpochsDropped','nEpochsTimeWarped','nEpochsFailedConstraint', ...
                      'nTrialsWithFeatures','nTrialsNaNFeatures'});


for i = 1:length(subjects_list)
    subj = subjects_list(i);
    disp(['subject ', num2str(subj)])
    subjTimer = tic;

    filename = ['sub-', num2str(subj), '\Epochs_FlextoFlex_based.mat'];
    data = load(fullfile(epoched_data_path, filename));
    name = fieldnames(data);
    data = data.(name{1});

    filename = ['sub-', num2str(subj), '\Trials_Info.mat'];
    Trials_Info = load(fullfile(epoched_data_path, filename));
    name = fieldnames(Trials_Info);
    Trials_Info = Trials_Info.(name{1});


    %% Stage 0 - assemble Main_data (reproduces the live part of main_EMG_processing.m)
    % TrialIndex and RetainedEpochMask are the additions: they are what let every
    % later stage get back to the right Trials_Info entry and the right events.
    emg_struct = struct('Names', [], 'events', [], 'time', [], ...
        'Signal', [], 'Signal_TimeWarped', [], ...
        'Flexion_Extension_Lengths', [],'Pressure', [], ...
        'Score', [], 'Description', [], 'Outlier', [], ...
        'Classification_Features', struct('per_trial', [], 'all_epochs', []), ...
        'TrialIndex', [], 'RetainedEpochMask', []);

    length_of_trials = cellfun(@(x) length(x.EMG_stream.Sensors_Preprocessed), data);
    nonzero_trials = sum(length_of_trials ~= 0);
    Main_data = repmat({emg_struct}, 1, nonzero_trials);

    nEpochsDropped = 0;

    jj = 0;
    for j = 1:length(data)

        if isempty(data{1, j}.EMG_stream.Sensors_Preprocessed)
            continue
        end
        jj = jj + 1;

        muscles_names = data{1, j}.General.Muscles_Names;

        % One mask over ALL epochs of this trial, used for Signal and for every
        % lookup into the Trials_Info event arrays.
        epochLengths = cellfun(@(x) size(x, 2), data{1, j}.EMG_stream.Sensors_Preprocessed);
        retained = epochLengths >= MIN_EPOCH_SAMPLES;
        nEpochsDropped = nEpochsDropped + sum(~retained);

        flexStart = Trials_Info{1, j}.Events.EMG_stream.flextoflex_start_indx;
        extStart  = Trials_Info{1, j}.Events.EMG_stream.extension_start_indx;
        flexEnd   = Trials_Info{1, j}.Events.EMG_stream.flextoflex_end_indx;

        retainedIdx = find(retained);
        kk = 0;
        for k = retainedIdx(:)'
            kk = kk + 1;

            % event, expressed relative to the start of its own cycle
            e = [flexStart(k), extStart(k), flexEnd(k)] - repmat(flexStart(k) - 1, 1, 3);
            Main_data{1, jj}.events = cat(1, Main_data{1, jj}.events, e);

            % time
            Main_data{1, jj}.time{1, kk} = data{1, j}.EMG_stream.Times{1, k};

            % Vastus_med_R
            index = strcmp(muscles_names, 'Vastus_med_R');
            Main_data{1, jj}.Signal{1, kk}(1, :) = data{1, j}.EMG_stream.Sensors_Preprocessed{1, k}(index, :);
            Main_data{1, jj}.Names{1, 1} = 'Vastus_med_R';
            % Rectus_femoris_R
            index = strcmp(muscles_names, 'Rectus_femoris_R');
            Main_data{1, jj}.Signal{1, kk}(2, :) = data{1, j}.EMG_stream.Sensors_Preprocessed{1, k}(index, :);
            Main_data{1, jj}.Names{1, 2} = 'Rectus_femoris_R';
            % Gastrocnemius_R
            index = strcmp(muscles_names, 'Gastrocnemius_R');
            Main_data{1, jj}.Signal{1, kk}(3, :) = data{1, j}.EMG_stream.Sensors_Preprocessed{1, k}(index, :);
            Main_data{1, jj}.Names{1, 3} = 'Gastrocnemius_R';
            % Biceps_femoris_R
            index = strcmp(muscles_names, 'Biceps_femoris_R');
            Main_data{1, jj}.Signal{1, kk}(4, :) = data{1, j}.EMG_stream.Sensors_Preprocessed{1, k}(index, :);
            Main_data{1, jj}.Names{1, 4} = 'Biceps_femoris_R';
        end

        % check again so we don't pass an empty cell to the next steps
        if isempty(Main_data{1, jj}.Signal)
            jj = jj - 1;
            continue
        end

        Main_data{1, jj}.TrialIndex = j;                 % -> Trials_Info index
        Main_data{1, jj}.RetainedEpochMask = retained;   % -> event array index

        Main_data{1, jj}.Pressure = Trials_Info{1, j}.General.Pressure;
        Main_data{1, jj}.Score = Trials_Info{1, j}.General.Score;
        if subj >= 10
            Main_data{1, jj}.Description = Trials_Info{1, j}.General.Description;
        else
            Main_data{1, jj}.Description = 'Experiment';
        end
    end
    Main_data = Main_data(1:jj);   % trim if any trial fell out at the last check


    %% Stage 1 - linear time warp to a common length (main_EMG_processing.m:114)
    % Pool the retained cycles of experimental trials to find the median
    % flexion / extension lengths, then resample every cycle onto them.
    events = [];
    for m = 1:numel(Main_data)
        if ~strcmp(Main_data{1, m}.Description, 'Experiment')
            continue
        end
        j = Main_data{1, m}.TrialIndex;
        retained = Main_data{1, m}.RetainedEpochMask;

        flextoflex_start = Trials_Info{1, j}.Events.EMG_stream.flextoflex_start_indx(retained);
        extension_start  = Trials_Info{1, j}.Events.EMG_stream.extension_start_indx(retained);
        flextoflex_end   = Trials_Info{1, j}.Events.EMG_stream.flextoflex_end_indx(retained);

        flextoflex_start = reshape(flextoflex_start, [], 1);
        extension_start  = reshape(extension_start,  [], 1);
        flextoflex_end   = reshape(flextoflex_end,   [], 1);

        n = length(flextoflex_start);
        events = cat(1, events, ...
            [flextoflex_start, extension_start(1:n), flextoflex_end(1:n)]);
    end

    flexion_lengths   = events(:,2) - events(:,1);
    extension_lengths = events(:,3) - events(:,2);

    median_flexion_length   = floor(median(flexion_lengths));
    median_extension_length = floor(median(extension_lengths));

    flexion_lower_lim = median_flexion_length - 3*floor(std(flexion_lengths));
    flexion_upper_lim = median_flexion_length + 3*floor(std(flexion_lengths));

    extension_lower_lim = median_extension_length - 3*floor(std(extension_lengths));
    extension_upper_lim = median_extension_length + 3*floor(std(extension_lengths));

    nWarped = 0; nFailed = 0;
    for m = 1:numel(Main_data)
        j = Main_data{1, m}.TrialIndex;
        retainedIdx = find(Main_data{1, m}.RetainedEpochMask);

        for k = 1:length(Main_data{1, m}.Signal)
            if isempty(Main_data{1, m}.Signal{1, k})
                continue
            end

            Main_data{1, m}.Signal_TimeWarped{1, k} = [];

            kOrig = retainedIdx(k);   % index into the full event arrays
            L_Flx = Trials_Info{1, j}.Events.EMG_stream.extension_start_indx(kOrig) - ...
                    Trials_Info{1, j}.Events.EMG_stream.flextoflex_start_indx(kOrig);
            L_Ext = Trials_Info{1, j}.Events.EMG_stream.flextoflex_end_indx(kOrig) - ...
                    Trials_Info{1, j}.Events.EMG_stream.extension_start_indx(kOrig);

            constraint1 = and(L_Flx > flexion_lower_lim,   L_Flx < flexion_upper_lim);
            constraint2 = and(L_Ext > extension_lower_lim, L_Ext < extension_upper_lim);

            if constraint1 && constraint2
                flexion_indexes   = 1:L_Flx+1;
                extension_indexes = L_Flx+2:L_Flx+L_Ext+1;

                signal_old = Main_data{1, m}.Signal{1, k};
                if size(signal_old, 2) < L_Flx + L_Ext + 1
                    nFailed = nFailed + 1;
                    continue   % event indices outrun the stored signal; skip
                end
                flexion_part_old   = signal_old(:, flexion_indexes);
                extension_part_old = signal_old(:, extension_indexes);

                new_flexion_part   = interp1(1:L_Flx+1, flexion_part_old', ...
                    linspace(1, L_Flx+1, median_flexion_length+1), "linear");
                new_extension_part = interp1(1:L_Ext, extension_part_old', ...
                    linspace(1, L_Ext, median_extension_length), "linear");

                Main_data{1, m}.Signal_TimeWarped{1, k} = ...
                    [new_flexion_part', new_extension_part'];
                nWarped = nWarped + 1;
            else
                nFailed = nFailed + 1;
            end
        end
        Main_data{1, m}.Flexion_Extension_Lengths = ...
            [median_flexion_length, median_extension_length];
    end


    %% Stage 2 - outlier detection (main_EMG_processing.m:194)
    features = cell(size(Main_data));
    for m = 1:length(features)
        for k = 1:length(Main_data{1, m}.Signal)
            if isempty(Main_data{1, m}.Signal{1, k})
                continue
            end
            features{1, m}{1, k} = OutlierDetection_features(Main_data{1, m}.Signal{1, k});
        end
    end

    features_P1 = []; features_P3 = []; features_P6 = [];
    P1_outlier_idx = []; P3_outlier_idx = []; P6_outlier_idx = [];

    for m = 1:length(features)
        if isempty(features{1, m})
            continue
        end
        c = cellfun(@(x) isempty(x), features{1, m});
        empty_indexes = find(c == 1);
        indexes = setdiff(1:length(features{1, m}), empty_indexes);

        switch Main_data{1, m}.Pressure
            case 1
                features_P1 = cat(3, features_P1, features{1, m}{:});
                P1_outlier_idx = cat(2, P1_outlier_idx, [indexes ; m*ones(size(indexes))]);
            case 3
                features_P3 = cat(3, features_P3, features{1, m}{:});
                P3_outlier_idx = cat(2, P3_outlier_idx, [indexes ; m*ones(size(indexes))]);
            case 6
                features_P6 = cat(3, features_P6, features{1, m}{:});
                P6_outlier_idx = cat(2, P6_outlier_idx, [indexes ; m*ones(size(indexes))]);
        end
    end

    outliers_P1 = OutlierDetection_MD_method(features_P1);
    outliers_P3 = OutlierDetection_MD_method(features_P3);
    outliers_P6 = OutlierDetection_MD_method(features_P6);


    %% Stage 3 - fill the Outlier field (main_EMG_processing.m:252)
    for m = 1:length(Main_data)
        Main_data{1, m}.Outlier = zeros(4, length(Main_data{1, m}.Signal));
    end

    for muscle = 1:4
        Main_data = markOutliers(Main_data, outliers_P1, P1_outlier_idx, muscle);
        Main_data = markOutliers(Main_data, outliers_P3, P3_outlier_idx, muscle);
        Main_data = markOutliers(Main_data, outliers_P6, P6_outlier_idx, muscle);
    end


    %% Stage 4 - extract the classification features (main_EMG_processing.m:293)
    % RMS of 4 right-leg muscles over the flexion and extension halves of the
    % time-warped cycle, averaged over the non-outlier cycles of the trial
    % -> a 1x8 vector per trial.
    nWithFeatures = 0; nNaNFeatures = 0;

    for m = 1:length(Main_data)
        perMuscle = cell(4, 2);   % {muscle, 1} flexion, {muscle, 2} extension

        for k = 1:length(Main_data{1, m}.Signal_TimeWarped)
            if isempty(Main_data{1, m}.Signal_TimeWarped{1, k})
                continue
            end
            S = Main_data{1, m}.Signal_TimeWarped{1, k};

            for muscle = 1:4
                if Main_data{1, m}.Outlier(muscle, k) == 0
                    perMuscle{muscle, 1} = cat(2, perMuscle{muscle, 1}, ...
                        rms(S(muscle, 1:median_flexion_length+1)'));
                    perMuscle{muscle, 2} = cat(2, perMuscle{muscle, 2}, ...
                        rms(S(muscle, median_flexion_length+2:end)'));
                end
            end
        end

        final_features = zeros(1, 8);
        for muscle = 1:4
            final_features(2*muscle-1) = mean(perMuscle{muscle, 1});
            final_features(2*muscle)   = mean(perMuscle{muscle, 2});
        end

        if any(isnan(final_features))
            nNaNFeatures = nNaNFeatures + 1;
            continue   % leave per_trial empty, exactly as the original did
        end

        Main_data{1, m}.Classification_Features.per_trial = final_features;
        nWithFeatures = nWithFeatures + 1;
    end


    %% Save into the rebuilt tree - never into structured_EMG_data\
    outDir = fullfile(output_root, ['sub-', num2str(subj)]);
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    save(fullfile(outDir, ['sub-', num2str(subj), '_structured_EMG_data.mat']), ...
        'Main_data', '-v7.3');

    rebuild_report(i, :) = {subj, numel(Trials_Info), numel(Main_data), ...
        numel(Trials_Info) - numel(Main_data), nEpochsDropped, nWarped, nFailed, ...
        nWithFeatures, nNaNFeatures};

    fprintf(['  trials %d/%d (dropped %d) | epochs dropped %d | warped %d, failed %d | ', ...
        'features %d, NaN %d | %.1f s\n'], ...
        numel(Main_data), numel(Trials_Info), numel(Trials_Info)-numel(Main_data), ...
        nEpochsDropped, nWarped, nFailed, nWithFeatures, nNaNFeatures, toc(subjTimer));

    clear data Main_data Trials_Info features
end

disp(' ')
disp('=== rebuild report ===')
disp(rebuild_report)
writetable(rebuild_report, fullfile(output_root, 'rebuild_report.csv'));
fprintf('written to %s\n', output_root);


function Main_data = markOutliers(Main_data, outliers, outlier_idx, muscle)
    % Reproduces main_EMG_processing.m:258-284 for one muscle and one pressure.
    if isempty(outliers) || isempty(outliers{muscle, 1})
        return
    end
    for p = 1:length(outliers{muscle, 1})
        col = outliers{muscle, 1}(p);
        trial_index = outlier_idx(2, col);
        epoch_index = outlier_idx(1, col);
        Main_data{1, trial_index}.Outlier(muscle, epoch_index) = 1;
    end
end
