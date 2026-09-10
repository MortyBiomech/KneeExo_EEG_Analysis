function clusterData = compute_cluster_ersp(clusterLabel, SUBJECTS_ICS, ...
    icatimefPath, p, nominalSubjects)
% COMPUTE_CLUSTER_ERSP  Per-subject, QC'd, baselined, dB ERSP for one cluster.
%
%   CLUSTERDATA = COMPUTE_CLUSTER_ERSP(CLUSTERLABEL, SUBJECTS_ICS, ...
%       ICATIMEFPATH, P)
%
% Reproduces the per-subject computation from the pre-cleanup analysis
% (the QC script + rm_anova_cluster_based.m): for every (subject, IC) pair
% assigned to this cluster, loads the subject's .icatimef file, computes
% power, crops to the time-warped cycle, flags bad trials per condition
% with FLAG_BAD_TRIALS (settings from P.QC), and averages the
% QC-surviving trials into a baseline-corrected, dB ERSP. The baseline is
% the mean over all three conditions and the whole warped cycle, computed
% from QC-surviving trials only, matching the 'median latency baseline'
% used at precompute time (see README.md).
%
%   CLUSTERLABEL   e.g. 'Left Prim Motor' -- must match a name in
%                  SUBJECTS_ICS{:,1}
%   SUBJECTS_ICS   cell array loaded from Subjects_ICs_in_clusters.mat
%   ICATIMEFPATH   folder containing the per-subject .icatimef files
%   P              parameter struct from ersp_params()
%
%   CLUSTERDATA  struct:
%     .subjects, .ICs        sorted subject numbers and matching IC numbers
%     .allTimes, .allFreqs   cropped, warped axes (common across subjects)
%     .eventTimes            [FlxS FlxE/ExtS ExtE], group-median warp
%                             latencies read from each subject's own
%                             .icatimef parameters, rounded to
%                             P.ersp.warpRoundToMs -- the .icatimef
%                             analogue of GROUP_MEDIAN_WARPTO, which needs
%                             ALLEEG.timewarp and isn't available on this
%                             path
%     .qc                    nSubjects x 3 cell of QC tables from
%                             FLAG_BAD_TRIALS, one per subject per condition
%     .nTrialsTotal, .nTrialsBad   nSubjects x 3 double, for reporting
%     .ersp.raw              3x1 cell, each allFreqs x allTimes x
%                             nSubjects, QC'd single-subject dB ERSP, in
%                             P.design.values order ('1','3','6')
%     .ersp.mean             3x1 cell, each allFreqs x allTimes, grand mean
%
% ASSUMES every subject crops to the same number of time samples. This
% held in the pre-cleanup pipeline (135 samples) because
% P.ersp.warpRoundToMs rounds every subject's warp-to latencies to the
% same grid before the .icatimef files are written; it is checked
% explicitly below (see the assert on TimeLengthMismatch) rather than
% assumed silently. If it ever fires, the fix is almost certainly to crop
% every subject to the shortest common length rather than each to their
% own timewarpms(end) -- talk to Morteza before changing this, since it
% would be a small departure from the analysis that produced the
% published figures.
%
% Subject numbering: SUBJECTS_ICS stores a 0-based index into the nominal
% subject list, so index 1 means the first analysed participant. The list is
% passed in as NOMINALSUBJECTS (cfg.subjects, currently 5:18) rather than
% recovered by adding 4, which was a magic number that would break silently
% if the participant list ever changed.

idxCluster = find(cellfun(@(x) strcmp(x, clusterLabel), SUBJECTS_ICS(:,1)));
if isempty(idxCluster)
    error('compute_cluster_ersp:UnknownCluster', ...
        'Cluster label ''%s'' not found in SUBJECTS_ICS.', clusterLabel);
end

if nargin < 5 || isempty(nominalSubjects)
    error('compute_cluster_ersp:NoSubjectList', ...
        ['NOMINALSUBJECTS is required. Pass cfg.subjects, the list that ' ...
         'SUBJECTS_ICS indexes into.']);
end

subjectIndex = SUBJECTS_ICS{idxCluster, 2}.Subjects;
if max(subjectIndex) > numel(nominalSubjects)
    error('compute_cluster_ersp:SubjectIndexOutOfRange', ...
        ['Cluster ''%s'' refers to participant index %d but only %d ' ...
         'participants were given. SUBJECTS_ICS was probably built from a ' ...
         'different participant list.'], ...
        clusterLabel, max(subjectIndex), numel(nominalSubjects));
end

subjects = nominalSubjects(subjectIndex);
[subjects, sortIdx] = sort(subjects, 'ascend');
ICs = SUBJECTS_ICS{idxCluster, 2}.ICs;
ICs = ICs(sortIdx);

nSubjects     = numel(subjects);
nConditions   = numel(p.design.values);
qcTables      = cell(nSubjects, nConditions);
nTrialsTotal  = zeros(nSubjects, nConditions);
nTrialsBad    = zeros(nSubjects, nConditions);
erspBySubject = cell(nSubjects, nConditions);
timewarpmsAll = nan(nSubjects, 3);
allTimes = [];
allFreqs = [];

for si = 1:nSubjects
    fileBaseName = sprintf('S%d', subjects(si));
    chanList     = sprintf('comp%d', ICs(si));
    fprintf('  Loading %s.icatimef (%s)...\n', fileBaseName, chanList);

    icatimef = load('-mat', fullfile(icatimefPath, [fileBaseName '.icatimef']), ...
        chanList, 'times', 'freqs', 'trialinfo', 'parameters');

    ic = icatimef.(chanList);
    ic = ic .* conj(ic);   % power

    idxParam   = find(strcmp(icatimef.parameters, 'timewarpms'));
    timewarpms = icatimef.parameters{1, idxParam + 1};
    timewarpmsAll(si, :) = timewarpms;

    times     = icatimef.times;
    idxToKeep = times < timewarpms(end);
    ic        = ic(:, idxToKeep, :);

    if isempty(allTimes)
        allTimes = times(idxToKeep);
        allFreqs = icatimef.freqs;
    else
        assert(nnz(idxToKeep) == numel(allTimes), ...
            'compute_cluster_ersp:TimeLengthMismatch', ...
            ['Subject %s crops to %d time samples; earlier subjects in ' ...
             'this cluster cropped to %d. The pipeline assumes every ' ...
             'subject''s warped cycle crops to the same length -- see ' ...
             'the note in this function''s header before changing that.'], ...
            fileBaseName, nnz(idxToKeep), numel(allTimes));
    end

    trials = cellfun(@str2double, {icatimef.trialinfo.trial});
    conds  = cellfun(@str2double, {icatimef.trialinfo.cond});
    uniqueConds = unique(conds);
    assert(numel(uniqueConds) == nConditions, ...
        'compute_cluster_ersp:UnexpectedConditionCount', ...
        'Subject %s has %d conditions, expected %d.', ...
        fileBaseName, numel(uniqueConds), nConditions);

    isBadByCond = cell(1, nConditions);
    for c = 1:nConditions
        trialIdx   = find(conds == uniqueConds(c));
        trialCells = squeeze(num2cell(ic(:, :, trialIdx), [1 2]));
        [qc, isBad] = flag_bad_trials(trialCells, allFreqs, trials(trialIdx)', ...
            'HighBand', p.qc.highBand, 'RefBand', p.qc.refBand, ...
            'HotZ', p.qc.hotZ, 'Zth', p.qc.zThreshold, ...
            'CorrType', p.qc.corrType);
        qcTables{si, c}     = qc;
        isBadByCond{c}      = isBad;
        nTrialsTotal(si, c) = numel(trialIdx);
        nTrialsBad(si, c)   = nnz(isBad);
    end

    meanTF = cell(1, nConditions);
    for c = 1:nConditions
        trialIdx   = find(conds == uniqueConds(c));
        goodTrials = trialIdx(~isBadByCond{c});
        meanTF{c}  = mean(ic(:, :, goodTrials), 3);
    end
    baseline = mean(mean(cat(3, meanTF{:}), 3), 2);

    for c = 1:nConditions
        erspBySubject{si, c} = 10*log10(meanTF{c} ./ ...
            repmat(baseline, 1, size(meanTF{c}, 2)));
    end
end

clusterData = struct();
clusterData.subjects     = subjects;
clusterData.ICs          = ICs;
clusterData.allTimes     = allTimes;
clusterData.allFreqs     = allFreqs;
clusterData.eventTimes   = round(median(timewarpmsAll, 1) / p.ersp.warpRoundToMs) ...
                            * p.ersp.warpRoundToMs;
clusterData.qc           = qcTables;
clusterData.nTrialsTotal = nTrialsTotal;
clusterData.nTrialsBad   = nTrialsBad;

clusterData.ersp.raw  = cell(nConditions, 1);
clusterData.ersp.mean = cell(nConditions, 1);
for c = 1:nConditions
    clusterData.ersp.raw{c,1}  = cat(3, erspBySubject{:, c});
    clusterData.ersp.mean{c,1} = mean(clusterData.ersp.raw{c,1}, 3);
end
end