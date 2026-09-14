function [masterIndex, masterTrials] = build_tracking_master(cfg, subject_list)
% BUILD_TRACKING_MASTER  One row per raw encoder epoch, on the EMG master's key.
%
%   [masterIndex, masterTrials] = build_tracking_master()
%   [masterIndex, masterTrials] = build_tracking_master(cfg)
%   [masterIndex, masterTrials] = build_tracking_master(cfg, subject_list)
%
% Same flag-based architecture as build_emg_master, and the same key.
%
% KEY. (SubjectID, RawTrial, RawEpoch). RawTrial is the position in
% Epochs_FlextoFlex_based and RawEpoch the position within that trial. The
% correspondence check showed EXP and EMG epoch counts agree exactly for
% every trial, so a row here and a row in the EMG master with the same key
% describe the same movement cycle. Joining the two needs no translation.
%
% This is what the old pipeline lacked. It stored a raw trial index while the
% EMG pipeline stored a compacted one, and the two silently diverged for
% subjects 9, 11, 12 and 18.
%
% WHAT IS STORED. The encoder angle and the reference angle, not a derived
% error. How error is defined, whether absolute difference, squared
% difference, or RMS over the cycle, is an analysis choice, and the earlier
% dataset changed that definition mid-project, which left two panels of
% Figure 2 differing by a factor of twenty. Storing the inputs makes the
% definition explicit at the point of use. The three summary columns are
% conveniences, computed per epoch, and which one the published values used
% is settled by checks/error_definition_check.m rather than assumed.
%
% Timestamps are stored in full. The EXP stream comes through LSL and is not
% guaranteed uniform, so unlike the EMG stream its sample spacing cannot be
% reconstructed from an index.
%
% OUTPUT, under cfg.masters
%   per subject : trk_master_sub-XX.mat, holding
%                   X    epoch table, one row per raw epoch
%                   Tr   trial table, one row per raw trial
%                   Enc  encoder angle per epoch
%                   Ref  reference angle per epoch
%                   Tim  timestamps per epoch
%   overall     : trk_master_index.mat, the tables without signals.
%
% See also BUILD_EMG_MASTER, SCREEN_EPOCHS, BUILD_BEHAVIOUR_TABLE.

    if nargin < 1 || isempty(cfg)
        cfg = kneeexo_config();
    end
    if nargin < 2 || isempty(subject_list)
        subject_list = cfg.subjects;
    end

    if isempty(cfg.raw)
        error('build_tracking_master:NoRawPath', ...
            ['This reads the epoched trial data from stage 2. Set cfg.raw ' ...
             'in config/local_paths.m.']);
    end

    epoched_data_path = cfg.trialsInfo;
    out_path          = cfg.masters;

    % Multiples of the epoch's own median interval before a gap counts. The
    % EXP stream is not guaranteed uniform, so the tolerance is relative
    % rather than tied to a nominal rate as it is for EMG.
    GAP_TOLERANCE = 3;

    if ~exist(out_path, 'dir'), mkdir(out_path); end

    masterIndex  = table();
    masterTrials = table();

    for subID = subject_list

        fprintf('Subject %d ... ', subID);

        subDir = fullfile(epoched_data_path, ['sub-', num2str(subID)]);
        L1 = load(fullfile(subDir, 'Epochs_FlextoFlex_based.mat'));
        L2 = load(fullfile(subDir, 'Trials_Info.mat'));
        Epochs_FlextoFlex_based = L1.Epochs_FlextoFlex_based;
        Trials_Info             = L2.Trials_Info;
        clear L1 L2

        nTrials = numel(Epochs_FlextoFlex_based);

        % ---- Pass 1: epoch counts -----------------------------------------
        nEpPerTrial = zeros(nTrials, 1);
        for j = 1:nTrials
            ep = Epochs_FlextoFlex_based{1, j};
            if isfield(ep, 'EXP_stream') && isfield(ep.EXP_stream, 'Times')
                nEpPerTrial(j) = numel(ep.EXP_stream.Times);
            end
        end
        nRows = sum(nEpPerTrial);

        % ---- Preallocate ---------------------------------------------------
        SubjectID = zeros(nRows, 1);
        RawTrial  = zeros(nRows, 1);
        RawEpoch  = zeros(nRows, 1);
        Pressure  = nan(nRows, 1);
        Score     = nan(nRows, 1);
        Description = strings(nRows, 1);

        FlxStart = nan(nRows, 1);
        ExtStart = nan(nRows, 1);
        ExtEnd   = nan(nRows, 1);
        NSamples = nan(nRows, 1);

        TimeStart    = nan(nRows, 1);
        TimeEnd      = nan(nRows, 1);
        Duration     = nan(nRows, 1);
        MedianDt     = nan(nRows, 1);
        MaxSampleGap = nan(nRows, 1);

        RMSError     = nan(nRows, 1);
        MeanAbsError = nan(nRows, 1);
        MaxAbsError  = nan(nRows, 1);

        IsExperiment   = false(nRows, 1);
        IsRejected     = false(nRows, 1);
        IsFamiliar     = false(nRows, 1);
        IsNoPAM        = false(nRows, 1);
        EpochHasSignal = false(nRows, 1);
        LengthsMatch   = false(nRows, 1);   % angles and timestamps same length
        EventsValid    = false(nRows, 1);
        ScoreValid     = false(nRows, 1);
        TimingRegular  = false(nRows, 1);

        Enc = cell(nRows, 1);
        Ref = cell(nRows, 1);
        Tim = cell(nRows, 1);

        % ---- Pass 2: fill, skipping nothing --------------------------------
        r = 0;
        for j = 1:nTrials

            ep = Epochs_FlextoFlex_based{1, j};
            ti = Trials_Info{1, j};

            desc = "";
            if isfield(ti, 'General') && isfield(ti.General, 'Description')
                desc = string(ti.General.Description);
            end
            isRejected = contains(desc, 'Reject',   'IgnoreCase', true);
            isFamiliar = contains(desc, 'Familiar', 'IgnoreCase', true);
            isNoPAM    = contains(desc, 'No_PAM',   'IgnoreCase', true);
            isExp      = startsWith(desc, 'Experiment') & ~isRejected;

            P = NaN; S = NaN;
            if isfield(ti, 'General')
                if isfield(ti.General, 'Pressure'), P = ti.General.Pressure; end
                if isfield(ti.General, 'Score'),    S = ti.General.Score;    end
            end

            encAll = {}; refAll = {}; timAll = {};
            if isfield(ep, 'EXP_stream')
                if isfield(ep.EXP_stream, 'Encoder_angle')
                    encAll = ep.EXP_stream.Encoder_angle;
                end
                if isfield(ep.EXP_stream, 'Ref_angle')
                    refAll = ep.EXP_stream.Ref_angle;
                end
                if isfield(ep.EXP_stream, 'Times')
                    timAll = ep.EXP_stream.Times;
                end
            end

            % Events at the RAW epoch index.
            evA = []; evB = []; evC = [];
            if isfield(ti, 'Events') && isfield(ti.Events, 'EXP_stream')
                ev = ti.Events.EXP_stream;
                if isfield(ev, 'flextoflex_start_indx'), evA = ev.flextoflex_start_indx; end
                if isfield(ev, 'extension_start_indx'),  evB = ev.extension_start_indx;  end
                if isfield(ev, 'flextoflex_end_indx'),   evC = ev.flextoflex_end_indx;   end
            end

            for k = 1:nEpPerTrial(j)
                r = r + 1;

                SubjectID(r)   = subID;
                RawTrial(r)    = j;
                RawEpoch(r)    = k;
                Pressure(r)    = P;
                Score(r)       = S;
                Description(r) = desc;

                IsExperiment(r) = isExp;
                IsRejected(r)   = isRejected;
                IsFamiliar(r)   = isFamiliar;
                IsNoPAM(r)      = isNoPAM;
                ScoreValid(r)   = ~isnan(S) && S >= 1 && S <= 10;

                if numel(evA) >= k && numel(evB) >= k && numel(evC) >= k
                    a = evA(k); b = evB(k); c = evC(k);
                    FlxStart(r) = 1;
                    ExtStart(r) = b - a + 1;
                    ExtEnd(r)   = c - a + 1;
                    EventsValid(r) = a < b && b < c;
                end

                haveEnc = numel(encAll) >= k && ~isempty(encAll{k});
                haveRef = numel(refAll) >= k && ~isempty(refAll{k});
                haveTim = numel(timAll) >= k && ~isempty(timAll{k});

                if haveEnc && haveRef
                    e = encAll{k}(:)';
                    f = refAll{k}(:)';
                    Enc{r} = e;
                    Ref{r} = f;
                    NSamples(r)       = numel(e);
                    EpochHasSignal(r) = true;
                    LengthsMatch(r)   = numel(e) == numel(f);

                    if LengthsMatch(r)
                        d = e - f;
                        RMSError(r)     = sqrt(mean(d.^2));
                        MeanAbsError(r) = mean(abs(d));
                        MaxAbsError(r)  = max(abs(d));
                    end
                end

                if haveTim
                    tv = timAll{k}(:)';
                    Tim{r} = tv;
                    if numel(tv) >= 2
                        TimeStart(r) = tv(1);
                        TimeEnd(r)   = tv(end);
                        Duration(r)  = tv(end) - tv(1);
                        dt = diff(tv);
                        MedianDt(r)     = median(dt);
                        MaxSampleGap(r) = max(dt);
                        TimingRegular(r) = max(dt) < GAP_TOLERANCE * median(dt);
                    end
                    if EpochHasSignal(r)
                        LengthsMatch(r) = LengthsMatch(r) && numel(tv) == NSamples(r);
                    end
                end
            end
        end

        X = table(SubjectID, RawTrial, RawEpoch, Pressure, Score, Description, ...
            FlxStart, ExtStart, ExtEnd, NSamples, ...
            TimeStart, TimeEnd, Duration, MedianDt, MaxSampleGap, ...
            RMSError, MeanAbsError, MaxAbsError, ...
            IsExperiment, IsRejected, IsFamiliar, IsNoPAM, ...
            EpochHasSignal, LengthsMatch, EventsValid, ScoreValid, TimingRegular, ...
            'VariableNames', ...
            {'SubjectID','RawTrial','RawEpoch','Pressure','Score','Description', ...
             'FlxStart','ExtStart','ExtEnd','NSamples', ...
             'TimeStart','TimeEnd','Duration','MedianDt','MaxSampleGap', ...
             'RMSError','MeanAbsError','MaxAbsError', ...
             'IsExperiment','IsRejected','IsFamiliar','IsNoPAM', ...
             'EpochHasSignal','LengthsMatch','EventsValid','ScoreValid','TimingRegular'});

        Tr = trial_table(Trials_Info, subID, nEpPerTrial);

        save(fullfile(out_path, sprintf('trk_master_sub-%d.mat', subID)), ...
             'X', 'Tr', 'Enc', 'Ref', 'Tim', '-v7.3');

        masterIndex  = [masterIndex;  X];  %#ok<AGROW>
        masterTrials = [masterTrials; Tr]; %#ok<AGROW>

        fprintf('%d epochs across %d trials\n', height(X), nTrials);
        clear Epochs_FlextoFlex_based Trials_Info Enc Ref Tim
    end

    save(fullfile(out_path, 'trk_master_index.mat'), 'masterIndex', 'masterTrials');

    report_tracking_master(masterIndex, masterTrials, out_path);

end


% ------------------------------------------------------------------------
function Tr = trial_table(Trials_Info, subID, nEpPerTrial)
% One row per raw trial, including trials that contributed no epochs.

    nTrials = numel(Trials_Info);

    TrPress  = nan(nTrials, 1);
    TrScore  = nan(nTrials, 1);
    TrDesc   = strings(nTrials, 1);
    TrIsExp  = false(nTrials, 1);
    TrReject = false(nTrials, 1);
    TrFamil  = false(nTrials, 1);
    TrNoPAM  = false(nTrials, 1);

    for j = 1:nTrials
        ti = Trials_Info{1, j};
        if isfield(ti, 'General')
            if isfield(ti.General, 'Pressure'), TrPress(j) = ti.General.Pressure; end
            if isfield(ti.General, 'Score'),    TrScore(j) = ti.General.Score;    end
            if isfield(ti.General, 'Description')
                dd = string(ti.General.Description);
                TrDesc(j)   = dd;
                TrReject(j) = contains(dd, 'Reject',   'IgnoreCase', true);
                TrFamil(j)  = contains(dd, 'Familiar', 'IgnoreCase', true);
                TrNoPAM(j)  = contains(dd, 'No_PAM',   'IgnoreCase', true);
                TrIsExp(j)  = startsWith(dd, 'Experiment') & ~TrReject(j);
            end
        end
    end

    Tr = table(subID * ones(nTrials,1), (1:nTrials)', TrPress, TrScore, ...
        TrDesc, nEpPerTrial, TrIsExp, TrReject, TrFamil, TrNoPAM, ...
        nEpPerTrial > 0, ...
        'VariableNames', {'SubjectID','RawTrial','Pressure','Score', ...
        'Description','NEpochs','IsExperiment','IsRejected','IsFamiliar', ...
        'IsNoPAM','HasAnyEpoch'});

end


% ------------------------------------------------------------------------
function report_tracking_master(masterIndex, masterTrials, out_path)

    fprintf('\n--- Tracking master: %d epochs, %d trials, %d subjects ---\n', ...
        height(masterIndex), height(masterTrials), ...
        numel(unique(masterIndex.SubjectID)));

    flags = {'IsExperiment','IsRejected','IsFamiliar','IsNoPAM', ...
             'EpochHasSignal','LengthsMatch','EventsValid','ScoreValid', ...
             'TimingRegular'};
    fprintf('\n%-18s %10s %10s\n', 'Flag', 'True', 'False');
    for f = 1:numel(flags)
        v = masterIndex.(flags{f});
        fprintf('%-18s %10d %10d\n', flags{f}, sum(v), sum(~v));
    end

    % Does the epoch span match the event boundary, as it does for the EMG?
    haveBoth = ~isnan(masterIndex.ExtEnd) & ~isnan(masterIndex.NSamples);
    fprintf('\nEpochs where ExtEnd differs from NSamples: %d\n', ...
        sum(haveBoth & masterIndex.ExtEnd ~= masterIndex.NSamples));

    % Sampling rate of the EXP stream, which the old code never stated.
    fprintf('Median sample interval: %.4f s (%.1f Hz)\n', ...
        median(masterIndex.MedianDt, 'omitnan'), ...
        1 / median(masterIndex.MedianDt, 'omitnan'));

    % Key alignment against the EMG master, the whole point of the rebuild.
    emgFile = fullfile(out_path, 'emg_master_index.mat');
    if exist(emgFile, 'file')
        emg = load(emgFile, 'masterIndex');
        a = masterIndex(:, {'SubjectID','RawTrial','RawEpoch'});
        b = emg.masterIndex(:, {'SubjectID','RawTrial','RawEpoch'});
        fprintf('\nKey alignment with the EMG master:\n');
        fprintf('  tracking rows %d, EMG rows %d, identical key sets: %s\n', ...
            height(a), height(b), string(isequal(sortrows(a), sortrows(b))));
    end

    fprintf(['\nNo rows were removed. Error is stored as encoder and ' ...
             'reference angles; the summary columns are conveniences, and ' ...
             'which one the published values used is settled by ' ...
             'checks/error_definition_check.m rather than assumed.\n']);

end