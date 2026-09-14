%% RESULTS_BEHAVIOUR
%  The behavioural, muscular and mediation subsections of the Results:
%  descriptives, statistics, the paste-ready LaTeX values, and all three
%  rows of Figure 2. The sensorimotor and parieto-occipital analyses and
%  the integration model live in their own scripts, each reading the same
%  masters through screen_epochs.
%
%  ONE FILE, DELIBERATELY. The alternative is an analysis script and a
%  figure script, which is tidier but lets the p value in a bracket drift
%  away from the p value in the sentence. Here every number in the text
%  and every annotation in the figure comes from one run.
%
%  The cost is the permutation tests, which dominate the runtime and get
%  recomputed on every styling change. RECOMPUTE_CLUSTERS caches them.
%
%  Figure 2, rows 1 and 2, on one canvas.
%
%    Row 1 (a) perceived difficulty by condition
%          (b) tracking error by condition, and across the movement cycle
%    Row 2 (c) four muscles across the cycle, plus the effort index
%
%  Row 3, the mediation diagram, is drawn separately: a path diagram is
%  not something MATLAB should be asked to produce.
%
%  SOURCES. Condition-level numbers come from behaviour_table.mat, so the
%  panels and the paragraph beside them cannot drift apart. Waveforms come
%  from the per-subject master files, since the tables hold no time
%  series. Both are screened through screen_epochs with one policy, so
%  every panel describes the same set of trials.
%
%  WHY THIS REPLACED THE EARLIER SCRIPTS. Rows 1 and 2 previously lived in
%  separate files reading separate legacy structures, each applying its
%  own screening. Those structures used two different trial numbering
%  conventions and disagreed for four participants without saying so.
%  Everything here keys on (SubjectID, RawTrial, RawEpoch), assigned
%  before any filtering, so position never carries identity.
%
%  Requires: screen_epochs.m on the path, and the master tables built by
%  build_emg_master.m, build_tracking_master.m and build_behaviour_table.m.
% =====================================================================

clc; clear;

%% 0. Configuration
% ---------------------------------------------------------------------
data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
out_path  = [data_path, '7_Master_Tables\'];
fig_path  = [data_path, '8_Figures\'];
if ~exist(fig_path,'dir'), mkdir(fig_path); end

LEVELS       = [1 3 6];
COND_NAMES   = {'Low','Medium','High'};
MUSCLE_COLS  = {'iEMG_VM','iEMG_RF','iEMG_GM','iEMG_BF'};
% Side omitted from the panel titles: every channel is from the right
% leg, so repeating it four times adds nothing the caption cannot say
% once.
MUSCLE_NAMES = {'Vastus medialis','Rectus femoris','Gastrocnemius','Biceps femoris'};
POLICY       = 'intersection';

% Warped grid. Resolution is set to what each recording can actually
% support, not to what looks smooth. The EMG envelope is already low-pass
% filtered, so 200 points is ample despite a native 4000 samples per
% cycle; the encoder gives a median of about 34 samples per cycle, so 50
% points is already a modest upsample.
NSAMP_EMG = 200;
NSAMP_TRK = 50;

% Both modalities are warped to equal halves, placing the reversal at 50%
% in every panel. The measured flexion fraction is computed and printed
% below for the Methods, but the plots use 50:50 so that the reversal
% mark means the same thing in every panel of the figure and the rows
% line up vertically. The measured value sits within a fraction of a
% percent of 0.50, so the compression this imposes is negligible.
FLEX_FRAC_PLOT = 0.50;

N_PERM      = 5000;
CLUST_ALPHA = 0.05;
RNG_SEED    = 21;

% The permutation tests take minutes; everything else takes seconds. Set
% false to reuse the cached result while adjusting the figure, and true
% after any change to the screening, the curves or the warp grid.
RECOMPUTE_CLUSTERS = true;
CLUSTER_CACHE = fullfile(out_path, 'figure2_clusters.mat');

% ---- Style, defined once and used by every panel --------------------
S.col       = [1 115 178; 222 143 5; 148 73 92]/255;   % Low, Medium, High
S.font      = 'Arial';
S.fsTick    = 6;
S.fsLab     = 7;
S.fsPanel   = 8;
S.fsEvent   = 4.5;
S.fsStar    = 7;         % significance labels, which need to read at a
                         % glance; the event labels do not and are smaller
S.lw        = 0.5;

% Bracket and label geometry in centimetres, not in data units. The three
% condition panels span different ranges (1 to 10 ratings, 0 to 9 degrees,
% 0 to 6 effort), so a tick specified as a fraction of the axis would come
% out visibly different in each. Fixing the physical size makes them match.
S.brBaseCm  = 0.45;      % gap between the data and the nearest bracket
S.brStepCm  = 0.32;      % separation between bracket levels
S.brTickCm  = 0.09;      % length of the short vertical ticks
S.evGapCm   = 0.06;      % gap between the box edge and the event labels

% Row 3. The diagram is monochrome: an earlier version shaded each
% pathway to match its bar, but three greys that read clearly as filled
% blocks do not survive as 0.8 pt strokes on white. The subscripts
% identify the paths and the bars are labelled in words, so the shading
% was solving a problem the labels had already solved.
S.arrow   = [0.30 0.30 0.30];
S.boxFace = [1 1 1];
S.boxEdge = [0.40 0.40 0.40];
S.boxRad  = 0.06;        % cm, corner radius; 0 gives square corners
S.headLen = 0.17;        % cm, arrow head
S.headWid = 0.062;
S.fsPath  = 6;           % coefficients on the arrows
S.fsBox   = 6;           % text inside the boxes

G = [0.30 0.30 0.30; 0.52 0.52 0.52; 0.72 0.72 0.72];   % bar greys
S.xlabPad   = 0.18;      % cm, below the x tick labels
S.ylabPad   = 0.18;      % cm, left of the y tick labels
S.titleOff  = 0.50;      % cm, above each axes top

% Box convention: on for panels carrying cycle event labels, since the
% box gives those labels something to sit on; off everywhere else, where
% there is no landmark for a box to anchor.

fprintf('=== Figure 2 ===\n');


%% 1. Load and screen
% ---------------------------------------------------------------------
load(fullfile(out_path,'emg_master_index.mat'), 'masterIndex'); E = masterIndex;
load(fullfile(out_path,'trk_master_index.mat'), 'masterIndex'); X = masterIndex;
load(fullfile(out_path,'behaviour_table.mat'),  'T');
clear masterIndex

[keepE, keepX, info] = screen_epochs(E, X, POLICY);
fprintf('Policy %s: %d EMG epochs, %d tracking epochs\n', ...
    info.policy, info.epochsEMG, info.epochsTrack);

% Retained keys, used to select rows inside the per-subject files.
keyE = E(keepE, {'SubjectID','RawTrial','RawEpoch'});
keyX = X(keepX, {'SubjectID','RawTrial','RawEpoch'});


%% 2. Subject-level condition means
% ---------------------------------------------------------------------
% Per-subject means first, then across subjects. Trial counts differ by
% design between the early and late participants (the protocol was
% revised after subject 10), so pooling trials would weight them
% unequally.

subsAll = unique(T.SubjectID);
nCond   = numel(LEVELS);

R = nan(numel(subsAll), nCond);        % perceived difficulty
Q = nan(numel(subsAll), nCond);        % tracking error
F = nan(numel(subsAll), nCond);        % effort index
M = nan(numel(subsAll), nCond, 4);     % per muscle

for i = 1:numel(subsAll)
    for c = 1:nCond
        s = T.SubjectID == subsAll(i) & T.Pressure == LEVELS(c);
        R(i,c) = mean(T.Score(s),       'omitnan');
        Q(i,c) = mean(T.Error(s),       'omitnan');
        F(i,c) = mean(T.EffortIndex(s), 'omitnan');
        for m = 1:4
            M(i,c,m) = mean(T.(MUSCLE_COLS{m})(s), 'omitnan');
        end
    end
end

hasEMG = any(~isnan(F), 2);
Rm = mean(R,1,'omitnan'); Rs = std(R,0,1,'omitnan');
Qm = mean(Q,1,'omitnan'); Qs = std(Q,0,1,'omitnan');
Fm = mean(F,1,'omitnan'); Fs = std(F,0,1,'omitnan');

fprintf('\nPerceived difficulty  %.2f %.2f %.2f  (n = %d), effect %.2f\n', ...
    Rm, sum(any(~isnan(R),2)), Rm(3)-Rm(1));
fprintf('Tracking error (deg)  %.2f %.2f %.2f  (n = %d), High-Low %+.2f\n', ...
    Qm, sum(any(~isnan(Q),2)), Qm(3)-Qm(1));
fprintf('Effort index          %.2f %.2f %.2f  (n = %d), %.2f-fold\n', ...
    Fm, sum(hasEMG), Fm(3)/Fm(1));


%% 3. Perceived difficulty
% ---------------------------------------------------------------------
% A bounded ordinal rating, so a rank-based omnibus was chosen a priori.
% Friedman assumes neither normality nor sphericity. Kendall's W rescales
% the same chi-square onto 0 to 1 and is an effect size, not a second
% test. Holm rather than FDR for the three pairwise comparisons: they are
% a small confirmatory family and the monotonicity claim needs all three
% to stand, so familywise control is the right guarantee.

Rk = R(any(~isnan(R),2), :);
nR = size(Rk,1);

[pFried, tblF] = friedman(Rk, 1, 'off');
chi2R = tblF{2,5}; dfR = tblF{2,3};
W     = chi2R / (nR * (nCond-1));

nMono = sum(all(diff(Rk,1,2) > 0, 2));

pairs = [1 2; 1 3; 2 3];
[pR, dzR] = holmPairwise(Rk, pairs, 'signrank');

fprintf('\n=== Perceived difficulty (n = %d) ===\n', nR);
for c = 1:nCond
    fprintf('  %-7s %.2f +- %.2f  [%.2f, %.2f]\n', COND_NAMES{c}, ...
        Rm(c), Rs(c), min(Rk(:,c)), max(Rk(:,c)));
end
fprintf('  Demand effect: %.2f rating points\n', Rm(3)-Rm(1));
fprintf('  Friedman chi2(%d) = %.2f, p = %.3g, Kendall W = %.3f\n', ...
    dfR, chi2R, pFried, W);
fprintf('  Strict ordering Low < Medium < High in %d of %d\n', nMono, nR);
for c = 1:size(pairs,1)
    fprintf('  %-16s p_Holm = %.4g\n', ...
        sprintf('%s vs %s', COND_NAMES{pairs(c,2)}, COND_NAMES{pairs(c,1)}), pR(c));
end


%% 4. Tracking error
% ---------------------------------------------------------------------
% Continuous, so the parametric route applies. This differs from the
% ratings by design, not by outcome: the argument for ranks there rested
% on the bounded ordinal scale, which does not apply to a kinematic
% measure.
%
% NOTE ON THE MEASURE. This is a mean absolute error, the mean absolute
% difference between knee angle and reference within each cycle. The
% manuscript describes it as root-mean-square, which it is not; per-epoch
% RMS runs 1.216 times larger. The numbers are right, the label is not.

Qk = Q(any(~isnan(Q),2), :);
nQ = size(Qk,1);

[repQ, rmQ] = rmAnovaReport(Qk, COND_NAMES, LEVELS);
[pQ, dzQ]   = holmPairwise(Qk, pairs, 'ttest');
nUp = sum(Qk(:,3) > Qk(:,1));

fprintf('\n=== Tracking error, deg (n = %d) ===\n', nQ);
for c = 1:nCond
    fprintf('  %-7s %.2f +- %.2f\n', COND_NAMES{c}, Qm(c), Qs(c));
end
fprintf('  High minus Low: %+.2f deg (%.1f%% of the Low mean), higher in %d of %d\n', ...
    Qm(3)-Qm(1), 100*(Qm(3)-Qm(1))/Qm(1), nUp, nQ);
fprintf('  %s\n', repQ.line);
fprintf('  Friedman robustness: chi2(2) = %.2f, p = %.3g\n', ...
    repQ.friedChi2, repQ.friedP);
for c = 1:size(pairs,1)
    fprintf('  %-16s diff = %+.3f, dz = %+.2f, p_Holm = %.4g\n', ...
        sprintf('%s vs %s', COND_NAMES{pairs(c,2)}, COND_NAMES{pairs(c,1)}), ...
        mean(Qk(:,pairs(c,2))-Qk(:,pairs(c,1))), dzQ(c), pQ(c));
end

% Trial-level model. The subject-level test has n = 14 and this has
% roughly 1700 observations, so the two can disagree through power alone.
% Reporting both makes that visible instead of leaving a reader to
% wonder which is right.
Tl = T(~isnan(T.Error), :);
Tl.PressureCat = categorical(Tl.Pressure, LEVELS, COND_NAMES);
Tl.PressureCat = reordercats(Tl.PressureCat, COND_NAMES);
lmeQ = fitlme(Tl, 'Error ~ PressureCat + (1|SubjectID)');
fprintf('  Trial-level LMM (n = %d trials):\n', height(Tl));
ciQ = coefCI(lmeQ);
for r = 2:height(lmeQ.Coefficients)
    fprintf('    %-22s %+.3f [%.3f, %.3f], p = %.3g\n', ...
        lmeQ.Coefficients.Name{r}, lmeQ.Coefficients.Estimate(r), ...
        ciQ(r,1), ciQ(r,2), lmeQ.Coefficients.pValue(r));
end


%% 5. Effort index
% ---------------------------------------------------------------------
Fk = F(hasEMG, :);
nF = size(Fk,1);
[repF, rmF_] = rmAnovaReport(Fk, COND_NAMES, LEVELS);
[pF, dzF]    = holmPairwise(Fk, pairs, 'ttest');

fprintf('\n=== Effort index (n = %d) ===\n', nF);
for c = 1:nCond
    fprintf('  %-7s %.2f +- %.2f\n', COND_NAMES{c}, Fm(c), Fs(c));
end
fprintf('  High / Low: %.2f-fold, monotonic in %d of %d\n', ...
    Fm(3)/Fm(1), sum(all(diff(Fk,1,2) > 0, 2)), nF);
fprintf('  %s\n', repF.line);
for c = 1:size(pairs,1)
    fprintf('  %-16s diff = %+.3f, dz = %+.2f, p_Holm = %.4g\n', ...
        sprintf('%s vs %s', COND_NAMES{pairs(c,2)}, COND_NAMES{pairs(c,1)}), ...
        mean(Fk(:,pairs(c,2))-Fk(:,pairs(c,1))), dzF(c), pF(c));
end


%% 6. Per-muscle, for the supplementary table
% ---------------------------------------------------------------------
fprintf('\n=== Per-muscle iEMG (n = %d) ===\n', nF);
muscleStats = struct();
for m = 1:4
    Mk = squeeze(M(hasEMG,:,m));
    pM = holmPairwise(Mk, pairs, 'ttest');
    mm = mean(Mk,1,'omitnan'); ss = std(Mk,0,1,'omitnan');
    muscleStats(m).name = MUSCLE_NAMES{m};
    muscleStats(m).mean = mm; muscleStats(m).sd = ss;
    muscleStats(m).fold = mm(3)/mm(1); muscleStats(m).p = pM;
    fprintf('  %-18s %.2f+-%.2f  %.2f+-%.2f  %.2f+-%.2f | %.2f-fold | p_Holm %.3g %.3g %.3g\n', ...
        MUSCLE_NAMES{m}, mm(1),ss(1), mm(2),ss(2), mm(3),ss(3), mm(3)/mm(1), pM);
end


%% 7. Mediation
% ---------------------------------------------------------------------
% How much of the pressure effect on perceived difficulty passes through
% peripheral effort and through task performance.
%
% PRESSURE CODING. Ordinal, 0 / 1 / 2. The hypothesis is that demand
% grades difficulty, and everything else in this section supports grading
% rather than mere difference, so the model should test the ordered
% prediction rather than remain agnostic about it. It also gives one
% coefficient per path instead of two, which is what makes the diagram
% readable. Section 7c checks the equal-step assumption.
%
% Note this is not the same as using raw bar values. Pressure runs 1, 3,
% 6, which are not equally spaced, while the responses are close to
% equally spaced. Coding 0 / 1 / 2 fits what the data do.
%
% WITHIN AND BETWEEN. Mediators are split into a person-mean part and a
% deviation from it. In a within-subject design the a and b paths can
% differ between the two levels, and a model ignoring the split can
% report an indirect effect that exists at neither.
%
% INTERVALS. Monte Carlo. The indirect effect is a product of two
% estimates, and products are skewed, so a symmetric interval is wrong at
% both ends. Drawing each coefficient from the sampling distribution its
% standard error already implies, forming the product, and taking
% percentiles reproduces the correct shape.
%
% A LIMIT FOR THE DISCUSSION. This estimates how much passes through the
% mediators as measured. The effort index is integrated EMG, which is
% efferent drive, not afferent feedback, so eliminating that route does
% not eliminate a peripheral origin.

N_MC = 20000;

medOK = ~isnan(T.Score) & ~isnan(T.Error) & ~isnan(T.EffortIndex) & ...
        ismember(T.Pressure, LEVELS);

% Complete cases only, so every path is fitted on one set of trials.
% Letting each model drop its own would make the decomposition into
% direct and indirect incoherent.
MD          = table();
MD.Subject  = categorical(T.SubjectID(medOK));
MD.Y        = T.Score(medOK);
MD.M1       = T.EffortIndex(medOK);
MD.M2       = T.Error(medOK);
MD.Xord     = double(categorical(T.Pressure(medOK), LEVELS)) - 1;
MD.Xcat     = reordercats(categorical(T.Pressure(medOK), LEVELS, COND_NAMES), COND_NAMES);
MD.Trial    = T.RawTrial(medOK);

fprintf('\n=== Mediation (%d trials, %d participants) ===\n', ...
    height(MD), numel(unique(MD.Subject)));

medSubs = unique(MD.Subject);
MD.M1w = nan(height(MD),1); MD.M1b = nan(height(MD),1);
MD.M2w = nan(height(MD),1); MD.M2b = nan(height(MD),1);
for i = 1:numel(medSubs)
    r = MD.Subject == medSubs(i);
    MD.M1b(r) = mean(MD.M1(r)); MD.M1w(r) = MD.M1(r) - mean(MD.M1(r));
    MD.M2b(r) = mean(MD.M2(r)); MD.M2w(r) = MD.M2(r) - mean(MD.M2(r));
end
MD.M1b = MD.M1b - mean(MD.M1b);
MD.M2b = MD.M2b - mean(MD.M2b);
MD.Tz  = (MD.Trial - mean(MD.Trial)) / std(MD.Trial);

% A between-subject term exists only if participants differ on that
% mediator. The effort index is normalised within subject, so every
% participant's mean is four by construction and the term is a column of
% zeros, which makes the design matrix rank deficient.
%
% Worth stating rather than silently dropping: the normalisation removes
% all between-subject variance in effort, so the mediation cannot ask
% whether people who work harder overall feel the task as harder. Without
% a maximum voluntary contraction there is no scale on which it could.
betweenTerms = {};
for v = {'M1b','M2b'}
    if std(MD.(v{1})) > 1e-10, betweenTerms{end+1} = v{1}; end %#ok<SAGROW>
end

% Trial number enters throughout: it has a large effect on tracking error
% and leaving it in a mediator's residual widens every interval.
mdlA1 = fitlme(MD, 'M1 ~ Xord + Tz + (1|Subject)');
mdlA2 = fitlme(MD, 'M2 ~ Xord + Tz + (1|Subject)');
mdlC  = fitlme(MD, 'Y  ~ Xord + Tz + (1|Subject)');
fB = 'Y ~ Xord + M1w + M2w + Tz';
for v = betweenTerms, fB = [fB ' + ' v{1}]; end %#ok<AGROW>
mdlB = fitlme(MD, [fB ' + (1|Subject)']);

a1 = getCoef(mdlA1,'Xord'); a2 = getCoef(mdlA2,'Xord');
b1 = getCoef(mdlB,'M1w');   b2 = getCoef(mdlB,'M2w');
cT = getCoef(mdlC,'Xord');  cP = getCoef(mdlB,'Xord');

showPath('a1  pressure -> effort',   a1, '');
showPath('a2  pressure -> error',    a2, 'deg');
showPath('b1  effort -> difficulty', b1, '');
showPath('b2  error -> difficulty',  b2, '');
showPath('c   total',                cT, 'rating points');
showPath('c'' direct',               cP, 'rating points');

rng(RNG_SEED,'twister');
ind1 = (a1.est + a1.se*randn(N_MC,1)) .* (b1.est + b1.se*randn(N_MC,1));
ind2 = (a2.est + a2.se*randn(N_MC,1)) .* (b2.est + b2.se*randn(N_MC,1));
dirD = cP.est + cP.se*randn(N_MC,1);
totD = ind1 + ind2 + dirD;

fprintf('\n--- Indirect effects (rating points per level) ---\n');
showMC('through effort',         ind1, '');
showMC('through tracking error', ind2, '');
showMC('direct',                 dirD, '');
showMC('total (decomposed)',     totD, '');
fprintf('%-26s %+7.3f [%+.3f, %+.3f]\n', 'total (fitted)', cT.est, cT.lo, cT.hi);

% A ratio of two uncertain quantities behaves worse than their product,
% so the proportions get intervals rather than point estimates. The
% denominator is the decomposed total from the same draw, which keeps
% numerator and denominator internally consistent.
fprintf('\n--- Proportion of the total effect ---\n');
showMC('through effort',         100*ind1./totD, '%');
showMC('through tracking error', 100*ind2./totD, '%');
showMC('direct',                 100*dirD./totD, '%');

% Collinearity. Pressure acts directly on muscular demand, so a strong
% coupling means the manipulation worked; but it also means the direct
% and effort-mediated paths are estimated from partially overlapping
% variance, which belongs in the Methods rather than left for a reader to
% compute.
rXM = corr(MD.Xord, MD.M1w);
fprintf('\nPressure and effort correlate at r = %.2f (VIF %.1f)\n', ...
    rXM, 1/(1-rXM^2));

% Section 7c. The ordinal coding treats Low to Medium as the same
% increment as Medium to High. The categorical model estimates the two
% separately, so this tests the assumption rather than asserting it.
mdlCc = fitlme(MD, 'Y ~ Xcat + Tz + (1|Subject)');
mMed  = getCoef(mdlCc,'Xcat_Medium'); mHigh = getCoef(mdlCc,'Xcat_High');
fprintf('Equal-step check: High contrast is %.2f times Medium (2.00 = equal)\n', ...
    mHigh.est/mMed.est);

med = struct('a1',a1,'a2',a2,'b1',b1,'b2',b2,'c',cT,'cPrime',cP, ...
             'ind1',ind1,'ind2',ind2,'direct',dirD,'total',totD, ...
             'nTrials',height(MD),'nSubjects',numel(medSubs));


%% 8. Warp composition, measured then fixed
% ---------------------------------------------------------------------
% Computed for the Methods; the plots use FLEX_FRAC_PLOT regardless.

fprintf('\n--- Measured flexion fraction (screened epochs) ---\n');
fprintf('EMG      %.4f\n', flexFraction(E(keepE,:)));
fprintf('Tracking %.4f\n', flexFraction(X(keepX,:)));
fprintf('Plotted at %.2f so the reversal marks the same point in every panel.\n', ...
    FLEX_FRAC_PLOT);


%% 9. Cycle curves
% ---------------------------------------------------------------------
% Epochs are averaged within a trial, then trials within a condition.
% Epoch counts vary between trials, so pooling epochs would weight long
% trials more heavily, and trial is the unit every model in the paper
% operates on.

fprintf('\nBuilding cycle curves ...\n');
[emgCurves, emgSubs] = buildEMGCurves(out_path, keyE, T, LEVELS, ...
                                      NSAMP_EMG, FLEX_FRAC_PLOT);
[trkCurves, trkSubs] = buildTrackingCurves(out_path, keyX, T, LEVELS, ...
                                      NSAMP_TRK, FLEX_FRAC_PLOT);
fprintf('  EMG      %d subjects\n', numel(emgSubs));
fprintf('  Tracking %d subjects\n', numel(trkSubs));


%% 10. Cluster-based permutation
% ---------------------------------------------------------------------
% A repeated measures F at every warped sample, contiguous suprathreshold
% samples grouped into clusters, and a null built by permuting condition
% labels within participant.
%
% The omnibus F is unsigned, so a significant cluster says the conditions
% differ somewhere in that window, not which is larger and not where the
% effect is concentrated. A cluster grows to absorb every adjacent
% suprathreshold sample, so its extent is not an estimate of the effect's
% extent. Partial eta squared is plotted beneath each panel to carry that
% question instead.
%
% Each muscle is its own family. These are four a priori hypotheses about
% anatomically distinct muscles, not a screen over many candidates, so no
% correction is applied across them.

if ~RECOMPUTE_CLUSTERS && exist(CLUSTER_CACHE,'file')
    load(CLUSTER_CACHE, 'emgClust','emgEta','trkClust','trkEta');
    fprintf('\nCluster results loaded from cache.\n');
else
    rng(RNG_SEED,'twister');
    emgClust = cell(4,1); emgEta = nan(4, NSAMP_EMG);
    fprintf('\n=== Cluster-based permutation ===\n');
    for m = 1:4
        [emgClust{m}, emgEta(m,:)] = clusterTest( ...
            squeeze(emgCurves(:,m,:,:)), N_PERM, CLUST_ALPHA);
    end
    [trkClust, trkEta] = clusterTest(trkCurves, N_PERM, CLUST_ALPHA);
    save(CLUSTER_CACHE, 'emgClust','emgEta','trkClust','trkEta');
end

% Reported with the effect-size trace alongside, because a cluster's
% extent is not an estimate of the effect's extent: it grows to absorb
% every adjacent suprathreshold sample.
for m = 1:4
    reportClusters(MUSCLE_NAMES{m}, emgClust{m}, emgEta(m,:));
end
reportClusters('Tracking error', trkClust, trkEta);


%% 11. Figure
% ---------------------------------------------------------------------
% One canvas for both rows, so the panels align vertically and the fonts
% and margins cannot drift apart. Positions are explicit in centimetres
% rather than through subplot or tiledlayout: the geometry is then edited
% in one block, and fonts are specified at final print size instead of
% being rescaled after the fact.

figW = 18.0; figH = 16.6;

% Both rows run between the same two margins. Panel widths and gaps are
% derived from those margins rather than set independently, so the rows
% cannot end at different points on the right: the earlier version had
% row 1 finishing at 17.15 and row 2 at 17.60.
L.left  = 1.30;
L.right = 17.15;
L.span  = L.right - L.left;

% Row origins chosen so the gap between rows 1 and 2 matches the gap
% between rows 2 and 3. Rows 1 and 2 share an internal structure and row
% 3 does not, so equal origin spacing would not have produced equal
% visual spacing.
L.rowY   = [11.50, 5.45, 0.55];

% Row 3 has no effect-size strip, so it gets its own geometry: two panels
% of equal height sharing one baseline.
L.r3O = 0.75; L.r3H = 3.00;
L.stripO = 0.80;  L.stripH = 0.55;
L.mainO  = 1.55;  L.mainH  = 2.85;
L.fullH  = L.mainO + L.mainH - L.stripO;
% Letter heights are set per row, not by one shared offset, because the
% rows differ in what sits above their axes. Row 2's panels carry titles,
% so its letter clears a title; rows 1 and 3 carry none, so the same
% offset left their letters floating well above the content they label.
% Values are centimetres above each row's origin.
L.letterUp = [4.55, 5.00, 3.70];

% Row 1: three panels, gaps split evenly over what the widths leave.
L.r1w = [4.10, 4.10, 4.45];
g1 = (L.span - sum(L.r1w)) / 2;
L.r1x = L.left + [0, L.r1w(1)+g1, L.r1w(1)+L.r1w(2)+2*g1];

% Row 2: five panels of equal width. The four muscle panels sit close
% together and the effort index further out, since its y-label needs
% clearance from biceps femoris. Equal gaps put the two against each
% other.
L.r2w   = 2.70;
gMus    = 0.45;
gEffort = L.span - 5*L.r2w - 3*gMus;
L.r2x   = L.left + [0, ...
                    (L.r2w+gMus), ...
                    2*(L.r2w+gMus), ...
                    3*(L.r2w+gMus), ...
                    3*(L.r2w+gMus) + L.r2w + gEffort];

assert(abs(L.r1x(end)+L.r1w(end) - L.right) < 1e-9 && ...
       abs(L.r2x(end)+L.r2w      - L.right) < 1e-9, ...
       'Rows do not share a right margin.');

fig = figure('Units','centimeters','Position',[1 1 figW figH], ...
             'Color','w','PaperPositionMode','auto');

% ================= ROW 1 =============================================
y0 = L.rowY(1);

% ---- a: perceived difficulty ----------------------------------------
ax = axes(fig,'Units','centimeters','Position',[L.r1x(1) y0+L.stripO L.r1w(1) L.fullH]);
hold(ax,'on');
conditionCloud(ax, R(any(~isnan(R),2),:), S.col, nCond);
ylim(ax,[0.5 10.5]);
% Brackets above the data here: the scale floors at 1 and a participant
% sits on it, so there is no room underneath.
drawBrackets(ax, pR, max(Rk(:)), S, false);
set(ax,'XTick',1:nCond,'XTickLabel',COND_NAMES,'YTick',1:10, ...
    'FontName',S.font,'FontSize',S.fsTick,'TickDir','in','Box','off','LineWidth',S.lw);
ylabel(ax,'Perceived difficulty','FontName',S.font,'FontSize',S.fsLab);
xlabel(ax,'Physical demand','FontName',S.font,'FontSize',S.fsLab);
padLabels(ax, S); hold(ax,'off');

% ---- b left: tracking error by condition ----------------------------
ax = axes(fig,'Units','centimeters','Position',[L.r1x(2) y0+L.stripO L.r1w(2) L.fullH]);
hold(ax,'on');
conditionCloud(ax, Q(any(~isnan(Q),2),:), S.col, nCond);
% Anchor at zero first, so the bracket geometry is computed against the
% final axis rather than the autoscaled one. axTop is reused below for
% the tick spacing, so it has to survive the ylim call.
axTop = max(ylim(ax));
ylim(ax,[0 axTop]);
drawBrackets(ax, pQ, min([Qk(:); (Qm-Qs)']), S, true);
set(ax,'XTick',1:nCond,'XTickLabel',COND_NAMES,'YTick',0:2:floor(axTop), ...
    'FontName',S.font,'FontSize',S.fsTick,'TickDir','in','Box','off','LineWidth',S.lw);
ylabel(ax,'Tracking error (deg)','FontName',S.font,'FontSize',S.fsLab);
xlabel(ax,'Physical demand','FontName',S.font,'FontSize',S.fsLab);
padLabels(ax, S); hold(ax,'off');

% ---- b right: tracking error across the cycle ------------------------
axM = axes(fig,'Units','centimeters','Position',[L.r1x(3) y0+L.mainO L.r1w(3) L.mainH]);
axS = axes(fig,'Units','centimeters','Position',[L.r1x(3) y0+L.stripO L.r1w(3) L.stripH]);
% No title on either tracking panel: the y-labels already say what they
% show, and the row reads as one panel b.
cyclePanel(axM, axS, trkCurves, trkEta, trkClust, S, COND_NAMES, ...
    'Tracking error (deg)', '', 'southeast', L.mainH);

% ================= ROW 2 =============================================
y0 = L.rowY(2);

% Extensors and flexors take separate shared y-limits. Their amplitudes
% differ by roughly threefold, and one common scale would flatten the
% extensors against the axis.
mu  = squeeze(mean(emgCurves,1,'omitnan'));
sem = squeeze(std(emgCurves,0,1,'omitnan'))/sqrt(size(emgCurves,1));
topExt = max(max(max(mu(1:2,:,:) + sem(1:2,:,:))));
topFlx = max(max(max(mu(3:4,:,:) + sem(3:4,:,:))));

for m = 1:4
    axM = axes(fig,'Units','centimeters', ...
        'Position',[L.r2x(m) y0+L.mainO L.r2w L.mainH]);
    axS = axes(fig,'Units','centimeters', ...
        'Position',[L.r2x(m) y0+L.stripO L.r2w L.stripH]);

    if m <= 2, yTop = topExt*1.10; else, yTop = topFlx*1.10; end
    ylab = ''; if m == 1, ylab = 'Normalised EMG'; end

    % Legend on biceps femoris rather than vastus medialis: that panel's
    % curves fall away after the reversal, leaving the top right corner
    % clear, whereas vastus medialis rises again into it.
    if m == 4, lgLoc = 'northeast'; else, lgLoc = ''; end
    cyclePanel(axM, axS, squeeze(emgCurves(:,m,:,:)), emgEta(m,:), ...
        emgClust{m}, S, COND_NAMES, ylab, MUSCLE_NAMES{m}, lgLoc, L.mainH, yTop);
end

% ---- effort index ----------------------------------------------------
ax = axes(fig,'Units','centimeters', ...
    'Position',[L.r2x(5) y0+L.stripO L.r2w L.fullH]);
hold(ax,'on');
conditionCloud(ax, F(hasEMG,:), S.col, nCond);
% Zero is a meaningful floor for a sum of normalised iEMG, and anchoring
% there matches the muscle panels beside it.
axTop = max(ylim(ax));
ylim(ax,[0 axTop]);
drawBrackets(ax, pF, min([Fk(:); (Fm-Fs)']), S, true);
set(ax,'XTick',1:nCond,'XTickLabel',COND_NAMES,'YTick',0:1:floor(axTop), ...
    'FontName',S.font,'FontSize',S.fsTick,'TickDir','in','Box','off','LineWidth',S.lw);
ylabel(ax,'Effort index','FontName',S.font,'FontSize',S.fsLab);
xlabel(ax,'Physical demand','FontName',S.font,'FontSize',S.fsLab);
panelTitle(ax,'All four muscles',S,L.fullH);
padLabels(ax, S); hold(ax,'off');

% ================= ROW 3 =============================================
y0 = L.rowY(3);

% Left: the path diagram. Drawn in normalised coordinates so the box
% positions survive a change of panel size.
xDiag = L.left;  wDiag = 7.60;
xDec  = 10.90;   wDec  = L.right - xDec;

axD = axes(fig,'Units','centimeters','Position',[xDiag y0+L.r3O wDiag L.r3H]);
hold(axD,'on'); xlim(axD,[0 1]); ylim(axD,[0 1]); axis(axD,'off');

BW = 0.25; BH = 0.22;
xP = 0.140; xM = 0.50; xY = 0.860;
yT = 0.82;  yMm = 0.50; yB = 0.18;

drawBox(axD, xP,  yMm, BW, BH, sprintf('Physical\ndemand'),      S);
drawBox(axD, xM,  yT,  BW, BH, 'Effort index',                   S);
drawBox(axD, xM,  yB,  BW, BH, 'Tracking error',                 S);
drawBox(axD, xY,  yMm, BW, BH, sprintf('Perceived\ndifficulty'), S);

% The three paths leave the manipulation at separate points on its right
% edge and arrive at the outcome at separate points on its left, so
% neither box has three arrows stacked on one spot. They meet the
% mediators at mid-height, where only one arrow lands.
dy = 0.06;
drawArrow(axD, [xP+BW/2, yMm+dy], [xM-BW/2, yT ], S);
drawArrow(axD, [xM+BW/2, yT ],    [xY-BW/2, yMm+dy], S);
drawArrow(axD, [xP+BW/2, yMm-dy], [xM-BW/2, yB ], S);
drawArrow(axD, [xM+BW/2, yB ],    [xY-BW/2, yMm-dy], S);
drawArrow(axD, [xP+BW/2, yMm],    [xY-BW/2, yMm], S);

% Labels on a fixed grid rather than derived from each arrow, which is
% what left them at four different heights. a1 and b1 share a row, a2 and
% b2 share a row, a1 and a2 a column, b1 and b2 a column. The rows sit
% level with the mediator boxes, in the open corners, so no label crosses
% a line.
pathLabel(axD, 0.235, yT,       sprintf('a_1 = %+.2f', med.a1.est), S);
pathLabel(axD, 0.765, yT,       sprintf('b_1 = %+.2f', med.b1.est), S);
pathLabel(axD, 0.235, yB,       sprintf('a_2 = %+.2f', med.a2.est), S);
pathLabel(axD, 0.765, yB,       sprintf('b_2 = %+.2f', med.b2.est), S);
pathLabel(axD, 0.500, yMm+0.085, sprintf('c'' = %+.2f', med.cPrime.est), S);

% Level with the axis label opposite, so the row has one baseline instead
% of a filled block on the right and empty space on the left.
text(axD, 0.50, -0.20, sprintf(['total effect c = %+.2f rating points ' ...
    'per level of demand'], med.c.est), ...
    'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'Clipping','off','FontName',S.font,'FontSize',S.fsPath, ...
    'Color',[0.4 0.4 0.4]);
hold(axD,'off');

% Right: the decomposition.
%
% Not a stacked bar. Only the bottom segment of a stack starts at a
% common baseline, so the others are judged by comparing edges that both
% float, and stacking forces the parts to sum to the whole, leaving
% nowhere to attach an interval. The interval on the tracking-error share
% is the strongest part of this result: not merely small, but bounded
% near zero.
axB = axes(fig,'Units','centimeters','Position',[xDec y0+L.r3O wDec L.r3H]);
hold(axB,'on');

comp = {'Direct', med.direct, G(1,:); 'Via effort', med.ind1, G(2,:); ...
        'Via tracking error', med.ind2, G(3,:)};
nC = size(comp,1);
for i = 1:nC
    yy = nC - i + 1;
    d = comp{i,2};
    lo = prctile(d,2.5); hi = prctile(d,97.5);
    barh(axB, yy, median(d), 0.5, 'FaceColor', comp{i,3}, 'EdgeColor','none');
    plot(axB, [lo hi], [yy yy], 'k-', 'LineWidth', 0.7);
    plot(axB, [lo lo], yy+[-0.10 0.10], 'k-', 'LineWidth', 0.7);
    plot(axB, [hi hi], yy+[-0.10 0.10], 'k-', 'LineWidth', 0.7);
    text(axB, hi+0.07, yy, sprintf('%.0f%%', median(100*d./med.total)), ...
        'FontName',S.font,'FontSize',S.fsTick, ...
        'HorizontalAlignment','left','VerticalAlignment','middle');
end

xlim(axB,[0, med.c.est*1.20]); ylim(axB,[0.45, nC+0.55]);
% Trailing spaces open a gap between the right-aligned tick labels and
% the axis line.
set(axB,'YTick',1:nC,'YTickLabel',strcat(flip(comp(:,1)), {'   '}), ...
    'XTick',0:0.5:2.5,'FontName',S.font,'FontSize',S.fsTick, ...
    'TickDir','in','Box','off','LineWidth',S.lw);
xlabel(axB, sprintf(['Effect on perceived difficulty\n' ...
    '(rating points per level)']),'FontName',S.font,'FontSize',S.fsLab);
padLabels(axB, S);
hold(axB,'off');


% ---- panel letters ---------------------------------------------------
% Row 2 takes a single letter: its five plots are one panel of the
% figure, not five.
yLet = (L.rowY + L.letterUp) / figH;
letterAt(fig, 0.004,                yLet(1), 'a', S);
letterAt(fig, (L.r1x(2)-1.10)/figW, yLet(1), 'b', S);
letterAt(fig, 0.004,                yLet(2), 'c', S);
% One letter for row 3: the diagram and the decomposition are a single
% analysis shown two ways.
letterAt(fig, 0.004,                yLet(3), 'd', S);


%% 12. Paste-ready values for the manuscript
% ---------------------------------------------------------------------
% Printed in the order they appear in the Results, so the section can be
% assembled without going back to individual outputs.

fprintf('\n%s\n', repmat('=',1,68));
fprintf('PASTE-READY\n');
fprintf('%s\n\n', repmat('=',1,68));

fprintf(['Low: $%.2f \\pm %.2f$; Medium: $%.2f \\pm %.2f$; ' ...
         'High: $%.2f \\pm %.2f$\n'], [Rm; Rs]);
fprintf('Friedman $\\chi^{2}(%d) = %.2f$, $p %s$, Kendall''s $W = %.2f$\n', ...
    dfR, chi2R, fmtP(pFried), W);
fprintf('Wilcoxon signed-rank, Holm-corrected, all $p %s$\n', fmtP(max(pR)));
fprintf('Ordering unanimous: %d of %d\n', nMono, nR);
fprintf('Demand effect: %.2f rating points\n\n', Rm(3)-Rm(1));

fprintf(['Low: $%.2f \\pm %.2f^{\\circ}$; Medium: $%.2f \\pm %.2f^{\\circ}$; ' ...
         'High: $%.2f \\pm %.2f^{\\circ}$\n'], [Qm; Qs]);
fprintf('%s\n', repQ.latex);
fprintf('High minus Low $%.2f^{\\circ}$ (%.1f\\%% of the Low mean), %d of %d\n', ...
    Qm(3)-Qm(1), 100*(Qm(3)-Qm(1))/Qm(1), nUp, nQ);
fprintf('No pairwise comparison survives Holm (all $p > %.2f$)\n', min(pQ));
for r = 2:height(lmeQ.Coefficients)
    fprintf('  %s: $%+.2f^{\\circ}$ [%.2f, %.2f]\n', ...
        lmeQ.Coefficients.Name{r}, lmeQ.Coefficients.Estimate(r), ciQ(r,1), ciQ(r,2));
end
fprintf('\n');

fprintf(['Low: $%.2f \\pm %.2f$; Medium: $%.2f \\pm %.2f$; ' ...
         'High: $%.2f \\pm %.2f$; $n = %d$\n'], [Fm; Fs], nF);
fprintf('%.2f-fold; monotonic in %d of %d\n', ...
    Fm(3)/Fm(1), sum(all(diff(Fk,1,2) > 0, 2)), nF);
fprintf('%s\n', repF.latex);
fprintf('All pairwise $p %s$, paired $t$ tests, Holm-corrected\n\n', fmtP(max(pF)));

for m = 1:4
    fprintf('%s: %.2f-fold, all pairwise $p %s$\n', ...
        muscleStats(m).name, muscleStats(m).fold, fmtP(max(muscleStats(m).p)));
end
fprintf('\n');

for m = 1:4
    latexClusters(MUSCLE_NAMES{m}, emgClust{m}, emgEta(m,:));
end
latexClusters('Tracking error', trkClust, trkEta);

fprintf('\n--- Mediation ---\n');
fprintf('a_1 $%+.2f$ [%.2f, %.2f];  b_1 $%+.2f$ [%.2f, %.2f]\n', ...
    med.a1.est, med.a1.lo, med.a1.hi, med.b1.est, med.b1.lo, med.b1.hi);
fprintf('a_2 $%+.2f$ [%.2f, %.2f];  b_2 $%+.3f$ [%.3f, %.3f]\n', ...
    med.a2.est, med.a2.lo, med.a2.hi, med.b2.est, med.b2.lo, med.b2.hi);
fprintf('c $%+.2f$ [%.2f, %.2f];  c'' $%+.2f$ [%.2f, %.2f]\n', ...
    med.c.est, med.c.lo, med.c.hi, med.cPrime.est, med.cPrime.lo, med.cPrime.hi);
fprintf('Effort %.0f\\%% [%.0f, %.0f]; error %.0f\\%% [%.0f, %.0f]; direct %.0f\\%% [%.0f, %.0f]\n', ...
    median(100*med.ind1./med.total), prctile(100*med.ind1./med.total,[2.5 97.5]), ...
    median(100*med.ind2./med.total), prctile(100*med.ind2./med.total,[2.5 97.5]), ...
    median(100*med.direct./med.total), prctile(100*med.direct./med.total,[2.5 97.5]));


%% 13. Export
% ---------------------------------------------------------------------
exportgraphics(fig, fullfile(fig_path,'figure2_rows12.pdf'), ...
    'ContentType','vector','BackgroundColor','white');
exportgraphics(fig, fullfile(fig_path,'figure2_rows12.png'), ...
    'Resolution',600,'BackgroundColor','white');
fprintf('\nWritten to %s\n', fig_path);


%% ====================================================================
%  Local functions
%  ====================================================================

function [curves, subs] = buildEMGCurves(out_path, keyE, T, LEVELS, NG, flexFrac)
% Per-subject, per-condition EMG cycle curves.
% Returns nSubj x 4 muscles x NG x 3 conditions.
%
% Normalisation divides each muscle by that subject's own mean across
% retained epochs, removing between-subject amplitude differences from
% electrode placement and tissue. It is a scalar divide per muscle, so it
% leaves condition ratios untouched and no fold change depends on it.

    subs = unique(keyE.SubjectID);
    nF = round(NG*flexFrac); nE = NG - nF;
    curves = nan(numel(subs), 4, NG, numel(LEVELS));

    for i = 1:numel(subs)
        f = fullfile(out_path, sprintf('emg_master_sub-%d.mat', subs(i)));
        D = load(f, 'E', 'Sig');

        sel = ismember(D.E(:,{'SubjectID','RawTrial','RawEpoch'}), keyE);
        rows = find(sel);
        if isempty(rows), continue; end

        W = nan(numel(rows), 4, NG);
        for q = 1:numel(rows)
            r = rows(q);
            W(q,:,:) = warpEpoch(double(D.Sig{r}), D.E.ExtStart(r), ...
                                 D.E.ExtEnd(r), nF, nE);
        end

        % Epochs to trials, then trials to conditions.
        tr  = D.E.RawTrial(rows);
        pr  = D.E.Pressure(rows);
        uTr = unique(tr);
        TC  = nan(numel(uTr), 4, NG); TP = nan(numel(uTr),1);
        for t = 1:numel(uTr)
            s = tr == uTr(t);
            TC(t,:,:) = mean(W(s,:,:), 1, 'omitnan');
            TP(t) = pr(find(s,1));
        end

        nf = mean(mean(TC, 3, 'omitnan'), 1, 'omitnan');   % 1 x 4
        for c = 1:numel(LEVELS)
            s = TP == LEVELS(c);
            if ~any(s), continue; end
            curves(i,:,:,c) = squeeze(mean(TC(s,:,:),1,'omitnan')) ./ nf(:);
        end
        clear D
    end

    good = squeeze(~all(all(all(isnan(curves),2),3),4));
    curves = curves(good,:,:,:); subs = subs(good);
end


function [curves, subs] = buildTrackingCurves(out_path, keyX, T, LEVELS, NG, flexFrac)
% Per-subject, per-condition tracking error curves.
% Returns nSubj x NG x 3.
%
% Error is the absolute difference between encoder and reference angle,
% matching the trial-level measure in the behaviour table. The masters
% store the two angles rather than a derived error precisely so that this
% definition is visible at the point of use.

    subs = unique(keyX.SubjectID);
    nF = round(NG*flexFrac); nE = NG - nF;
    curves = nan(numel(subs), NG, numel(LEVELS));

    for i = 1:numel(subs)
        f = fullfile(out_path, sprintf('trk_master_sub-%d.mat', subs(i)));
        D = load(f, 'X', 'Enc', 'Ref');

        sel = ismember(D.X(:,{'SubjectID','RawTrial','RawEpoch'}), keyX);
        rows = find(sel);
        if isempty(rows), continue; end

        W = nan(numel(rows), NG);
        for q = 1:numel(rows)
            r = rows(q);
            e = abs(D.Enc{r} - D.Ref{r});
            W(q,:) = warpEpoch(e, D.X.ExtStart(r), D.X.ExtEnd(r), nF, nE);
        end

        tr  = D.X.RawTrial(rows);
        pr  = D.X.Pressure(rows);
        uTr = unique(tr);
        TC  = nan(numel(uTr), NG); TP = nan(numel(uTr),1);
        for t = 1:numel(uTr)
            s = tr == uTr(t);
            TC(t,:) = mean(W(s,:), 1, 'omitnan');
            TP(t) = pr(find(s,1));
        end

        for c = 1:numel(LEVELS)
            s = TP == LEVELS(c);
            if any(s), curves(i,:,c) = mean(TC(s,:),1,'omitnan'); end
        end
        clear D
    end

    good = squeeze(~all(all(isnan(curves),2),3));
    curves = curves(good,:,:); subs = subs(good);
end


function W = warpEpoch(sig, extStart, extEnd, nF, nE)
% Warp one epoch onto a common grid, flexion and extension separately.
% sig is nChannels x nSamples or 1 x nSamples.
    if isvector(sig), sig = sig(:)'; end
    nCh = size(sig,1);
    W = nan(nCh, nF + nE);
    if any(isnan([extStart extEnd])) || extEnd > size(sig,2) || ...
       extStart < 2 || extEnd <= extStart + 1
        return
    end
    for ch = 1:nCh
        flx = sig(ch, 1:extStart);
        ext = sig(ch, extStart+1:extEnd);
        W(ch,:) = [interp1(1:numel(flx), flx, linspace(1,numel(flx),nF)), ...
                   interp1(1:numel(ext), ext, linspace(1,numel(ext),nE))];
    end
    if nCh == 1, W = W(:)'; end
end


function fr = flexFraction(Etbl)
% Median within subject, then across subjects, following the convention
% the EMG pipeline used.
    subs = unique(Etbl.SubjectID);
    m = nan(numel(subs),2);
    for i = 1:numel(subs)
        s = Etbl.SubjectID == subs(i);
        m(i,1) = median(Etbl.ExtStart(s) - Etbl.FlxStart(s), 'omitnan');
        m(i,2) = median(Etbl.ExtEnd(s)   - Etbl.ExtStart(s), 'omitnan');
    end
    fr = median(m(:,1)) / (median(m(:,1)) + median(m(:,2)));
end


function [clust, eta] = clusterTest(C, nPerm, alpha)
% Cluster-based permutation across the three conditions.
% C is nSubj x nSamp x nCond.
    Y = permute(C, [1 3 2]);                 % nSubj x nCond x nSamp
    [n, k, ns] = size(Y);
    Fcrit = finv(1-alpha, k-1, (n-1)*(k-1));

    [Fobs, eta] = rmF(Y);
    [mass, runs] = clusterMass(Fobs, Fcrit);

    nullMax = zeros(nPerm,1);
    for p = 1:nPerm
        Yp = Y;
        for i = 1:n, Yp(i,:,:) = Y(i, randperm(k), :); end
        nullMax(p) = max([clusterMass(rmF(Yp), Fcrit); 0]);
    end

    if isempty(mass)
        clust = table();
    else
        pc = arrayfun(@(x)(sum(nullMax >= x)+1)/(nPerm+1), mass);
        clust = table(runs(:,1)/ns*100, runs(:,2)/ns*100, mass(:), pc(:), ...
            'VariableNames', {'StartPct','EndPct','Mass','p'});
        clust = sortrows(clust,'Mass','descend');
    end
end


function [rep, rm] = rmAnovaReport(D, condNames, levels)
% One-way repeated measures ANOVA, with the sphericity rule applied
% rather than left to judgement. Greenhouse-Geisser when Mauchly rejects,
% uncorrected when it does not: applying the correction unconditionally
% is needlessly conservative, and omitting it when sphericity fails
% inflates the error rate. Recording the rule here means the choice is
% consistent across measures and visible to a reader.
    tbl = array2table(D, 'VariableNames', condNames);
    within = table(categorical(levels(:)), 'VariableNames', {'Pressure'});
    rm = fitrm(tbl, sprintf('%s,%s,%s ~ 1', condNames{:}), 'WithinDesign', within);

    rav = ranova(rm); mau = mauchly(rm); eps = epsilon(rm);
    rep.F = rav.F(1); rep.df1 = rav.DF(1); rep.df2 = rav.DF(2);
    rep.mauchlyW = mau.W(1); rep.mauchlyP = mau.pValue(1);
    rep.eps = eps.GreenhouseGeisser(1);
    rep.violated = mau.pValue(1) < 0.05;

    if rep.violated
        rep.p = rav.pValueGG(1);
        rep.line  = sprintf(['Mauchly W = %.3f, p = %.4f: sphericity violated. ' ...
            'F(%.2f, %.2f) = %.2f, p = %.3g, epsilon = %.3f'], ...
            rep.mauchlyW, rep.mauchlyP, rep.df1*rep.eps, rep.df2*rep.eps, ...
            rep.F, rep.p, rep.eps);
        rep.latex = sprintf(['$F(%.2f, %.2f) = %.2f$, $p %s$, ' ...
            'Greenhouse-Geisser corrected, $\\varepsilon = %.2f$'], ...
            rep.df1*rep.eps, rep.df2*rep.eps, rep.F, fmtP(rep.p), rep.eps);
    else
        rep.p = rav.pValue(1);
        rep.line  = sprintf(['Mauchly W = %.3f, p = %.4f: sphericity holds. ' ...
            'F(%d, %d) = %.2f, p = %.3g'], ...
            rep.mauchlyW, rep.mauchlyP, rep.df1, rep.df2, rep.F, rep.p);
        rep.latex = sprintf('$F(%d, %d) = %.2f$, $p %s$', ...
            rep.df1, rep.df2, rep.F, fmtP(rep.p));
    end

    [rep.friedP, ft] = friedman(D, 1, 'off');
    rep.friedChi2 = ft{2,5};
end


function reportClusters(name, clust, eta)
% Clusters alongside the effect-size trace. The cluster answers whether
% the conditions differ; the trace answers where the difference is large.
% They are reported together because a cluster spanning the whole cycle
% says nothing about location.
    n = numel(eta);
    half = round(n/2);
    fprintf('\n  %s\n', name);
    [pk, pi] = max(eta);
    fprintf('    peak eta2p = %.3f at %.1f%%, flexion mean %.3f, extension mean %.3f\n', ...
        pk, pi/n*100, mean(eta(1:half)), mean(eta(half+1:end)));
    if isempty(clust)
        fprintf('    no suprathreshold cluster\n'); return
    end
    sig = clust(clust.p < 0.05, :);
    if isempty(sig)
        fprintf('    no cluster survives permutation testing\n'); return
    end
    for k = 1:height(sig)
        fprintf('    %.1f to %.1f%% of cycle, p = %.4g\n', ...
            sig.StartPct(k), sig.EndPct(k), sig.p(k));
    end
end


function latexClusters(name, clust, eta)
    n = numel(eta); [pk, pi] = max(eta);
    if isempty(clust) || ~any(clust.p < 0.05)
        fprintf('%s: no significant cluster\n', name); return
    end
    sig = clust(clust.p < 0.05, :);
    parts = strings(height(sig),1);
    for k = 1:height(sig)
        parts(k) = sprintf('%.0f to %.0f\\%% ($p %s$)', ...
            sig.StartPct(k), sig.EndPct(k), fmtP(sig.p(k)));
    end
    fprintf('%s: %s; peak $\\eta^{2}_{p} = %.2f$ at %.0f\\%%\n', ...
        name, strjoin(parts, ', '), pk, pi/n*100);
end


function s = fmtP(p)
% Journal-style formatting: a bound rather than a spuriously precise
% figure below one in a thousand.
    if p < 0.001, s = '< 0.001'; else, s = sprintf('= %.3f', p); end
end


function [F, eta2p] = rmF(Y)
% Repeated measures F and partial eta squared at every sample.
% F decides significance; eta squared describes magnitude. They diverge:
% a small but highly consistent difference gives a large F because the
% error term is tiny, while eta squared stays modest.
    [n,k,~] = size(Y);
    gm = mean(Y,[1 2],'omitnan'); mc = mean(Y,1,'omitnan'); ms = mean(Y,2,'omitnan');
    ssCond  = n * sum((mc-gm).^2, 2);
    ssSubj  = k * sum((ms-gm).^2, 1);
    ssTotal = sum((Y-gm).^2, [1 2], 'omitnan');
    ssErr   = ssTotal - ssCond - ssSubj;
    F = squeeze((ssCond/(k-1)) ./ (ssErr/((n-1)*(k-1))))';
    F(~isfinite(F)) = 0;
    eta2p = squeeze(ssCond ./ (ssCond + ssErr))';
    eta2p(~isfinite(eta2p)) = 0;
end


function [mass, runs] = clusterMass(F, thresh)
    above = F > thresh;
    if ~any(above), mass = zeros(0,1); runs = zeros(0,2); return; end
    d = diff([0 above 0]);
    runs = [find(d==1)', (find(d==-1)-1)'];
    mass = arrayfun(@(a,b) sum(F(a:b)), runs(:,1), runs(:,2));
end


function [pHolm, dz] = holmPairwise(D, pairs, kind)
% Holm-corrected pairwise comparisons, with monotonicity enforced.
    nP = size(pairs,1);
    pRaw = nan(nP,1); dz = nan(nP,1); pHolm = nan(nP,1);
    for c = 1:nP
        d = D(:,pairs(c,2)) - D(:,pairs(c,1));
        d = d(~isnan(d));
        if strcmp(kind,'signrank')
            pRaw(c) = signrank(d, 0, 'method','exact');
        else
            [~, pRaw(c)] = ttest(d);
        end
        dz(c) = mean(d)/std(d);
    end
    [ps, ord] = sort(pRaw);
    pHolm(ord) = min(cummax(ps .* (nP:-1:1)'), 1);
end


function conditionCloud(ax, D, COL, nCond)
% Individual traces, per-condition points, and the group summary. The
% traces carry within-subject consistency, the summary carries magnitude.
% A white marker edge separates overlapping points that transparency
% alone cannot, which matters where a condition's distribution is tight.
    n = size(D,1);
    rng(7,'twister');
    jit = (rand(n,1)-0.5)*0.24;
    xc  = 1:nCond;  xcl = xc - 0.05;

    for i = 1:n
        plot(ax, xcl + jit(i), D(i,:), '-', ...
            'Color',[0.65 0.65 0.65 0.45],'LineWidth',0.4);
    end
    for c = 1:nCond
        scatter(ax, xcl(c)+jit, D(:,c), 12, ...
            'MarkerFaceColor',COL(c,:),'MarkerFaceAlpha',0.55, ...
            'MarkerEdgeColor','w','LineWidth',0.35);
    end
    errorbar(ax, xc+0.28, mean(D,1,'omitnan'), std(D,0,1,'omitnan'), 'k-', ...
        'LineWidth',0.9,'CapSize',2.5,'Marker','o','MarkerSize',3, ...
        'MarkerFaceColor','k','MarkerEdgeColor','k');
    xlim(ax,[0.55 nCond+0.65]);
end


function cyclePanel(axM, axS, C, eta, clust, S, COND, ylab, ttl, legendLoc, mainH, yTop)
% A cycle plot with its effect-size strip beneath.
%
% The panel takes a box because it carries event labels, which need
% something to sit on. The strip does not: it shares the x-axis and the
% reversal is already marked above it.
    ns = size(C,2);
    x  = linspace(0,100,ns);
    mu  = squeeze(mean(C,1,'omitnan'))';
    sem = squeeze(std(C,0,1,'omitnan'))'/sqrt(size(C,1));

    hold(axM,'on');
    for c = 1:3
        fill(axM,[x fliplr(x)],[mu(c,:)+sem(c,:), fliplr(mu(c,:)-sem(c,:))], ...
            S.col(c,:),'EdgeColor','none','FaceAlpha',0.30,'HandleVisibility','off');
    end
    for c = 1:3
        plot(axM, x, mu(c,:), 'Color', S.col(c,:), 'LineWidth', 0.9);
    end

    if nargin < 12 || isempty(yTop), yTop = max(mu(:)+sem(:))*1.10; end
    ylim(axM,[0 yTop]); xlim(axM,[0 100]);
    plot(axM,[50 50],[0 yTop],'--','Color',[0.35 0.35 0.35], ...
        'LineWidth',S.lw,'HandleVisibility','off');

    % Event labels sit above the box, so they never collide with a curve,
    % with a small gap so they do not touch the box edge.
    ev = {'FlxS', sprintf('FlxE\nExtS'), 'ExtE'};
    evx = [2 50 98];
    yLab = yTop + cm2data(axM, S.evGapCm);
    for e = 1:3
        text(axM, evx(e), yLab, ev{e}, 'Rotation',90, ...
            'HorizontalAlignment','left','VerticalAlignment','middle', ...
            'Clipping','off','FontName',S.font,'FontSize',S.fsEvent, ...
            'Color',[0.25 0.25 0.25]);
    end

    set(axM,'XTick',[0 50 100],'XTickLabel',[], ...
        'FontName',S.font,'FontSize',S.fsTick,'TickDir','in', ...
        'Box','on','LineWidth',S.lw);
    if ~isempty(ylab), ylabel(axM, ylab, 'FontName',S.font,'FontSize',S.fsLab); end
    if ~isempty(ttl), panelTitle(axM, ttl, S, mainH); end

    if ~isempty(legendLoc)
        lg = legend(axM, COND, 'Location', legendLoc, ...
            'FontName',S.font,'FontSize',S.fsTick);
        legend(axM,'boxoff'); lg.ItemTokenSize = [7 7];
    end
    hold(axM,'off');

    % ---- strip -------------------------------------------------------
    hold(axS,'on');
    plot(axS, x, eta, '-', 'Color',[0.25 0.25 0.25],'LineWidth',0.7);
    plot(axS, [0 100],[0.14 0.14],':','Color',[0.5 0.5 0.5],'LineWidth',S.lw);
    plot(axS, [50 50],[0 1],'--','Color',[0.35 0.35 0.35],'LineWidth',S.lw);
    if ~isempty(clust)
        sig = clust(clust.p < 0.05, :);
        for k = 1:height(sig)
            plot(axS,[sig.StartPct(k) sig.EndPct(k)],[-0.08 -0.08], ...
                'k-','LineWidth',1.8);
        end
    end
    ylim(axS,[-0.16 1]); xlim(axS,[0 100]);
    % Ticks at 0 and 1 only. The strip is half a centimetre tall, and a
    % third label crowds it without adding anything the reader needs.
    set(axS,'XTick',[0 50 100],'YTick',[0 1], ...
        'FontName',S.font,'FontSize',S.fsTick,'TickDir','in', ...
        'Box','off','LineWidth',S.lw);
    xlabel(axS,'Cycle (%)','FontName',S.font,'FontSize',S.fsLab);
    if ~isempty(ylab)
        ylabel(axS,'\eta^2_p','FontName',S.font,'FontSize',S.fsLab);
    end
    padLabels(axS, S);
    hold(axS,'off');
    padLabels(axM, S);
end


function combinedBracket(ax, xs, y, h, label, S, below)
% One rule spanning the given conditions with a tick beneath each, and a
% single label. Called by drawBrackets, either once across all three when
% the comparisons agree, or three times for a mixed result.
    x1 = min(xs); x2 = max(xs);
    plot(ax,[x1 x2],[y y],'k-','LineWidth',S.lw,'HandleVisibility','off');
    for i = 1:numel(xs)
        if below, yy = [y y+h]; else, yy = [y-h y]; end
        plot(ax,[xs(i) xs(i)], yy,'k-','LineWidth',S.lw,'HandleVisibility','off');
    end
    if below, va = 'top'; else, va = 'bottom'; end
    text(ax,(x1+x2)/2, y, label, 'HorizontalAlignment','center', ...
        'VerticalAlignment',va,'FontName',S.font,'FontSize',S.fsStar, ...
        'Interpreter','tex');
end


function drawBrackets(ax, p, anchor, S, below)
% One bracket if all three comparisons share a verdict, three if not.
%
% The combined form is only honest when every comparison says the same
% thing. Collapsing a mixed result into a single label would hide a real
% difference between the comparisons, so the shape follows the data
% rather than being fixed in advance.
%
% Worth checking p directly when the data changes: the tracking
% comparisons moved from all non-significant to one significant on the
% rebuild, and the figure alone will not draw attention to that.
%
% anchor is the data extreme the brackets sit beyond: the lowest point
% when below is true, the highest when it is false. Everything else is
% specified in centimetres and converted, so brackets in panels with
% different data ranges come out the same physical size.
    h    = cm2data(ax, S.brTickCm);
    step = cm2data(ax, S.brStepCm);
    gap  = cm2data(ax, S.brBaseCm);

    if below, base = anchor - gap; else, base = anchor + gap; end

    if all(p < 0.05) || all(p >= 0.05)
        if all(p < 0.05), lbl = pStars(max(p)); else, lbl = 'n.s.'; end
        combinedBracket(ax, 1:3, base, h, lbl, S, below);
        return
    end

    % Mixed. Adjacent pairs on the near level, the spanning comparison
    % beyond them so the rules do not cross. p follows [1 2; 1 3; 2 3].
    if below, second = base - step; else, second = base + step; end
    combinedBracket(ax, [1 2], base,   h, pStars(p(1)), S, below);
    combinedBracket(ax, [2 3], base,   h, pStars(p(3)), S, below);
    combinedBracket(ax, [1 3], second, h, pStars(p(2)), S, below);
end


function d = cm2data(ax, cm)
% Convert a vertical distance in centimetres to data units for this axis.
% Axes are positioned in centimetres, so the conversion is exact, and it
% keeps annotation sizes consistent across panels with different ranges.
% ylim must already be final when this is called.
    pos = get(ax, 'Position');
    yl  = ylim(ax);
    d   = cm / pos(4) * diff(yl);
end


function c = getCoef(mdl, name)
% Estimate, standard error and 95% interval for one fixed effect.
    r = find(strcmp(mdl.Coefficients.Name, name), 1);
    assert(~isempty(r), 'Coefficient %s not in the model.', name);
    ci = coefCI(mdl);
    c = struct('est', mdl.Coefficients.Estimate(r), ...
               'se',  mdl.Coefficients.SE(r), ...
               'p',   mdl.Coefficients.pValue(r), ...
               'lo',  ci(r,1), 'hi', ci(r,2));
end


function showPath(label, c, unit)
    fprintf('%-30s %+7.3f [%+.3f, %+.3f] %s  p = %.3g\n', ...
        label, c.est, c.lo, c.hi, unit, c.p);
end


function showMC(label, draws, unit)
% Median rather than mean, since the distribution of a product is skewed.
    fprintf('%-26s %+7.3f [%+.3f, %+.3f] %s\n', label, ...
        median(draws), prctile(draws,2.5), prctile(draws,97.5), unit);
end


function drawBox(ax, xc, yc, w, h, label, S)
% Corner radius in centimetres rather than through Curvature directly.
% Curvature takes a fraction of each side, not a radius, so one value
% gives an elliptical corner on any box that is not square on screen.
% Solving for equal physical radii gives the pair below.
    if S.boxRad > 0
        pos = get(ax,'Position');
        sx  = pos(3)/diff(xlim(ax));
        sy  = pos(4)/diff(ylim(ax));
        cur = min([2*S.boxRad/(w*sx), 2*S.boxRad/(h*sy)], 1);
    else
        cur = [0 0];
    end
    rectangle(ax,'Position',[xc-w/2, yc-h/2, w, h], ...
        'Curvature',cur,'FaceColor',S.boxFace, ...
        'EdgeColor',S.boxEdge,'LineWidth',0.8);
    text(ax, xc, yc, label, 'HorizontalAlignment','center', ...
        'VerticalAlignment','middle','FontName',S.font,'FontSize',S.fsBox);
end


function drawArrow(ax, from, to, S)
% Head sized in centimetres and converted back to data units, so it keeps
% its shape whatever the aspect ratio of the axes. Built directly in
% normalised data units on a panel wider than it is tall, a symmetric
% head comes out stretched.
    pos = get(ax,'Position');
    sx  = pos(3)/diff(xlim(ax));
    sy  = pos(4)/diff(ylim(ax));

    p1 = [from(1)*sx, from(2)*sy];
    p2 = [to(1)*sx,   to(2)*sy];
    d  = (p2 - p1) / norm(p2 - p1);
    perp = [-d(2), d(1)];
    base = p2 - S.headLen*d;

    plot(ax, [p1(1) base(1)]/sx, [p1(2) base(2)]/sy, '-', ...
        'Color', S.arrow, 'LineWidth', 0.8);
    tri = [p2; base + S.headWid*perp; base - S.headWid*perp];
    patch(ax, tri(:,1)/sx, tri(:,2)/sy, S.arrow, 'EdgeColor','none');
end


function pathLabel(ax, x, y, str, S)
    text(ax, x, y, str, 'HorizontalAlignment','center', ...
        'VerticalAlignment','middle','FontName',S.font,'FontSize',S.fsPath);
end


function s = pStars(p)
% TeX asterisks rather than the keyboard character. MATLAB renders \ast
% centred on the line, like the star in a typeset paper; a plain * sits
% high and reads as a footnote marker.
    if     p < 0.001, s = '\ast\ast\ast';
    elseif p < 0.01,  s = '\ast\ast';
    elseif p < 0.05,  s = '\ast';
    else,             s = 'n.s.';
    end
end


function panelTitle(ax, str, S, axH)
    th = title(ax, str, 'FontName',S.font,'FontSize',S.fsLab,'FontWeight','normal');
    th.Units = 'centimeters';
    th.Position(2) = axH + S.titleOff;
end


function padLabels(ax, S)
% Widen the gap between axis labels and tick labels. MATLAB places each
% label tight against the longest tick label, and that length varies with
% the number of digits, so panels drift out of alignment without this.
    ylh = get(ax,'YLabel');
    if ~isempty(get(ylh,'String'))
        set(ylh,'Units','centimeters');
        p = get(ylh,'Position'); set(ylh,'Position',[p(1)-S.ylabPad p(2) p(3)]);
    end
    xlh = get(ax,'XLabel');
    if ~isempty(get(xlh,'String'))
        set(xlh,'Units','centimeters');
        p = get(xlh,'Position'); set(xlh,'Position',[p(1) p(2)-S.xlabPad p(3)]);
    end
end


function letterAt(fig, x, y, str, S)
    annotation(fig,'textbox',[max(x,0.002) y 0.05 0.05],'String',str, ...
        'FontName',S.font,'FontSize',S.fsPanel,'FontWeight','bold', ...
        'EdgeColor','none','HorizontalAlignment','left', ...
        'VerticalAlignment','middle');
end
