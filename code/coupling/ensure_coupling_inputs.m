function in = ensure_coupling_inputs(C, opts)
%ENSURE_COUPLING_INPUTS  Build or load the cached inputs of the coupling analysis.
%
%   IN = ENSURE_COUPLING_INPUTS(C) returns the epoch pairing and the warped
%   tracking error, building either one if its cache is missing or stale and
%   loading it otherwise. C comes from COUPLING_CONFIG.
%
%   Both the entry point and the audit script call this, so the audit can be run
%   first on a clean checkout: it builds what it needs to audit rather than
%   failing on a missing file.
%
%   OPTS fields:
%     needPower        also load the single-trial power of the cluster
%                      component (default false). The audit does not need it,
%                      the analysis does
%     rebuildPairing   rebuild the pairing even if its cache exists
%     rebuildError     rebuild the warped tracking error even if its cache exists
%     verbose          print progress (default true)
%
%   IN fields:
%     pairing   struct array from BUILD_EPOCH_PAIRING
%     axis      the movement-cycle axis, from READ_CYCLE_AXIS
%     trk       struct array from BUILD_WARPED_TRACKING_ERROR
%     pow       struct from LOAD_CLUSTER_POWER, empty unless needPower is true
%     stamp     provenance of whatever was built in this call
%
%   Building the pairing needs EEGLAB, because it reads the urevent tables
%   through POP_LOADSTUDY. Nothing else here does.
%
%   See also COUPLING_CONFIG, RUN_CROSS_CORRELATION, EPOCH_PAIRING_CHECK.
%
%   Part of the KneeExo-EEG analysis code.

arguments
    C (1,1) struct
    opts.needPower (1,1) logical = false
    opts.rebuildPairing (1,1) logical = false
    opts.rebuildError (1,1) logical = false
    opts.verbose (1,1) logical = true
end

in = struct('pairing', [], 'axis', [], 'trk', [], 'pow', [], 'stamp', []);
in.stamp = coupling_stamp(C);

%% ---- the cycle axis, read from one file without loading any component ----
firstFile = fullfile(C.paths.icatimef, sprintf('S%d.icatimef', C.subjects(1)));
in.axis   = read_cycle_axis(firstFile);

if opts.verbose
    fprintf(['Cycle axis: %d samples from %.1f%% to %.1f%%, extension ' ...
        'begins at %.1f%%\n'], numel(in.axis.pct), in.axis.pct(1), ...
        in.axis.pct(end), 100*in.axis.warpFrac);
end

%% ---- step 1, the epoch pairing ------------------------------------------
if opts.rebuildPairing || exist(C.files.pairing, 'file') ~= 2

    if opts.verbose
        fprintf('Building the epoch pairing. This needs EEGLAB.\n');
    end
    start_eeglab_if_needed();

    pairing = build_epoch_pairing(C.paths, C.subjects, ...
        'studyName', C.cluster, 'toleranceMs', C.toleranceMs, ...
        'verbose', opts.verbose);

    pairingStamp = in.stamp; %#ok<NASGU>
    save(C.files.pairing, 'pairing', 'pairingStamp', '-v7.3');
    fprintf('Pairing written to %s\n', C.files.pairing);

else

    if opts.verbose
        fprintf('Loading the cached pairing from %s\n', C.files.pairing);
    end
    loaded  = load(C.files.pairing, 'pairing');
    pairing = loaded.pairing;

    missing = setdiff(C.subjects, [pairing.subject]);
    if ~isempty(missing)
        error('ensure_coupling_inputs:StalePairing', ...
            ['The cached pairing has no entry for participant(s) %s. Set ' ...
            'rebuildPairing to true.'], mat2str(missing));
    end

end

in.pairing = pairing;

%% ---- step 2, the warped tracking error ----------------------------------
needRebuild = opts.rebuildError || exist(C.files.error, 'file') ~= 2;
trk         = [];

if ~needRebuild

    loaded = load(C.files.error, 'trk', 'errorAxis');
    trk    = loaded.trk;

    sameAxis = isfield(loaded, 'errorAxis') && ...
        numel(loaded.errorAxis.pct) == numel(in.axis.pct) && ...
        max(abs(loaded.errorAxis.pct - in.axis.pct)) <= 1e-6;

    if ~sameAxis
        fprintf(['The cached tracking error sits on a different cycle axis, ' ...
            'so it is being rebuilt.\n']);
        needRebuild = true;
    elseif opts.verbose
        fprintf('Loading the cached tracking error from %s\n', C.files.error);
    end

end

if needRebuild

    trk = build_warped_tracking_error(C.paths, C.subjects, in.axis.pct, ...
        in.axis.warpFrac, 'verbose', opts.verbose);

    errorStamp = in.stamp; %#ok<NASGU>
    errorAxis  = struct('pct', in.axis.pct, 'warpFrac', in.axis.warpFrac, ...
        'timewarpms', in.axis.timewarpms); %#ok<NASGU>
    save(C.files.error, 'trk', 'errorStamp', 'errorAxis', '-v7.3');
    fprintf('Warped tracking error written to %s\n', C.files.error);

end

in.trk = trk;

%% ---- step 3, the cluster power, only when it is wanted -------------------
if opts.needPower
    in.pow = load_cluster_power(C.paths, C.subjects, in.pairing, C.cluster, ...
        'icFile', C.clusterICFile, 'verbose', opts.verbose);
end

end


% ----------------------------------------------------------------------------
function start_eeglab_if_needed()
%START_EEGLAB_IF_NEEDED  Make POP_LOADSTUDY available without opening a window.

if ~isempty(which('pop_loadstudy'))
    return
end

if exist('eeglab', 'file') ~= 2
    error('ensure_coupling_inputs:NoEEGLAB', ...
        ['EEGLAB is needed to read the urevent tables but is not on the ' ...
        'MATLAB path. Add it, or restore an existing epoch_pairing_map.mat.']);
end

eeglab nogui

end


% ----------------------------------------------------------------------------
function s = coupling_stamp(C)
%COUPLING_STAMP  Provenance of a written file.
%
%   This mirrors behaviour/build_stamp.m. If that function is generalised to
%   take an arbitrary builder path, replace this with a call to it.

builderFile = which('run_cross_correlation');
info        = dir(builderFile);

s = struct();
s.written  = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
s.builder  = builderFile;
s.subjects = C.subjects;
s.cluster  = C.cluster;
s.matlab   = version;

if isempty(info)
    s.builderModified = '';
else
    s.builderModified = char(datetime(info.datenum, 'ConvertFrom', 'datenum', ...
        'Format', 'yyyy-MM-dd HH:mm:ss'));
end

s.gitCommit = git_commit(C.cfg.root);

end


% ----------------------------------------------------------------------------
function c = git_commit(repoRoot)
%GIT_COMMIT  Short hash of the checked out commit, marked when the tree is dirty.

c = 'unknown';

[status, out] = system(sprintf('git -C "%s" rev-parse --short HEAD', repoRoot));
if status ~= 0
    return
end
c = strtrim(out);

[status, out] = system(sprintf('git -C "%s" status --porcelain', repoRoot));
if status == 0 && ~isempty(strtrim(out))
    c = [c ' (working tree modified)'];
end

end
