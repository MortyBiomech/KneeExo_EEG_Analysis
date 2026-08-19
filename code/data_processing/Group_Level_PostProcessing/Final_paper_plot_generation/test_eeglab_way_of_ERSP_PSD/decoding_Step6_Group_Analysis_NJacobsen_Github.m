% Group Analysis
% Create study using EEG datasets and precompute component measures
% Authors: Steve Peterson, UMich
%          Noelle Jacobsen, University of Florida
% Last modified 7/7/2023

%Run after DIPFIT and epoching. This puts all good dipoles into a study for
%clustering and ERSP plotting.

%   NJacobsen notes about time warping!!
%   When using time warping parameters for ERSPS wtih newtimef(), first save structure 
%   created with [timewarp]= make_timewarp() as EEG.timewarp = timewarp;
%   Also save the median latency of your events if you want to warp to the
%   subject median:
%   EEG.timewarp.medianlatency = median(timewarp.latencies(:,:));%Warping to the median latency of my 5 events
%   By default, std_ersp will use the median of all subject's
%   timewarp.latencies(:,:) as 'timewarpms' unless individual subject 
%   warpto is indiciated using 'timewarpms', 'subject tw matrix'
%
%   Took ~5 hrs to run, including ERSP and spectra calculations (~23
%   mins/sub)
% Last updated 1/6/23
%%%%%%%%%%%%%%%%%%%%%%%%%% SET THESE OPTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define input and output path
% If subject code for convenience
RootData = uigetdir('R:\\Ferris-Lab\\jacobsen.noelle\\Exo Adaptation\\','Select STUDY folder'); %folder with datasets that you want to include in study 
eeglabpath = 'C:\Users\jacobsen.noelle\Desktop\eeglab2022.0';
codeRepo = 'R:\Ferris-Lab\jacobsen.noelle\Matlab_Scripts\ExoAdapt-EEG-Processing\';
addpath(genpath(codeRepo))
%subjcode = 'S'; %don't include number
%subjsToAnalyze=[8 9]; % INACTIVE CODE [number array] or 'all'
group='exo-adapt';
dateTime=clock;
studyname=[group '-' datestr(now, 'yyyy-mm-dd') '.study'];

%cond2Analyze={'B1','B2','B3','SB1','P1','SB2','P2'}; %NJacobsen; right now, only choose cond or sessions. Leave the other empty
%cond2Analyze={'B3','SB1_early','SB1late_','SB2_early','SB2late_','P2late_','SB1_perturbation_','SB2_perturbation_'};
cond2Analyze= {};
sessions2Analyze = {}; %NJacobsen
TW = 1; %NJacobsen; use subject's time warp; [1=ON, 0=OFF ]
groupmedian_timewarpms = 1; %NJacobsen; warp each subject's
%                           tw matrix to the entire group's median event
%                           latencies [1=ON], or use individual subject's
%                           median event latencies [0=OFF]. TW must be ON
%                           for this setting to do anything



%Options to choose for this
createStudy=1; %1 - create a study from scratch; 0 - load study
redrawAfterStudyCreated=1; %1 - eeglab redraw and break so can look at study; 0 - continue on
preclust=1; %1 - precluster study; 0 - no preclustering
clust=1; %1 - precluster study; 0 - no preclustering
precomp_nonERSPs=0; %1 - pulls up precompute gui; 0 - no gui
precomp_ersp=1; %1 - precompute ersps; 0 - don't precompute ersps
erspComp='light'; %'light' - quicker computation; 'full' - with usual parameters (takes longer)
showClusterPlotGUI=1; %1 - show cluster plot gui at end; 0 - don't show it (and clear study)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Load files
mergeEpch_path = RootData;

fileList = dir(fullfile(RootData, '*.set'));
% FILTERSPEC = '*.set';
% TITLE = 'Load EEG dataset(s)';
% [fileList RootData] = uigetfile(FILTERSPEC, TITLE,'MultiSelect', 'on');
cd(RootData)
fileList = {fileList.name};
fileList = cellstr(fileList);

%Start up EEGLAB if not running already
if ~exist('ALLCOM')
    addpath(eeglabpath)
    eeglab
end

%Add necessary dependent path
%addpath('C:\Users\jacobsen.noelle\Desktop\eeglab2021.0\plugins\Fieldtrip-lite20210601\external\freesurfer');
%addpath('C:\Users\jacobsen.noelle\Desktop\eeglab2021.0\plugins\Fieldtrip-lite20210601\fileio');

% Edit eeg_options.m file
pop_editoptions( 'option_storedisk', 1, 'option_savetwofiles', 1, ...
    'option_single', 1, 'option_memmapdata', 0, ...
    'option_computeica', 1, 'option_scaleicarms', 1, 'option_rememberfolder', 1);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
global ALLEEG EEG CURRENTSET ALLCOM CURRENTSTUDY STUDY eeglabpath;

%% Load Sets & Create Study
%Use final epoched sets from DIPFIT script (create separate Study for each
%subject
EEG=[]; ALLEEG=[]; CURRENTSET=[]; ALLCOM=[]; CURRENTSTUDY = []; STUDY = [];

%% Create Study
if createStudy==1
    %[STUDY ALLEEG]=pop_study([],[],'gui','on');
    indx=1; 
    for filei=1:length(fileList)
        [STUDY ALLEEG] = std_editset( STUDY, ALLEEG, 'name',studyname,'commands',...
        	{{'index' indx 'load' [fileList{filei}]}...
        	{'inbrain' 'off' 'dipselect' 0.15}},'updatedat','on','savedat','on' );
        indx=indx+1;
        if any([STUDY.cluster.sets] == NaN)
            disp('FOUND NANs')
            disp(fileList{filei})
            return;
        end
        %subjCell{1,frodo}=[subjcode num2str(frodo)];
    end
   % Remove empty cells from subjCell
   % subjCell=subjCell(~cellfun('isempty',subjCell));
    CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
    
     %reject any additional comps based on dipfit info (check for NaNs)
    for subi= 1:length(ALLEEG)
    for compi = 1:length(ALLEEG(subi).reject.gcompreject)
        if ALLEEG(subi).reject.gcompreject(compi)==0 && any( isnan(ALLEEG(subi).dipfit.model(compi).posxyz))
            fprintf('rejecting set %i , comp %i based on dipfit info\n',subi, compi)
            ALLEEG(subi).reject.gcompreject(compi) =1;
        end
    end
    end
     [STUDY ALLEEG] = std_checkset(STUDY, ALLEEG);
    CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];

    %Select good components to use in STUDY
    for set_ind=[1:length(EEG)]
        good_comp_ind = find(EEG(set_ind).reject.gcompreject==0); % 1 = rej, 0= keep 
    [STUDY ALLEEG] = std_editset( STUDY, ALLEEG, 'commands',{{'index' set_ind 'comps' [good_comp_ind] }},'updatedat','on','savedat','on','rmclust','off' );
    end
    [STUDY ALLEEG] = std_checkset(STUDY, ALLEEG);
    CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
%
    

    %Make STUDY design
    if ~isempty(cond2Analyze)
    [STUDY] = std_makedesign(STUDY, ALLEEG, 1, 'variable1','type','values1', cond2Analyze);
    elseif ~isempty(sessions2Analyze)
    [STUDY] = std_makedesign(STUDY, ALLEEG, 1, 'variable1','session','values1',sessions2Analyze,'variable2','','name','STUDY.design 1','pairing1','on','pairing2','on','delfiles','off','defaultdesign','off'); %NJ
    %STUDY = std_makedesign(STUDY, ALLEEG, 1, 'variable1','session','variable2','','name','STUDY.design 1','pairing1','on','pairing2','on','delfiles','off','defaultdesign','off','values1',{'C1' 'C2' 'C4'},'subjselect',{'S03' 'S06' 'S07' 'S08' 'S09' 'S10' 'S11' 'S12' 'S13' 'S3' 'S6' 'S7' 'S8' 'S9'}); %NJ
    end

    
    % Save STUDY
    [STUDY ALLEEG] = pop_savestudy( STUDY, EEG, 'filename',studyname,'filepath',RootData);
    CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];

    if redrawAfterStudyCreated==1
        eeglab redraw
        return;
    end
else
    %Load STUDY (assuming it exists)
     studyname = dir('*.study');
    [STUDY, ALLEEG]=pop_loadstudy('filename',studyname.name,'filepath',RootData);
    CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
end

%% Precompute ERSPs

if precomp_ersp==1
    tic
    if TW==0
        switch erspComp
            case 'full'
                tic
                [STUDY, ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'components','ersp','on','itc','on','erspparams',{'cycles',[3 0.8],'alpha',0.05, 'padratio',2,'savetrials','off','baseline',NaN,'basenorm','on','trialbase','full',}, 'recompute','on');
                toc
            case 'light'
                tic
                %Parameters for quicker computation (still works quite well)
                [STUDY, ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'components','ersp','on','itc','off','erspparams',{'cycles',[3 0.8],'freqs',[3 256],'nfreqs',100,'padration',2,'alpha',NaN,'freqscale','log','savetrials','off','baseline',NaN,'basenorm','on','trialbase','full',}, 'recompute','on');
                toc
            otherwise
                error('Incorrect case for erspComp!');
        end
    elseif TW==1
        %Run ERSPs (timewarped)
        if groupmedian_timewarpms ==1 
            warps=zeros(length(ALLEEG),length(ALLEEG(1,1).timewarp.warpto));%NJ; stored in ALLEEG.timewarp.warpto
        for i=1:length(ALLEEG)
            warps(i,:)=ALLEEG(1,i).timewarp.warpto; %NJ; stored in ALLEEG.timewarp.warpto
        end
        roundNear=50; %round numbers to the closest multiple of this value
        warpingvalues=round(median(warps)/roundNear)*roundNear;
        elseif groupmedian_timewarpms ==0 %use subject specific warpto values
            warpingvalues=zeros(1,length(ALLEEG(1,1).timewarp.warpto)); %%zeros are place holder so subject time warp can be filled in later
        end
            
        switch erspComp
            case 'full'
                tic
                [STUDY ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'components','ersp','on','itc','off','erspparams',{'cycles',[3 0.8],'alpha',0.05, 'padratio',2,'savetrials','off','baseline',NaN,'basenorm','on','trialbase','full','timewarp',[0],'timewarpms', warpingvalues}, 'recompute','on'); %timewarp = 0 as space holder so subject time warp can be filled in later, recompute on/off didnt' affect ERSP computation
                %[STUDY ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'channels','ersp','on','itc','off','erspparams',{'cycles',[3 0.8],'alpha',0.05, 'padratio',2,'savetrials','off','baseline','median latency baseline','timewarp',[0],'timewarpms', warpingvalues}, 'recompute','on'); %timewarp = 0 as space holder so subject time warp can be filled in later, recompute on/off didnt' affect ERSP computation
      
                toc
            case 'light'
                tic
                %Parameters suggested by Makoto
                [STUDY ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'components','ersp','on','itc','off','erspparams',{'cycles',[3 0.8],'freqs',[3 100],'padratio',2,'alpha',NaN,'freqscale','log','savetrials','off','baseline',[0 1200],'basenorm','off','trialbase','full','timewarp',[0],'timewarpms', warpingvalues}, 'recompute','on'); %timewarp = 0 as space holder so subject time warp can be filled in later
                %[STUDY ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'channels','ersp','on','itc','off','erspparams',{'cycles',[3 0.8],'alpha',NaN, 'padratio',2,'savetrials','off','baseline','median latency baseline','timewarp',[0],'timewarpms', warpingvalues}, 'recompute','on'); %timewarp = 0 as space holder so subject time warp can be filled in later, recompute on/off didnt' affect ERSP computation
                toc
            otherwise
                error('Incorrect case for erspComp!');
        end
    end
    toc
end

%% Save STUDY again
[STUDY ALLEEG] = pop_savestudy( STUDY, EEG, 'filename',studyname,'filepath',RootData);
CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];

%%Precompute other component measures
if precomp_nonERSPs==1
%     [STUDY ALLEEG] = pop_precomp(STUDY, ALLEEG,'components');
    [STUDY ALLEEG] = std_precomp(STUDY, ALLEEG, 'components', 'spec','on', 'specparams', {'specmode', 'psd', 'logtrials', 'on', 'freqfac', 8, 'percent', 100, 'freqrange', [2 100], 'overlap', 75});
end

% optimize number of clusters
optimize_num_clusters(ALLEEG)

%% Precluster components
if preclust==1
    [STUDY ALLEEG]=pop_preclust(STUDY,ALLEEG);
end

%% Cluster components
if clust==1

    [STUDY]=pop_clust(STUDY,ALLEEG);
end

[STUDY] = std_dipplot(STUDY, ALLEEG, 'clusters', 'all','groups','on','mode','multicolor'); 

if showClusterPlotGUI==1
    [STUDY]=pop_clustedit(STUDY,ALLEEG); %pulls up cluster visualization interface
else
    clear EEG;  clear EEG_orig; clear ALLEEG; clear CURRENTSET; clear STUDY;
end

%% add labels
STUDY = add_anatomical_labels(STUDY);
%%adjust clusters so there's one cluster per subject
STUDY= oneSubPerCluster(STUDY); %one subject/cluster using lowest IC number

%% Save STUDY final time
[STUDY ALLEEG] = pop_savestudy(STUDY, EEG, 'filename',studyname,'filepath',RootData);
CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];

%% STUDY info
for i = 1:size(STUDY.datasetinfo,2)
tmp(i) = size(STUDY.datasetinfo(i).comps,2);
end
fprintf('Average # brain comps/sub = %i (%i SD)', round(mean(tmp)),round(std(tmp)))

disp('Step 6 finished!')
disp('Data from multiple subjects have been combined into a STUDY.');
disp('Proceed to Step 8 to plot STUDY results.');


function STUDY= oneSubPerCluster(STUDY)
%% weighted average across components in each cluster
cluster_lowestIC = STUDY.cluster;
for CL = 3:length(STUDY.cluster)
        rm_comp_ind =[];
        unique_clus_subs = unique(STUDY.cluster(CL).sets);
            for uc = 1:length(unique_clus_subs)
                x = find(STUDY.cluster(CL).sets == unique_clus_subs(uc));
                index = uc;
                if ~isempty(x)
                    if size(x,2)>1 %if subject appears more than once in cluster
                        rm_comp_ind = [rm_comp_ind, x(2:end)];
                    end
                end
            end

new_outlier_comps = STUDY.cluster(CL).comps(rm_comp_ind);
new_outlier_sets =  STUDY.cluster(CL).sets(rm_comp_ind);
cluster_lowestIC(2).comps = [cluster_lowestIC(2).comps, new_outlier_comps]; %CL 2 is outlier comp
cluster_lowestIC(2).sets = [cluster_lowestIC(2).sets, new_outlier_sets];
cluster_lowestIC(CL).comps(rm_comp_ind) = [];
cluster_lowestIC(CL).sets(rm_comp_ind) = [];
end
fprintf('Subject IC ERSPs consolidated to one subject/cluster using lowest IC number:')
fprintf('\n\tSTUDY.cluster_lowestIC')
  STUDY.cluster_og = STUDY.cluster;
  STUDY.cluster_lowestIC = cluster_lowestIC;
  STUDY.cluster =  STUDY.cluster_lowestIC ;
                        
 fprintf('Original cluster saved in STUDY.cluster_og')
                        
end