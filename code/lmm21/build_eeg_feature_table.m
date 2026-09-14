function [F, audit] = build_eeg_feature_table(cfg)
%BUILD_EEG_FEATURE_TABLE  The 21 trial level cortical features.
%
%  [F, audit] = BUILD_EEG_FEATURE_TABLE(cfg) walks the 7 clusters and the 14
%  participants, reads each participant's single component from the .icatimef
%  file, computes whole cycle band power for theta, alpha and beta, joins the
%  epochs to behaviour keys through the pairing map, and averages the movement
%  cycles of a trial into one value.
%
%  F      one row per participant and raw trial, with SubjectID, RawTrial and
%         21 feature columns named <abbr>_<band>, in dB
%  audit  one row per participant and cluster, recording how many epochs were
%         read, how many were matched, the match residual, and the windows
%         used. Read this before trusting the features.
%
%  A participant who has no component in a cluster keeps NaN in that cluster's
%  three columns. Nothing is dropped and no row is deleted, so each feature
%  model later runs on its own subset and the subset size is reported.
%
%  The number 21 is asserted, not assumed. The manuscript states it, so a
%  cluster or band quietly going missing must stop the run rather than
%  silently change what the correction is applied across.
%
%  See also READ_ICATIMEF_COMPONENT, ICATIMEF_BAND_FEATURES,
%           PAIR_ICATIMEF_TO_BEHAVIOUR, CLUSTER_MEMBERSHIP.

if nargin < 1 || isempty(cfg)
    cfg = lmm21_config();
end

nCl = numel(cfg.clusters);
nB  = numel(cfg.bands);

if nCl * nB ~= 21
    error('build_eeg_feature_table:notTwentyOne', ...
        ['The configuration gives %d clusters by %d bands = %d features. ' ...
         'The manuscript reports 21.'], nCl, nB, nCl * nB);
end

membershipSrc = cfg.paths.clusters;
pairingSrc    = cfg.paths.pairing;

F = [];
auditRows = {};

for c = 1:nCl
    cl = cfg.clusters(c);

    [subjects, ics] = cluster_membership(membershipSrc, cl.name, cfg);

    if cfg.verbose
        fprintf('\n[%s] %d participants\n', cl.name, numel(subjects));
    end

    colNames = arrayfun(@(b) sprintf('%s_%s', cl.abbr, cfg.bands(b).name), ...
        1:nB, 'UniformOutput', false);

    Fc = [];

    for s = 1:numel(subjects)
        subject = subjects(s);
        ic      = ics(s);

        icaFile = fullfile(cfg.paths.icatimef, sprintf(cfg.paths.icatimefPattern, subject));

        try
            S = read_icatimef_component(icaFile, ic);
        catch ME
            warning('build_eeg_feature_table:read', ...
                'Participant %d, cluster %s: %s', subject, cl.name, ME.message);
            auditRows{end+1} = auditRow(subject, cl.name, ic, NaN, NaN, NaN, ...
                NaN, NaN, NaN, [NaN NaN], [NaN NaN], ME.message); %#ok<AGROW>
            continue
        end

        % ---- windows, taken from the file wherever possible --------------
        [cycWin, baseWin, winNote] = resolveWindows(cfg, S);

        % ---- per epoch band ratios ---------------------------------------
        [ratio, finfo] = icatimef_band_features(S.power, S.freqs, S.times, ...
            cfg.bands, cycWin, baseWin, cfg.feature.trialBaseline);

        % ---- epoch to trial join ------------------------------------------
        map = pair_icatimef_to_behaviour(pairingSrc, subject, S.nEpochs);

        use = map.Matched & map.EpochIndex >= 1 & map.EpochIndex <= S.nEpochs;
        epochIdx = map.EpochIndex(use);
        rawTrial = map.RawTrial(use);
        R        = ratio(epochIdx, :);

        if isempty(R)
            warning('build_eeg_feature_table:noMatch', ...
                'Participant %d, cluster %s: no epoch matched a behaviour trial.', ...
                subject, cl.name);
            auditRows{end+1} = auditRow(subject, cl.name, ic, S.nEpochs, ...
                height(map), 0, 0, NaN, finfo.nNonFiniteRatio, cycWin, baseWin, ...
                winNote); %#ok<AGROW>
            continue
        end

        % ---- aggregate the movement cycles of a trial ---------------------
        [gid, trials] = findgroups(rawTrial);

        switch lower(cfg.feature.aggSpace)
            case 'linear'
                lin  = splitapply(@(v) mean(v, 1, 'omitnan'), R, gid);
                feat = 10 * log10(lin);
            case 'db'
                dbR  = 10 * log10(R);
                feat = splitapply(@(v) mean(v, 1, 'omitnan'), dbR, gid);
            otherwise
                error('build_eeg_feature_table:aggSpace', ...
                    'cfg.feature.aggSpace must be linear or db, got %s', ...
                    cfg.feature.aggSpace);
        end

        nEpTrial = splitapply(@(v) size(v, 1), R, gid);

        Fs = table();
        Fs.SubjectID = repmat(subject, numel(trials), 1);
        Fs.RawTrial  = trials(:);
        for b = 1:nB
            Fs.(colNames{b}) = feat(:, b);
        end

        Fc = [Fc; Fs]; %#ok<AGROW>

        auditRows{end+1} = auditRow(subject, cl.name, ic, S.nEpochs, ...
            height(map), nnz(use), numel(trials), ...
            median(map.ResidualMs(use), 'omitnan'), ...
            nnz(~isfinite(feat)), cycWin, baseWin, winNote); %#ok<AGROW>

        if cfg.verbose
            fprintf(['  S%-3d ic %-3d  epochs %4d  matched %4d  trials %4d  ' ...
                     'cycles/trial %.1f\n'], ...
                subject, ic, S.nEpochs, nnz(use), numel(trials), mean(nEpTrial));
        end
    end

    if isempty(Fc)
        warning('build_eeg_feature_table:emptyCluster', ...
            'Cluster %s produced no rows. Its three columns will be all NaN.', ...
            cl.name);
        Fc = table('Size', [0 2 + nB], ...
            'VariableTypes', [{'double', 'double'}, repmat({'double'}, 1, nB)], ...
            'VariableNames', [{'SubjectID', 'RawTrial'}, colNames]);
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
if numel(featNames) ~= 21
    error('build_eeg_feature_table:columnCount', ...
        'The feature table has %d feature columns, expected 21: %s', ...
        numel(featNames), strjoin(featNames, ', '));
end

if isempty(auditRows)
    audit = table();
else
    audit = vertcat(auditRows{:});
end

% ---- save ----------------------------------------------------------------
if ~isempty(cfg.paths.out)
    if exist(cfg.paths.out, 'dir') ~= 7
        mkdir(cfg.paths.out);
    end
    save(fullfile(cfg.paths.out, cfg.out.featureTable), 'F', 'audit', 'cfg');
    writetable(audit, fullfile(cfg.paths.out, cfg.out.featureAudit));
end

if cfg.verbose
    fprintf('\n[build_eeg_feature_table] %d trials, %d participants, 21 features.\n', ...
        height(F), numel(unique(F.SubjectID)));
    cov = sum(~isnan(F{:, featNames}), 1);
    fprintf('Trials with a finite value, per feature:\n');
    for k = 1:numel(featNames)
        fprintf('  %-14s %5d\n', featNames{k}, cov(k));
    end
end

end

% =========================================================================
function [cycWin, baseWin, note] = resolveWindows(cfg, S)
%RESOLVEWINDOWS  Cycle and baseline window in ms, preferring the file itself.

note = '';

% ---- cycle ---------------------------------------------------------------
switch lower(cfg.feature.cycleSource)
    case 'timewarp'
        if isempty(S.timewarpms)
            cycWin = [S.times(1) S.times(end)];
            note = [note 'timewarpms absent, whole epoch used as cycle; '];
            warning('build_eeg_feature_table:noTimewarp', ...
                ['%s has no timewarpms parameter, so the whole epoch is being ' ...
                 'treated as the movement cycle. Set cfg.feature.cycleSource ' ...
                 'to explicit and give the window instead.'], S.file);
        else
            cycWin = [S.timewarpms(1) S.timewarpms(end)];
        end
    case 'explicit'
        cycWin = cfg.feature.cycleWindowMs;
        if isempty(cycWin)
            error('build_eeg_feature_table:noCycleWindow', ...
                'cfg.feature.cycleSource is explicit but cycleWindowMs is empty.');
        end
    otherwise
        error('build_eeg_feature_table:cycleSource', ...
            'cfg.feature.cycleSource must be timewarp or explicit.');
end

% ---- baseline ------------------------------------------------------------
switch lower(cfg.feature.baselineSource)
    case 'none'
        baseWin = [];

    case 'explicit'
        baseWin = cfg.feature.baselineWindowMs;
        if isempty(baseWin)
            error('build_eeg_feature_table:noBaselineWindow', ...
                'cfg.feature.baselineSource is explicit but baselineWindowMs is empty.');
        end

    case 'fromfile'
        b = icatimef_param(S.parameters, 'baseline');
        if isempty(b)
            b = icatimef_param(S.parameters, 'commonbase');
        end

        if ischar(b) || isstring(b)
            % 'median latency baseline' is resolved by
            % mod_std_precomp_v_forEEGlabv2021 to [0 medianLatency], where the
            % median latency is the second warp landmark.
            if isempty(S.timewarpms) || numel(S.timewarpms) < 2
                error('build_eeg_feature_table:cannotResolveBaseline', ...
                    ['The file records the baseline as "%s" but has no ' ...
                     'timewarpms to resolve it against. Set ' ...
                     'cfg.feature.baselineSource to explicit.'], char(b));
            end
            baseWin = [0 S.timewarpms(2)];
            note = [note sprintf('baseline "%s" resolved to [0 %.0f]; ', ...
                char(b), S.timewarpms(2))];

        elseif isnumeric(b) && numel(b) == 2
            baseWin = b(:).';

        elseif isnumeric(b) && numel(b) == 1
            baseWin = [S.times(1) b];
            note = [note sprintf('scalar baseline %.0f read as [%.0f %.0f]; ', ...
                b, S.times(1), b)];

        else
            error('build_eeg_feature_table:noBaselineInFile', ...
                ['No usable baseline parameter in %s. Set ' ...
                 'cfg.feature.baselineSource to explicit and state the window.'], ...
                S.file);
        end

    otherwise
        error('build_eeg_feature_table:baselineSource', ...
            'cfg.feature.baselineSource must be fromfile, explicit or none.');
end

end

% -------------------------------------------------------------------------
function r = auditRow(subject, cluster, ic, nEpochsFile, nMapRows, nMatched, ...
    nTrials, medResid, nNonFinite, cycWin, baseWin, note)

r = table(subject, string(cluster), ic, nEpochsFile, nMapRows, nMatched, ...
    nTrials, medResid, nNonFinite, cycWin(1), cycWin(2), ...
    baselineOrNaN(baseWin, 1), baselineOrNaN(baseWin, 2), string(note), ...
    'VariableNames', {'SubjectID', 'Cluster', 'IC', 'nEpochsFile', ...
    'nMapRows', 'nMatched', 'nTrials', 'medianResidualMs', 'nNonFinite', ...
    'cycleStartMs', 'cycleEndMs', 'baseStartMs', 'baseEndMs', 'Note'});
end

function v = baselineOrNaN(w, i)
if isempty(w)
    v = NaN;
else
    v = w(i);
end
end
