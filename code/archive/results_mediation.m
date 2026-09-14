%% RESULTS_MEDIATION
%  How much of the pressure effect on perceived difficulty passes through
%  peripheral effort and through task performance.
%
%  MODEL. Two parallel mediators, the effort index and tracking error,
%  with a by-subject random intercept on every path. Trial number enters
%  as a covariate throughout: it has a large effect on tracking error
%  (about -0.45 degrees per SD, roughly three times the pressure effect),
%  and leaving it in the residual of a mediator widens every interval.
%
%  PRESSURE CODING. Ordinal, 0 / 1 / 2, as primary. The hypothesis is
%  that demand grades difficulty, and everything else in the paper
%  supports grading rather than mere difference, so the model should test
%  the ordered prediction rather than remain agnostic about it. It also
%  gives one coefficient per path instead of two, which is what makes the
%  diagram readable. The equal-step assumption is checked by the
%  categorical model in section 6, which is reported as a supplementary
%  sensitivity analysis.
%
%  Note this is not the same as using raw bar values. Pressure runs 1, 3,
%  6, which are not equally spaced, while the responses are close to
%  equally spaced (effort rises 1.00 then 1.06; ratings 2.42 then 2.78).
%  Coding 0 / 1 / 2 fits what the data do; coding 1 / 3 / 6 would impose a
%  linearity in pressure that the muscles do not show.
%
%  WITHIN AND BETWEEN. Mediators are split into a person-mean part and a
%  deviation from it. In a within-subject design the a and b paths can
%  differ between the two levels, and a model that ignores the split can
%  report an indirect effect that exists at neither. The within-subject
%  coefficient is the one the mediation is about.
%
%  INTERVALS. Monte Carlo rather than bootstrap. The indirect effect is a
%  product of two estimates, and products are skewed, so a symmetric
%  interval is wrong at both ends. Drawing each coefficient from the
%  sampling distribution its standard error already implies, forming the
%  product, and taking percentiles reproduces the correct shape. The
%  bootstrap would do the same but requires resampling participants, and
%  with thirteen of them many resamples would contain only nine or ten
%  distinct people.
%
%  SAMPLE. The effort index requires EMG, so this runs on 13 of the 14
%  participants.
%
%  A LIMIT WORTH STATING IN THE DISCUSSION. This estimates how much of
%  the effect passes through the mediators as measured. The effort index
%  is integrated EMG, which measures efferent drive, not afferent
%  feedback. Eliminating that route does not eliminate a peripheral
%  origin: group III and IV afferent signalling is unmeasured here.
%
%  Requires: Statistics and Machine Learning Toolbox.
% =====================================================================

clc; clear;

%% 0. Configuration
% ---------------------------------------------------------------------
data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
out_path  = [data_path, '7_Master_Tables\'];

LEVELS     = [1 3 6];
COND_NAMES = {'Low','Medium','High'};

N_MC     = 20000;      % Monte Carlo draws
RNG_SEED = 21;

load(fullfile(out_path,'behaviour_table.mat'), 'T');


%% 1. Prepare the analysis table
% ---------------------------------------------------------------------
% Complete cases only: a mediation needs the outcome and both mediators
% on the same trial, so a trial missing any one of them cannot contribute
% to any path. Dropping them here rather than letting each model drop its
% own keeps every path fitted on one set of trials, which is what makes
% the decomposition into direct and indirect coherent.

ok = ~isnan(T.Score) & ~isnan(T.Error) & ~isnan(T.EffortIndex) & ...
     ismember(T.Pressure, LEVELS);

D = table();
D.Subject = categorical(T.SubjectID(ok));
D.Y       = T.Score(ok);                     % perceived difficulty
D.M1      = T.EffortIndex(ok);               % effort index
D.M2      = T.Error(ok);                     % tracking error, deg
D.Xord    = double(categorical(T.Pressure(ok), LEVELS)) - 1;   % 0, 1, 2
D.Xcat    = categorical(T.Pressure(ok), LEVELS, COND_NAMES);
D.Xcat    = reordercats(D.Xcat, COND_NAMES);
D.Trial   = T.RawTrial(ok);

fprintf('Mediation sample: %d trials, %d participants\n', ...
    height(D), numel(unique(D.Subject)));
if numel(unique(D.Subject)) < numel(unique(T.SubjectID))
    miss = setdiff(unique(T.SubjectID), double(string(unique(D.Subject))));
    fprintf('Excluded for missing EMG: %s\n', mat2str(miss(:)'));
end


%% 2. Within and between decomposition
% ---------------------------------------------------------------------
% Each mediator is split into that participant's own mean and their
% trial-by-trial deviation from it. Both go into the outcome model. The
% deviation carries the within-subject association, which is what the
% mediation is about; the person mean absorbs the between-subject one,
% which would otherwise contaminate it.
%
% Trial number is standardised so its coefficient reads per SD, and the
% pressure code is left uncentred so that zero means the Low condition
% and the intercept stays interpretable.

subs = unique(D.Subject);
D.M1w = nan(height(D),1); D.M1b = nan(height(D),1);
D.M2w = nan(height(D),1); D.M2b = nan(height(D),1);

for i = 1:numel(subs)
    r = D.Subject == subs(i);
    D.M1b(r) = mean(D.M1(r));  D.M1w(r) = D.M1(r) - mean(D.M1(r));
    D.M2b(r) = mean(D.M2(r));  D.M2w(r) = D.M2(r) - mean(D.M2(r));
end
D.M1b = D.M1b - mean(D.M1b);        % centred, so the intercept is the
D.M2b = D.M2b - mean(D.M2b);        % average participant
D.Tz  = (D.Trial - mean(D.Trial)) / std(D.Trial);

% A between-subject term only exists if participants differ on that
% mediator. The effort index is normalised per subject, each muscle
% divided by that participant's own mean, so every participant's mean
% effort index is exactly four by construction and the between term is a
% column of zeros. Including it makes the design matrix rank deficient.
%
% This is worth stating rather than silently dropping: the normalisation
% removes all between-subject variance in effort, so the mediation cannot
% speak to whether people who work harder overall feel the task as
% harder. Only the within-subject path is estimable, which is the one the
% claim rests on. Tracking error is not normalised, so its between term
% survives and is estimated.
betweenTerms = {};
for v = {'M1b','M2b'}
    if std(D.(v{1})) > 1e-10
        betweenTerms{end+1} = v{1}; %#ok<SAGROW>
    else
        fprintf(['\nNote: %s has no variance and is omitted. The mediator ' ...
                 'is normalised within subject, so participants do not ' ...
                 'differ on it.\n'], v{1});
    end
end


%% 3. Fit the paths
% ---------------------------------------------------------------------
%   a1, a2   pressure -> each mediator
%   b1, b2   each mediator -> difficulty, adjusting for the other and
%            for pressure
%   c        total effect of pressure on difficulty
%   cPrime   direct effect, pressure adjusted for both mediators

mdlA1 = fitlme(D, 'M1 ~ Xord + Tz + (1|Subject)');
mdlA2 = fitlme(D, 'M2 ~ Xord + Tz + (1|Subject)');
mdlC  = fitlme(D, 'Y  ~ Xord + Tz + (1|Subject)');
fB = ['Y ~ Xord + M1w + M2w + Tz'];
for v = betweenTerms, fB = [fB ' + ' v{1}]; end %#ok<AGROW>
mdlB = fitlme(D, [fB ' + (1|Subject)']);

a1 = getCoef(mdlA1, 'Xord');
a2 = getCoef(mdlA2, 'Xord');
b1 = getCoef(mdlB,  'M1w');
b2 = getCoef(mdlB,  'M2w');
cT = getCoef(mdlC,  'Xord');
cP = getCoef(mdlB,  'Xord');

fprintf('\n=== Paths (per level of pressure) ===\n');
showPath('a1  pressure -> effort',        a1, '');
showPath('a2  pressure -> error',         a2, 'deg');
showPath('b1  effort -> difficulty',      b1, '');
showPath('b2  error -> difficulty',       b2, '');
showPath('c   total',                     cT, 'rating points');
showPath('c'' direct',                    cP, 'rating points');

% Between-subject coefficients, where they exist. Reported because the
% contrast with the within-subject path is informative in itself: a
% mediator that predicts difficulty across people but not across a
% person's own trials is not carrying the effect.
if ~isempty(betweenTerms)
    fprintf('\nBetween-subject mediator coefficients (not the mediation path):\n');
    for v = betweenTerms
        showPath(sprintf('    %s', v{1}), getCoef(mdlB, v{1}), '');
    end
end


%% 4. Indirect effects, by Monte Carlo
% ---------------------------------------------------------------------
% a and b come from separate models fitted to the same data, so they are
% drawn independently. Were both from one model, the draw would have to
% use its covariance matrix.

rng(RNG_SEED, 'twister');
a1d = a1.est + a1.se*randn(N_MC,1);
a2d = a2.est + a2.se*randn(N_MC,1);
b1d = b1.est + b1.se*randn(N_MC,1);
b2d = b2.est + b2.se*randn(N_MC,1);
cPd = cP.est + cP.se*randn(N_MC,1);

ind1 = a1d .* b1d;                  % through effort
ind2 = a2d .* b2d;                  % through tracking error
tot  = ind1 + ind2 + cPd;           % decomposed total

fprintf('\n=== Indirect effects (rating points per level) ===\n');
showMC('through effort',         ind1);
showMC('through tracking error', ind2);
showMC('direct',                 cPd);
showMC('total (decomposed)',     tot);
fprintf('total (fitted separately): %.3f [%.3f, %.3f]\n', ...
    cT.est, cT.lo, cT.hi);

% Proportions. A ratio of two uncertain quantities is worse behaved than
% their product, so these get intervals rather than point estimates. The
% denominator is the decomposed total from the same draw, which keeps
% numerator and denominator internally consistent.
fprintf('\n=== Proportion of the total effect ===\n');
showMC('through effort',         100*ind1./tot, '%%');
showMC('through tracking error', 100*ind2./tot, '%%');
showMC('direct',                 100*cPd ./tot, '%%');


%% 5. Sensitivity: does the equal-step assumption hold?
% ---------------------------------------------------------------------
% The ordinal coding treats Low to Medium as the same increment as Medium
% to High. The categorical model estimates the two separately, so
% comparing them tests the assumption rather than asserting it. Reported
% as a supplementary analysis.

mdlA1c = fitlme(D, 'M1 ~ Xcat + Tz + (1|Subject)');
mdlA2c = fitlme(D, 'M2 ~ Xcat + Tz + (1|Subject)');
mdlCc  = fitlme(D, 'Y  ~ Xcat + Tz + (1|Subject)');
fBc = ['Y ~ Xcat + M1w + M2w + Tz'];
for v = betweenTerms, fBc = [fBc ' + ' v{1}]; end %#ok<AGROW>
mdlBc = fitlme(D, [fBc ' + (1|Subject)']);

fprintf('\n=== Categorical sensitivity analysis ===\n');
for nm = {'Xcat_Medium','Xcat_High'}
    fprintf('%s:\n', nm{1});
    showPath('    -> effort',     getCoef(mdlA1c, nm{1}), '');
    showPath('    -> error',      getCoef(mdlA2c, nm{1}), 'deg');
    showPath('    total',         getCoef(mdlCc,  nm{1}), '');
    showPath('    direct',        getCoef(mdlBc,  nm{1}), '');
end

% If the High contrast is close to twice the Medium contrast on each
% path, the equal-step coding is fair. A marked departure means the
% ordinal model is smoothing over something real and the categorical
% version should lead instead.
mMed = getCoef(mdlCc,'Xcat_Medium'); mHigh = getCoef(mdlCc,'Xcat_High');
fprintf('\nTotal effect: High contrast is %.2f times the Medium contrast\n', ...
    mHigh.est / mMed.est);
fprintf('(2.00 would mean exactly equal steps)\n');


%% 6. Values for the diagram and the manuscript
% ---------------------------------------------------------------------
fprintf('\n%s\nPASTE-READY\n%s\n\n', repmat('=',1,64), repmat('=',1,64));

fprintf('a1 (pressure to effort):        $%+.2f$ [%.2f, %.2f]\n', a1.est, a1.lo, a1.hi);
fprintf('a2 (pressure to error):         $%+.2f$ [%.2f, %.2f]\n', a2.est, a2.lo, a2.hi);
fprintf('b1 (effort to difficulty):      $%+.2f$ [%.2f, %.2f]\n', b1.est, b1.lo, b1.hi);
fprintf('b2 (error to difficulty):       $%+.3f$ [%.3f, %.3f]\n', b2.est, b2.lo, b2.hi);
fprintf('c  (total):                     $%+.2f$ [%.2f, %.2f]\n', cT.est, cT.lo, cT.hi);
fprintf('c'' (direct):                    $%+.2f$ [%.2f, %.2f]\n', cP.est, cP.lo, cP.hi);
fprintf('\nMediated via effort: %.0f%% [%.0f, %.0f]\n', ...
    median(100*ind1./tot), prctile(100*ind1./tot,2.5), prctile(100*ind1./tot,97.5));
fprintf('Mediated via error:  %.0f%% [%.0f, %.0f]\n', ...
    median(100*ind2./tot), prctile(100*ind2./tot,2.5), prctile(100*ind2./tot,97.5));
fprintf('Direct:              %.0f%% [%.0f, %.0f]\n', ...
    median(100*cPd./tot),  prctile(100*cPd./tot,2.5),  prctile(100*cPd./tot,97.5));

med = struct('a1',a1,'a2',a2,'b1',b1,'b2',b2,'c',cT,'cPrime',cP, ...
             'ind1',ind1,'ind2',ind2,'direct',cPd,'total',tot, ...
             'nTrials',height(D),'nSubjects',numel(subs));
save(fullfile(out_path,'mediation_results.mat'), 'med');
fprintf('\nSaved mediation_results.mat\n');


%% Local functions
% ---------------------------------------------------------------------
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
    fprintf('%-32s %+7.3f [%+.3f, %+.3f] %s  p = %.3g\n', ...
        label, c.est, c.lo, c.hi, unit, c.p);
end

function showMC(label, draws, unit)
% Median and percentile interval from the Monte Carlo draws. The median
% rather than the mean, since the distribution of a product is skewed.
    if nargin < 3, unit = ''; end
    fprintf('%-26s %+7.3f [%+.3f, %+.3f] %s\n', label, ...
        median(draws), prctile(draws,2.5), prctile(draws,97.5), unit);
end
