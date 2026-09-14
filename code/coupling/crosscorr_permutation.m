function out = crosscorr_permutation(Ecell, Pcell, opts)
%CROSSCORR_PERMUTATION  Trial-shuffled null for a group mean cross-correlation.
%
%   OUT = CROSSCORR_PERMUTATION(ECELL, PCELL, OPTS) tests whether the tracking
%   error and the band power of a given cluster covary from trial to trial.
%
%   ECELL and PCELL are {nSubjects x 1} cell arrays holding, for one pressure
%   condition and one frequency band, the [nTrials x nTime] matrices of the two
%   signals. Row k of ECELL{s} and row k of PCELL{s} are the same trial. Empty
%   cells are skipped, so a participant without an independent component in the
%   cluster needs no special handling by the caller.
%
%   The observed statistic is the correlation averaged over trials within a
%   participant and then over participants, which weights every participant
%   equally regardless of how many trials they contributed.
%
%   Under the null hypothesis the power of a trial carries no information about
%   the error of that same trial. The null is therefore built by permuting the
%   trial labels of the power within each participant, which leaves every
%   marginal property of both signals untouched, including the cyclic waveform,
%   the trial count and the condition structure. Only the pairing changes. This
%   is the standard exchangeability argument for paired data, as in Maris, E., &
%   Oostenveld, R. (2007), Nonparametric statistical testing of EEG- and
%   MEG-data, Journal of Neuroscience Methods, 164(1), 177-190.
%
%   Because a correlation is evaluated at every lag, the omnibus statistic is
%   the largest absolute group mean correlation over all lags. Comparing it
%   against the distribution of the same maximum under the null controls the
%   family-wise error rate over lags without any further correction, which is
%   the max-statistic argument of Nichols, T. E., & Holmes, A. P. (2002),
%   Nonparametric permutation tests for functional neuroimaging, Human Brain
%   Mapping, 15(1), 1-25.
%
%   OPTS fields:
%     maxLag      maximum lag in samples (required)
%     nPerm       number of permutations (default 1000)
%     rngSeed     seed for the permutation stream (default 42)
%     minOverlap  shortest admissible overlap in samples (default 10)
%     alpha       two-sided level for the pointwise band (default 0.05)
%
%   OUT fields:
%     lags          [1 x nLags] lags in samples
%     groupMean     [1 x nLags] observed group mean correlation
%     groupSem      [1 x nLags] standard error across participants
%     subjectMean   [nSubjects x nLags] per-participant mean, NaN where empty
%     nullLo        [1 x nLags] lower pointwise percentile of the null
%     nullHi        [1 x nLags] upper pointwise percentile of the null
%     nullMax       [nPerm x 1] null distribution of the omnibus statistic
%     statObs       observed omnibus statistic
%     pOmnibus      permutation p value, floored at 1/(nPerm+1)
%     peakLag       lag of the largest absolute group mean correlation
%     peakR         signed group mean correlation at that lag
%     nSubjects     number of participants contributing
%     nTrials       [nSubjects x 1] trials per participant
%
%   See also XCORR_PEARSON.
%
%   Part of the KneeExo-EEG analysis code.

arguments
    Ecell cell
    Pcell cell
    opts.maxLag (1,1) double {mustBePositive, mustBeInteger}
    opts.nPerm (1,1) double {mustBeNonnegative, mustBeInteger} = 1000
    opts.rngSeed (1,1) double = 42
    opts.minOverlap (1,1) double {mustBePositive} = 10
    opts.alpha (1,1) double {mustBePositive} = 0.05
end

nSub  = numel(Ecell);
nLags = 2*opts.maxLag + 1;

if numel(Pcell) ~= nSub
    error('crosscorr_permutation:SizeMismatch', ...
        'Ecell has %d entries and Pcell has %d.', nSub, numel(Pcell));
end

use     = false(nSub, 1);
nTrials = zeros(nSub, 1);
for s = 1:nSub
    if isempty(Ecell{s}) || isempty(Pcell{s})
        continue
    end
    if ~isequal(size(Ecell{s}), size(Pcell{s}))
        error('crosscorr_permutation:TrialMismatch', ...
            ['Participant %d has a %dx%d error matrix and a %dx%d power ', ...
             'matrix. The two must be paired trial by trial.'], ...
            s, size(Ecell{s}, 1), size(Ecell{s}, 2), ...
            size(Pcell{s}, 1), size(Pcell{s}, 2));
    end
    use(s)     = true;
    nTrials(s) = size(Ecell{s}, 1);
end

if ~any(use)
    error('crosscorr_permutation:NoData', 'No participant has data.');
end

% ---- observed -----------------------------------------------------------
subjectMean = nan(nSub, nLags);
for s = find(use).'
    rTrials          = xcorr_pearson(Ecell{s}, Pcell{s}, opts.maxLag, opts.minOverlap);
    subjectMean(s,:) = mean(rTrials, 1, 'omitnan');
end

[groupMean, groupSem] = mean_and_sem(subjectMean(use, :));
statObs = max(abs(groupMean));

% ---- null ---------------------------------------------------------------
% With nPerm set to zero only the observed curve is returned. That is the right
% setting when each participant contributes a single averaged waveform, because
% there are then no trial labels left to permute.
stream  = RandStream('twister', 'Seed', opts.rngSeed);
nullAll = nan(max(opts.nPerm, 1), nLags);
nullMax = nan(opts.nPerm, 1);

subjIdx = find(use).';
if opts.nPerm > 0
    fprintf('  permutation null: ');
end
for iPerm = 1:opts.nPerm

    permMean = nan(nSub, nLags);
    for s = subjIdx
        n = nTrials(s);
        % A derangement is not required. Leaving a few trials matched by
        % chance is part of the null and shifts it only by O(1/n).
        order            = randperm(stream, n);
        rTrials          = xcorr_pearson(Ecell{s}, Pcell{s}(order, :), ...
            opts.maxLag, opts.minOverlap);
        permMean(s, :)   = mean(rTrials, 1, 'omitnan');
    end

    nullAll(iPerm, :) = mean_and_sem(permMean(use, :));
    nullMax(iPerm)    = max(abs(nullAll(iPerm, :)));

    if mod(iPerm, max(1, round(opts.nPerm/10))) == 0
        fprintf('%d%% ', round(100*iPerm/opts.nPerm));
    end
end
if opts.nPerm > 0
    fprintf('done\n');
end

loPct = 100 * (opts.alpha/2);
hiPct = 100 * (1 - opts.alpha/2);

out = struct();
out.lags        = -opts.maxLag:opts.maxLag;
out.groupMean   = groupMean;
out.groupSem    = groupSem;
out.subjectMean = subjectMean;
out.nSubjects   = sum(use);
out.nTrials     = nTrials;
out.settings    = opts;
out.statObs     = statObs;

if opts.nPerm > 0
    out.nullLo   = prctile(nullAll, loPct, 1);
    out.nullHi   = prctile(nullAll, hiPct, 1);
    out.nullMax  = nullMax;
    out.pOmnibus = (1 + sum(nullMax >= statObs)) / (opts.nPerm + 1);
else
    out.nullLo   = nan(1, nLags);
    out.nullHi   = nan(1, nLags);
    out.nullMax  = [];
    out.pOmnibus = NaN;
end

[~, iPeak]  = max(abs(groupMean));
out.peakLag = out.lags(iPeak);
out.peakR   = groupMean(iPeak);

end


% ----------------------------------------------------------------------------
function [m, sem] = mean_and_sem(X)
%MEAN_AND_SEM  Column mean and standard error, ignoring missing entries.
%
%   Written out rather than using the omitnan flag of MEAN and STD, because the
%   flag on STD is recent and this keeps the function usable on older releases.

valid  = ~isnan(X);
nValid = sum(valid, 1);

Z          = X;
Z(~valid)  = 0;
m          = sum(Z, 1) ./ max(nValid, 1);

D          = (X - m) .^ 2;
D(~valid)  = 0;
sd         = sqrt(sum(D, 1) ./ max(nValid - 1, 1));
sem        = sd ./ sqrt(max(nValid, 1));

m(nValid == 0)   = NaN;
sem(nValid < 2)  = NaN;

end
