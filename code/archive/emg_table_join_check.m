%% EMG_TABLE_JOIN_CHECK
%  Determines how the EMG structure's trial identifiers map onto the
%  Trial column of the screened behaviour table.
%
%  Why this is needed. EMG_Data_timewarped stores two candidate trial
%  identifiers in trial_epoch:
%     column 1  a counter over experimental trials only
%     column 2  the raw index into structured_EMG_data, which also
%               contains non-experimental trials
%  Only one of them can match T.Trial. The test below does not assume
%  either: for each candidate it checks whether the pressure and score
%  recorded in the EMG structure agree with the behaviour table row
%  carrying that trial number. The correct identifier should agree on
%  essentially every trial; the wrong one should disagree often.
% =====================================================================

clc; clear;

cfg = ansymb_config();
addpath(genpath(cfg.code));

load([cfg.derived, filesep, 'behavior_table.mat'], 'T');
load('EMG_Data_timewarped.mat');          % adjust path if needed

data         = EMG_Data_timewarped.data;
subject_list = 5:18;

if iscategorical(T.Pressure)
    Tpres = str2double(string(T.Pressure));
else
    Tpres = double(T.Pressure);
end
Tsubj = double(string(T.SubjectID));

fprintf('Muscle order in file: %s\n\n', strjoin(EMG_Data_timewarped.Muscle_Name, ', '));

results = [];

for s = 1:numel(subject_list)

    subID = subject_list(s);
    if isempty(data{s,2}), continue; end

    st = data{s,2};

    % Trial-level pressure and score, one value per stored trial.
    pTrial = cellfun(@(x) x(1), st.pressure);
    sTrial = cellfun(@(x) x(1), st.score);
    nTrials = numel(pTrial);

    % The two candidate identifiers, one per stored trial. unique() is
    % ascending, and the cell arrays were built and filtered in the same
    % order, so the k-th unique id belongs to the k-th stored trial.
    idsCol1 = unique(st.trial_epoch(:,1), 'stable');
    idsCol2 = unique(st.trial_epoch(:,2), 'stable');

    if numel(idsCol1) ~= nTrials || numel(idsCol2) ~= nTrials
        fprintf(['Sub %d: identifier count (%d, %d) does not match stored ' ...
                 'trial count (%d). Positional correspondence is broken ' ...
                 'and must be fixed before joining.\n'], ...
                 subID, numel(idsCol1), numel(idsCol2), nTrials);
        continue;
    end

    % Behaviour table rows for this subject.
    rows  = Tsubj == subID;
    Ttr   = T.Trial(rows);
    Tp    = Tpres(rows);
    Ts    = T.Score(rows);

    agree = nan(1,2);
    found = nan(1,2);
    for cand = 1:2
        if cand == 1, ids = idsCol1; else, ids = idsCol2; end

        [tf, loc] = ismember(ids, Ttr);
        found(cand) = sum(tf);

        % Among identifiers that exist in the table, do pressure and
        % score agree? Score is compared only where the table's value is
        % valid, since zeros were screened out of the table.
        okP = Tp(loc(tf)) == pTrial(tf);
        okS = Ts(loc(tf)) == sTrial(tf) | sTrial(tf) == 0;
        agree(cand) = mean(okP & okS);
    end

    results = [results; subID, nTrials, height(T(rows,:)), ...
               found(1), agree(1), found(2), agree(2)]; %#ok<AGROW>
end

R = array2table(results, 'VariableNames', ...
    {'Subject','EMGtrials','TableRows', ...
     'Col1_found','Col1_agree','Col2_found','Col2_agree'});

fprintf('--- Join diagnostic ---\n');
disp(R);

fprintf('Mean agreement, column 1: %.3f\n', mean(R.Col1_agree, 'omitnan'));
fprintf('Mean agreement, column 2: %.3f\n', mean(R.Col2_agree, 'omitnan'));
fprintf(['\nThe correct identifier should show agreement near 1.00 and a ' ...
         'found count close to the table row count. If neither does, the ' ...
         'two sources cannot be joined on trial number and we need another ' ...
         'route.\n']);
