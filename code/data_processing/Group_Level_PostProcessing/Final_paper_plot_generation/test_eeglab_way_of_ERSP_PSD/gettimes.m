% get time points
% ---------------
function [ timevals, timeindices ] = gettimes(frames, tlimits, timevar, winsize, ntimevar, causal, verbose);
timevect = linspace(tlimits(1), tlimits(2), frames);
srate    = 1000*(frames-1)/(tlimits(2)-tlimits(1));

if isempty(timevar) % no pre-defined time points
    if ntimevar(1) > 0
        % generate linearly space vector
        % ------------------------------
        if (ntimevar > frames-winsize)
            ntimevar = frames-winsize;
            if ntimevar < 0
                error('Not enough data points, reduce the window size or lowest frequency');
            end
            verboseprintf(verbose, ['Value of ''timesout'' must be <= frame-winsize, ''timesout'' adjusted to ' int2str(ntimevar) '\n']);
        end
        npoints = ntimevar(1);
        wintime = 500*winsize/srate;
        if strcmpi(causal, 'on')
             timevals = linspace(tlimits(1)+2*wintime, tlimits(2), npoints);
        else timevals = linspace(tlimits(1)+wintime, tlimits(2)-wintime, npoints);
        end
        verboseprintf(verbose, 'Generating %d time points (%1.1f to %1.1f ms)\n', npoints, min(timevals), max(timevals));
    else
        % subsample data
        % --------------
        nsub     = -ntimevar(1);
        if strcmpi(causal, 'on')
             timeindices = [ceil(winsize+nsub):nsub:length(timevect)];
        else timeindices = [ceil(winsize/2+nsub/2):nsub:length(timevect)-ceil(winsize/2)-1];
        end
        timevals    = timevect( timeindices ); % the conversion at line 741 leaves timeindices unchanged
        verboseprintf(verbose, 'Subsampling by %d (%1.1f to %1.1f ms)\n', nsub, min(timevals), max(timevals));
    end
else
    timevals = timevar;
    % check boundaries
    % ----------------
    wintime = 500*winsize/srate;
    if strcmpi(causal, 'on')
         tmpind  = find( (timevals >= tlimits(1)+2*wintime-0.0001) & (timevals <= tlimits(2)) ); 
    else tmpind  = find( (timevals >= tlimits(1)+wintime-0.0001) & (timevals <= tlimits(2)-wintime+0.0001) ); 
    end
    % 0.0001 account for numerical inaccuracies on opteron computers
    if isempty(tmpind)
        error('No time points. Reduce time window or minimum frequency.');
    end
    if  length(timevals) ~= length(tmpind)
        verboseprintf(verbose, 'Warning: %d out of %d time values were removed (now %3.2f to %3.2f ms) so the lowest\n', ...
            length(timevals)-length(tmpind), length(timevals), timevals(tmpind(1)), timevals(tmpind(end)));
        verboseprintf(verbose, '         frequency could be computed with the requested accuracy\n');
    end
    timevals = timevals(tmpind);
end

% find closet points in data
% --------------------------
timeindices = round(eeg_lat2point(timevals, 1, srate, tlimits, 1E-3));
if length(timeindices) < length(unique(timeindices))
    timeindices = unique_bc(timeindices)
    verboseprintf(verbose, 'Warning: duplicate times, reduce the number of output times\n');
end
if length(unique(timeindices(2:end)-timeindices(1:end-1))) > 1
    verboseprintf(verbose, 'Finding closest points for time variable\n');
    verboseprintf(verbose, 'Time values for time/freq decomposition is not perfectly uniformly distributed\n');
else
    verboseprintf(verbose, 'Distribution of data point for time/freq decomposition is perfectly uniform\n');
end
timevals    = timevect(timeindices);
