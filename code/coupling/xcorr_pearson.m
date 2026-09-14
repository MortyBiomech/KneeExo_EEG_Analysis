function [r, lags] = xcorr_pearson(E, P, maxLag, minOverlap)
%XCORR_PEARSON  Row-wise lagged Pearson correlation over the overlapping samples.
%
%   [R, LAGS] = XCORR_PEARSON(E, P, MAXLAG) correlates each row of E with the
%   matching row of P at the integer lags -MAXLAG:MAXLAG. The value at lag L is
%   the Pearson correlation between E(t) and P(t + L), computed only from the
%   samples at which both signals are defined. A positive lag therefore means
%   that the P signal follows the E signal in time.
%
%   [R, LAGS] = XCORR_PEARSON(E, P, MAXLAG, MINOVERLAP) returns NaN at any lag
%   whose overlap is shorter than MINOVERLAP samples. The default is 10.
%
%   R is [nRows x (2*MAXLAG+1)] and LAGS is [1 x (2*MAXLAG+1)].
%
%   Why this rather than XCORR(..., 'normalized'):
%
%     1. XCORR does not remove the mean of either signal. With signals that sit
%        far from zero, such as raw spectral power or an unsigned tracking
%        error, the result is then dominated by the product of the two means
%        rather than by their covariation. A Pearson correlation removes both
%        means, so no separate detrending step is needed.
%
%     2. XCORR normalises every lag by the norms of the full signals, while the
%        sum at lag L runs over only nTime - |L| products. The returned value
%        therefore decays towards zero as |L| grows even when the underlying
%        correlation is constant, which biases any estimate of the peak lag
%        towards zero. Normalising by the actual overlap removes that taper.
%
%   The six lag-dependent sums are obtained by FFT, so the cost is
%   O(nRows * nfft * log nfft) rather than O(nRows * nTime * nLags).
%
%   Reference for the overlap-normalised form: Bendat, J. S., & Piersol, A. G.
%   (2010). Random Data: Analysis and Measurement Procedures, 4th ed., Wiley,
%   chapter 5. The unbiased estimator divides each lag by its own number of
%   contributing products.
%
%   See also CROSSCORR_PERMUTATION.
%
%   Part of the KneeExo-EEG analysis code.

if nargin < 4 || isempty(minOverlap)
    minOverlap = 10;
end

validateattributes(E, {'numeric'}, {'2d', 'real'}, mfilename, 'E', 1);
validateattributes(P, {'numeric'}, {'2d', 'real'}, mfilename, 'P', 2);
if ~isequal(size(E), size(P))
    error('xcorr_pearson:SizeMismatch', ...
        'E is %dx%d and P is %dx%d. They must have the same size.', ...
        size(E, 1), size(E, 2), size(P, 1), size(P, 2));
end

nTime = size(E, 2);
if maxLag >= nTime
    error('xcorr_pearson:LagTooLarge', ...
        'maxLag (%d) must be smaller than the number of samples (%d).', ...
        maxLag, nTime);
end

nfft = 2^nextpow2(2*nTime - 1);
U    = ones(size(E));

FE  = fft(E,    nfft, 2);
FP  = fft(P,    nfft, 2);
FU  = fft(U,    nfft, 2);
FE2 = fft(E.^2, nfft, 2);
FP2 = fft(P.^2, nfft, 2);

% Circular cross-correlation with zero padding. Index k of the inverse
% transform of conj(fft(a)) .* fft(b) holds sum_t a(t) * b(t + k - 1).
ord = [nfft - maxLag + 1 : nfft, 1 : maxLag + 1];

Sep = lagged(FE,  FP,  ord);   % sum of e * p over the overlap
Se  = lagged(FE,  FU,  ord);   % sum of e over the overlap
Sp  = lagged(FU,  FP,  ord);   % sum of p over the overlap
See = lagged(FE2, FU,  ord);   % sum of e squared over the overlap
Spp = lagged(FU,  FP2, ord);   % sum of p squared over the overlap
Sn  = lagged(FU,  FU,  ord);   % number of overlapping samples

covEP = Sep - (Se .* Sp) ./ Sn;
varE  = See - (Se .^ 2)  ./ Sn;
varP  = Spp - (Sp .^ 2)  ./ Sn;

denom = sqrt(varE .* varP);
r     = covEP ./ denom;

% Rounding can leave a variance marginally negative or a correlation just
% outside [-1, 1] when a signal is nearly constant over the overlap.
r(denom <= 0 | ~isfinite(denom)) = NaN;
r(Sn < minOverlap) = NaN;
r = max(min(r, 1), -1);

lags = -maxLag:maxLag;

end


% ----------------------------------------------------------------------------
function S = lagged(FA, FB, ord)
%LAGGED  Lag-dependent sums of A(t) .* B(t + lag), selected at the wanted lags.

S = real(ifft(conj(FA) .* FB, [], 2));
S = S(:, ord);

end
