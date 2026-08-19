function plotParams = getplotParams(title)
%set up parameters to plot PSDs for multiple condition comparisons
%% setup colors
%https://en.wikipedia.org/wiki/List_of_colors:_A%E2%80%93F
atomicTangerine = [1 .6 .4];
burntOrange = [.8 .33 0];
orange = [0.8500, 0.3250, 0.0980];
lightOrange = [1,0.8,0.4];
green =  [0.4660, 0.6740, 0.1880];
darkGreen =  [0.0667    0.2196    0.0980];
cyan = [0.3010, 0.7450, 0.9330];
blue = [0,0.625,1];
darkBlue = [0,0.156,1];
lightRed = [1 0.6 0.6];
red2 = [1 0.16 0.16];
Bloodred = [.4 0 0];
claret = [.5 0.09 .2];
darkRed = [0.55 , 0, 0];
fieryRose = [1 .33 .44];
yellow = [0.9290, 0.6940, 0.1250];
lightPurple =  [0.6 0.4 1];
darkPurple = [0.2 0 0.6];
darkPurple2 = [0.1647    0.1529    0.4353];
pink = [1 0 0.6];
purple = [0.75 0.2 0.8];
bdazzledblue = [0.18 0.35 0.58];
beauBlue = [0.74 0.83 0.9];
BlackCoral = [.33 .38 .44];
maroon = [.6 .2 0.3];
blush = [.9 .3 0.5];
limeGreen = [0.9020    1.0000    0.2588];
pink2 =  [0.9098    0.4078    0.7765];
darkpink2 = [0.5412    0.1843    0.4431];
%test colors
% figure; plot([1 5],[1 1],'color',Bloodred,'LineWidth',4);
% hold on; plot([1 5],[1.1 1.1],'color',burntOrange,'LineWidth',4);
% plot([1 5],[1.2 1.2],'color',atomicTangerine,'LineWidth',4);
% plot([1 5],[1.3 1.3],'color',lightOrange,'LineWidth',4);
% plot([1 5],[1.4 1.4],'color',orange,'LineWidth',4);

% %color assignments for each condition
% noexoc = [0.6 0.6 0.6];
% unpowc = BlackCoral;
% EAc = blue;
P1 = blue;
% LAc = darkBlue;
% EPAc= limeGreen;
P3 = limeGreen;
% LPAc= darkGreen;
P6 = lightRed;

% x = [1:10];
% y = ones([1,10]);
% figure; plot(x,y,'color',noexoc,'LineWidth',2);
% hold on;
% plot(x,y.*1.1,'color',unpowc,'LineWidth',2);
% plot(x,y.*1.2,'color',EAc,'LineWidth',2);
% plot(x,y.*1.3,'color',LAc,'LineWidth',2);
% plot(x,y.*1.4,'color',EPAc,'LineWidth',2);
% plot(x,y.*1.4,'color',LPAc,'LineWidth',2);


clear atomicTangerine burntOrange orange lightOrange purple green darkGreen cyan blue darkBlue lightRed red2 Bloodred claret darkRed
clear fieryRose yellow lightPurple darkPurple pink bdazzledblue beauBlue BlackCoral maroon blush


%% Three pressure conditions
plotParams(1).design = 1;
plotParams(1).labels = {'1', '3', '6'};
plotParams(1).colors = [{P1},{P3},{P6}];
plotParams(1).figname = 'Three Pressure Conditions';
plotParams(1).title = title;
plotParams(1).legend = [{'Low Pressure'}, {'Medium Pressure'}, {'High Pressure'}];
plotParams(1).refCond = '1';
plotParams(1).compareGroups = 0; % logical, compare groups based on STUDY.group





% %% abrupt adaptation- slow baseline
% plotParams(2).design = 2;
% plotParams(2).labels = {'noExo','unpow','early adapt','late adapt','early post-adapt','late post-adapt'};
% plotParams(2).colors = [{noexoc},{unpowc},{EAc},{LAc},{EPAc},{LPAc}];
% plotParams(2).figname = 'all_subcond';
% plotParams(2).title = 'Exo Adaptation:';
% plotParams(2).legend = [{'no exo'},{'unpowered'},{'early adapt.'},{'late adapt.'},{'early post-adapt.'},{'late post-adapt.'}];
% plotParams(2).refCond = 'noExo';
% plotParams(2).testCond = 'early adapt';
% plotParams(2).compareGroups = 0; %logical, compare groups based on STUDY.group


% Exo only
% plotParams(3).design = 3;
% plotParams(3).labels = {'unpow','early adapt','late adapt','early post-adapt','late post-adapt'};
% plotParams(3).colors = [{unpowc},{EAc},{LAc},{EPAc},{LPAc}];
% plotParams(3).figname = 'Exo Only';
% plotParams(3).title = 'Exo Adaptation:';
% plotParams(3).legend = [{'unpowered'},{'early adapt.'},{'late adapt.'},{'early post-adapt.'},{'late post-adapt.'}];
% plotParams(3).refCond = 'unpow';
% plotParams(3).compareGroups = 0; %logical, compare groups based on STUDY.group

% Adapt only
% plotParams(4).design = 4;
% plotParams(4).labels = {'noExo','unpow','early adapt','late adapt'};
% plotParams(4).colors = [{noexoc},{unpowc},{EAc},{LAc},{EPAc},{LPAc}];
% plotParams(4).figname = 'Exo Only';
% plotParams(4).title = 'Exo Adaptation:';
% plotParams(4).legend = [{'no Exo'},{'unpowered'},{'early adapt.'},{'late adapt.'}];
% plotParams(4).refCond = 'noExo';
% plotParams(4).compareGroups = 0; %logical, compare groups based on STUDY.group

% %% EMG
% %abrupt adaptation - med baseline
% plotParams(10).design = 1;
% plotParams(10).labels = {'B3 late','SB1 early','SB1 late','P1 early','P1 late'}; % put in the order you want to see plotted
% plotParams(10).colors = [{B3c},{SB1ec},{SB1lc},{P1ec},{P1lc}];
% plotParams(10).figname = 'PSD_B3_A1_EMG_Ch';
% plotParams(10).title = 'Abrupt Adaptation Spectrum: EMG Chan ';
% plotParams(10).legend = [{'baseline (0.9 m/s)'},{'early adaptation'},{'late adaptation'},{'early post-adaptation'},{'late post-adaptation'}];
% 
% %abrupt adaptation - fast baseline
% plotParams(11).design = 2;
% plotParams(11).labels = {'B2 late','SB1 early','SB1 late','P1 early','P1 late'};
% plotParams(11).colors = [{B2c},{SB1ec},{SB1lc},{P1ec},{P1lc}];
% plotParams(11).figname = 'PSD_B2_A1_EMG_Ch';
% plotParams(11).title = 'Abrupt Adaptation Spectrum: EMG Chan ';
% plotParams(11).legend = [{'baseline (1.2 m/s)'},{'early adaptation'},{'late adaptation'},{'early post-adaptation'},{'late post-adaptation'}];
% 
% %abrupt adaptation with perturbation - medium baseline
% plotParams(12).design = 3;
% plotParams(12).labels =  {'B3 late','SB1 perturbation','SB1 early','SB1 late','P1 perturbation','P1 early','P1 late'};
% plotParams(12).colors = [{B3c},{SB1pc},{SB1ec},{SB1lc},{P1pc},{P1ec},{P1lc}];
% plotParams(12).figname = 'PSD_B3_A1_perturb_EMG_Ch';
% plotParams(12).title = 'Abrupt Adaptation Spectrum: EMG Chan ';
% plotParams(12).legend = [{'baseline (0.9 m/s)'},{'split perturbation'},{'early adaptation'},{'late adaptation'},{'tied pertubation'},{'early post-adaptation'},{'late post-adaptation'}];
% 
% %abrupt adaptation with perturbation - fast baseline
% plotParams(13).design = 4;
% plotParams(13).labels = {'B2 late','SB1 perturbation','SB1 early','SB1 late','P1 perturbation','P1 early','P1 late'};
% plotParams(13).colors = [{B2c},{SB1pc},{SB1ec},{SB1lc},{P1pc},{P1ec},{P1lc}];
% plotParams(13).figname = 'PSD_B2_perturb_A1_EMG_Ch';
% plotParams(13).title = 'Abrupt Adaptation Spectrum: EMG Chan ';
% plotParams(13).legend = [{'baseline (1.2 m/s)'},{'split perturbation'},{'early adaptation'},{'late adaptation'},{'tied pertubation'},{'early post-adaptation'},{'late post-adaptation'}];
% 
% %abrupt adaptation with perturbation - fast baseline
% plotParams(14).design = 5;
% plotParams(14).labels = {'B1','B3','B2'};
% plotParams(14).colors = [{B2c},{SB1pc},{SB1ec},{SB1lc},{P1pc},{P1ec},{P1lc}];
% plotParams(14).figname = 'PSD_B1_B3_B2_EMG_Ch';
% plotParams(14).title = 'Abrupt Adaptation Spectrum: EMG Chan ';
% plotParams(14).legend = [{'0.6 m/s)'},{'0.9 m/s'},{'1.2 m/s'}];