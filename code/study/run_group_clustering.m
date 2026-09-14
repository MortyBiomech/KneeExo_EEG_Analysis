% run_group_clustering.m
% Stage 4. Build the STUDY, precluster it, and run the repeated clustering
% that produces one solution per region of interest.
%
%   epoched datasets  ->  STUDY  ->  preclustered STUDY  ->  one clustering
%                                                            solution per ROI
%
% Four stages, each switchable below. Every stage loads what it needs from
% disk, so you can run them one at a time across sessions and you never have
% to load a STUDY through the EEGLAB GUI between stages.
%
% Stage 3 and stage 4 both take a long time. Stage 4 is 200 k-means runs per
% region.

clc
clear


%% Paths
% config/ is always two levels up from code/<stage>/.
% Locate config/, which is always two levels up from code/<stage>/.
%
% mfilename is empty when these lines are pasted into the command window,
% and reports a temporary helper file when a single %% section is run with
% Ctrl+Enter, so neither case can be trusted. Fall back to this file's own
% name, which resolves whenever the file is runnable at all.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('run_group_clustering');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_group_clustering.m and press Run, ' ...
           'or make its folder the current folder first. Pasting the ' ...
           'bootstrap into the command window gives MATLAB nothing to ' ...
           'resolve the path from.']);
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg, 'bemobil');   % this stage needs the BeMoBIL pipeline

if isempty(cfg.raw)
    error(['This stage reads the epoched single-subject datasets. ' ...
           'Set cfg.raw in config/local_paths.m.']);
end

epoched_folder = cfg.epoched;
study_folder   = cfg.studyEpoched;


%% What to run
% Participants that enter the group analysis. Note this is not the same list
% as the preprocessing entry points: 1 to 4 are preprocessed but excluded
% here.
subject_list = cfg.subjects;   % 5:18

run_build_study  = true;   % stage 1: the two main STUDY files
run_precomp_topo = true;   % stage 2: IC topographies, the .icatopo files
run_precluster   = true;   % stage 3: bemobil_precluster
run_clustering   = true;   % stage 4: repeated clustering per region

% Passed through to bemobil_repeated_clustering_and_evaluation. Set both to 0
% to re-rank existing solutions without recomputing them.
do_clustering        = 1;
do_multivariate_data = 1;


%% Preclustering settings
clustering_weights = struct();
clustering_weights.dipoles = 3;
clustering_weights.scalp   = 1;
clustering_weights.spec    = 0;   % spectra not used

precluster_freqrange  = [1 70];
precluster_timewindow = [];


%% Repeated clustering settings
outlier_sigma = 3;    % SD boundary for outlier detection
n_iterations  = 200;  % k-means runs per region

% One clustering solution per region. Each region gets its own k and its own
% quality weights, tuned so that one cluster in the winning solution lands on
% the region of interest.
%
% The six quality weights are, in order:
%   1 number of participants in the cluster
%   2 ICs per participant
%   3 normalised spread
%   4 mean residual variance
%   5 distance from the ROI
%   6 Mahalanobis distance from the median of the multivariate distribution
% Positive rewards, negative penalises. So the tuning reads as: many
% participants, few ICs each, tight, low RV, close to the ROI.
%
% MNI coordinates: https://bioimagesuiteweb.github.io/webapp/mni2tal.html
%
% Authoritative record: every clustering folder carries a study_info.txt
% written by the run that produced it. If a value here disagrees with one of
% those files, the file is right and this table has drifted.
regions = struct( ...
    'name',    {'Right_Prim_Motor', ...
                'Right_PreMot_SuppMot', ...
                'Right_Parieto_Occipital', ...
                'Prime_Visual', ...
                'Left_Prim_Motor', ...
                'Left_PreMot_SuppMot', ...
                'Left_Parieto_Occipital'}, ...
    'roi',     {[ 43, -27, 41], ...
                [ 15,  15, 60], ...
                [ 35, -65, 40], ...
                [  0, -85,  5], ...
                [-38, -28, 59], ...
                [-15,  15, 60], ...
                [-35, -65, 40]}, ...
    'k',       {12, 13, 8, 9, 13, 10, 9}, ...
    'weights', {[1000  -900  -900  -10  -100  -100], ...
                [1000  -900  -900  -10  -100  -100], ...
                [2000  -300  -500  -10  -400  -100], ...
                [1000  -200  -100  -10  -500  -100], ...
                [2000  -300  -500  -10  -400  -100], ...
                [1100  -900 -1200  -10  -100  -100], ...
                [2000  -200  -500  -10  -300  -100]});

% Run only some of them by name, or leave empty for all.
regions_to_run = {};


%% Initialize EEGLAB
if ~exist('ALLCOM', 'var')
    eeglab;
end

if ~exist(study_folder, 'dir')
    mkdir(study_folder);
end

study_name_brain = 'main_study_potential_brain_ICs_RV-15_epochedData.study';
study_name_preclust = [study_name_brain(1:end-6), '_preclustered.study'];


%% Stage 1: build the two main STUDY files
if run_build_study

    disp('--- Stage 1: building the STUDY files ---');

    [STUDY, ALLEEG] = build_study_files(subject_list, ...
        epoched_folder, study_folder);

else

    disp('--- Stage 1 skipped, loading the STUDY from disk ---');
    [STUDY, ALLEEG] = pop_loadstudy('filename', study_name_brain, ...
        'filepath', study_folder);

end

EEG = ALLEEG;
CURRENTSTUDY = 1; CURRENTSET = 1:numel(ALLEEG); %#ok<NASGU>


%% Stage 2: IC topographies
% Preclustering weights the scalp maps, so the .icatopo files have to exist
% before stage 3.
if run_precomp_topo

    disp('--- Stage 2: precomputing IC topographies ---');

    [STUDY, ALLEEG] = std_precomp(STUDY, ALLEEG, 'components', ...
        'scalp', 'on', 'recompute', 'on');

end


%% Stage 3: preclustering
if run_precluster

    disp('--- Stage 3: preclustering ---');

    [STUDY, ALLEEG, EEG] = bemobil_precluster(STUDY, ALLEEG, EEG, ...
        clustering_weights, precluster_freqrange, precluster_timewindow, ...
        study_name_preclust(1:end-6), study_folder);

end


%% Stage 4: repeated clustering, one solution per region
if run_clustering

    disp('--- Stage 4: repeated clustering ---');

    preclust_file = fullfile(study_folder, study_name_preclust);
    if ~exist(preclust_file, 'file')
        listing = dir(fullfile(study_folder, '*.study'));
        error('run_group_clustering:NoPreclusteredStudy', ...
            ['The preclustered STUDY is not on disk:\n  %s\n\n' ...
             'STUDY files present in that folder:\n  %s\n\n' ...
             'Run stage 3, or correct study_name_preclust to match what ' ...
             'bemobil_precluster wrote.'], ...
            preclust_file, strjoin({listing.name}, sprintf('\n  ')));
    end

    if isempty(regions_to_run)
        selected = 1:numel(regions);
    else
        selected = find(ismember({regions.name}, regions_to_run));
        missing  = setdiff(regions_to_run, {regions.name});
        if ~isempty(missing)
            error('run_group_clustering:UnknownRegion', ...
                'No region named %s in the table.', strjoin(missing, ', '));
        end
    end

    for S = selected

        region = regions(S);
        fprintf('\n=========== %s ===========\n', region.name);
        fprintf('ROI %s, k = %d, %d iterations\n', ...
            mat2str(region.roi), region.k, n_iterations);

        % Reload the preclustered STUDY for every region, because the
        % previous region's run leaves its own solution in STUDY.cluster.
        [STUDY, ALLEEG] = pop_loadstudy('filename', study_name_preclust, ...
            'filepath', study_folder);
        EEG = ALLEEG;

        cluster_ROI_MNI = struct('x', region.roi(1), ...
                                 'y', region.roi(2), ...
                                 'z', region.roi(3));

        filepath_STUDY = fullfile(study_folder, 'multiple_clustering', ...
            region.name);
        if ~exist(filepath_STUDY, 'dir')
            mkdir(filepath_STUDY);
        end

        % Record what this run actually used, next to what it produces. This
        % file, not the table above, is the authoritative record.
        write_study_info(fullfile(filepath_STUDY, 'study_info.txt'), ...
            region, n_iterations, outlier_sigma, subject_list);

        filepath_clustering_solutions = fullfile(filepath_STUDY, ...
            'clustering_solutions');
        filename_clustering_solutions = [region.name, '_clustering_solutions'];

        filepath_multivariate_data = fullfile(filepath_STUDY, ...
            'multivariate_data');
        filename_multivariate_data = [region.name, '_multivariate_data'];

        [STUDY, ALLEEG, EEG] = ...
            bemobil_repeated_clustering_and_evaluation(STUDY, ALLEEG, EEG, ...
            outlier_sigma, region.k, n_iterations, cluster_ROI_MNI, ...
            region.weights, do_clustering, do_multivariate_data, ...
            filepath_STUDY, region.name, ...
            filepath_clustering_solutions, filename_clustering_solutions, ...
            filepath_multivariate_data, filename_multivariate_data);

        fprintf('%s done. Best fitting cluster: %d\n', region.name, ...
            STUDY.etc.bemobil.clustering.cluster_ROI_index);

    end

end

disp('GROUP LEVEL POSTPROCESSING DONE.');


% ------------------------------------------------------------------------
function write_study_info(filename, region, n_iterations, outlier_sigma, subject_list)
% Record the settings of this run beside its output.

    fid = fopen(filename, 'w');
    if fid == -1
        error('Cannot open file: %s', filename);
    end

    fprintf(fid, 'STUDY Name = %s\n', region.name);
    fprintf(fid, 'Region of Interest = %s\n', num2str(region.roi));
    fprintf(fid, 'Number of Clusters = %d\n', region.k);
    fprintf(fid, 'Quality Measure Weights = %s\n', num2str(region.weights));
    fprintf(fid, 'Repeated Clustering Iterations = %d\n', n_iterations);
    fprintf(fid, 'Outlier Sigma = %d\n', outlier_sigma);
    fprintf(fid, 'Subjects = %s\n', mat2str(subject_list));
    fprintf(fid, 'Written = %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));

    fclose(fid);

end
