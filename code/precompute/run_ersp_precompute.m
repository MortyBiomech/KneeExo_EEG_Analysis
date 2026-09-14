% run_ersp_precompute.m
% Stage 5. Time-frequency decomposition of every analysed component.
%
%   epoched datasets with EEG.timewarp  ->  S<N>.icatimef
%
% This is the slow one. Hours, not minutes, and it writes several gigabytes.
% The output is published as tier 2 of the data release, so you almost
% certainly do not need to run it. See README.
%
% Time warping
% ------------
% Every participant's movement cycles are warped onto a common set of event
% latencies so that the same point of the cycle is the same point on the time
% axis for everyone. Each participant's own median latencies are in
% EEG.timewarp.warpto, written by run_epoching_timewarp. The target is the
% median of those across participants, rounded to the nearest 50 ms.
%
% Baseline
% --------
% 'median latency baseline' is resolved inside the modified std_precomp to
% [0 median_latency], that is, the mean over the whole movement cycle rather
% than a pre-movement window. That is deliberate: the analysis compares three
% conditions, so all three need one common reference, and there is no rest
% period in this task to use instead.
%
% Which fork
% ----------
% mod_std_precomp_v_forEEGlabv2021 in vendor/ is the function that produced
% the published .icatimef files, and it is the only one in this repository.
%
% A cleaned-up rewrite of it, std_precomp_timewarp, together with a wrapper
% called precompute_timewarped_ersp, circulated at one point and is NOT part
% of the repository. If you come across those two files, they are not a
% second result: line by line they parse the same three placeholders and make
% the same substitutions, so for the parameters used here they compute an
% identical ERSP. Their additions are a rename, an input-argument check, a
% guard for a missing 'timewarpms', and tidier printing. Nothing was lost by
% leaving them out.

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
    thisFile = which('run_ersp_precompute');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_ersp_precompute.m and press Run, ' ...
           'or make its folder the current folder first. Pasting the ' ...
           'bootstrap into the command window gives MATLAB nothing to ' ...
           'resolve the path from.']);
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);

if isempty(cfg.raw)
    error(['This stage reads the epoched datasets and the STUDY. ' ...
           'Set cfg.raw in config/local_paths.m.']);
end


%% What to run
% The STUDY that defines which components are analysed. Any of the
% clustering solutions carries the same component set, so the main
% brain-component STUDY is used here rather than picking one arbitrarily.
study_name   = 'main_study_potential_brain_ICs_RV-15_epochedData.study';
study_folder = cfg.studyEpoched;

% Round the group median warp latencies to the nearest multiple of this, in
% milliseconds.
warp_round_to_ms = 50;

% Overwrite .icatimef files that already exist.
recompute = 'on';

% Exactly the parameters that produced the published files.
ersp_params = { ...
    'cycles',     [3 0.8], ...        % wavelet, 3 cycles at the lowest freq
    'freqs',      [3 130], ...        % Hz
    'nfreqs',     250, ...            % log-spaced bins across that range
    'freqscale',  'log', ...
    'padratio',   2, ...
    'alpha',      NaN, ...            % no per-file masking; stats come later
    'savetrials', 'off', ...
    'baseline',   'median latency baseline', ...
    'basenorm',   'off', ...
    'trialbase',  'off'};


%% Initialize EEGLAB
if ~exist('ALLCOM', 'var')
    eeglab;
end

% Keep datasets on disk and in single precision. The .icatimef files are
% large enough without holding every dataset in memory as well.
pop_editoptions('option_storedisk', 1, 'option_savetwofiles', 1, ...
    'option_single', 1, 'option_memmapdata', 0, ...
    'option_computeica', 1, 'option_scaleicarms', 1, ...
    'option_rememberfolder', 1);


%% Load the STUDY
studyFile = fullfile(study_folder, study_name);
if ~exist(studyFile, 'file')
    listing = dir(fullfile(study_folder, '*.study'));
    error('run_ersp_precompute:NoStudy', ...
        ['The STUDY is not on disk:\n  %s\n\nSTUDY files in that folder:\n' ...
         '  %s\n\nRun study/run_group_clustering.m first.'], ...
        studyFile, strjoin({listing.name}, sprintf('\n  ')));
end

[STUDY, ALLEEG] = pop_loadstudy('filename', study_name, ...
    'filepath', study_folder);

% Rebuild trialinfo from the datasets. Without this the condition labels in
% the .icatimef files can disagree with the STUDY design, which is a mistake
% that only shows up much later, at plotting time.
[STUDY, trialinfo] = std_maketrialinfo(STUDY, ALLEEG); %#ok<ASGLU>


%% Work out the common warp target
if ~isfield(ALLEEG(1), 'timewarp') || isempty(ALLEEG(1).timewarp)
    error('run_ersp_precompute:NoTimewarp', ...
        ['The datasets in this STUDY carry no EEG.timewarp. Run ' ...
         'run_epoching_timewarp.m first.']);
end

nWarpEvents = numel(ALLEEG(1).timewarp.warpto);
warps = zeros(numel(ALLEEG), nWarpEvents);

for i = 1:numel(ALLEEG)
    if numel(ALLEEG(i).timewarp.warpto) ~= nWarpEvents
        error('run_ersp_precompute:WarpEventMismatch', ...
            ['Dataset %d has %d warp events, dataset 1 has %d. Every ' ...
             'participant must have been epoched with the same event list.'], ...
            i, numel(ALLEEG(i).timewarp.warpto), nWarpEvents);
    end
    warps(i, :) = ALLEEG(i).timewarp.warpto;
end

warpingvalues = round(median(warps, 1) / warp_round_to_ms) * warp_round_to_ms;

fprintf('\nParticipants: %d\n', numel(ALLEEG));
fprintf('Per-participant warpto, ms:\n');
for i = 1:numel(ALLEEG)
    fprintf('  %-8s %s\n', ALLEEG(i).subject, mat2str(round(warps(i, :))));
end
fprintf('Group median, rounded to %d ms: %s\n\n', ...
    warp_round_to_ms, mat2str(warpingvalues));


%% Precompute
% 'timewarp' is passed as 0 as a placeholder. The modified std_precomp
% substitutes each participant's own EEG.timewarp.latencies for it, and warps
% all of them onto timewarpms.
tStart = tic;

[STUDY, ALLEEG] = mod_std_precomp_v_forEEGlabv2021(STUDY, ALLEEG, ...
    'components', 'ersp', 'on', 'itc', 'off', ...
    'erspparams', [ersp_params, {'timewarp', 0, 'timewarpms', warpingvalues}], ...
    'recompute', recompute);

fprintf('\nERSP precompute finished in %.1f minutes.\n', toc(tStart) / 60);


%% Record what produced these files
% Written beside the .icatimef files, because the parameters are otherwise
% only recoverable by loading one of them.
infoFile = fullfile(cfg.epoched, 'ersp_precompute_settings.txt');
fid = fopen(infoFile, 'w');
if fid ~= -1
    fprintf(fid, 'STUDY = %s\n', study_name);
    fprintf(fid, 'Participants = %s\n', strjoin({ALLEEG.subject}, ', '));
    fprintf(fid, 'Warp target (ms) = %s\n', mat2str(warpingvalues));
    fprintf(fid, 'Warp rounding (ms) = %d\n', warp_round_to_ms);
    for k = 1:2:numel(ersp_params)
        fprintf(fid, '%s = %s\n', ersp_params{k}, mat2str(ersp_params{k+1}));
    end
    fprintf(fid, 'Function = mod_std_precomp_v_forEEGlabv2021\n');
    fprintf(fid, 'Written = %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
    fclose(fid);
    fprintf('Settings recorded in %s\n', infoFile);
end
