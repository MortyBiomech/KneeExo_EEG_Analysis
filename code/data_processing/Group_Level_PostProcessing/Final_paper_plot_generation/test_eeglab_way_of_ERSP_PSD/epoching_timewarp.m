%Step 7 epoch to gait events, create
% time warp matrix
%Last modified 1/6/23 
clc; clear; %clearvars -except fileList
FILTERSPEC = '*.set';
TITLE = 'Load EEG dataset';
[fileList, inputFolder] = uigetfile(FILTERSPEC, TITLE,'MultiSelect', 'on');
fileList = cellstr(fileList);
cd(inputFolder)
mydir = inputFolder; %'R:\Ferris-Lab\jacobsen.noelle\Exo Adaptation\Data\processed_data\';
outputFolder= mydir + string(datetime("today", "Format", "uuuu-MM-dd")) + '-Step5-Epoch-Timewarp';

if ~exist(outputFolder, 'dir') %check to see if output folder exists, if not make new one
    mkdir(outputFolder);
end
datasetinfo_folder = outputFolder + '\processed_data'; %main dataset info sheet for study, stores good/bad epochs
if ~exist(datasetinfo_folder, 'dir') %check to see if output folder exists, if not make new one
    mkdir(datasetinfo_folder);
end


%% Startup EEGlab if not already running
current_path = pwd;
cd('D:\Morteza\Toolboxes\EEGLAB\eeglab2025.0.0')
if ~exist('ALLCOM', 'var')
    [ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;
end
datasetinfo = struct([]);
cd(current_path)


%% Loop through files
fin = []; count = 0;
for subi = 2:length(fileList)
    %% Load dataset from file list
    mytic = tic;
    file = fileList(subi);
    
    if ~exist('ALLCOM', 'var')
        eeglab;
    end
    
    cd(inputFolder)
    EEG = pop_loadset('filename',file,'filepath',inputFolder);
    [ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, 0 );
    EEG = eeg_checkset( EEG );
    eeglab redraw;

    subject = regexp(file, '(?<=sub-)[^_]+', 'match', 'once');
    subject = str2double(subject{:});

    % check subject code format (STUDY doesn't like just a number)
    EEG.subject = strcat('S', num2str(subject));
    
    filename = extractBefore(EEG.filename,'.set'); %use for saving datasets later


    %% remove unwanted events
    EEG = pop_selectevent(EEG, 'type', {'FlxS', 'ExtS', 'ExtE'}, 'deleteevents', 'on');
    EEG = eeg_checkset(EEG, 'eventconsistency');


    %% Add trial and cond columns in the event structure
    for e = 1:length(EEG.event)

        nums = str2double(strsplit(EEG.event(e).desc,'_')).';
        if strcmp(EEG.event(e).type, 'boundary')
            EEG.event(e).trial = 'none';
            EEG.event(e).cond = 'none';
        else
            EEG.event(e).trial = nums(end);
            EEG.event(e).cond = nums(2);
        end

    end


    %% Epoching
    EEG = pop_epoch(EEG, {'FlxS'}, [-0.5 3.5], 'newname', 'FlxStartEvents epochs', 'epochinfo', 'yes');
    EEG = eeg_checkset( EEG );
    EEG.setname = strcat(EEG.subject,' Epoched');
    EEG = eeg_checkset(EEG);


    %% Time warping
    events = {'FlxS', 'ExtS', 'ExtE'}; %{'RHS', 'LTO', 'LHS', 'RTO', 'RHS'}; %My previously defined events, I specify which to warp to
    timewarp = make_timewarp(EEG, events, 'baselineLatency',0, ...
        'maxSTDForAbsolute',3,...
        'maxSTDForRelative',3);
    timewarp.warpto = median(timewarp.latencies); % Will be used in newtimef, group analysis uses median of these warpto values in mod_std_precomp_v10_1_5_5a.m
    EEG.timewarp = timewarp;
    median_latency = median(timewarp.latencies(:,3)); %Warping to the median latency of my 5 events
    EEG.timewarp.medianlatency = median_latency;
    
    % Getting rid of bad epochs
    goodepochs = sort([timewarp.epochs]);
    EEG = eeg_checkset(EEG);
    notneeded = [];
    badepochs = setdiff(1:length(EEG.epoch),goodepochs);
    EEG.etc.badepochs = badepochs;
    EEG = pop_select(EEG, 'notrial', badepochs );


    % %% Label pressure conditions
    % EEG = tag_pressure_conditions(EEG, 'P1');




    
    %% label early and late stage
    %use function EEG = tag_splitbelt_subconditions(EEG, beginningString, numEpochs, sub_condition_name)
    %%use function EEG = tag_splitbelt_subconditions(EEG, StartString,begOrEnd,numEpochs,epoch_start_delay,sub_condition_name)
    % EEG = tag_exo_subconditions(EEG, 'noExo','end',-30,0,'noExo');
    % EEG = tag_exo_subconditions(EEG, 'unpow','end',-30,0,'unpow');  
    % EEG = tag_exo_subconditions(EEG, 'pow_1','beginning',30,0,'early adapt');
    % EEG = tag_exo_subconditions(EEG, 'pow_3','end',-30,0,'late adapt');
    % EEG = tag_exo_subconditions(EEG, 'deadapt','beginning',30,0,'early post-adapt');
    % EEG = tag_exo_subconditions(EEG, 'deadapt','end',-30,0,'late post-adapt');   
    % 
    % disp('Sub conditions have been labeled in EEG.event')
    % %fill in empty cells so STUDY is happy later
    % empty_ind = find(cellfun(@isempty,{EEG.event.subcond}));
    % [EEG.event(empty_ind).subcond] = deal('none');
    % empty_ind = find(cellfun(@isempty,{EEG.event.cond}));
    % [EEG.event(empty_ind).cond] = deal('none');
 
    %% save dataset
    EEG.filename = string( strcat(filename,'_epoched') );
    [ALLEEG, EEG, CURRENTSET] = eeg_store( ALLEEG, EEG, CURRENTSET);
    eeglab redraw;
    EEG = eeg_checkset(EEG);

    disp(EEG.filename)
    EEG = pop_saveset(EEG);


    %% save epoch rejection info
    % find event file based on subject
    % cd(datasetinfo_folder)
    % % f = strcat(EEG.subject,'_exo_events');
    % epochreject = zeros(length(EEG.epoch),1);
    % epochreject(badepochs) =1;
    % datasetinfo(subi).filename = EEG.filename;
    % datasetinfo(subi).epoch.epochreject = epochreject; %good IC index
    % %
    % fprintf('\nFinished file %i/%i\n', subi,length(fileList));
    % t_remaining(mytic,fin,count,length(fileList))
    % close all;
    
    clear EEG ALLCOM ALLEEG CURRENTSET

end


