%% SUBJECT10_EMG_CHECK
%  The old pipeline excluded subject 10 from every EMG analysis by hand:
%
%      subjects_list = [5 6 7 8 9 11 12 13 14 15 16 17 18];
%      ...
%      if subject_list(sub) == 10; continue; end;  % no EMG data for subject 10
%
%  The rebuilt master disagrees. It found 2375 epochs across 179 trials
%  for that subject, every one with a signal and all four muscles located.
%  Both cannot be true, and the answer decides whether muscular effort is
%  an n = 13 or an n = 14 analysis.
%
%  Three possibilities:
%    - The comment was stale and the data is fine. The exclusion should
%      be dropped and the EMG analyses gain a participant.
%    - The stream recorded something, but not usable EMG: flat, saturated,
%      clipped, or at the wrong gain. Then the exclusion was right and
%      needs a flag rather than a hand-edited subject list.
%    - The muscle names matched but the channels are mislabelled, in which
%      case the signals look plausible and are wrong, which is the worst
%      case and the hardest to see.
%
%  Comparing subject 10 against the others on amplitude, dynamic range and
%  the shape of the condition effect distinguishes these.
% =====================================================================

clc; clear;

data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
out_path  = [data_path, '7_Master_Tables\'];

LEVELS = [1 3 6];
MUS    = {'iEMG_VM','iEMG_RF','iEMG_GM','iEMG_BF'};
MUSN   = {'VM','RF','GM','BF'};

load(fullfile(out_path,'emg_master_index.mat'), 'masterIndex');
E = masterIndex; clear masterIndex

keep = E.IsExperiment & E.EpochHasSignal & E.EpochLongEnough & ...
       E.EventsValid & E.AllMusclesFound & ismember(E.Pressure, LEVELS);
Ek = E(keep,:);
subs = unique(Ek.SubjectID);


%% 1. Amplitude, compared across subjects
% ---------------------------------------------------------------------
% Raw iEMG in signal-seconds, before normalisation. Absolute values vary
% widely between participants through electrode placement and tissue, so
% what matters is whether subject 10 sits inside the spread or far
% outside it.
fprintf('--- Median raw iEMG per subject (signal-seconds) ---\n');
fprintf('%8s %10s %10s %10s %10s %10s\n', 'Subject', MUSN{:}, 'Epochs');
med = nan(numel(subs), 4);
for i = 1:numel(subs)
    s = Ek.SubjectID == subs(i);
    for m = 1:4
        med(i,m) = median(Ek.(MUS{m})(s), 'omitnan');
    end
    fprintf('%8d %10.4f %10.4f %10.4f %10.4f %10d\n', subs(i), med(i,:), sum(s));
end

others = subs ~= 10;
fprintf('\nSubject 10 relative to the others (ratio to their median):\n');
for m = 1:4
    r = med(subs==10, m) / median(med(others, m));
    fprintf('  %s: %.2f\n', MUSN{m}, r);
end


%% 2. Does the signal move with condition?
% ---------------------------------------------------------------------
% The decisive test. A dead or mislabelled channel has no reason to track
% pressure. Every other subject shows a large graded rise in the flexors,
% so if subject 10 shows one too, the recording is real.
fprintf('\n--- Fold change High over Low, per subject ---\n');
fprintf('%8s %10s %10s %10s %10s\n', 'Subject', MUSN{:});
fold = nan(numel(subs), 4);
for i = 1:numel(subs)
    for m = 1:4
        lo = mean(Ek.(MUS{m})(Ek.SubjectID==subs(i) & Ek.Pressure==1), 'omitnan');
        hi = mean(Ek.(MUS{m})(Ek.SubjectID==subs(i) & Ek.Pressure==6), 'omitnan');
        fold(i,m) = hi/lo;
    end
    mark = '';
    if subs(i) == 10, mark = '   <-- subject 10'; end
    fprintf('%8d %10.2f %10.2f %10.2f %10.2f%s\n', subs(i), fold(i,:), mark);
end

medFold = median(fold(others,:), 1, 'omitnan');
s10Fold = fold(subs == 10, :);
fprintf('\n%-24s', 'Others, median:');
for m = 1:4, fprintf('%s %.2f   ', MUSN{m}, medFold(m)); end
fprintf('\n%-24s', 'Subject 10:');
for m = 1:4, fprintf('%s %.2f   ', MUSN{m}, s10Fold(m)); end
fprintf('\n');


%% 3. Signal shape, from the stored waveforms
% ---------------------------------------------------------------------
% Amplitude statistics cannot distinguish a real signal from a constant
% offset or a clipped one. These look at the waveform itself: a flat
% channel has near-zero variability, a clipped one spends much of its time
% at its own maximum.
fprintf('\n--- Waveform checks, 200 epochs sampled per subject ---\n');
fprintf('%8s %28s %28s\n', '', 'coefficient of variation', 'fraction at 99%% of max');
fprintf('%8s %7s %6s %6s %6s %7s %6s %6s %6s\n', 'Subject', MUSN{:}, MUSN{:});

for i = 1:numel(subs)
    S = load(fullfile(out_path, sprintf('emg_master_sub-%d.mat', subs(i))), 'E','Sig');
    ok = find(S.E.EpochHasSignal & S.E.IsExperiment);
    if numel(ok) > 200, ok = ok(round(linspace(1, numel(ok), 200))); end

    cv = nan(numel(ok),4); sat = nan(numel(ok),4);
    for q = 1:numel(ok)
        sig = S.Sig{ok(q)};
        if isempty(sig), continue; end
        cv(q,:)  = std(sig,0,2)' ./ abs(mean(sig,2))';
        pk = max(abs(sig),[],2);
        sat(q,:) = mean(abs(sig) >= 0.99*pk, 2)';
    end
    fprintf('%8d %7.2f %6.2f %6.2f %6.2f %7.3f %6.3f %6.3f %6.3f\n', ...
        subs(i), median(cv,1,'omitnan'), median(sat,1,'omitnan'));
    clear S
end

fprintf(['\nA coefficient of variation far below the others means a flat\n' ...
         'channel. A saturation fraction far above means clipping. If\n' ...
         'subject 10 sits inside the spread on both, and shows the usual\n' ...
         'graded fold change, the old exclusion was stale and the EMG\n' ...
         'analyses gain a fourteenth participant.\n\n' ...
         'If it is excluded, the reason belongs in a flag in the master,\n' ...
         'not in a hand-edited subject list where it is invisible and\n' ...
         'cannot be revisited.\n']);