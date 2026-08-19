clc
clear


%% Add paths
addpath(genpath('D:\Morteza\MyProjects\ANSYMB2024\Code'))
icatimef_epoched_data_path = ['D:\Morteza\MyProjects\ANSYMB2024\data\', ...
    '5_single-subject-EEG-analysis\timewarp_test\Epoched_data'];
mlt_clst_path = ['D:\Morteza\MyProjects\ANSYMB2024\data\7_STUDY', ...
    '\Epoched_data\multiple_clustering\'];


%% run eeglab
current_path = pwd;
if ~exist("ALLEEG", "var")
    cd('D:\Morteza\Toolboxes\EEGLAB\eeglab2025.1.0')
    eeglab
end
cd(current_path)


%% Run one of the multiple clustering STUDY files from the GUI
% For example Right_Prim_Motor

% Note: we need STUDY and ALLEEG variables to pass them to the next
%       function which is mod_std_precomp_v_forEEGlabv2021 that will 
%       precomputes ERSP data for ICs present in the STUDY.

% Note: It doesn't matter which STUDY from the multiple clusterig solutions
%       to be loaded as the ICs which are present in all of them are the
%       same.
STUDY_File_Names = {'Right_Prim_Motor.study', ...
                    'Right_PreMot_SuppMot.study', ...
                    'Right_Parieto_Occipital.study', ...
                    'Prime_Visual.study', ...
                    'Left_Prim_Motor.study', ...
                    'Left_PreMot_SuppMot.study', ...
                    'Left_Parieto_Occipital.study', ...
                    'Left_Dorsal_ACC.study'};

STUDY_File_Paths = strcat(mlt_clst_path, STUDY_File_Names);
STUDY_File_Paths = cellfun(@(x) x(1:end-6), STUDY_File_Paths, ...
    'UniformOutput', false);


[STUDY ALLEEG] = pop_loadstudy('filename', STUDY_File_Names{1}, ...
            'filepath', STUDY_File_Paths{1});
[STUDY, trialinfo] = std_maketrialinfo(STUDY, ALLEEG);


%% Group Ananlysis

% cond2Analyze={'B1','B2','B3','SB1','P1','SB2','P2'}; %NJacobsen; right now, only choose cond or sessions. Leave the other empty
% cond2Analyze={'B3','SB1_early','SB1late_','SB2_early','SB2late_','P2late_','SB1_perturbation_','SB2_perturbation_'};
% cond2Analyze = {};
% sessions2Analyze = {}; %NJacobsen
TW = 1; %NJacobsen; use subject's time warp; [1=ON, 0=OFF ]
groupmedian_timewarpms = 1; 
% NJacobsen; warp each subject's
%            tw matrix to the entire group's median event
%            latencies [1=ON], or use individual subject's
%            median event latencies [0=OFF]. TW must be ON
%            for this setting to do anything



% Options to choose for this
% createStudy = 1; %1 - create a study from scratch; 0 - load study
% redrawAfterStudyCreated = 1; %1 - eeglab redraw and break so can look at study; 0 - continue on
% preclust = 1; %1 - precluster study; 0 - no preclustering
% clust = 1; %1 - precluster study; 0 - no preclustering
% precomp_nonERSPs = 0; %1 - pulls up precompute gui; 0 - no gui
precomp_ersp = 1; %1 - precompute ersps; 0 - don't precompute ersps
erspComp = 'light'; %'light' - quicker computation; 'full' - with usual parameters (takes longer)
% showClusterPlotGUI = 1; %1 - show cluster plot gui at end; 0 - don't show it (and clear study)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% global ALLEEG EEG CURRENTSET ALLCOM CURRENTSTUDY STUDY eeglabpath;





%% Precompute ERSPs - This step has been done and the .icatimef files have been saved on the disc!
if precomp_ersp == 1
    tic

    if TW == 1
        % Run ERSPs (timewarped)
        if groupmedian_timewarpms == 1 
            warps = zeros(length(ALLEEG),length(ALLEEG(1,1).timewarp.warpto)); %NJ; stored in ALLEEG.timewarp.warpto
            for i= 1:length(ALLEEG)
                warps(i,:) = ALLEEG(1,i).timewarp.warpto; %NJ; stored in ALLEEG.timewarp.warpto
            end
            roundNear = 50; % round numbers to the closest multiple of this value
            warpingvalues = round(median(warps)/roundNear)*roundNear;
        elseif groupmedian_timewarpms == 0 %use subject specific warpto values
            warpingvalues = zeros(1,length(ALLEEG(1,1).timewarp.warpto)); %% zeros are place holder so subject time warp can be filled in later
        end

        switch erspComp
            case 'full'
                % tic
                % [STUDY, ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'components','ersp','on','itc','off','erspparams',{'cycles',[3 0.8],'alpha',0.05, 'padratio',2,'savetrials','off','baseline',NaN,'basenorm','on','trialbase','full','timewarp',[0],'timewarpms', warpingvalues}, 'recompute','on'); %timewarp = 0 as space holder so subject time warp can be filled in later, recompute on/off didnt' affect ERSP computation
                % [STUDY ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'channels','ersp','on','itc','off','erspparams',{'cycles',[3 0.8],'alpha',0.05, 'padratio',2,'savetrials','off','baseline','median latency baseline','timewarp',[0],'timewarpms', warpingvalues}, 'recompute','on'); %timewarp = 0 as space holder so subject time warp can be filled in later, recompute on/off didnt' affect ERSP computation
                % toc
            case 'light'
                tic
                % Parameters suggested by Makoto
                % [STUDY, ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'components','ersp','on','itc','off','erspparams',{'cycles',[3 0.8],'freqs',[3 100],'padratio',2,'alpha',NaN,'freqscale','log','savetrials','off','baseline',[0 1200],'basenorm','off','trialbase','full','timewarp',[0],'timewarpms', warpingvalues}, 'recompute','on'); %timewarp = 0 as space holder so subject time warp can be filled in later
                % [STUDY ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'channels','ersp','on','itc','off','erspparams',{'cycles',[3 0.8],'alpha',NaN, 'padratio',2,'savetrials','off','baseline','median latency baseline','timewarp',[0],'timewarpms', warpingvalues}, 'recompute','on'); %timewarp = 0 as space holder so subject time warp can be filled in later, recompute on/off didnt' affect ERSP computation

                % I implemented this line: 
                % Open: decoding_mod_std_precomp_v_forEEGlabv2021_function 
                [STUDY, ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, 'components', ...
                    'ersp','on','itc','off', ...
                    'erspparams', {'cycles', [3 0.8], 'freqs', [3 130], 'nfreqs', 250, ...
                                   'padratio', 2, 'alpha', NaN, 'freqscale', 'log', ...
                                   'savetrials', 'off', 'baseline', 'median latency baseline', ...
                                   'basenorm', 'off', 'trialbase', 'off', ...
                                   'timewarp', [0], 'timewarpms', warpingvalues}, 'recompute','on');
                toc
            otherwise
                error('Incorrect case for erspComp!');
        end
    end
    toc
end




%% Work on the STUDY

savePath = 'D:\Morteza\MyProjects\ANSYMB2024\data\7_STUDY\Epoched_data\Final_figures';
eeglabpath = 'D:\Morteza\Toolboxes\EEGLAB\eeglab2025.1.0';

% Make a within-subject design using the 'cond' column in trialinfo
% STUDY = std_makedesign(STUDY, ALLEEG, 1, ...
%   'name','3-condition design', ...
%   'trialinfo','cond', ...
%   'values', {'1','3','6'}, ...
%   'pairing','on');   % within-subject since every subject did all conds

% STUDY = std_makedesign(STUDY, ALLEEG, 1, ...
%     'name', '3-condition design', ...
%     'delfiles', 'off', 'defaultdesign', 'off', ...
%     'variable1', 'cond', 'values1', {'1','3','6'}, ...
%     'vartype1','categorical', ...
%     'pairing','on'); % within-subject since every subject did all conds
% 
% STUDY = add_anatomical_labels(STUDY, eeglabpath);
% 
% % adjust clusters so there's one one subject per cluster using 
% % lowest IC number (highest explained standard deviation)
% STUDY = oneSubPerCluster(STUDY); 




%% plot ERSP on the cluster and subject level

% parameters
savePlots = 1;           % 1 - save plots; 0 - don't save
plotSpectra = 1;         % 1 - plot PSD; 0 - don't plot
plotERSPs = 1;           % 1 - plot ERSPs; 0 - no ERSPs
plotDipCentroids = 0;    % 1 - plot dipoles and centroids; 0 - don't plot
pullUpClustGUI = 0;      % 1 - pulls up study cluster gui at end; 0 - don't pull it up
plotTopo = 0;            % 1 - plot scalp topographies; 0 - don't plot
saveSTUDY = 0;           % save study at end of processing
loadSTUDY = 0;           % 1 - loads in study; 0 - study already loaded
centrDipsTogether = 1;   % 1 - plot centroids and dipoles together; 0 - only dipoles
one_sub_per_cl = 2;      % 2 = take lowest number IC/ highest variance IC)
compareGroups = 0;       % compare different groups ERSPs (manaully) using groups names stored in STUDY.datasetinfo.group




% Edit eeg_options.m file
pop_editoptions( 'option_storedisk', 1, 'option_savetwofiles', 1, ...
    'option_single', 1, 'option_memmapdata', 0, ...
    'option_computeica', 1, 'option_scaleicarms', 1, ...
    'option_rememberfolder', 1);



%% load ersp parameters from one of the .icatimef files
% load one .icatimef file to have the erspparam 
icatimef_filepath = ['D:\Morteza\MyProjects\ANSYMB2024\data\', ...
    '5_single-subject-EEG-analysis\timewarp_test\Epoched_data'];
S5_icatimef = load('-mat', fullfile(icatimef_filepath, 'S5.icatimef'), ...
    'trialinfo', 'parameters', 'times');
erspParamOverride = S5_icatimef.parameters;
% freqs_index = find(strcmpi(erspParamOverride, 'freqs'));
% erspParamOverride{freqs_index + 1} = [2.9, 130.1];



%% Correct the trialinfo structure in icatimef data (takes time!) 
% - not necessary anymore! I recomputed the icatimef data with correct trialinfo
% - Apparantly I should use:
%   [STUDY, trialinfo] = std_maketrialinfo(STUDY, ALLEEG) to correct trialinfo

% subject_list = 5:18;
% cd(icatimef_epoched_data_path)
% for sub = 1:length(subject_list)
%     disp(['S', num2str(subject_list(sub))])
%     all_trials = load('-mat', fullfile(icatimef_epoched_data_path, ...
%         '\backup 29 Nov 2025', ...
%         ['S', num2str(subject_list(sub)), '.icatimef']));
%     all_trials.trialinfo = trialinfo{sub};
%     filenametrials = [ 'S', num2str(subject_list(sub)) ,'.icatimef' ]; 
%     std_savedat( filenametrials , all_trials );
% end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Main Multiple Clusters ERSP Plotting Part
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


cd(savePath)
clc;
tStart = tic;
if plotERSPs == 1

    for study = 1:length(STUDY_File_Names)

        [STUDY ALLEEG] = pop_loadstudy('filename', STUDY_File_Names{study}, ...
            'filepath', STUDY_File_Paths{study});
        [STUDY, trialinfo] = std_maketrialinfo(STUDY, ALLEEG);
        CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
        eeglab redraw;

        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % % it is a bit complicated here:
        % %    we should find the equivalent IC numbers (comps) from old
        % %    study in the new study by comparing the dipole locations. 
        % if study == 4
        % % for the Prim Visual Cluster we need the previous version
        % old_fileName = 'main_study_potential_brain_ICs_RV-15_Prime_Visual (0, -85, 10).study';
        % old_filePath = 'D:\Morteza\MyProjects\ANSYMB2024\data\7_STUDY\multiple_clustering\_Final_Selected_Clusters\Prime_Visual (0, -85, 10)';
        % STUDY_old = pop_loadstudy('filename', old_fileName, 'filepath', old_filePath);
        % old_clusters_to_plot = STUDY_old.etc.bemobil.clustering.cluster_ROI_index;
        % 
        % epsilon = 1e-3;
        % old_dipoles_locs = STUDY_old.cluster(old_clusters_to_plot).all_diplocs;
        % SC_recompute_icatimef = []; % subjects and comps need to recompute icatimef
        % new_subjects = [];
        % new_comps = [];
        % for dip = 1:length(old_dipoles_locs)
        %     dip_old = old_dipoles_locs(dip, :);
        % 
        %     subject = STUDY_old.cluster(old_clusters_to_plot).sets(dip);
        %     comp_old = STUDY_old.cluster(old_clusters_to_plot).comps(dip);
        % 
        %     subject_comps_in_mainStd = STUDY.datasetinfo(subject).comps;
        %     model = ALLEEG(subject).dipfit.model;
        %     dip_comps_mainStd = vertcat(model.posxyz);
        % 
        %     dip_old = repmat(dip_old, size(dip_comps_mainStd, 1), 1);
        %     difference = sqrt( sum(( dip_comps_mainStd - dip_old ).^2, 2) );
        % 
        %     dip_new_indx = find(difference < epsilon);
        %     if length(dip_new_indx) > 1
        %         epsilon = epsilon*1e-6;
        %         dip_new_indx = find(difference < epsilon);
        %     end
        %     if isempty(dip_new_indx)
        %         dip_new_indx = find(difference < 2);
        %     end
        % 
        %     new_subjects = [new_subjects, subject];
        %     new_comps = [new_comps, dip_new_indx];
        % 
        %     if ~ismember(dip_new_indx, subject_comps_in_mainStd)
        %         SC_recompute_icatimef = [SC_recompute_icatimef; subject dip_new_indx];
        %     end
        % 
        % end
        % % Now we need to change the cluster, preclust, and etc fields
        % STUDY.cluster = STUDY_old.cluster;
        % STUDY.preclust = STUDY_old.preclust;
        % STUDY.etc.bemobil = STUDY_old.etc.bemobil;
        % STUDY.etc.preclust = STUDY_old.etc.preclust;
        % end
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        STUDY = std_makedesign(STUDY, ALLEEG, 1, ...
            'name', '3-condition design', ...
            'delfiles', 'off', 'defaultdesign', 'off', ...
            'variable1', 'cond', 'values1', {'1','3','6'}, ...
            'vartype1','categorical', ...
            'pairing','on'); % within-subject since every subject did all conds
        
        STUDY = add_anatomical_labels(STUDY, eeglabpath);

        % adjust clusters so there's one subject per cluster using 
        % lowest IC number (highest explained standard deviation)
        STUDY = oneSubPerCluster(STUDY); 

        % clusters of interest (from the results of repeated multiple clustering)
        clusters_to_plot = STUDY.etc.bemobil.clustering.cluster_ROI_index;


        % Get plotting parameters
        STUDY_title = STUDY.filename;
        % Remove extension
        nameWithoutExt = erase(STUDY_title, ".study");
        % Replace underscores with spaces
        STUDY_title = strrep(nameWithoutExt, "_", " ");
        
        plotParams = getplotParams(STUDY_title);


        % Plots time-frequency spectral power
        if ~exist('ersp_results','var')
            ersp_results = struct;
        end
    
        for p = 1 
            % if there are several STUDY designs, 
            % p can take other values as well.
            
            
            STUDY = std_selectdesign(STUDY, ALLEEG, plotParams(p).design);
            
            if ~isfolder([savePath,'\ERSP\',plotParams(p).figname])
                mkdir([savePath,'\ERSP\',plotParams(p).figname])
            end
            cd([savePath,'\ERSP\',plotParams(p).figname])
            diary ON
            disp(datetime('today'))
            tic
            fprintf('ERSPs for %s\n Subject List:\n',plotParams(p).figname)
            fprintf('-%s\n',STUDY.design(STUDY.currentdesign).cases.value{:})
            
            ersp_results = my_plotERSPSfromSTUDY(STUDY, ALLEEG, savePath, ...
                plotParams(p), clusters_to_plot, one_sub_per_cl, ...
                erspParamOverride, STUDY_title, ersp_results);
            filePath = [savePath, '\ERSP\', plotParams(p).figname, '\'];
            fileName = [char(STUDY_title), ' ersp_results','.mat'];
            save(fullfile(filePath, fileName),'ersp_results','-mat')
        
        end
    
    end

    cd(savePath)
    diary ON
    disp(datetime('today'))
    disp('Elapsed time:')
    toc(tStart)
    diary OFF

end









