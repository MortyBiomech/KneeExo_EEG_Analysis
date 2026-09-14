function pairing = build_epoch_pairing(paths, subjects, opts)
%BUILD_EPOCH_PAIRING  Re-pair EEG time-frequency epochs with experiment epochs.
%
%   PAIRING = BUILD_EPOCH_PAIRING(PATHS, SUBJECTS) returns, for every epoch that
%   survives into the single-trial time-frequency file of each participant, the
%   trial and epoch number of the same movement cycle in the experiment stream.
%
%   Why this step exists:
%
%   Each recorded stream was cleaned on its own terms. The EEG lost epochs to
%   artefact rejection and to independent component rejection, and the
%   experiment stream lost epochs to its own completeness criteria. The two
%   survivor sets are different subsets of the same movement cycles, and neither
%   file carries an index into the other, so the epochs cannot be joined by
%   position. Correlating them without re-pairing would silently compare the
%   power of one movement cycle against the tracking error of a different one.
%
%   How it is solved:
%
%   Every epoch in the time-frequency file records, in TRIALINFO.INIT_INDEX, the
%   index of the event that opened it. That same index appears in the UREVENT
%   table of the continuous dataset, alongside the event latency in samples.
%   Converting the latency to milliseconds gives the absolute onset time of the
%   epoch, which can then be matched against the first time sample of every
%   surviving experiment epoch. The match is nearest neighbour in time and the
%   residual distance is returned, so the quality of every match is auditable.
%
%   PATHS must have the fields ICATIMEF, EPOCHS and STUDY, as built by
%   RUN_CROSS_CORRELATION. SUBJECTS is a vector of participant numbers.
%
%   OPTS fields:
%     studyName     name of the clustering STUDY to read UREVENT from. The
%                   UREVENT table belongs to the per-participant datasets rather
%                   than to the cluster solution, so any STUDY built on the same
%                   datasets gives the same answer. The default is
%                   'Left_Parieto_Occipital'.
%     toleranceMs   largest residual accepted for a match, in milliseconds.
%                   Default 50. A movement cycle lasts on the order of a second,
%                   so a correct match should be accurate to a few milliseconds.
%     verbose       print progress (default true)
%
%   PAIRING is a [nSubjects x 1] struct array with fields:
%     subject       participant number
%     expRow        [nKept x 1] row of this participant's experiment epoch list
%                   for each kept time-frequency epoch, in time-frequency order
%     pairs         [nKept x 2] trial and epoch number of the same cycle
%     residualMs    [nKept x 1] absolute time difference of each match
%     keepTF        [nKept x 1] index of each kept epoch in the original
%                   time-frequency file
%     dropTF        [nDrop x 1] time-frequency epochs with no experiment
%                   counterpart, because their whole trial is absent
%     dropTrials    trials absent from the experiment stream
%     nTF           number of epochs in the time-frequency file
%     nExp          number of epochs in the experiment stream
%
%   Returning EXPROW rather than a logical mask is deliberate. A mask assumes
%   that the surviving experiment epochs, in experiment order, are the same
%   sequence as the time-frequency epochs in time-frequency order. That
%   assumption is usually true and fails silently when it is not. An explicit
%   row index removes it, and the uniqueness of the mapping is checked here.
%
%   See also RUN_CROSS_CORRELATION, EPOCH_PAIRING_CHECK.
%
%   Part of the KneeExo-EEG analysis code.

arguments
    paths (1,1) struct
    subjects (1,:) double {mustBePositive, mustBeInteger}
    opts.studyName (1,:) char = 'Left_Parieto_Occipital'
    opts.toleranceMs (1,1) double {mustBePositive} = 50
    opts.verbose (1,1) logical = true
end

if exist('pop_loadstudy', 'file') ~= 2
    error('build_epoch_pairing:NoEEGLAB', ...
        'EEGLAB is not on the path. Run eeglab before calling this function.');
end

studyDir  = fullfile(paths.study, opts.studyName);
studyFile = [opts.studyName '.study'];
if exist(fullfile(studyDir, studyFile), 'file') ~= 2
    error('build_epoch_pairing:NoStudy', ...
        'Cannot find %s in %s.', studyFile, studyDir);
end

if opts.verbose
    fprintf('Loading STUDY %s for its urevent tables ...\n', opts.studyName);
end
[STUDY, ALLEEG] = pop_loadstudy('filename', studyFile, 'filepath', studyDir);

datasetSubject = dataset_subject_numbers(STUDY);

pairing = repmat(struct( ...
    'subject', [], 'expRow', [], 'pairs', [], 'residualMs', [], ...
    'keepTF', [], 'dropTF', [], 'dropTrials', [], 'nTF', [], 'nExp', []), ...
    numel(subjects), 1);

for s = 1:numel(subjects)

    thisSubject = subjects(s);
    pairing(s).subject = thisSubject;

    iSet = find(datasetSubject == thisSubject);
    if numel(iSet) ~= 1
        error('build_epoch_pairing:DatasetLookup', ...
            ['Participant %d matches %d datasets in the STUDY. Exactly one ', ...
             'is required. Positional indexing into ALLEEG is not safe here.'], ...
            thisSubject, numel(iSet));
    end

    % ---- time-frequency side ------------------------------------------
    tfFile = fullfile(paths.icatimef, sprintf('S%d.icatimef', thisSubject));
    if exist(tfFile, 'file') ~= 2
        error('build_epoch_pairing:NoIcatimef', 'Cannot find %s.', tfFile);
    end
    if opts.verbose
        fprintf('Participant %d: reading %s\n', thisSubject, ...
            sprintf('S%d.icatimef', thisSubject));
    end
    tf       = load(tfFile, '-mat', 'trialinfo');
    initTF   = double(cell2mat({tf.trialinfo.init_index}.'));
    trialTF  = trial_numbers({tf.trialinfo.trial});
    nTF      = numel(initTF);

    % ---- continuous dataset side --------------------------------------
    [initUR, latencyUR] = urevent_columns(ALLEEG(iSet));
    srate = ALLEEG(iSet).srate;
    if isempty(srate) || ~isfinite(srate) || srate <= 0
        error('build_epoch_pairing:NoSrate', ...
            'Participant %d has no usable sampling rate in its dataset.', ...
            thisSubject);
    end

    iUR = zeros(nTF, 1);
    for k = 1:nTF
        hit = find(initUR == initTF(k));
        if numel(hit) ~= 1
            error('build_epoch_pairing:InitIndexLookup', ...
                ['Participant %d, time-frequency epoch %d: init_index %d ', ...
                 'matches %d urevent entries. Exactly one is required.'], ...
                thisSubject, k, initTF(k), numel(hit));
        end
        iUR(k) = hit;
    end

    % EEGLAB latencies are one based and the first sample sits at time zero.
    onsetTF = (latencyUR(iUR) - 1) / srate * 1000;

    % ---- experiment stream side ---------------------------------------
    [expOnsetMs, expTrial, expEpoch, emptyTrials] = ...
        experiment_epoch_onsets(paths.epochs, thisSubject);

    % ---- match ---------------------------------------------------------
    dropTF = find(ismember(trialTF, emptyTrials));
    keepTF = setdiff((1:nTF).', dropTF);

    expRow     = zeros(numel(keepTF), 1);
    residualMs = zeros(numel(keepTF), 1);
    for k = 1:numel(keepTF)
        [residualMs(k), expRow(k)] = min(abs(expOnsetMs - onsetTF(keepTF(k))));
    end

    bad = residualMs > opts.toleranceMs;
    if any(bad)
        error('build_epoch_pairing:LooseMatch', ...
            ['Participant %d: %d of %d epochs matched no experiment epoch ', ...
             'within %g ms (worst %.1f ms). Check the sampling rate and the ', ...
             'event tables before trusting any coupling result.'], ...
            thisSubject, sum(bad), numel(keepTF), opts.toleranceMs, ...
            max(residualMs));
    end

    if numel(unique(expRow)) ~= numel(expRow)
        error('build_epoch_pairing:DuplicateMatch', ...
            ['Participant %d: %d time-frequency epochs matched the same ', ...
             'experiment epoch. The pairing is not one to one.'], ...
            thisSubject, numel(expRow) - numel(unique(expRow)));
    end

    pairing(s).expRow     = expRow;
    pairing(s).pairs      = [expTrial(expRow), expEpoch(expRow)];
    pairing(s).residualMs = residualMs;
    pairing(s).keepTF     = keepTF;
    pairing(s).dropTF     = dropTF;
    pairing(s).dropTrials = emptyTrials;
    pairing(s).nTF        = nTF;
    pairing(s).nExp       = numel(expOnsetMs);

    if opts.verbose
        fprintf(['  %d of %d time-frequency epochs paired, worst residual ', ...
            '%.2f ms, %d trials absent from the experiment stream\n'], ...
            numel(keepTF), nTF, max([residualMs; 0]), numel(emptyTrials));
    end

end

end


% ----------------------------------------------------------------------------
function n = dataset_subject_numbers(STUDY)
%DATASET_SUBJECT_NUMBERS  Participant number of every dataset in the STUDY.

raw = {STUDY.datasetinfo.subject};
n   = nan(numel(raw), 1);
for k = 1:numel(raw)
    digits = regexp(raw{k}, '\d+', 'match', 'once');
    if ~isempty(digits)
        n(k) = str2double(digits);
    end
end

end


% ----------------------------------------------------------------------------
function [initUR, latencyUR] = urevent_columns(EEG)
%UREVENT_COLUMNS  init_index and latency of every urevent that has both.

if ~isfield(EEG, 'urevent') || isempty(EEG.urevent)
    error('build_epoch_pairing:NoUrevent', ...
        'Dataset %s has no urevent table.', EEG.setname);
end

initCell    = {EEG.urevent.init_index}.';
latencyCell = {EEG.urevent.latency}.';

hasBoth = ~cellfun(@isempty, initCell) & ~cellfun(@isempty, latencyCell);

initUR    = double(cell2mat(initCell(hasBoth)));
latencyUR = double(cell2mat(latencyCell(hasBoth)));

end


% ----------------------------------------------------------------------------
function t = trial_numbers(raw)
%TRIAL_NUMBERS  Numeric trial number from the trialinfo trial field.

t = nan(numel(raw), 1);
for k = 1:numel(raw)
    if isnumeric(raw{k})
        t(k) = double(raw{k});
    else
        t(k) = str2double(raw{k});
    end
end

if any(isnan(t))
    error('build_epoch_pairing:TrialNumber', ...
        'Could not read a numeric trial number for %d epochs.', sum(isnan(t)));
end

end


% ----------------------------------------------------------------------------
function [onsetMs, trialOut, epochOut, emptyTrials] = ...
    experiment_epoch_onsets(epochRoot, subject)
%EXPERIMENT_EPOCH_ONSETS  Onset time of every surviving experiment epoch.
%
%   The onset is read from the EEG stream of the epoched experiment file, which
%   shares its clock with the continuous dataset the urevent latencies refer to.

subDir = fullfile(epochRoot, sprintf('sub-%d', subject));
epFile = fullfile(subDir, 'Epochs_FlextoFlex_based.mat');
if exist(epFile, 'file') ~= 2
    error('build_epoch_pairing:NoEpochFile', 'Cannot find %s.', epFile);
end

loaded = load(epFile, 'Epochs_FlextoFlex_based');
epochs = loaded.Epochs_FlextoFlex_based;

onsetMs     = [];
trialOut    = [];
epochOut    = [];
emptyTrials = [];

for trial = 1:numel(epochs)

    times = epochs{1, trial}.EEG_stream.Preprocessed.Times;
    if isempty(times)
        emptyTrials(end+1, 1) = trial; %#ok<AGROW>
        continue
    end

    first = cellfun(@(x) x(1), times);
    first = first(:);

    onsetMs  = [onsetMs;  first];                              %#ok<AGROW>
    trialOut = [trialOut; repmat(trial, numel(first), 1)];     %#ok<AGROW>
    epochOut = [epochOut; (1:numel(first)).'];                 %#ok<AGROW>

end

if isempty(onsetMs)
    error('build_epoch_pairing:NoExperimentEpochs', ...
        'Participant %d has no surviving experiment epochs.', subject);
end

end
