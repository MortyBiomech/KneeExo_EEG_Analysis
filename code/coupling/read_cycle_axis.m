function axisOut = read_cycle_axis(source, subject)
%READ_CYCLE_AXIS  The movement-cycle axis a time-frequency file sits on.
%
%   AXIS = READ_CYCLE_AXIS(FILE) reads only the time vector and the stored ERSP
%   parameters of a single-trial time-frequency file, and returns the percent of
%   cycle axis, the fraction of the cycle at which extension begins, and the
%   samples that fall inside the warp window. No component data are read, so
%   this is cheap enough to call before deciding whether anything else needs
%   loading.
%
%   AXIS = READ_CYCLE_AXIS(S) does the same for a struct S that already holds
%   the fields TIMES and PARAMETERS, so a caller that has loaded the file for
%   another reason does not read it twice.
%
%   AXIS fields:
%     pct         [1 x nKept] percent of the movement cycle
%     warpFrac    fraction of the cycle at which extension begins
%     timewarpms  the three group warp landmarks in milliseconds
%     keepTime    logical index of the samples inside the warp window
%     times       the original time vector in milliseconds
%
%   All participants share one group warp target, so every file must return the
%   same axis. LOAD_CLUSTER_POWER checks that they do.
%
%   See also LOAD_CLUSTER_POWER, ENSURE_COUPLING_INPUTS.
%
%   Part of the KneeExo-EEG analysis code.

if nargin < 2
    subject = NaN;
end

if ischar(source) || isstring(source)
    source = char(source);
    if exist(source, 'file') ~= 2
        error('read_cycle_axis:NoFile', 'Cannot find %s.', source);
    end
    tf = load(source, '-mat', 'times', 'parameters');
    label = source;
else
    tf = source;
    label = sprintf('participant %g', subject);
end

if ~isfield(tf, 'times') || ~isfield(tf, 'parameters')
    error('read_cycle_axis:MissingFields', ...
        '%s holds no times or no parameters.', label);
end

idx = find(strcmp(tf.parameters, 'timewarpms'), 1);
if isempty(idx)
    error('read_cycle_axis:NoTimewarp', ...
        ['%s has no timewarpms in its stored parameters, so the data were ' ...
        'not time warped and there is no common cycle axis.'], label);
end

tw = double(tf.parameters{idx + 1});
tw = tw(:).';

if numel(tw) ~= 3
    error('read_cycle_axis:WarpLandmarkCount', ...
        ['%s has %d warp landmarks. This analysis assumes three, namely ' ...
        'cycle start, extension start and cycle end.'], label, numel(tw));
end
if ~issorted(tw) || tw(end) <= tw(1)
    error('read_cycle_axis:WarpLandmarkOrder', ...
        '%s has warp landmarks that do not increase: %s.', label, mat2str(tw));
end

times    = double(tf.times(:)).';
keepTime = times >= tw(1) & times <= tw(end);

if ~any(keepTime)
    error('read_cycle_axis:EmptyCrop', ...
        '%s has no time samples inside the warp window.', label);
end

axisOut            = struct();
axisOut.pct        = 100 * (times(keepTime) - tw(1)) / (tw(end) - tw(1));
axisOut.warpFrac   = (tw(2) - tw(1)) / (tw(end) - tw(1));
axisOut.timewarpms = tw;
axisOut.keepTime   = keepTime;
axisOut.times      = times;

end
