function out = lmm21_trial_features(power, freqs, epochTrial, epochCond, bands, opts)
%LMM21_TRIAL_FEATURES  Whole-cycle band power per trial, for one component.
%
%   OUT = LMM21_TRIAL_FEATURES(POWER, FREQS, EPOCHTRIAL, EPOCHCOND, BANDS, OPTS)
%   turns the single-trial time-frequency power of one participant's component
%   into one number per trial per band.
%
%   POWER       [nFreq x nTime x nEpoch] linear power, already cropped to the
%               warped movement cycle
%   FREQS       [1 x nFreq] Hz
%   EPOCHTRIAL  [nEpoch x 1] trial number of each epoch
%   EPOCHCOND   [nEpoch x 1] condition of each epoch, used for the QC and the
%               condition-balanced baseline
%   BANDS       struct, one field per band, each [lo hi] Hz. Lower edge
%               inclusive, upper edge exclusive.
%
%   OPTS fields:
%     applyQC     run FLAG_BAD_TRIALS per condition and drop what it flags
%                 (default true)
%     qc          the settings struct, ERSP_PARAMS' p.qc
%     baseline    'ersp' or 'none' (default 'ersp')
%     aggSpace    'linear' or 'db' (default 'linear')
%
%   OUT fields:
%     trial       [nTrial x 1] trial numbers, ascending
%     feature     [nTrial x nBand] whole-cycle band power in dB
%     nEpochs     [nTrial x 1] movement cycles behind each value
%     cond        [nTrial x 1] condition of each trial
%     baseline    [nFreq x 1] the baseline spectrum used
%     isBad       [nEpoch x 1] the QC verdict per epoch
%     nBandBins   [1 x nBand] frequency bins in each band
%
%   THE DEFINITION
%
%       feature = 10 * log10( mean over band and cycle of P(f,t) / B(f) )
%
%   with the movement cycles of a trial averaged before the logarithm.
%
%   B is COMPUTE_CLUSTER_ERSP's baseline: the mean over the three conditions of
%   each condition's mean over QC-surviving trials, averaged over the cycle. A
%   feature here is therefore the same quantity as a pixel of the published
%   ERSP, averaged over a band and over the cycle instead of over trials.
%
%   Two properties of that baseline carry the analysis and are asserted in
%   CHECKS/CHECK_LMM21.
%
%   It is common across trials, not per trial. A per-trial baseline divides
%   every trial by its own power and removes exactly the trial-to-trial
%   variation this model exists to test.
%
%   It is condition-balanced. A plain mean over trials would let a participant
%   with more trials in one condition shift their own reference, and the
%   between-condition difference is the effect the figures report.
%
%   Averaging happens in linear ratio units and the logarithm is taken once, at
%   the end. Converting each epoch to dB and averaging afterwards computes a
%   geometric mean across cycles, which is a different and smaller number.
%
%   See also BUILD_LMM21_FEATURES, COMPUTE_CLUSTER_ERSP, FLAG_BAD_TRIALS.
%
%   Part of the KneeExo-EEG analysis code.

arguments
    power double
    freqs (1,:) double
    epochTrial (:,1) double
    epochCond (:,1) double
    bands (1,1) struct
    opts.applyQC (1,1) logical = true
    opts.qc (1,1) struct = struct('highBand', [35 80], 'refBand', [8 30], ...
                                  'hotZ', 5, 'zThreshold', 3, 'corrType', 'Spearman')
    opts.baseline (1,:) char {mustBeMember(opts.baseline, {'ersp', 'none'})} = 'ersp'
    opts.aggSpace (1,:) char {mustBeMember(opts.aggSpace, {'linear', 'db'})} = 'linear'
end

nF = numel(freqs);
nE = size(power, 3);
bandNames = fieldnames(bands);
nB = numel(bandNames);

if size(power, 1) ~= nF
    error('lmm21_trial_features:FreqLength', ...
        'POWER has %d frequency rows and FREQS has %d entries.', ...
        size(power, 1), nF);
end
if numel(epochTrial) ~= nE || numel(epochCond) ~= nE
    error('lmm21_trial_features:EpochLength', ...
        ['POWER has %d epochs, EPOCHTRIAL has %d and EPOCHCOND has %d. ' ...
         'All three describe the same epochs in the same order.'], ...
        nE, numel(epochTrial), numel(epochCond));
end

conds = unique(epochCond(~isnan(epochCond)));

% ---- quality control, per condition, as the published ERSPs do ----------
isBad = false(nE, 1);
if opts.applyQC
    for c = 1:numel(conds)
        idx = find(epochCond == conds(c));
        if isempty(idx)
            continue
        end
        cells = squeeze(num2cell(power(:, :, idx), [1 2]));
        [~, bad] = flag_bad_trials(cells, freqs, epochTrial(idx).', ...
            'HighBand', opts.qc.highBand, 'RefBand', opts.qc.refBand, ...
            'HotZ', opts.qc.hotZ, 'Zth', opts.qc.zThreshold, ...
            'CorrType', opts.qc.corrType);
        isBad(idx) = bad(:);
    end
end

good = ~isBad & ~isnan(epochCond);

if ~any(good)
    error('lmm21_trial_features:NoGoodEpochs', ...
        'Every epoch was flagged or has no condition.');
end

% ---- baseline ----------------------------------------------------------
switch opts.baseline
    case 'none'
        B = ones(nF, 1);

    case 'ersp'
        meanTF = cell(1, numel(conds));
        for c = 1:numel(conds)
            sel = good & epochCond == conds(c);
            if ~any(sel)
                error('lmm21_trial_features:EmptyCondition', ...
                    ['Condition %g has no surviving epoch, so the baseline ' ...
                     'cannot be condition balanced.'], conds(c));
            end
            meanTF{c} = mean(power(:, :, sel), 3);
        end
        B = mean(mean(cat(3, meanTF{:}), 3), 2);
end

if any(~isfinite(B) | B <= 0)
    error('lmm21_trial_features:BadBaseline', ...
        '%d of %d baseline entries are zero, negative or not finite.', ...
        nnz(~isfinite(B) | B <= 0), numel(B));
end

% ---- band by cycle average, per epoch, in linear ratio units ------------
ratio     = nan(nE, nB);
nBandBins = zeros(1, nB);

for b = 1:nB
    e = bands.(bandNames{b});
    fIdx = freqs >= e(1) & freqs < e(2);      % upper edge exclusive

    if ~any(fIdx)
        error('lmm21_trial_features:EmptyBand', ...
            'Band %s [%g %g) Hz contains no frequency bin of [%g %g] Hz.', ...
            bandNames{b}, e(1), e(2), freqs(1), freqs(end));
    end
    nBandBins(b) = nnz(fIdx);

    R  = power(fIdx, :, :) ./ B(fIdx);
    Rv = reshape(R, [], nE);
    ratio(:, b) = mean(Rv, 1, 'omitnan').';
end

% ---- movement cycles to trials -----------------------------------------
gTrial = epochTrial(good);
gRatio = ratio(good, :);
gCond  = epochCond(good);

[gid, uTrial] = findgroups(gTrial);

switch opts.aggSpace
    case 'linear'
        lin = splitapply(@(v) mean(v, 1, 'omitnan'), gRatio, gid);
        feature = 10 * log10(lin);
    case 'db'
        feature = splitapply(@(v) mean(v, 1, 'omitnan'), 10 * log10(gRatio), gid);
end

nEpochs = splitapply(@(v) size(v, 1), gRatio, gid);

% A trial belongs to one condition. If it does not, the epoch to trial mapping
% is wrong and averaging would hide it.
condPerTrial = splitapply(@(v) v(1), gCond, gid);
condSpread   = splitapply(@(v) max(v) - min(v), gCond, gid);
if any(condSpread > 0)
    error('lmm21_trial_features:MixedCondition', ...
        '%d trials contain epochs from more than one condition.', ...
        nnz(condSpread > 0));
end

out = struct();
out.trial     = uTrial(:);
out.feature   = feature;
out.nEpochs   = nEpochs(:);
out.cond      = condPerTrial(:);
out.baseline  = B;
out.isBad     = isBad;
out.nBandBins = nBandBins;
out.bandNames = bandNames(:).';
out.nEpochsUsed = nnz(good);
out.nEpochsTotal = nE;

end
