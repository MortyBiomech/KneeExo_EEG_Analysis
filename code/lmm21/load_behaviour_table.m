function B = load_behaviour_table(cfg)
%LOAD_BEHAVIOUR_TABLE  Trial level behaviour, read from the screened master table.
%
%  B = LOAD_BEHAVIOUR_TABLE(cfg) returns one row per participant and raw
%  trial with the columns
%
%     SubjectID    numeric participant number, 5 to 18
%     RawTrial     raw trial number, never the compacted counter
%     Pressure     1, 3 or 6
%     Score        perceived difficulty, 1 to 10
%     Error        tracking error in degrees
%     EffortIndex  EMG composite
%     nEpochs      number of surviving epochs behind the trial level values
%
%  THIS IS THE SECOND ADAPTER. It is the only file that knows the shape of
%  your master tables.
%
%  Single authoritative source. This function must read the same screened
%  table that produced the behavioural results, through the same screening
%  step, so the null and the behavioural figures describe the same 1732 rows.
%  Do not re derive score quality control here. The tail specific z score
%  removal that lived inside the old score_pressure_model belongs to the
%  flag based architecture now, as a boolean column, and re implementing it
%  in a second place is how two numbers start to disagree.
%
%  The raw trial number matters. Three separate indexing bugs in the old
%  pipeline came from writing at a compacted counter while reading at the raw
%  index. Every key here is the raw one.
%
%  TODO check the four marked lines below against build_behaviour_table.m.

% -------------------------------------------------------------------------
% TODO 1. File name of the screened trial level table.
srcFile = fullfile(cfg.paths.behaviour, 'behaviour_table.mat');

if exist(srcFile, 'file') ~= 2
    error('load_behaviour_table:missing', ...
        ['Behaviour table not found at %s.\n' ...
         'Point cfg.paths.behaviour at the folder that build_behaviour_table.m ' ...
         'writes into.'], srcFile);
end

raw = load(srcFile);
f = fieldnames(raw);
% TODO 2. Variable name inside that file.
if ismember('T', f)
    T = raw.T;
elseif numel(f) == 1
    T = raw.(f{1});
else
    error('load_behaviour_table:ambiguous', ...
        'The behaviour file holds %s. Name the one to use here.', ...
        strjoin(f', ', '));
end

if ~istable(T)
    error('load_behaviour_table:notTable', ...
        'The behaviour variable is a %s, not a table.', class(T));
end

T = renameIfPresent(T, { ...
    'Subject',      'SubjectID'; ...
    'subject',      'SubjectID'; ...
    'Trial',        'RawTrial'; ...
    'trial',        'RawTrial'; ...
    'Epoch',        'RawEpoch'; ...
    'BicepFem',     'BicepsFem'});

required = {'SubjectID', 'RawTrial', 'Pressure', 'Score', 'Error', 'EffortIndex'};
missing  = required(~ismember(required, T.Properties.VariableNames));
if ~isempty(missing)
    error('load_behaviour_table:columns', ...
        ['The behaviour table is missing %s.\nColumns present: %s'], ...
        strjoin(missing, ', '), strjoin(T.Properties.VariableNames, ', '));
end

% -------------------------------------------------------------------------
% TODO 3. Apply the screening flags.
% The rebuilt pipeline removes no rows and records every quality decision as
% a boolean column, so the screen is applied here rather than upstream. List
% every flag whose true value means the row must be dropped. Any flag column
% not named here is ignored, and the function says so, so a new flag added to
% the master table is noticed rather than silently skipped.
dropFlags = {'ignore_scoreQC', 'ignore_epoch', 'ignore_trial', 'zeroScore'};

present = dropFlags(ismember(dropFlags, T.Properties.VariableNames));
drop = false(height(T), 1);
for i = 1:numel(present)
    drop = drop | logical(T.(present{i}));
end

flagLike = T.Properties.VariableNames( ...
    varfun(@(c) islogical(c), T, 'OutputFormat', 'uniform'));
unused = setdiff(flagLike, present);
if ~isempty(unused) && cfg.verbose
    fprintf(['[load_behaviour_table] Logical columns present but not used ' ...
             'as drop flags: %s\n'], strjoin(unused, ', '));
end

nBefore = height(T);
T = T(~drop, :);
if cfg.verbose
    fprintf('[load_behaviour_table] Screen kept %d of %d rows using %s.\n', ...
        height(T), nBefore, strjoin(present, ', '));
end

% -------------------------------------------------------------------------
% TODO 4. Collapse to trial level if the table is epoch level.
isEpochLevel = ismember('RawEpoch', T.Properties.VariableNames) && ...
    height(unique(T(:, {'SubjectID', 'RawTrial'}))) < height(T);

if isEpochLevel
    if cfg.verbose
        fprintf('[load_behaviour_table] Table is epoch level, averaging to trial.\n');
    end
    [gid, key] = findgroups(T(:, {'SubjectID', 'RawTrial'}));

    B = key;
    B.Pressure    = splitapply(@(v) modeNumeric(v), asNum(T.Pressure), gid);
    B.Score       = splitapply(@(v) meanOmit(v),    asNum(T.Score),    gid);
    B.Error       = splitapply(@(v) meanOmit(v),    asNum(T.Error),    gid);
    B.EffortIndex = splitapply(@(v) meanOmit(v),    asNum(T.EffortIndex), gid);
    B.nEpochs     = splitapply(@numel, asNum(T.Score), gid);

    % A rating is given once per trial, so it must be constant within a trial.
    % If it is not, something upstream is wrong and averaging would hide it.
    spread = splitapply(@(v) rangeOmit(v), asNum(T.Score), gid);
    if any(spread > 0)
        warning('load_behaviour_table:scoreVaries', ...
            ['Score varies within %d trials. A rating is one value per trial, ' ...
             'so this points at a key problem upstream.'], nnz(spread > 0));
    end
else
    B = T;
    B.SubjectID   = asNum(B.SubjectID);
    B.RawTrial    = asNum(B.RawTrial);
    B.Pressure    = asNum(B.Pressure);
    B.Score       = asNum(B.Score);
    B.Error       = asNum(B.Error);
    B.EffortIndex = asNum(B.EffortIndex);
    if ~ismember('nEpochs', B.Properties.VariableNames)
        B.nEpochs = nan(height(B), 1);
    end
    B = B(:, {'SubjectID', 'RawTrial', 'Pressure', 'Score', 'Error', ...
              'EffortIndex', 'nEpochs'});
end

B = B(ismember(B.SubjectID, cfg.subjectList), :);
B = sortrows(B, {'SubjectID', 'RawTrial'});

if height(unique(B(:, {'SubjectID', 'RawTrial'}))) ~= height(B)
    error('load_behaviour_table:duplicateKeys', ...
        'SubjectID by RawTrial is not unique in the trial level table.');
end

if cfg.verbose
    fprintf('[load_behaviour_table] %d trials, %d participants.\n', ...
        height(B), numel(unique(B.SubjectID)));
end

end

% =========================================================================
function T = renameIfPresent(T, alias)
for i = 1:size(alias, 1)
    vn = T.Properties.VariableNames;
    if ismember(alias{i, 1}, vn) && ~ismember(alias{i, 2}, vn)
        T.Properties.VariableNames{strcmp(vn, alias{i, 1})} = alias{i, 2};
    end
end
end

function v = asNum(v)
if iscategorical(v) || isstring(v) || iscellstr(v)
    v = double(string(v));
else
    v = double(v);
end
v = v(:);
end

function m = meanOmit(v)
m = mean(v, 'omitnan');
end

function r = rangeOmit(v)
v = v(isfinite(v));
if isempty(v), r = 0; else, r = max(v) - min(v); end
end

function m = modeNumeric(v)
v = v(isfinite(v));
if isempty(v), m = NaN; else, m = mode(v); end
end
