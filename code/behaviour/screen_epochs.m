function [keepE, keepX, info] = screen_epochs(E, X, policy)
%SCREEN_EPOCHS  Apply a named screening policy to the master tables.
%
%   [keepE, keepX, info] = SCREEN_EPOCHS(E, X, policy)
%
%   E       EMG epoch table      (emg_master_index.mat)
%   X       tracking epoch table (trk_master_index.mat)
%   policy  'intersection' | 'emg' | 'tracking' | 'none'
%
%   Returns logical masks over the rows of E and X, and a struct
%   recording how many epochs each criterion removed.
%
%   WHY THIS EXISTS. Every analysis previously wrote its own filter. The
%   behaviour table, the EMG plotting script and the tracking script each
%   applied a different set, so they disagreed about which trials existed
%   and the disagreement was invisible until the numbers failed to
%   reconcile. One function means one definition, and changing a screen
%   changes it everywhere at once.
%
%   POLICIES
%     'intersection'  a trial must survive both streams. Used for
%                     everything in the main text, because the mediation
%                     and the integration model require a rating, an EMG
%                     value and a tracking value on the same trial and so
%                     run on the intersection regardless. Behavioural
%                     means from a larger set would not reconcile with
%                     the models beside them.
%     'emg'           EMG criteria only.
%     'tracking'      tracking criteria only. Legitimate for analyses
%                     that never touch EMG, and it retains about 13 per
%                     cent more trials, but the Methods must then state
%                     two different trial counts.
%     'none'          flags reported, nothing removed. For auditing.
%
%   ONE ASYMMETRY, DELIBERATE. A participant with no usable EMG is
%   retained for the behavioural and kinematic analyses. A missing EMG
%   recording is a fact about the EMG, not about that person's ratings or
%   their tracking, and excluding them would discard a full participant
%   for an unrelated reason.
%
%   CONSTANTS. LEVELS and MUSCLE_COLS below must agree with cfg.pressures
%   and cfg.muscles. They are repeated here rather than read from the
%   config on purpose: this function takes only tables, so it can be run
%   against a master table from anywhere without a configured repository.
%   If you change the pressure set, change it in both places.

%   Outlier screens are applied within subject, and the iEMG screen
%   within subject and condition, matching the original pipeline. They
%   are analysis choices rather than data properties, which is why they
%   live here and not in the builders.

arguments
    E table
    X table
    policy (1,:) char {mustBeMember(policy, ...
        {'intersection','emg','tracking','none'})} = 'intersection'
end

LEVELS       = [1 3 6];
MUSCLE_COLS  = {'iEMG_VM','iEMG_RF','iEMG_GM','iEMG_BF'};
MAD_FACTOR   = 3;
MIN_EPOCHS_PER_TRIAL = 5;

info = struct();

%% Basic flags
% ---------------------------------------------------------------------
% Each criterion is applied in turn and its effect recorded, so the
% Methods can state what every screen cost rather than reporting one
% aggregate number.

baseE = true(height(E),1);
steps = { ...
    'experimental trial', E.IsExperiment; ...
    'signal present',     E.EpochHasSignal; ...
    'signal varies',      pick(E, 'SignalHasVariance'); ...
    'long enough',        E.EpochLongEnough; ...
    'events valid',       E.EventsValid; ...
    'all muscles found',  E.AllMusclesFound; ...
    'rating valid',       E.ScoreValid; ...
    'pressure in set',    ismember(E.Pressure, LEVELS)};

for s = 1:size(steps,1)
    before = sum(baseE);
    baseE  = baseE & steps{s,2};
    info.emg.(matlab.lang.makeValidName(steps{s,1})) = before - sum(baseE);
end
info.emg.afterBasicFlags = sum(baseE);

baseX = true(height(X),1);
stepsX = { ...
    'experimental trial', X.IsExperiment; ...
    'signal present',     X.EpochHasSignal; ...
    'lengths match',      X.LengthsMatch; ...
    'events valid',       X.EventsValid; ...
    'rating valid',       X.ScoreValid; ...
    'pressure in set',    ismember(X.Pressure, LEVELS)};

for s = 1:size(stepsX,1)
    before = sum(baseX);
    baseX  = baseX & stepsX{s,2};
    info.tracking.(matlab.lang.makeValidName(stepsX{s,1})) = before - sum(baseX);
end
info.tracking.afterBasicFlags = sum(baseX);

if strcmp(policy, 'none')
    keepE = baseE; keepX = baseX; return
end


%% EMG outlier screens
% ---------------------------------------------------------------------
% Event-timing outliers within subject, then trials left too short, then
% iEMG outliers within subject and condition. Order matters: dropping
% thin trials before the iEMG screen would change which trials the
% latter sees.

subs = unique(E.SubjectID);
before = sum(baseE);
for i = 1:numel(subs)
    s = E.SubjectID == subs(i) & baseE;
    if ~any(s), continue; end
    o1 = false(height(E),1); o2 = false(height(E),1);
    o1(s) = isoutlier(E.ExtStart(s), 'median', 'ThresholdFactor', MAD_FACTOR);
    o2(s) = isoutlier(E.ExtEnd(s),   'median', 'ThresholdFactor', MAD_FACTOR);
    baseE = baseE & ~(o1 | o2);
end
info.emg.eventTimingOutliers = before - sum(baseE);

before = sum(baseE);
[g, key] = findgroups(E(baseE, {'SubjectID','RawTrial'}));
cnt  = splitapply(@numel, find(baseE), g);
thin = key(cnt < MIN_EPOCHS_PER_TRIAL, :);
if ~isempty(thin)
    baseE = baseE & ~ismember(E(:, {'SubjectID','RawTrial'}), thin);
end
info.emg.thinTrials = before - sum(baseE);

% The iEMG screen operates on trial means, so it is evaluated at trial
% level and then propagated back to the epochs of the trials it rejects.
Ek = E(baseE, :);
[g, key] = findgroups(Ek(:, {'SubjectID','RawTrial'}));
trialPres = splitapply(@(x) x(1), Ek.Pressure, g);
trialIEMG = nan(height(key), numel(MUSCLE_COLS));
for m = 1:numel(MUSCLE_COLS)
    trialIEMG(:,m) = splitapply(@mean, Ek.(MUSCLE_COLS{m}), g);
end

drop = false(height(key),1);
for i = 1:numel(subs)
    for c = 1:numel(LEVELS)
        s = key.SubjectID == subs(i) & trialPres == LEVELS(c);
        if sum(s) < 3, continue; end
        o = false(sum(s),1);
        for m = 1:numel(MUSCLE_COLS)
            o = o | isoutlier(trialIEMG(s,m), 'median', 'ThresholdFactor', MAD_FACTOR);
        end
        idx = find(s); drop(idx(o)) = true;
    end
end

before = sum(baseE);
if any(drop)
    baseE = baseE & ~ismember(E(:, {'SubjectID','RawTrial'}), key(drop,:));
end
info.emg.iemgOutlierTrials = before - sum(baseE);
info.emg.final = sum(baseE);


%% Combine according to policy
% ---------------------------------------------------------------------
switch policy
    case 'emg'
        keepE = baseE;
        keepX = baseX & ismember(X(:, {'SubjectID','RawTrial'}), ...
                                 unique(E(baseE, {'SubjectID','RawTrial'})));

    case 'tracking'
        keepX = baseX;
        keepE = baseE;

    case 'intersection'
        okE = unique(E(baseE, {'SubjectID','RawTrial'}));
        okX = unique(X(baseX, {'SubjectID','RawTrial'}));
        both = intersect(okE, okX);

        keepE = baseE & ismember(E(:, {'SubjectID','RawTrial'}), both);
        keepX = baseX & ismember(X(:, {'SubjectID','RawTrial'}), both);

        % Participants with no usable EMG at all are kept on the tracking
        % screen alone. A missing EMG recording says nothing about that
        % person's ratings or their tracking, and dropping them would
        % cost a whole participant from the behavioural analysis.
        noEMG = setdiff(unique(X.SubjectID), unique(okE.SubjectID));
        if ~isempty(noEMG)
            keepX = keepX | (baseX & ismember(X.SubjectID, noEMG));
            info.subjectsWithoutEMG = noEMG(:)';
        end
end

info.policy       = policy;
info.epochsEMG    = sum(keepE);
info.epochsTrack  = sum(keepX);
info.trialsEMG    = height(unique(E(keepE, {'SubjectID','RawTrial'})));
info.trialsTrack  = height(unique(X(keepX, {'SubjectID','RawTrial'})));
info.subjectsEMG  = numel(unique(E.SubjectID(keepE)));
info.subjectsTrack = numel(unique(X.SubjectID(keepX)));

end


function v = pick(T, name)
% Return a flag if the table has it, otherwise pass everything and warn.
% Lets the function run against a master built before a flag was added,
% rather than failing on a missing column and inviting a hand-edited
% workaround.
    if ismember(name, T.Properties.VariableNames)
        v = T.(name);
    else
        warning('screen_epochs:missingFlag', ...
            '%s is absent from the master. Rebuild it; the screen is skipped.', name);
        v = true(height(T),1);
    end
end