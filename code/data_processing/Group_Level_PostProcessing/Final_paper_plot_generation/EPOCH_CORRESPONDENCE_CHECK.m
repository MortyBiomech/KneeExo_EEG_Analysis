%% EPOCH_CORRESPONDENCE_CHECK
%  Groundwork for the rebuild. Two questions.
%
%  1. Do the streams agree on how many epochs each trial contains?
%     Events are detected on the encoder in the EXP stream and translated
%     to the EMG and EEG streams, so the counts should match exactly. If
%     they do, one epoch key (subject, raw trial, raw epoch) identifies
%     the same movement cycle in every modality, and the modality tables
%     can be joined on it directly. If they do not, each stream needs its
%     own epoch key plus an explicit correspondence.
%
%  2. How many epochs fall under the 2000-sample threshold in the EMG
%     builder? That matters because of a fault in the existing builder:
%
%         for k = 1:length(...Sensors_Preprocessed)
%             if size(...{1,k}, 2) < 2000, continue; end
%             kk = kk + 1;
%             e = [Trials_Info{j}.Events.EMG_stream.flextoflex_start_indx(kk), ...
%             Main_data{1,jj}.Signal{1,kk}(1,:) = ...{1,k}(index,:);
%
%     The signal is read at the raw index k, the events at the compacted
%     index kk. Once one epoch in a trial is skipped, every later epoch in
%     that trial receives another epoch's flexion and extension
%     boundaries, and those boundaries drive the time warping. The count
%     below bounds how much of the existing EMG data this touched.
% =====================================================================

clc; clear;

data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
epoched_data_path = [data_path, '6_Trials_Info_and_Epoched_data\'];
subject_list = 5:18;
MIN_EMG_SAMPLES = 2000;

home = pwd;
summaryRows = [];

for subID = subject_list

    cd([epoched_data_path, 'sub-', num2str(subID)]);
    load Epochs_FlextoFlex_based.mat
    load Trials_Info.mat
    cd(home);

    nTrials = numel(Epochs_FlextoFlex_based);

    if subID == subject_list(1)
        fprintf('Stream fields present: %s\n\n', ...
            strjoin(fieldnames(Epochs_FlextoFlex_based{1})', ', '));
    end

    nExp = nan(nTrials,1); nEmg = nan(nTrials,1); nEeg = nan(nTrials,1);
    nEvExp = nan(nTrials,1); nEvEmg = nan(nTrials,1);
    nShort = zeros(nTrials,1); nAffected = zeros(nTrials,1);

    for j = 1:nTrials
        ep = Epochs_FlextoFlex_based{1,j};
        ti = Trials_Info{1,j};

        % Epoch counts per stream.
        if isfield(ep,'EXP_stream') && isfield(ep.EXP_stream,'Times')
            nExp(j) = numel(ep.EXP_stream.Times);
        end
        if isfield(ep,'EMG_stream') && isfield(ep.EMG_stream,'Sensors_Preprocessed')
            sp = ep.EMG_stream.Sensors_Preprocessed;
            nEmg(j) = numel(sp);

            % Short epochs, and how many later epochs they displace.
            if ~isempty(sp)
                lens  = cellfun(@(x) size(x,2), sp);
                short = lens < MIN_EMG_SAMPLES;
                nShort(j) = sum(short);
                first = find(short, 1);
                if ~isempty(first)
                    % Every retained epoch after the first skip receives
                    % the wrong event indices.
                    nAffected(j) = sum(~short(first+1:end));
                end
            end
        end
        if isfield(ep,'EEG_stream')
            f = fieldnames(ep.EEG_stream);
            c = f(contains(f, {'Times','Preprocessed','Signal'}));
            if ~isempty(c), nEeg(j) = numel(ep.EEG_stream.(c{1})); end
        end

        % Event array lengths, as a second view on the same question.
        if isfield(ti,'Events')
            if isfield(ti.Events,'EXP_stream')
                nEvExp(j) = numel(ti.Events.EXP_stream.flextoflex_start_indx);
            end
            if isfield(ti.Events,'EMG_stream')
                nEvEmg(j) = numel(ti.Events.EMG_stream.flextoflex_start_indx);
            end
        end
    end

    % Compare only trials where both streams hold something.
    both = ~isnan(nExp) & ~isnan(nEmg) & nExp > 0 & nEmg > 0;
    agreeStreams = mean(nExp(both) == nEmg(both));

    bothEv = ~isnan(nEvExp) & ~isnan(nEvEmg);
    agreeEvents = mean(nEvExp(bothEv) == nEvEmg(bothEv));

    agreeExpEv = mean(nExp(both & ~isnan(nEvExp)) == nEvExp(both & ~isnan(nEvExp)));

    summaryRows = [summaryRows; subID, nTrials, sum(both), ...
        agreeStreams, agreeEvents, agreeExpEv, ...
        sum(nShort), sum(nAffected), sum(nEmg(both))]; %#ok<AGROW>

    clear Epochs_FlextoFlex_based Trials_Info
end

S = array2table(summaryRows, 'VariableNames', ...
    {'Subject','Trials','Comparable','ExpVsEmg','EventsExpVsEmg', ...
     'EpochsVsEvents','ShortEpochs','EpochsWithWrongEvents','TotalEpochs'});

fprintf('--- Epoch correspondence ---\n');
disp(S);

fprintf('ExpVsEmg near 1.000 means one epoch key serves every modality.\n');
fprintf('EpochsVsEvents near 1.000 means the event arrays match the epochs.\n\n');

fprintf('Short EMG epochs overall     : %d of %d (%.2f%%)\n', ...
    sum(S.ShortEpochs), sum(S.TotalEpochs), ...
    100*sum(S.ShortEpochs)/sum(S.TotalEpochs));
fprintf('Epochs given wrong events    : %d (%.2f%% of all epochs)\n', ...
    sum(S.EpochsWithWrongEvents), ...
    100*sum(S.EpochsWithWrongEvents)/sum(S.TotalEpochs));
fprintf(['\nThe second figure bounds how much of the existing warped EMG\n' ...
         'was built on another epoch''s reversal point. If it is small,\n' ...
         'the published curves are essentially unaffected and the rebuild\n' ...
         'simply removes the risk. If it is large, the current EMG row of\n' ...
         'Figure 2 needs regenerating before anything else.\n']);