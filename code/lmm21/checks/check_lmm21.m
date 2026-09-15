function nFail = check_lmm21()
%CHECK_LMM21  Acceptance test for the trial-level cortical LMM.
%
%   NFAIL = CHECK_LMM21() runs every check that does not need tier 2. It takes
%   about a minute, most of it in the synthetic model recovery at the end. Run
%   it after moving the code and after editing any of these files.
%
%   WHAT IS CHECKED
%     1  the configuration describes 21 features, with names, bands and
%        clusters that agree with cfg and with SUBJECTS_ICS
%     2  BH_FDR against a brute force implementation of the definition
%     3  WITHIN_SUBJECT_SCALE, including the guards the old helpers lacked
%     4  LMM21_TRIAL_FEATURES against a brute force loop, and the two baseline
%        properties the analysis turns on
%     5  the model recovers a planted coefficient and returns an honest null
%        when there is nothing there
%
%   WHAT IS NOT CHECKED, because it needs tier 2: the reading of the .icatimef
%   files and the epoch pairing. The audit table from BUILD_LMM21_FEATURES is
%   what covers those, and CHECKS/EPOCH_PAIRING_CHECK covers the pairing itself.
%
%   See also LMM21_CONFIG, LMM21_TRIAL_FEATURES, EPOCH_PAIRING_CHECK.
%
%   Part of the KneeExo-EEG analysis code.

thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('check_lmm21');
end
addpath(fullfile(fileparts(fileparts(fileparts(thisFile))), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);

nFail = 0;
fprintf('\n');


%% 1. Configuration
fprintf('--- configuration ---\n');
L = lmm21_config(cfg);

nFail = ck(L.nFeatures == 21, 'clusters times bands is 21', nFail);

names = lmm21_feature_names(L);
nFail = ck(numel(names) == 21, 'the name list has 21 entries', nFail);
nFail = ck(numel(unique(names)) == 21, 'feature names are unique', nFail);
nFail = ck(all(cellfun(@isvarname, names)), ...
    'feature names are valid identifiers', nFail);

% The bands must be the ones the rest of the pipeline uses, not a second
% definition that has drifted.
for b = 1:numel(L.bandNames)
    nm = L.bandNames{b};
    nFail = ck(isequal(L.bands.(nm), cfg.bands.(nm)), ...
        sprintf('band %s matches cfg.bands', nm), nFail);
end

% The cluster names must exist in the mapping file, otherwise the first real
% run fails halfway through.
loaded = load(L.files.clusterIC, 'SUBJECTS_ICS');
available = loaded.SUBJECTS_ICS(:, 1).';
for c = 1:size(L.clusters, 1)
    nFail = ck(any(strcmp(available, L.clusters{c, 1})), ...
        sprintf('cluster %s is in SUBJECTS_ICS', L.clusters{c, 1}), nFail);
end

% And the exclusion has to be deliberate, so say out loud what is left out.
excluded = setdiff(available, L.clusters(:, 1).');
fprintf('        ROIs present but not analysed: %s\n', ...
    strjoin(excluded, ', '));
nFail = ck(numel(available) == numel(L.clusters(:, 1)) + numel(excluded), ...
    'every ROI is either analysed or accounted for', nFail);

% Component overlap between clusters. The eight clustering solutions are
% separate runs over the same component set, each seeded at its own ROI, so
% one component can land in more than one cluster. Where it does, the two
% clusters are not independent sources and a family of tests containing both
% counts the same signal twice. This is why Prime_Visual is excluded, and the
% numbers are recomputed here rather than trusted to a comment.
comp = containers.Map('KeyType', 'char', 'ValueType', 'any');
for c = 1:numel(available)
    e = loaded.SUBJECTS_ICS{c, 2};
    idx = double(e.Subjects(:));
    ics = double(e.ICs(:));
    subjNum = L.subjects(idx);
    comp(available{c}) = [subjNum(:), ics(:)];
end

analysed = L.clusters(:, 1).';
fprintf('\n        component overlap, analysed clusters\n');
worst = 0;
for a = 1:numel(analysed)
    for b = a+1:numel(analysed)
        n = size(intersect(comp(analysed{a}), comp(analysed{b}), 'rows'), 1);
        if n > 0
            frac = n / min(size(comp(analysed{a}), 1), size(comp(analysed{b}), 1));
            worst = max(worst, frac);
            fprintf('          %-24s %-24s %d shared (%.0f%%)\n', ...
                analysed{a}, analysed{b}, n, 100 * frac);
        end
    end
end
if worst == 0
    fprintf('          none\n');
end

% Half is the line: below it two clusters are mostly distinct sources that
% happen to share a near-midline component, at or above it they are the same
% source under two names and one of them has to go.
nFail = ck(worst < 0.5, ...
    'no two analysed clusters share half their components', nFail);

for c = 1:numel(excluded)
    fprintf('        %s overlaps:', excluded{c});
    any_ov = false;
    for a = 1:numel(analysed)
        n = size(intersect(comp(excluded{c}), comp(analysed{a}), 'rows'), 1);
        if n > 0
            fprintf(' %s %d/%d;', analysed{a}, n, size(comp(excluded{c}), 1));
            any_ov = true;
        end
    end
    if ~any_ov
        fprintf(' none');
    end
    fprintf('\n');
end

nFail = ck(strcmp(L.baseline, 'ersp'), ...
    'baseline matches the published ERSPs', nFail);
nFail = ck(strcmp(L.aggregate, 'trial'), 'observation level is the trial', nFail);
nFail = ck(any(strcmp({L.specs.key}, L.primarySpec)), ...
    'the primary specification exists', nFail);


%% 2. bh_fdr
fprintf('\n--- bh_fdr ---\n');
rng(11);
p = [rand(18, 1); 0.0005; 0.02; 0.049];

q = bh_fdr(p);
nFail = ck(max(abs(q - brute_bh(p))) < 1e-12, ...
    'matches the definition computed directly', nFail);
nFail = ck(all(q >= p - 1e-15), 'adjusted is never below raw', nFail);

[~, ord] = sort(p);
nFail = ck(all(diff(q(ord)) >= -1e-15), 'monotone in p', nFail);

pn = p; pn([2 5]) = NaN;
qn = bh_fdr(pn);
nFail = ck(all(isnan(qn([2 5]))), 'NaN in gives NaN out', nFail);
nFail = ck(max(abs(qn(~isnan(pn)) - bh_fdr(pn(~isnan(pn))))) < 1e-14, ...
    'a failed fit does not inflate the family size', nFail);

nFail = ck(abs(bh_fdr(0.03) - 0.03) < 1e-15, 'm = 1 leaves p alone', nFail);
nFail = ck(max(abs(bh_fdr([0.2; 0.2; 0.2]) - 0.2)) < 1e-15, 'ties handled', nFail);

[~, crit, nRej] = bh_fdr([0.001; 0.008; 0.039; 0.041; 0.9], 0.05);
nFail = ck(nRej == 2 && abs(crit - 0.008) < 1e-15, ...
    'critical value and rejection count', nFail);


%% 3. within_subject_scale
fprintf('\n--- within_subject_scale ---\n');
g = repelem((1:2)', 6);
x = [1; 2; 3; 4; 5; 6; 10; 20; 30; 40; 50; 60];

z = within_subject_scale(x, g, 'z', 5);
nFail = ck(abs(mean(z(1:6))) < 1e-12 && abs(std(z(1:6)) - 1) < 1e-12, ...
    'z has mean 0 and sd 1 inside a participant', nFail);
nFail = ck(max(abs(z(1:6) - z(7:12))) < 1e-12, ...
    'z removes a per participant scale difference', nFail);

c = within_subject_scale(x, g, 'center', 5);
nFail = ck(abs(std(c(7:12)) - std(x(7:12))) < 1e-12, ...
    'centring keeps the unit', nFail);
nFail = ck(isequal(within_subject_scale(x, g, 'raw'), x), ...
    'raw passes through', nFail);

zs = within_subject_scale([1;2;3;1;2;3;4;5;6], [1;1;1;2;2;2;2;2;2], 'z', 5);
nFail = ck(all(isnan(zs(1:3))) && all(isfinite(zs(4:9))), ...
    'a participant below the minimum trial count is set to NaN', nFail);
nFail = ck(all(isnan(within_subject_scale(7*ones(6,1), ones(6,1), 'z', 5))), ...
    'a constant participant is NaN, not a column of zeros', nFail);

xn = x; xn(2) = NaN;
zn = within_subject_scale(xn, g, 'z', 5);
nFail = ck(isnan(zn(2)) && all(isfinite(zn([1 3 4 5 6]))), ...
    'one NaN does not poison the participant', nFail);
nFail = ck(abs(mean(zn([1 3 4 5 6]))) < 1e-12, ...
    'the NaN row is left out of the mean', nFail);


%% 4. lmm21_trial_features
fprintf('\n--- lmm21_trial_features ---\n');
freqs = logspace(log10(3), log10(130), 250);
nT = 135;
nEp = 60;
bands = L.bands;

rng(3);
P = 1 + rand(numel(freqs), nT, nEp);

% Twenty trials of three cycles, and a condition per trial rather than per
% epoch, so no trial can straddle two conditions by accident. Seven, seven and
% six trials, deliberately unequal, because an equal split would make a
% condition-balanced baseline and a trial-weighted one identical and the
% balance test below would pass either way.
epTrial   = repelem((1:20)', 3);
trialCond = [repmat([1; 3; 6], 6, 1); 1; 3];
epCond    = trialCond(epTrial);

out = lmm21_trial_features(P, freqs, epTrial, epCond, bands, ...
    'applyQC', false, 'baseline', 'ersp');

[refFeat, refB] = brute_features(P, freqs, epTrial, epCond, bands);
nFail = ck(max(abs(out.baseline - refB)) < 1e-12, ...
    'baseline equals the brute force condition-balanced mean', nFail);
nFail = ck(max(abs(out.feature(:) - refFeat(:))) < 1e-10, ...
    'feature equals the brute force band by cycle mean', nFail);
nFail = ck(numel(out.trial) == 20 && all(out.nEpochs == 3), ...
    'cycles are aggregated to trials', nFail);

% Bands must not share a frequency bin, because the edges in cfg.bands touch
% at 8 and 14 Hz.
nAlpha = nnz(freqs >= bands.alpha(1) & freqs < bands.alpha(2));
nBeta  = nnz(freqs >= bands.beta(1)  & freqs < bands.beta(2));
nFail = ck(out.nBandBins(2) == nAlpha && out.nBandBins(3) == nBeta, ...
    'band membership uses an exclusive upper edge', nFail);
nFail = ck(nnz(freqs >= bands.alpha(1) & freqs < bands.alpha(2) & ...
               freqs >= bands.beta(1)  & freqs < bands.beta(2)) == 0, ...
    'adjacent bands share no frequency bin', nFail);

% The property the whole design turns on. Identical epochs scaled by a known
% per-epoch gain must come through the common baseline as exactly that gain,
% referred to the balanced mean gain.
gain = linspace(0.5, 2, nEp);
P0 = repmat(P(:, :, 1), [1 1 nEp]);
Pg = P0 .* reshape(gain, 1, 1, nEp);

o0 = lmm21_trial_features(P0, freqs, epTrial, epCond, bands, ...
    'applyQC', false, 'baseline', 'ersp');
og = lmm21_trial_features(Pg, freqs, epTrial, epCond, bands, ...
    'applyQC', false, 'baseline', 'ersp');

nFail = ck(std(o0.feature(:, 2)) < 1e-9, ...
    'identical epochs give identical features', nFail);
nFail = ck(std(og.feature(:, 2)) > 0.5, ...
    'a common baseline passes trial-level variation through', nFail);

conds = unique(epCond);
gBal = mean(arrayfun(@(c) mean(gain(epCond == c)), conds));
trialGain = arrayfun(@(t) mean(gain(epTrial == t)), (1:20)');
nFail = ck(max(abs(og.feature(:, 2) - ...
    (o0.feature(:, 2) + 10 * log10(trialGain / gBal)))) < 1e-9, ...
    'and does so by exactly the trial gain over the balanced mean gain', nFail);

% Condition balance: adding trials to one condition must not move the
% baseline. Duplicating the condition-6 epochs is the test, and a
% trial-weighted baseline would fail it, which is checked too so the test is
% known to have teeth.
sel6 = find(epCond == 6);
P2 = cat(3, P, P(:, :, sel6));
t2 = [epTrial; epTrial(sel6) + 100];
c2 = [epCond; epCond(sel6)];
o2 = lmm21_trial_features(P2, freqs, t2, c2, bands, ...
    'applyQC', false, 'baseline', 'ersp');
nFail = ck(max(abs(o2.baseline - out.baseline)) < 1e-12, ...
    'the baseline is condition balanced, not trial weighted', nFail);
nFail = ck(max(abs(mean(mean(P2, 3), 2) - out.baseline)) > 1e-6, ...
    'and a trial-weighted baseline really would have moved', nFail);

% Mean then log is not log then mean.
od = lmm21_trial_features(P, freqs, epTrial, epCond, bands, ...
    'applyQC', false, 'baseline', 'ersp', 'aggSpace', 'db');
nFail = ck(all(out.feature(:) >= od.feature(:) - 1e-12), ...
    'the arithmetic mean is never below the geometric one', nFail);

nFail = ck(errors(@() lmm21_trial_features(P, freqs, epTrial, epCond, ...
    struct('none', [200 300]), 'applyQC', false)), ...
    'a band off the frequency axis errors', nFail);

mixed = epCond; mixed(1) = 99;
nFail = ck(errors(@() lmm21_trial_features(P, freqs, epTrial, mixed, bands, ...
    'applyQC', false)), 'a trial spanning two conditions errors', nFail);

% The quality control branch, with the real FLAG_BAD_TRIALS. This is exercised
% here because it is the one path the synthetic tests above skip, and it is
% where an interface mistake hides: FLAG_BAD_TRIALS builds a table whose metric
% columns are nTrials x 1, so a row-shaped trial vector fails inside the table
% constructor with an error that names neither this file nor that argument.
if isempty(ver('stats'))
    fprintf('  SKIP  QC branch needs the Statistics Toolbox\n');
else
    p = ersp_params();
    qcOK = true;
    qcMsg = '';
    try
        oq = lmm21_trial_features(P, freqs, epTrial, epCond, bands, ...
            'applyQC', true, 'qc', p.qc);
    catch ME
        qcOK = false;
        qcMsg = ME.message;
    end

    if qcOK
        nFail = ck(true, 'the QC branch runs with the real flag_bad_trials', nFail);
        fprintf('        flagged %d of %d epochs\n', nnz(oq.isBad), numel(oq.isBad));

        % Whatever it flags must be gone from both the baseline and the
        % features, which is checked against removing them by hand.
        good = ~oq.isBad;
        ref = lmm21_trial_features(P(:, :, good), freqs, epTrial(good), ...
            epCond(good), bands, 'applyQC', false);
        nFail = ck(max(abs(oq.baseline - ref.baseline)) < 1e-12, ...
            'the baseline is built from surviving epochs only', nFail);
        nFail = ck(isequal(oq.trial, ref.trial) && ...
            max(abs(oq.feature(:) - ref.feature(:))) < 1e-12, ...
            'features match a run with the flagged epochs removed by hand', nFail);
    else
        nFail = ck(false, ['the QC branch runs with the real flag_bad_trials: ' ...
            qcMsg], nFail);
    end
end



%% 5. lmm21_derive_terms
fprintf('\n--- lmm21_derive_terms ---\n');

% Unequal trial counts on purpose: the between term is grand centred over
% participants, not over rows, and with equal counts the two are the same
% number and the test could not tell them apart.
sub = [ones(10, 1); 2 * ones(20, 1); 3 * ones(30, 1)];
W = table();
W.Subject_cat  = categorical(sub);
W.RawTrial     = (1:numel(sub))';
W.Error        = sub * 2 + randn(numel(sub), 1);
W.EffortIndex  = 4 + randn(numel(sub), 1) * 0.5;   % no between variance by design

% Give the effort index exactly zero between-participant variance, which is
% what BUILD_BEHAVIOUR_TABLE's within-participant normalisation produces.
for i = 1:3
    r = sub == i;
    W.EffortIndex(r) = W.EffortIndex(r) - mean(W.EffortIndex(r)) + 4;
end

[W2, terms] = lmm21_derive_terms(W, L);

wSums = arrayfun(@(i) sum(W2.Error_w(sub == i)), 1:3);
nFail = ck(max(abs(wSums)) < 1e-12, ...
    'the within term sums to zero inside every participant', nFail);

recon = W2.Error_w + W2.Error_b;
subjMeans = arrayfun(@(i) mean(W.Error(sub == i)), 1:3);
nFail = ck(max(abs(recon - (W.Error - mean(subjMeans)))) < 1e-12, ...
    'within plus between reconstructs the centred original', nFail);

nFail = ck(abs(mean(arrayfun(@(i) W2.Error_b(find(sub == i, 1)), 1:3))) < 1e-12, ...
    'the between term is centred over participants, not over rows', nFail);
nFail = ck(abs(mean(W2.Error_b)) > 1e-6, ...
    'and with unequal trial counts those two differ, so the test has teeth', nFail);

nFail = ck(ismember('Error_b', terms.between), ...
    'a mediator with between-participant variance keeps its between term', nFail);
nFail = ck(~ismember('EffortIndex_b', terms.between), ...
    'a mediator normalised within participant loses its between term', nFail);
nFail = ck(all(ismember({'Error_w', 'EffortIndex_w'}, terms.within)), ...
    'both within terms are offered', nFail);

nFail = ck(abs(mean(W2.Trial_z)) < 1e-12 && abs(std(W2.Trial_z) - 1) < 1e-12, ...
    'the trial term is z scored over the analysed rows', nFail);
nFail = ck(isequal(terms.trial, {'Trial_z'}), 'the trial term is offered', nFail);


%% 6. Model recovery
fprintf('\n--- model recovery ---\n');
if isempty(ver('stats'))
    fprintf('  SKIP  Statistics and Machine Learning Toolbox not available\n');
else
    nFail = model_recovery(L, nFail);
end


%% Done
fprintf('\n%s\n', repmat('-', 1, 44));
if nFail == 0
    fprintf('ALL CHECKS PASSED\n\n');
else
    fprintf('%d CHECK(S) FAILED\n\n', nFail);
end

end


% ----------------------------------------------------------------------------
function n = ck(cond, name, n)

if cond
    fprintf('  PASS  %s\n', name);
else
    fprintf('  FAIL  %s\n', name);
    n = n + 1;
end

end


% ----------------------------------------------------------------------------
function tf = errors(fn)

tf = false;
try
    fn();
catch
    tf = true;
end

end


% ----------------------------------------------------------------------------
function q = brute_bh(p)
%BRUTE_BH  The definition, written out, with no shortcuts.

m = numel(p);
[ps, ord] = sort(p(:));
adj = zeros(m, 1);
for i = 1:m
    best = Inf;
    for k = i:m
        best = min(best, min(1, m / k * ps(k)));
    end
    adj(i) = best;
end
q = zeros(m, 1);
q(ord) = adj;
q = reshape(q, size(p));

end


% ----------------------------------------------------------------------------
function [feat, B] = brute_features(P, freqs, epTrial, epCond, bands)
%BRUTE_FEATURES  The feature definition with explicit loops.

conds = unique(epCond);
nF = numel(freqs);

meanTF = cell(1, numel(conds));
for c = 1:numel(conds)
    meanTF{c} = mean(P(:, :, epCond == conds(c)), 3);
end
B = zeros(nF, 1);
for f = 1:nF
    acc = 0;
    for c = 1:numel(conds)
        acc = acc + mean(meanTF{c}(f, :));
    end
    B(f) = acc / numel(conds);
end

names = fieldnames(bands);
uT = unique(epTrial);
feat = zeros(numel(uT), numel(names));

for b = 1:numel(names)
    e = bands.(names{b});
    fIdx = find(freqs >= e(1) & freqs < e(2));
    for t = 1:numel(uT)
        eps = find(epTrial == uT(t));
        acc = [];
        for k = 1:numel(eps)
            v = [];
            for f = fIdx
                v = [v, P(f, :, eps(k)) / B(f)]; %#ok<AGROW>
            end
            acc(k) = mean(v); %#ok<AGROW>
        end
        feat(t, b) = 10 * log10(mean(acc));
    end
end

end


% ----------------------------------------------------------------------------
function nFail = model_recovery(L, nFail)
%MODEL_RECOVERY  Plant a known effect in synthetic data and get it back.
%
%   Fourteen participants, 120 trials, three conditions. One feature genuinely
%   contributes, twenty are noise of the same variance.
%
%   This does not validate the science. It validates that the scaling, the
%   formula, the Wald test and the correction are wired the right way round,
%   which is the part that silently produced nonsense last time.

rng(2026);

nSub = 14;
nTri = 120;
bTrue = 0.30;

sub = repelem((1:nSub)', nTri);

% Pressure is permuted within each participant. Blocking it by trial number,
% which is the obvious way to generate it, makes pressure and trial number
% collinear, and the model now carries both, so the test would be exercising a
% degenerate design rather than the analysis.
press = zeros(nSub * nTri, 1);
trial = zeros(nSub * nTri, 1);
base  = repelem([1; 3; 6], nTri / 3);
for i = 1:nSub
    r = (sub == i);
    press(r) = base(randperm(nTri));
    trial(r) = 1:nTri;
end

subInt = randn(nSub, 1) * 1.2;
effort = 3 + 0.35 * press + randn(nSub * nTri, 1) * 0.8;
err    = 5.5 + 0.08 * press + 0.004 * trial + randn(nSub * nTri, 1) * 1.3;

signal = randn(nSub * nTri, 1);
noise  = randn(nSub * nTri, 20);

score = 1.5 + 1.2 * press + subInt(sub) + 0.25 * effort + 0.05 * err + ...
        bTrue * signal + randn(nSub * nTri, 1) * 1.0;

T = table();
T.SubjectID   = sub;
T.RawTrial    = trial;
T.Score       = score;
T.Error       = err;
T.EffortIndex = effort;
T.Subject_cat = categorical(sub);
T.Pressure_ord = double(categorical(press, [1 3 6])) - 1;     % 0 1 2
T.Pressure_cat = reordercats(categorical(press, [1 3 6], ...
    {'Low', 'Medium', 'High'}), {'Low', 'Medium', 'High'});

% Feature order is cluster then band, so names{1} is the first band of the
% first cluster. The planted effect therefore sits inside one cluster, which
% is what makes the cluster test below a meaningful check.
names = lmm21_feature_names(L);
T.(names{1}) = signal;
for k = 2:numel(names)
    T.(names{k}) = noise(:, k - 1);
end

Lr = L;
Lr.specs = L.specs(strcmp({L.specs.key}, L.primarySpec));

res = fit_lmm21_models(T, Lr);

% The planted feature is the first one, which belongs to the first cluster.
plantedCluster = string(L.clusters{1, 1});

C = res.cluster;
hit    = C(C.Cluster == plantedCluster, :);
others = C(C.Cluster ~= plantedCluster, :);

fprintf('        cluster %s: F(%d,%.0f) = %.2f, p = %.4f, q = %.4f\n', ...
    plantedCluster, hit.DF1, hit.DF2, hit.FStat, hit.pValue, hit.q);
fprintf('        survivors among the other %d clusters: %d\n', ...
    height(others), nnz(others.q < 0.05));

nFail = ck(hit.q < 0.05, ...
    'the cluster holding the planted effect survives the correction', nFail);
nFail = ck(nnz(others.q < 0.05) == 0, ...
    'the six clusters of pure noise give no survivor', nFail);

% The bound pass: the single-feature interval must cover the truth, and the
% feature table must carry no q, because a q there would invite it to be read
% as a family of 21 tests.
F = res.feature;
planted = F(F.Feature == string(names{1}), :);

fprintf('        planted beta %.3f, recovered %.3f [%.3f %.3f]\n', ...
    bTrue, planted.Estimate, planted.Lower, planted.Upper);

nFail = ck(planted.Lower < bTrue && planted.Upper > bTrue, ...
    'the single-feature interval covers the truth', nFail);
nFail = ck(~ismember('q', F.Properties.VariableNames), ...
    'the feature table carries no q, so it cannot be read as 21 tests', nFail);
nFail = ck(ismember('q', C.Properties.VariableNames), ...
    'the cluster table carries the q, because that is the family', nFail);
nFail = ck(height(C) == size(L.clusters, 1), ...
    'there is one test per cluster', nFail);

end