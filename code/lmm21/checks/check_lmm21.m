function nFail = check_lmm21()
%CHECK_LMM21  Acceptance test for the 21 feature LMM code.
%
%  nFail = CHECK_LMM21() runs every check that does not need the data on
%  disk. Run it once after moving the code, and again whenever any of these
%  files is edited. It takes about a minute, most of it in the synthetic
%  model recovery.
%
%  What is checked
%    1. The configuration really describes 21 features, with unique names.
%    2. bh_fdr against a brute force implementation of the definition.
%    3. within_subject_scale, including the guards the old helpers lacked.
%    4. icatimef_band_features against a brute force loop, and the two
%       properties that matter scientifically: a common baseline preserves
%       trial to trial variation and a single trial baseline destroys it.
%    5. The model recovers a planted coefficient, and returns an honest null
%       when there is nothing there.
%
%  What is not checked, because it needs your files
%    the pairing map, the cluster membership file and the behaviour table.
%    Those three adapters are exercised by the first real run, and the audit
%    table from build_eeg_feature_table is what tells you they worked.

nFail = 0;
fprintf('\n');

% =========================================================================
fprintf('--- configuration ---\n');
cfg = lmm21_config();

nFail = ck(numel(cfg.clusters) * numel(cfg.bands) == 21, ...
    'clusters times bands is 21', nFail);

abbr = {cfg.clusters.abbr};
nFail = ck(numel(unique(abbr)) == numel(abbr), 'cluster abbreviations unique', nFail);

names = {};
for c = 1:numel(cfg.clusters)
    for b = 1:numel(cfg.bands)
        names{end+1} = sprintf('%s_%s', cfg.clusters(c).abbr, cfg.bands(b).name); %#ok<AGROW>
    end
end
nFail = ck(numel(unique(names)) == 21, 'feature names unique', nFail);
nFail = ck(all(cellfun(@isvarname, names)), 'feature names are valid identifiers', nFail);

edges = vertcat(cfg.bands.edges);
nFail = ck(all(edges(:, 1) < edges(:, 2)), 'band edges ascend', nFail);
nFail = ck(all(diff(edges(:, 1)) > 0), 'bands listed in ascending order', nFail);

nFail = ck(~cfg.feature.trialBaseline, ...
    'baseline is common, not single trial', nFail);

specKeys = {cfg.specs.key};
nFail = ck(ismember(cfg.primarySpec, specKeys), 'primary spec exists', nFail);

% =========================================================================
fprintf('\n--- bh_fdr ---\n');
rng(11);
p = [rand(18, 1); 0.0005; 0.02; 0.049];

q  = bh_fdr(p);
qb = bruteBH(p);
nFail = ck(max(abs(q - qb)) < 1e-12, 'matches the definition, computed directly', nFail);
nFail = ck(all(q >= p - 1e-15), 'adjusted never below raw', nFail);

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
nFail = ck(nRej == 2 && abs(crit - 0.008) < 1e-15, 'critical value and count', nFail);

% =========================================================================
fprintf('\n--- within_subject_scale ---\n');
g = repelem((1:2)', 6);
x = [1; 2; 3; 4; 5; 6; 10; 20; 30; 40; 50; 60];

z = within_subject_scale(x, g, 'z', 5);
nFail = ck(abs(mean(z(1:6))) < 1e-12 && abs(std(z(1:6)) - 1) < 1e-12, ...
    'z has mean 0 and sd 1 inside a participant', nFail);
nFail = ck(max(abs(z(1:6) - z(7:12))) < 1e-12, ...
    'z removes a per participant scale difference', nFail);

c = within_subject_scale(x, g, 'center', 5);
nFail = ck(abs(std(c(7:12)) - std(x(7:12))) < 1e-12, 'centring keeps the unit', nFail);
nFail = ck(isequal(within_subject_scale(x, g, 'raw'), x), 'raw passes through', nFail);

zs = within_subject_scale([1; 2; 3; 1; 2; 3; 4; 5; 6], ...
                          [1; 1; 1; 2; 2; 2; 2; 2; 2], 'z', 5);
nFail = ck(all(isnan(zs(1:3))) && all(isfinite(zs(4:9))), ...
    'a participant below the minimum trial count is set to NaN', nFail);

nFail = ck(all(isnan(within_subject_scale(7 * ones(6, 1), ones(6, 1), 'z', 5))), ...
    'a constant participant is NaN, not a column of zeros', nFail);

xn = x; xn(2) = NaN;
zn = within_subject_scale(xn, g, 'z', 5);
nFail = ck(isnan(zn(2)) && all(isfinite(zn([1 3 4 5 6]))), ...
    'one NaN does not poison the participant', nFail);
nFail = ck(abs(mean(zn([1 3 4 5 6]))) < 1e-12, ...
    'the NaN row is left out of the mean', nFail);

% =========================================================================
fprintf('\n--- icatimef_band_features ---\n');
freqs = 1:0.5:40;
times = -500:10:3500;
nE = 30;
bands = struct('name', {'theta', 'alpha', 'beta'}, 'edges', {[4 8], [8 13], [13 30]});

rng(3);
P = 1 + rand(numel(freqs), numel(times), nE);
cycWin  = [0 3000];
baseWin = [0 600];

[ratio, info] = icatimef_band_features(P, freqs, times, bands, cycWin, baseWin, false);
[rRef, bRef]  = bruteBandFeatures(P, freqs, times, bands, cycWin, baseWin);

nFail = ck(max(abs(info.baseline - bRef)) < 1e-12, ...
    'common baseline averages over time and epochs', nFail);
nFail = ck(max(abs(ratio(:) - rRef(:))) < 1e-10, ...
    'ratio equals the brute force band by cycle mean', nFail);
nFail = ck(isequal(info.nFreqBins(:)', [9 11 35]), ...
    'band edges are inclusive at both ends', nFail);

% The property the whole design turns on.
P0 = repmat(P(:, :, 1), [1 1 nE]);
gain = linspace(0.5, 2, nE);
Pg = P0 .* reshape(gain, 1, 1, nE);

r0 = icatimef_band_features(P0, freqs, times, bands, cycWin, baseWin, false);
rg = icatimef_band_features(Pg, freqs, times, bands, cycWin, baseWin, false);
nFail = ck(max(abs(rg(:) - reshape(r0 .* (gain(:) / mean(gain)), [], 1))) < 1e-10, ...
    'a common baseline passes trial level variation through', nFail);

rt = icatimef_band_features(Pg, freqs, times, bands, cycWin, baseWin, true);
nFail = ck(std(rt(:, 2)) < 1e-12, ...
    'a single trial baseline destroys trial level variation', nFail);

lin = 10 * log10(mean(ratio(:, 2)));
dbm = mean(10 * log10(ratio(:, 2)));
nFail = ck(lin > dbm && abs(lin - dbm) > 1e-6, ...
    'mean then log differs from log then mean, and is larger', nFail);

Pn = P; Pn(5, 10, 3) = NaN;
nFail = ck(all(isfinite(icatimef_band_features(Pn, freqs, times, bands, ...
    cycWin, baseWin, false)), 'all'), 'one NaN bin does not kill an epoch', nFail);

nFail = ck(errors(@() icatimef_band_features(P, freqs, times, bands, ...
    [9000 9100], baseWin, false)), 'a cycle window off the axis errors', nFail);
nFail = ck(errors(@() icatimef_band_features(P, freqs, times, ...
    struct('name', {'x'}, 'edges', {[200 300]}), cycWin, baseWin, false)), ...
    'a band off the axis errors', nFail);

% =========================================================================
fprintf('\n--- model recovery ---\n');
if isempty(ver('stats'))
    fprintf('  SKIP  Statistics and Machine Learning Toolbox not available\n');
else
    [okPlant, okNull, okBound] = modelRecovery(cfg);
    nFail = ck(okPlant, 'a planted effect is recovered and survives FDR', nFail);
    nFail = ck(okNull,  'pure noise gives no survivor out of 21', nFail);
    nFail = ck(okBound, 'the interval covers the truth', nFail);
end

% =========================================================================
fprintf('\n%s\n', repmat('-', 1, 40));
if nFail == 0
    fprintf('ALL CHECKS PASSED\n\n');
else
    fprintf('%d CHECK(S) FAILED\n\n', nFail);
end

end

% =========================================================================
function n = ck(cond, name, n)
if cond
    fprintf('  PASS  %s\n', name);
else
    fprintf('  FAIL  %s\n', name);
    n = n + 1;
end
end

% -------------------------------------------------------------------------
function tf = errors(fn)
tf = false;
try
    fn();
catch
    tf = true;
end
end

% -------------------------------------------------------------------------
function q = bruteBH(p)
% The definition, written out, with no shortcuts.
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

% -------------------------------------------------------------------------
function [ratio, B] = bruteBandFeatures(P, freqs, times, bands, cycWin, baseWin)
nF = numel(freqs);
nE = size(P, 3);
cycIdx  = find(times >= cycWin(1)  & times <= cycWin(2));
baseIdx = find(times >= baseWin(1) & times <= baseWin(2));

B = zeros(nF, 1);
for f = 1:nF
    acc = [];
    for e = 1:nE
        acc = [acc, reshape(P(f, baseIdx, e), 1, [])]; %#ok<AGROW>
    end
    B(f) = mean(acc);
end

ratio = zeros(nE, numel(bands));
for b = 1:numel(bands)
    fIdx = find(freqs >= bands(b).edges(1) & freqs <= bands(b).edges(2));
    for e = 1:nE
        acc = [];
        for f = fIdx
            acc = [acc, reshape(P(f, cycIdx, e), 1, []) / B(f)]; %#ok<AGROW>
        end
        ratio(e, b) = mean(acc);
    end
end
end

% -------------------------------------------------------------------------
function [okPlant, okNull, okBound] = modelRecovery(cfg)
%MODELRECOVERY  Plant a known effect in synthetic data and get it back.
%
%  14 participants, 120 trials each, three pressure levels. The rating is
%  built from a pressure effect, an effort effect, an error effect, a
%  participant intercept and noise, plus one cortical feature that genuinely
%  contributes. The other 20 features are noise with the same variance.
%
%  This does not validate the science. It validates that the scaling, the
%  formula, the Wald test and the correction are wired up the right way
%  round, which is the part that silently produced nonsense last time.

rng(2026);

nSub = 14;
nTri = 120;
bTrue = 0.30;              % rating points per within participant SD

sub = repelem((1:nSub)', nTri);
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
T.RawTrial    = repmat((1:nTri)', nSub, 1);
T.Pressure    = press;
T.Score       = score;
T.Error       = err;
T.EffortIndex = effort;

F = T(:, {'SubjectID', 'RawTrial'});
featNames = cell(1, 21);
for k = 1:21
    featNames{k} = sprintf('f%02d', k);
end
F.(featNames{1}) = signal;
for k = 2:21
    F.(featNames{k}) = noise(:, k - 1);
end

localCfg = cfg;
localCfg.paths.out = '';
localCfg.verbose   = false;
localCfg.specs     = cfg.specs(strcmp({cfg.specs.key}, cfg.primarySpec));

res = run_lmm_21features(localCfg, F, T(:, {'SubjectID', 'RawTrial', ...
    'Pressure', 'Score', 'Error', 'EffortIndex'}));

P = res.primary;
planted = P(P.Feature == "f01", :);
others  = P(P.Feature ~= "f01", :);

okPlant = planted.q < 0.05;
okNull  = nnz(others.q < 0.05) == 0;
okBound = planted.Lower < bTrue && planted.Upper > bTrue;

fprintf('        planted beta %.3f, recovered %.3f [%.3f %.3f], q = %.4f\n', ...
    bTrue, planted.Estimate, planted.Lower, planted.Upper, planted.q);
fprintf('        survivors among the 20 null features: %d\n', nnz(others.q < 0.05));
end
