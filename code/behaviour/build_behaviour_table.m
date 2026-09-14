function [T, info] = build_behaviour_table(cfg, policy)
% BUILD_BEHAVIOUR_TABLE  The trial-level table the models and figures read.
%
%   [T, info] = build_behaviour_table()
%   [T, info] = build_behaviour_table(cfg)
%   [T, info] = build_behaviour_table(cfg, policy)
%
% policy is passed straight to screen_epochs and defaults to 'intersection'.
%
% This is a thin aggregation rather than a pipeline: screen with
% screen_epochs, collapse epochs to trials, join the two modalities on the
% key. Every decision lives in the builders or in the screening function, so
% there is one definition of a valid trial and it is visible in one place.
%
% WHAT CHANGED FROM THE OLD TABLE
%   * Trial numbers are raw indices throughout. The old table carried indices
%     compacted by the EMG builder, so it silently disagreed with the tracking
%     data for subjects 9, 11, 12 and 18.
%   * Error is the mean absolute difference between knee angle and reference.
%     The old column was the same quantity, but the manuscript describes it as
%     root-mean-square, which it is not. Per-epoch RMS runs 1.216 times larger.
%     Both columns are carried here so the two can never be confused again.
%   * FlexorIndex and ExtensorIndex are correctly assigned. Vastus medialis
%     and rectus femoris are extensors; gastrocnemius and biceps femoris are
%     flexors. The old table had them reversed. EffortIndex sums all four and
%     was never affected.
%   * Rows are never dropped for a reason belonging to another modality. A
%     participant with no EMG keeps their ratings and their tracking.
%
% Writes behaviour_table.mat under cfg.masters, holding T and info.
%
% See also SCREEN_EPOCHS, BUILD_EMG_MASTER, BUILD_TRACKING_MASTER.

    if nargin < 1 || isempty(cfg),    cfg = kneeexo_config(); end
    if nargin < 2 || isempty(policy), policy = 'intersection'; end

    out_path    = cfg.masters;
    LEVELS      = cfg.pressures;          % [1 3 6] bar
    COND_NAMES  = cfg.conditionNames;     % Low, Medium, High
    MUSCLE_COLS = {'iEMG_VM','iEMG_RF','iEMG_GM','iEMG_BF'};

    emgFile = fullfile(out_path, 'emg_master_index.mat');
    trkFile = fullfile(out_path, 'trk_master_index.mat');
    for f = {emgFile, trkFile}
        if ~exist(f{1}, 'file')
            error('build_behaviour_table:NoMaster', ...
                ['%s is missing. Run run_build_masters.m first: this ' ...
                 'function aggregates the masters, it does not build ' ...
                 'them.'], f{1});
        end
    end

    L = load(emgFile, 'masterIndex'); E = L.masterIndex;
    L = load(trkFile, 'masterIndex'); X = L.masterIndex;
    clear L

    [keepE, keepX, info] = screen_epochs(E, X, policy);

    fprintf('Policy: %s\n', info.policy);
    fprintf('  EMG      %d epochs, %d trials, %d subjects\n', ...
        info.epochsEMG, info.trialsEMG, info.subjectsEMG);
    fprintf('  Tracking %d epochs, %d trials, %d subjects\n', ...
        info.epochsTrack, info.trialsTrack, info.subjectsTrack);
    if isfield(info, 'subjectsWithoutEMG')
        fprintf('  Retained without EMG: %s\n', mat2str(info.subjectsWithoutEMG));
    end


    %% 1. Epochs to trials
    % -----------------------------------------------------------------
    % Epochs are averaged within a trial before anything else. Epoch counts
    % vary between trials, so pooling epochs would weight long trials more
    % heavily, and trial is the unit every model in the paper operates on.

    Ek = E(keepE, :);
    [ge, keyE] = findgroups(Ek(:, {'SubjectID','RawTrial'}));
    TE = keyE;
    TE.Pressure   = splitapply(@(x) x(1), Ek.Pressure, ge);
    TE.Score      = splitapply(@(x) x(1), Ek.Score,    ge);
    TE.NEpochsEMG = splitapply(@numel,    Ek.Pressure, ge);
    for m = 1:numel(MUSCLE_COLS)
        TE.(MUSCLE_COLS{m}) = splitapply(@mean, Ek.(MUSCLE_COLS{m}), ge);
    end

    Xk = X(keepX, :);
    [gx, keyX] = findgroups(Xk(:, {'SubjectID','RawTrial'}));
    TX = keyX;
    TX.Pressure   = splitapply(@(x) x(1), Xk.Pressure, gx);
    TX.Score      = splitapply(@(x) x(1), Xk.Score,    gx);
    TX.NEpochsTrk = splitapply(@numel,    Xk.Pressure, gx);
    TX.Error      = splitapply(@mean, Xk.MeanAbsError, gx);
    TX.RMSError   = splitapply(@mean, Xk.RMSError,     gx);


    %% 2. Normalise the EMG within subject
    % -----------------------------------------------------------------
    % Each muscle is divided by that subject's own mean across retained
    % trials, which removes between-subject amplitude differences arising
    % from electrode placement and tissue. Being a scalar divide per muscle
    % it leaves condition ratios untouched, so fold changes are unaffected.
    %
    % One consequence to keep in mind downstream: after this, every
    % participant's mean effort index is exactly four by construction, so
    % the between-subject term in a mediation has no variance to estimate.

    subsE = unique(TE.SubjectID);
    for i = 1:numel(subsE)
        s = TE.SubjectID == subsE(i);
        for m = 1:numel(MUSCLE_COLS)
            TE.(MUSCLE_COLS{m})(s) = ...
                TE.(MUSCLE_COLS{m})(s) / mean(TE.(MUSCLE_COLS{m})(s));
        end
    end

    % Anatomy, stated once so the assignment cannot drift again:
    %   vastus medialis, rectus femoris -> knee extensors
    %   gastrocnemius, biceps femoris   -> knee flexors
    TE.ExtensorIndex = TE.iEMG_VM + TE.iEMG_RF;
    TE.FlexorIndex   = TE.iEMG_GM + TE.iEMG_BF;
    TE.EffortIndex   = TE.ExtensorIndex + TE.FlexorIndex;


    %% 3. Join
    % -----------------------------------------------------------------
    % Left outer join on the key, so trials present in tracking but not in
    % EMG are retained with NaN rather than dropped. Under the intersection
    % policy the only such rows are the participant without EMG.

    T = outerjoin(TX, TE, 'Keys', {'SubjectID','RawTrial'}, ...
        'MergeKeys', true, 'Type', 'left');

    % outerjoin suffixes the duplicated columns; keep one copy of each.
    T.Pressure = T.Pressure_TX;
    T.Score    = T.Score_TX;
    T = removevars(T, {'Pressure_TX','Score_TX','Pressure_TE','Score_TE'});

    % Convenience columns for the models.
    T.Pressure_cat  = reordercats(categorical(T.Pressure, LEVELS, COND_NAMES), ...
                                  COND_NAMES);
    T.Pressure_ord  = double(T.Pressure_cat) - 1;         % 0, 1, 2
    T.Error_c       = T.Error       - mean(T.Error,       'omitnan');
    T.EffortIndex_c = T.EffortIndex - mean(T.EffortIndex, 'omitnan');

    T = sortrows(T, {'SubjectID','RawTrial'});


    %% 4. Checks
    % -----------------------------------------------------------------
    fprintf('\n--- Behaviour table ---\n');
    fprintf('Rows: %d, subjects: %d\n', height(T), numel(unique(T.SubjectID)));
    fprintf('Rows with EMG: %d, without: %d\n', ...
        sum(~isnan(T.EffortIndex)), sum(isnan(T.EffortIndex)));

    fprintf('\nTrials per subject and condition:\n');
    disp(unstack(groupsummary(T, {'SubjectID','Pressure_cat'}), ...
        'GroupCount', 'Pressure_cat'));

    report_condition_means(T, LEVELS);

    % The check that would have caught the trial-numbering divergence:
    % every trial here must exist in the tracking master under the same key.
    assert(all(ismember(T(:, {'SubjectID','RawTrial'}), ...
        unique(X(:, {'SubjectID','RawTrial'})))), ...
        'A trial in the behaviour table is absent from the tracking master.');
    fprintf('\nKey check passed: every trial exists in the tracking master.\n');

    save(fullfile(out_path, 'behaviour_table.mat'), 'T', 'info');
    fprintf('Saved behaviour_table.mat to %s\n', out_path);

end


% ------------------------------------------------------------------------
function report_condition_means(T, LEVELS)
% Across-subject means of per-subject condition means, against the values
% validated from the old pipeline. A mismatch here means a screen changed,
% and checks/acceptance_test.m says which.

    subs = unique(T.SubjectID);
    R = nan(numel(subs), 3);
    Q = nan(numel(subs), 3);
    F = nan(numel(subs), 3);

    for i = 1:numel(subs)
        for c = 1:3
            s = T.SubjectID == subs(i) & T.Pressure == LEVELS(c);
            R(i,c) = mean(T.Score(s),       'omitnan');
            Q(i,c) = mean(T.Error(s),       'omitnan');
            F(i,c) = mean(T.EffortIndex(s), 'omitnan');
        end
    end

    fprintf('\n--- Condition means (across subject means) ---\n');
    fprintf('Perceived difficulty %6.2f %6.2f %6.2f   (target 1.80 4.23 6.99)\n', ...
        mean(R, 1, 'omitnan'));
    fprintf('Tracking error       %6.2f %6.2f %6.2f   (target 5.73 6.06 6.19)\n', ...
        mean(Q, 1, 'omitnan'));
    fprintf('Effort index         %6.2f %6.2f %6.2f   (target 2.96 3.96 5.02)\n', ...
        mean(F, 1, 'omitnan'));

end