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


%% 5. Model recovery
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

sub   = repelem((1:nSub)', nTri);
press = repmat(repelem([1; 3; 6], nTri / 3), nSub, 1);

subInt = randn(nSub, 1) * 1.2;
effort = 3 + 0.35 * press + randn(nSub * nTri, 1) * 0.8;
err    = 5.5 + 0.08 * press + randn(nSub * nTri, 1) * 1.3;

signal = randn(nSub * nTri, 1);
noise  = randn(nSub * nTri, 20);

score = 1.5 + 1.2 * press + subInt(sub) + 0.25 * effort + 0.05 * err + ...
        bTrue * signal + randn(nSub * nTri, 1) * 1.0;

T = table();
T.SubjectID   = sub;
T.Score       = score;
T.Error       = err;
T.EffortIndex = effort;
T.Subject_cat = categorical(sub);
T.Pressure_cat = reordercats(categorical(press, [1 3 6], ...
    {'Low', 'Medium', 'High'}), {'Low', 'Medium', 'High'});

names = lmm21_feature_names(L);
T.(names{1}) = signal;
for k = 2:21
    T.(names{k}) = noise(:, k - 1);
end

Lr = L;
Lr.specs = L.specs(strcmp({L.specs.key}, L.primarySpec));

res = fit_lmm21_models(T, Lr);

P = res.primary;
planted = P(P.Feature == string(names{1}), :);
others  = P(P.Feature ~= string(names{1}), :);

fprintf('        planted beta %.3f, recovered %.3f [%.3f %.3f], q = %.4f\n', ...
    bTrue, planted.Estimate, planted.Lower, planted.Upper, planted.q);
fprintf('        survivors among the 20 null features: %d\n', ...
    nnz(others.q < 0.05));

nFail = ck(planted.q < 0.05, ...
    'a planted effect is recovered and survives the correction', nFail);
nFail = ck(nnz(others.q < 0.05) == 0, ...
    'pure noise gives no survivor out of 21', nFail);
nFail = ck(planted.Lower < bTrue && planted.Upper > bTrue, ...
    'the interval covers the truth', nFail);

end
