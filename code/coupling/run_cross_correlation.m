%RUN_CROSS_CORRELATION  Entry point C1. Coupling of band power and tracking error.
%
%   Question this answers
%   ---------------------
%   Parieto-occipital theta and alpha power rise and fall within the movement
%   cycle, and so does the knee tracking error. Two signals that share the same
%   cyclic structure correlate strongly whether or not they have anything to do
%   with each other, so the shared shape on its own says nothing. The question
%   is whether the power of a given trial carries information about the error of
%   that same trial, over and above the cycle both of them follow.
%
%   The analysis therefore runs in three modes on the same prepared data:
%
%     mean      the cyclic waveform of each participant and condition, averaged
%               over trials, correlated against the error waveform. This
%               quantifies the shared cyclic structure and nothing else.
%     actual    every trial correlated as recorded. Dominated by the same cyclic
%               structure, but attenuated relative to the mean mode, because
%               single-trial noise shrinks a correlation while averaging over
%               trials does not. This is the mode the figure draws.
%     residual  the condition mean waveform removed from both signals first, so
%               only trial-to-trial fluctuation is left. This is the mode that
%               answers the question.
%
%   Modes actual and residual are tested against a null built by permuting the
%   trial labels of the power within each participant. The observed statistic is
%   the largest absolute group mean correlation over all lags, which controls the
%   family-wise error rate over lags without a further correction.
%
%   Pipeline
%   --------
%     1  BUILD_EPOCH_PAIRING          re-pair the EEG and experiment epochs
%     2  BUILD_WARPED_TRACKING_ERROR  error on the EEG movement-cycle axis
%     3  LOAD_CLUSTER_POWER           single-trial power of the cluster component
%     4  PREPARE_TRIAL_MATRICES       band average, aggregate, split by condition
%     5  CROSSCORR_PERMUTATION        group statistic and its null
%     6  PLOT_FIGURE5_COUPLING        the figure
%
%   Steps 1 and 2 are the expensive ones, are cached in data/derived and are
%   handled by ENSURE_COUPLING_INPUTS. Step 1 reads the urevent tables of the
%   per-participant datasets rather than any cluster solution, so its result is
%   shared by every cluster.
%
%   Usage
%   -----
%   Open this file and press Run. The analysis settings live in
%   COUPLING_CONFIG, which CHECKS/EPOCH_PAIRING_CHECK reads as well, so the two
%   cannot disagree. Only the run-time choices are below.
%
%   See also COUPLING_CONFIG, EPOCH_PAIRING_CHECK, RUN_RESULTS_BEHAVIOUR.
%
%   Part of the KneeExo-EEG analysis code.

clear
clc

%% ---------------------------------------------------------------------------
%  Bootstrap. Locate config/ relative to this file.
%  ---------------------------------------------------------------------------
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('run_cross_correlation');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open run_cross_correlation.m and press ' ...
        'Run, or add <repo>/code/config to the MATLAB path by hand.']);
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));

cfg = kneeexo_config();
add_code_paths(cfg);

C = coupling_config(cfg);


%% ---------------------------------------------------------------------------
%  Run-time choices. Everything else is in coupling_config.m
%  ---------------------------------------------------------------------------

% Rebuild the cached inputs even when they exist. Needed after a change to the
% upstream data, or to the participant list.
REBUILD_PAIRING = false;
REBUILD_ERROR   = false;

% Reuse a stored result when it was produced with the current settings.
USE_PRECOMPUTED = true;

% Reuse the stored permutation statistics when the ANALYSIS settings match, even
% if the stored result is otherwise out of date. The permutations are the slow
% part and they do not change when only the figure does, so leave this true
% while iterating on the figure. Set it false to force a fresh null.
REUSE_STATS = true;


%% ---------------------------------------------------------------------------
%  Short circuit on the cached result
%  ---------------------------------------------------------------------------
%  Two levels of reuse. If everything matches, the stored result is drawn as it
%  stands. If only the analysis settings match, the stored permutation
%  statistics are carried over and just the waveforms are rebuilt, which is the
%  case whenever the figure changed but the analysis did not.

% The settings the statistics actually depend on. Anything outside this list
% affects only how the result is stored or drawn.
STATS_FIELDS = {'cluster', 'subjects', 'bands', 'conditions', 'maxLagPct', ...
    'aggregate', 'dropZeroScore', 'dropOutlierCycles', 'baseline', ...
    'nPerm', 'rngSeed'};

reuseStats  = false;
cachedStats = [];

if exist(C.files.precomputed, 'file') == 2

    cached  = load(C.files.precomputed);
    changed = settings_differ(cached.settings, C.settings, {});

    if USE_PRECOMPUTED && isempty(changed) && isfield(cached.res, 'waveformAll')
        fprintf('Using the cached result in %s\n', C.files.precomputed);
        fprintf('  built %s\n', cached.stamp.written);
        res = cached.res;
        plot_figure5_coupling(res, 'outDir', C.files.figureDir, ...
            'baseName', C.files.figureName, 'formats', C.files.figureFormats);
        write_report(res, C);
        return
    end

    if ~isempty(changed)
        fprintf(['The cached result was built with different settings (%s).\n'], ...
            strjoin(changed, ', '));
    end

    changedStats = settings_differ(cached.settings, C.settings, STATS_FIELDS);

    if REUSE_STATS && isempty(changedStats) && isfield(cached.res, 'stats')
        reuseStats  = true;
        cachedStats = cached.res.stats;
        fprintf(['The analysis settings are unchanged, so the stored ' ...
            'permutation statistics are reused and only the waveforms are ' ...
            'rebuilt.\n']);
    end

end


%% ---------------------------------------------------------------------------
%  Steps 1 to 3. Pairing, warped tracking error, cluster power
%  ---------------------------------------------------------------------------
in = ensure_coupling_inputs(C, 'needPower', true, ...
    'rebuildPairing', REBUILD_PAIRING, 'rebuildError', REBUILD_ERROR);


%% ---------------------------------------------------------------------------
%  Step 4. Match, band average, aggregate
%  ---------------------------------------------------------------------------
data = prepare_trial_matrices(in.pow, in.trk, in.pairing, C.bands, ...
    'aggregate', C.aggregate, 'dropZeroScore', C.dropZeroScore, ...
    'dropOutlierCycles', C.dropOutlierCycles, 'baseline', C.baseline, ...
    'conditions', C.conditions);


%% ---------------------------------------------------------------------------
%  Step 5. Cross-correlation and its null
%  ---------------------------------------------------------------------------
pctPerSample = (in.axis.pct(end) - in.axis.pct(1)) / (numel(in.axis.pct) - 1);
maxLagSamp   = round(C.maxLagPct / pctPerSample);

bandNames = fieldnames(C.bands);
modes     = {'mean', 'actual', 'residual'};

res = struct();
res.cluster      = C.cluster;
res.subjects     = C.subjects;
res.conditions   = C.conditions;
res.pct          = in.axis.pct;
res.warpFrac     = in.axis.warpFrac;
res.lagPerSample = pctPerSample;
res.maxLagSamp   = maxLagSamp;
res.bands        = C.bands;
res.nTrials      = data.nTrials;
res.stats        = struct();

if reuseStats

    res.stats = cachedStats;

else

    for m = 1:numel(modes)

        mode  = modes{m};
        nPerm = C.nPerm;
        if strcmp(mode, 'mean')
            nPerm = 0;
        end

        for b = 1:numel(bandNames)

            band = bandNames{b};

            for c = 1:numel(C.conditions)

                fprintf('%s, %s band, pressure %g ...\n', mode, band, ...
                    C.conditions(c));

                [Ecell, Pcell] = mode_signals(data.E(:, c), ...
                    data.P.(band)(:, c), mode);

                res.stats.(mode).(band)(c) = crosscorr_permutation(Ecell, Pcell, ...
                    'maxLag', maxLagSamp, 'nPerm', nPerm, ...
                    'rngSeed', C.rngSeed + 1000*m + 100*b + c);

            end

        end

    end

end


%% ---------------------------------------------------------------------------
%  Cyclic waveforms for panel a
%  ---------------------------------------------------------------------------
%  Kept per participant and expressed as percent change from that participant's
%  own cycle mean, so that the tracking error in degrees and the spectral power
%  in arbitrary units share one axis honestly and the figure can show a standard
%  error across participants.
res.waveformAll = struct();
res.waveformAll.error = percent_waveform(data.E);
for b = 1:numel(bandNames)
    band = bandNames{b};
    res.waveformAll.(band) = percent_waveform(data.P.(band));
end


%% ---------------------------------------------------------------------------
%  Save and draw
%  ---------------------------------------------------------------------------
settings = C.settings; %#ok<NASGU>
stamp    = in.stamp;   %#ok<NASGU>
save(C.files.precomputed, 'res', 'settings', 'stamp', '-v7.3');
fprintf('Result written to %s\n', C.files.precomputed);

plot_figure5_coupling(res, 'outDir', C.files.figureDir, ...
    'baseName', C.files.figureName, 'formats', C.files.figureFormats);
write_report(res, C);


%% ===========================================================================
%  Local functions
%  ===========================================================================

function [Ecell, Pcell] = mode_signals(Ein, Pin, mode)
%MODE_SIGNALS  Turn the prepared matrices into the signals a mode correlates.

Ecell = cell(size(Ein));
Pcell = cell(size(Pin));

for s = 1:numel(Ein)

    E = Ein{s};
    P = Pin{s};

    if isempty(E) || isempty(P) || size(E, 1) < 2
        continue
    end

    switch mode
        case 'mean'
            Ecell{s} = mean(E, 1);
            Pcell{s} = mean(P, 1);
        case 'actual'
            Ecell{s} = E;
            Pcell{s} = P;
        case 'residual'
            Ecell{s} = E - mean(E, 1);
            Pcell{s} = P - mean(P, 1);
        otherwise
            error('run_cross_correlation:UnknownMode', 'Unknown mode %s.', mode);
    end

end

end


function W = percent_waveform(cellIn)
%PERCENT_WAVEFORM  One cyclic waveform per participant, in percent of its mean.
%
%   Each condition is averaged first and the conditions are then averaged
%   together, so a condition with more trials does not pull the waveform towards
%   itself. The result is expressed as percent change from that participant's own
%   cycle mean, which puts signals of different units on a common scale without
%   a second y axis.

[nSub, nCond] = size(cellIn);

nPct = 0;
for s = 1:nSub
    if ~isempty(cellIn{s, 1})
        nPct = size(cellIn{s, 1}, 2);
        break
    end
end

W = nan(nSub, nPct);

for s = 1:nSub

    acc = nan(nCond, nPct);
    for c = 1:nCond
        if isempty(cellIn{s, c})
            continue
        end
        acc(c, :) = mean(cellIn{s, c}, 1);
    end

    if all(isnan(acc(:)))
        continue
    end

    w    = mean(acc, 1, 'omitnan');
    base = mean(w);

    if ~isfinite(base) || base == 0
        W(s, :) = w - mean(w);
    else
        W(s, :) = 100 * (w - base) / abs(base);
    end

end

end


function changed = settings_differ(stored, current, onlyThese)
%SETTINGS_DIFFER  Names of the settings that do not match.
%
%   Pass a cell array in ONLYTHESE to compare just those fields, which is how
%   the caller asks whether the ANALYSIS settings match while ignoring fields
%   that affect only how the result is stored or drawn. Pass {} to compare all.

changed = {};

if isempty(onlyThese)
    names = fieldnames(current);
else
    names = onlyThese;
end

for k = 1:numel(names)
    if ~isfield(current, names{k})
        continue
    end
    if ~isfield(stored, names{k}) || ~isequaln(stored.(names{k}), current.(names{k}))
        changed{end+1} = names{k}; %#ok<AGROW>
    end
end

end


function write_report(res, C)
%WRITE_REPORT  Print the numbers to the console and to the figure's folder.
%
%   Every other figure in this manuscript ships a stats report beside it, so
%   this one does too. Console and file are written from the same code, so they
%   cannot drift apart.

fid = fopen(C.files.statsReport, 'w');
if fid < 0
    warning('run_cross_correlation:NoReport', ...
        'Cannot write %s, so the report goes to the console only.', ...
        C.files.statsReport);
    report_coupling(res, C, 1);
    return
end

cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
report_coupling(res, C, [1 fid]);
fprintf('Report written to %s\n', C.files.statsReport);

end


function report_coupling(res, C, fids)
%REPORT_COUPLING  Write the numbers the manuscript needs to each open stream.

bandNames = fieldnames(res.bands);

emit(fids, '\n');
emit(fids, 'Figure 5, coupling of band power and tracking error\n');
emit(fids, 'Cluster      %s\n', strrep(res.cluster, '_', ' '));
emit(fids, 'Written      %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
emit(fids, 'Observation  %s level, score zero %s\n', C.aggregate, ...
    ternary(C.dropZeroScore, 'excluded', 'kept'));
emit(fids, 'Lags         %+d to %+d%% of the cycle\n', -C.maxLagPct, C.maxLagPct);
emit(fids, 'Permutations %d, seed %d\n', C.nPerm, C.rngSeed);
emit(fids, '\nPositive lag means power follows error.\n');
emit(fids, ['Peak is the largest positive correlation, trough the largest ' ...
    'negative one.\n']);
emit(fids, ['The test statistic is the larger of the two in absolute value, ' ...
    'over all lags.\n']);
emit(fids, '%s\n', repmat('-', 1, 78));
emit(fids, '%-9s %-6s %-9s %8s %7s %8s %7s %10s\n', ...
    'mode', 'band', 'pressure', 'peak r', 'lag %', 'trough r', 'lag %', 'p');

for m = {'mean', 'actual', 'residual'}

    mode = m{1};

    for b = 1:numel(bandNames)

        band = bandNames{b};

        for c = 1:numel(res.conditions)

            st = res.stats.(mode).(band)(c);

            if isnan(st.pOmnibus)
                pStr = 'n.a.';
            elseif st.pOmnibus <= 1/(st.settings.nPerm + 1)
                pStr = sprintf('< %.4f', 1/(st.settings.nPerm + 1));
            else
                pStr = sprintf('%.4f', st.pOmnibus);
            end

            [peakR,   iPk] = max(st.groupMean);
            [troughR, iTr] = min(st.groupMean);

            emit(fids, '%-9s %-6s %-9g %8.3f %7.1f %8.3f %7.1f %10s\n', ...
                mode, band, res.conditions(c), ...
                peakR,   st.lags(iPk) * res.lagPerSample, ...
                troughR, st.lags(iTr) * res.lagPerSample, pStr);

        end

    end

end

emit(fids, '%s\n', repmat('-', 1, 78));
emit(fids, 'n = %d participants, %d to %d observations each per condition\n', ...
    res.stats.residual.(bandNames{1})(1).nSubjects, ...
    min(res.nTrials(res.nTrials > 0)), max(res.nTrials(:)));
emit(fids, '\n');

end


function emit(fids, varargin)
%EMIT  One formatted line to every open stream.

for f = fids
    fprintf(f, varargin{:});
end

end


function out = ternary(cond, a, b)
%TERNARY  Pick one of two strings, to keep the report lines on one line.

if cond
    out = a;
else
    out = b;
end

end