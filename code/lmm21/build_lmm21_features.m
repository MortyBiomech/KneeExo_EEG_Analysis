function [F, audit] = build_lmm21_features(L)
%BUILD_LMM21_FEATURES  The 21 trial-level cortical features.
%
%   [F, AUDIT] = BUILD_LMM21_FEATURES(L) walks the seven clusters and the
%   participants that contribute a component to each, reads the single-trial
%   time-frequency decomposition of that component, and returns one value per
%   trial per cluster per band.
%
%   F      one row per participant and raw trial, with SubjectID, RawTrial and
%          21 feature columns named <abbr>_<band>, in dB
%   AUDIT  one row per participant and cluster: epochs read, epochs kept, trials
%          produced, the QC count, and the match residual of the pairing. Read
%          it before trusting the features.
%
%   Needs tier 2, the .icatimef files. The result is cached in data/derived so
%   that the model itself runs on a fresh clone without them, the same
%   arrangement figure2_precomputed.mat uses for Figure 2.
%
%   WHICH TRIAL NUMBER. The key is the trial number of the EXPERIMENT stream,
%   taken from the pairing, not the trial number the time-frequency file
%   carries in trialinfo. The two are different countings and they disagree for
%   the participants whose EMG builder compacted its index. The behaviour table
%   keys on the experiment side, so that is the side used here. The audit
%   reports how often the two disagree, which is worth looking at once.
%
%   A participant with no component in a cluster leaves that cluster's three
%   columns NaN. Nothing is dropped, so every feature model later runs on its
%   own subset and the subset size is reported.
%
%   See also LMM21_TRIAL_FEATURES, LOAD_CLUSTER_POWER, BUILD_EPOCH_PAIRING,
%            RUN_LMM21.
%
%   Part of the KneeExo-EEG analysis code.

if nargin < 1 || isempty(L)
    L = lmm21_config();
end

cfg = L.cfg;

% ---- inputs that only a rebuild needs ----------------------------------
if isempty(L.paths.icatimef) || exist(L.paths.icatimef, 'dir') ~= 7
    error('build_lmm21_features:NoIcatimef', ...
        ['The single-trial time-frequency files are needed to rebuild the ' ...
         'features and cannot be found at\n  %s\n\nThey are tier 2 of the ' ...
         'data release. Set cfg.raw in config/local_paths.m, or use the ' ...
         'cached feature table at\n  %s'], ...
        L.paths.icatimef, L.files.features);
end

if exist(L.files.pairing, 'file') ~= 2
    error('build_lmm21_features:NoPairing', ...
        ['Cannot find the epoch pairing at\n  %s\nIt ships in data/derived ' ...
         'and is built by coupling/build_epoch_pairing.m.'], L.files.pairing);
end

loaded  = load(L.files.pairing, 'pairing');
pairing = loaded.pairing;

p = ersp_params();

nCl = size(L.clusters, 1);
nB  = numel(L.bandNames);

F = [];
auditRows = {};
trialinfoCache = containers.Map('KeyType', 'double', 'ValueType', 'any');

for c = 1:nCl

    clusterName = L.clusters{c, 1};
    abbr        = L.clusters{c, 2};

    fprintf('\n=== %s ===\n', clusterName);

    colNames = cellfun(@(b) sprintf('%s_%s', abbr, b), L.bandNames, ...
        'UniformOutput', false);

    % LOAD_CLUSTER_POWER is the coupling analysis's reader, reused unchanged.
    % Using one reader for both analyses is what lets the Methods say that the
    % null and the cross-correlation describe the same signal.
    pow = load_cluster_power(L.paths, L.subjects, pairing, clusterName, ...
        'icFile', L.files.clusterIC, 'verbose', false);

    Fc = [];

    for s = 1:numel(L.subjects)

        subject = L.subjects(s);

        if isempty(pow.power{s})
            continue
        end

        iPair = find([pairing.subject] == subject, 1);
        keepTF   = pairing(iPair).keepTF(:);
        rawTrial = pairing(iPair).pairs(:, 1);
        residual = pairing(iPair).residualMs(:);

        if numel(rawTrial) ~= size(pow.power{s}, 3)
            error('build_lmm21_features:PairingLength', ...
                ['Participant %d, cluster %s: the pairing has %d kept epochs ' ...
                 'and the loaded power has %d. The pairing is stale.'], ...
                subject, clusterName, numel(rawTrial), size(pow.power{s}, 3));
        end

        % Condition per epoch, from the file's own trialinfo, so the baseline
        % and the QC use the same condition labels the published ERSPs used.
        % Read once per participant and reused across clusters.
        if isKey(trialinfoCache, subject)
            ti = trialinfoCache(subject);
        else
            tfFile = fullfile(L.paths.icatimef, sprintf('S%d.icatimef', subject));
            ti = load(tfFile, '-mat', 'trialinfo');
            ti = ti.trialinfo;
            trialinfoCache(subject) = ti;
        end

        condAll   = cellfun(@as_double, {ti.cond}).';
        eegTrial  = cellfun(@as_double, {ti.trial}).';
        epochCond = condAll(keepTF);
        eegTrialK = eegTrial(keepTF);

        out = lmm21_trial_features(pow.power{s}, pow.freqs, rawTrial, ...
            epochCond, L.bands, ...
            'applyQC',  L.applyErspQC, 'qc', p.qc, ...
            'baseline', L.baseline,    'aggSpace', L.aggSpace);

        Fs = table();
        Fs.SubjectID = repmat(subject, numel(out.trial), 1);
        Fs.RawTrial  = out.trial;
        for b = 1:nB
            Fs.(colNames{b}) = out.feature(:, b);
        end

        Fc = [Fc; Fs]; %#ok<AGROW>

        auditRows{end+1} = table(subject, string(clusterName), pow.ic(s), ...
            pairing(iPair).nTF, numel(keepTF), out.nEpochsTotal, ...
            out.nEpochsUsed, nnz(out.isBad), numel(out.trial), ...
            median(residual, 'omitnan'), max(residual), ...
            nnz(eegTrialK ~= rawTrial), ...
            'VariableNames', {'SubjectID', 'Cluster', 'IC', 'nEpochsFile', ...
            'nPaired', 'nLoaded', 'nUsed', 'nFlaggedQC', 'nTrials', ...
            'medianResidualMs', 'maxResidualMs', 'nTrialNumberDisagree'}); %#ok<AGROW>

        fprintf(['  S%-3d ic %-3d  epochs %4d  kept %4d  QC dropped %3d  ' ...
                 'trials %4d  cycles/trial %.1f\n'], ...
            subject, pow.ic(s), pairing(iPair).nTF, numel(keepTF), ...
            nnz(out.isBad), numel(out.trial), mean(out.nEpochs));
    end

    if isempty(Fc)
        error('build_lmm21_features:EmptyCluster', ...
            'Cluster %s produced no rows at all.', clusterName);
    end

    if isempty(F)
        F = Fc;
    else
        F = outerjoin(F, Fc, 'Keys', {'SubjectID', 'RawTrial'}, ...
            'MergeKeys', true, 'Type', 'full');
    end
end

F = sortrows(F, {'SubjectID', 'RawTrial'});

featNames = setdiff(F.Properties.VariableNames, {'SubjectID', 'RawTrial'}, 'stable');
if numel(featNames) ~= L.nFeatures
    error('build_lmm21_features:ColumnCount', ...
        'The feature table has %d feature columns, expected %d: %s', ...
        numel(featNames), L.nFeatures, strjoin(featNames, ', '));
end

audit = vertcat(auditRows{:});

% ---- save --------------------------------------------------------------
settings = L.settings; %#ok<NASGU>
stamp = build_stamp(cfg, struct('analysis', 'lmm21 features', ...
    'featureVersion', L.featureVersion, ...
    'clusters', {L.clusters(:, 1).'}, 'bands', L.bandNames)); %#ok<NASGU>

save(L.files.features, 'F', 'audit', 'settings', 'stamp');
writetable(audit, L.files.audit);

fprintf('\n%d trials, %d participants, %d features.\n', ...
    height(F), numel(unique(F.SubjectID)), numel(featNames));
fprintf('Saved %s\n', L.files.features);

nDisagree = sum(audit.nTrialNumberDisagree);
if nDisagree > 0
    fprintf(['\nNote: the time-frequency trialinfo and the experiment stream ' ...
             'disagree about\nthe trial number for %d epoch(s). The experiment ' ...
             'numbering was used, which is\nwhat the behaviour table keys on. ' ...
             'See lmm21_feature_audit.csv.\n'], nDisagree);
end

fprintf('\nTrials with a finite value, per feature:\n');
for k = 1:numel(featNames)
    fprintf('  %-14s %5d\n', featNames{k}, sum(~isnan(F.(featNames{k}))));
end

end


% ----------------------------------------------------------------------------
function v = as_double(x)
%AS_DOUBLE  trialinfo stores these as text in some files and numbers in others.

if isnumeric(x)
    v = double(x);
else
    v = str2double(x);
end

end
