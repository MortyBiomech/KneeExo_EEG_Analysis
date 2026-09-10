function [qc, isBad, details] = tf_qc_bad_trials(tfCells, freqs, trials, varargin)
%TF_QC_BAD_TRIALS Identify bad TF trials using robust (MAD-based) outlier rules.
%
% Inputs
%   tfCells : cell array, size [nTrials x 1] (or [1 x nTrials])
%             Each cell contains a 2D TF power matrix (nFreq x nTime) OR (nTime x nFreq).
%             Assumes power already in your intended units (e.g., dB, log-power, etc).
%   freqs   : vector of frequency bins corresponding to one TF dimension
%
% Name-value options
%   'HighBand'      : [35 80]  (Hz)  for EMG-like band
%   'RefBand'       : [8 30]   (Hz)  reference band for ratio
%   'HotZ'          : 5        abs(z) threshold for "hot pixels" at TF-bin level
%   'Zth'           : 3.5      robust z-score threshold for outlier decision (A,B,C,D)
%   'CorrType'      : 'Pearson' or 'Spearman'
%   'AssumeFreqDim' : 'auto' | 1 | 2
%                     auto: infer whether freqs matches rows or cols of TF matrices.
%
% Outputs
%   qc     : table with per-trial metrics and robust z-scores
%   isBad  : logical vector [nTrials x 1], true if trial flagged by any metric
%   details: struct with intermediate arrays (medianTF, etc.)
%
% Unchanged from the pre-cleanup analysis. Moved into this module so the
% QC step lives with the rest of the ERSP pipeline; ANSYMB2024, ERSP
% cluster analysis (QC extension), see README.md.
% -------------------- Parse inputs --------------------
p = inputParser;
p.addRequired('tfCells', @(c) iscell(c) && ~isempty(c));
p.addRequired('freqs', @(x) isnumeric(x) && isvector(x) && ~isempty(x));
p.addParameter('HighBand', [35 80], ...
    @(x) isnumeric(x) && numel(x)==2);
p.addParameter('RefBand',  [8 30],  ...
    @(x) isnumeric(x) && numel(x)==2);
p.addParameter('HotZ',     5,       ...
    @(x) isnumeric(x) && isscalar(x) && x>0);
p.addParameter('Zth',      3.5,     ...
    @(x) isnumeric(x) && isscalar(x) && x>0);
p.addParameter('CorrType', 'Pearson', ...
    @(s) ischar(s) || isstring(s));
p.addParameter('AssumeFreqDim', 'auto', ...
    @(x) (ischar(x)||isstring(x)) || (isscalar(x) && any(x==[1 2])));
p.parse(tfCells, freqs, varargin{:});
opt = p.Results;

tfCells = tfCells(:);
nTrials = numel(tfCells);

% Validate consistent sizes
sz0 = size(tfCells{1});
for k = 2:nTrials
    if ~isequal(size(tfCells{k}), sz0)
        error(['All TF matrices must have the same size. ' ...
            'Trial 1 is %s, trial %d is %s.'], ...
            mat2str(sz0), k, mat2str(size(tfCells{k})));
    end
end

% -------------------- Determine freq dimension --------------------
if ischar(opt.AssumeFreqDim) || isstring(opt.AssumeFreqDim)
    assume = lower(string(opt.AssumeFreqDim));
    if assume == "auto"
        if numel(freqs) == sz0(1)
            freqDim = 1;
        elseif numel(freqs) == sz0(2)
            freqDim = 2;
        else
            error(['Cannot infer freq dimension: length(freqs)=%d, ' ...
                'TF size=%s. Set AssumeFreqDim to 1 or 2.'], ...
                numel(freqs), mat2str(sz0));
        end
    else
        error('AssumeFreqDim must be "auto", 1, or 2.');
    end
else
    freqDim = opt.AssumeFreqDim;
    if numel(freqs) ~= sz0(freqDim)
        error(['AssumeFreqDim=%d but length(freqs)=%d does not match ' ...
            'TF size in that dimension (%d).'], ...
            freqDim, numel(freqs), sz0(freqDim));
    end
end

idxBand = @(band) find(freqs >= band(1) & freqs <= band(2));
hiIdx  = idxBand(opt.HighBand);
refIdx = idxBand(opt.RefBand);
if isempty(hiIdx) || isempty(refIdx)
    error('HighBand or RefBand has no overlap with freqs.');
end

% -------------------- Stack TF into 3D --------------------
if freqDim == 1
    nF = sz0(1); nT = sz0(2);
    TF = nan(nF, nT, nTrials);
    for k = 1:nTrials
        TF(:,:,k) = tfCells{k};
    end
else
    nF = sz0(2); nT = sz0(1);
    TF = nan(nF, nT, nTrials);
    for k = 1:nTrials
        TF(:,:,k) = tfCells{k}.';
    end
end
TFvec = reshape(TF, [], nTrials);

% -------------------- Metric A: global power outlier --------------------
A_globalMedAbs = nan(nTrials,1);
for k = 1:nTrials
    x = TFvec(:,k);
    A_globalMedAbs(k) = median(abs(x), 'omitnan');
end

% -------------------- Metric B: HF contamination ratio --------------------
B_hfRatio = nan(nTrials,1);
for k = 1:nTrials
    X = TF(:,:,k);
    hf  = X(hiIdx,  :);
    ref = X(refIdx, :);
    num = median(abs(hf(:)), 'omitnan');
    den = median(abs(ref(:)), 'omitnan');
    B_hfRatio(k) = num / max(den, eps);
end

% -------------------- Metric C: hot pixels proportion --------------------
medBin = median(TF, 3, 'omitnan');
madBin = mad(TF, 1, 3);
denBin = 1.4826 * madBin;
denBin(denBin < eps) = eps;
hotProp = nan(nTrials,1);
for k = 1:nTrials
    Z = (TF(:,:,k) - medBin) ./ denBin;
    hotProp(k) = mean(abs(Z(:)) > opt.HotZ, 'omitnan');
end

% -------------------- Metric D: correlation with "typical" trial --------------------
typicalVec = median(TFvec, 2, 'omitnan');
D_corrToMedian = nan(nTrials,1);
corrType = lower(string(opt.CorrType));
for k = 1:nTrials
    x = TFvec(:,k);
    good = isfinite(x) & isfinite(typicalVec);
    if nnz(good) < 10
        D_corrToMedian(k) = NaN;
    else
        if corrType == "spearman"
            D_corrToMedian(k) = corr(x(good), typicalVec(good), 'Type', 'Spearman');
        else
            D_corrToMedian(k) = corr(x(good), typicalVec(good), 'Type', 'Pearson');
        end
    end
end

% -------------------- Robust z-scores (MAD-based) --------------------
zA = robust_z(A_globalMedAbs);
zB = robust_z(B_hfRatio);
zC = robust_z(hotProp);
zD = robust_z(D_corrToMedian);

Zth = opt.Zth;
flagA = abs(zA) > Zth;
flagB = abs(zB) > Zth;
flagC = abs(zC) > Zth;
flagD = zD < -Zth;
isBad = flagA | flagB | flagC | flagD;

qc = table( ...
    A_globalMedAbs, zA, flagA, ...
    B_hfRatio,      zB, flagB, ...
    hotProp,        zC, flagC, ...
    D_corrToMedian, zD, flagD, ...
    isBad, trials);

details = struct();
details.freqDim     = freqDim;
details.HiIdx       = hiIdx;
details.RefIdx      = refIdx;
details.medianTF    = reshape(typicalVec, nF, nT);
details.medBin      = medBin;
details.denBin      = denBin;
end

function z = robust_z(x)
x = x(:);
m = median(x, 'omitnan');
s = 1.4826 * mad(x, 1);
if ~isfinite(s) || s < eps
    z = nan(size(x));
else
    z = (x - m) ./ s;
end
end
