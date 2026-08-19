% find indices for selection of measure
% -------------------------------------
function [measureRange, indBegin, indEnd] = indicesselect(measureRange, measureLimits)
indBegin = 1;
indEnd   = length(measureRange);
if ~isempty(measureRange) && ~isempty(measureLimits) && (measureLimits(1) > measureRange(1) || measureLimits(end) < measureRange(end))
    indBegin   = min(find(measureRange >= measureLimits(1)));
    indEnd     = max(find(measureRange <= measureLimits(end)));
    measureRange = measureRange(indBegin:indEnd);
end
end