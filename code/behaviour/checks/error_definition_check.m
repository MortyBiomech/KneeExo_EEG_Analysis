%% ERROR_DEFINITION_CHECK
%  The rebuilt tracking error is a uniform 1.22 to 1.24 times the
%  published values: 7.01 against 5.73, 7.49 against 6.06, 7.63 against
%  6.19. A constant multiplier across all three conditions is the
%  signature of a different formula, not a different trial set, which
%  would shift the conditions by differing amounts.
%
%  Four candidates, differing in the summary statistic and in the order
%  of operations. Averaging the waveform across epochs before summarising
%  suppresses cycle-to-cycle variability and yields a smaller number than
%  summarising each epoch first, so the order matters as much as the
%  choice between RMS and mean absolute.
%
%  This matters beyond bookkeeping: the manuscript states root-mean-square
%  and reports 5.73. If that figure is a mean absolute error, the label is
%  wrong. If it is an RMS computed in a different order, the number stands
%  but the Methods must say which order.
% =====================================================================

clc
clear

%% 0. Configuration
% ---------------------------------------------------------------------
% config/ is three levels up from code/<stage>/checks/.
%
% mfilename is empty at the command prompt and reports a temporary helper
% file when a single %% section is run, so fall back to this file's name.
thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('error_definition_check');
end
if isempty(thisFile)
    error(['Cannot locate config/. Open error_definition_check.m and press Run, ' ...
           'or make its folder the current folder first.']);
end
addpath(fullfile(fileparts(fileparts(fileparts(thisFile))), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);

if isempty(cfg.raw)
    error(['This reads the master tables written by run_build_masters.m. ' ...
           'Set cfg.raw in config/local_paths.m.']);
end

out_path = cfg.masters;     % masters and the behaviour table

LEVELS     = [1 3 6];
COND_NAMES = {'Low','Medium','High'};
TARGET     = [5.73 6.06 6.19];

load(fullfile(out_path,'trk_master_index.mat'), 'masterIndex');
X = masterIndex; clear masterIndex

keep = X.IsExperiment & X.EpochHasSignal & X.LengthsMatch & ...
       X.EventsValid & X.ScoreValid & ismember(X.Pressure, LEVELS);
fprintf('Epochs retained: %d of %d\n', sum(keep), height(X));

subs = unique(X.SubjectID);
rows = find(keep);

% Group epochs by trial once, then evaluate every definition on the same
% grouping so only the formula varies.
[g, trialKey] = findgroups(X(keep, {'SubjectID','RawTrial'}));
trialPres = splitapply(@(x) x(1), X.Pressure(keep), g);

defs = { ...
 'A  mean over epochs of per-epoch RMS',        @(sub) splitapply(@mean, X.RMSError(keep),     g); ...
 'B  mean over epochs of per-epoch mean-abs',   @(sub) splitapply(@mean, X.MeanAbsError(keep), g); ...
 'C  RMS over all samples pooled in the trial', @(sub) pooledStat(X, rows, g, 'rms'); ...
 'D  mean-abs over all samples pooled',         @(sub) pooledStat(X, rows, g, 'mad')};

fprintf('\n%-42s %8s %8s %8s %10s\n', 'Definition', COND_NAMES{:}, 'maxDiff');
fprintf('%s\n', repmat('-', 1, 80));

for d = 1:size(defs,1)
    v = defs{d,2}(0);

    % Per-subject condition means, then across subjects, matching how the
    % published values were computed.
    M = nan(numel(subs), 3);
    for i = 1:numel(subs)
        for c = 1:3
            sel = trialKey.SubjectID == subs(i) & trialPres == LEVELS(c);
            if any(sel), M(i,c) = mean(v(sel)); end
        end
    end
    got = mean(M, 1, 'omitnan');
    fprintf('%-42s %8.2f %8.2f %8.2f %10.2f\n', ...
        defs{d,1}, got(1), got(2), got(3), max(abs(got - TARGET)));
end

fprintf(['\nThe definition matching the published values is the one the\n' ...
         'behaviour table used. A residual difference of a few hundredths\n' ...
         'is expected, since this screen keeps more trials than the old\n' ...
         'intersection did, and should not be read as a mismatch.\n']);

% Ratio between the two summary statistics, for context. If it sits near
% the 1.23 observed against the published values, that alone identifies
% the discrepancy as RMS versus mean absolute.
r = X.RMSError(keep) ./ X.MeanAbsError(keep);
fprintf('\nPer-epoch RMS / mean-abs ratio: median %.3f, IQR %.3f to %.3f\n', ...
    median(r,'omitnan'), prctile(r,25), prctile(r,75));


%% Local functions
% ---------------------------------------------------------------------
function out = pooledStat(X, rows, g, kind)
% Summarise across all samples of a trial at once, rather than
% summarising each epoch and averaging afterwards. Requires the signals,
% so this reloads them per subject.
    cfg      = kneeexo_config();
    out_path = cfg.masters;

    nG   = max(g);
    out  = nan(nG,1);
    subs = unique(X.SubjectID(rows));

    for i = 1:numel(subs)
        S = load(fullfile(out_path, sprintf('trk_master_sub-%d.mat', subs(i))), ...
                 'X','Enc','Ref');
        % Map this subject's retained rows onto their position in the
        % per-subject file, using the key rather than position.
        mine = X.SubjectID(rows) == subs(i);
        idxGlobal = rows(mine);
        gLocal    = g(mine);

        [tf, loc] = ismember(X(idxGlobal, {'SubjectID','RawTrial','RawEpoch'}), ...
                             S.X(:, {'SubjectID','RawTrial','RawEpoch'}));
        assert(all(tf), 'Key missing from the per-subject file.');

        for u = unique(gLocal)'
            sel = loc(gLocal == u);
            d = [];
            for q = sel'
                d = [d, S.Enc{q} - S.Ref{q}]; %#ok<AGROW>
            end
            if strcmp(kind,'rms')
                out(u) = sqrt(mean(d.^2));
            else
                out(u) = mean(abs(d));
            end
        end
    end
end
