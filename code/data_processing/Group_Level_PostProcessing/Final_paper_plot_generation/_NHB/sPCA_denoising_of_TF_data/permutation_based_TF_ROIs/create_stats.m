function stats = create_stats()

    mlt_clst_path = ['D:\Morteza\MyProjects\ANSYMB2024\data\7_STUDY', ...
    '\Epoched_data\multiple_clustering\'];
    eeglab_path = 'D:\Morteza\Toolboxes\EEGLAB\eeglab2025.1.0';
    curr_path = ['D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab\' ...
        'data_processing\Group_Level_PostProcessing\' ...
        'Final_paper_plot_generation\_NHB\' ...
        'sPCA_denoising_of_TF_data\permutation_based_TF_ROIs'];

    cd(eeglab_path)
    eeglab
    cd(curr_path)

    STUDY_File_Name = 'Right_Prim_Motor.study';
    STUDY_File_Path = strcat(mlt_clst_path, STUDY_File_Name);
    STUDY_File_Path = STUDY_File_Path(1:end-6);

   
    [STUDY ALLEEG] = pop_loadstudy('filename', STUDY_File_Name, ...
        'filepath', STUDY_File_Path);
    [STUDY, ~] = std_maketrialinfo(STUDY, ALLEEG);


    STUDY = std_makedesign(STUDY, ALLEEG, 1, ...
        'name', '3-condition design', ...
        'delfiles', 'off', 'defaultdesign', 'off', ...
        'variable1', 'cond', 'values1', {'1','3','6'}, ...
        'vartype1','categorical', ...
        'pairing','on'); % within-subject since every subject did all conds
    
    STUDY = add_anatomical_labels(STUDY, eeglab_path);

    % adjust clusters so there's one subject per cluster using 
    % lowest IC number (highest explained standard deviation)
    STUDY = oneSubPerCluster(STUDY); 

    condstats ='on';        % ['on'|'off]
    statsMethod ='perm';    % ['param'|'perm'|'bootstrap']
    Alpha = 0.01;           % [NaN|alpha], Significance threshold (0<alpha<<1) ***hard coded this in places to skip certain stats, be careful if changing to diff vaule
    mcorrect = 'cluster'; % fdr
    mode = 'fieldtrip';
    singletrials = 'off' ;  % ['on'|'off'] load single trials spectral data (if available). Default is 'off'.

    STUDY = pop_statparams(STUDY, 'condstats', condstats,...
        'method',statsMethod,...
        'singletrials',singletrials,'mode', mode,'fieldtripalpha',Alpha,...
        'fieldtripmethod','montecarlo','fieldtripmcorrect',mcorrect);

    tmpSTUDY = pop_statparams(STUDY, 'condstats', condstats,...
        'method', statsMethod, 'singletrials', singletrials, ...
        'mode', mode, 'fieldtripalpha', Alpha, ...
        'fieldtripmethod', 'montecarlo', ...
        'fieldtripmcorrect', mcorrect, ...
        'fieldtripnaccu', 10000);

    statstruct.etc = tmpSTUDY.etc; 


    stats = statstruct.etc.statistics;
    stats.fieldtrip.channelneighbor = struct([]); % asumes one channel or 1 component
    if isempty(STUDY.design(1).variable)
        stats.paired = { };
    else
        stats.paired = { STUDY.design(1).variable(:).pairing };
    end
    stats.groupstats = 'off';
    % stats.condstats  = 'off'; 
    
   
end