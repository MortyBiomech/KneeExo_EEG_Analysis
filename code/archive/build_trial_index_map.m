%% BUILD_TRIAL_INDEX_MAP
%  Reconciles the two trial numbering conventions in the project.
%
%  The EMG builder walks the raw trials but stores into a compacted
%  counter:
%
%      jj = 0;
%      for j = 1:length(data)
%          if isempty(data{1,j}.EMG_stream.Sensors_Preprocessed), continue; end
%          jj = jj + 1;
%          Main_data{1,jj}.Pressure = Trials_Info{1,j}.General.Pressure;
%
%  so Main_data sits at compacted positions while its metadata was read at
%  raw positions. A second compaction follows: a trial whose epochs were
%  all shorter than 2000 samples has jj decremented and its slot reused.
%  main_EMG_detailed_analysis.m then writes the index into Main_data as
%  the trial number, so the behaviour table carries compacted indices.
%
%  The tracking builder loops over Epochs_FlextoFlex_based directly and
%  stores the raw index. The two agree until a subject's first skipped
%  trial and diverge by one per skip thereafter, which is exactly the
%  observed pattern.
%
%  Neither is wrong. This script reconstructs the mapping so the tracking
%  structure can be expressed in the table's numbering.
%
%  Output: trial_index_map.mat, holding one table per subject with
%  columns RawTrial and CompactTrial.
% =====================================================================

clc; clear;

data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
epoched_data_path = [data_path, '6_Trials_Info_and_Epoched_data\'];
EMG_subjects = [5 6 7 8 9 11 12 13 14 15 16 17 18];   % as in the EMG builder

home = pwd;
mapAll = struct();

for subID = EMG_subjects

    cd([epoched_data_path, 'sub-', num2str(subID)]);
    load Epochs_FlextoFlex_based.mat
    cd(home);

    nRaw = numel(Epochs_FlextoFlex_based);
    kept = false(nRaw,1);

    for j = 1:nRaw
        sp = Epochs_FlextoFlex_based{1,j}.EMG_stream.Sensors_Preprocessed;

        % First compaction: no EMG at all for this trial.
        if isempty(sp), continue; end

        % Second compaction: every epoch shorter than 2000 samples, so
        % Signal ends up empty and the builder reuses the slot.
        lens = cellfun(@(x) size(x,2), sp);
        if ~any(lens >= 2000), continue; end

        kept(j) = true;
    end

    compact = nan(nRaw,1);
    compact(kept) = (1:sum(kept))';

    mapAll.(sprintf('sub%d', subID)) = ...
        table((1:nRaw)', compact, kept, ...
        'VariableNames', {'RawTrial','CompactTrial','KeptInEMG'});

    nSkip = sum(~kept);
    if nSkip == 0
        fprintf('Sub %2d: %3d raw trials, none skipped, numbering identical\n', ...
            subID, nRaw);
    else
        fprintf('Sub %2d: %3d raw trials, %d skipped at raw index %s\n', ...
            subID, nRaw, nSkip, mat2str(find(~kept)'));
    end

    clear Epochs_FlextoFlex_based
end

save('trial_index_map.mat', 'mapAll');
fprintf('\nSaved trial_index_map.mat\n');


%% Verify the map against the behaviour table
% ---------------------------------------------------------------------
% Remapping the tracking structure should restore agreement to 1.000 for
% every subject. If it does not, the compaction rule reconstructed above
% does not match what the builder actually did.

cfg = ansymb_config();
addpath(genpath(cfg.code));
load([cfg.derived, filesep, 'behavior_table.mat'], 'T');
load('Subject_Tracking_Error.mat');

if iscategorical(T.Pressure)
    Tpres = str2double(string(T.Pressure));
else
    Tpres = double(T.Pressure);
end
Tsubj = double(string(T.SubjectID));
bad   = T.Score == 0 | isnan(T.Score) | T.Score < 1 | T.Score > 10;
T     = T(~bad,:); Tpres = Tpres(~bad); Tsubj = Tsubj(~bad);

subject_list = 5:18;
fprintf('\n--- Agreement after remapping ---\n');
fprintf('%8s %14s %14s\n', 'Subject','Before','After');

for s = 1:numel(subject_list)
    subID = subject_list(s);
    if isempty(Subject_Tracking_Error{s}), continue; end
    if ~isfield(mapAll, sprintf('sub%d', subID))
        fprintf('%8d %14s %14s   (no EMG, raw numbering)\n', subID, '-', '-');
        continue;
    end

    trk = Subject_Tracking_Error{s};
    M   = mapAll.(sprintf('sub%d', subID));

    rows = Tsubj == subID;
    keepIDs = T.Trial(rows); keepP = Tpres(rows); keepS = T.Score(rows);

    % Before: raw index used directly.
    [tf, loc] = ismember(trk.trial, keepIDs);
    before = mean(trk.pressure(tf) == keepP(loc(tf)) & ...
                  trk.score(tf)    == keepS(loc(tf)));

    % After: raw index translated to the compacted numbering.
    trkCompact = M.CompactTrial(trk.trial);
    valid = ~isnan(trkCompact);
    [tf2, loc2] = ismember(trkCompact(valid), keepIDs);
    p2 = trk.pressure(valid); s2 = trk.score(valid);
    after = mean(p2(tf2) == keepP(loc2(tf2)) & s2(tf2) == keepS(loc2(tf2)));

    fprintf('%8d %14.3f %14.3f\n', subID, before, after);
end

fprintf(['\nIf every subject now reads 1.000, the mapping is correct and\n' ...
         'the tracking pipeline should apply CompactTrial before joining.\n' ...
         'Subject 10 has no EMG structure, so its table entries were\n' ...
         'built on raw numbering and need no translation.\n']);
