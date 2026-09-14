function pow = load_cluster_power(paths, subjects, pairing, clusterName, opts)
%LOAD_CLUSTER_POWER  Single-trial spectral power of one cluster component.
%
%   POW = LOAD_CLUSTER_POWER(PATHS, SUBJECTS, PAIRING, CLUSTERNAME) reads the
%   single-trial time-frequency coefficients of the independent component each
%   participant contributes to the named cluster, converts them to power, crops
%   them to the warped movement cycle, and drops the epochs that PAIRING found
%   no experiment counterpart for.
%
%   The stored coefficients are complex, so power is obtained as z times its own
%   conjugate. No baseline correction and no logarithm are applied here. Both
%   are left to the caller because a lagged Pearson correlation is invariant to
%   any positive rescaling of either signal, so a divisive baseline changes the
%   result only through the weighting of frequencies inside a band.
%
%   Participants with no component in the cluster get an empty entry rather than
%   being silently dropped, so downstream code can mask on ISEMPTY instead of on
%   a hard-coded row number.
%
%   OPTS fields:
%     icFile    full path to the file holding the cluster to component mapping,
%               a cell array named SUBJECTS_ICS whose first column is the
%               cluster name and whose second column is a struct with the
%               fields Subjects and ICs
%     verbose   print progress (default true)
%
%   POW is a struct with fields:
%     subject      [nSubjects x 1] participant numbers, matching SUBJECTS
%     ic           [nSubjects x 1] component index, NaN where absent
%     power        {nSubjects x 1} each [nFreq x nTime x nEpoch], empty where
%                  the participant has no component in the cluster
%     trial        {nSubjects x 1} trial number of every epoch
%     freqs        [1 x nFreq] frequencies in Hz
%     pct          [1 x nTime] percent of the movement cycle
%     timewarpms   the group warp landmarks in milliseconds
%     warpFrac     fraction of the cycle at which extension begins
%     cluster      CLUSTERNAME
%
%   See also BUILD_EPOCH_PAIRING, RUN_CROSS_CORRELATION.
%
%   Part of the KneeExo-EEG analysis code.

arguments
    paths (1,1) struct
    subjects (1,:) double {mustBePositive, mustBeInteger}
    pairing (:,1) struct
    clusterName (1,:) char
    opts.icFile (1,:) char
    opts.verbose (1,1) logical = true
end

if exist(opts.icFile, 'file') ~= 2
    error('load_cluster_power:NoIcFile', ...
        ['Cannot find the cluster to component mapping at\n  %s\n', ...
         'In the original project this was Subjects_ICs_in_clusters.mat under ', ...
         'Final_paper_plot_generation/Detailed_Analysis_on_TF_regions.'], ...
        opts.icFile);
end

loaded = load(opts.icFile, 'SUBJECTS_ICS');
table  = loaded.SUBJECTS_ICS;

iCluster = find(strcmp(table(:, 1), clusterName));
if numel(iCluster) ~= 1
    error('load_cluster_power:ClusterLookup', ...
        'Cluster %s matches %d entries. Available: %s.', ...
        clusterName, numel(iCluster), strjoin(table(:, 1).', ', '));
end

entry = table{iCluster, 2};
if any(entry.Subjects < 1) || any(entry.Subjects > numel(subjects))
    error('load_cluster_power:SubjectIndex', ...
        ['Cluster %s refers to participant indices outside 1 to %d. The stored ', ...
         'indices are positions in the participant list, not participant ', ...
         'numbers, so the list passed in must be the one the clustering used.'], ...
        clusterName, numel(subjects));
end

memberSubject = subjects(entry.Subjects(:));
memberIC      = double(entry.ICs(:));

pow = struct();
pow.subject    = subjects(:);
pow.ic         = nan(numel(subjects), 1);
pow.power      = cell(numel(subjects), 1);
pow.trial      = cell(numel(subjects), 1);
pow.cluster    = clusterName;
pow.freqs      = [];
pow.pct        = [];
pow.timewarpms = [];
pow.warpFrac   = [];

for s = 1:numel(subjects)

    thisSubject = subjects(s);
    iMember     = find(memberSubject == thisSubject);

    if isempty(iMember)
        if opts.verbose
            fprintf('Participant %d: no component in %s\n', thisSubject, clusterName);
        end
        continue
    end
    if numel(iMember) > 1
        error('load_cluster_power:MultipleComponents', ...
            ['Participant %d contributes %d components to %s. One component ', ...
             'per participant must be selected before this step.'], ...
            thisSubject, numel(iMember), clusterName);
    end

    thisIC  = memberIC(iMember);
    compVar = sprintf('comp%d', thisIC);
    tfFile  = fullfile(paths.icatimef, sprintf('S%d.icatimef', thisSubject));

    if opts.verbose
        fprintf('Participant %d: loading %s from S%d.icatimef ...\n', ...
            thisSubject, compVar, thisSubject);
    end

    tf = load(tfFile, '-mat', compVar, 'times', 'freqs', 'parameters', ...
        'trialinfo');
    if ~isfield(tf, compVar)
        error('load_cluster_power:NoComponent', ...
            'S%d.icatimef holds no variable %s.', thisSubject, compVar);
    end

    z = tf.(compVar);
    p = real(z .* conj(z));

    ax         = read_cycle_axis(tf, thisSubject);
    timewarpms = ax.timewarpms;
    pct        = ax.pct;

    p = p(:, ax.keepTime, :);

    % Every participant shares one group warp target, so the axes must agree.
    % If they ever stop agreeing, the percent axis is no longer common and the
    % cross-correlation across participants is meaningless.
    if isempty(pow.pct)
        pow.pct        = pct;
        pow.freqs      = double(tf.freqs(:)).';
        pow.timewarpms = timewarpms;
        pow.warpFrac   = ax.warpFrac;
    else
        assert_same(pow.pct,        pct,        thisSubject, 'time axis');
        assert_same(pow.freqs,      double(tf.freqs(:)).', thisSubject, 'frequency axis');
        assert_same(pow.timewarpms, timewarpms, thisSubject, 'warp landmarks');
    end

    % Drop the epochs whose trial never reached the experiment stream, then put
    % the survivors in the order BUILD_EPOCH_PAIRING paired them in.
    iPair = find([pairing.subject] == thisSubject);
    if numel(iPair) ~= 1
        error('load_cluster_power:PairingLookup', ...
            'Participant %d appears %d times in the pairing.', ...
            thisSubject, numel(iPair));
    end

    keepTF = pairing(iPair).keepTF;
    if max(keepTF) > size(p, 3)
        error('load_cluster_power:EpochCount', ...
            ['Participant %d: the pairing refers to epoch %d but the loaded ', ...
             'component has only %d. The pairing is stale, rebuild it.'], ...
            thisSubject, max(keepTF), size(p, 3));
    end

    trials = cellfun(@str2double_or_num, {tf.trialinfo.trial}).';

    pow.ic(s)    = thisIC;
    pow.power{s} = p(:, :, keepTF);
    pow.trial{s} = trials(keepTF);

end

if isempty(pow.pct)
    error('load_cluster_power:NoMembers', ...
        'No participant in the list contributes a component to %s.', clusterName);
end

end


% ----------------------------------------------------------------------------
function assert_same(a, b, subject, what)
%ASSERT_SAME  Fail loudly when a shared axis is not shared after all.

if ~isequal(numel(a), numel(b)) || max(abs(a - b)) > 1e-6
    error('load_cluster_power:AxisMismatch', ...
        ['Participant %d has a different %s from the participants before it. ', ...
         'All participants must share one group warp target.'], subject, what);
end

end


% ----------------------------------------------------------------------------
function v = str2double_or_num(x)
%STR2DOUBLE_OR_NUM  Trial numbers are stored as text in some files.

if isnumeric(x)
    v = double(x);
else
    v = str2double(x);
end

end
