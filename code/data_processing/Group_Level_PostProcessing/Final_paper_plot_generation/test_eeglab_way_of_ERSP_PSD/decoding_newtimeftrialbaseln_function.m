% function PP = newtimeftrialbaseln(PPori, timesout, varargin)
% P = newtimeftrialbaseln(P, timesout, 'baseline', g.baseline, 'basenorm', g.basenorm, 'trialbase', g.trialbase);

% if nargin < 3
%     help newtimefbaseln;
%     return;
% end

PPori = P;
varargin_ggg = {'baseline', g.baseline, 'basenorm', g.basenorm, 'trialbase', g.trialbase};

[ggg timefreqopts ] = finputcheck(varargin_ggg, ...
    {'basenorm'      'string'    {'on','off'} 'off';
    'baseline'      'real'      []          0;
    'trialbase'     'string'    {'on','off','full'} 'off';
    'verbose'       'string'    {'on','off'} 'on';
    }, 'newtimeftrialbaseln', 'ignore');

if ischar(ggg)
    error(ggg);
    return;
end
PP = PPori; if ~iscell(PP), PP = { PP }; end

% ---------------
% baseline length
% ---------------
if size(ggg.baseline,2) == 2
    baseln = [];
    for index = 1:size(ggg.baseline,1)
        tmptime   = find(timesout >= ggg.baseline(index,1) & timesout <= ggg.baseline(index,2));
        baseln = union_bc(baseln, tmptime);
    end
    if isempty(baseln)
        error( [ 'There are no sample points found in the default baseline.' 10 ...
            'This may happen even though data time limits overlap with' 10 ...
            'the baseline period (because of the time-freq. window width).' 10 ...
            'Either disable the baseline, change the baseline limits.' ] );
    end
else
    if ~isempty(find(timesout < ggg.baseline))
         baseln = find(timesout < ggg.baseline); % subtract means of pre-0 (centered) windows
    else baseln = 1:length(timesout); % use all times as baseline
    end
end

for ind = 1:length(PP(:))
    
    P = PP{ind};
    
    % -----------------------------------------
    % remove baseline on a trial by trial basis
    % -----------------------------------------
    if strcmpi(ggg.trialbase, 'on'), tmpbase = baseln;
    else                           tmpbase = 1:size(P,2); % full baseline
    end
    if ~strcmpi(ggg.trialbase, 'off')
        if ndims(P) == 4
            mbase = mean(P(:,:,tmpbase,:),3);
            if strcmpi(ggg.basenorm, 'on')
                mstd = std(P(:,:,tmpbase,:),[],3);
                P = bsxfun(@rdivide, bsxfun(@minus, P, mbase), mstd);
            else P = bsxfun(@rdivide, P, mbase);
            end
        else
            mbase = mean(P(:,tmpbase,:),2);
            if strcmpi(ggg.basenorm, 'on')
                mstd = std(P(:,tmpbase,:),[],2);
                P = (P-repmat(mbase,[1 size(P,2) 1]))./repmat(mstd,[1 size(P,2) 1]); % convert to log then back to normal
            else
                P = P./repmat(mbase,[1 size(P,2) 1]);
                %P = 10 .^ (log10(P) - repmat(log10(mbase),[1 size(P,2) 1])); % same as above
            end
        end
    end
    
    PP{ind} = P;
end
if ~iscell(PPori) 
    PP = PP{1}; 
end