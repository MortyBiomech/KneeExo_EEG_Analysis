%% plot ersps from study
% Plots ERSPs with and without significance mask contour
% Inputs:
%       STUDY               - eeglab STUDY structure
%       ALLEEG              - eeglab structure containing all EEG datasets
%       savePath            - main folder to save figures, study design
%                             subfolders will be created automatically (string)
%       plotParams          - structure with the following fields:
%                 design    - STUDY design number (integer)
%                 labels    - put conditions in the order you want them
%                             to be plotted, or else conditions will be
%                             plotting alphabetically. Must match variable
%                             names stored in STUDY.design (1xN cell array where
%                             N is the number of conditions)
%                 figname   - file name for figure without extension
%                             (string)
%                 title     - figure title (string)
%                 legend    - condition names for legend (psd) or subplot
%                             headings (ersps); e.g.
%                             [{'Condition 1',{'Condition 2'}];(1xN cell array where
%                             N is the number of conditions)
%       clusters_to_plot    - vector of cluster indices to plot
%       one_sub_per_cl      - [0|1|2], 1= average one subject per cluster, 2=
%                                       select IC with highest variance, 0=off
%       erspParamOverride   - ersp paramter structure. If empty, default
%                             will use paramters stored in subject .timef
%                             files
% Outputs:
%       ersp_results        - strucuture with ersp from std_erspplot, both
%                             raw and masked, and condtion stats output
%                             p-values
%                             (pcond)
%
% Note: to compare groups manually, you must have a group name assigned in
% STUDY.datasetinfo.group
% Author: Noelle Jacobsen, University of Florida
% Created: 2021, last modified 1/6/23
% Citations: vline from Brandon Kuczenski (2022). hline and vline (https://www.mathworks.com/matlabcentral/fileexchange/1039-hline-and-vline), MATLAB Central File Exchange. Retrieved March 22, 2022.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% function ersp_results = 
% plotERSPSfromSTUDY(STUDY,ALLEEG,savePath,myplotParams,clusters_to_plot,one_sub_per_cl,erspParamOverride, ersp_results)

% ersp_results = plotERSPSfromSTUDY(STUDY, ALLEEG, ...
%     savePath, plotParams(p), clusters_to_plot,one_sub_per_cl, ...
%     erspParamOverride, ersp_results);  

myplotParams = plotParams(p);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%





%% check input parameters
if ~isempty(myplotParams)
    if ~isfield(myplotParams,'design')
        myplotParams.design = STUDY.currentdesign;
    end
    if ~isfield(myplotParams,'figname')
        figname = STUDY.design(design).name;
     else
        figname = myplotParams.figname;
    end
end
changePlotOrder = 1; %1= reorder plots, 0= keep conditions alphabetical
cond_labels = myplotParams.labels;
condstats ='on';        % ['on'|'off]
statsMethod ='perm';    % ['param'|'perm'|'bootstrap']
Alpha = 0.01;           % [NaN|alpha], Significance threshold (0<alpha<<1) ***hard coded this in places to skip certain stats, be careful if changing to diff vaule
mcorrect = 'cluster'; %fdr
groupstats = 'off';
mode = 'fieldtrip';
singletrials = 'off' ;  %['on'|'off'] load single trials spectral data (if available). Default is 'off'.
design = myplotParams.design;
% eventLabels = {'RFC','LFO','LFC','RFO','RFC'}; %labels corresponding to evPlotLines
eventLabels = {'FlxS', 'ExtS', 'ExtE'};
STUDY.etc.erspparams.ersplim = [-inf inf]; %ersp cbar limits
% STUDY.etc.specparams.freqrange = [3 100];
STUDY.etc.specparams.freqrange = [3 130];
plotStuff = 1;

% if design == 17   %TEMP
%     refErspCond = 'SB1 early'; %(string) compute difference ersps against this condition. Subtract full baseline ERSP (difference between baseline and condition. If empty, then don't compare conditions
% elseif design ==24
%     refErspCond = 'SB1 late';
% else
%     refErspCond = 'B3 late';
% end
%
% if design ~= 9 && design ~= 17 && design ~=24 %TEMP
%     refErspCond = {};
% end

if isfield(myplotParams,'refCond') % referenced condition for difference ersps
    refErspCond = myplotParams.refCond;
else
    refErspCond = 'noExo';
end

if isfield(myplotParams,'compareGroups') && strcmp(myplotParams.compareGroups,'on')
    compareGroupsFlag = 1;
else
    compareGroupsFlag = 0;
end

%% flag for option to override ersp params
if exist('erspParamOverride','var') && ~isempty(erspParamOverride)
    erspParamOverride_flag =1;
    myErspParams = erspParamOverride;
else %load existing parameters from timef file
    erspParamOverride_flag =0;
    cd(STUDY.filepath)
    tf_fileList = dir(fullfile(STUDY.filepath, '*timef'));
    load(tf_fileList(1).name,'-mat','parameters');
    myErspParams = parameters;
end

warps=zeros(length(ALLEEG),length(ALLEEG(1,1).timewarp.warpto));%NJ; stored in ALLEEG.timewarp.warpto
for i=1:length(ALLEEG)
    warps(i,:)=ALLEEG(1,i).timewarp.warpto; %NJ; stored in ALLEEG.timewarp.warpto
end
roundNear=50; %round numbers to the closest multiple of this value
warpingvalues=round(median(warps)/roundNear)*roundNear;
evPlotLines = warpingvalues; % vector of event times to mark events on ERSP plots
if size(evPlotLines) ~= size(eventLabels)
    error('Size of evPlotLines and eventLabels do not match. Please check your epoch event labels (line 29)')
end
STUDY.etc.erspparams.timerange = [evPlotLines(1) evPlotLines(end)];
mysgtitle = ['stats method: ',statsMethod,', alpha= ',num2str(Alpha),', mcorrect= ',mcorrect,', mode= ',mode];
refErspCond_ind = strmatch(refErspCond,[STUDY.design(design).variable(1).value]);
if isempty(refErspCond_ind)
    error('Condition for reference ersp not found in STUDY design: %s',refErspCond)
end


%% Stats
% set parameters
% -------------
% subject = '';
comps = [];
% set stastical method
switch mode
    case 'eeglab'
        STUDY = pop_statparams(STUDY, 'condstats', condstats,'method',statsMethod2,'alpha',Alpha,'mcorrect',mcorrect2,'singletrials',singletrials);
    case  'fieldtrip'
        STUDY = pop_statparams(STUDY, 'condstats', condstats,...
            'method',statsMethod,...
            'singletrials',singletrials,'mode',mode,'fieldtripalpha',Alpha,...
            'fieldtripmethod','montecarlo','fieldtripmcorrect',mcorrect);
end
if length(comps) == 1
    stats.condstats = 'off'; stats.groupstats = 'off';
    disp('Statistics cannot be computed for single component');
end

%set ersp params. Settings subbaseline = 'on' will normalize ERSPs using
%average of all conditions in design as baseline

% 'subbaseline' - ['on'|'off'] subtract the same baseline across conditions for ERSP
STUDY = pop_erspparams(STUDY, 'subbaseline','on','timerange',[evPlotLines(1) evPlotLines(end)],'freqrange',[3 130], 'ersplim',[-1.5 1.5]);  


%% loop through clusters
if one_sub_per_cl ==1
    fprintf('Using IC w/ highest variance to reduce to 1 sub/cluster \n')
end

sfields = cell(1,length(clusters_to_plot)); %cell array to store results
%function for parallel loop
fcn = @erspStats;
% parpool('local',2);
try
    for XX = 1:length(clusters_to_plot)
        CL = clusters_to_plot(XX);
        
        if iscell(STUDY.cluster(CL).label)
            mylabel = STUDY.cluster(CL).label{1,1};
        elseif ischar(STUDY.cluster(CL).label)
            mylabel = STUDY.cluster(CL).label;
        end
        fprintf('\nCalculating ERSPs for CL %i , %s\n',CL,mylabel)
        if ~isfield(myplotParams,'figname')
        figname = STUDY.design(design).name;
        else
        figname = myplotParams.figname;
        end
 
        cd(STUDY.filepath)
        %set stastical method
        if compareGroupsFlag
            ogcondstats = condstats;
            condstats = 'off'; %disable here because we recalculate later for each group
        end
        switch mode
            case 'eeglab'
                tmpSTUDY = pop_statparams(STUDY, 'condstats', condstats,'method',statsMethod2,'alpha',Alpha,'mcorrect',mcorrect2,'singletrials',singletrials);
            case  'fieldtrip'
                tmpSTUDY = pop_statparams(STUDY, 'condstats', condstats,...
                    'method',statsMethod,...
                    'singletrials',singletrials,'mode',mode,'fieldtripalpha', Alpha,...
                    'fieldtripmethod','montecarlo','fieldtripmcorrect',mcorrect,'fieldtripnaccu',10000);
        end

        % read and plot ersp data
        if erspParamOverride_flag == 1 %override parameters using myErspParams given in input
            cellArray= {myErspParams{1,2:2:length(myErspParams)}};
            fields = {myErspParams{1,1:2:length(myErspParams)-1}};
            myErspParams = cell2struct(cellArray, fields,2);
            % modified std_erspplot to override ersp parameters
            [tmpSTUDY, allersp, alltimes, allfreqs, pgroup, all_pcond, pinter, events] = ...
                std_erspplot_myparams(tmpSTUDY, ALLEEG,myErspParams, 'clusters',CL,'logfreq','on','subtractsubjectmean','on');
            c = colorbar;
            clim = c.Limits;
        else %use ersp parameters stored in timef (typical use of std_erspplot)
            try
                [tmpSTUDY, allersp, alltimes, allfreqs, pgroup, all_pcond, pinter, events] = ...
                    std_erspplot(tmpSTUDY, ALLEEG, 'clusters',CL,'logfreq','on','subtractsubjectmean','on');
            catch
                STUDY = pop_erspparams(STUDY,'ersplim',[]); %change cbar limits if error is given when there's no sig diff across conditions
                [tmpSTUDY, allersp, alltimes, allfreqs, pgroup, all_pcond, pinter, events] = ...
                    std_erspplot(tmpSTUDY, ALLEEG, 'clusters',CL,'logfreq','on','subtractsubjectmean','on');
                %allersp is a cell {conditions x groups}, with each cell being
                %{freq x time x subject}

                STUDY = pop_erspparams(STUDY,'ersplim',[]); %change back to using ersp min and max for other CLs
            end
            c = colorbar;
            clim = c.Limits;
        end
        close;
        clear tmpSTUDY

        s = struct;
        s.CL_num = CL;
        s.alltimes = alltimes;
        s.allfreqs = allfreqs;
        s.all_pcond = all_pcond;

        cluster_perm_test(1).name = 'all_cond';
        cluster_perm_test(1).freqrange = STUDY.etc.specparams.freqrange;
        cluster_perm_test(1).pcond = all_pcond;

        %reenable stats func
        if compareGroupsFlag
            condstats =  ogcondstats; %enable
        end

        %% average across components in each cluster
        tmpErsp =[];
        if one_sub_per_cl ~= 0
            if one_sub_per_cl == 1
                disp('one subject/cluster by averaging')
            elseif one_sub_per_cl == 2
                disp('one subject/cluster using lowest IC number')
            end
            %remove any subjects not included in study design
            design_subs = STUDY.design(design).cases.value;
            [~, rm_setidx] = setdiff({STUDY.datasetinfo.subject},design_subs);
            idx = ~ismember(STUDY.cluster(CL).sets, rm_setidx);
            CL_sets = STUDY.cluster(CL).sets(idx);
            unique_clus_subs = unique(CL_sets); %set index
            clear rm_setidx design_subs

            for i=1:length(allersp)
                %conslidate subjects that appear more than once in a cluster
                %               if size(unique_clus_subs,2) ~= size(allersp{i, 1},3)
                %                 error('size of ersp and number of subjects in study design don''t match')
                %             end

                for uc = 1:length(unique_clus_subs)
                    x = find(CL_sets == unique_clus_subs(uc));
                    CL_cond_ersp = allersp{i, 1} ;%all ersps in cluster
                    sub_CL_cond_ersp= CL_cond_ersp(:,:,x);%all ersps in cluster belonging to a subject
                    if size(x,2)>1 %if subject appears more than once in cluster
                        % cond(i).ersp(:,:,uc) = mean(sub_CL_cond_ersp,3);

                        if one_sub_per_cl ==1
                            tmpErsp(:,:,uc) = mean(sub_CL_cond_ersp,3);

                        elseif one_sub_per_cl ==2
                            tmpErsp(:,:,uc) = sub_CL_cond_ersp(:,:,1);

                        end
                    else
                        %cond(i).ersp(:,:,uc) = sub_CL_cond_ersp;
                        tmpErsp(:,:,uc) = [sub_CL_cond_ersp];
                    end
                end
                if size(tmpErsp,3) ~= length(unique_clus_subs)%size(cond(i).ersp,3) ~= length(unique_clus_subs)
                    error('Dimensions of ersp do not match number of unique subjects in cluster')
                end
                % allersp{i,1}= cond(i).ersp;
                allersp{i,1}= tmpErsp;
            end
        end

        if compareGroupsFlag
            %rearrange allersp to seperate groups based on label in
            %STUDY.dataset.group
            groupNames = unique({STUDY.datasetinfo.group});
            s.groups = groupNames;
            %find sets in cluster
            %remove any subjects not included in study design
            design_subs = STUDY.design(design).cases.value;
            [~, rm_setidx] = setdiff({STUDY.datasetinfo.subject},design_subs);
            idx = ~ismember(STUDY.cluster(CL).sets, rm_setidx);
            CL_sets = STUDY.cluster(CL).sets(idx);
            setgroups = {STUDY.datasetinfo(CL_sets).group};

            groupersp = {};
            for groupNamei = 1:length(groupNames)
                group = groupNames{1,groupNamei};
                groupi = find(strcmp(setgroups,group));
                for condi = 1:size(allersp,1)
                    condersp = allersp{condi,1}; % [freq x time x sub]
                    groupersp{condi,groupNamei} = condersp(:,:,groupi); %extract subjects by group
                end
            end

            allersp = groupersp; %update allersp = {condition x group}
        end

        %% baseline normalization
%         tmpersp = [];
%         for condi = 1:size(allersp,1)
%             allersp{condi,1} =  real(allersp{condi,1});
%             tmpersp(:,:,:,condi)= mean(allersp{condi,1},2);%avg across time
%         end
%         baseline = mean(tmpersp,4);% avg across conditions

        %% mask invidual ersps- check that it's sig. different from zero
        statsMethod2 = 'perm';    % ['param'|'perm'|'bootstrap']
        mcorrect2 = 'fdr'; %fdr
        mode2 = 'eeglab';
        clear ersp
        %baseidx = find(alltimes>=basetime(1) & alltimes<=basetime(end)); %Take times that are in your baseline
        for condi = 1:size(allersp,1)
            %Calculate and subtract baseline
            %baseline = mean(allersp{c}(:,baseidx,:),2); 
            %average baseline within condition. Your baseline depends on the comparisons you want to make.
            for groupi = 1:size(allersp,2)
                %curr_ersp = allersp{condi,groupi}-repmat(baseline,1,length(alltimes));
                 curr_ersp = allersp{condi,groupi};
                %Bootstrap and significance mask
%                 if ~isnan(Alpha)
%                     %             pboot = bootstat(curr_ersp,'mean(arg1,3);','boottype','shuffle',...
%                     %                 'label','ERSP','bootside','both','naccu',200,...
%                     %                 'basevect',baseidx,'alpha',Alpha,'dimaccu',2);
%                     [pboot, rboot] = bootstat(curr_ersp,'mean(arg1,3);','boottype','shuffle',...
%                         'label','ERSP','bootside','both','naccu',200,...
%                         'alpha',Alpha,'dimaccu',2); 
%                          % ***I'm not sure if this is the best way to compare if a 
%                          % condition is sig different from zero-- "bootstrap"-- 
%                          % which is really only doing permutation-- might overestimate significance
%                     curr_ersp_raw = curr_ersp;
%                     curr_ersp = mean(curr_ersp,3);
%                     curr_maskedersp = curr_ersp;
%                     curr_maskedersp(curr_ersp > repmat(pboot(:,1),[1 size(curr_ersp,2)]) & ...
%                                     curr_ersp < repmat(pboot(:,2),[1 size(curr_ersp,2)])) = 0;
%                     pcond = ones(size(curr_maskedersp));
%                     pcond(curr_ersp > repmat(pboot(:,1),[1 size(curr_ersp,2)]) & ...
%                           curr_ersp < repmat(pboot(:,2),[1 size(curr_ersp,2)])) = 0;
%                     ersp.pcond{condi,groupi} = pcond;
% 
%                 else
                    curr_ersp_raw = curr_ersp;
                    curr_ersp = mean(curr_ersp,3);
                    curr_maskedersp = curr_ersp;
                    ersp.pcond{condi,groupi}= zeros(size(curr_maskedersp));
                    
%                 end

                 %recalculate any sig differences between conditions by
                    %group

                  Alpha = 0.01; % 0.05
                    if compareGroupsFlag
                        [pcond, pgroup, pinter] = feval(fcn, STUDY,{allersp{:,groupi}}');
                         pmask = pcond{1,1}< Alpha; % 1 = n.s. 
                        all_pcond{1,groupi} = double(pmask);
                    end

                ersp.masked{condi,groupi} = curr_maskedersp;
                ersp.mean{condi,groupi} = curr_ersp;
                ersp.raw{condi,groupi} =curr_ersp_raw;
            end
        end

        %% compute difference ersps
        condstats = 'on';
        if ~isempty(refErspCond)
            r = refErspCond_ind; %reference ersp index
            compareCondi = 1:size(allersp,1); %number of conditions
            compareCondi= setdiff(compareCondi,r); %condition indices to compare to reference condition
            % mask differenec ersps- check that it's sig. different from zero
            clear erspDiff
            for c = compareCondi

                for groupi = 1:size(allersp,2)
                    curr_ersp = allersp{c,groupi};
                    ref_ersp = allersp{r,groupi};
                    %[pcond, pgroup, pinter] = erspStats(STUDY,{curr_ersp;ref_ersp});
                    if strcmp(condstats,'on')&& any(any(all_pcond{1,groupi})) %chekc if there are any differences across all conditions
                        [pcond, pgroup, pinter, pval] = feval(fcn, STUDY,{curr_ersp;ref_ersp});
                        pmask = find(pcond{1,1}==1); % 1 = n.s.
                        if iscell(pval)
                            pval = pval{1,1};
                        end
                        pval(pmask) =1;%apply mask
                   
                        cluster_perm_test(end+1).name = ...
                            strcat(STUDY.design(design).variable(1).value(c), ...
                            ' vs. ', STUDY.design(design).variable(1).value(r));
                        cluster_perm_test(end).freqrange = STUDY.etc.erspparams.freqrange;
                        cluster_perm_test(end).pval = pval;
                        cluster_perm_test(end).pcond = pcond{1,1};


                        if any(any(pval<0.01)) %if any pvalues <alpha, continue to next step
                            %determine effect size for clusters
                            [effect] = calc_clust_effectsize({curr_ersp;ref_ersp},alltimes, pval,0);
                            cluster_perm_test(end).effect = effect;
                        end
                    else
                        pcond ={};
                        try
                        pcond{1,1} = ones(size(all_pcond{1,groupi}));
                        catch
                            pcond{1,1} = ones(size(curr_ersp));
                        end
                        
                    end
                    erspDiff.raw{c,groupi} = curr_ersp-ref_ersp;
                    erspDiff.mean{c,groupi} = [mean(curr_ersp-ref_ersp,3)];
                    if strcmp(condstats,'on')
                        mask = pcond{1,1}<Alpha;
                        erspDiff.masked{c,groupi} = [erspDiff.mean{c,groupi}.*mask];
                    end
                    erspDiff.pcond{c, groupi} = pcond{1,1};
                end
            end
        end

        
        %% Reorder conditions
        if changePlotOrder ==1
            mylegend = cond_labels;
            order= [];
            %reorderedData = struct([]);
            %reorderedData_diff= struct([]);
            clear reorderedData reorderedData_diff
            allersp_reordered = {};
            for condi = 1:length(cond_labels)
                try
                    order(1,condi) = find(strcmp(cond_labels{1,condi},[STUDY.design(design).variable(1).value]));
                catch
                    disp('Variable name not found in STUDY.design.variable')

                end
                for groupi = 1:size(ersp.mean,2)
                    [reorderedData.mean{condi,groupi}] = [ersp.mean{order(1,condi),groupi}];
                    [reorderedData.raw{condi,groupi}] = [ersp.raw{order(1,condi),groupi}];
                    [reorderedData.masked{condi, groupi}] = [ersp.masked{order(1,condi),groupi}];
                    if ~isnan(Alpha)
                        [reorderedData.pcond{condi, groupi}] = [ersp.pcond{order(1,condi),groupi}];
                    end
                    allersp_reordered{condi, groupi} = allersp{condi, groupi};
                    if ~isempty(refErspCond) && order(1,condi) ~= refErspCond_ind %big update for second logical
                        reorderedData_diff.raw{condi, groupi} = [erspDiff.raw{order(1,condi),groupi}];
                        reorderedData_diff.mean{condi, groupi} = [erspDiff.mean{order(1,condi),groupi}];
                        reorderedData_diff.masked{condi, groupi} = [erspDiff.masked{order(1,condi),groupi}];
                        if ~isnan(Alpha)
                            reorderedData_diff.pcond{condi, groupi} = [erspDiff.pcond{order(1,condi),groupi}];
                        end
                    end
                end
            end
            erspdata = reorderedData;

            if ~isempty(refErspCond)
                erspDiff = reorderedData_diff;
                s.erspDiff = erspDiff;
                s.compareCondi = compareCondi;
                s.refErspCond = refErspCond;
                %recalculate condition indices to compare to reference
                %condition after reordering
                refErspCond_ind_reordered = strmatch(refErspCond,[cond_labels]);
                 r = refErspCond_ind_reordered; %reference ersp index
                 compareCondi = 1:size(allersp,1); %number of conditions
                compareCondi= setdiff(compareCondi,r); %condition indices to compare to reference condition
            end

            s.allersp = allersp_reordered;
            s.order = cond_labels;
            s.erspdata = erspdata;
            clear reorderedData reorderedData_diff allersp_reordered
        else
            erspdata = ersp;
            s.allersp = allersp;
            s.erspdata = erspdata;
            mylegend = [STUDY.design(design).variable(1).value];
        end

        clear curr_ersp ersp erspboot curr_maskedersp ref_ersp

 %% compare differences between first two groups
 Alpha = 0.01;
 if compareGroupsFlag
     if ~isnan(Alpha)
         STUDY.etc.statistics.paried ='off';
         for condi = compareCondi
             g1ersp = erspDiff.raw{condi,1};
             g2ersp = erspDiff.raw{condi,2};
             [pcond, pgroup, pinter, pval] = feval(fcn, STUDY,{g1ersp;g2ersp});
             erspGroupDiff.mean{condi} = erspDiff.mean{condi,1}-erspDiff.mean{condi,2};
             mask = pcond{1,1}<Alpha;
             erspGroupDiff.masked{condi} = [erspGroupDiff.mean{condi} .*mask];
             erspGroupDiff.pcond{condi}= pcond{1,1};

             pmask = find(pcond{1,1}==1); % 1 = n.s.
             if iscell(pval)
                 pval = pval{1,1};
             end
             pval(pmask) =1;%apply mask

             cluster_perm_test(end+1).name =strcat(groupNames{1,1},'_vs_',groupNames{1,2},'_',cond_labels{condi});
             cluster_perm_test(end).freqrange = STUDY.etc.erspparams.freqrange;
             cluster_perm_test(end).pval = pval;
             cluster_perm_test(end).pcond = pcond{1,1};
         end
     end
     s.erspGroupDiff = erspGroupDiff;
 end
        %% hypothesis driven stats
%         %if there is a sig effect of condition on ersp, then test specific
%         %     % set parameters
%         %     stats.effect = 'marginal';
%         %     stats.groupstats = 'off';
%         %     stats.condstats = 'on';
%         %     stats.singletrials = 'off';
%         %     stats.mode = 'fieldtrip';
%         %     stats.paried = {'on'};
%         %     stats.fieldtrip.naccu = 1000;
%         %     stats.fieldtrip.method = 'motecarlo';
%         %     stats.fieldtrip.alpha = 0.05;
%         %     stats.fieldtrip.mcorrect = 'cluster';
%         %     stats.fieldtrip.clusterparam = "'clusterstatistic','maxsum'";
%         %     stats.fieldtrip.channelneighbor = struct([]);
%         %     stats.fieldtrip.channelneighborparam = "'method','triangulation'";
%         condstats = 'on' ;
%         subject = '';
%         comps = [];
%         %set stastical method
%         switch mode
%             case 'eeglab'
%                 STUDY = pop_statparams(STUDY, 'condstats', condstats,'method',statOpt.statsMethod,'alpha',Alpha,'mcorrect',mcorrect,'singletrials','off');
%             case  'fieldtrip'
%                 STUDY = pop_statparams(STUDY, 'condstats', condstats,...
%                     'method',statsMethod,...
%                     'singletrials','off','mode',mode,'fieldtripalpha',Alpha,...
%                     'fieldtripmethod','montecarlo','fieldtripmcorrect',mcorrect,'fieldtripnaccu',10000);
%         end
%         if length(comps) == 1
%             stats.condstats = 'off'; stats.groupstats = 'off';
%             disp('Statistics cannot be computed for single component');
%         end
% 
%         stats = STUDY.etc.statistics;
%         stats.fieldtrip.channelneighbor = struct([]); % assumes one channel or 1 component
%         if isempty(STUDY.design(STUDY.currentdesign).variable)
%             stats.paired = { };
%         else
%             stats.paired = { STUDY.design(STUDY.currentdesign).variable(:).pairing };
%         end
% 
% 
%         sigcondeffect = any(any(all_pcond{1,1}< Alpha)); %check for any sig dif accross all conditions
%         testersp = erspdata.raw;
%         if sigcondeffect
%             %hypotheses pairs-
%             ref_cond = myplotParams.refCond;
%             test_cond = myplotParams.testCond;
%             refi = find(strcmpi(myplotParams.labels,ref_cond));
%             testi = find(strcmpi(myplotParams.labels,test_cond));
%             conditions2compare = [testi refi];
% 
%             %test specific hypotheses
%             if CL == 7 || CL ==10 || CL ==3 || CL ==13 % Cingulate clusters
%                 % theta
%                 stats_freq_range = [4 7];
%                 freqi = find(allfreqs>=stats_freq_range(1) & allfreqs<=stats_freq_range(2));
%                 ersp_all_tmp = {};
%                 for condi = 1:2
%                     tmp= testersp{conditions2compare(condi),1};
%                     ersp_all_tmp{condi,1} = squeeze(mean(tmp(freqi,:,:),1)); %average in selected frq range, [time x subject]
%                 end
% 
%                 % run cluster-based perm test
%                 [pcond, pgroup, pinter, statscond, statsgroup, statsinter, pval] = std_stat_clusterpval(ersp_all_tmp, stats);
% 
%                 pmask = find(pcond{1,1}==1); % 1 = n.s.
%                 if iscell(pval)
%                     pval = pval{1,1};
%                 end
%                 pval(pmask) =1;%apply mask
% 
%                     cluster_perm_test(end+1).name = 'theta';
%                     cluster_perm_test(end).freqrange = stats_freq_range;
%                     cluster_perm_test(end).pval = pval;
%                     cluster_perm_test(end).pcond = pcond{1,1};
% 
%                 if any(any(pval<0.05)) %if any pvalues <alpha, continue to next step
%                     %determine effect size for cluster with lowest p-val
%                     [effect] = calc_clust_effectsize(ersp_all_tmp,alltimes, pval,0);
%                     cluster_perm_test(end).effect = effect;
%                 end
% 
%                 %plot
%                 if plotStuff
%                     mean_ersp_all_tmp(1,:) = mean(ersp_all_tmp{1,1},2); %avg across subjects
%                     mean_ersp_all_tmp(2,:)= mean(ersp_all_tmp{2,1},2);
%                     plotopt = {'highlightmode','bottom','plotmean','off','ylim',[], 'xlabel','','ylabel',...
%                         'Mean Power (dB)','legend',mylegend};
%                     fh = figure;
%                     shadedErrorBar(alltimes, ersp_all_tmp{1,1}', {@mean,@std}, 'lineprops',  {'-','Color',[myplotParams.colors{1,refi}],'LineWidth',2},'patchSaturation',0.1)
%                     hold on;
%                     shadedErrorBar(alltimes,  ersp_all_tmp{2,1}', {@mean,@std}, 'lineprops',  {'-','Color',[myplotParams.colors{1,testi}],'LineWidth',2},'patchSaturation',0.1)
%                     plotcurve_colors(alltimes,mean_ersp_all_tmp, 'colors',...
%                         {[myplotParams.colors{1,refi}],...
%                         [myplotParams.colors{1,testi}]}, 'maskarray',...
%                         double(cluster_perm_test(end).pcond)', ...
%                         plotopt{1:end}, 'title',['CL',num2str(CL),'_',mylabel,': Theta band ERSP']);
% 
%                     fh = formatFig(fh,evPlotLines,eventLabels);
%                     legend([{mylegend{conditions2compare}},'']);  
%                     %%
%                     savethisfig(fh,[figname,'_CL',num2str(CL),'_',mylabel,'_theta.png'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\png\'],'png')
%                     savethisfig(fh,[figname,'_CL',num2str(CL),'_',mylabel,'_theta.fig'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\fig\'],'fig')
%                     savethisfig(fh,[figname,'_CL',num2str(CL),'_',mylabel,'_theta.svg'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\svg\'],'svg')
%                     close;
%                 end
%             end
% 
% 
%             if CL == 6 || CL ==8 || CL ==14 %PPC, SMI
%                 % alpha
%                 stats_freq_range = [8 12];
%                 freqi = find(allfreqs>=stats_freq_range(1) & allfreqs<=stats_freq_range(2));
%                 ersp_all_tmp = {};
%                 for condi = 1:2
%                     tmp= testersp{conditions2compare(condi),1};
%                     ersp_all_tmp{condi,1} = squeeze(mean(tmp(freqi,:,:),1)); %average in selected frq range, [time x subject]
%                 end
%                 % run cluster-based perm test
%                 [pcond, pgroup, pinter, statscond, statsgroup, statsinter, pval] = std_stat_clusterpval(ersp_all_tmp, stats);
% 
%                 pmask = find(pcond{1,1}==1); % 1= n.s.
%                 if iscell(pval)
%                     pval = pval{1,1};
%                 end
%                 pval(pmask) =1;%apply mask
%                   cluster_perm_test(end+1).name = 'alpha';
%                     cluster_perm_test(end).freqrange = stats_freq_range;
%                     cluster_perm_test(end).pval = pval;
%                     cluster_perm_test(end).pcond = pcond{1,1};
% 
%                 if any(pval<0.05) %if any pvalues <alpha, continue to next step
%                     %determine effect size for cluster with lowest p-val
%                     [effect] = calc_clust_effectsize(ersp_all_tmp,alltimes, pval,0);
% 
%                   
%                     cluster_perm_test(end).effect = effect;
%                 end
% 
%                 %plot
%                 if plotStuff
%                     mean_ersp_all_tmp(1,:) = mean(ersp_all_tmp{1,1},2); %avg across subjects
%                     mean_ersp_all_tmp(2,:)= mean(ersp_all_tmp{2,1},2);
%                     plotopt = {'highlightmode','bottom','plotmean','off','ylim',[], 'xlabel','','ylabel',...
%                         'Mean Power (dB)','legend',mylegend};
%                     fh = figure;
%                     shadedErrorBar(alltimes, ersp_all_tmp{1,1}', {@mean,@std}, 'lineprops',  {'-','Color',[myplotParams.colors{1,refi}],'LineWidth',2},'patchSaturation',0.1)
%                     hold on;
%                     shadedErrorBar(alltimes,  ersp_all_tmp{2,1}', {@mean,@std}, 'lineprops',  {'-','Color',[myplotParams.colors{1,testi}],'LineWidth',2},'patchSaturation',0.1)
%                     plotcurve_colors(alltimes,mean_ersp_all_tmp, 'colors',...
%                         {[myplotParams.colors{1,refi}],...
%                         [myplotParams.colors{1,testi}]}, 'maskarray', ...
%                         double(cluster_perm_test(end).pcond)',...
%                         plotopt{1:end}, 'title',['CL',num2str(CL),'_',mylabel,': Alpha band ERSP']);
% 
%                     fh = formatFig(fh,evPlotLines,eventLabels);
%                     legend([{mylegend{conditions2compare}},'']); 
% 
%                     savethisfig(fh,[figname,'_CL',num2str(CL),'_',mylabel,'_alpha.png'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\png\'],'png')
%                     savethisfig(fh,[figname,'_CL',num2str(CL),'_',mylabel,'_alpha.fig'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\fig\'],'fig')
%                     savethisfig(fh,[figname,'_CL',num2str(CL),'_',mylabel,'_alpha.svg'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\svg\'],'svg')
%                     close;
%                 end
% 
% 
%                 clear pmask pval pcond effect
%                 stats_freq_range = [13 30];
%                 freqi = find(allfreqs>=stats_freq_range(1) & allfreqs<=stats_freq_range(2));
%                 ersp_all_tmp = {};
%                 for condi = 1:2
%                     tmp= testersp{conditions2compare(condi),1};
%                     ersp_all_tmp{condi,1} = squeeze(mean(tmp(freqi,:,:),1)); %average in selected frq range, [time x subject]
%                 end
%                 % run cluster-based perm test
%                 [pcond, pgroup, pinter, statscond, statsgroup, statsinter, pval] = std_stat_clusterpval(ersp_all_tmp, stats);
% 
%                 pmask = find(pcond{1,1}==1); % 1 = n.s.
%                 if iscell(pval)
%                     pval = pval{1,1};
%                 end
%                 pval(pmask) =1;%apply mask
% 
%                     cluster_perm_test(end+1).name = 'beta';
%                     cluster_perm_test(end).freqrange = stats_freq_range;
%                     cluster_perm_test(end).pval = pval;
%                     cluster_perm_test(end).pcond = pcond{1,1};
% 
%                 if any(pval<0.05) %if any pvalues <alpha, continue to next step
%                     %determine effect size for cluster with lowest p-val
%                     [effect] = calc_clust_effectsize(ersp_all_tmp,alltimes, pval,0);
% 
%                     cluster_perm_test(end).effect = effect;
%                 end
% 
%                 %plot
%                 if plotStuff
%                     mean_ersp_all_tmp(1,:) = mean(ersp_all_tmp{1,1},2); %avg across subjects
%                     mean_ersp_all_tmp(2,:)= mean(ersp_all_tmp{2,1},2);
%                     plotopt = {'highlightmode','bottom','plotmean','off','ylim',[], 'xlabel','','ylabel',...
%                         'Mean Power (dB)','legend',mylegend};
%                     fh = figure;
%                     shadedErrorBar(alltimes, ersp_all_tmp{1,1}', {@mean,@std}, 'lineprops',  {'-','Color',[myplotParams.colors{1,refi}],'LineWidth',2},'patchSaturation',0.1)
%                     hold on;
%                     shadedErrorBar(alltimes,  ersp_all_tmp{2,1}', {@mean,@std}, 'lineprops',  {'-','Color',[myplotParams.colors{1,testi}],'LineWidth',2},'patchSaturation',0.1)
%                     plotcurve_colors(alltimes,mean_ersp_all_tmp, 'colors',...
%                         {[myplotParams.colors{1,refi}],...
%                         [myplotParams.colors{1,testi}]}, 'maskarray', ...
%                         double(cluster_perm_test(end).pcond)', ...
%                         plotopt{1:end}, 'title',['CL',num2str(CL),'_',mylabel,': Beta band ERSP']);
% 
%                     fh = formatFig(fh,evPlotLines,eventLabels);
%                     legend([{mylegend{conditions2compare}},'']);     
%                     savethisfig(fh,[figname,'_CL',num2str(CL),'_',mylabel,'_beta.png'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\png\'],'png')
%                     savethisfig(fh,[figname,'_CL',num2str(CL),'_',mylabel,'_beta.fig'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\fig\'],'fig')
%                     savethisfig(fh,[figname,'_CL',num2str(CL),'_',mylabel,'_beta.svg'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\svg\'],'svg')
%                     close;
%                 end
%             end
%             clear fh
%         end
% 

      s.cluster_perm_test = cluster_perm_test;
        %% plot ERSPs
        if plotStuff
            %make a different figure for each group
            for groupi = 1:size(erspdata.mean,2)
                data = [];
                for condi = 1:size(erspdata.mean,1)
                    data = [data, reshape(mean(erspdata.mean{condi,groupi},3).',1,[])];
                end
                IQR = iqr(data); %interquartile range
                Q1 = quantile(data,0.25);
                myMin = round(Q1-1.5*IQR,1);
                erspdata_clim = [myMin myMin*(-1)];

                % find appropriate plot limits for ersp difference data
                if ~isempty(refErspCond)
                    data = [];
                    for condi = 1:size(erspDiff.mean,1)
                        data = [data, reshape(mean(erspDiff.mean{condi,groupi},3).',1,[])];
                    end
                    IQR = iqr(data); %interquartile range
                    Q1 = quantile(data,0.25);
                    myMin = round(Q1-1.5*IQR,1);
                    erspDiff_clim = [myMin myMin*(-1)];
                end


                numCond = size(erspdata.mean,1);
                if compareGroupsFlag
                numGroupMembers = num2str(size(groupersp{condi,groupi},3)); %num of subjecsts in groups
                end
                %% ============================================================
                %                   Plotting
                % ============================================================
                % Now plot the ersps
                %1) all conditions, unmasked

                figure('name',['Cls ' num2str(CL) ' ' mylabel],'InvertHardcopy', 'off', 'PaperType', 'a2', 'PaperOrientation', 'landscape');
                fig_width = 1.75*(numCond+1); %previously 10 for 7 cond, adjusting to so figure isnt' stretched for 1 condition
                fig_height = fig_width/2.857;% previously 3.5 for 7 cond, 2.85 will maintain ratio
                % set(gcf,'PaperUnits','inches','Units','Inches','PaperPosition',[0 0 fig_width  fig_height],'Position',[5 5  fig_width fig_height ],'Units','Inches');
                set(gcf,'PaperUnits','inches','Units','Inches','PaperPositionMode','auto','Position',[0 0 fig_width*2 fig_height*2 ],'Units','Inches');
                clim = erspdata_clim;

                for condi = 1:size(erspdata.mean,1)+1
                    fh(condi).h = subplot(1,numCond+1,condi);

                    if condi < numCond+1
                        contourf(alltimes, allfreqs, erspdata.mean{condi,groupi},200,'linecolor','none')
                    elseif condi == numCond+1
                        contourf(alltimes, allfreqs, all_pcond{1,groupi},200,'linecolor','none')
                    end
                    hold on;

                    % set(gca,'clim',clim,'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
                    set(gca,'clim',clim,'xlim',[alltimes(1) alltimes(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
                    set(gcf,'Colormap', calldefinedcolormap(), 'Color',[1 1 1]);

                    % resize plot to fit title
                    pos = fh(condi).h.Position;
                    fh(condi).h.Position =[pos(1)-0.04 pos(2)*1.8 pos(3) pos(4)*.7];


                    if condi == numCond +1
                        pos = fh(condi).h.Position;
                        c = colorbar('Position',[pos(1)+pos(3)+0.01  pos(2) 0.012 pos(4)]);
                        c.Limits = clim;
                        % make the Ticks symmetric
                        maxAbs = max(abs(c.Ticks));
                        % If maxAbs isn't in v, append it to make symmetric
                        if ~ismember(maxAbs, c.Ticks)
                            c.Ticks = sort([c.Ticks maxAbs]); % sort if you want increasing order
                        end
                        % hL = ylabel(c,[{'\Delta Power'};{'WRT'};{myplotParams.legend{1,refErspCond_ind}};{'(dB)'}],...
                        %     'fontweight','bold','FontName','Arial','FontSize',8,'Rotation',0);
                        hL = ylabel(c,[{'Baseline-Corrected Power (dB)'}],...
                            'fontweight','bold','FontName','Arial','FontSize', 14,'Rotation',90);
                        hL.Position(1) = 4;
                        hL.Position(2) = 0;
                    end

                    xlimits = xlim;
                    %         set(gca,'XTick',[evPlotLines(1:4) xlimits(1,2)],...
                    %             'XTickLabel',{'0','','50','','100'},'ytick', [4 8 13 30 50 100]);
                    % set(gca,'XTick',[evPlotLines],...
                    %     'XTickLabel',{'0','','50','','100'},'ytick', [4 8 13 30 50 100],'fontsize',10);
                    set(gca,'XTick',[alltimes(1) evPlotLines(2) alltimes(end)],...
                        'XTickLabel',{'0', '50', '100'}, 'ytick', [4 8 14 30 60 120],'fontsize',10);
                    xtickangle(45)
                    h = gca;
                    h.XRuler.TickLabelGapOffset = -2; % it was -2

                    % ylabel
                    if condi == 1
                        ylh = ylabel(sprintf('Frequency\n(Hz)'),'fontsize',16,'fontweight','bold','FontName','Arial');
                        ylh.Position(1) = ylh.Position(1)-250; % it was -450 I changed it!
                    else
                        set(gca,'YTickLabel',[]);
                        %ylabel('');
                    end

                    % if condi ~=1
                    %     xlabel('');
                    % else
                    %     xlh = xlabel('Gait Cycle (%)','Fontsize',16,'fontweight','bold');
                    %     xlh.Position(2) = 2;
                    % end
                    xlh = xlabel('Cycle (%)','Fontsize',16,'fontweight','bold');
                    xlh.Position(2) = 1.8;
                    

                    set(gca,'Fontsize',16);
                    if  condi == numCond + 1
                        T = title('RM-ANOVA (p<0.01)','FontSize',16, ...
                            'FontName', 'Arial', 'FontWeight', 'bold', 'FontAngle', 'normal');
                        T.Position(2) = T.Position(2)+100;
                    else
                        T = title(myplotParams.legend{condi},'FontSize',16);
                        T.Position(2) = T.Position(2)+100;
                    end

                    evPlotLines_correct = [alltimes(1) evPlotLines(2) alltimes(end)];
                    eventLabels_new = {sprintf('FlxS'), sprintf('FlxE\nExtS'), sprintf('ExtE')};
                    % add event lines from time warp
                    if ~isempty(evPlotLines_correct)
                        hold on;
                        for L = 1:length(evPlotLines_correct)
                            if L == 1 || L == length(evPlotLines_correct)
                                %v = vline(evPlotLines(L),'-k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1); %solid line
                                v = vline(evPlotLines_correct(L),'-k', eventLabels_new{1,L}); set(v,'LineWidth',1); %solid line
                            else
                                %v = vline(evPlotLines(L),':k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1.2);
                                v = vline(evPlotLines_correct(L),':k',eventLabels_new{1,L}); set(v,'LineWidth',1.2);
                            end
                        end
                        %             text([evPlotLines]-80,140*ones([1,length(evPlotLines)]),eventLabels,'VerticalAlignment','top')
                        % adjust event text box position
                        H = findobj(gcf);
                        tb = findobj(H,'Type','text');

                        for textbox = 1:3 % 1:size(tb,1)
                            if     mod(textbox, 3) == 1
                                pos = tb(textbox).Position;
                                tb(textbox).Position = [pos(1)+30 140 0];
                                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                                set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                            elseif mod(textbox, 3) == 2
                                pos = tb(textbox).Position;
                                tb(textbox).Position = [pos(1)-10 140 0];
                                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                                set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                            elseif mod(textbox, 3) == 0
                                pos = tb(textbox).Position;
                                tb(textbox).Position = [pos(1)+15 140 0];
                                set(tb(textbox),'Rotation',90) % rotate 90 degrees
                                set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                            end
                            % pos = tb(textbox).Position;
                            % tb(textbox).Position = [pos(1) 150 0];
                            % set(tb(textbox),'Rotation',90) % rotate 90 degrees
                            % set(tb(textbox),'FontSize',8) 
                        end
                        hold off;
                    end
                    set(gca,'FontName','Arial','box','on','YMinorTick','off');
                end

                % set figure settings
                set(gcf,'Colormap', calldefinedcolormap2(), ...
                    'Color',[1 1 1]);

                %% save figure
                
                % if compareGroupsFlag
                %     sgtitle([mylabel,'-',groupNames{groupi},' group (n = ',numGroupMembers,')'],'interpreter','none')
                %     figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',groupNames{groupi},'Group_',statsMethod2,num2str(Alpha),'_',mcorrect2,'_',mode2);
                % else
                %     figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',statsMethod2,num2str(Alpha),'_',mcorrect2,'_',mode2);
                % end

                if compareGroupsFlag
                    sgtitle([mylabel,'-',groupNames{groupi},' group (n = ',numGroupMembers,')'],'interpreter','none')
                    figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',groupNames{groupi},'Group_',statsMethod2,num2str(Alpha),'_',mcorrect2,'_',mode2);
                else
                    figname = strcat(STUDY_title,'_ERSP_', myplotParams.figname, '_CL', num2str(CL),'_', statsMethod, num2str(Alpha),'_', mcorrect,'_',mode);
                end

                savethisfig(gcf, strcat(figname,'.png'), ...
                    [savePath,'\ERSP\',myplotParams.figname,'\all_cond\png'],'png')
                savethisfig(gcf, strcat(figname,'.fig'), ...
                    [savePath,'\ERSP\',myplotParams.figname,'\all_cond\fig'],'fig')
                savethisfig(gcf, strcat(figname,'.svg'), ...
                    [savePath,'\ERSP\',myplotParams.figname,'\all_cond\svg'],'svg')

%                 if ~exist([savePath,'\ERSP\',myplotParams.figname,'\all_cond\dpdf\'], 'dir') %check
%                     mkdir([savePath,'\ERSP\',myplotParams.figname,'\all_cond\dpdf\'])
%                 end
                %orient(gcf,'landscape')
%                 set(gcf,'PaperUnits','inches','Units','Inches','PaperPosition',[0 0 10 3.5],'Position',[0 0 10 3.5]);

               % print([savePath,'\ERSP\',myplotParams.figname,'\all_cond\dpdf\',figname,'.dpdf'], '-dpdf', '-painters','-bestfit') % Makoto's print method. On Linux.
                close;

%                 %% 2) all conditions, masked
%                 figure('name',['Cls ' num2str(CL) ' ' mylabel],'InvertHardcopy', 'off', 'PaperType', 'a2', 'PaperOrientation', 'landscape');
%                 fig_width = 1.25*(numCond+1); %previously 10 for 7 cond, adjusting to so figure isnt' stretched for 1 condition
%                 fig_height = fig_width/2.857;% previously 3.5 for 7 cond, 2.85 will maintain ratio
%                 %set(gcf,'PaperUnits','inches','Units','Inches','PaperPosition',[0 0 fig_width  fig_height],'Position',[5 5  fig_width fig_height ],'Units','Inches');
%                 set(gcf,'PaperUnits','inches','Units','Inches','PaperPositionMode','auto','Position',[0 0 fig_width*2 fig_height*2 ],'Units','Inches');
%                 clim = erspdata_clim;
%                 %tiledlayout(1,length(erspdata)+1)
%                 for condi =1:size(erspdata.mean,1)+1
%                     fh(condi).h = subplot(1,numCond+1,condi);
%                     %nexttile;
%                     if condi < numCond+1
%                         contourf(alltimes, allfreqs, erspdata.mean{condi,groupi},200,'linecolor','none')
%                         hold on;
%                         %overlay transparent masked ersp, create array the same size as ersp — Use a different transparency value for each image element.
%                         faceAlpha = ones(size(erspdata.pcond{condi,groupi}))*0.5; %alpha range [0-1] where 0 is fully transparent and 1 = fully opaque
%                         faceAlpha (erspdata.pcond{condi,groupi} ==1) = 0; %set sig regions in this MASK to be fully TRANSPARENT so we can see underlying sig regions
%                         imagesc(alltimes,allfreqs,erspdata.masked{condi,groupi},'AlphaData',faceAlpha)
% 
%                     elseif condi == numCond+1
%                         contourf(alltimes, allfreqs, all_pcond{1,groupi},200,'linecolor','none')
%                     end
%                     hold on;
% 
%                     set(gca,'clim',clim,'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
%                     set(gcf,'Colormap', calldefinedcolormap3(), ...
%                         'Color',[1 1 1]);
% 
%                     %resize plot to fit title
%                     pos = fh(condi).h.Position;
%                     fh(condi).h.Position =[pos(1)-0.04 pos(2)*1.8 pos(3) pos(4)*.7];
% 
% 
%                     if condi ==numCond +1
%                         pos = fh(condi).h.Position;
%                         c = colorbar('Position',[pos(1)+pos(3)+0.01  pos(2) 0.012 pos(4)]);
%                         c.Limits = clim;
%                         hL = ylabel(c,[{'\Delta Power'};{'WRT'};{myplotParams.legend{1,refErspCond_ind}};{'(dB)'}],...
%                             'fontweight','bold','FontName','Arial','FontSize',8,'Rotation',0);
%                         hL.Position(1) = 6;
%                         hL.Position(2) = 0.2;
%                     end
% 
%                     xlimits = xlim;
%                     %         set(gca,'XTick',[evPlotLines(1:4) xlimits(1,2)],...
%                     %             'XTickLabel',{'0','','50','','100'},'ytick', [4 8 13 30 50 100]);
%                     set(gca,'XTick',[evPlotLines],...
%                         'XTickLabel',{'0','','50','','100'},'ytick', [4 8 13 30 50 100],'fontsize',10);
%                     xtickangle(45)
%                     h = gca;
%                     h.XRuler.TickLabelGapOffset = -2;
% 
%                     %ylabel
%                     if condi ==1
%                         ylh = ylabel(sprintf('Frequency\n(Hz)'),'fontsize',16,'fontweight','bold','FontName','Arial');
%                         ylh.Position(1) = ylh.Position(1)-450;
% 
%                     else
%                         set(gca,'YTickLabel',[]);
%                         %ylabel('');
%                     end
% 
%                     if condi ~=1
%                         xlabel('');
%                     else
%                         xlh = xlabel('Gait Cycle (%)','Fontsize',16,'fontweight','bold');
%                         xlh.Position(2) = 2;
%                     end
% 
%                     set(gca,'Fontsize',16);
%                     if  condi == numCond+1
%                         T = title('p<0.05','FontSize',10);
%                         T.Position(2) = T.Position(2)+100;
%                     else
%                         T = title(myplotParams.legend{condi},'FontSize',10);
%                         T.Position(2) = T.Position(2)+100;
%                     end
% 
%                     %add event lines from time warp
%                     if ~isempty(evPlotLines)
%                         hold on;
%                         for L = 1:length(evPlotLines)
%                             if L ==1 || L==length(evPlotLines)
%                                 %v = vline(evPlotLines(L),'-k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1); %solid line
%                                 v = vline(evPlotLines(L),'-k',eventLabels{1,L}); set(v,'LineWidth',1); %solid line
%                             else
%                                 %v = vline(evPlotLines(L),':k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1.2);
%                                 v = vline(evPlotLines(L),':k',eventLabels{1,L}); set(v,'LineWidth',1.2);
%                             end
%                         end
%                         %             text([evPlotLines]-80,140*ones([1,length(evPlotLines)]),eventLabels,'VerticalAlignment','top')
%                         %adjust event text box position
%                         H=findobj(gcf);
%                         tb = findobj(H,'Type','text');
% 
%                         for textbox = 1:size(tb,1)
%                             pos = tb(textbox).Position;
%                             tb(textbox).Position = [pos(1) 100 0];
%                             set(tb(textbox),'Rotation',90)
%                             set(tb(textbox),'FontSize',8) %rotate 90 degrees
%                         end
%                         hold off;
%                     end
% 
%                     %         set(gca,'Fontsize',14,'fontweight','bold','FontName','Arial','box','on','YMinorTick','off');
%                     set(gca,'FontName','Arial','box','on','YMinorTick','off');
% 
%                 end
% 
%                 % set figure settings
%                 set(gcf,'Colormap', calldefinedcolormap4(), ...
%                     'Color',[1 1 1]);
% 
%                 %% save figure
%                 if compareGroupsFlag
%                     sgtitle([mylabel,'-',groupNames{groupi},' group (n = ',numGroupMembers,')'],'interpreter','none')
%                     figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',groupNames{groupi},'Group_',statsMethod2,num2str(Alpha),'_',mcorrect2,'_',mode2,'_masked');
%                 else
%                     figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',statsMethod2,num2str(Alpha),'_',mcorrect2,'_',mode2,'_masked');
%                 end
% 
%                 savethisfig(gcf,[figname,'.png'],[savePath,'\ERSP\',myplotParams.figname,'\all_cond\png'],'png')
%                 savethisfig(gcf,[figname,'.fig'],[savePath,'\ERSP\',myplotParams.figname,'\all_cond\fig'],'fig')
%                 savethisfig(gcf,[figname,'.svg'],[savePath,'\ERSP\',myplotParams.figname,'\all_cond\svg'],'svg')
%                 orient(gcf,'landscape')
%                 print([savePath,'\ERSP\',myplotParams.figname,'\all_cond\dpdf\',figname,'.dpdf'], '-dpdf', '-painters','-bestfit') % Makoto's print method. On Linux.
%                 close;
%                %% 3) plot ERSPs using full reference ersp subtraction - unmasked 
% 
                if ~isempty(refErspCond)
                     %% 3) plot ERSPs using full reference ersp subtraction - unmasked 
                     clim = erspDiff_clim;
%                     figure('name',['Cls ' num2str(CL) ' ' mylabel,'_condVsBaseline'],'InvertHardcopy', 'off', 'PaperType', 'a2', 'PaperOrientation', 'landscape');
%                     %set(gcf,'PaperUnits','inches','Units','Inches','PaperPosition',[0 0 10 3.5],'Position',[5 5 10 3.5]);
%                     fig_width = 1.25*(numCond); %previously 10 for 7 cond, adjusting to so figure isnt' stretched for 1 condition
%                     fig_height = fig_width/2;%
%                     set(gcf,'PaperUnits','inches','Units','Inches','PaperPositionMode','auto','Position',[0 0 fig_width*2 fig_height*2 ],'Units','Inches');
% 
%                     K = 0;
%                     for condi =compareCondi
%                         K = K+1;
%                         fh(K).h = subplot(1,length(compareCondi),K); %
%                         contourf(alltimes, allfreqs,erspDiff.mean{condi,groupi},200,'linecolor','none')
%                         set(gca,'clim',clim,'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
%                         set(gcf,'Colormap', calldefinedcolormap5(), ...
%                             'Color',[1 1 1]);
% 
%                         %resize plot to fit title
%                         pos = fh(K).h.Position;
%                         fh(K).h.Position =[pos(1)-0.04 pos(2)*1.8 pos(3) pos(4)*.7];
% 
%                         if condi ==compareCondi(end)
%                             pos = fh(K).h.Position;
%                             c = colorbar('Position',[pos(1)+pos(3)+0.01  pos(2) 0.012 pos(4)]);
%                             c.Limits = clim;
%                             hL = ylabel(c,[{'\Delta Power'};{'WRT'};{myplotParams.legend{1,refErspCond_ind_reordered}};{'(dB)'}],...
%                                 'fontweight','bold','FontName','Arial','FontSize',8,'Rotation',0);
%                             hL.Position(1) = 7;
%                             hL.Position(2) = 0.2;
%                         end
% 
%                         xlimits = xlim;
%                         set(gca,'XTick',[evPlotLines(1:4) xlimits(1,2)],...
%                             'XTickLabel',{'0','','50','','100'});
%                         xtickangle(45)
%                         h = gca;
%                         h.XRuler.TickLabelGapOffset = -2;
% 
%                         %add axes labels
%                         if K==1
%                             set(gca,'ytick', [4 8 13 30 50 100]);
%                             ylh = ylabel(sprintf('Frequency\n(Hz)'),'fontsize',16,'fontweight','bold','FontName','Arial');
%                             ylh.Position(1) = ylh.Position(1)-400;
%                         else
%                             set(gca,'YTickLabel',[]);
%                             ylabel('');
%                         end
% 
%                         if K ~= 1
%                             xlabel('');
%                         else
%                             xlh = xlabel('Gait Cycle (%)','Fontsize',16,'fontweight','bold');
%                             xlh.Position(2) = 2;
%                         end
% 
%                         set(gca,'Fontsize',16);
%                         T = title(myplotParams.legend{condi},'FontSize',12);
%                         T.Position(2) = 200;
%                         %add event lines from time warp
%                         if ~isempty(evPlotLines)
%                             hold on;
%                             for L = 1:length(evPlotLines)
%                                 if L ==1 || L==length(evPlotLines)
%                                     %v = vline(evPlotLines(L),'-k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1); %solid line
%                                     v = vline(evPlotLines(L),'-k',eventLabels{1,L}); set(v,'LineWidth',1); %solid line
%                                 else
%                                     %v = vline(evPlotLines(L),':k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1.2);
%                                     v = vline(evPlotLines(L),':k',eventLabels{1,L}); set(v,'LineWidth',1.2);
%                                 end
%                             end
%                             %                 text([evPlotLines]-80,140*ones([1,length(evPlotLines)]),eventLabels,'VerticalAlignment','top','FontSize',8)
%                             %adjust event text box position
%                             H=findobj(gcf);
%                             tb = findobj(H,'Type','text');
%                             for textbox = 1:size(tb,1)
%                                 pos = tb(textbox).Position;
%                                 tb(textbox).Position = [pos(1) 100 0];
%                                 set(tb(textbox),'Rotation',90)
%                                 set(tb(textbox),'FontSize',8) %rotate 90 degrees
%                             end
%                             hold off;
%                         end
% 
%                         % set figure settings
%                         %             set(gca,'Fontsize',14,'fontweight','bold','FontName','Arial','YMinorTick','off');
%                         set(gca,'FontName','Arial','box','on','YMinorTick','off');
% 
%                     end
% 
%                     set(gcf,'Colormap', calldefinedcolormap6(), ...
%                         'Color',[1 1 1]);
%                     %% save figure
%                     if compareGroupsFlag
%                         sgtitle([mylabel,'-',groupNames{groupi},' group (n = ',numGroupMembers,')'],'interpreter','none')
%                         figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',groupNames{groupi},'Group_condVsBaseline_',statsMethod,num2str(Alpha),'_',mcorrect,'_',mode);
%                     else
% 
%                         figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_','_condVsBaseline_',statsMethod,num2str(Alpha),'_',mcorrect,'_',mode);
%                     end
% 
%                     savethisfig(gcf,[figname,'.png'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\png\'],'png')
%                     savethisfig(gcf,[figname,'.fig'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\fig\'],'fig')
%                     savethisfig(gcf,[figname,'.svg'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\svg\'],'svg')
%                     if ~exist([savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\dpdf'], 'dir') %check
%                         mkdir([savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\dpdf'])
%                     end
%                     orient(gcf,'landscape')
%                     print([savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\dpdf\',figname,'.dpdf'], '-dpdf', '-painters','-bestfit') % Makoto's print method. On Linux.
%                     close;
                    %% 4) plot ERSPs using full reference ersp subtraction - masked
                    figure('name',['Cls ' num2str(CL) ' ' mylabel,'_condVsBaseline'],'InvertHardcopy', 'off', 'PaperType', 'a2', 'PaperOrientation', 'landscape');
                    %set(gcf,'PaperUnits','inches','Units','Inches','PaperPosition',[0 0 10 3.5],'Position',[5 5 10 3.5]);
                    %fig_width = 1.25*(numCond); %previously 10 for 7 cond, adjusting to so figure isnt' stretched for 1 condition
                    fig_width = 2*(numCond); %previously 10 for 7 cond, adjusting to so figure isnt' stretched for 1 condition
                    fig_height = fig_width/2;%
                    set(gcf,'PaperUnits','inches','Units','Inches','PaperPositionMode','auto','Position',[0 0 fig_width*2 fig_height*2 ],'Units','Inches');

                    K = 0;
                    for condi = compareCondi
                        K = K+1;
                        fh(K).h = subplot(1,length(compareCondi),K); %
                        contourf(alltimes, allfreqs, erspDiff.mean{condi,groupi}, ...
                            200,'linecolor','none')
                        hold on;
                        %overlay transparent masked ersp, create array the same size as ersp — Use a different transparency value for each image element.
                        % faceAlpha = ones(size(erspDiff.pcond{condi,groupi}))*0.7; %alpha range [0-1] where 0 is fully transparent and 1 = fully opaque
                        % faceAlpha (erspDiff.pcond{condi,groupi} < Alpha) = 0; %set sig regions in this MASK to be fully TRANSPARENT so we can see underlying sig regions
                        % imagesc(alltimes, allfreqs, erspDiff.masked{condi,groupi},'AlphaData',faceAlpha)

                        % Find boundaries of the mask
                        B = bwboundaries(erspDiff.pcond{condi,groupi});
                        % Overlay each boundary on the image
                        for k = 1:length(boundaries)
                            yBoundary = allfreqs(B{k}(:,1)); % mask rows -> frequency vector
                            xBoundary = alltimes(B{k}(:,2)); % mask cols -> time vector
                            plot(xBoundary, yBoundary, 'Color', [0.97 0 1], 'LineWidth', 2, 'LineStyle', '-'); % color and width as desired
                        end

                        set(gca,'clim',clim,'xlim',[alltimes(1) alltimes(end)], ...
                            'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
                        set(gcf,'Colormap', calldefinedcolormap7(), ...
                            'Color',[1 1 1]);

                        %resize plot to fit title
                        pos = fh(K).h.Position;
                        fh(K).h.Position =[pos(1)-0.04 pos(2)*1.8 pos(3) pos(4)*.7];

                        if condi == compareCondi(end)
                            pos = fh(K).h.Position;
                            c = colorbar('Position',[pos(1)+pos(3)+0.01  pos(2) 0.012 pos(4)]);
                            c.Limits = clim;

                            % make the Ticks symmetric
                            maxAbs = max(abs(c.Ticks));
                            % If maxAbs isn't in v, append it to make symmetric
                            if ~ismember(maxAbs, c.Ticks)
                                c.Ticks = sort([c.Ticks maxAbs]); % sort if you want increasing order
                            end

                            hL = ylabel(c,[{'\Delta Baseline-Corrected Power (dB)'}],...
                                'fontweight','bold','FontName','Arial','FontSize', 14,'Rotation', 90);
                            hL.Position(1) = 5;
                            hL.Position(2) = 0;
                        end

                        xlimits = xlim;
                        % set(gca,'XTick',[evPlotLines(1:4) xlimits(1,2)],...
                        %     'XTickLabel',{'0','','50','','100'});
                        set(gca,'XTick',[alltimes(1) evPlotLines(2) alltimes(end)],...
                        'XTickLabel',{'0', '50', '100'}, 'ytick', [4 8 14 30 60 120]);
                    
                        xtickangle(45)
                        h = gca;
                        h.XRuler.TickLabelGapOffset = -2;

                        %add axes labels
                        if K==1
                            set(gca,'ytick', [4 8 14 30 60 120]);
                            ylh = ylabel(sprintf('Frequency\n(Hz)'),'fontsize',16,'fontweight','bold','FontName','Arial');
%                             ylh.Position(1) = ylh.Position(1)-400;
                        else
                            set(gca,'YTickLabel',[]);
                            ylabel('');
                        end

                        % if K ~= 1
                        %     xlabel('');
                        % else
                        %     xlh = xlabel('Gait Cycle (%)','Fontsize',16,'fontweight','bold');
                        %     %xlh.Position(2) = 2;
                        %     xlh.Position(2) = 1.5;
                        % end
                    
                        xlh = xlabel('Cycle (%)','Fontsize',16,'fontweight','bold');
                        %xlh.Position(2) = 2;
                        xlh.Position(2) = 1.8;
                        

                        set(gca,'Fontsize',16);
                        difftitle = [myplotParams.legend{condi}, ...
                            ' vs. ',myplotParams.legend{refErspCond_ind_reordered}];
                        T = title(difftitle,'FontSize',16);
                        T.Position(2) = 200;
                        % add event lines from time warp
                        if ~isempty(evPlotLines)
                            hold on;
                            for L = 1:length(evPlotLines_correct)
                                if L == 1 || L == length(evPlotLines_correct)
                                    %v = vline(evPlotLines(L),'-k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1); %solid line
                                    v = vline(evPlotLines_correct(L),'-k', eventLabels_new{1,L}); set(v,'LineWidth',1); %solid line
                                else
                                    %v = vline(evPlotLines(L),':k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1.2);
                                    v = vline(evPlotLines_correct(L),':k',eventLabels_new{1,L}); set(v,'LineWidth',1.2);
                                end
                            end
                            %                 text([evPlotLines]-80,140*ones([1,length(evPlotLines)]),eventLabels,'VerticalAlignment','top','FontSize',8)
                            %adjust event text box position
                            H = findobj(gcf);
                            tb = findobj(H,'Type','text');
                            
                            for textbox = 1:3 % 1:size(tb,1)
                                if     mod(textbox, 3) == 1
                                    pos = tb(textbox).Position;
                                    tb(textbox).Position = [pos(1)+65 140 0];
                                    set(tb(textbox),'Rotation',90) % rotate 90 degrees
                                    set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                                elseif mod(textbox, 3) == 2
                                    pos = tb(textbox).Position;
                                    tb(textbox).Position = [pos(1)-20 140 0];
                                    set(tb(textbox),'Rotation',90) % rotate 90 degrees
                                    set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                                elseif mod(textbox, 3) == 0
                                    pos = tb(textbox).Position;
                                    tb(textbox).Position = [pos(1)+15 140 0];
                                    set(tb(textbox),'Rotation',90) % rotate 90 degrees
                                    set(tb(textbox),'FontSize',8, 'FontWeight', 'bold') 
                                end
                                % pos = tb(textbox).Position;
                                % tb(textbox).Position = [pos(1) 150 0];
                                % set(tb(textbox),'Rotation',90) % rotate 90 degrees
                                % set(tb(textbox),'FontSize',8) 
                            end

                            % clear tb

                            hold off;
                        end

                        % set figure settings
                        %             set(gca,'Fontsize',14,'fontweight','bold','FontName','Arial','YMinorTick','off');
                        set(gca,'FontName','Arial','box','on','YMinorTick','off');

                    end
                    %         sgtitle('Difference ERSP: Condition vs Baseline')
                    set(gcf,'Colormap', calldefinedcolormap8(), ...
                        'Color',[1 1 1]);

                    %% save figure
                    % if compareGroupsFlag
                    %     sgtitle([mylabel,'-',groupNames{groupi},' group (n = ',numGroupMembers,')'],'interpreter','none')
                    %     figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',groupNames{groupi},'Group_condVsBaseline_',statsMethod,num2str(Alpha),'_',mcorrect,'_',mode,'_masked');
                    % else
                        % figname = strcat('ERSP_',myplotParams.figname,'_CL',num2str(CL),'_',mylabel,'_','_condVsBaseline_',statsMethod,num2str(Alpha),'_',mcorrect,'_',mode,'_masked');
                    % end

                    if compareGroupsFlag
                        sgtitle([mylabel,'-',groupNames{groupi},' group (n = ',numGroupMembers,')'],'interpreter','none')
                        figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',groupNames{groupi},'Group_',statsMethod2,num2str(Alpha),'_',mcorrect2,'_',mode2);
                    else
                        figname = strcat(STUDY_title,'_ERSP_', myplotParams.figname, '_CL', num2str(CL),'_condVsBaseline_', statsMethod, num2str(Alpha),'_', mcorrect,'_',mode);
                    end

                    savethisfig(gcf, strcat(figname,'.png'), ...
                        [savePath,'\ERSP\',myplotParams.figname,'\all_cond\png'],'png')
                    savethisfig(gcf, strcat(figname,'.fig'), ...
                        [savePath,'\ERSP\',myplotParams.figname,'\all_cond\fig'],'fig')
                    savethisfig(gcf, strcat(figname,'.svg'), ...
                        [savePath,'\ERSP\',myplotParams.figname,'\all_cond\svg'],'svg')


%                   if ~exist([savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\dpdf'], 'dir') %check
%                         mkdir([savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\dpdf'])
%                     end
%                     orient(gcf,'landscape')
%                     print([savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\dpdf\',figname,'.dpdf'], '-dpdf', '-painters','-bestfit') % Makoto's print method. On Linux.
%                     close;
                end
            end

%             %% Compare group ERSPs
%             if compareGroupsFlag && ~isempty(refErspCond)
%                 % find appropriate plot limits for ersp group
%                 % difference data
%                 data = [];
%                 for condi = 1:size(erspGroupDiff.mean,2)
%                     data = [data, reshape(mean(erspDiff.mean{condi},3).',1,[])];
%                 end
%                 IQR = iqr(data); %interquartile range
%                 Q1 = quantile(data,0.25);
%                 myMin = round(Q1-1.5*IQR,1);
%                 erspGroupDiff_clim = [myMin myMin*(-1)];
%                 clim = erspGroupDiff_clim;
% 
%                 numCond = size(erspdata.mean,2); %ref condition is empty
% 
%                 figure('name',['Cls ' num2str(CL) ' ' mylabel,'_GroupDiff'],'InvertHardcopy', 'off', 'PaperType', 'a2', 'PaperOrientation', 'landscape');
%                 %set(gcf,'PaperUnits','inches','Units','Inches','PaperPosition',[0 0 10 3.5],'Position',[5 5 10 3.5])
%                 fig_width = 2*(numCond); %previously 10 for 7 cond, adjusting to so figure isnt' stretched for 1 condition
%                 fig_height = fig_width/2;%
%                 set(gcf,'PaperUnits','inches','Units','Inches','PaperPositionMode','auto','Position',[0 0 fig_width*2 fig_height*2 ],'Units','Inches');
% 
%                 K = 0;
%                 for condi =compareCondi
%                     K = K+1;
%                     fh(K).h = subplot(1,length(compareCondi),K); %
%                     contourf(alltimes, allfreqs,erspGroupDiff.mean{condi},200,'linecolor','none')
%                     hold on;
%                     %overlay transparent masked ersp, create array the same size as ersp — Use a different transparency value for each image element.
%                     faceAlpha = ones(size(erspGroupDiff.pcond{condi}))*0.5; %alpha range [0-1] where 0 is fully transparent and 1 = fully opaque
%                     faceAlpha (erspGroupDiff.pcond{condi} < Alpha) = 0; %set sig regions in this MASK to be fully TRANSPARENT so we can see underlying sig regions
%                     imagesc(alltimes,allfreqs,erspGroupDiff.masked{condi},'AlphaData',faceAlpha)
% 
%                     set(gca,'clim',clim,'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
%                     set(gcf,'Colormap', calldefinedcolormap9(), ...
%                         'Color',[1 1 1]);
% 
%                     %resize plot to fit title
%                     pos = fh(K).h.Position;
%                     fh(K).h.Position =[pos(1)-0.04 pos(2)*1.8 pos(3) pos(4)*.7];
% 
%                     if condi ==compareCondi(end)
%                         pos = fh(K).h.Position;
%                         c = colorbar('Position',[pos(1)+pos(3)+0.01  pos(2) 0.012 pos(4)]);
%                         c.Limits = clim;
%                         hL = ylabel(c,[{'\Delta Power'};{'WRT'};{myplotParams.legend{1,refErspCond_ind_reordered}};{'(dB)'}],...
%                             'fontweight','bold','FontName','Arial','FontSize',8,'Rotation',0);
%                         hL.Position(1) = 7;
%                         hL.Position(2) = 0.2;
%                     end
% 
%                     xlimits = xlim;
%                     set(gca,'XTick',[evPlotLines(1:4) xlimits(1,2)],...
%                         'XTickLabel',{'0','','50','','100'});
%                     xtickangle(45)
%                     h = gca;
%                     h.XRuler.TickLabelGapOffset = -2;
% 
%                     %add axes labels
%                     if K==1
%                         set(gca,'ytick', [4 8 13 30 50 100]);
%                         ylh = ylabel(sprintf('Frequency\n(Hz)'),'fontsize',16,'fontweight','bold','FontName','Arial');
%                         %                             ylh.Position(1) = ylh.Position(1)-400;
%                     else
%                         set(gca,'YTickLabel',[]);
%                         ylabel('');
%                     end
% 
%                     if K ~= 1
%                         xlabel('');
%                     else
%                         xlh = xlabel('Gait Cycle (%)','Fontsize',16,'fontweight','bold');
%                         %xlh.Position(2) = 2;
%                         xlh.Position(2) = 1.5;
%                     end
% 
%                     set(gca,'Fontsize',16);
%                     T = title(myplotParams.legend{condi},'FontSize',12);
%                     T.Position(2) = 200;
%                     %add event lines from time warp
%                     if ~isempty(evPlotLines)
%                         hold on;
%                         for L = 1:length(evPlotLines)
%                             if L ==1 || L==length(evPlotLines)
%                                 v = vline(evPlotLines(L),'-k',eventLabels{1,L}); set(v,'LineWidth',1); %solid line
%                             else
%                                 v = vline(evPlotLines(L),':k',eventLabels{1,L}); set(v,'LineWidth',1.2);
%                             end
%                         end
%                         %adjust event text box position
%                         H=findobj(gcf);
%                         tb = findobj(H,'Type','text');
%                         for textbox = 1:size(tb,1)
%                             pos = tb(textbox).Position;
%                             tb(textbox).Position = [pos(1) 100 0];
%                             set(tb(textbox),'Rotation',90)
%                             set(tb(textbox),'FontSize',8) %rotate 90 degrees
%                         end
%                         hold off;
%                     end
% 
%                     set(gca,'FontName','Arial','box','on','YMinorTick','off');
% 
%                 end
%                 set(gcf,'Colormap', calldefinedcolormap10(), ...
%                     'Color',[1 1 1]);
% 
%                     %% save figure
%                         sgtitle([mylabel,'   ',groupNames{1,1},'-',groupNames{1,2},' group diff'],'interpreter','none')
%                         figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',groupNames{groupi},'GroupDiff',statsMethod,num2str(Alpha),'_',mcorrect,'_',mode,'_masked');
%                     savethisfig(gcf,[figname,'.png'],[savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\png\'],'png')
%                     savethisfig(gcf,[figname,'.fig'],[savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\fig\'],'fig')
%                     savethisfig(gcf,[figname,'.svg'],[savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\svg\'],'svg')
% %                     if ~exist([savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\dpdf'], 'dir') %check
% %                         mkdir([savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\dpdf'])
% %                     end
%                    % orient(gcf,'landscape')
%                     %print([savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\dpdf\',figname,'.dpdf'], '-dpdf', '-painters','-bestfit') % Makoto's print method. On Linux.
%                     close;
%             end
        end
        sfields{1,XX} = s; %for filling structure in parfor loop
        clear cond
    end
    delete(gcp('nocreate')); %shutdown parallel pool
    %fill structure using parfor results
    index = 1;

    %store study design info to output variable
    ersp_results(index).name = STUDY_title;
    ersp_results(index).design = design;
    ersp_results(index).designVariables =  {STUDY.design(design).variable.value};
    %store study design info to output variable
    ersp_results(index).design_name = STUDY.design(design).name;
    ersp_results(index).variable = STUDY.design(design).variable;
    ersp_results(index).one_subjectAvg_per_Cl = one_sub_per_cl;

    for i=1:length(clusters_to_plot)
        ersp_results(index).data(i) = sfields{1,i};
    end

catch ME %save results if you run into error
    rethrow(ME)
    index = size(ersp_results,2)+1;

    %store study design info to output variable
    ersp_results(index).name = STUDY.design(design).name;
    ersp_results(index).design = design;
    ersp_results(index).designVariables =  {STUDY.design(design).variable.value};
    %store study design info to output variable
    ersp_results(index).design_name = STUDY.design(design).name;
    ersp_results(index).variable = STUDY.design(design).variable;
    ersp_results(index).one_subjectAvg_per_Cl = one_sub_per_cl;

    for i=1:size(sfields{1,i},2)
        ersp_results(index).data(i) = sfields{1,i};
    end
    rethrow(ME)
end

%exerpt from std_erspplot, uses std_stat
function [pcond, pgroup, pinter, pval] = erspStats(STUDY,allersp)

        %get stats parameters
        stats = STUDY.etc.statistics;
        stats.fieldtrip.channelneighbor = struct([]); % assumes one channel or 1 component
        if isempty(STUDY.design(STUDY.currentdesign).variable)
            stats.paired = { };
        else
            stats.paired = { STUDY.design(STUDY.currentdesign).variable(:).pairing };
        end

        %get ersp params
        params = STUDY.etc.erspparams;
        params.plottf =[];
        % select specific time and freq
        % -----------------------------

        if ~isempty(params.plottf)
            if length(params.plottf) < 3
                params.plottf(3:4) = params.plottf(2);
                params.plottf(2)   = params.plottf(1);
            end
            [~, fi1] = min(abs(allfreqs-params.plottf(1)));
            [~, fi2] = min(abs(allfreqs-params.plottf(2)));
            [~, ti1] = min(abs(alltimes-params.plottf(3)));
            [~, ti2] = min(abs(alltimes-params.plottf(4)));
            for index = 1:length(allersp(:))
                allersp{index} = mean(mean(allersp{index}(fi1:fi2,ti1:ti2,:,:),1),2);
                allersp{index} = reshape(allersp{index}, [1 size(allersp{index},3) size(allersp{index},4) ]);
            end

            % prepare channel neighbor matrix for Fieldtrip
            statstruct = std_prepare_neighbors(STUDY, ALLEEG);
            stats.fieldtrip.channelneighbor = statstruct.etc.statistics.fieldtrip.channelneighbor;

            params.plottf = { params.plottf(1:2) params.plottf(3:4) };

             [pcond, pgroup, pinter, statscond, statsgroup, statsinter, pval] = std_stat_clusterpval(allersp, stats);%modified func to provide pvals


            if (~isempty(pcond) && length(pcond{1}) == 1) || (~isempty(pgroup) && length(pgroup{1}) == 1), pcond = {}; pgroup = {}; pinter = {}; end % single subject STUDY
        else
             [pcond, pgroup, pinter, statscond, statsgroup, statsinter, pval] = std_stat_clusterpval(allersp, stats);%modified func to provide pvals
            if (~isempty(pcond ) && (size( pcond{1},1) == 1 || size( pcond{1},2) == 1)) || ...
                    (~isempty(pgroup) && (size(pgroup{1},1) == 1 || size(pgroup{1},2) == 1))
                pcond = {}; pgroup = {}; pinter = {}; pval = {};
                disp('No statistics possible for single subject STUDY');
            end % single subject STUDY
        end
    end


% %determine effect size for cluster with lowest p-val
% %modified from Arnald Delorme: https://github.com/Donders-Institute/infant-cluster-effectsize/blob/main/do_group_analysis.m
% function [effect] = calc_clust_effectsize(allersp_tmp,freq,pval,method)
% %determine cluster with lowest p-val
% if iscell(pval)
%     pval = pval{1,1};
% end
% p= unique(pval);
% p = p(p<0.05);
%
% for clusti = 1:length(p)
%     effectWindow = pval==p(clusti);
%     %calculate pairwise difference in ersp between conditions
%     %for each participant
%     cond1ersp = allersp{1,1}; % collapsed to 2D array now
%     cond2ersp = allersp{2,1};
%     all_ersp_diff = cond2ersp-cond1ersp;
%
%     ersp_diff = [];
%     for subi = 1:size(all_ersp_diff,3)
%         sub_ersp = all_ersp_diff(:,:,subi);
%         ersp_diff(:,subi) = sub_ersp(effectWindow);
%     end
%
%
%
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     % Option 1: Calculate Cohen's d for the average difference
%     % in the respective cluster
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     if method == 1
%         ersp_diff_mean = nanmean(ersp_diff,1); %avg across freq band
%         %calculate Cohen's d
%         effect(clusti).method = 'avg difference in cluster';
%         effect(clusti).SD = std(ersp_diff);
%         effect(clusti).MEAN = mean(ersp_diff);
%         effect(clusti).COHENS_D = mean(ersp_diff)/std(ersp_diff);
%     end
%
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     % Option 2: Determine at maximum effect size and at which channel/time it
%     % is maximal (upper bound)
%     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     if method ==2
%         % Determine maximum effect sizavg across subjectse and at which frequency Cohen's d is maximal
%         cohens_d = abs(nanmean(ersp_diff,2)./std(ersp_diff,0,2));%%abs so doesn't matter if clusters is positive or negative, avg across subjects
%         maxcd= max(cohens_d); %
%         maxeffectfreq = freq(cohens_d == maxdiff);
%         effect(clusti).method = 'max effect size';
%         effect(clusti).COHENS_D = maxcd;
%         effect(clusti).maxeffectfreq=  freq(effectWindow(cohens_d == maxcd));
%     end
%
%
%     if method ==0
%         ersp_diff_mean = nanmean(ersp_diff,1); %avg across cluster timef band
%         cohens_d = abs(nanmean(ersp_diff,2)./std(ersp_diff,0,2));%%abs so doesn't matter if clusters is positive or negative, avg across subjects
%         maxcd= max(cohens_d); %
%         rowi = find(cohens_d==maxcd);
%
%         %calc 95% CI just for freq with max cd
%         e = meanEffectSize(abs(cohens_d(rowi,:)));
%         Effect="cohen",ConfidenceIntervalType="bootstrap", ...
%             BootstrapOptions=statset(UseParallel=true,type='norm'),NumBootstraps=3000); %idk why this function isn't working after matlab was reinstalled
%
%
%
%         effect(clusti).SD = std(ersp_diff);
%         effect(clusti).MEAN = ersp_diff_mean;
%         effect(clusti).COHENS_D_avg = ersp_diff_mean/std(ersp_diff);
%         effect(clusti).COHENS_D_max = e.Effect;
%         effect(clusti).CI95 = [e.ConfidenceIntervals];
%         effect(clusti).maxeffectfreq =  [maxeffectfreq];
%         effect(clusti).window = [freq(effectWindow(1)), freq(effectWindow(end))];
%
%     end
% end
% end

% function savethisfig(fig,name,figfilepath,type)
% if ~exist(figfilepath, 'dir') %check
%     mkdir(figfilepath)
% end
% cd(figfilepath)
% saveas(fig,name,type);
% end


% Elsewhere in script, a separate file, or another method of your class.
    function updateTransparency(contourObj,alphaValues) %author Will Grant, modified by Noelle J.
        contourFillObjs = contourObj.FacePrims;
        for i = 1:length(contourFillObjs)
            % Have to set this. The default is 'truecolor' which ignores alpha.
            contourFillObjs(i).ColorType = 'truecoloralpha';
            % The 4th element is the 'alpha' value. First 3 are RGB. Note, the
            % values expected are in range 0-255.
            contourFillObjs(i).ColorData(4) = alphaValues(i);
        end
    end

% end


% %################### test ersp plotting methods ###########################
%    figure;tftopo(curr_ersp,alltimes,allfreqs,'logfreq','native','limits',[0 warpingvalues(end)],'vert',[evPlotLines(2:4)],'cbar','on');
%     hold on; %contour(alltimes, allfreqs, pcond{1,1},1,'linecolor','k'); %can't get contouring to work
%     figure;tftopo( maskedersp{1,c},alltimes,allfreqs,'logfreq','native','limits',[0 warpingvalues(end)],'vert',[evPlotLines(2:4)],'cbar','on');
%      set(gca,'YTick',log([4.01,8,13,30,50,99.4843]));
%     figure;tftopo(mean(averagePower,3),alltimes,allfreqs,'logfreq','native','limits',[0 warpingvalues(end)],'vert',[evPlotLines(2:4)],'cbar','on');
%
%
%
% %     maskedersp(c) = {ersp_diff.*pcond{1,1}};
%     figure; subplot(121); 
%     tftopo(erspdata(1).raw,alltimes,allfreqs,'logfreq','native','limits',[0 warpingvalues(end)],'vert',[evPlotLines(2:4)],'cbar','on');
%     colorbar;
%     title('Imagesc');
% %     figure;
% %     tftopo(ersp(1).raw,alltimes,allfreqs,'logfreq','native','limits',[0 warpingvalues(end)],'vert',[evPlotLines(2:4)],'cbar','on');
% %     contour(alltimes, allfreqs, log(ersp(1).pcond),1,'linecolor','k');
% %
% % %test, Mike Cohen
%     %figure, clf
%     subplot(122);
%     title('Contourf')
%     contourf(alltimes, allfreqs,ersp(1).raw,200,'linecolor','none')
%         set(gca,'clim',[-0.58 0.58],'xlim',[evPlotLines(1) evPlotLines(end)], ...
%         'ydir','norm','ylim',[allfreqs(1) allfreqs(end)], ...
%         'yscale','log','ytick', [5 7 9 11 13 15 18 20 23 27 31 36 42 48 56 64 80 99])
%     set(gca,'clim',[-0.5 0.5],'xlim',[evPlotLines(1) evPlotLines(end)], ...
%         'ydir','norm','ylim',[allfreqs(1) allfreqs(end)], ...
%         'yscale','log','ytick', [4 8 13 30 50 100])
%     xlabel('Time (ms)'); ylabel('Frequency (Hz)');
%     hold on;
%     contour(alltimes, allfreqs, ersp(1).pcond,1,'linecolor','k')
%     set(gca,'clim',[-0.5 0.5],'xlim',[evPlotLines(1) evPlotLines(end)], ...
%         'ydir','norm','ylim',[allfreqs(1) allfreqs(end)], ...
%         'yscale','log','ytick', [4 8 13 30 50 100])
%     colorbar;
%      set(gcf,'Colormap', calldefinedcolormap11()...
%      'Color',[1 1 1]);
%
%
%
%     figure;
%     logimagesc(alltimes,allfreqs, ersp_diff )
%     hold on;
%     logimagesc(alltimes,allfreqs, maskedersp{1,c});
%     alpha(0.5)
%     set(gcf,'Colormap', calldefinedcolormap12(), ...
%         'Color',[1 1 1]);
%     set(gcf,'Color','w')
%     colorbar

%####### old manual baseline subtraction method ###########################
%     %% 2) calculate ERSPs using full baseline ersp subtraction
%     % Calculate baseline and bootstrapping
%     baseline = allersp{1};
%     for c = 1:length(allersp)
%         curr_ersp = allersp{c}(:,:,:);
%         %Bootstrap and significance mask
%         if ~isnan(Alpha)
%             pboot = bootstat({allersp{c} baseline },'mean(arg1-arg2,3);','boottype','shuffle',...
%                 'label','ERSP','bootside','both','naccu',200,...
%                 'alpha',Alpha,'dimaccu',2);
%             curr_ersp = mean(curr_ersp-baseline,3);
%             curr_maskedersp = curr_ersp;
%             curr_maskedersp(curr_ersp > repmat(pboot(:,1),[1 size(curr_ersp,2)]) & curr_ersp < repmat(pboot(:,2),[1 size(curr_ersp,2)])) = 0;
%         else
%             curr_ersp = mean(curr_ersp,3);
%             curr_maskedersp = curr_ersp;
%         end
%         %         pstats(c) = {pboot};
%         maskedersp(c) = {curr_maskedersp};
%         ersp(c) = {curr_ersp};
%     end
%     % reorder
%     if changePlotOrder ==1
%         mylegend = cond_labels;
%         order= [];
%         reorderedData ={};
%         for s = 1:length(cond_labels)
%             try
%                 order(1,s) = find(strcmp(cond_labels{1,s},[STUDY.design(design).variable(1).value]));
%                 reorderedData(s) = [ersp(order(1,s))];
%                 reorderedData_masked(s) = [maskedersp(order(1,s))];
%                 %                 reordered_pstats(s) =  pstats(order(1,s));
%             catch
%                 disp('Variable name not found in STUDY.design.variable')
%             end
%         end
%         erspdata = reorderedData;
%         erspdata_masked = reorderedData_masked;
%         clear reorderedData
%     else
%         erspdata_masked = maskedersp;
%         erspdata = ersp;
%         mylegend = [STUDY.design(design).variable(1).value];
%     end




%
%     for k=1:length( erspdata)
%         h=subplot(1,length(erspdata),k);
%         contourf(alltimes, allfreqs, erspdata(k).raw,200,'linecolor','none')
%         set(gca,'clim',clim,'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
%         hold on;
%         contour(alltimes, allfreqs, erspdata(k).pcond,1,'linecolor','k','linewidth',1.5)
%         set(gca,'clim',clim,'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
%         set(gcf,'Colormap', calldefinedcolormap13(), ...
%             'Color',[1 1 1]);
%         if k==length(erspdata)
%             hp4 = get(subplot(1,length(erspdata),k),'Position');
%             c = colorbar('Position',[hp4(1)+hp4(3)+0.01  hp4(2)-0.0085 0.012  hp4(4)-0.071]);
%             c.Limits = clim;
%             hL = ylabel(c,[{'\Delta Power'};{'(dB)'}],'fontweight','bold','FontName','Arial');
%             set(hL,'Rotation',0);
%             hL.Position(1) = hL.Position(1)+1;
%             hL.Position(2) = hL.Position(2)+0.025;
%         end
%         T = title(plotParams.legend{k},'FontSize',16);
%         T.Position(2) = T.Position(2)+10;
%         xlimits = xlim;
%         set(gca,'XTick',[evPlotLines(1:4) xlimits(1,2)],...
%             'XTickLabel',{'0','','50','','100'});
%
%         if k==1
%             set(gca,'ytick', [4 8 13 30 50 100],'Fontsize',12,'FontName','Arial');
%             ylh = ylabel(sprintf('Frequency\n(Hz)'),'Rotation',0,'fontsize',16,'fontweight','bold','FontName','Arial');
%             ylh.Position(1) = ylh.Position(1)-100;
%         else
%             set(gca,'YTickLabel',{'','','','','',''});
%             ylabel('');
%         end
%
%         if k~=3
%             xlabel('');
%         else
%             xlabel('Gait Cycle (%)','Fontsize',16,'fontweight','bold');
%         end
%
%         %add event lines
%         if ~isempty(evPlotLines)
%
%             hold on;
%             for L = 1:length(evPlotLines)
%                 if L ==1 || L==length(evPlotLines)
%                     v = vline(evPlotLines(L),'-k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',0.8); %solid line for ends of plot
%                 else
%                     v = vline(evPlotLines(L),':k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1.2); %dotted line for middle of plot
%                 end
%             end
%             hold off;
%         end
%
%         set(gca,'Fontsize',14,'fontweight','bold','FontName','Arial','box','on','YMinorTick','off');
%     end
%     sgtitle(mysgtitle);
%     % set figure settings
%     set(gcf,'Colormap', calldefinedcolormap14(), ...
%         'Color',[1 1 1]);
%     set(gcf,'PaperUnits','inches','Units','Inches','PaperPosition',[0 0 20 6]);


%% set face alpha value to 50% transparency in non-significant
%regions-- not masking right
%         faceAlpha = ones(size(erspdata(k).pboot))*(255/2); %alpha range [0-255] where 0 is fully transparent and 255 = fully opaque
%         faceAlpha (erspdata(k).pboot ==1) = 255; %set sig regions to be fully opaque
% %         % This is the secret that 'keeps' the transparency. Or else matlab
%         % will revert back everytime object is regenerated/refreshed
%         eventFcn = @(srcObj, e) updateTransparency(srcObj, faceAlpha);
%         addlistener(contourObj, 'MarkedClean', eventFcn);


function plot1cond(xdata1, ydata1, zdata1,figname,plotTitle,clim)
%CREATEFIGURE(xdata1, ydata1, zdata1)
%  XDATA1:  contour x
%  YDATA1:  contour y
%  ZDATA1:  contour z

%  Auto-generated by MATLAB on 21-May-2023 16:58:54

% Create figure
figure1 = figure('PaperOrientation','landscape','InvertHardcopy','off',...
    'PaperType','A2',...
    'Name',figname,...
    'Colormap', calldefinedcolormap15(), 'Color',[1 1 1]);

% Create axes
axes1 = axes('Parent',figure1,'Position',[0.299 0.198 0.4 0.5705]);
hold(axes1,'on');

% Create contour
contour(xdata1,ydata1,zdata1,'LineColor','none',...
    'LevelList', calldefinedcolormap16());

% Create text
text('Parent',axes1,'FontSize',8,'Rotation',90,'String','RFC',...
    'Position',[12.5 100 0]);

% Create text
text('Parent',axes1,'FontSize',8,'Rotation',90,'String','LFO',...
    'Position',[212.5 100 0]);

% Create text
text('Parent',axes1,'FontSize',8,'Rotation',90,'String','LFC',...
    'Position',[612.5 100 0]);

% Create text
text('Parent',axes1,'FontSize',8,'Rotation',90,'String','RFO',...
    'Position',[812.5 100 0]);

% Create text
text('Parent',axes1,'FontSize',8,'Rotation',90,'String','RFC',...
    'Position',[1187.5 100 0]);

% Create ylabel
ylabel({'Frequency','(Hz)'},'FontWeight','bold','FontName','Arial',...
    'Rotation',0);

% Create xlabel
xlabel('Gait Cycle (%)','FontWeight','bold','FontName','Arial');

% Create title
title(plotTitle,'FontSize',12);

% Uncomment the following line to preserve the X-limits of the axes
xlim(axes1,[0 1250]);
% Uncomment the following line to preserve the Y-limits of the axes
% ylim(axes1,[3 97.6885317339151]);
box(axes1,'on');
hold(axes1,'off');
% Set the remaining axes properties
set(axes1,'BoxStyle','full','CLim',[clim(1) clim(2)],'FontName','Arial','FontSize',...
    12,'Layer','top','XTick',[0 200 600 800 1250],'XTickLabel',...
    {'0','','50','','100'},'XTickLabelRotation',45,'YScale','log','YTick',...
    [4 8 13 30 50 100]);
% Create colorbar
colorbar(axes1,'Position',...
    [0.723333333333333 0.204166666666667 0.0224999999999996 0.5625],...
    'Limits',[-1.1 1.1]);

end

function gcf = formatFig(gcf, evPlotLines,eventLabels)
set(findall(gcf,'-property','XTickLabel'),'XTickLabel',[])
ylim([-inf inf])
xlim([0 evPlotLines(end)])
yline(0,'--','Color',[0.5 0.5 0.5])
set(gca,'XTick',[evPlotLines],...
    'fontsize',10);

xlh = xlabel('Gait Cycle (%)');
xlh.Position(2) = xlh.Position(2)-0.2;
ylabel('Mean Power (dB)')

%add event lines from time warp
if ~isempty(evPlotLines)
    hold on;
    for L = 1:length(evPlotLines)
        if L ==1 || L==length(evPlotLines)
            v = vline(evPlotLines(L),'-k',eventLabels{1,L}); set(v,'LineWidth',1); %solid line
        else
            v = vline(evPlotLines(L),':k',eventLabels{1,L}); set(v,'LineWidth',1.2);
        end
    end

    %adjust event text box position
    H=findobj(gcf);
    tb = findobj(H,'Type','text');
    for textbox = 1:size(tb,1)
        pos = tb(textbox).Position;
        tb(textbox).Position = [pos(1) 100 0];
        set(tb(textbox),'Rotation',90)
        set(tb(textbox),'FontSize',8) %rotate 90 degrees
    end
    hold off;
end
set(gca,'FontName','Arial','box','off','YMinorTick','off')
set(gcf,'Color','w');

end