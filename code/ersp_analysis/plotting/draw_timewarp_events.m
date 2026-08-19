function draw_timewarp_events(eventTimes, eventLabels, labelY)
% DRAW_TIMEWARP_EVENTS  Mark the time-warp events on the current ERSP axes.
%
%   DRAW_TIMEWARP_EVENTS(EVENTTIMES, EVENTLABELS)
%   DRAW_TIMEWARP_EVENTS(EVENTTIMES, EVENTLABELS, LABELY)
%
%   EVENTTIMES  1-by-N latencies, in the units of the x axis
%   EVENTLABELS 1-by-N cellstr, one label per line; may contain newlines
%   LABELY      y position for the rotated labels (default 140 Hz)
%
% The first and last events get a solid line, interior events a dotted one:
% the outer two are the cycle boundaries, the interior ones are transitions
% within the cycle.
%
% This replaces a block that was duplicated verbatim in two places and that
% positioned its labels by fishing every text object out of the figure with
% FINDOBJ and nudging objects 1, 2 and 3 by hardcoded offsets chosen with
% MOD(textbox,3). That worked only while exactly three events existed and
% only while no other text had been added to the figure first, and it
% silently moved the wrong objects when either assumption broke. Labels are
% now placed directly, by the same call that draws the line.

    if nargin < 3 || isempty(labelY)
        labelY = 140;
    end

    nEvents = numel(eventTimes);
    assert(numel(eventLabels) == nEvents, ...
        'draw_timewarp_events:SizeMismatch', ...
        'Got %d event times but %d labels.', nEvents, numel(eventLabels));

    washold = ishold;
    hold on;

    yl = ylim;
    for k = 1:nEvents
        isBoundary = (k == 1) || (k == nEvents);
        if isBoundary
            style = '-';
            width = 1.0;
        else
            style = ':';
            width = 1.2;
        end

        plot([eventTimes(k) eventTimes(k)], yl, style, ...
            'Color', 'k', 'LineWidth', width, 'HandleVisibility', 'off');

        text(eventTimes(k), labelY, eventLabels{k}, ...
            'Rotation', 90, ...
            'FontSize', 8, ...
            'FontWeight', 'bold', ...
            'FontName', 'Arial', ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'bottom', ...
            'Clipping', 'off');
    end

    ylim(yl);
    if ~washold
        hold off;
    end
end
