function data = prepare_trial_matrices(pow, trk, pairing, bands, opts)
%PREPARE_TRIAL_MATRICES  Pair, band-average and aggregate the two signals.
%
%   DATA = PREPARE_TRIAL_MATRICES(POW, TRK, PAIRING, BANDS) turns the component
%   power and the warped tracking error into matched [nTrials x nTime] matrices,
%   one pair per participant, pressure condition and frequency band.
%
%   The error rows are selected by their trial and epoch number rather than by
%   position, so an epoch that one of the two builders skipped can never shift
%   the pairing without being noticed.
%
%   BANDS is a struct whose field names are band names and whose values are
%   two-element frequency limits in Hz, for example
%       bands.theta = [4 8];
%       bands.alpha = [8 14];
%   Limits are inclusive at the lower edge and exclusive at the upper edge, so
%   adjacent bands do not share a frequency bin.
%
%   OPTS fields:
%     aggregate       'trial' averages the epochs of a trial before correlating,
%                     'epoch' keeps every movement cycle as its own observation.
%                     Default 'trial', matching the original analysis. The
%                     choice decides what a residual means: with 'trial' the
%                     residual is a trial-to-trial fluctuation, with 'epoch' it
%                     is a cycle-to-cycle fluctuation.
%     dropZeroScore   drop trials whose recorded score is zero (default true)
%     dropOutlierCycles  drop cycles whose transition fraction was flagged as
%                     unusual (default false)
%     baseline        'none' or 'divisive'. Divisive scales every frequency by
%                     its own grand mean before the band average, which equalises
%                     the contribution of frequencies within a band. It cannot
%                     change a correlation through overall scaling, because a
%                     Pearson correlation is scale invariant. Default 'none'.
%     verbose         print progress (default true)
%
%   DATA fields:
%     E          {nSubjects x nConditions} error matrices
%     P          struct of {nSubjects x nConditions} power matrices, one field
%                per band
%     conditions the pressure levels, in the order of the columns
%     pct        the percent-of-cycle axis
%     nTrials    [nSubjects x nConditions] trial counts
%     subject    participant numbers
%     bands      the band definition used
%     opts       the options used
%
%   See also LOAD_CLUSTER_POWER, BUILD_WARPED_TRACKING_ERROR.
%
%   Part of the KneeExo-EEG analysis code.

arguments
    pow (1,1) struct
    trk (:,1) struct
    pairing (:,1) struct
    bands (1,1) struct
    opts.aggregate (1,:) char {mustBeMember(opts.aggregate, {'trial', 'epoch'})} = 'trial'
    opts.dropZeroScore (1,1) logical = true
    opts.dropOutlierCycles (1,1) logical = false
    opts.baseline (1,:) char {mustBeMember(opts.baseline, {'none', 'divisive'})} = 'none'
    opts.conditions (1,:) double = [1 3 6]
    opts.verbose (1,1) logical = true
end

bandNames = fieldnames(bands);
nSub      = numel(pow.subject);
nCond     = numel(opts.conditions);
nPct      = numel(pow.pct);

data = struct();
data.E          = cell(nSub, nCond);
data.P          = struct();
for b = 1:numel(bandNames)
    data.P.(bandNames{b}) = cell(nSub, nCond);
end
data.conditions = opts.conditions;
data.pct        = pow.pct;
data.nTrials    = zeros(nSub, nCond);
data.subject    = pow.subject;
data.bands      = bands;
data.opts       = opts;

bandIdx = struct();
for b = 1:numel(bandNames)
    lim = bands.(bandNames{b});
    bandIdx.(bandNames{b}) = pow.freqs >= lim(1) & pow.freqs < lim(2);
    if ~any(bandIdx.(bandNames{b}))
        error('prepare_trial_matrices:EmptyBand', ...
            'Band %s (%g to %g Hz) contains no frequency bin.', ...
            bandNames{b}, lim(1), lim(2));
    end
end

for s = 1:nSub

    if isempty(pow.power{s})
        continue
    end

    thisSubject = pow.subject(s);
    iPair = find([pairing.subject] == thisSubject, 1);
    iTrk  = find([trk.subject]     == thisSubject, 1);
    if isempty(iPair) || isempty(iTrk)
        error('prepare_trial_matrices:MissingParticipant', ...
            'Participant %d is missing from the pairing or the tracking error.', ...
            thisSubject);
    end

    % ---- line up the error with the power, epoch by epoch --------------
    wanted = pairing(iPair).pairs;
    [found, rowInTrk] = ismember(wanted, trk(iTrk).trialEpoch, 'rows');
    if ~all(found)
        error('prepare_trial_matrices:UnmatchedEpoch', ...
            ['Participant %d: %d of %d paired epochs have no tracking error ', ...
             'row. Rebuild the tracking error and the pairing together.'], ...
            thisSubject, sum(~found), numel(found));
    end

    errEpoch = trk(iTrk).error(rowInTrk, :);
    if size(errEpoch, 2) ~= nPct
        error('prepare_trial_matrices:AxisMismatch', ...
            ['Participant %d has %d error samples against %d power samples. ', ...
             'The tracking error must be built on the power percent axis.'], ...
            thisSubject, size(errEpoch, 2), nPct);
    end

    pressEpoch = trk(iTrk).pressure(rowInTrk);
    scoreEpoch = trk(iTrk).score(rowInTrk);
    trialEpoch = trk(iTrk).trialEpoch(rowInTrk, 1);
    flagEpoch  = trk(iTrk).flagOutlier(rowInTrk);

    % ---- band average the power ----------------------------------------
    p = pow.power{s};
    if strcmp(opts.baseline, 'divisive')
        p = divisive_baseline(p, pressEpoch, opts.conditions);
    end

    powEpoch = struct();
    for b = 1:numel(bandNames)
        band = bandNames{b};
        m = mean(p(bandIdx.(band), :, :), 1);
        powEpoch.(band) = permute(m, [3 2 1]);
    end

    % ---- optional cycle level filtering ---------------------------------
    keep = true(size(trialEpoch));
    if opts.dropOutlierCycles
        keep = keep & ~flagEpoch;
    end

    errEpoch   = errEpoch(keep, :);
    pressEpoch = pressEpoch(keep);
    scoreEpoch = scoreEpoch(keep);
    trialEpoch = trialEpoch(keep);
    for b = 1:numel(bandNames)
        powEpoch.(bandNames{b}) = powEpoch.(bandNames{b})(keep, :);
    end

    % ---- aggregate -------------------------------------------------------
    switch opts.aggregate
        case 'trial'
            [errAgg, powAgg, pressAgg, scoreAgg, nPerTrial] = ...
                aggregate_by_trial(errEpoch, powEpoch, trialEpoch, ...
                pressEpoch, scoreEpoch, bandNames);
        case 'epoch'
            errAgg    = errEpoch;
            powAgg    = powEpoch;
            pressAgg  = pressEpoch;
            scoreAgg  = scoreEpoch;
            nPerTrial = ones(size(pressAgg));
    end

    if opts.dropZeroScore
        alive     = scoreAgg ~= 0;
        errAgg    = errAgg(alive, :);
        for b = 1:numel(bandNames)
            powAgg.(bandNames{b}) = powAgg.(bandNames{b})(alive, :);
        end
        pressAgg  = pressAgg(alive);
        nPerTrial = nPerTrial(alive);
    end

    % ---- split by condition ----------------------------------------------
    for c = 1:nCond
        sel = pressAgg == opts.conditions(c);
        data.E{s, c} = errAgg(sel, :);
        for b = 1:numel(bandNames)
            data.P.(bandNames{b}){s, c} = powAgg.(bandNames{b})(sel, :);
        end
        data.nTrials(s, c) = sum(sel);
    end

    if opts.verbose
        fprintf(['Participant %d: %d observations (%s level), %s per ', ...
            'condition, median %.1f cycles each\n'], ...
            thisSubject, numel(pressAgg), opts.aggregate, ...
            mat2str(data.nTrials(s, :)), median(nPerTrial));
    end

end

end


% ----------------------------------------------------------------------------
function [errAgg, powAgg, pressAgg, scoreAgg, nPerTrial] = ...
    aggregate_by_trial(errEpoch, powEpoch, trialEpoch, pressEpoch, ...
    scoreEpoch, bandNames)
%AGGREGATE_BY_TRIAL  Average the movement cycles that belong to one trial.

uTrial    = unique(trialEpoch, 'stable');
nTrial    = numel(uTrial);
errAgg    = zeros(nTrial, size(errEpoch, 2));
pressAgg  = zeros(nTrial, 1);
scoreAgg  = zeros(nTrial, 1);
nPerTrial = zeros(nTrial, 1);

powAgg = struct();
for b = 1:numel(bandNames)
    powAgg.(bandNames{b}) = zeros(nTrial, size(errEpoch, 2));
end

for k = 1:nTrial

    sel = trialEpoch == uTrial(k);

    errAgg(k, :)  = mean(errEpoch(sel, :), 1);
    pressAgg(k)   = pressEpoch(find(sel, 1));
    scoreAgg(k)   = scoreEpoch(find(sel, 1));
    nPerTrial(k)  = sum(sel);

    for b = 1:numel(bandNames)
        powAgg.(bandNames{b})(k, :) = mean(powEpoch.(bandNames{b})(sel, :), 1);
    end

    if numel(unique(pressEpoch(sel))) > 1
        error('prepare_trial_matrices:MixedPressure', ...
            'Trial %d carries more than one pressure level.', uTrial(k));
    end

end

end


% ----------------------------------------------------------------------------
function p = divisive_baseline(p, pressEpoch, conditions)
%DIVISIVE_BASELINE  Scale every frequency by its grand mean across conditions.
%
%   The mean is taken within each condition first and the three condition means
%   are then averaged, so an unequal number of trials per condition does not tilt
%   the result towards the condition with the most data.

nFreq = size(p, 1);
base  = zeros(nFreq, 1);
used  = 0;

for c = 1:numel(conditions)
    sel = pressEpoch == conditions(c);
    if ~any(sel)
        continue
    end
    condMean = mean(mean(p(:, :, sel), 3), 2);
    base     = base + condMean;
    used     = used + 1;
end

if used == 0
    error('prepare_trial_matrices:NoConditionData', ...
        'No epoch belongs to any of the requested pressure conditions.');
end

base = base / used;
p    = p ./ repmat(base, 1, size(p, 2), size(p, 3));

end
