function map = pair_icatimef_to_behaviour(pairingSource, subject, nEpochs)
%PAIR_ICATIMEF_TO_BEHAVIOUR  Epoch index in a .icatimef file to behaviour keys.
%
%  map = PAIR_ICATIMEF_TO_BEHAVIOUR(src, subject, nEpochs) returns a table with
%  one row per epoch of that participant's .icatimef file:
%
%     EpochIndex   1 based position in the third dimension of comp<ic>_timef
%     RawTrial     raw trial number, the key used by the master tables
%     RawEpoch     raw epoch number within that trial
%     ResidualMs   distance of the nearest neighbour match, NaN when unknown
%     Matched      false where no behaviour epoch corresponds
%
%  THIS IS THE ADAPTER. It is the only file that knows the shape of your
%  pairing map, so it is the first thing to check when the analysis is moved.
%
%  Why a pairing map is needed at all. Each stream was cleaned separately. The
%  EEG lost epochs to artefact and component rejection, the experiment stream
%  lost epochs to its own completeness criteria, and neither file carries an
%  index into the other. The two survivor sets are different subsets of the
%  same movement cycles, so joining them by position compares the power of one
%  cycle against the behaviour of another. That was defect 9 of the original
%  cross correlation code. The map is built once per participant from
%  trialinfo.init_index looked up in EEG.urevent, and serves every cluster,
%  because urevent belongs to the participant's dataset rather than to any
%  clustering solution.
%
%  Accepted shapes for src, which may be a path to a .mat file or the loaded
%  contents:
%
%    1. A table or struct array with columns
%         Subject or SubjectID, EpochIndex, RawTrial, RawEpoch,
%         and optionally ResidualMs
%       covering every participant. Preferred, and what the merged
%       epoch_pairing_map.mat should hold.
%
%    2. A cell array, one entry per participant in cfg.subjectList order, each
%       an nEpochs by 2 matrix of [RawTrial RawEpoch], optionally by 3 with
%       the residual in the third column. This is the shape the original
%       Subjects_corresponding_TrialsEpochs_to_icatimef.mat used.
%
%    3. A struct array indexed the same way with fields Trials and Epochs.
%
%  See also BUILD_EEG_FEATURE_TABLE.

if ischar(pairingSource) || isstring(pairingSource)
    f = char(pairingSource);
    if exist(f, 'file') ~= 2
        error('pair_icatimef_to_behaviour:missing', ...
            'Pairing file not found: %s', f);
    end
    raw = load(f);
    pairingSource = unwrapSingleField(raw);
end

map = [];

% ---- shape 1, one long table over every participant ---------------------
if istable(pairingSource) || (isstruct(pairingSource) && ...
        any(isfield(pairingSource, {'RawTrial', 'rawTrial'})))

    T = pairingSource;
    if isstruct(T), T = struct2table(T); end
    T = normaliseNames(T);

    subCol = firstPresent(T, {'Subject', 'SubjectID'});
    if isempty(subCol)
        error('pair_icatimef_to_behaviour:noSubject', ...
            ['The pairing table has no Subject or SubjectID column. ' ...
             'Columns present: %s'], strjoin(T.Properties.VariableNames, ', '));
    end

    keep = asDouble(T.(subCol)) == subject;
    T = T(keep, :);

    if isempty(T)
        error('pair_icatimef_to_behaviour:noSubjectRows', ...
            'The pairing table has no rows for participant %d.', subject);
    end

    map = table();
    map.EpochIndex = asDouble(T.EpochIndex);
    map.RawTrial   = asDouble(T.RawTrial);
    map.RawEpoch   = asDouble(T.RawEpoch);
    if ismember('ResidualMs', T.Properties.VariableNames)
        map.ResidualMs = asDouble(T.ResidualMs);
    else
        map.ResidualMs = nan(height(T), 1);
    end

% ---- shapes 2 and 3, indexed per participant ----------------------------
else
    idx = subjectSlot(pairingSource, subject);

    if iscell(pairingSource)
        entry = pairingSource{idx};
    elseif isstruct(pairingSource)
        entry = pairingSource(idx);
    else
        error('pair_icatimef_to_behaviour:unknownShape', ...
            ['The pairing map is a %s. It must be a table, a struct array ' ...
             'or a cell array. See the help text for the three accepted ' ...
             'shapes.'], class(pairingSource));
    end

    if isstruct(entry) && isfield(entry, 'Trials')
        trials = asDouble(entry.Trials(:));
        epochs = asDouble(entry.Epochs(:));
        resid  = nan(size(trials));
        if isfield(entry, 'ResidualMs')
            resid = asDouble(entry.ResidualMs(:));
        end
    elseif isstruct(entry)
        error('pair_icatimef_to_behaviour:structFields', ...
            ['Participant %d maps to a struct with fields %s. Trials and ' ...
             'Epochs are expected.'], subject, strjoin(fieldnames(entry)', ', '));
    else
        % A plain numeric matrix, columns [RawTrial RawEpoch] and optionally
        % a third column of match residuals. The shape is kept, so do not
        % route this through the flattening helper.
        M = double(entry);
        if size(M, 2) < 2
            error('pair_icatimef_to_behaviour:shape', ...
                ['Participant %d maps to a %dx%d array. Two columns of ' ...
                 '[RawTrial RawEpoch] are the minimum.'], ...
                subject, size(M, 1), size(M, 2));
        end
        trials = M(:, 1);
        epochs = M(:, 2);
        if size(M, 2) >= 3
            resid = M(:, 3);
        else
            resid = nan(size(trials));
        end
    end

    map = table();
    map.EpochIndex = (1:numel(trials)).';
    map.RawTrial   = trials;
    map.RawEpoch   = epochs;
    map.ResidualMs = resid;
end

map.Matched = isfinite(map.RawTrial) & isfinite(map.RawEpoch) & map.RawTrial > 0;

% ---- align to the file the caller actually read -------------------------
% Position based shapes carry no epoch index of their own, so a length
% mismatch means the map and the file disagree about which epochs survived.
% That is exactly the failure this whole mechanism exists to prevent, so it
% is an error rather than a truncation.
if nargin >= 3 && ~isempty(nEpochs)
    if max(map.EpochIndex) > nEpochs
        error('pair_icatimef_to_behaviour:tooManyEpochs', ...
            ['The pairing map refers to epoch %d for participant %d, but the ' ...
             '.icatimef file has %d epochs. The map and the file were built ' ...
             'from different versions of the data.'], ...
            max(map.EpochIndex), subject, nEpochs);
    end
    if height(map) ~= nEpochs
        warning('pair_icatimef_to_behaviour:epochCount', ...
            ['Participant %d: the pairing map has %d rows and the .icatimef ' ...
             'file has %d epochs. Unmapped epochs are dropped.'], ...
            subject, height(map), nEpochs);
    end
end

map = sortrows(map, 'EpochIndex');

end

% =========================================================================
function s = unwrapSingleField(raw)
f = fieldnames(raw);
if numel(f) == 1
    s = raw.(f{1});
else
    % Prefer an obviously named field over guessing.
    prefer = {'pairing', 'map', 'epoch_pairing_map', 'Subjects_corresponding_TrialsEpochs_to_icatimef'};
    hit = find(ismember(prefer, f), 1);
    if isempty(hit)
        error('pair_icatimef_to_behaviour:ambiguous', ...
            ['The pairing file holds %d variables (%s) and none is named ' ...
             'pairing or map. Load it yourself and pass the right one.'], ...
            numel(f), strjoin(f', ', '));
    end
    s = raw.(prefer{hit});
end
end

% -------------------------------------------------------------------------
function idx = subjectSlot(src, subject)
cfg = lmm21_config();
idx = find(cfg.subjectList == subject, 1);
if isempty(idx)
    error('pair_icatimef_to_behaviour:notInList', ...
        'Participant %d is not in cfg.subjectList.', subject);
end
if idx > numel(src)
    error('pair_icatimef_to_behaviour:short', ...
        ['The pairing map has %d entries but participant %d is at position ' ...
         '%d of cfg.subjectList.'], numel(src), subject, idx);
end
end

% -------------------------------------------------------------------------
function T = normaliseNames(T)
alias = { ...
    'icatimefEpoch', 'EpochIndex'; ...
    'IcatimefEpoch', 'EpochIndex'; ...
    'Epoch',         'RawEpoch'; ...
    'Trial',         'RawTrial'; ...
    'residual_ms',   'ResidualMs'; ...
    'MatchResidualMs', 'ResidualMs'};
vn = T.Properties.VariableNames;
for i = 1:size(alias, 1)
    if ismember(alias{i, 1}, vn) && ~ismember(alias{i, 2}, vn)
        T.Properties.VariableNames{strcmp(vn, alias{i, 1})} = alias{i, 2};
        vn = T.Properties.VariableNames;
    end
end
end

% -------------------------------------------------------------------------
function name = firstPresent(T, candidates)
name = '';
for i = 1:numel(candidates)
    if ismember(candidates{i}, T.Properties.VariableNames)
        name = candidates{i};
        return
    end
end
end

% -------------------------------------------------------------------------
function v = asDouble(v)
if iscategorical(v)
    v = double(string(v));
elseif isstring(v) || iscellstr(v)
    v = double(string(v));
else
    v = double(v);
end
v = v(:);
end
