%% EXPDATA_ALIGNMENT_CHECK
%  Trials_Info is corrupted for subjects 9, 11, 12 and 18: an entry is
%  duplicated, and everything after it is displaced by one. The EMG
%  structure is correct, since the effort index and the ratings both rise
%  monotonically in every participant under its labels, which scrambled
%  labels could not produce.
%
%  The open question is whether the same duplication also affects
%  Epochs_FlextoFlex_based, which supplies the tracking signal:
%
%    Case A  duplication only in Trials_Info. The signal is fine, and the
%            fix is to take pressure and score from the EMG structure.
%    Case B  duplication in both. The signal is displaced too, and it
%            must be shifted back before any labels are attached.
%
%  Epoch counts decide it. Both files segment the same trials into cycles,
%  so the number of epochs in a given trial should agree between them.
%  Counts run to eight or more and vary trial to trial, so an accidental
%  match across a whole session is very unlikely.
% =====================================================================

clc
clear

%% 0. Configuration
% ---------------------------------------------------------------------
% config/ is three levels up from code/<stage>/checks/.
%
% mfilename is empty at the command prompt and reports a temporary helper
% file when a single %% section is run, so fall back to this file's name.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('expdata_alignment_check');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open expdata_alignment_check.m and press Run, ' ...
           'or make its folder the current folder first.']);
end
addpath(fullfile(fileparts(fileparts(fileparts(thisFile))), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);

if isempty(cfg.raw)
    error(['This reads the master tables written by run_build_masters.m. ' ...
           'Set cfg.raw in config/local_paths.m.']);
end

epoched_data_path = cfg.trialsInfo;   % stage 2 output, per participant
out_path          = cfg.masters;
% The per-subject EMG intermediates. The original wrote these inside the
% code tree; they are derived data, so cfg puts them with the rest of it.
structured_EMG_data_path = cfg.structuredEMG;

SUSPECT = [9 11 12 18];
CONTROL = [13 15];           % known-clean subjects, as a sanity check

fprintf('%8s %14s %14s %14s %10s\n', ...
    'Subject','Agree@0','Agree@+1','Agree@-1','Verdict');

for subID = [CONTROL SUSPECT]

    L1 = load(fullfile(epoched_data_path, ['sub-', num2str(subID)], ...
        'Epochs_FlextoFlex_based.mat'));
    L2 = load(fullfile(structured_EMG_data_path, ['sub-', num2str(subID)], ...
        ['sub-', num2str(subID), '_structured_EMG_data.mat']));
    Epochs_FlextoFlex_based = L1.Epochs_FlextoFlex_based;
    Main_data               = L2.Main_data;
    clear L1 L2

    % Epochs per trial from each source.
    nExp = cellfun(@(x) numel(x.EXP_stream.Times), Epochs_FlextoFlex_based);
    nEmg = cellfun(@(x) numel(x.Signal),           Main_data);

    n = min(numel(nExp), numel(nEmg));
    a0  = mean(nExp(1:n)       == nEmg(1:n));
    ap1 = mean(nExp(2:n)       == nEmg(1:n-1));   % EXP lags EMG by one
    am1 = mean(nExp(1:n-1)     == nEmg(2:n));     % EXP leads EMG by one

    [~, k] = max([a0 ap1 am1]);
    switch k
        case 1, verdict = 'aligned';
        case 2, verdict = 'EXP lags';
        case 3, verdict = 'EXP leads';
    end

    fprintf('%8d %14.3f %14.3f %14.3f %10s\n', subID, a0, ap1, am1, verdict);

    clear Epochs_FlextoFlex_based Main_data
end

fprintf(['\nIf the suspect subjects come out aligned at shift zero, the\n' ...
         'duplication is confined to Trials_Info (case A) and the signal\n' ...
         'is sound. Taking pressure and score from the EMG structure, or\n' ...
         'from the behaviour table, then repairs the tracking dataset\n' ...
         'without touching the epochs.\n\n' ...
         'If they come out displaced, the duplication reached the epoched\n' ...
         'data as well (case B), and the signal has to be shifted back by\n' ...
         'the reported amount before labels are attached.\n\n' ...
         'The two control subjects should read aligned with agreement\n' ...
         'near 1.000. If they do not, the epoch counting itself is wrong\n' ...
         'and nothing above can be trusted.\n']);
