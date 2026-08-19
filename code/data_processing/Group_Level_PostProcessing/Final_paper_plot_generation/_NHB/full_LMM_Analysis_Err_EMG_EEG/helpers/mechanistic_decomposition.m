function mech = mechanistic_decomposition(ME, MErr, M3, Mtot, nMC)
% Mechanistic decomposition for categorical Pressure (baseline = 1),
% with mediators EffortIndex and Error predicting Score.
%
% Inputs:
%   ME   : fitlme for EffortIndex ~ Pressure + (1 + Pressure | Subject)
%   MErr : fitlme for Error       ~ Pressure + (1 + Pressure | Subject)
%   M3   : fitlme for Score       ~ Pressure + Error + EffortIndex + (1 + Pressure | Subject)
%   Mtot : fitlme for Score       ~ Pressure + (1 + Pressure | Subject)   (optional, can be [])
%   nMC  : Monte Carlo samples, e.g., 100000
%
% Output struct mech with effects and CIs.

if nargin < 5, nMC = 100000; end

% Helper to get coefficient mean & SE by name
getCoef = @(M, name) deal( ...
    M.Coefficients.Estimate(strcmp(M.Coefficients.Name, name)), ...
    M.Coefficients.SE(strcmp(M.Coefficients.Name, name)) );

% --- a-paths (Pressure -> mediators)
[aE3, se_aE3] = getCoef(ME,   'Pressure_cat_3');
[aE6, se_aE6] = getCoef(ME,   'Pressure_cat_6');

[aR3, se_aR3] = getCoef(MErr, 'Pressure_cat_3'); % R = Error mediator
[aR6, se_aR6] = getCoef(MErr, 'Pressure_cat_6');

% --- b-paths (mediators -> Score)
[bEff, se_bEff] = getCoef(M3, 'EffortIndex');
[bErr, se_bErr] = getCoef(M3, 'Error');

% --- direct effects c' (Pressure -> Score | mediators)
[cP3, se_cP3] = getCoef(M3, 'Pressure_cat_3');
[cP6, se_cP6] = getCoef(M3, 'Pressure_cat_6');

% --- total effects c (Pressure -> Score) [optional]
hasTotal = ~isempty(Mtot);
if hasTotal
    [tP3, se_tP3] = getCoef(Mtot, 'Pressure_cat_3');
    [tP6, se_tP6] = getCoef(Mtot, 'Pressure_cat_6');
else
    tP3 = NaN; se_tP3 = NaN;
    tP6 = NaN; se_tP6 = NaN;
end

% Monte Carlo draws (independence assumption across models; acceptable and common)
rng(0);
draw = @(mu,se) mu + se.*randn(nMC,1);

aE3s = draw(aE3, se_aE3); aE6s = draw(aE6, se_aE6);
aR3s = draw(aR3, se_aR3); aR6s = draw(aR6, se_aR6);

bEffs = draw(bEff, se_bEff);
bErrs = draw(bErr, se_bErr);

% Indirect effects
IE_Eff_3 = aE3s .* bEffs;
IE_Eff_6 = aE6s .* bEffs;

IE_Err_3 = aR3s .* bErrs;
IE_Err_6 = aR6s .* bErrs;

% Summaries
ci = @(x) prctile(x, [2.5 50 97.5]);

mech.IE_Eff_3 = ci(IE_Eff_3);
mech.IE_Eff_6 = ci(IE_Eff_6);
mech.IE_Err_3 = ci(IE_Err_3);
mech.IE_Err_6 = ci(IE_Err_6);

mech.Direct_3 = [cP3, cP3-1.96*se_cP3, cP3+1.96*se_cP3];
mech.Direct_6 = [cP6, cP6-1.96*se_cP6, cP6+1.96*se_cP6];

mech.Total_3  = [tP3, tP3-1.96*se_tP3, tP3+1.96*se_tP3];
mech.Total_6  = [tP6, tP6-1.96*se_tP6, tP6+1.96*se_tP6];

% Optional proportion mediated (requires Mtot)
if hasTotal
    % Use MC for proportion mediated: (IEeff + IEerr) / TE
    tP3s = draw(tP3, se_tP3); tP6s = draw(tP6, se_tP6);
    PM3 = (IE_Eff_3 + IE_Err_3) ./ tP3s;
    PM6 = (IE_Eff_6 + IE_Err_6) ./ tP6s;

    % Out of the total pressure effect on difficulty, 
    % what fraction is via effort vs via error:
    PropEff_3 = IE_Eff_3 ./ tP3s;
    PropErr_3 = IE_Err_3 ./ tP3s;
    
    PropEff_6 = IE_Eff_6 ./ tP6s;
    PropErr_6 = IE_Err_6 ./ tP6s;
    
    mech.PropEffort_3 = ci(PropEff_3);
    mech.PropError_3  = ci(PropErr_3);
    
    mech.PropEffort_6 = ci(PropEff_6);
    mech.PropError_6  = ci(PropErr_6);

    mech.PropMediated_3 = ci(PM3);
    mech.PropMediated_6 = ci(PM6);
end
end
