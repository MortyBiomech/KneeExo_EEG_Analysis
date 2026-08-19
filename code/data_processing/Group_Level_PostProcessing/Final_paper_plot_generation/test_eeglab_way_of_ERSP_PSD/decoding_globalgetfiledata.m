% recursive function to load data
% -------------------------------
% function [ measureData, trialInfo, eventVals ] = ...
% decoding_globalgetfiledata(fileData, designvar, options10, trialselect, v6Flag)


% designvar = opt5.designvar;
designvar = designvar(2:end);
options10 = options5;
trialselect = {};
v6Flag = 1;

if length(designvar) == 0
    [ measureData, trialInfo, eventVals ] = getfiledata(fileData, trialselect, v6Flag, options10{:});
    measureData = { measureData };
    trialInfo = { trialInfo };
    eventVals   = { eventVals   };
else
    % scan independent variable values
    if isfield(designvar(1), 'vartype') && strcmpi('continuous', designvar(1).vartype)
        if ~ischar(designvar(1).value), designvar(1).value = ''; end
        trialselect = { trialselect{:} designvar(1).label designvar(1).value };
        [ tmpMeasureData, tmpTrialInfo, tmpEvents ] = globalgetfiledata(fileData, designvar(2:end), options10, trialselect, v6Flag);
        measureData(1,:,:,:) = reshape(tmpMeasureData, [ 1 size(tmpMeasureData) ]);
        trialInfo(  1,:,:,:) = reshape(tmpTrialInfo,   [ 1 size(tmpTrialInfo  ) ]);
        eventVals(  1,:,:,:) = reshape(tmpEvents     , [ 1 size(tmpEvents     ) ]);
    else
        trialselectOri = trialselect;
        for iField = 1:length(designvar(1).value)
            trialselect = { trialselectOri{:} designvar(1).label designvar(1).value{iField} };
            [ tmpMeasureData, tmpTrialInfo, tmpEvents ] = globalgetfiledata(fileData, designvar(2:end), options10, trialselect, v6Flag);
            measureData(iField,:,:,:) = reshape(tmpMeasureData, [ 1 size(tmpMeasureData) ]);
            trialInfo(  iField,:,:,:) = reshape(tmpTrialInfo  , [ 1 size(tmpTrialInfo  ) ]);
            eventVals(  iField,:,:,:) = reshape(tmpEvents     , [ 1 size(tmpEvents     ) ]);
        end
    end
end
% end