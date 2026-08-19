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



function ersp_results = plotERSPSfromSTUDY(STUDY,ALLEEG,savePath,myplotParams,clusters_to_plot,one_sub_per_cl,erspParamOverride, ersp_results)
%check input parameters
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
changePlotOrder =1; %1= reorder plots, 0= keep conditions alphabetical
cond_labels = myplotParams.labels;
condstats ='on';        % ['on'|'off]
statsMethod ='perm';    % ['param'|'perm'|'bootstrap']
Alpha = 0.05;           % [NaN|alpha], Significance threshold (0<alpha<<1) ***hard coded this in places to skip certain stats, be careful if changing to diff vaule
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
    compareGroupsFlag =0;
end

%flag for option to override ersp params
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
%set stastical method
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
STUDY = pop_erspparams(STUDY, 'subbaseline','on','timerange',[evPlotLines(1) evPlotLines(end)],'freqrange',[0 100], 'ersplim',[-1.5 1.5]);  % 'subbaseline' - ['on'|'off'] subtract the same baseline across conditions for ERSP

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
                    'singletrials',singletrials,'mode',mode,'fieldtripalpha',Alpha,...
                    'fieldtripmethod','montecarlo','fieldtripmcorrect',mcorrect,'fieldtripnaccu',10000);
        end

        % read and plot ersp data
        if erspParamOverride_flag == 1 %override parameters using myErspParams given in input
            cellArray= {myErspParams{1,2:2:length(myErspParams)}};
            fields = {myErspParams{1,1:2:length(myErspParams)-1}};
            myErspParams = cell2struct(cellArray, fields,2);
            [tmpSTUDY, allersp, alltimes, allfreqs, pgroup, all_pcond, pinter, events] = std_erspplot_myparams(tmpSTUDY, ALLEEG,myErspParams, 'clusters',CL,'logfreq','on','subtractsubjectmean','on');%modified std_erspplot to override ersp parameters
            c = colorbar;
            clim = c.Limits;
        else %use ersp parameters stored in timef (typical use of std_erspplot)
            try
                [tmpSTUDY, allersp, alltimes, allfreqs, pgroup, all_pcond, pinter, events] = std_erspplot(tmpSTUDY, ALLEEG, 'clusters',CL,'logfreq','on','subtractsubjectmean','on');
            catch
                STUDY = pop_erspparams(STUDY,'ersplim',[]); %change cbar limits if error is given when there's no sig diff across conditions
                [tmpSTUDY, allersp, alltimes, allfreqs, pgroup, all_pcond, pinter, events] = std_erspplot(tmpSTUDY, ALLEEG, 'clusters',CL,'logfreq','on','subtractsubjectmean','on');
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
        if one_sub_per_cl ~=0
            if one_sub_per_cl ==1
                disp('one subject/cluster by averaging')
            elseif one_sub_per_cl ==2
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
                %allersp{i,1}= cond(i).ersp;
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
        statsMethod2 ='perm';    % ['param'|'perm'|'bootstrap']
        mcorrect2 = 'fdr'; %fdr
        mode2 = 'eeglab';
        clear ersp
        %baseidx = find(alltimes>=basetime(1) & alltimes<=basetime(end)); %Take times that are in your baseline
        for condi = 1:size(allersp,1)
            %Calculate and subtract baseline
            %baseline = mean(allersp{c}(:,baseidx,:),2); %average baseline within condition. Your baseline depends on the comparisons you want to make.
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
%                         'alpha',Alpha,'dimaccu',2); % ***I'm not sure if this is the best way to compare if a condition is sig different from zero-- "bootstrap"-- which is really only doing permutation-- might overestimate significance
%                     curr_ersp_raw = curr_ersp;
%                     curr_ersp = mean(curr_ersp,3);
%                     curr_maskedersp = curr_ersp;
%                     curr_maskedersp(curr_ersp > repmat(pboot(:,1),[1 size(curr_ersp,2)]) & curr_ersp < repmat(pboot(:,2),[1 size(curr_ersp,2)])) = 0;
%                     pcond = ones(size(curr_maskedersp));
%                     pcond(curr_ersp > repmat(pboot(:,1),[1 size(curr_ersp,2)]) & curr_ersp < repmat(pboot(:,2),[1 size(curr_ersp,2)])) = 0;
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

                  Alpha = 0.05;
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
                   
                        cluster_perm_test(end+1).name = strcat(STUDY.design(design).variable(1).value(c),' vs. ',STUDY.design(design).variable(1).value(r));
                        cluster_perm_test(end).freqrange = STUDY.etc.erspparams.freqrange;
                        cluster_perm_test(end).pval = pval;
                        cluster_perm_test(end).pcond = pcond{1,1};


                        if any(any(pval<0.05)) %if any pvalues <alpha, continue to next step
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
 Alpha = 0.05;
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

                for condi =1:size(erspdata.mean,1)+1
                    fh(condi).h = subplot(1,numCond+1,condi);

                    if condi < numCond+1
                        contourf(alltimes, allfreqs, erspdata.mean{condi,groupi},200,'linecolor','none')
                    elseif condi == numCond+1
                        contourf(alltimes, allfreqs, all_pcond{1,groupi},200,'linecolor','none')
                    end
                    hold on;

                    set(gca,'clim',clim,'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
                    set(gcf,'Colormap',...
                        [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
                        'Color',[1 1 1]);

                    %resize plot to fit title
                    pos = fh(condi).h.Position;
                    fh(condi).h.Position =[pos(1)-0.04 pos(2)*1.8 pos(3) pos(4)*.7];


                    if condi ==numCond +1
                        pos = fh(condi).h.Position;
                        c = colorbar('Position',[pos(1)+pos(3)+0.01  pos(2) 0.012 pos(4)]);
                        c.Limits = clim;
                        hL = ylabel(c,[{'\Delta Power'};{'WRT'};{myplotParams.legend{1,refErspCond_ind}};{'(dB)'}],...
                            'fontweight','bold','FontName','Arial','FontSize',8,'Rotation',0);
                        hL.Position(1) = 6;
                        hL.Position(2) = 0.2;
                    end

                    xlimits = xlim;
                    %         set(gca,'XTick',[evPlotLines(1:end) xlimits(1,2)],...
                    %             'XTickLabel',{'0','','50','','100'},'ytick', [4 8 13 30 50 100]);
                    set(gca,'XTick',[evPlotLines],...
                        'XTickLabel',{'0','','50','','100'},'ytick', [4 8 13 30 50 100],'fontsize',10);
                    xtickangle(45)
                    h = gca;
                    h.XRuler.TickLabelGapOffset = -2;

                    %ylabel
                    if condi ==1
                        ylh = ylabel(sprintf('Frequency\n(Hz)'),'fontsize',16,'fontweight','bold','FontName','Arial');
                        ylh.Position(1) = ylh.Position(1)-450;
                    else
                        set(gca,'YTickLabel',[]);
                        %ylabel('');
                    end

                    if condi ~=1
                        xlabel('');
                    else
                        xlh = xlabel('Gait Cycle (%)','Fontsize',16,'fontweight','bold');
                        xlh.Position(2) = 2;
                    end

                    set(gca,'Fontsize',16);
                    if  condi == numCond+1
                        T = title('p<0.05','FontSize',10);
                        T.Position(2) = T.Position(2)+100;
                    else
                        T = title(myplotParams.legend{condi},'FontSize',10);
                        T.Position(2) = T.Position(2)+100;
                    end

                    %add event lines from time warp
                    if ~isempty(evPlotLines)
                        hold on;
                        for L = 1:length(evPlotLines)
                            if L ==1 || L==length(evPlotLines)
                                %v = vline(evPlotLines(L),'-k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1); %solid line
                                v = vline(evPlotLines(L),'-k',eventLabels{1,L}); set(v,'LineWidth',1); %solid line
                            else
                                %v = vline(evPlotLines(L),':k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1.2);
                                v = vline(evPlotLines(L),':k',eventLabels{1,L}); set(v,'LineWidth',1.2);
                            end
                        end
                        %             text([evPlotLines]-80,140*ones([1,length(evPlotLines)]),eventLabels,'VerticalAlignment','top')
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
                    set(gca,'FontName','Arial','box','on','YMinorTick','off');
                end

                % set figure settings
                set(gcf,'Colormap',...
                    [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
                    'Color',[1 1 1]);

                %% save figure
                if compareGroupsFlag
                    sgtitle([mylabel,'-',groupNames{groupi},' group (n = ',numGroupMembers,')'],'interpreter','none')
                    figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',groupNames{groupi},'Group_',statsMethod2,num2str(Alpha),'_',mcorrect2,'_',mode2);
                else
                    figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',statsMethod2,num2str(Alpha),'_',mcorrect2,'_',mode2);
                end

                savethisfig(gcf,[figname,'.png'],[savePath,'\ERSP\',myplotParams.figname,'\all_cond\png'],'png')
                savethisfig(gcf,[figname,'.fig'],[savePath,'\ERSP\',myplotParams.figname,'\all_cond\fig'],'fig')
                savethisfig(gcf,[figname,'.svg'],[savePath,'\ERSP\',myplotParams.figname,'\all_cond\svg'],'svg')

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
%                     set(gcf,'Colormap',...
%                         [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
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
%                     %         set(gca,'XTick',[evPlotLines(1:end) xlimits(1,2)],...
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
%                 set(gcf,'Colormap',...
%                     [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
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
%                         set(gcf,'Colormap',...
%                             [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
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
%                         set(gca,'XTick',[evPlotLines(1:end) xlimits(1,2)],...
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
%                     set(gcf,'Colormap',...
%                         [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
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
                    for condi =compareCondi
                        K = K+1;
                        fh(K).h = subplot(1,length(compareCondi),K); %
                        contourf(alltimes, allfreqs,erspDiff.mean{condi,groupi},200,'linecolor','none')
                        hold on;
                        %overlay transparent masked ersp, create array the same size as ersp — Use a different transparency value for each image element.
                        faceAlpha = ones(size(erspDiff.pcond{condi,groupi}))*0.5; %alpha range [0-1] where 0 is fully transparent and 1 = fully opaque
                        faceAlpha (erspDiff.pcond{condi,groupi} < Alpha) = 0; %set sig regions in this MASK to be fully TRANSPARENT so we can see underlying sig regions
                        imagesc(alltimes,allfreqs,erspDiff.masked{condi,groupi},'AlphaData',faceAlpha)

                        set(gca,'clim',clim,'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
                        set(gcf,'Colormap',...
                            [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
                            'Color',[1 1 1]);

                        %resize plot to fit title
                        pos = fh(K).h.Position;
                        fh(K).h.Position =[pos(1)-0.04 pos(2)*1.8 pos(3) pos(4)*.7];

                        if condi ==compareCondi(end)
                            pos = fh(K).h.Position;
                            c = colorbar('Position',[pos(1)+pos(3)+0.01  pos(2) 0.012 pos(4)]);
                            c.Limits = clim;
                            hL = ylabel(c,[{'\Delta Power'};{'WRT'};{myplotParams.legend{1,refErspCond_ind_reordered}};{'(dB)'}],...
                                'fontweight','bold','FontName','Arial','FontSize',8,'Rotation',0);
                            hL.Position(1) = 7;
                            hL.Position(2) = 0.2;
                        end

                        xlimits = xlim;
                        % set(gca,'XTick',[evPlotLines(1:4) xlimits(1,2)],...
                        %     'XTickLabel',{'0','','50','','100'});
                        set(gca,'XTick',[evPlotLines(1:2) xlimits(1,2)],...
                            'XTickLabel',{'0','50','100'});
                        xtickangle(45)
                        h = gca;
                        h.XRuler.TickLabelGapOffset = -2;

                        %add axes labels
                        if K==1
                            set(gca,'ytick', [4 8 13 30 50 100]);
                            ylh = ylabel(sprintf('Frequency\n(Hz)'),'fontsize',16,'fontweight','bold','FontName','Arial');
%                             ylh.Position(1) = ylh.Position(1)-400;
                        else
                            set(gca,'YTickLabel',[]);
                            ylabel('');
                        end

                        if K ~= 1
                            xlabel('');
                        else
                            xlh = xlabel('Gait Cycle (%)','Fontsize',16,'fontweight','bold');
                            %xlh.Position(2) = 2;
                            xlh.Position(2) = 1.5;
                        end

                        set(gca,'Fontsize',16);
                        T = title(myplotParams.legend{condi},'FontSize',12);
                        T.Position(2) = 200;
                        %add event lines from time warp
                        if ~isempty(evPlotLines)
                            hold on;
                            for L = 1:length(evPlotLines)
                                if L ==1 || L==length(evPlotLines)
                                    %v = vline(evPlotLines(L),'-k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1); %solid line
                                    v = vline(evPlotLines(L),'-k',eventLabels{1,L}); set(v,'LineWidth',1); %solid line
                                else
                                    %v = vline(evPlotLines(L),':k',eventLabels{1,L},[0.05 1.05]); set(v,'LineWidth',1.2);
                                    v = vline(evPlotLines(L),':k',eventLabels{1,L}); set(v,'LineWidth',1.2);
                                end
                            end
                            %                 text([evPlotLines]-80,140*ones([1,length(evPlotLines)]),eventLabels,'VerticalAlignment','top','FontSize',8)
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

                        % set figure settings
                        %             set(gca,'Fontsize',14,'fontweight','bold','FontName','Arial','YMinorTick','off');
                        set(gca,'FontName','Arial','box','on','YMinorTick','off');

                    end
                    %         sgtitle('Difference ERSP: Condition vs Baseline')
                    set(gcf,'Colormap',...
                        [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
                        'Color',[1 1 1]);

                    %% save figure
                    if compareGroupsFlag
                        sgtitle([mylabel,'-',groupNames{groupi},' group (n = ',numGroupMembers,')'],'interpreter','none')
                        figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',groupNames{groupi},'Group_condVsBaseline_',statsMethod,num2str(Alpha),'_',mcorrect,'_',mode,'_masked');
                    else
                        figname = strcat('ERSP_',myplotParams.figname,'_CL',num2str(CL),'_',mylabel,'_','_condVsBaseline_',statsMethod,num2str(Alpha),'_',mcorrect,'_',mode,'_masked');
                    end

                    savethisfig(gcf,[figname,'.png'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\png\'],'png')
                    savethisfig(gcf,[figname,'.fig'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\fig\'],'fig')
                    savethisfig(gcf,[figname,'.svg'],[savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\svg\'],'svg')
%                     if ~exist([savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\dpdf'], 'dir') %check
%                         mkdir([savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\dpdf'])
%                     end
%                     orient(gcf,'landscape')
%                     print([savePath,'\ERSP\',myplotParams.figname,'\Cond_vs_Baseline\dpdf\',figname,'.dpdf'], '-dpdf', '-painters','-bestfit') % Makoto's print method. On Linux.
%                     close;
                end
            end

            %% Compare group ERSPs
            if compareGroupsFlag && ~isempty(refErspCond)
                % find appropriate plot limits for ersp group
                % difference data
                data = [];
                for condi = 1:size(erspGroupDiff.mean,2)
                    data = [data, reshape(mean(erspDiff.mean{condi},3).',1,[])];
                end
                IQR = iqr(data); %interquartile range
                Q1 = quantile(data,0.25);
                myMin = round(Q1-1.5*IQR,1);
                erspGroupDiff_clim = [myMin myMin*(-1)];
                clim = erspGroupDiff_clim;
                
                numCond = size(erspdata.mean,2); %ref condition is empty

                figure('name',['Cls ' num2str(CL) ' ' mylabel,'_GroupDiff'],'InvertHardcopy', 'off', 'PaperType', 'a2', 'PaperOrientation', 'landscape');
                %set(gcf,'PaperUnits','inches','Units','Inches','PaperPosition',[0 0 10 3.5],'Position',[5 5 10 3.5])
                fig_width = 2*(numCond); %previously 10 for 7 cond, adjusting to so figure isnt' stretched for 1 condition
                fig_height = fig_width/2;%
                set(gcf,'PaperUnits','inches','Units','Inches','PaperPositionMode','auto','Position',[0 0 fig_width*2 fig_height*2 ],'Units','Inches');

                K = 0;
                for condi =compareCondi
                    K = K+1;
                    fh(K).h = subplot(1,length(compareCondi),K); %
                    contourf(alltimes, allfreqs,erspGroupDiff.mean{condi},200,'linecolor','none')
                    hold on;
                    %overlay transparent masked ersp, create array the same size as ersp — Use a different transparency value for each image element.
                    faceAlpha = ones(size(erspGroupDiff.pcond{condi}))*0.5; %alpha range [0-1] where 0 is fully transparent and 1 = fully opaque
                    faceAlpha (erspGroupDiff.pcond{condi} < Alpha) = 0; %set sig regions in this MASK to be fully TRANSPARENT so we can see underlying sig regions
                    imagesc(alltimes,allfreqs,erspGroupDiff.masked{condi},'AlphaData',faceAlpha)

                    set(gca,'clim',clim,'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log')
                    set(gcf,'Colormap',...
                        [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
                        'Color',[1 1 1]);

                    %resize plot to fit title
                    pos = fh(K).h.Position;
                    fh(K).h.Position =[pos(1)-0.04 pos(2)*1.8 pos(3) pos(4)*.7];

                    if condi ==compareCondi(end)
                        pos = fh(K).h.Position;
                        c = colorbar('Position',[pos(1)+pos(3)+0.01  pos(2) 0.012 pos(4)]);
                        c.Limits = clim;
                        hL = ylabel(c,[{'\Delta Power'};{'WRT'};{myplotParams.legend{1,refErspCond_ind_reordered}};{'(dB)'}],...
                            'fontweight','bold','FontName','Arial','FontSize',8,'Rotation',0);
                        hL.Position(1) = 7;
                        hL.Position(2) = 0.2;
                    end

                    xlimits = xlim;
                    set(gca,'XTick',[evPlotLines(1:end) xlimits(1,2)],...
                        'XTickLabel',{'0','','50','','100'});
                    xtickangle(45)
                    h = gca;
                    h.XRuler.TickLabelGapOffset = -2;

                    %add axes labels
                    if K==1
                        set(gca,'ytick', [4 8 13 30 50 100]);
                        ylh = ylabel(sprintf('Frequency\n(Hz)'),'fontsize',16,'fontweight','bold','FontName','Arial');
                        %                             ylh.Position(1) = ylh.Position(1)-400;
                    else
                        set(gca,'YTickLabel',[]);
                        ylabel('');
                    end

                    if K ~= 1
                        xlabel('');
                    else
                        xlh = xlabel('Gait Cycle (%)','Fontsize',16,'fontweight','bold');
                        %xlh.Position(2) = 2;
                        xlh.Position(2) = 1.5;
                    end

                    set(gca,'Fontsize',16);
                    T = title(myplotParams.legend{condi},'FontSize',12);
                    T.Position(2) = 200;
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

                    set(gca,'FontName','Arial','box','on','YMinorTick','off');

                end
                set(gcf,'Colormap',...
                    [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
                    'Color',[1 1 1]);

                    %% save figure
                        sgtitle([mylabel,'   ',groupNames{1,1},'-',groupNames{1,2},' group diff'],'interpreter','none')
                        figname = strcat('ERSP_',myplotParams.figname,num2str(CL),'_',mylabel,'_',groupNames{groupi},'GroupDiff',statsMethod,num2str(Alpha),'_',mcorrect,'_',mode,'_masked');
                    savethisfig(gcf,[figname,'.png'],[savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\png\'],'png')
                    savethisfig(gcf,[figname,'.fig'],[savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\fig\'],'fig')
                    savethisfig(gcf,[figname,'.svg'],[savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\svg\'],'svg')
%                     if ~exist([savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\dpdf'], 'dir') %check
%                         mkdir([savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\dpdf'])
%                     end
                   % orient(gcf,'landscape')
                    %print([savePath,'\ERSP\',myplotParams.figname,'\GroupDiff\dpdf\',figname,'.dpdf'], '-dpdf', '-painters','-bestfit') % Makoto's print method. On Linux.
                    close;
                    end
        end
        sfields{1,XX} = s; %for filling structure in parfor loop
        clear cond
    end
    delete(gcp('nocreate')); %shutdown parallel pool
    %fill structure using parfor results
    index = size(ersp_results,2)+1;

    %store study design info to output variable
    ersp_results(index).name = STUDY.design(design).name;
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

end


% %################### test ersp plotting methods ###########################
%    figure;tftopo(curr_ersp,alltimes,allfreqs,'logfreq','native','limits',[0 warpingvalues(end)],'vert',[evPlotLines(2:end)],'cbar','on');
%     hold on; %contour(alltimes, allfreqs, pcond{1,1},1,'linecolor','k'); %can't get contouring to work
%     figure;tftopo( maskedersp{1,c},alltimes,allfreqs,'logfreq','native','limits',[0 warpingvalues(end)],'vert',[evPlotLines(2:end)],'cbar','on');
%      set(gca,'YTick',log([4.01,8,13,30,50,99.4843]));
%     figure;tftopo(mean(averagePower,3),alltimes,allfreqs,'logfreq','native','limits',[0 warpingvalues(end)],'vert',[evPlotLines(2:end)],'cbar','on');
%
%
%
% %     maskedersp(c) = {ersp_diff.*pcond{1,1}};
%     figure; subplot(121); tftopo(erspdata(1).raw,alltimes,allfreqs,'logfreq','native','limits',[0 warpingvalues(end)],'vert',[evPlotLines(2:end)],'cbar','on');
%     colorbar;
%     title('Imagesc');
% %     figure;tftopo(ersp(1).raw,alltimes,allfreqs,'logfreq','native','limits',[0 warpingvalues(end)],'vert',[evPlotLines(2:end)],'cbar','on');
% %     contour(alltimes, allfreqs, log(ersp(1).pcond),1,'linecolor','k');
% %
% % %test, Mike Cohen
%     %figure, clf
%     subplot(122);
%     title('Contourf')
%     contourf(alltimes, allfreqs,ersp(1).raw,200,'linecolor','none')
%         set(gca,'clim',[-0.58 0.58],'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log','ytick', [5 7 9 11 13 15 18 20 23 27 31 36 42 48 56 64 80 99])
%     set(gca,'clim',[-0.5 0.5],'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log','ytick', [4 8 13 30 50 100])
%     xlabel('Time (ms)'); ylabel('Frequency (Hz)');
%     hold on;
%     contour(alltimes, allfreqs, ersp(1).pcond,1,'linecolor','k')
%     set(gca,'clim',[-0.5 0.5],'xlim',[evPlotLines(1) evPlotLines(end)],'ydir','norm','ylim',[allfreqs(1) allfreqs(end)],'yscale','log','ytick', [4 8 13 30 50 100])
%     colorbar;
%      set(gcf,'Colormap',...
%     [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0360807664692402 1 1;0.0546176768839359 1 1;0.0731545835733414 1 1;0.0916914939880371 1 1;0.110228404402733 1 1;0.128765314817429 1 1;0.147302225232124 1 1;0.165839120745659 1 1;0.184376031160355 1 1;0.20291294157505 1 1;0.221449851989746 1 1;0.239986762404442 1 1;0.258523672819138 1 1;0.277060568332672 1 1;0.295597493648529 1 1;0.314134389162064 1 1;0.332671314477921 1 1;0.351208209991455 1 1;0.36974510550499 1 1;0.388282030820847 1 1;0.406818926334381 1 1;0.425355851650238 1 1;0.443892747163773 1 1;0.46242967247963 1 1;0.480966567993164 1 1;0.499503463506699 1 1;0.518040359020233 1 1;0.53657728433609 1 1;0.555114209651947 1 1;0.573651134967804 1 1;0.592188000679016 1 1;0.610724925994873 1 1;0.62926185131073 1 1;0.647798717021942 1 1;0.666335642337799 1 1;0.684872567653656 1 1;0.703409492969513 1 1;0.721946358680725 1 1;0.740483283996582 1 1;0.759020209312439 1 1;0.777557075023651 1 1;0.796094000339508 1 1;0.814630925655365 1 1;0.833167850971222 1 1;0.851704716682434 1 1;0.870241641998291 1 1;0.888778567314148 1 1;0.90731543302536 1 1;0.925852358341217 1 1;0.944389283657074 1 1;0.962926208972931 1 1;0.981463074684143 1 1;1 1 1;1 1 0.976190447807312;1 1 0.952380955219269;1 1 0.928571403026581;1 1 0.904761910438538;1 1 0.88095235824585;1 1 0.857142865657806;1 1 0.833333313465118;1 1 0.809523820877075;1 1 0.785714268684387;1 1 0.761904776096344;1 1 0.738095223903656;1 1 0.714285731315613;1 1 0.690476179122925;1 1 0.666666686534882;1 1 0.642857134342194;1 1 0.61904764175415;1 1 0.595238089561462;1 1 0.571428596973419;1 1 0.547619044780731;1 1 0.523809552192688;1 1 0.5;1 1 0.476190477609634;1 1 0.452380955219269;1 1 0.428571432828903;1 1 0.404761910438538;1 1 0.380952388048172;1 1 0.357142865657806;1 1 0.333333343267441;1 1 0.309523820877075;1 1 0.28571429848671;1 1 0.261904776096344;1 1 0.238095238804817;1 1 0.214285716414452;1 1 0.190476194024086;1 1 0.16666667163372;1 1 0.142857149243355;1 1 0.119047619402409;1 1 0.095238097012043;1 1 0.0714285746216774;1 1 0.0476190485060215;1 1 0.0238095242530107;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
%      'Color',[1 1 1]);
%
%
%
%     figure;
%     logimagesc(alltimes,allfreqs, ersp_diff )
%     hold on;
%     logimagesc(alltimes,allfreqs, maskedersp{1,c});
%     alpha(0.5)
%     set(gcf,'Colormap',...
%         [0 0 0.515625;0 0 0.533564805984497;0 0 0.551504611968994;0 0 0.569444417953491;0 0 0.587384283542633;0 0 0.60532408952713;0 0 0.623263895511627;0 0 0.641203701496124;0 0 0.659143507480621;0 0 0.677083313465118;0 0 0.695023119449615;0 0 0.712962985038757;0 0 0.730902791023254;0 0 0.748842597007751;0 0 0.766782402992249;0 0 0.784722208976746;0 0 0.802662014961243;0 0 0.820601880550385;0 0 0.838541686534882;0 0 0.856481492519379;0 0 0.874421298503876;0 0 0.892361104488373;0 0 0.91030091047287;0 0 0.928240716457367;0 0 0.946180582046509;0 0 0.964120388031006;0 0 0.982060194015503;0 0 1;0.000649772584438324 0.0370370373129845 1;0.00129954516887665 0.0740740746259689 1;0.00194931775331497 0.111111111938953 1;0.0025990903377533 0.148148149251938 1;0.00324886292219162 0.185185179114342 1;0.00389863550662994 0.222222223877907 1;0.00454840809106827 0.259259253740311 1;0.00519818067550659 0.296296298503876 1;0.00584795325994492 0.333333343267441 1;0.00649772584438324 0.370370358228683 1;0.00714749842882156 0.407407402992249 1;0.00779727101325989 0.444444447755814 1;0.00844704359769821 0.481481492519379 1;0.00909681618213654 0.518518507480621 1;0.00974658876657486 0.555555582046509 1;0.0103963613510132 0.592592597007751 1;0.0110461339354515 0.629629611968994 1;0.0116959065198898 0.666666686534882 1;0.0123456791043282 0.703703701496124 1;0.0129954516887665 0.740740716457367 1;0.0136452242732048 0.777777791023254 1;0.0142949968576431 0.814814805984497 1;0.0149447694420815 0.851851880550385 1;0.0155945420265198 0.888888895511627 1;0.0162443146109581 0.92592591047287 1;0.0168940871953964 0.962962985038757 1;0.0175438597798347 1 1;0.0343371815979481 0.99893045425415 0.99893045425415;0.0511304996907711 0.997860968112946 0.997860968112946;0.0679238215088844 0.996791422367096 0.996791422367096;0.0847171396017075 0.995721936225891 0.995721936225891;0.10151045769453 0.994652390480042 0.994652390480042;0.118303783237934 0.993582904338837 0.993582904338837;0.135097101330757 0.992513358592987 0.992513358592987;0.151890426874161 0.991443872451782 0.991443872451782;0.168683737516403 0.990374326705933 0.990374326705933;0.185477063059807 0.989304840564728 0.989304840564728;0.20227038860321 0.988235294818878 0.988235294818878;0.219063699245453 0.987165749073029 0.987165749073029;0.235857024788857 0.986096262931824 0.986096262931824;0.25265035033226 0.985026717185974 0.985026717185974;0.269443660974503 0.983957231044769 0.983957231044769;0.286236971616745 0.98288768529892 0.98288768529892;0.30303031206131 0.981818199157715 0.981818199157715;0.319823622703552 0.980748653411865 0.980748653411865;0.336616933345795 0.97967916727066 0.97967916727066;0.353410273790359 0.978609621524811 0.978609621524811;0.370203584432602 0.977540135383606 0.977540135383606;0.386996895074844 0.976470589637756 0.976470589637756;0.403790235519409 0.975401043891907 0.975401043891907;0.420583546161652 0.974331557750702 0.974331557750702;0.437376856803894 0.973262012004852 0.973262012004852;0.454170197248459 0.972192525863647 0.972192525863647;0.470963507890701 0.971122980117798 0.971122980117798;0.487756818532944 0.970053493976593 0.970053493976593;0.504550158977509 0.968983948230743 0.968983948230743;0.521343469619751 0.967914462089539 0.967914462089539;0.538136780261993 0.966844916343689 0.966844916343689;0.554930090904236 0.965775430202484 0.965775430202484;0.571723401546478 0.964705884456635 0.964705884456635;0.588516771793365 0.963636338710785 0.963636338710785;0.605310082435608 0.96256685256958 0.96256685256958;0.62210339307785 0.96149730682373 0.96149730682373;0.638896703720093 0.960427820682526 0.960427820682526;0.655690014362335 0.959358274936676 0.959358274936676;0.672483325004578 0.958288788795471 0.958288788795471;0.689276695251465 0.957219243049622 0.957219243049622;0.706070005893707 0.956149756908417 0.956149756908417;0.72286331653595 0.955080211162567 0.955080211162567;0.739656627178192 0.954010725021362 0.954010725021362;0.756449937820435 0.952941179275513 0.952941179275513;0.773243248462677 0.951871633529663 0.951871633529663;0.790036618709564 0.950802147388458 0.950802147388458;0.806829929351807 0.949732601642609 0.949732601642609;0.823623239994049 0.948663115501404 0.948663115501404;0.840416550636292 0.947593569755554 0.947593569755554;0.857209861278534 0.946524083614349 0.946524083614349;0.874003171920776 0.9454545378685 0.9454545378685;0.890796542167664 0.944385051727295 0.944385051727295;0.907589852809906 0.943315505981445 0.943315505981445;0.924383163452148 0.94224601984024 0.94224601984024;0.941176474094391 0.941176474094391 0.941176474094391;0.942352950572968 0.942352950572968 0.922352969646454;0.943529427051544 0.943529427051544 0.903529405593872;0.944705903530121 0.944705903530121 0.884705901145935;0.945882380008698 0.945882380008698 0.865882337093353;0.947058796882629 0.947058796882629 0.847058832645416;0.948235273361206 0.948235273361206 0.828235268592834;0.949411749839783 0.949411749839783 0.809411764144897;0.950588226318359 0.950588226318359 0.79058825969696;0.951764702796936 0.951764702796936 0.771764695644379;0.952941179275513 0.952941179275513 0.752941191196442;0.954117655754089 0.954117655754089 0.73411762714386;0.955294132232666 0.955294132232666 0.715294122695923;0.956470608711243 0.956470608711243 0.696470618247986;0.957647085189819 0.957647085189819 0.677647054195404;0.958823561668396 0.958823561668396 0.658823549747467;0.959999978542328 0.959999978542328 0.639999985694885;0.961176455020905 0.961176455020905 0.621176481246948;0.962352931499481 0.962352931499481 0.602352917194366;0.963529407978058 0.963529407978058 0.583529412746429;0.964705884456635 0.964705884456635 0.564705908298492;0.965882360935211 0.965882360935211 0.545882344245911;0.967058837413788 0.967058837413788 0.527058839797974;0.968235313892365 0.968235313892365 0.508235275745392;0.969411790370941 0.969411790370941 0.489411771297455;0.970588207244873 0.970588207244873 0.470588237047195;0.97176468372345 0.97176468372345 0.451764702796936;0.972941160202026 0.972941160202026 0.432941168546677;0.974117636680603 0.974117636680603 0.414117634296417;0.97529411315918 0.97529411315918 0.39529412984848;0.976470589637756 0.976470589637756 0.376470595598221;0.977647066116333 0.977647066116333 0.357647061347961;0.97882354259491 0.97882354259491 0.338823527097702;0.980000019073486 0.980000019073486 0.319999992847443;0.981176495552063 0.981176495552063 0.301176458597183;0.98235297203064 0.98235297203064 0.282352954149246;0.983529388904572 0.983529388904572 0.263529419898987;0.984705865383148 0.984705865383148 0.244705885648727;0.985882341861725 0.985882341861725 0.225882351398468;0.987058818340302 0.987058818340302 0.207058817148209;0.988235294818878 0.988235294818878 0.18823529779911;0.989411771297455 0.989411771297455 0.169411763548851;0.990588247776031 0.990588247776031 0.150588229298592;0.991764724254608 0.991764724254608 0.131764709949493;0.992941200733185 0.992941200733185 0.112941175699234;0.994117617607117 0.994117617607117 0.0941176488995552;0.995294094085693 0.995294094085693 0.0752941146492958;0.99647057056427 0.99647057056427 0.056470587849617;0.997647047042847 0.997647047042847 0.0376470573246479;0.998823523521423 0.998823523521423 0.018823528662324;1 1 0;1 0.984375 0;1 0.96875 0;1 0.953125 0;1 0.9375 0;1 0.921875 0;1 0.90625 0;1 0.890625 0;1 0.875 0;1 0.859375 0;1 0.84375 0;1 0.828125 0;1 0.8125 0;1 0.796875 0;1 0.78125 0;1 0.765625 0;1 0.75 0;1 0.734375 0;1 0.71875 0;1 0.703125 0;1 0.6875 0;1 0.671875 0;1 0.65625 0;1 0.640625 0;1 0.625 0;1 0.609375 0;1 0.59375 0;1 0.578125 0;1 0.5625 0;1 0.546875 0;1 0.53125 0;1 0.515625 0;1 0.5 0;1 0.484375 0;1 0.46875 0;1 0.453125 0;1 0.4375 0;1 0.421875 0;1 0.40625 0;1 0.390625 0;1 0.375 0;1 0.359375 0;1 0.34375 0;1 0.328125 0;1 0.3125 0;1 0.296875 0;1 0.28125 0;1 0.265625 0;1 0.25 0;1 0.234375 0;1 0.21875 0;1 0.203125 0;1 0.1875 0;1 0.171875 0;1 0.15625 0;1 0.140625 0;1 0.125 0;1 0.109375 0;1 0.09375 0;1 0.078125 0;1 0.0625 0;1 0.046875 0;1 0.03125 0;1 0.015625 0;1 0 0;0.984375 0 0;0.96875 0 0;0.953125 0 0;0.9375 0 0;0.921875 0 0;0.90625 0 0;0.890625 0 0;0.875 0 0;0.859375 0 0;0.84375 0 0;0.828125 0 0;0.8125 0 0;0.796875 0 0;0.78125 0 0;0.765625 0 0;0.75 0 0;0.734375 0 0;0.71875 0 0;0.703125 0 0;0.6875 0 0;0.671875 0 0;0.65625 0 0;0.640625 0 0;0.625 0 0;0.609375 0 0;0.59375 0 0;0.578125 0 0;0.5625 0 0;0.546875 0 0;0.53125 0 0;0.515625 0 0;0.5 0 0],...
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
%         set(gcf,'Colormap',...
%             [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
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
%         set(gca,'XTick',[evPlotLines(1:end) xlimits(1,2)],...
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
%     set(gcf,'Colormap',...
%         [0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
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
    'Colormap',[0 0 0.515625;0 0 0.531770825386047;0 0 0.547916650772095;0 0 0.564062476158142;0 0 0.580208361148834;0 0 0.596354186534882;0 0 0.612500011920929;0 0 0.628645837306976;0 0 0.644791662693024;0 0 0.660937488079071;0 0 0.677083313465118;0 0 0.693229138851166;0 0 0.709375023841858;0 0 0.725520849227905;0 0 0.741666674613953;0 0 0.7578125;0 0 0.773958325386047;0 0 0.790104150772095;0 0 0.806249976158142;0 0 0.822395861148834;0 0 0.838541686534882;0 0 0.854687511920929;0 0 0.870833337306976;0 0 0.886979162693024;0 0 0.903124988079071;0 0 0.919270813465118;0 0 0.935416638851166;0 0 0.951562523841858;0 0 0.967708349227905;0 0 0.983854174613953;0 0 1;0.000427899009082466 0.0243902429938316 1;0.000855798018164933 0.0487804859876633 1;0.00128369708545506 0.0731707289814949 1;0.00171159603632987 0.0975609719753265 1;0.00213949498720467 0.121951222419739 1;0.00256739417091012 0.14634145796299 1;0.00299529312178493 0.170731708407402 1;0.00342319207265973 0.195121943950653 1;0.00385109125636518 0.219512194395065 1;0.00427898997440934 0.243902444839478 1;0.00470688939094543 0.26829269528389 1;0.00513478834182024 0.29268291592598 1;0.00556268729269505 0.317073166370392 1;0.00599058624356985 0.341463416814804 1;0.00641848519444466 0.365853667259216 1;0.00684638414531946 0.390243887901306 1;0.00727428309619427 0.414634138345718 1;0.00770218251273036 0.439024388790131 1;0.00813008099794388 0.463414639234543 1;0.00855797994881868 0.487804889678955 1;0.00898587983101606 0.512195110321045 1;0.00941377878189087 0.53658539056778 1;0.00984167773276567 0.560975611209869 1;0.0102695766836405 0.585365831851959 1;0.0106974756345153 0.609756112098694 1;0.0111253745853901 0.634146332740784 1;0.0115532735362649 0.658536612987518 1;0.0119811724871397 0.682926833629608 1;0.0124090714380145 0.707317054271698 1;0.0128369703888893 0.731707334518433 1;0.0132648693397641 0.756097555160522 1;0.0136927682906389 0.780487775802612 1;0.0141206672415137 0.804878056049347 1;0.0145485661923885 0.829268276691437 1;0.0149764660745859 0.853658556938171 1;0.0154043650254607 0.878048777580261 1;0.0158322639763355 0.902438998222351 1;0.0162601619958878 0.926829278469086 1;0.0166880618780851 0.951219499111176 1;0.0171159598976374 0.97560977935791 1;0.0175438597798347 1 1;0.0349708907306194 0.998890101909637 0.998890101909637;0.0523979216814041 0.99778026342392 0.99778026342392;0.0698249489068985 0.996670365333557 0.996670365333557;0.0872519835829735 0.995560467243195 0.995560467243195;0.104679010808468 0.994450628757477 0.994450628757477;0.122106045484543 0.993340730667114 0.993340730667114;0.139533072710037 0.992230832576752 0.992230832576752;0.156960099935532 0.991120994091034 0.991120994091034;0.174387127161026 0.990011096000671 0.990011096000671;0.191814169287682 0.988901197910309 0.988901197910309;0.209241196513176 0.987791359424591 0.987791359424591;0.22666822373867 0.986681461334229 0.986681461334229;0.244095250964165 0.985571563243866 0.985571563243866;0.26152229309082 0.984461724758148 0.984461724758148;0.278949320316315 0.983351826667786 0.983351826667786;0.296376347541809 0.982241928577423 0.982241928577423;0.313803374767303 0.981132090091705 0.981132090091705;0.331230401992798 0.980022192001343 0.980022192001343;0.348657429218292 0.97891229391098 0.97891229391098;0.366084456443787 0.977802455425262 0.977802455425262;0.383511513471603 0.9766925573349 0.9766925573349;0.400938540697098 0.975582659244537 0.975582659244537;0.418365567922592 0.97447282075882 0.97447282075882;0.435792595148087 0.973362922668457 0.973362922668457;0.453219622373581 0.972253024578094 0.972253024578094;0.470646649599075 0.971143186092377 0.971143186092377;0.48807367682457 0.970033288002014 0.970033288002014;0.505500733852386 0.968923449516296 0.968923449516296;0.522927761077881 0.967813551425934 0.967813551425934;0.540354788303375 0.966703653335571 0.966703653335571;0.55778181552887 0.965593814849854 0.965593814849854;0.575208842754364 0.964483916759491 0.964483916759491;0.592635869979858 0.963374018669128 0.963374018669128;0.610062897205353 0.962264180183411 0.962264180183411;0.627489924430847 0.961154282093048 0.961154282093048;0.644916951656342 0.960044384002686 0.960044384002686;0.662343978881836 0.958934545516968 0.958934545516968;0.67977100610733 0.957824647426605 0.957824647426605;0.697198033332825 0.956714749336243 0.956714749336243;0.714625060558319 0.955604910850525 0.955604910850525;0.732052087783813 0.954495012760162 0.954495012760162;0.749479115009308 0.9533851146698 0.9533851146698;0.766906142234802 0.952275276184082 0.952275276184082;0.784333229064941 0.951165378093719 0.951165378093719;0.801760256290436 0.950055480003357 0.950055480003357;0.81918728351593 0.948945641517639 0.948945641517639;0.836614310741425 0.947835743427277 0.947835743427277;0.854041337966919 0.946725845336914 0.946725845336914;0.871468365192413 0.945616006851196 0.945616006851196;0.888895392417908 0.944506108760834 0.944506108760834;0.906322419643402 0.943396210670471 0.943396210670471;0.923749446868896 0.942286372184753 0.942286372184753;0.941176474094391 0.941176474094391 0.941176474094391;0.942577004432678 0.942577004432678 0.918767511844635;0.94397759437561 0.94397759437561 0.896358549594879;0.945378184318542 0.945378184318542 0.873949587345123;0.94677871465683 0.94677871465683 0.851540625095367;0.948179244995117 0.948179244995117 0.829131662845612;0.949579834938049 0.949579834938049 0.806722700595856;0.950980424880981 0.950980424880981 0.7843137383461;0.952380955219269 0.952380955219269 0.761904776096344;0.953781485557556 0.953781485557556 0.739495813846588;0.955182075500488 0.955182075500488 0.717086851596832;0.95658266544342 0.95658266544342 0.694677889347076;0.957983195781708 0.957983195781708 0.672268927097321;0.959383726119995 0.959383726119995 0.649859964847565;0.960784316062927 0.960784316062927 0.627451002597809;0.962184906005859 0.962184906005859 0.605042040348053;0.963585436344147 0.963585436344147 0.582633078098297;0.964985966682434 0.964985966682434 0.560224115848541;0.966386556625366 0.966386556625366 0.537815153598785;0.967787146568298 0.967787146568298 0.51540619134903;0.969187676906586 0.969187676906586 0.492997199296951;0.970588207244873 0.970588207244873 0.470588237047195;0.971988797187805 0.971988797187805 0.44817927479744;0.973389387130737 0.973389387130737 0.425770312547684;0.974789917469025 0.974789917469025 0.403361350297928;0.976190447807312 0.976190447807312 0.380952388048172;0.977591037750244 0.977591037750244 0.358543425798416;0.978991627693176 0.978991627693176 0.33613446354866;0.980392158031464 0.980392158031464 0.313725501298904;0.981792688369751 0.981792688369751 0.291316539049149;0.983193278312683 0.983193278312683 0.268907576799393;0.984593868255615 0.984593868255615 0.246498599648476;0.985994398593903 0.985994398593903 0.22408963739872;0.98739492893219 0.98739492893219 0.201680675148964;0.988795518875122 0.988795518875122 0.179271712899208;0.990196108818054 0.990196108818054 0.156862750649452;0.991596639156342 0.991596639156342 0.134453788399696;0.992997169494629 0.992997169494629 0.11204481869936;0.994397759437561 0.994397759437561 0.089635856449604;0.995798349380493 0.995798349380493 0.0672268941998482;0.997198879718781 0.997198879718781 0.044817928224802;0.998599410057068 0.998599410057068 0.022408964112401;1 1 0;1 0.97826087474823 0;1 0.95652174949646 0;1 0.93478262424469 0;1 0.91304349899292 0;1 0.89130437374115 0;1 0.869565188884735 0;1 0.847826063632965 0;1 0.826086938381195 0;1 0.804347813129425 0;1 0.782608687877655 0;1 0.760869562625885 0;1 0.739130437374115 0;1 0.717391312122345 0;1 0.695652186870575 0;1 0.673913061618805 0;1 0.652173936367035 0;1 0.630434811115265 0;1 0.60869562625885 0;1 0.58695650100708 0;1 0.56521737575531 0;1 0.54347825050354 0;1 0.52173912525177 0;1 0.5 0;1 0.47826087474823 0;1 0.45652174949646 0;1 0.434782594442368 0;1 0.413043469190598 0;1 0.391304343938828 0;1 0.369565218687057 0;1 0.347826093435287 0;1 0.326086968183517 0;1 0.304347813129425 0;1 0.282608687877655 0;1 0.260869562625885 0;1 0.239130437374115 0;1 0.217391297221184 0;1 0.195652171969414 0;1 0.173913046717644 0;1 0.152173906564713 0;1 0.130434781312943 0;1 0.108695648610592 0;1 0.0869565233588219 0;1 0.0652173906564713 0;1 0.0434782616794109 0;1 0.0217391308397055 0;1 0 0;0.988372087478638 0 0;0.976744174957275 0 0;0.965116262435913 0 0;0.953488349914551 0 0;0.941860437393188 0 0;0.930232584476471 0 0;0.918604671955109 0 0;0.906976759433746 0 0;0.895348846912384 0 0;0.883720934391022 0 0;0.872093021869659 0 0;0.860465109348297 0 0;0.848837196826935 0 0;0.837209284305573 0 0;0.82558137178421 0 0;0.813953459262848 0 0;0.80232560634613 0 0;0.790697693824768 0 0;0.779069781303406 0 0;0.767441868782043 0 0;0.755813956260681 0 0;0.744186043739319 0 0;0.732558131217957 0 0;0.720930218696594 0 0;0.709302306175232 0 0;0.69767439365387 0 0;0.686046540737152 0 0;0.67441862821579 0 0;0.662790715694427 0 0;0.651162803173065 0 0;0.639534890651703 0 0;0.627906978130341 0 0;0.616279065608978 0 0;0.604651153087616 0 0;0.593023240566254 0 0;0.581395328044891 0 0;0.569767415523529 0 0;0.558139562606812 0 0;0.546511650085449 0 0;0.534883737564087 0 0;0.523255825042725 0 0;0.511627912521362 0 0;0.5 0 0],...
    'Color',[1 1 1]);

% Create axes
axes1 = axes('Parent',figure1,'Position',[0.299 0.198 0.4 0.5705]);
hold(axes1,'on');

% Create contour
contour(xdata1,ydata1,zdata1,'LineColor','none',...
    'LevelList',[-1.19419531289604 -1.18275948460044 -1.17132365630483 -1.15988782800923 -1.14845199971362 -1.13701617141802 -1.12558034312241 -1.11414451482681 -1.1027086865312 -1.0912728582356 -1.07983702993999 -1.06840120164438 -1.05696537334878 -1.04552954505317 -1.03409371675757 -1.02265788846196 -1.01122206016636 -0.999786231870752 -0.988350403575147 -0.976914575279541 -0.965478746983936 -0.95404291868833 -0.942607090392725 -0.93117126209712 -0.919735433801514 -0.908299605505909 -0.896863777210303 -0.885427948914698 -0.873992120619092 -0.862556292323487 -0.851120464027881 -0.839684635732276 -0.82824880743667 -0.816812979141065 -0.805377150845459 -0.793941322549854 -0.782505494254249 -0.771069665958643 -0.759633837663038 -0.748198009367432 -0.736762181071827 -0.725326352776221 -0.713890524480616 -0.70245469618501 -0.691018867889405 -0.6795830395938 -0.668147211298194 -0.656711383002589 -0.645275554706983 -0.633839726411378 -0.622403898115772 -0.610968069820167 -0.599532241524561 -0.588096413228956 -0.57666058493335 -0.565224756637745 -0.55378892834214 -0.542353100046534 -0.530917271750929 -0.519481443455323 -0.508045615159718 -0.496609786864112 -0.485173958568507 -0.473738130272901 -0.462302301977296 -0.45086647368169 -0.439430645386085 -0.427994817090479 -0.416558988794874 -0.405123160499269 -0.393687332203663 -0.382251503908058 -0.370815675612452 -0.359379847316847 -0.347944019021241 -0.336508190725636 -0.32507236243003 -0.313636534134425 -0.30220070583882 -0.290764877543214 -0.279329049247608 -0.267893220952003 -0.256457392656398 -0.245021564360792 -0.233585736065187 -0.222149907769581 -0.210714079473976 -0.19927825117837 -0.187842422882765 -0.17640659458716 -0.164970766291554 -0.153534937995949 -0.142099109700343 -0.130663281404738 -0.119227453109132 -0.107791624813527 -0.0963557965179214 -0.0849199682223158 -0.0734841399267103 -0.0620483116311048 -0.0506124833354995 -0.039176655039894 -0.0277408267442885 -0.0163049984486832 -0.00486917015307764 0.00656665814252788 0.0180024864381332 0.0294383147337387 0.0408741430293442 0.0523099713249495 0.063745799620555 0.0751816279161606 0.0866174562117659 0.0980532845073714 0.109489112802977 0.120924941098582 0.132360769394188 0.143796597689793 0.155232425985399 0.166668254281004 0.17810408257661 0.189539910872215 0.200975739167821 0.212411567463426 0.223847395759032 0.235283224054637 0.246719052350242 0.258154880645848 0.269590708941453 0.281026537237059 0.292462365532664 0.30389819382827 0.315334022123875 0.32676985041948 0.338205678715086 0.349641507010692 0.361077335306297 0.372513163601902 0.383948991897508 0.395384820193113 0.406820648488719 0.418256476784324 0.42969230507993 0.441128133375535 0.452563961671141 0.463999789966746 0.475435618262352 0.486871446557957 0.498307274853562 0.509743103149168 0.521178931444773 0.532614759740379 0.544050588035984 0.55548641633159 0.566922244627195 0.5783580729228 0.589793901218406 0.601229729514011 0.612665557809617 0.624101386105222 0.635537214400828 0.646973042696433 0.658408870992039 0.669844699287644 0.68128052758325 0.692716355878855 0.704152184174461 0.715588012470066 0.727023840765672 0.738459669061277 0.749895497356882 0.761331325652488 0.772767153948093 0.784202982243699 0.795638810539304 0.80707463883491 0.818510467130515 0.82994629542612 0.841382123721726 0.852817952017331 0.864253780312937 0.875689608608542 0.887125436904148 0.898561265199753 0.909997093495359 0.921432921790964 0.93286875008657 0.944304578382175 0.955740406677781 0.967176234973386 0.978612063268992 0.990047891564597 1.0014837198602 1.01291954815581 1.02435537645141 1.03579120474702 1.04722703304262 1.05866286133823 1.07009868963384 1.08153451792944 1.09297034622505]);

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