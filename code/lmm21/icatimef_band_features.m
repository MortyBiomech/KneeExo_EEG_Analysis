function [ratio, info] = icatimef_band_features(P, freqs, times, bands, ...
    cycleWindowMs, baselineWindowMs, trialBaseline)
%ICATIMEF_BAND_FEATURES  Whole cycle band power ratio, one value per epoch.
%
%  ratio = ICATIMEF_BAND_FEATURES(P, freqs, times, bands, cycleWindowMs, ...
%          baselineWindowMs, trialBaseline)
%
%  P                 [nFreq x nTime x nEpoch] linear power
%  freqs             [1 x nFreq] Hz
%  times             [1 x nTime] ms on the warped grid
%  bands             struct array with fields name and edges, edges = [lo hi] Hz
%  cycleWindowMs     [lo hi] ms, the movement cycle, normally the first and
%                    last time warp landmark
%  baselineWindowMs  [lo hi] ms, or [] for no baseline
%  trialBaseline     false for one baseline spectrum per participant and
%                    component, true for a per epoch baseline
%
%  ratio             [nEpoch x nBand], the mean of P(f,t)/B(f) over the band
%                    by cycle patch, in LINEAR units
%  info              struct with the indices used, the baseline spectrum and
%                    the count of non finite entries
%
%  The value returned is deliberately linear, not dB. The scalar feature is
%  defined as mean first and log second,
%
%        feature = 10 * log10( mean over band, cycle and epochs of P/B )
%
%  so the log has to be taken once, after the epochs of a trial have been
%  averaged, and that averaging happens in the caller. Taking 10*log10 here
%  and averaging afterwards computes the geometric mean across epochs instead
%  of the arithmetic one, which is a different feature.
%
%  Baseline. With trialBaseline false the baseline spectrum is the mean power
%  in the baseline window over every epoch of that participant and component.
%  This is what makes the feature usable at trial level: a per epoch baseline
%  divides each epoch by its own power and removes exactly the trial to trial
%  variation the model is trying to explain. The band edges and the baseline
%  window must match the ones used for the published ERSP figures, otherwise
%  the figure and the null describe different quantities.
%
%  See also READ_ICATIMEF_COMPONENT, BUILD_EEG_FEATURE_TABLE.

if nargin < 7 || isempty(trialBaseline)
    trialBaseline = false;
end

freqs = freqs(:).';
times = times(:).';

nF = numel(freqs);
nT = numel(times);
nE = size(P, 3);
nB = numel(bands);

if size(P, 1) ~= nF || size(P, 2) ~= nT
    error('icatimef_band_features:size', ...
        'P is %dx%dx%d but freqs has %d and times has %d entries.', ...
        size(P, 1), size(P, 2), nE, nF, nT);
end

% ---- cycle window -------------------------------------------------------
if isempty(cycleWindowMs)
    cycIdx = true(1, nT);
else
    cycIdx = times >= cycleWindowMs(1) & times <= cycleWindowMs(2);
end
if ~any(cycIdx)
    error('icatimef_band_features:cycleWindow', ...
        ['The cycle window [%g %g] ms does not overlap the time axis ' ...
         '[%g %g] ms.'], cycleWindowMs(1), cycleWindowMs(2), times(1), times(end));
end

% ---- baseline -----------------------------------------------------------
if isempty(baselineWindowMs)
    baseIdx = false(1, nT);
    B = ones(nF, 1);
else
    baseIdx = times >= baselineWindowMs(1) & times <= baselineWindowMs(2);
    if ~any(baseIdx)
        error('icatimef_band_features:baselineWindow', ...
            ['The baseline window [%g %g] ms does not overlap the time axis ' ...
             '[%g %g] ms.'], baselineWindowMs(1), baselineWindowMs(2), ...
            times(1), times(end));
    end

    if trialBaseline
        B = mean(P(:, baseIdx, :), 2, 'omitnan');        % nF x 1 x nE
    else
        flat = reshape(P(:, baseIdx, :), nF, []);        % nF x (nBaseT * nE)
        B    = mean(flat, 2, 'omitnan');                 % nF x 1
    end

    bad = ~isfinite(B) | B <= 0;
    if any(bad(:))
        warning('icatimef_band_features:badBaseline', ...
            ['%d of %d baseline entries are zero, negative or non finite. ' ...
             'The affected frequencies are set to NaN.'], nnz(bad), numel(B));
        B(bad) = NaN;
    end
end

% ---- band by cycle averages --------------------------------------------
ratio   = nan(nE, nB);
fUsed   = cell(nB, 1);
nFbins  = zeros(nB, 1);

for b = 1:nB
    edges = bands(b).edges;
    fIdx  = freqs >= edges(1) & freqs <= edges(2);

    if ~any(fIdx)
        error('icatimef_band_features:band', ...
            ['Band %s [%g %g] Hz does not overlap the frequency axis ' ...
             '[%g %g] Hz.'], bands(b).name, edges(1), edges(2), ...
            freqs(1), freqs(end));
    end

    patch = P(fIdx, cycIdx, :);                          % nFb x nTc x nE

    if trialBaseline
        R = patch ./ B(fIdx, 1, :);
    else
        R = patch ./ B(fIdx);
    end

    Rv = reshape(R, [], nE);                             % (nFb*nTc) x nE
    ratio(:, b) = mean(Rv, 1, 'omitnan').';

    fUsed{b}  = freqs(fIdx);
    nFbins(b) = nnz(fIdx);
end

% ---- audit --------------------------------------------------------------
info.cycleIdx        = cycIdx;
info.baselineIdx     = baseIdx;
info.nCycleBins      = nnz(cycIdx);
info.nBaselineBins   = nnz(baseIdx);
info.nFreqBins       = nFbins;
info.freqsUsed       = fUsed;
info.baseline        = B;
info.trialBaseline   = trialBaseline;
info.nEpochs         = nE;
info.nNonFinitePower = nnz(~isfinite(P));
info.nNonFiniteRatio = nnz(~isfinite(ratio));
info.cycleWindowMs   = cycleWindowMs;
info.baselineWindowMs = baselineWindowMs;

end
