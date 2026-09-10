function [STUDY, ALLEEG] = precompute_timewarped_ersp(STUDY, ALLEEG, p, warpMode)
% PRECOMPUTE_TIMEWARPED_ERSP  Compute and store per-IC time-warped ERSPs.
%
%   [STUDY, ALLEEG] = PRECOMPUTE_TIMEWARPED_ERSP(STUDY, ALLEEG, P)
%   [STUDY, ALLEEG] = PRECOMPUTE_TIMEWARPED_ERSP(STUDY, ALLEEG, P, WARPMODE)
%
%   P         parameter struct from ersp_params()
%   WARPMODE  'groupmedian' (default) warp every subject to the group median
%               event latencies, so that subjects can be averaged pixel by
%               pixel
%             'subject'      warp each subject to its own median latencies
%
% Writes one .icatimef file per subject next to the subject's dataset. This
% is the expensive step -- hours for the full set -- and it only has to run
% once; everything downstream reads the .icatimef files back.
%
% Each epoch is one flexion-to-flexion movement cycle. Cycles differ in
% duration within and between subjects, so they are time-warped onto a
% common set of event latencies before the time-frequency decomposition;
% without that, averaging would smear the movement-locked structure.
%
% Requires ALLEEG(i).timewarp to be populated for every dataset (produced by
% the epoching stage).

    if nargin < 4 || isempty(warpMode)
        warpMode = 'groupmedian';
    end

    check_timewarp_present(ALLEEG);

    switch lower(warpMode)
        case 'groupmedian'
            warpingValues = group_median_warpto(ALLEEG, p.ersp.warpRoundToMs);
            fprintf('Warping all subjects to group median latencies:\n');
            fprintf('  %s ms\n', mat2str(warpingValues));
        case 'subject'
            % An all-zero vector is the placeholder that tells
            % std_precomp_timewarp to substitute each subject's own warpto.
            warpingValues = zeros(1, numel(ALLEEG(1).timewarp.warpto));
            fprintf('Warping each subject to its own median latencies.\n');
        otherwise
            error('precompute_timewarped_ersp:BadWarpMode', ...
                'warpMode must be ''groupmedian'' or ''subject'', got ''%s''.', ...
                warpMode);
    end

    erspParams = { ...
        'cycles',     p.ersp.cycles, ...
        'freqs',      p.ersp.freqs, ...
        'nfreqs',     p.ersp.nfreqs, ...
        'padratio',   p.ersp.padratio, ...
        'alpha',      p.ersp.alpha, ...
        'freqscale',  p.ersp.freqscale, ...
        'savetrials', p.ersp.savetrials, ...
        'baseline',   p.ersp.baseline, ...
        'basenorm',   p.ersp.basenorm, ...
        'trialbase',  p.ersp.trialbase, ...
        'timewarp',   0, ...                  % placeholder, see the fork notice
        'timewarpms', warpingValues};

    tStart = tic;
    [STUDY, ALLEEG] = std_precomp_timewarp(STUDY, ALLEEG, 'components', ...
        'ersp', 'on', 'itc', 'off', ...
        'erspparams', erspParams, ...
        'recompute', 'on');
    fprintf('ERSP precomputation finished in %.1f min.\n', toc(tStart)/60);
end


function check_timewarp_present(ALLEEG)
    missing = find(arrayfun(@(E) ~isfield(E, 'timewarp') || ...
        isempty(E.timewarp) || ~isfield(E.timewarp, 'warpto'), ALLEEG));
    if ~isempty(missing)
        error('precompute_timewarped_ersp:NoTimewarp', ...
            ['Datasets %s have no .timewarp.warpto. Run the epoching stage ' ...
             'first -- ERSPs here are computed on time-warped epochs.'], ...
            mat2str(missing));
    end
end


function warpingValues = group_median_warpto(ALLEEG, roundToMs)
% Median event latency across subjects, rounded to a multiple of roundToMs.
    nEvents = numel(ALLEEG(1).timewarp.warpto);
    warps = zeros(numel(ALLEEG), nEvents);
    for i = 1:numel(ALLEEG)
        thisWarp = ALLEEG(i).timewarp.warpto;
        if numel(thisWarp) ~= nEvents
            error('precompute_timewarped_ersp:WarpLengthMismatch', ...
                ['Dataset %d has %d warp events but dataset 1 has %d. ' ...
                 'All datasets must share the same event structure.'], ...
                i, numel(thisWarp), nEvents);
        end
        warps(i,:) = thisWarp;
    end
    warpingValues = round(median(warps, 1) / roundToMs) * roundToMs;
end
