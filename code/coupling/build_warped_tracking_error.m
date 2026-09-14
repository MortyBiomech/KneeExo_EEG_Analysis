function trk = build_warped_tracking_error(paths, subjects, targetPct, warpFrac, opts)
%BUILD_WARPED_TRACKING_ERROR  Tracking error on the EEG movement-cycle axis.
%
%   TRK = BUILD_WARPED_TRACKING_ERROR(PATHS, SUBJECTS, TARGETPCT, WARPFRAC)
%   returns the absolute knee tracking error of every surviving experiment
%   epoch, expressed on the same percent-of-cycle axis as the time-warped
%   event-related spectral perturbations.
%
%   TARGETPCT is the percent-of-cycle axis of the time-frequency data and
%   WARPFRAC is the fraction of the cycle at which the flexion to extension
%   transition sits in that data, both taken from the TIMEWARPMS parameter
%   stored in the single-trial time-frequency files.
%
%   Why WARPFRAC is passed in rather than derived here:
%
%   The EEG was warped to a group target derived from the EEG epoching, and the
%   original analysis warped the tracking error to a second group target derived
%   independently from the experiment stream. Two medians of the same physical
%   landmark, taken over different epoch subsets, do not coincide. Mapping both
%   signals onto a nominal zero to one hundred percent axis therefore left the
%   flexion to extension transition at two slightly different places, which
%   displaces the peak of any cross-correlation between them by exactly that
%   difference. Warping the error to the landmark fraction the EEG actually
%   uses removes that artefact, and it is the only choice under which a lag of
%   zero means physical simultaneity.
%
%   Each epoch is mapped with a piecewise linear time to phase function anchored
%   at the two landmarks, then interpolated once onto TARGETPCT. Warping to an
%   intermediate uniform grid first, as the original did, adds a second
%   interpolation without adding information. The piecewise linear landmark
%   warp itself follows Gwin, J. T., Gramann, K., Makeig, S., & Ferris, D. P.
%   (2011), Electrocortical activity is coupled to gait cycle phase during
%   treadmill walking, NeuroImage, 54(2), 1289-1296.
%
%   OPTS fields:
%     verbose         print progress (default true)
%     outlierMethod   method passed to ISOUTLIER for flagging cycles whose
%                     transition sits at an unusual fraction (default 'median')
%
%   TRK is a [nSubjects x 1] struct array with fields:
%     subject      participant number
%     error        [nEpochs x numel(TARGETPCT)] absolute tracking error
%     trialEpoch   [nEpochs x 2] trial and epoch number of each row
%     pressure     [nEpochs x 1] pressure condition of the trial
%     score        [nEpochs x 1] score of the trial
%     transFrac    [nEpochs x 1] observed transition fraction before warping
%     durationMs   [nEpochs x 1] cycle duration before warping
%     flagOutlier  [nEpochs x 1] logical, unusual transition fraction
%     pct          TARGETPCT, repeated for convenience
%
%   See also BUILD_EPOCH_PAIRING, RUN_CROSS_CORRELATION.
%
%   Part of the KneeExo-EEG analysis code.

arguments
    paths (1,1) struct
    subjects (1,:) double {mustBePositive, mustBeInteger}
    targetPct (1,:) double
    warpFrac (1,1) double {mustBePositive}
    opts.verbose (1,1) logical = true
    opts.outlierMethod (1,:) char = 'median'
end

if warpFrac <= 0 || warpFrac >= 1
    error('build_warped_tracking_error:BadFraction', ...
        'warpFrac must lie strictly between 0 and 1, got %g.', warpFrac);
end

transPct = 100 * warpFrac;

trk = repmat(struct( ...
    'subject', [], 'error', [], 'trialEpoch', [], 'pressure', [], ...
    'score', [], 'transFrac', [], 'durationMs', [], 'flagOutlier', [], ...
    'pct', []), numel(subjects), 1);

for s = 1:numel(subjects)

    thisSubject = subjects(s);
    subDir = fullfile(paths.epochs, sprintf('sub-%d', thisSubject));

    epFile = fullfile(subDir, 'Epochs_FlextoFlex_based.mat');
    tiFile = fullfile(subDir, 'Trials_Info.mat');
    if exist(epFile, 'file') ~= 2
        error('build_warped_tracking_error:NoEpochFile', 'Cannot find %s.', epFile);
    end
    if exist(tiFile, 'file') ~= 2
        error('build_warped_tracking_error:NoTrialsInfo', 'Cannot find %s.', tiFile);
    end

    if opts.verbose
        fprintf('Participant %d: reading the experiment stream ...\n', thisSubject);
    end

    loaded = load(epFile, 'Epochs_FlextoFlex_based');
    EXP    = cellfun(@(x) x.EXP_stream, loaded.Epochs_FlextoFlex_based, ...
        'UniformOutput', false);
    clear loaded

    info = load(tiFile, 'Trials_Info');
    info = info.Trials_Info;

    nPct       = numel(targetPct);
    errOut     = zeros(0, nPct);
    trialEpoch = zeros(0, 2);
    pressure   = [];
    score      = [];
    transFrac  = [];
    durationMs = [];

    for trial = 1:numel(EXP)

        if isempty(EXP{trial}.Times)
            continue
        end

        nEpoch = numel(EXP{trial}.Times);
        events = epoch_landmarks(info{trial}, nEpoch);

        for e = 1:nEpoch

            t   = double(EXP{trial}.Times{e}(:)).';
            err = abs(double(EXP{trial}.Encoder_angle{e}(:)).' - ...
                      double(EXP{trial}.Ref_angle{e}(:)).');

            iTrans = events(e, 2);
            if iTrans <= 1 || iTrans >= numel(t)
                warning('build_warped_tracking_error:BadLandmark', ...
                    ['Participant %d trial %d epoch %d has its transition at ', ...
                     'sample %d of %d. The epoch is skipped.'], ...
                    thisSubject, trial, e, iTrans, numel(t));
                continue
            end

            phase = cycle_phase(t, iTrans, transPct);
            errOut(end+1, :) = interp1(phase, err, targetPct, ...
                'linear', 'extrap'); %#ok<AGROW>

            trialEpoch(end+1, :) = [trial, e];                    %#ok<AGROW>
            pressure(end+1, 1)   = info{trial}.General.Pressure;   %#ok<AGROW>
            score(end+1, 1)      = info{trial}.General.Score;      %#ok<AGROW>
            transFrac(end+1, 1)  = (t(iTrans) - t(1)) / (t(end) - t(1)); %#ok<AGROW>
            durationMs(end+1, 1) = t(end) - t(1);                  %#ok<AGROW>

        end

    end

    if isempty(errOut)
        error('build_warped_tracking_error:NoEpochs', ...
            'Participant %d produced no usable epochs.', thisSubject);
    end

    trk(s).subject     = thisSubject;
    trk(s).error       = errOut;
    trk(s).trialEpoch  = trialEpoch;
    trk(s).pressure    = pressure;
    trk(s).score       = score;
    trk(s).transFrac   = transFrac;
    trk(s).durationMs  = durationMs;
    trk(s).flagOutlier = isoutlier(transFrac, opts.outlierMethod);
    trk(s).pct         = targetPct;

    if opts.verbose
        fprintf(['  %d epochs, median cycle %.0f ms, transition at %.1f%% ', ...
            'of the cycle, %d unusual cycles flagged\n'], ...
            size(errOut, 1), median(durationMs), 100*median(transFrac), ...
            sum(trk(s).flagOutlier));
    end

end

end


% ----------------------------------------------------------------------------
function pct = cycle_phase(t, iTrans, transPct)
%CYCLE_PHASE  Piecewise linear map from epoch time to percent of movement cycle.
%
%   Flexion occupies 0 to TRANSPCT and extension occupies TRANSPCT to 100, so
%   the transition lands on the same percentage in every epoch and in the EEG.

pct = zeros(size(t));

flex = 1:iTrans;
ext  = iTrans:numel(t);

pct(flex) = transPct * (t(flex) - t(1)) / (t(iTrans) - t(1));
pct(ext)  = transPct + (100 - transPct) * ...
    (t(ext) - t(iTrans)) / (t(end) - t(iTrans));

end


% ----------------------------------------------------------------------------
function events = epoch_landmarks(trialInfo, nEpoch)
%EPOCH_LANDMARKS  One based landmark indices within each epoch of a trial.
%
%   The stored indices are absolute within the trial, so the cycle start of each
%   epoch is subtracted to make them relative to that epoch.

ev = trialInfo.Events.EXP_stream;

startIdx = double(ev.flextoflex_start_indx(:));
transIdx = double(ev.extension_start_indx(:));
endIdx   = double(ev.flextoflex_end_indx(:));

if numel(startIdx) ~= nEpoch
    error('build_warped_tracking_error:LandmarkCount', ...
        ['A trial holds %d epochs but %d cycle-start landmarks. The event ', ...
         'table and the epoched data disagree.'], nEpoch, numel(startIdx));
end

events = [startIdx, transIdx, endIdx] - repmat(startIdx - 1, 1, 3);

end
