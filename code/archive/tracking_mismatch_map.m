%% TRACKING_MISMATCH_MAP
%  Locates which trials disagree between the tracking structure and the
%  behaviour table.
%
%  This replaces tracking_drift_profile.m, which had a flaw: it scanned
%  candidate shifts from -25 upward and stopped at the first match, so a
%  chance agreement at a large negative shift was reported in preference
%  to the true small one. With three pressure levels and ten score values
%  there are only thirty combinations, so chance matches are common and
%  the output was dominated by them. Here the search runs outward from
%  zero, so the smallest shift always wins.
%
%  What we already know from the earlier, sound test:
%    Subject 9      uniform shift of -1, agreement 1.000 once applied.
%    Subjects 11,12,18  no global shift beats zero, yet agreement is only
%                   0.79, 0.70 and 0.53. So most trials are numbered
%                   correctly and a subset is wrong. The question is
%                   whether that subset is contiguous.
% =====================================================================

clc; clear;

cfg = ansymb_config();
addpath(genpath(cfg.code));

load([cfg.derived, filesep, 'behavior_table.mat'], 'T');
load('Subject_Tracking_Error.mat');

subject_list = 5:18;
CHECK = [9 11 12 18];

if iscategorical(T.Pressure)
    Tpres = str2double(string(T.Pressure));
else
    Tpres = double(T.Pressure);
end
Tsubj = double(string(T.SubjectID));
bad   = T.Score == 0 | isnan(T.Score) | T.Score < 1 | T.Score > 10;
T     = T(~bad,:); Tpres = Tpres(~bad); Tsubj = Tsubj(~bad);

% Shifts ordered by absolute size, so the smallest explanation wins.
SHIFTS = [0, reshape([-1:-1:-10; 1:10], 1, [])];

for subID = CHECK

    s   = find(subject_list == subID);
    trk = Subject_Tracking_Error{s};

    rows    = Tsubj == subID;
    keepIDs = T.Trial(rows); keepP = Tpres(rows); keepS = T.Score(rows);

    trkTr = unique(trk.trial, 'stable');
    trkP  = arrayfun(@(t) trk.pressure(find(trk.trial == t,1)), trkTr);
    trkS  = arrayfun(@(t) trk.score(find(trk.trial == t,1)),    trkTr);

    % Global shift that maximises agreement, applied before mapping.
    best = -Inf; bestK = 0;
    for k = SHIFTS
        [tf, loc] = ismember(trkTr + k, keepIDs);
        if sum(tf) < 0.5*numel(trkTr), continue; end
        a = mean(trkP(tf) == keepP(loc(tf)) & trkS(tf) == keepS(loc(tf)));
        if a > best, best = a; bestK = k; end
    end
    fprintf('\n=== Subject %d ===\n', subID);
    fprintf('Best global shift %+d, agreement %.3f\n', bestK, best);

    if best > 0.999
        fprintf('Fully explained by that shift. Correctable.\n');
        continue;
    end

    % Map each trial at the best shift and mark agreement.
    [tf, loc] = ismember(trkTr + bestK, keepIDs);
    ok = false(size(trkTr));
    ok(tf) = trkP(tf) == keepP(loc(tf)) & trkS(tf) == keepS(loc(tf));

    inTable = tf;
    fprintf('Trials in structure: %d, present in table: %d, agreeing: %d\n', ...
        numel(trkTr), sum(inTable), sum(ok));

    % Runs of consecutive agreeing or disagreeing trials, among those the
    % table contains. Contiguous blocks point to a session or a segment
    % of the recording; scattered singletons point to something else.
    idx  = find(inTable);
    v    = ok(idx);
    tr   = trkTr(idx);
    brk  = [1; find(diff(v) ~= 0)+1];

    fprintf('Runs (trial range, verdict, length):\n');
    for b = 1:numel(brk)
        lo = brk(b);
        if b < numel(brk), hi = brk(b+1)-1; else, hi = numel(v); end
        if v(lo), verdict = 'match   '; else, verdict = 'MISMATCH'; end
        fprintf('  %4d to %4d  %s  %d\n', tr(lo), tr(hi), verdict, hi-lo+1);
    end

    % A session boundary is the most likely cause of a contiguous block,
    % so the span of the mismatching region is worth seeing directly.
    if any(~v)
        mm = tr(~v);
        fprintf('Mismatching trials span %d to %d (%d trials)\n', ...
            min(mm), max(mm), numel(mm));
    end
end

fprintf(['\nA small number of long runs means whole segments are ' ...
         'misnumbered,\nwhich usually traces to one session being ' ...
         'concatenated differently.\nMany short runs means the trials ' ...
         'are individually shuffled, which\nno shift can repair and ' ...
         'which has to be fixed at source.\n']);
