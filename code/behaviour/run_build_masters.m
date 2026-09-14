% run_build_masters.m
% Stage B1. Build the master tables the behaviour branch runs on.
%
%   epoched trial data (stage 2)  ->  emg_master_*.mat
%                                     trk_master_*.mat
%                                     behaviour_table.mat
%
% This is the entry point for the behaviour, EMG and tracking analyses. It
% branches off the EEG chain at stage 2 and never rejoins it: stage 3 goes
% back to the cleaned datasets from stage 1.
%
% THE ARCHITECTURE, IN ONE SENTENCE. Every raw trial and every raw epoch
% gets a row, no row is ever removed, quality is recorded as boolean columns,
% and the screening happens once, later, in screen_epochs.
%
% That is not tidiness. The previous pipeline compacted trial indices in the
% EMG builder but not in the tracking one, so the two disagreed for subjects
% 9, 11, 12 and 18, and within a trial it read signals at the raw epoch index
% but event boundaries at a compacted one. Neither fault announces itself:
% the values stay valid and simply attach to the wrong row.
%
% Run it in one go, or section by section.
%
% Prerequisites
%   * cfg.raw set in config/local_paths.m
%   * stage 2 complete, so cfg.trialsInfo holds Epochs_FlextoFlex_based.mat
%     and Trials_Info.mat per participant
%   * Statistics and Machine Learning Toolbox, for isoutlier in screen_epochs

clc
clear


%% Paths and parameters
% config/ is always two levels up from code/<stage>/.
% Locate config/, which is always two levels up from code/<stage>/.
%
% mfilename is empty when these lines are pasted into the command window,
% and reports a temporary helper file when a single %% section is run with
% Ctrl+Enter, so neither case can be trusted. Fall back to this file's own
% name, which resolves whenever the file is runnable at all.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('run_build_masters');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_build_masters.m and press Run, ' ...
           'or make its folder the current folder first. Pasting the ' ...
           'bootstrap into the command window gives MATLAB nothing to ' ...
           'resolve the path from.']);
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);

if isempty(cfg.raw)
    error(['This stage reads the epoched trial data from stage 2. Set ' ...
           'cfg.raw in config/local_paths.m.']);
end

% Which stages to run. Each writes its own files, so a later one can be
% re-run without repeating an earlier one.
build_emg      = true;    % ~ minutes, writes several GB of signals
build_tracking = true;    % ~ minutes
build_table    = true;    % seconds

% Screening policy for the behaviour table. 'intersection' is what the
% manuscript reports: a trial counts only if it survives both streams,
% because the mediation needs a rating, an EMG value and a tracking value on
% the same trial. See screen_epochs for the alternatives and what they cost.
policy = 'intersection';

% Participants. cfg.subjects is 5 to 18 and INCLUDES sub-10, whose EMG is
% all zeros. That is deliberate: the builder records it as
% SignalHasVariance = false and screen_epochs acts on the flag, so the
% exclusion is visible in the data rather than hidden in a subject list.
subject_list = cfg.subjects;

fprintf('Masters will be written to %s\n\n', cfg.masters);


%% B1a. EMG master
if build_emg
    fprintf('%s\n=== EMG master ===\n%s\n', repmat('=',1,60), repmat('=',1,60));
    build_emg_master(cfg, subject_list);
end


%% B1b. Tracking master
% Run after the EMG master, so its report can check that the two key sets
% are identical. That check is the whole point of the rebuild.
if build_tracking
    fprintf('\n%s\n=== Tracking master ===\n%s\n', repmat('=',1,60), repmat('=',1,60));
    build_tracking_master(cfg, subject_list);
end


%% B1c. Behaviour table
if build_table
    fprintf('\n%s\n=== Behaviour table ===\n%s\n', repmat('=',1,60), repmat('=',1,60));
    build_behaviour_table(cfg, policy);
end


%% Next
fprintf(['\nNext: checks/acceptance_test.m, which confirms the rebuild ' ...
         'reproduces the validated condition means. Nothing should be ' ...
         'built on these masters until it passes.\n']);
fprintf(['Then behaviour/run_results_behaviour.m for the statistics and ' ...
         'Figure 2.\n']);
