% function [PP, baseln, mbase] = newtimefbaseln(PPori, timesout, varargin)

% [P, baseln, mbase] = newtimefbaseln(P, timesout, 'baseline', g.baseline, 'basenorm', g.basenorm, ...
%                                    'verbose', g.verbose, 'powbase', g.powbase, 'trialbase', g.trialbase, 'singletrials','on');


% if nargin < 3
%     help newtimefbaseln;
%     return;
% end


PPori = P;
varargin_g1 = {'baseline', g.baseline, 'basenorm', g.basenorm, ...
               'verbose', g.verbose, 'powbase', g.powbase, ...
               'trialbase', g.trialbase, 'singletrials','on'};



[ g1, timefreqopts ] = finputcheck(varargin_g1, ...
    {'powbase'       'real'      []          NaN;
    'basenorm'      'string'    {'on','off'} 'off';
    'baseline'      'real'      []          0;
    'commonbase'    'string'    {'on','off'} 'off';
    'singletrials'  'string'    {'on','off'} 'on';
    'trialbase',     'string',    {'on', 'off', 'full'}, 'off';
    'verbose',       'string',    {'on', 'off'}, 'on';
    }, 'newtimefbaseln', 'ignore');

if ischar(g1)
    error(g1);
    return;
end
PP = PPori; if ~iscell(PP), PP = { PP }; end

% ---------------
% baseline length
% ---------------
if size(g1.baseline,2) == 2
    baseln = [];
    for index = 1:size(g1.baseline,1)
        tmptime   = find(timesout >= g1.baseline(index,1) & timesout <= g1.baseline(index,2));
        baseln = union_bc(baseln, tmptime);
    end
    if isempty(baseln)
        error( [ 'There are no sample points found in the default baseline.' 10 ...
            'This may happen even though data time limits overlap with' 10 ...
            'the baseline period (because of the time-freq. window width).' 10 ...
            'Either disable the baseline, change the baseline limits.' ] );
    end
else
    if ~isempty(find(timesout < g1.baseline))
         baseln = find(timesout < g1.baseline); % subtract means of pre-0 (centered) windows
    else baseln = 1:length(timesout); % use all times as baseline
    end
end

allMbase = cell(size(PP));
allPmean = cell(size(PP));
for ind = 1:length(PP(:))
    
    P = PP{ind};
    
    % -----------------------
    % compute baseline values
    % -----------------------
    if isnan(g1.powbase(1))
        verboseprintf(g1.verbose, 'Computing the mean baseline spectrum\n');
        if strcmpi(g1.singletrials, 'on') && strcmpi(g1.trialbase, 'off')
            if ndims(P) == 4, Pmean  = mean(P, 4); % average power over trials (channels x freq x time x trials)
            else              Pmean  = mean(P, 3); % average power over trials (freq x time x trials)
            end
        else
            Pmean = P;
        end
        mbase = mean(Pmean(:,baseln,:,:),2);
        mstd  = std(Pmean(:,baseln,:,:),[],2);
    else
        verboseprintf(g1.verbose, 'Using the input baseline spectrum\n');
        mbase    = g1.powbase;
        mstd     = [];
        if size(mbase,1) == 1 % if input was a row vector, flip to be a column
            mbase = mbase';
        end
    end
    
    PP{ind}       = P;
    baselength    = length(baseln);
    allMbase{ind} = mbase;
    allMstd{ind}  = mstd;
end

% ------------------------
% compute average baseline
% ------------------------
if strcmpi(g1.commonbase, 'on')
    meanBaseln = allMbase{1}/length(PP(:));
    meanStd    = allMstd{1}/length(PP(:));
    for ind = 2:length(PP(:))
        meanBaseln = meanBaseln + allMbase{ind}/length(PP(:));
        meanStd    = meanBaseln + allMstd{ ind}/length(PP(:));
    end
    for ind = 1:length(PP(:))
        allMbase{ind} = meanBaseln;
        allMstd{ind}  = meanStd;
    end
end

% -------------------------
% remove baseline (average)
% -------------------------
% original ERSP baseline removal
if ~strcmpi(g1.trialbase, 'on') % full or off
    for ind = 1:length(PP(:))
        if ~isnan( g1.baseline(1) ) && any(~isnan( allMbase{ind}(1) )) && strcmpi(g1.basenorm, 'off')
            PP{ind} = bsxfun(@rdivide, PP{ind}, allMbase{ind});
            % PP{ind} = bsxfun(@rdivide, bsxfun(@minus, PP{ind}, allMbase{ind}), allMstd{ind});
            % ERSP baseline normalized
        elseif ~isnan( g1.baseline(1) ) && ~isnan( allMbase{ind}(1) ) && strcmpi(g1.basenorm, 'on')
            PP{ind} = bsxfun(@rdivide, bsxfun(@minus, PP{ind}, allMbase{ind}), allMstd{ind});
        end
    end
end
for ind = 1:length(allMbase(:))
    if ndims(allMbase{ind}) > 2
        % The baseline is only used for plotting purposes
        % It is different from version EEGLAB v14 (not to be used)
        allMbase{ind} = mean(allMbase{ind},3);
    end
end
mbase = allMbase;
if ~iscell(PPori)
    PP = PP{1}; 
    mbase = allMbase{1};
end

% print
function verboseprintf(verbose, varargin)
    if strcmpi(verbose, 'on')
        fprintf(varargin{:});
    end
end