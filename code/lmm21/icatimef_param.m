function v = icatimef_param(parameters, key, default)
%ICATIMEF_PARAM  Read one value out of an EEGLAB parameters cell.
%
%  v = ICATIMEF_PARAM(parameters, key) returns the value stored against key,
%  or [] when the key is absent. Comparison is case insensitive, because
%  EEGLAB is not consistent about the case of its parameter names.
%
%  v = ICATIMEF_PARAM(parameters, key, default) returns default instead of [].
%
%  The parameters field of a .icatimef file is a flat cell of name value
%  pairs, {'cycles', [3 0.5], 'freqs', [1 70], ...}. It is the record of what
%  the precompute actually did, which matters here because the baseline window
%  and the time warp landmarks of the features have to be the ones the ERSP
%  figures were built with, not ones re entered by hand.

if nargin < 3
    default = [];
end

v = default;

if isempty(parameters)
    return
end

if isstruct(parameters)
    % Some versions store a struct rather than a cell.
    f = fieldnames(parameters);
    hit = find(strcmpi(f, key), 1);
    if ~isempty(hit)
        v = parameters.(f{hit});
    end
    return
end

if ~iscell(parameters)
    return
end

% Nested cell, which happens when parameters were wrapped once more.
if numel(parameters) == 1 && iscell(parameters{1})
    parameters = parameters{1};
end

for i = 1:2:numel(parameters) - 1
    name = parameters{i};
    if (ischar(name) || isstring(name)) && strcmpi(char(name), key)
        v = parameters{i + 1};
        return
    end
end

end
