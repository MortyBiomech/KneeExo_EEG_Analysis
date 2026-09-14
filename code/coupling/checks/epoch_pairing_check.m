%EPOCH_PAIRING_CHECK  Audit the join between EEG and experiment epochs.
%
%   Everything in the coupling analysis rests on one claim: that row k of the
%   power matrix and row k of the tracking error matrix describe the same
%   movement cycle. This script tests that claim and prints the evidence, so it
%   can be run before anyone trusts a coupling number.
%
%   It builds whatever it needs to audit. On a clean checkout the first run
%   creates the epoch pairing, which needs EEGLAB, and the warped tracking
%   error, and caches both in data/derived. Later runs read the caches. The
%   settings come from COUPLING_CONFIG, the same file the analysis reads, so
%   the two can never audit different things.
%
%   What it reports, per participant:
%
%     1  how many time-frequency epochs were paired, and how many were dropped
%        because their whole trial never reached the experiment stream
%     2  the distribution of the residual time difference of every match. A
%        correct match is accurate to a few milliseconds, because movement
%        cycles are about a second apart. A residual of tens of milliseconds
%        means the sampling rate or the event table is wrong
%     3  whether any two epochs were matched to the same experiment epoch
%     4  whether the tracking error and the power share one cycle axis, and
%        whether either carries a NaN. This is the failure the original script
%        was exposed to, where the error was interpolated from a sample index
%        grid onto a percentage query axis
%     5  the flexion to extension transition, as the EEG warp places it and as
%        the experiment stream observes it. A gap between the two displaces the
%        peak of any cross-correlation by exactly that gap, and its size says
%        how far the original analysis was off
%
%   Open this file and press Run.
%
%   See also COUPLING_CONFIG, ENSURE_COUPLING_INPUTS, RUN_CROSS_CORRELATION.
%
%   Part of the KneeExo-EEG analysis code.

clear
clc

thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('epoch_pairing_check');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open epoch_pairing_check.m and press Run, ' ...
        'or add <repo>/code/config to the MATLAB path by hand.']);
end
addpath(fullfile(fileparts(fileparts(fileparts(thisFile))), 'config'));

cfg = kneeexo_config();
add_code_paths(cfg);

C = coupling_config(cfg);

% Rebuild rather than audit the cache. Leave both false for a normal audit.
REBUILD_PAIRING = false;
REBUILD_ERROR   = false;

in = ensure_coupling_inputs(C, 'needPower', false, ...
    'rebuildPairing', REBUILD_PAIRING, 'rebuildError', REBUILD_ERROR);

pairing = in.pairing;
trk     = in.trk;

fprintf('\n');
fprintf('Epoch pairing audit, %s, participants %d to %d\n', ...
    strrep(C.cluster, '_', ' '), C.subjects(1), C.subjects(end));
fprintf('%s\n\n', repmat('=', 1, 88));

problems = {};


%% ---------------------------------------------------------------------------
%  1 to 3, the pairing itself
%  ---------------------------------------------------------------------------
fprintf('%-6s %8s %8s %8s %12s %12s %10s\n', ...
    'sub', 'tf', 'paired', 'dropped', 'median res', 'worst res', 'one to one');
fprintf('%s\n', repmat('-', 1, 88));

allResidual = [];

for s = 1:numel(pairing)

    p = pairing(s);
    if isempty(p.expRow)
        fprintf('%-6d %8s %8s %8s %12s %12s %10s\n', p.subject, ...
            '-', '-', '-', '-', '-', 'no data');
        continue
    end

    oneToOne    = numel(unique(p.expRow)) == numel(p.expRow);
    allResidual = [allResidual; p.residualMs]; %#ok<AGROW>

    fprintf('%-6d %8d %8d %8d %12.3f %12.3f %10s\n', p.subject, p.nTF, ...
        numel(p.expRow), numel(p.dropTF), median(p.residualMs), ...
        max(p.residualMs), yes_no(oneToOne));

    if ~oneToOne
        problems{end+1} = sprintf(['participant %d matched several epochs ' ...
            'to the same experiment epoch'], p.subject); %#ok<AGROW>
    end
    if max(p.residualMs) > 10
        problems{end+1} = sprintf(['participant %d has a worst match ' ...
            'residual of %.1f ms'], p.subject, max(p.residualMs)); %#ok<AGROW>
    end

end

fprintf('%s\n', repmat('-', 1, 88));
fprintf(['All matches: median %.3f ms, 95th percentile %.3f ms, ' ...
    'worst %.3f ms\n\n'], median(allResidual), prctile(allResidual, 95), ...
    max(allResidual));


%% ---------------------------------------------------------------------------
%  4, the shared cycle axis
%  ---------------------------------------------------------------------------
fprintf('Cycle axis\n');
fprintf('%s\n', repmat('-', 1, 88));
fprintf('Warp landmarks: %s ms\n', mat2str(in.axis.timewarpms));
fprintf('Shared axis: %d samples from %.2f%% to %.2f%%\n', ...
    numel(in.axis.pct), in.axis.pct(1), in.axis.pct(end));
fprintf('EEG places the extension onset at %.2f%% of the cycle\n', ...
    100*in.axis.warpFrac);

nanCount       = 0;
sampleMismatch = 0;
for s = 1:numel(trk)
    if isempty(trk(s).error)
        continue
    end
    nanCount = nanCount + sum(isnan(trk(s).error(:)));
    if size(trk(s).error, 2) ~= numel(in.axis.pct)
        sampleMismatch = sampleMismatch + 1;
    end
end

fprintf('NaN values in the warped tracking error: %d\n', nanCount);
fprintf('Participants whose error is on a different axis: %d\n\n', sampleMismatch);

if nanCount > 0
    problems{end+1} = sprintf(['the warped tracking error holds %d NaN ' ...
        'values, so some epochs were queried outside their own time range'], ...
        nanCount); %#ok<AGROW>
end
if sampleMismatch > 0
    problems{end+1} = ['the tracking error and the power are on ' ...
        'different axes']; %#ok<AGROW>
end


%% ---------------------------------------------------------------------------
%  5, where the transition actually sits
%  ---------------------------------------------------------------------------
fprintf('Flexion to extension transition, observed in the experiment stream\n');
fprintf('%s\n', repmat('-', 1, 88));
fprintf('%-6s %10s %10s %10s %10s\n', 'sub', 'median %', 'iqr %', 'cycles', 'flagged');
fprintf('%s\n', repmat('-', 1, 88));

allTrans = [];
for s = 1:numel(trk)
    if isempty(trk(s).error)
        continue
    end
    tf       = 100 * trk(s).transFrac;
    allTrans = [allTrans; tf]; %#ok<AGROW>
    fprintf('%-6d %10.2f %10.2f %10d %10d\n', trk(s).subject, median(tf), ...
        iqr(tf), numel(tf), sum(trk(s).flagOutlier));
end

fprintf('%s\n', repmat('-', 1, 88));
gap = median(allTrans) - 100*in.axis.warpFrac;
fprintf(['Group median transition %.2f%% against the EEG warp target %.2f%%, ' ...
    'a gap of %.2f%% of the cycle\n'], median(allTrans), ...
    100*in.axis.warpFrac, gap);
fprintf(['The error is anchored to the EEG target, so this gap is what the ' ...
    'original analysis left uncorrected.\n\n']);

if abs(gap) > 2
    problems{end+1} = sprintf(['the experiment stream places the transition ' ...
        '%.2f%% of the cycle away from the EEG warp target, which is how far ' ...
        'the two signals were misaligned before'], gap); %#ok<AGROW>
end


%% ---------------------------------------------------------------------------
%  Verdict
%  ---------------------------------------------------------------------------
fprintf('%s\n', repmat('=', 1, 88));
if isempty(problems)
    fprintf('No problems found. The pairing supports a coupling analysis.\n');
else
    fprintf('%d point(s) to note:\n', numel(problems));
    for k = 1:numel(problems)
        fprintf('  %d. %s\n', k, problems{k});
    end
end
fprintf('\n');


function s = yes_no(tf)
if tf
    s = 'yes';
else
    s = 'NO';
end
end
