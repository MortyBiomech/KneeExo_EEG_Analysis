function S = read_icatimef_component(icatimefFile, icIndex)
%READ_ICATIMEF_COMPONENT  Load one component's single trial time frequency data.
%
%  S = READ_ICATIMEF_COMPONENT(file, ic) returns
%    S.power      [nFreq x nTime x nEpoch] linear power, always real and non negative
%    S.freqs      [1 x nFreq]   Hz
%    S.times      [1 x nTime]   ms on the warped grid
%    S.trialinfo  struct array, one entry per epoch, as written by std_precomp
%    S.parameters cell of name value pairs from the precompute call
%    S.timewarpms [1 x nLandmark] warp target latencies in ms, or [] when absent
%    S.wasComplex true when the file held the complex decomposition
%
%  EEGLAB writes the single trial decomposition into a variable named
%  comp<ic>_timef. It is complex when std_precomp ran with savetrials on,
%  which is the only case in which trial level features are possible at all.
%  Power is abs(x).^2.
%
%  Only the requested component is read from disk. Loading the whole file
%  would pull every component of that participant into memory for no reason.
%
%  See also ICATIMEF_BAND_FEATURES, BUILD_EEG_FEATURE_TABLE.

if exist(icatimefFile, 'file') ~= 2
    error('read_icatimef_component:missing', ...
        'File not found: %s', icatimefFile);
end

varName = sprintf('comp%d_timef', icIndex);

info = whos('-file', icatimefFile);
names = {info.name};

if ~ismember(varName, names)
    % Some EEGLAB versions write channel data with a different prefix. Say
    % what is actually in the file rather than failing blind.
    compNames = names(startsWith(names, 'comp'));
    error('read_icatimef_component:noComponent', ...
        ['Variable %s is not in %s.\n' ...
         'Components present: %s'], ...
        varName, icatimefFile, strjoin(compNames, ', '));
end

want = {varName, 'freqs', 'times', 'parameters', 'trialinfo'};
want = want(ismember(want, names));

raw = load('-mat', icatimefFile, want{:});

X = raw.(varName);

if ndims(X) ~= 3
    error('read_icatimef_component:notSingleTrial', ...
        ['%s in %s has %d dimensions, not 3. The file holds a trial ' ...
         'averaged decomposition, so trial level features cannot be built ' ...
         'from it. Re run the precompute with savetrials on.'], ...
        varName, icatimefFile, ndims(X));
end

S.wasComplex = ~isreal(X);
if S.wasComplex
    S.power = abs(X) .^ 2;
else
    % Already real. Treat as power, but a negative entry means it is dB or a
    % difference, and squaring it would be silently wrong.
    if any(X(:) < 0)
        error('read_icatimef_component:notPower', ...
            ['%s in %s is real and contains negative values, so it is not ' ...
             'linear power. This analysis needs the complex decomposition ' ...
             'or linear power.'], varName, icatimefFile);
    end
    S.power = double(X);
end

S.freqs = getFieldOrEmpty(raw, 'freqs');
S.times = getFieldOrEmpty(raw, 'times');

if isempty(S.freqs) || isempty(S.times)
    error('read_icatimef_component:noAxes', ...
        'freqs or times missing from %s.', icatimefFile);
end

S.freqs = S.freqs(:).';
S.times = S.times(:).';

if numel(S.freqs) ~= size(S.power, 1) || numel(S.times) ~= size(S.power, 2)
    error('read_icatimef_component:axisMismatch', ...
        ['Axis lengths do not match the data in %s: ' ...
         'freqs %d vs %d, times %d vs %d.'], icatimefFile, ...
        numel(S.freqs), size(S.power, 1), ...
        numel(S.times), size(S.power, 2));
end

S.trialinfo  = getFieldOrEmpty(raw, 'trialinfo');
S.parameters = getFieldOrEmpty(raw, 'parameters');

if ~isempty(S.trialinfo) && numel(S.trialinfo) ~= size(S.power, 3)
    warning('read_icatimef_component:trialinfoLength', ...
        ['trialinfo has %d entries but the data has %d epochs in %s. ' ...
         'The epoch to trial join cannot be trusted.'], ...
        numel(S.trialinfo), size(S.power, 3), icatimefFile);
end

S.timewarpms = icatimef_param(S.parameters, 'timewarpms');
if ~isempty(S.timewarpms) && ~isvector(S.timewarpms)
    % A per epoch matrix of landmark latencies. The warped grid is common to
    % every epoch, so the group target is the median down the rows.
    S.timewarpms = median(S.timewarpms, 1, 'omitnan');
end
if ~isempty(S.timewarpms)
    S.timewarpms = S.timewarpms(:).';
end

S.file    = icatimefFile;
S.icIndex = icIndex;
S.nEpochs = size(S.power, 3);

end

% -------------------------------------------------------------------------
function v = getFieldOrEmpty(s, f)
if isfield(s, f)
    v = s.(f);
else
    v = [];
end
end
