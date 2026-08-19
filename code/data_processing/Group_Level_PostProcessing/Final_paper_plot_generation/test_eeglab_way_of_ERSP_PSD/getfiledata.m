% function [ fieldData, trialInfo, events ] = getfiledata(fileData, trialselect, v6Flag, chan, func, dataType, indBegin1, indEnd1, indBegin2, indEnd2)

chan = options10{1}; 
func = options10{2}; 
dataType = options10{3}; 
indBegin1 = options10{4}; 
indEnd1 = options10{5}; 
indBegin2 = options10{6}; 
indEnd2 = options10{7};

persistent tmpcache;
persistent hashcode;

if length(chan) > 1
    %    error('This function can only read one channel at a time');
end

% get trial indices
fieldData = [];
trialInfo = [];
events    = [];
subTrials = [];
trials    = [];
if ~isempty(trialselect)
    if isnumeric(trialselect) && isnan(trialselect(1))
        trials = [1:length(fileData.trialinfo)]; % read all trials if NaN
    else
        [trials, events] = std_gettrialsind(fileData.trialinfo, trialselect{:});
        if length(unique(diff(trials))) > 1 && ~v6Flag % speed up access when subsets of trials are selected
            temptrials = [trials(1):trials(end)];
            subTrials  = trials-trials(1)+1;
            trials     = temptrials;
        end
    end
end

% get trial information
trialInfo = fileData.trialinfo(trials);
if ~isempty(subTrials), tmpTrialInfo = tmpTrialInfo(subTrials); end

% scan channels
for index = 1:length(chan)
    allfields   = fieldnames(fileData);
    topoFlag    = ~isempty(findstr(allfields{1}, '_grid'));
    fieldToRead = [ dataType int2str(chan(index)) fastif(topoFlag, '_grid', '') ];
    
    % find trials
    if isempty(trials)
        return;
        % trials = size(fileData.(fieldToRead), ndims(fileData.(fieldToRead))); % not sure what this does
    end

    
    % load data
    warning('off', 'MATLAB:MatFile:OlderFormat');
    if ischar(fileData.(fieldToRead)) % special ERP-image
        try
            fileData.chanlocsforinterp; % isfield does not work because fileData is a MatFile
        catch, error('Missing field in ERPimage STUDY file, try recomputing them');
        end
        chanlocsforinterp = fileData.chanlocsforinterp;
        
        % caching for ERPimage only
        if isequal(hashcode, fileData.(fieldToRead))
            tmpFieldData = tmpcache;
        else
            tmpFieldData = eval( fileData.(fieldToRead) );
            tmpcache = tmpFieldData;
            hashcode = fileData.(fieldToRead);
        end
        tmpFieldData = tmpFieldData(indBegin1:indEnd1,trials);
        if ~isempty(subTrials)
            tmpFieldData = tmpFieldData(:, subTrials); 
            tmpTrialInfo = tmpTrialInfo(subTrials); 
        end
    else
        
        if topoFlag
            tmpFieldData = fileData.(fieldToRead);
            if isempty(trials), tmpFieldData = []; end
        elseif ndims(fileData.(fieldToRead)) == 2
            tmpFieldData = fileData.(fieldToRead)(indBegin1:indEnd1,trials);
            if ~isempty(subTrials), tmpFieldData = tmpFieldData(:, subTrials); end
        else
            tmpFieldData = fileData.(fieldToRead)(indBegin2:indEnd2,indBegin1:indEnd1,trials); % frequencies first here
            if ~isempty(subTrials), tmpFieldData = tmpFieldData(:, :, subTrials); end
        end
    end
    if isfield(fileData, 'events') && ~isempty(fileData.events)
        events = fileData.events(trials);
        if ~isempty(subTrials), events = events(subTrials); end
    end
    warning('on', 'MATLAB:MatFile:OlderFormat');
    
    % average single trials if necessary
    if ~isempty(func)
        tmpFieldData = func(tmpFieldData);
    end
    
    % store data
    if index == 1 && length(chan) == 1
        fieldData = tmpFieldData;
    else
        if index == 1
            fieldData = zeros([ size(tmpFieldData) length(chan) ]);
        end
        if ndims(tmpFieldData) == 2
            fieldData(:,:,index) = tmpFieldData;
        else
            fieldData(:,:,:,index) = tmpFieldData;
        end
    end
end
% end