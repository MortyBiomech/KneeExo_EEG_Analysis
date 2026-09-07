%% BUILD_EMG_MASTER
%  Rebuilds the EMG data on a flag-based architecture.
%
%  THE PRINCIPLE. Every raw trial and every raw epoch gets a row, and no
%  row is ever removed. Quality decisions are recorded as boolean columns
%  and applied at analysis time. Position never carries identity: each
%  row is identified by (SubjectID, RawTrial, RawEpoch), assigned before
%  anything is judged good or bad.
%
%  WHY. The previous pipeline compacted at two levels. Trials without EMG
%  advanced a separate counter jj, so Main_data sat at compacted
%  positions while its metadata was read at raw ones, and the behaviour
%  table inherited compacted trial numbers while the tracking pipeline
%  kept raw ones. Within a trial, epochs under 2000 samples were skipped
%  with a counter kk, and the builder then read the signal at the raw
%  index k but the event boundaries at kk, so later epochs in that trial
%  were warped on another epoch's reversal point. Neither fault announces
%  itself: the values stay valid, they simply attach to the wrong row.
%  Keeping every row and flagging instead makes both impossible.
%
%  OUTPUT
%    per subject : emg_master_sub-XX.mat, holding
%                    E        epoch table, one row per raw epoch
%                    Sig      cell array of 4 x nSamples signals,
%                             indexed by row of E, empty where absent
%                    muscles  channel order
%    overall     : emg_master_index.mat, the concatenated table without
%                  signals, for querying and for building the behaviour
%                  table.
%
%  Nothing here screens, normalises or warps. Those are analysis steps and
%  belong downstream, where the flags are applied.
% =====================================================================

clc; clear;

%% Configuration
% ---------------------------------------------------------------------
data_path          = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
epoched_data_path  = [data_path, '6_Trials_Info_and_Epoched_data\'];
out_path           = [data_path, '7_Master_Tables\'];

subject_list    = 5:18;
MUSCLES         = {'Vastus_med_R','Rectus_femoris_R','Gastrocnemius_R','Biceps_femoris_R'};
EMG_FS          = 2000;          % Hz
MIN_EMG_SAMPLES = 2000;          % one second, the old builder's threshold

if ~exist(out_path,'dir'), mkdir(out_path); end
home = pwd;
masterIndex  = table();
masterTrials = table();

for subID = subject_list

    fprintf('Subject %d ... ', subID);

    cd([epoched_data_path, 'sub-', num2str(subID)]);
    load Epochs_FlextoFlex_based.mat
    load Trials_Info.mat
    cd(home);

    nTrials = numel(Epochs_FlextoFlex_based);

    % ---- Pass 1: count epochs, so the table can be preallocated -------
    % Epoch count comes from the EXP stream, because events are detected
    % on the encoder there and translated to the other modalities. The
    % correspondence check confirmed the counts match exactly, so this
    % count is authoritative for every stream.
    nEpPerTrial = zeros(nTrials,1);
    for j = 1:nTrials
        ep = Epochs_FlextoFlex_based{1,j};
        if isfield(ep,'EXP_stream') && isfield(ep.EXP_stream,'Times')
            nEpPerTrial(j) = numel(ep.EXP_stream.Times);
        end
    end
    nRows = sum(nEpPerTrial);

    % ---- Preallocate ---------------------------------------------------
    SubjectID = zeros(nRows,1);
    RawTrial  = zeros(nRows,1);
    RawEpoch  = zeros(nRows,1);
    Pressure  = nan(nRows,1);
    Score     = nan(nRows,1);
    Description = strings(nRows,1);

    % Event boundaries, expressed relative to the start of the epoch and
    % 1-based. The cycle runs flexion start -> extension start -> 
    % extension end, matching the FlxS, FlxE/ExtS, ExtE labels used in the
    % figures. The middle event is simultaneously the end of flexion and
    % the start of extension, so it needs only one column.
    %
    % FlxStart is 1 by construction and ExtEnd should equal NSamples,
    % since epochs are cut at the cycle boundaries. Both are kept rather
    % than dropped: any row where ExtEnd differs from NSamples means the
    % epoch and its events disagree about where the cycle ends, which is
    % worth catching.
    FlxStart = nan(nRows,1);
    ExtStart = nan(nRows,1);
    ExtEnd   = nan(nRows,1);
    NSamples = nan(nRows,1);

    iEMG = nan(nRows, numel(MUSCLES));

    % Timing. The EMG stream is nominally uniform at 2000 Hz, so sample
    % index and time are equivalent in principle. Storing the timestamps
    % anyway buys two things index arithmetic cannot: a duration that can
    % be checked against the sample count, which exposes dropped samples,
    % and a real-time window that can be matched against the EXP stream
    % if the event translation ever needs verifying independently.
    TimeStart   = nan(nRows,1);
    TimeEnd     = nan(nRows,1);
    Duration    = nan(nRows,1);   % seconds, from the timestamps
    MaxSampleGap = nan(nRows,1);  % seconds, largest interval between samples

    % Flags. Every one records a fact; none removes a row.
    IsExperiment    = false(nRows,1);   % experimental trial, not rejected
    IsRejected      = false(nRows,1);   % trial carries a reject reason
    IsFamiliar      = false(nRows,1);   % familiarization trial
    IsNoPAM         = false(nRows,1);   % No_PAM trial
    TrialHasEMG     = false(nRows,1);   % trial carried any EMG at all
    EpochHasSignal  = false(nRows,1);   % this epoch carried EMG
    EpochLongEnough = false(nRows,1);   % at least MIN_EMG_SAMPLES
    EventsValid     = false(nRows,1);   % event indices exist and are ordered
    ScoreValid      = false(nRows,1);   % rating in 1 to 10
    AllMusclesFound = false(nRows,1);   % all four channels present
    TimingRegular   = false(nRows,1);   % no sample gap beyond tolerance
    SignalHasVariance = false(nRows,1); % every channel actually varies
    NDeadChannels   = nan(nRows,1);     % channels with zero variance

    Sig = cell(nRows,1);
    Tim = cell(nRows,1);

    % ---- Pass 2: fill, without skipping anything ----------------------
    r = 0;
    for j = 1:nTrials

        ep = Epochs_FlextoFlex_based{1,j};
        ti = Trials_Info{1,j};

        % Trial-level facts, recorded once and replicated to every epoch.
        %
        % Description is free text and inconsistent: "Familiarization" for
        % subject 5 against "Familiarizatton" for the rest, and reject
        % reasons vary down to trailing punctuation. Substring tests
        % rather than equality, so nothing depends on exact wording.
        %
        % The protocol was revised partway through the sample. Subjects 6
        % to 9 recorded experimental trials only; familiarization appears
        % for subject 5 and No_PAM from subject 10 onward. An experimental
        % fraction of 1.000 for the early subjects is therefore correct
        % and not a labelling failure.
        desc = "";
        if isfield(ti,'General') && isfield(ti.General,'Description')
            desc = string(ti.General.Description);
        end
        isRejected = contains(desc, 'Reject',    'IgnoreCase', true);
        isFamiliar = contains(desc, 'Familiar',  'IgnoreCase', true);
        isNoPAM    = contains(desc, 'No_PAM',    'IgnoreCase', true);
        isExp      = startsWith(desc, 'Experiment') & ~isRejected;
        P = NaN; S = NaN;
        if isfield(ti,'General')
            if isfield(ti.General,'Pressure'), P = ti.General.Pressure; end
            if isfield(ti.General,'Score'),    S = ti.General.Score;    end
        end

        sp = {};
        if isfield(ep,'EMG_stream') && isfield(ep.EMG_stream,'Sensors_Preprocessed')
            sp = ep.EMG_stream.Sensors_Preprocessed;
        end
        hasEMG = ~isempty(sp);

        % Muscle name lookup, once per trial.
        musIdx = nan(1, numel(MUSCLES));
        if isfield(ep,'General') && isfield(ep.General,'Muscles_Names')
            names = ep.General.Muscles_Names;
            for m = 1:numel(MUSCLES)
                hit = find(strcmp(names, MUSCLES{m}), 1);
                if ~isempty(hit), musIdx(m) = hit; end
            end
        end
        allFound = ~any(isnan(musIdx));

        % Event arrays for this trial, read at the RAW epoch index. The
        % old builder read them at a compacted index, which is the fault
        % this rebuild exists to remove.
        evA = []; evB = []; evC = [];
        if isfield(ti,'Events') && isfield(ti.Events,'EMG_stream')
            E = ti.Events.EMG_stream;
            if isfield(E,'flextoflex_start_indx'), evA = E.flextoflex_start_indx; end
            if isfield(E,'extension_start_indx'),  evB = E.extension_start_indx;  end
            if isfield(E,'flextoflex_end_indx'),   evC = E.flextoflex_end_indx;   end
        end

        for k = 1:nEpPerTrial(j)
            r = r + 1;

            SubjectID(r)   = subID;
            RawTrial(r)    = j;
            RawEpoch(r)    = k;
            Pressure(r)    = P;
            Score(r)       = S;
            Description(r) = string(ti.General.Description);

            IsExperiment(r)    = isExp;
            IsRejected(r)      = isRejected;
            IsFamiliar(r)      = isFamiliar;
            IsNoPAM(r)         = isNoPAM;
            TrialHasEMG(r)     = hasEMG;
            ScoreValid(r)      = ~isnan(S) && S >= 1 && S <= 10;
            AllMusclesFound(r) = allFound;

            % Events, at the raw epoch index.
            if numel(evA) >= k && numel(evB) >= k && numel(evC) >= k
                a = evA(k); b = evB(k); c = evC(k);
                FlxStart(r) = 1;
                ExtStart(r) = b - a + 1;
                ExtEnd(r)   = c - a + 1;
                EventsValid(r) = a < b && b < c;
            end

            % Signal and timestamps, both at the raw epoch index.
            if hasEMG && numel(sp) >= k && ~isempty(sp{1,k}) && allFound
                sig = sp{1,k}(musIdx, :);
                Sig{r} = sig;
                NSamples(r)       = size(sig,2);
                EpochHasSignal(r) = true;
                EpochLongEnough(r) = size(sig,2) >= MIN_EMG_SAMPLES;

                % Timestamps for this epoch, stored in full.
                if isfield(ep.EMG_stream,'Times') && numel(ep.EMG_stream.Times) >= k
                    tv = ep.EMG_stream.Times{1,k}(:)';
                    Tim{r} = tv;
                    if numel(tv) >= 2
                        TimeStart(r) = tv(1);
                        TimeEnd(r)   = tv(end);
                        Duration(r)  = tv(end) - tv(1);
                        dt = diff(tv);
                        MaxSampleGap(r) = max(dt);
                        % A gap beyond one and a half nominal intervals
                        % means samples went missing inside the epoch.
                        TimingRegular(r) = max(dt) < 1.5 / EMG_FS;
                    end
                end

                % A non-empty array is not a signal. Subject 10's stream
                % exists but contains only zeros, which the old pipeline
                % knew about and handled by omitting that subject from a
                % hardcoded list. A channel that never varies recorded
                % nothing, whatever its length.
                chanSD = std(double(sig), 0, 2);
                NDeadChannels(r)     = sum(chanSD <= 0);
                SignalHasVariance(r) = all(chanSD > 0);

                % Integrated EMG per channel, in signal-seconds. Stored
                % unnormalised: normalisation depends on which epochs are
                % kept, so it belongs downstream.
                iEMG(r,:) = sum(sig, 2)' / EMG_FS;
            end
        end
    end

    E = table(SubjectID, RawTrial, RawEpoch, Pressure, Score, Description, ...
        FlxStart, ExtStart, ExtEnd, NSamples, ...
        TimeStart, TimeEnd, Duration, MaxSampleGap, ...
        iEMG(:,1), iEMG(:,2), iEMG(:,3), iEMG(:,4), ...
        IsExperiment, IsRejected, IsFamiliar, IsNoPAM, ...
        TrialHasEMG, EpochHasSignal, EpochLongEnough, ...
        EventsValid, ScoreValid, AllMusclesFound, TimingRegular, ...
        SignalHasVariance, NDeadChannels, ...
        'VariableNames', ...
        {'SubjectID','RawTrial','RawEpoch','Pressure','Score','Description', ...
         'FlxStart','ExtStart','ExtEnd','NSamples', ...
         'TimeStart','TimeEnd','Duration','MaxSampleGap', ...
         'iEMG_VM','iEMG_RF','iEMG_GM','iEMG_BF', ...
         'IsExperiment','IsRejected','IsFamiliar','IsNoPAM', ...
         'TrialHasEMG','EpochHasSignal','EpochLongEnough', ...
         'EventsValid','ScoreValid','AllMusclesFound','TimingRegular', ...
         'SignalHasVariance','NDeadChannels'});

    % ---- Trial-level companion table ----------------------------------
    % A trial with no epochs produces no rows in E, so it would vanish
    % from the record entirely. That is the failure mode this rebuild
    % exists to prevent, so every raw trial gets a row here regardless of
    % how many epochs it contributed.
    TrSubject = (subID * ones(nTrials,1));
    TrRaw     = (1:nTrials)';
    TrPress   = nan(nTrials,1);
    TrScore   = nan(nTrials,1);
    TrDesc    = strings(nTrials,1);
    TrNEpoch  = nEpPerTrial;
    TrIsExp   = false(nTrials,1);
    TrReject  = false(nTrials,1);
    TrFamil   = false(nTrials,1);
    TrNoPAM   = false(nTrials,1);
    TrHasEMG  = false(nTrials,1);

    for j = 1:nTrials
        ti = Trials_Info{1,j};
        ep = Epochs_FlextoFlex_based{1,j};
        if isfield(ti,'General')
            if isfield(ti.General,'Pressure'),    TrPress(j) = ti.General.Pressure; end
            if isfield(ti.General,'Score'),       TrScore(j) = ti.General.Score;    end
            if isfield(ti.General,'Description')
                dd = string(ti.General.Description);
                TrDesc(j)   = dd;
                TrReject(j) = contains(dd,'Reject',   'IgnoreCase',true);
                TrFamil(j)  = contains(dd,'Familiar', 'IgnoreCase',true);
                TrNoPAM(j)  = contains(dd,'No_PAM',   'IgnoreCase',true);
                TrIsExp(j)  = startsWith(dd,'Experiment') & ~TrReject(j);
            end
        end
        if isfield(ep,'EMG_stream') && isfield(ep.EMG_stream,'Sensors_Preprocessed')
            TrHasEMG(j) = ~isempty(ep.EMG_stream.Sensors_Preprocessed);
        end
    end

    Tr = table(TrSubject, TrRaw, TrPress, TrScore, TrDesc, TrNEpoch, ...
        TrIsExp, TrReject, TrFamil, TrNoPAM, TrHasEMG, TrNEpoch > 0, ...
        'VariableNames', {'SubjectID','RawTrial','Pressure','Score', ...
        'Description','NEpochs','IsExperiment','IsRejected','IsFamiliar', ...
        'IsNoPAM','TrialHasEMG','HasAnyEpoch'});

    muscles = MUSCLES; %#ok<NASGU>
    save(fullfile(out_path, sprintf('emg_master_sub-%d.mat', subID)), ...
         'E','Tr','Sig','Tim','muscles','-v7.3');

    masterIndex = [masterIndex; E]; %#ok<AGROW>
    masterTrials = [masterTrials; Tr]; %#ok<AGROW>

    fprintf('%d epochs across %d trials\n', height(E), nTrials);
    clear Epochs_FlextoFlex_based Trials_Info Sig Tim
end

save(fullfile(out_path, 'emg_master_index.mat'), 'masterIndex', 'masterTrials');


%% Report
% ---------------------------------------------------------------------
% Every count below is a flag total, not a removal. Nothing has been
% dropped; this is what a downstream screen would exclude.

fprintf('\n--- Master index: %d epochs, %d trials, %d subjects ---\n', ...
    height(masterIndex), height(masterTrials), numel(unique(masterIndex.SubjectID)));

flags = {'IsExperiment','IsRejected','IsFamiliar','IsNoPAM', ...
         'TrialHasEMG','EpochHasSignal','EpochLongEnough', ...
         'EventsValid','ScoreValid','AllMusclesFound','TimingRegular', ...
         'SignalHasVariance'};
fprintf('\n%-18s %10s %10s\n', 'Flag', 'True', 'False');
for f = 1:numel(flags)
    v = masterIndex.(flags{f});
    fprintf('%-18s %10d %10d\n', flags{f}, sum(v), sum(~v));
end

usable = masterIndex.IsExperiment & masterIndex.EpochHasSignal & ...
         masterIndex.SignalHasVariance & ...
         masterIndex.EpochLongEnough & masterIndex.EventsValid & ...
         masterIndex.AllMusclesFound;
fprintf('\nEpochs passing all EMG flags: %d (%.2f%%)\n', sum(usable), 100*mean(usable));

% ---- Do the events agree with the epoch length? ----------------------
% Epochs are cut at cycle boundaries, so ExtEnd should equal NSamples. A
% disagreement means the segmentation and the event indices disagree
% about where the cycle ends, which would misplace the reversal in every
% warped curve built from that epoch.
haveBoth = ~isnan(masterIndex.ExtEnd) & ~isnan(masterIndex.NSamples);
mismatch = haveBoth & masterIndex.ExtEnd ~= masterIndex.NSamples;
fprintf('Epochs where ExtEnd differs from NSamples: %d\n', sum(mismatch));
if any(mismatch)
    d = masterIndex.ExtEnd(mismatch) - masterIndex.NSamples(mismatch);
    fprintf('  difference: median %+d, range %+d to %+d\n', ...
        median(d), min(d), max(d));
    disp(head(masterIndex(mismatch, ...
        {'SubjectID','RawTrial','RawEpoch','ExtStart','ExtEnd','NSamples'}), 10));
end

% ---- Does the recorded duration match the sample count? --------------
% At a uniform 2000 Hz these must agree. A discrepancy means samples were
% dropped inside the epoch, which index arithmetic alone cannot see and
% which would stretch that epoch when it is warped onto a common grid.
haveT = ~isnan(masterIndex.Duration) & ~isnan(masterIndex.NSamples);
expected = (masterIndex.NSamples - 1) / 2000;
resid = masterIndex.Duration(haveT) - expected(haveT);
fprintf('\nDuration versus sample count, %d epochs with timestamps\n', sum(haveT));
fprintf('  residual: median %+.6f s, max absolute %.6f s\n', ...
    median(resid), max(abs(resid)));
fprintf('  epochs off by more than one sample interval: %d\n', ...
    sum(abs(resid) > 1/2000));

% ---- Dead channels, by subject ---------------------------------------
% A subject whose every epoch has four dead channels recorded no EMG at
% all, which is the case the old pipeline handled by editing a subject
% list. Recording it as a flag makes the exclusion visible and lets any
% analysis apply it consistently.
fprintf('\n--- Epochs with dead channels, by subject ---\n');
subsD = unique(masterIndex.SubjectID);
for i = 1:numel(subsD)
    sel = masterIndex.SubjectID == subsD(i) & masterIndex.EpochHasSignal;
    if ~any(sel), continue; end
    nd = masterIndex.NDeadChannels(sel);
    if any(nd > 0)
        fprintf('Sub %2d: %d of %d epochs affected, median %d dead channel(s)\n', ...
            subsD(i), sum(nd > 0), sum(sel), median(nd(nd > 0)));
    end
end

% ---- Trials with no epochs -------------------------------------------
% These produce no rows in the epoch table, which is precisely why the
% trial table exists. Under the old pipeline they vanished silently and
% took the trial numbering with them.
noEp = masterTrials(~masterTrials.HasAnyEpoch, :);
fprintf('\nTrials with no epochs: %d\n', height(noEp));
if ~isempty(noEp)
    disp(noEp(:, {'SubjectID','RawTrial','Pressure','Score','Description','TrialHasEMG'}));
end

% ---- Per-subject breakdown -------------------------------------------
% IsExperiment is the flag to scrutinise. The old builder overrode
% Description to 'Experiment' for subjects below 10 rather than reading
% it, which implies those subjects may label trials differently. If their
% experimental proportion is far from the others, the descriptions are
% not comparable across the sample and the flag needs a subject-aware
% definition.
fprintf('\n--- Per subject ---\n');
fprintf('%8s %8s %8s %8s %8s %8s %8s\n', ...
    'Subject','Trials','Epochs','Exp','Reject','Familiar','NoPAM');

subs = unique(masterTrials.SubjectID);
for i = 1:numel(subs)
    tRows = masterTrials.SubjectID == subs(i);
    eRows = masterIndex.SubjectID  == subs(i);
    fprintf('%8d %8d %8d %8d %8d %8d %8d\n', ...
        subs(i), sum(tRows), sum(eRows), ...
        sum(masterTrials.IsExperiment(tRows)), ...
        sum(masterTrials.IsRejected(tRows)), ...
        sum(masterTrials.IsFamiliar(tRows)), ...
        sum(masterTrials.IsNoPAM(tRows)));
end

fprintf(['\nNo rows were removed. Apply the flags at analysis time, and\n' ...
         'report the counts above in the Methods so each criterion''s\n' ...
         'effect is visible rather than implicit.\n']);