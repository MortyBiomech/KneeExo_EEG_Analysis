% Step9_group_results_plotting
% Plots ERSPs,spectra, dipoles & centroids together, or pulls up gui
% Assumes the study is clustered
% ERSP and PSD results saved in .mat structurse
%
%Authors:
%   Noelle Jacobsen,University of Florida
%   Also includes code from Steve Peterson, University of Michigan and
%   Makoto's useful EEGLAB code
%   Created 10/17/21
%   Last updated 3/14/23
%
%close all; clc; %clear all;
%%%%%%%%%%%%%%%%%%%%%%%%%% SET THESE OPTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define input and output paths
% If subject code for convenience
% RootData = uigetdir('R:\\Ferris-Lab\\jacobsen.noelle\\Exo Adaptation\\Data\\processed_data\\','Select STUDY folder');
% studyname = dir( fullfile(RootData, '*.study'));
% savePath = [RootData filesep 'Figures' filesep];
% savePath = 'D:\Morteza\MyProjects\ANSYMB2024\data\7_STUDY\Epoched_data\Final_figures';
% eeglabpath = 'C:\Users\jacobsen.noelle\Desktop\eeglab2022.0';
% eeglabpath = 'D:\Morteza\Toolboxes\EEGLAB\eeglab2025.1.0';
% codeRepo = 'R:\Ferris-Lab\jacobsen.noelle\Matlab_Scripts\ExoAdapt-EEG-Processing\';
% addpath(genpath(codeRepo))


%parameters
savePlots = 1; %1 - save plots; 0 - don't save
plotSpectra = 1; %1- plot PSD; 0 - don't plot
plotERSPs= 1; %1 - plot ERSPs; 0 - no ERSPs
plotDipCentroids=0; %1 - plot dipoles and centroids; 0 - don't plot
pullUpClustGUI=0; %1 - pulls up study cluster gui at end; 0 - don't pull it up
plotTopo =0;% 1- plot scalp topographies 0- don't plot
saveSTUDY=0; %save study at end of processing
loadSTUDY=0; %1 - loads in study; 0 - study already loaded
centrDipsTogether=1; %1 - plot centroids and dipoles together; 0 - only dipoles
one_sub_per_cl =2; % 2 = take lowest number IC/ highest variance IC)
erspParamOverride =[];  %override parameters stored in ica.timef
compareGroups = 0; % compare different groups ERSPs (manaully) using groups names stored in STUDY.datasetinfo.group

%dipole colors
% colors2use={[1 0 0], [0 1 0], [0 0 1], [1 0 1], [0 1 1], [.8549 .6471 .1255], [1 .4902 0], ... %[1 1 0], [1 .4902 0], ...
%     [1 .0784 .5765], [.8 0 1], [.6 0 0], [0 0 0]};
% colors2use={[0.2 0.4 0.6], [0.2 0 0.6],[0.2 0.8 0.6], [0.4 0 0.6], [0.6 0.4 1], [0.6 1.0 1.0], [1 0 0.6], ... %[1 1 0], [1 .4902 0], ...
%     [1 0.6 0.6], [1 0 0.2], [1 0.6 0.2], [1 1 0.2], [0.4 0.8 0],[0.4 0.4 0],[0.4 0 0],[0 1 1],[0.9 0.9 0.9]};


colors2use={[ 0    0.3804    0.5686], [1.0000    0.8824    0.1098],[0.4118    0.1216    1.0000],..., 
   [0.3020    0.7451    0.9333],  [0.9843    0.7882    1.0000], ... %[1 1 0], [1 .4902 0], ...
    [0.5765    0.8314    0.4000], [1 0.6 0.2],[1 1 0.2]}; %for just my manusript 1


% colors2use={[0.2 0.4 0.6], [0.4 0 0.6], [0.6 0.4 1], [0.6 1.0 1.0], ... %[1 1 0], [1 .4902 0], ...
%     [1 0.6 0.6], [1 0.6 0.2],[1 1 0.2]}; %for just my manusript 2, clusters_to_plot= [3 6:8 10 13 14];
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Start up EEGLAB if not running already
% if ~exist('ALLCOM')
%     addpath(eeglabpath);
%     eeglab
% end

% Edit eeg_options.m file
pop_editoptions( 'option_storedisk', 1, 'option_savetwofiles', 1, ...
  'option_single', 1, 'option_memmapdata', 0, ...
    'option_computeica', 1, 'option_scaleicarms', 1, 'option_rememberfolder', 1);

% cd(RootData)
% if ~isdir(savePath)
%     mkdir(savePath)
% end
% if loadSTUDY==1
%     %Load in study
%     [STUDY ALLEEG] = pop_loadstudy('filename', [studyname.name], 'filepath', RootData);
%     CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
% end

% clusters of interest
clusters_to_plot = 4; %[3 4 6 10 11 12];
%clusters_to_plot = setdiff(3:length(STUDY.cluster),clusters_to_plot)

%% compare groups
% if compareGroups
% % add group names to STUDY
% load('R:\Ferris-Lab\jacobsen.noelle\Split Belt Pilot Study\STUDY-CustomHDM-EEG\Learning Groups\adaptGroups.mat')
% %add group names to STUDY
% for subi = 1:length(STUDY.datasetinfo)
%     studysub = STUDY.datasetinfo(subi).subject;
%     i = find(strcmp(adaptGroups.subject,studysub));
%     group = adaptGroups.M3_equalSplit(i);
%     STUDY.datasetinfo(subi).group = group{1,1};
% end
% % Save STUDY
% if saveSTUDY==1
%     [STUDY EEG] = pop_savestudy( STUDY, EEG, 'filename',STUDY.filename,'filepath',STUDY.filepath);
%     CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
% end
% end


%% Get plotting parameters
plotParams = getplotParams;
% Get ERSPs, bootstrap, and then plot them
cd(savePath)
clc;
tStart = tic;
if plotERSPs == 1
    %Plots time-frequency spectral power

    if ~exist('ersp_results','var')
        ersp_results = struct;
    end

    for p = 1 % if there are several STUDY designs, p can take other values as well.
        % if compareGroups  
        %     plotParams(p).compareGroups = 'on';
        % end
        STUDY = std_selectdesign(STUDY, ALLEEG, plotParams(p).design);
        if ~isdir([savePath,'\ERSP\',plotParams(p).figname])
            mkdir([savePath,'\ERSP\',plotParams(p).figname])
        end
        cd([savePath,'\ERSP\',plotParams(p).figname])
        diary ON
        disp(date)
        tic
        fprintf('ERSPs for %s\n Subject List:\n',plotParams(p).figname)
        fprintf('-%s\n',STUDY.design(STUDY.currentdesign).cases.value{:})
        ersp_results = plotERSPSfromSTUDY(STUDY, ALLEEG, savePath, ...
            plotParams(p), clusters_to_plot, one_sub_per_cl, ...
            erspParamOverride, ersp_results);
        save([savePath,'\ERSP\',plotParams(p).figname,'\','ersp_results.mat'],'ersp_results','-mat')
    end

    cd(savePath)
    diary ON
    disp(date)
    disp('Elapsed time:')
    toc(tStart)
    diary OFF
end

%Make stats summary table-- don't do range of p values, bad stats practice
% for i = 1:length(ersp_results)
%     for CL = 1:size(ersp_results(i).data)
%         cond_num = size(ersp_results(i).data(CL).erspDiff,2);
%         for condi = 1:cond_num
%             if ~isempty(ersp_results(i).data(CL).erspDiff(condi).pcond)
%                 pcond = ersp_results(i).data(CL).erspDiff(condi).pcond;
%                 pmax = max(pcond,[],"all");
%                 pmin = min(pcond,[],"all")
%          T = table()
%
%             end
%         end
%     end
% end


%Elapsed time is 14727.056387 seconds., no parallel computing

% %% plot spectra
% if ~exist('psd_results','var')
%     psd_results = struct([]);
%     i = 0;
% else
%     i = size(psd_results,2);
% end
% plotParams = getplotParams;
% %%
% tStart = tic;
% if plotSpectra ==1
% 
%     for p= [2]
%         STUDY = std_selectdesign(STUDY, ALLEEG, plotParams(p).design);
%         [STUDY EEG] = pop_savestudy( STUDY, EEG, 'savemode','resave');
%         if ~isdir([savePath,'\PSD\',plotParams(p).figname])
%             mkdir([savePath,'\PSD\',plotParams(p).figname])
%         end
%         cd([savePath,'\PSD\',plotParams(p).figname])
%         diary ON
%         disp(date)
%         tic
%         fprintf('PSDs for %s\n Subject List:\n',plotParams(p).figname)
%         fprintf('-%s\n',STUDY.design(STUDY.currentdesign).cases.value{:})
%         i = i+1;
%         STUDY.etc.specparams.freqrange =[4 30];
%         [all_cond] = plot_smooth_spec_from_study(STUDY,ALLEEG,savePath,clusters_to_plot,one_sub_per_cl,plotParams(p),plotTopo);
% 
%         %cond = plot_smooth_chan_spec_from_study(STUDY,ALLEEG,savePath,channels_to_plot,plotParams(p),plotTopo);
%         psd_results(i).design = plotParams(p).design;
%         psd_results(i).conditions = plotParams(p).legend;
%         psd_results(i).name = plotParams(p).figname;
%         psd_results(i).data = all_cond;
%         toc
%         diary OFF
% 
%         %% psd stats table
%         %         psd_results(i).stats = psd_stats(psd_results(i));
%         %         writetable(struct2table(psd_results(i).stats),[savePath,'\PSD\',plotParams(p).figname,'\summaryStatistics.csv']);
%         fprintf('\nFreq Band\td(max)\t\tmax effect freq\t\t effect window \t\t 95%%CI\t\t\t\tCL\n')
%         fprintf('___________________________________________________________________________________________\n')
%         for i = 1:size(all_cond,2)
%             if size(all_cond(i).cluster_perm_test,2)>1
%                 for xx = 2:size(all_cond(i).cluster_perm_test,2)
%                     tmp = all_cond(i).cluster_perm_test(xx);
%                     fprintf('\n%s',tmp.name)
%                     fprintf('\t\t%.3f\t\t%.3f',tmp.effect.COHENS_D_max,tmp.effect.maxeffectfreq)
%                     fprintf('\t\t\t\t[%.3f %.3f]',tmp.effect.window(1), tmp.effect.window(2))
%                     fprintf('\t\t[%.3f %.3f]',tmp.effect.CI95(1), tmp.effect.CI95(2))
%                       try
%                         fprintf('\t\t%s',all_cond(i).label{1,1})
%                     catch
%                         fprintf('\t\t%s',all_cond(i).label)
%                     end
%                 end
%             end
% 
%         end
%     end
% end
% %%
% cd(savePath)
% save([savePath,'\PSD\',plotParams(p).figname,'\psd_results.mat'],'psd_results');
% diary ON
% disp(date)
% disp('Elapsed time is')
% toc(tStart)
% diary OFF
% 
% 
% %% Plot dipoles and centroids
% if plotDipCentroids==1
%     STUDY= diplotfig(STUDY,ALLEEG,clusters_to_plot, colors2use(1:length(clusters_to_plot)),[savePath,'/Dipoles'],centrDipsTogether,one_sub_per_cl);
% end
% %% Plot scalp topography
% if plotTopo ==1
%     for CL = clusters_to_plot
%     cd(STUDY.filepath)
%     STUDY = std_topoplot(STUDY,ALLEEG,'clusters',CL, 'design','gridscale',100);
%     set(gcf,'Color','w')
%     savethisfig(gcf,['topo_Cls',num2str(CL)],[savePath,'\Topo'],'png')
%     savethisfig(gcf,['topo_Cls',num2str(CL)],[savePath,'\Topo'],'svg')
%     cd([savePath,'\Topo'])
%     I = imread([pwd,'\topo_Cls',num2str(CL),'.png']);
%     topofig = imcrop(I,[214.5 254.5 817 900]);
%     imwrite(topofig,[[savePath,'\Topo'],'\topo_Cls',num2str(CL),'.png']);
%     savethisfig(gcf,['topo_Cls',num2str(CL)],[savePath,'\Topo'],'svg')
%     close;
%     end
% end
% %% Pull up cluster visualization interface
% if pullUpClustGUI==1
%     [STUDY]=pop_clustedit(STUDY,ALLEEG);
% end
% 
% 
% 
% % Save STUDY
% if saveSTUDY==1
%     [STUDY EEG] = pop_savestudy( STUDY, EEG, 'filename',studyname.name,'filepath',RootData);
%     CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
% end
% 
% %close all;
% disp('Study results have been plotted.');
% disp('Step 9 Finished!');
% disp('Study results have been plotted.');




% %average psd stats
% % or use commonly defined frequency bands
% function stats = psd_stats(psd)
% stats = struct([]);
% cond = psd.legend;
% if size(cond,2)~= size(psd.data,2)
%     error('Number of conditions doesn''t match size of psd data');
% end
% for CLi=1:size(psd.data,2)
%     allconddata = psd.data(CLi).data.allpsd;
%     freqs = psd.data(CLi).data.freqs;
%     for condi = 1:size(allconddata,1)
%         data = allconddata{condi,1}; %[freq x sub]
%         theta = mean(data(freqs>=4 & freqs<7,:),1); %avg data in freq band, [1 x subs]
%         alpha = mean(data(freqs>=8 & freqs<13,:),1);
%         beta = mean(data(freqs>=13 & freqs<30,:),1);
%         gamma = mean(data(freqs>=30 & freqs<128,:),1);
%
%         freqBand = {'theta','alpha','beta','gamma'};
%         for f = 1:length(freqBand)
%             tmpdata = eval(freqBand{1,f});
%             stats(end+1).CL = psd.data(CLi).cluster;
%             stats(end).CL_label = psd.data(CLi).label;
%             stats(end).Condition = psd.legend{1,condi};
%             stats(end).Freq = freqBand{1,f};
%             stats(end).Mean = mean(tmpdata);
%             stats(end).SD = std(tmpdata);
%         end
%     end
% end
%   end