%% =========================================================================
% FULL LMM PIPELINE (Behavior + EEG) — EEG INDEX PER TRIAL
%
% EEG features:
%   - Bands: theta/mu/beta
%   - Clusters: L_M1 and R_M1
%   - Cycle: whole cycle (0–100%)
%   - Log-feature definition: OPTION 2
%       1) average normalized TF ratio over (band × full_cycle)
%       2) apply 10*log10 to that mean
%
% EEG index:
%   - Within each subject: z-score each available EEG feature column
%   - Per trial: EEGIndex = mean of all z-scored EEG features (omit NaNs)
%
% Missing clusters:
%   - If a subject is not present in a cluster, loader should return empty table
%   - Merge keeps behavior rows; EEG features stay NaN for those missing subjects/trials
%
% Requirements: Statistics and Machine Learning Toolbox (fitlme, mafdr)


%% =========================================================================

clear; clc;

main_project_path = 'D:\Morteza\MyProjects\ANSYMB2024\';
addpath(genpath([main_project_path, 'Code']));

data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
icatimef_path = [data_path, '5_single-subject-EEG-analysis\' ...
    'timewarp_test\Epoched_data'];
Code_path = 'D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab\data_processing\';
NHB_path = [Code_path, 'Group_Level_PostProcessing\' ...
    'Final_paper_plot_generation\_NHB\'];
behavior_path = [NHB_path, 'behavioural_results'];
eeg_path = [NHB_path, 'manual_TF_outlier_removal'];

current_path = [NHB_path, 'full_LMM_Analysis_Err_EMG_EEG'];



%%  LOAD BEHAVIOR TABLE ===================================================
allBeh = load(fullfile(behavior_path, "behavior_table.mat"));
allBeh = allBeh.T;


%%  LOAD EEG FEATURE ======================================================
eegfeatures = load(fullfile(eeg_path, "EEG_features.mat"));
eegfeatures = eegfeatures.EEG_features;


%%  MERGE BEHAVIOR + EEG FEATURES =========================================
T = create_the_main_table(allBeh, eegfeatures);



%% ===================================================
%   Main SETTINGS
%  ===================================================

% add categorical Sujects
T.Subject_cat = categorical(T.Subject);
T.Pressure_cat = categorical(T.Pressure);

difficultyVar = 'Score';
emgVar        = 'EffortIndex';
subjectVar    = 'Subject_cat';
pressureVar   = 'Pressure';

% List of EEG feature for per-subject z-score transform
eegVars = ...
    {...
    'Alpha_LM1','Beta_LM1', ...
    'Alpha_Flx_LM1', 'Alpha_Ext_LM1', 'Beta_Flx_LM1', 'Beta_Ext_LM1', ...
    'Alpha_RM1','Beta_RM1', ...
    'Alpha_Flx_RM1', 'Alpha_Ext_RM1', 'Beta_Flx_RM1', 'Beta_Ext_RM1', ...
    'Alpha_roi_LM1','Beta_roi_LM1', ...
    'Alpha_Flx_roi_LM1', 'Alpha_Ext_roi_LM1', 'Beta_Flx_roi_LM1', 'Beta_Ext_roi_LM1', ...
    'Alpha_roi_RM1','Beta_roi_RM1', ...
    'Alpha_Flx_roi_RM1', 'Alpha_Ext_roi_RM1', 'Beta_Flx_roi_RM1', 'Beta_Ext_roi_RM1', ...
    }; 

% EEG is already in dB (ERSP)
doWithinSubjectZ_EEG   = true;   
doWithinSubjectZ_EMG   = true;   


% Fit method:
%  - Use 'ML' when comparing models with different fixed effects (needed for compare()).
fitMethodForCompare = 'ML';
% Random effects structure (start simple; upgrade if stable)
useRandomSlopePressure = false;   % false: (Pressure|Subject); true: (1|Subject)
useRandomSlopeEMG      = false;   % usually avoid multiple random slopes unless enough data



%% -------------------------
%  Within-subject normalization (ERSP already in dB)
%  -------------------------
tbl0 = T;
% EMG
if doWithinSubjectZ_EMG
    tbl0 = withinSubjectZ(tbl0, subjectVar, emgVar);
end

% EEG (already dB ERSP)
for k = 1:numel(eegVars)
    v = eegVars{k};
    if ~ismember(v, tbl0.Properties.VariableNames), continue; end

    if doWithinSubjectZ_EEG
        tbl0 = withinSubjectZ(tbl0, subjectVar, v);
    end
end


% add EEGIndex from the z-scores EEG features
tbl0.EEGIndex = mean([tbl0.Alpha_LM1, tbl0.Beta_LM1, ...
    tbl0.Alpha_RM1, tbl0.Beta_RM1], 2, 'omitnan');
tbl0.EEGIndex_roi = mean([tbl0.Alpha_roi_LM1, tbl0.Beta_roi_LM1, ...
    tbl0.Alpha_roi_RM1, tbl0.Beta_roi_RM1], 2, 'omitnan');


%% ============================================================
%  1) BEHAVIOUR MODEL ON FULL COHORT
%  ============================================================

%% 1.1) Score ~ 1 + Pressure_cat + (1 + Pressure | Subject_cat)
% T_clean is the same tbl but some rows are removed. subject level outlier 
% removal on score values per condtion was applied on tbl.
[T_clean, M1] = score_pressure_model(tbl0); 
disp(M1);

disp('ANOVA (fixed effects):');
disp(anova(M1,'DFMethod','satterthwaite'));


%% 1.2) Score ~ 1 + Pressure_cat + Error + (1 + Pressure | Subject_cat)
M2 = score_pressure_err_model(T_clean)
disp(M2);

disp('ANOVA (fixed effects):');
disp(anova(M1,'DFMethod','satterthwaite'));


%% 1.3) Score ~ 1 + Pressure_cat + Error + EffortIndex + 
%               (1 + Pressure | Subject_cat)
M3 = fitlme(T_clean, ...
    'Score ~ 1 + Pressure_cat + Error + EffortIndex + (1 + Pressure_cat | Subject_cat)', ...
    'FitMethod','ML');

compare(M2, M3)



%% Mechanistic analysis
% Effort mediator model (a₁ paths)
ME = fitlme(T_clean, ...
 'EffortIndex ~ 1 + Pressure_cat + (1 + Pressure_cat | Subject_cat)', ...
 'FitMethod','ML');

% Error mediator model (a₂ paths)
MErr = fitlme(T_clean, ...
 'Error ~ 1 + Pressure_cat + (1 + Pressure_cat | Subject_cat)', ...
 'FitMethod','ML');

% "total effect" (c paths, without mediators)
Mtot = fitlme(T_clean, ...
 'Score ~ 1 + Pressure_cat + (1 + Pressure_cat | Subject_cat)', ...
 'FitMethod','ML');


mech = mechanistic_decomposition(ME, MErr, M3, Mtot, 100000);
disp(mech)

% plot the results of this part
M3 = score_pressure_effort_with_mediation_plot(T_clean, mech)





%% ============================================================
%  2) EEG-ADDED MODELS (cluster-specific subsets)
%     For each EEG feature:
%        - restrict to rows where EEG is observed (not NaN)
%        - fit baseline: Score ~ Pressure + EMG + (RE)
%        - fit eeg-added: Score ~ Pressure + EMG + EEG + (RE)
%        - compare with likelihood ratio test (ML fits)
% ============================================================
% List EEG feature columns you want to test (one per brain cluster)
Alpha_LM1 = {'Alpha_LM1', 'Alpha_Flx_LM1', 'Alpha_Ext_LM1', ...
    'Alpha_LM1_z', 'Alpha_Flx_LM1_z', 'Alpha_Ext_LM1_z'};
Alpha_roi_LM1 = {'Alpha_roi_LM1', 'Alpha_Flx_roi_LM1', 'Alpha_Ext_roi_LM1', ...
    'Alpha_roi_LM1_z', 'Alpha_Flx_roi_LM1_z', 'Alpha_Ext_roi_LM1_z'};
Beta_LM1 = {'Beta_LM1', 'Beta_Flx_LM1', 'Beta_Ext_LM1', ...
    'Beta_LM1_z', 'Beta_Flx_LM1_z', 'Beta_Ext_LM1_z'};
Beta_roi_LM1 = {'Beta_roi_LM1', 'Beta_Flx_roi_LM1', 'Beta_Ext_roi_LM1', ...
    'Beta_roi_LM1_z', 'Beta_Flx_roi_LM1_z', 'Beta_Ext_roi_LM1_z'};

Alpha_RM1 = {'Alpha_RM1', 'Alpha_Flx_RM1', 'Alpha_Ext_RM1', ...
    'Alpha_RM1_z', 'Alpha_Flx_RM1_z', 'Alpha_Ext_RM1_z'};
Alpha_roi_RM1 = {'Alpha_roi_RM1', 'Alpha_Flx_roi_RM1', 'Alpha_Ext_roi_RM1', ...
    'Alpha_roi_RM1_z', 'Alpha_Flx_roi_RM1_z', 'Alpha_Ext_roi_RM1_z'};
Beta_RM1 = {'Beta_RM1', 'Beta_Flx_RM1', 'Beta_Ext_RM1', ...
    'Beta_RM1_z', 'Beta_Flx_RM1_z', 'Beta_Ext_RM1_z'};
Beta_roi_RM1 = {'Beta_roi_RM1', 'Beta_Flx_roi_RM1', 'Beta_Ext_roi_RM1', ...
    'Beta_roi_RM1_z', 'Beta_Flx_roi_RM1_z', 'Beta_Ext_roi_RM1_z'};

EEGIndex = {'EEGIndex', 'EEGIndex_roi'};

eegVars = [Alpha_LM1, Alpha_roi_LM1, Beta_LM1, Beta_roi_LM1, ...
    Alpha_RM1, Alpha_roi_RM1, Beta_RM1, Beta_roi_RM1, ...
    EEGIndex];


eegVar_all = [];
Estimate_all = [];
SE_all = [];
tStat_all = [];
pValue_all = [];
LowerCI_all = [];
UpperCI_all = [];

for k = 1:numel(eegVars)
    eegVar = eegVars{k};

    disp(eegVar)
    
    % Subset where EEG is available
    subMask = ~isnan(T_clean.(eegVar));
    tblSub  = T_clean(subMask,:);

    
    % Baseline behavioural model on SAME subset (for fair comparison)
    baseFormula = ...
        'Score ~ 1 + Pressure_cat + Error + EffortIndex + (1 + Pressure_cat | Subject_cat)';  
    baseLME = fitlme(tblSub, baseFormula, 'FitMethod', 'ML');

    % EEG-added model (fixed effects differ => compare() is valid under ML)
    eegFormula = sprintf(['Score ~ 1 + Pressure_cat + Error + ', ...
        'EffortIndex + %s + (1 + Pressure_cat | Subject_cat)'], eegVar);
    % eegFormula = sprintf(['Score ~ 1 + %s + (1 + Pressure_cat | Subject_cat)'], eegVar);
    eegLME  = fitlme(tblSub, eegFormula, 'FitMethod', 'ML');

    

   

    % Extract EEG coefficient
    coefTbl = eegLME.Coefficients;
    eegRow = coefTbl(strcmp(coefTbl.Name, eegVar),:);

    eegVar_all = cat(1, eegVar_all, {eegVar});
    Estimate_all = cat(1, Estimate_all, eegRow.Estimate);
    SE_all = cat(1, SE_all, eegRow.SE);
    tStat_all = cat(1, tStat_all, eegRow.tStat);
    pValue_all = cat(1, pValue_all, eegRow.pValue);
    LowerCI_all = cat(1, LowerCI_all, eegRow.Lower);
    UpperCI_all = cat(1, UpperCI_all, eegRow.Upper);
    


end


eegVar_table = table(eegVar_all, Estimate_all, SE_all, tStat_all, ...
    pValue_all, LowerCI_all, UpperCI_all, 'VariableNames', ...
    {'eegVar', 'Estimate', 'SE', 'tStat', 'pValue', 'LowerCI', 'UpperCI'});


%%
eegVars_plot = {Alpha_LM1, Alpha_roi_LM1, Beta_LM1, Beta_roi_LM1, ...
    Alpha_RM1, Alpha_roi_RM1, Beta_RM1, Beta_roi_RM1, ...
    EEGIndex};
figure(); hold on; 
set(gcf, 'Position', [1600, 400, 1400, 400])
CC = lines(10);

cumsum_x = cumsum(cellfun(@(x) length(x), eegVars_plot, 'UniformOutput', true));

plot(1:cumsum_x(1), eegVar_table.Estimate(1:cumsum_x(1)), ...
    'Marker', 'o', 'LineStyle', 'none', 'MarkerFaceColor', CC(1, :));
xline(cumsum_x(1)+0.5, 'LineWidth', 0.5, 'LineStyle', '--')
for i = 1:size(eegVars_plot, 2)-1
    x_start = cumsum_x(i)+1;
    plot(x_start:cumsum_x(i+1), eegVar_table.Estimate(x_start:cumsum_x(i+1)), ...
        'Marker', 'o', 'LineStyle', 'none', 'MarkerFaceColor', CC(i+1, :));
    xline(cumsum_x(i+1)+0.5, 'LineWidth', 0.5, 'LineStyle', '--')
end


yline(0.04, 'LineWidth', 1, 'LineStyle', '--')
yline(0, 'LineWidth', 2)
yline(-0.04, 'LineWidth', 1, 'LineStyle', '--')
xlabels = cellfun(@(x) strrep(x, '_', ' '), eegVar_table.eegVar, ...
    'UniformOutput', false);
ylabel('LMM Estimate')
set(gca, 'XTick', 1:size(eegVar_table, 1))
set(gca, 'XTickLabel', xlabels, 'XTickLabelRotation', 45)
set(gca, 'FontSize', 12)



%% define new EEGIndex based on our observation on the effects of eegVars
T_clean.EEGIndex_roi_new = ...
    - T_clean.Alpha_Flx_roi_LM1_z ...
    - T_clean.Alpha_Ext_roi_LM1_z ...
    - T_clean.Alpha_Ext_roi_RM1_z ...
    + T_clean.Beta_Flx_roi_RM1_z  ...
    + T_clean.Beta_Ext_roi_RM1_z;

T_clean.EEGIndex_new = ...
    - T_clean.Alpha_Flx_LM1_z ...
    - T_clean.Alpha_Ext_LM1_z ...
    + T_clean.Beta_Flx_LM1_z  ...
    + T_clean.Beta_Ext_LM1_z  ...
    - T_clean.Alpha_Flx_RM1_z ...
    - T_clean.Alpha_Ext_RM1_z ...
    + T_clean.Beta_Flx_RM1_z  ...
    + T_clean.Beta_Ext_RM1_z;


eegVars_new = {'EEGIndex_new', 'EEGIndex_roi_new'};
for k = 1:2
    
    eegVar = eegVars_new{k};

    disp(eegVar)
    
    % Subset where EEG is available
    subMask = ~isnan(T_clean.(eegVar));
    tblSub  = T_clean(subMask,:);

    
    % Baseline behavioural model on SAME subset (for fair comparison)
    baseFormula = ...
        'Score ~ 1 + Pressure_cat + Error + EffortIndex + (1 + Pressure_cat | Subject_cat)';  
    baseLME = fitlme(tblSub, baseFormula, 'FitMethod', 'ML');

    % EEG-added model (fixed effects differ => compare() is valid under ML)
    eegFormula = sprintf(['Score ~ 1 + Pressure_cat + Error + ', ...
        'EffortIndex + %s + (1 + Pressure_cat | Subject_cat)'], eegVar);
    % eegFormula = sprintf(['Score ~ 1 + %s + (1 + Pressure_cat | Subject_cat)'], eegVar);
    eegLME  = fitlme(tblSub, eegFormula, 'FitMethod', 'ML');

    

   

    % Extract EEG coefficient
    coefTbl = eegLME.Coefficients;
    eegRow = coefTbl(strcmp(coefTbl.Name, eegVar),:);


    plot(cumsum_x(end) + k, eegRow.Estimate, ...
        'Marker', 'o', 'LineStyle', 'none', ...
        'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');

    

end


set(gca, 'XTick', 1:size(eegVar_table, 1) + 2)
set(gca, 'XTickLabel', [xlabels; 'EEGIndex_new'; 'EEGIndex_roi_new'], ...
    'XTickLabelRotation', 45)






%% Analysis with ChatGPT tried on 09.01.2026
% ==========================================
% Baseline vs EEG-augmented comparison for each feature (with FDR)
% IMPORTANT: Use ML (not REML) when comparing fixed-effects models

out = table('Size',[numel(eegVars) 9], ...
    'VariableTypes',{'string','double','double','double','double','double','double','double','double'}, ...
    'VariableNames',{'Var','Beta','SE','t','p','AIC','BIC','dAIC','N'});

for k = 1:numel(eegVars)

    v = eegVars{k}; 
    disp(v)

    % Subset where EEG is available
    subMask = ~isnan(T_clean.(v));
    tblSub  = T_clean(subMask,:);

    form0 = 'Score ~ 1 + Pressure_cat + Error + EffortIndex + (1 + Pressure_cat | Subject_cat)';
    lme0  = fitlme(tblSub, form0, 'FitMethod','ML');

    
    form1 = sprintf('Score ~ 1 + Pressure_cat + Error + EffortIndex + %s + (1 + Pressure_cat | Subject_cat)', v);
    lme1  = fitlme(tblSub, form1, 'FitMethod','ML');

    c = lme1.Coefficients;
    ix = strcmp(c.Name, v);

    out.Var(k)  = string(v);
    out.Beta(k) = c.Estimate(ix);
    out.SE(k)   = c.SE(ix);
    out.t(k)    = c.tStat(ix);
    out.p(k)    = c.pValue(ix);

    out.AIC(k)  = lme1.ModelCriterion.AIC;
    out.BIC(k)  = lme1.ModelCriterion.BIC;
    out.dAIC(k) = lme1.ModelCriterion.AIC - lme0.ModelCriterion.AIC;

    out.N(k)    = lme1.NumObservations; % detect sample-size changes due to NaNs


    % compare Pressure coefficients between models
    c0 = lme0.Coefficients; 
    c1 = lme1.Coefficients;
    
    
    % Suppose the names are 'Pressure_cat_3' and 'Pressure_cat_6'
    pNames = {'Pressure_cat_3','Pressure_cat_6'};
    
    for j = 1:numel(pNames)
        nm = pNames{j};
        b0 = c0.Estimate(strcmp(c0.Name,nm));
        b1 = c1.Estimate(strcmp(c1.Name,nm));
        fprintf('====> %s: baseline %.4f, +EEG %.4f, change %.4f\n', nm, b0, b1, (b1-b0));
    end


end

% FDR across EEG features
out.q = mafdr(out.p, 'BHFDR', true);

% Sort by best improvement (most negative dAIC) or smallest q
out = sortrows(out, {'dAIC','q'}, {'ascend','ascend'});




%% Analysis with ChatGPT tried on 10.01.2026
% ==========================================
% Test the scientifically plausible effect: EEG as a moderator (interaction)
outInt = table('Size',[numel(eegVars) 13], ...
    'VariableTypes',{'string','double','double','double','double','double','double','double','double','double','double','double','double'}, ...
    'VariableNames',{'Var','AIC_main','AIC_int','dAIC','LR','df','pLR','N','bMain','pMain','bInt3','bInt6','qLR'});

for k = 1:numel(eegVars)

    v = eegVars{k}; 
    disp(v)

    % Subset where EEG is available
    subMask = ~isnan(T_clean.(v));
    tblSub  = T_clean(subMask,:);

    
    form1 = sprintf('Score ~ 1 + Pressure_cat + Error + EffortIndex + %s + (1 + Pressure_cat | Subject_cat)', v);
    lme1  = fitlme(tblSub, form1, 'FitMethod','ML');


    formInt = sprintf(['Score ~ 1 + Pressure_cat + Error + EffortIndex + %s ' ...
        '+ Pressure_cat:%s + (1 + Pressure_cat | Subject_cat)'], v, v);
    lmeInt  = fitlme(tblSub, formInt, 'FitMethod','ML');


    % --- Moderation test: compare main vs interaction (isolates Pressure×EEG)
    cmp = compare(lme1, lmeInt);

    outInt.Var(k)      = string(v);
    outInt.AIC_main(k) = lme1.ModelCriterion.AIC;
    outInt.AIC_int(k)  = lmeInt.ModelCriterion.AIC;
    outInt.dAIC(k)     = outInt.AIC_int(k) - outInt.AIC_main(k);
    outInt.LR(k)       = cmp.LRStat(2);
    outInt.df(k)       = cmp.DF(2);
    outInt.pLR(k)      = cmp.pValue(2);
    outInt.N(k)        = lmeInt.NumObservations;


    % --- Store main effect of v (optional; not moderation)
    cInt = lmeInt.Coefficients;
    ixMain = strcmp(cInt.Name, v);
    outInt.bMain(k) = cInt.Estimate(ixMain);
    outInt.pMain(k) = cInt.pValue(ixMain);

    % --- Store both interaction coefficients (names depend on MATLAB coding)
    nm3 = sprintf('%s:Pressure_cat_3', v);
    nm6 = sprintf('%s:Pressure_cat_6', v);
    outInt.bInt3(k) = getCoefEitherOrder(lmeInt, v, "Pressure_cat_3");
    outInt.bInt6(k) = getCoefEitherOrder(lmeInt, v, "Pressure_cat_6");
    
    
    
    % (Your pressure-coefficient printing can stay, but compare lmeMain vs lmeInt)
    cMain = lme1.Coefficients;
    pNames = {'Pressure_cat_3','Pressure_cat_6'};
    for j = 1:numel(pNames)
        nm = pNames{j};
        bM  = cMain.Estimate(strcmp(cMain.Name,nm));
        bI  = cInt.Estimate(strcmp(cInt.Name,nm));
        fprintf('====> %s: main %.4f, +Interaction %.4f, change %.4f\n', nm, bM, bI, (bI-bM));
    end


end

% FDR across EEG features for the MODERATION test
outInt.qLR = mafdr(outInt.pLR, 'BHFDR', true);

% Sort by best moderation improvement
outInt = sortrows(outInt, {'dAIC','qLR'}, {'ascend','ascend'});



%%
v = outInt.Var(1);

subMask = ~isnan(T_clean.(v)) & ~isnan(T_clean.Score) & ~isnan(T_clean.Error) & ~isnan(T_clean.EffortIndex);
tblSub  = T_clean(subMask,:);

formMain = sprintf('Score ~ 1 + Pressure_cat + Error + EffortIndex + %s + (1 + Pressure_cat | Subject_cat)', v);
formInt  = sprintf(['Score ~ 1 + Pressure_cat + Error + EffortIndex + %s ' ...
                    '+ Pressure_cat:%s + (1 + Pressure_cat | Subject_cat)'], v, v);

lmeMain = fitlme(tblSub, formMain, 'FitMethod','ML');
lmeInt  = fitlme(tblSub, formInt,  'FitMethod','ML');

cmp = compare(lmeMain, lmeInt);
disp(cmp)

% sanity check of df and p:
LR  = cmp.LRStat(2);
dDF = cmp.DF(2);
p   = 1 - chi2cdf(LR, dDF);
fprintf('LR=%.4f, dDF=%d, p=%.6g\n', LR, dDF, p);






%% Allow EEG slopes to vary by subject (very common in EEG–behavior)

outRS = table('Size',[numel(eegVars) 9], ...
    'VariableTypes',{'string','double','double','double','double','double','double','double','double'}, ...
    'VariableNames',{'Var','Beta','SE','t','p','AIC','BIC','dAIC','N'});

for k = 1:numel(eegVars)

    v = eegVars{k}; 
    disp(v)

    % Subset where EEG is available
    subMask = ~isnan(T_clean.(v));
    tblSub  = T_clean(subMask,:);

    form0 = 'Score ~ 1 + Pressure_cat + Error + EffortIndex + (1 + Pressure_cat | Subject_cat)';
    lme0  = fitlme(tblSub, form0, 'FitMethod','ML');

    formRS = sprintf(['Score ~ 1 + Pressure_cat + Error + EffortIndex + %s ' ...
        '+ (1 + Pressure_cat + %s | Subject_cat)'], v, v);
    lmeRS  = fitlme(tblSub, formRS, 'FitMethod','ML');

    c = lmeRS.Coefficients;
    ix = strcmp(c.Name, v);

    outRS.Var(k)  = string(v);
    outRS.Beta(k) = c.Estimate(ix);
    outRS.SE(k)   = c.SE(ix);
    outRS.t(k)    = c.tStat(ix);
    outRS.p(k)    = c.pValue(ix);

    outRS.AIC(k)  = lmeRS.ModelCriterion.AIC;
    outRS.BIC(k)  = lmeRS.ModelCriterion.BIC;
    outRS.dAIC(k) = lmeRS.ModelCriterion.AIC - lme0.ModelCriterion.AIC;

    outRS.N(k)    = lmeRS.NumObservations; % detect sample-size changes due to NaNs


    % compare Pressure coefficients between models
    c1 = lme0.Coefficients; 
    cRS = lmeRS.Coefficients;
    
    
    % Suppose the names are 'Pressure_cat_3' and 'Pressure_cat_6'
    pNames = {'Pressure_cat_3','Pressure_cat_6'};
    
    for j = 1:numel(pNames)
        nm = pNames{j};
        b1 = c1.Estimate(strcmp(c1.Name,nm));
        bRS = cRS.Estimate(strcmp(cRS.Name,nm));
        fprintf('====> %s: baseline %.4f, +EEG_formInt %.4f, change %.4f\n', nm, b1, bRS, (bRS-b1));
    end


end

% FDR across EEG features
outRS.q = mafdr(outRS.p, 'BHFDR', true);

% Sort by best improvement (most negative dAIC) or smallest q
outRS = sortrows(outRS, {'dAIC','q'}, {'ascend','ascend'});







%% --------------------- EEG INDEX PER TRIAL (MEAN OF Z-SCORES) -------------
% For each trial row, EEG index is mean across available (non-NaN) z-scored EEG features.
if ~isempty(eegCols)
    T.(cfg.eegIndexName) = mean(T{:, eegCols}, 2, 'omitnan');
else
    T.(cfg.eegIndexName) = NaN(height(T),1);
end

writetable(T, fullfile(cfg.outDir, "Merged_Behavior_EEG_Table_WithIndex.csv"));

%% --------------------- DEFINE BEHAVIOR OUTCOMES (EDIT) --------------------
dvList = {};
if ismember("Score", T.Properties.VariableNames);                 dvList{end+1} = "Score"; end %#ok<SAGROW>
if ismember("RMSE", T.Properties.VariableNames);                  dvList{end+1} = "RMSE"; end %#ok<SAGROW>
if ismember("SubjectiveDifficulty", T.Properties.VariableNames);  dvList{end+1} = "SubjectiveDifficulty"; end %#ok<SAGROW>
assert(~isempty(dvList), "No behavioral DV columns detected. Update dvList mapping.");

%% --------------------- MODEL FORMULAS -----------------------------------
cond = cfg.condVarName;

if cfg.useRandomSlope
    re = sprintf('(1 + %s | Subject)', cond);
else
    re = '(1 | Subject)';
end

% Behavior vs Pressure
baseFormula = @(dv) sprintf('%s ~ 1 + %s + %s', dv, cond, re);

% EEGIndex vs Pressure
idxFormula  = sprintf('%s ~ 1 + %s + %s', cfg.eegIndexName, cond, re);

% Behavior vs Pressure + EEGIndex
if cfg.includeCondByEEGInteraction
    behIdxFormula = @(dv) sprintf('%s ~ 1 + %s * %s + %s', dv, cond, cfg.eegIndexName, re);
else
    behIdxFormula = @(dv) sprintf('%s ~ 1 + %s + %s + %s', dv, cond, cfg.eegIndexName, re);
end

%% --------------------- FIT: BEHAVIORAL LMMs ------------------------------
behResults = table();

for i = 1:numel(dvList)
    dv = dvList{i};
    Ti = T(~ismissing(T.(dv)), :);

    mdl = fitlme(Ti, baseFormula(dv), 'FitMethod', cfg.fitMethod, 'DummyVarCoding', 'effects');
    a = anova(mdl, 'DFMethod','satterthwaite');
    pCond = extract_term_pvalue(a, cond);

    behResults = [behResults; table(string(dv), pCond, string(mdl.Formula), height(Ti), ...
        'VariableNames', {'DV','p_Condition','Formula','N'})]; %#ok<AGROW>

    save(fullfile(cfg.outDir, "LMM_Behavior_" + dv + ".mat"), "mdl", "a");
end

writetable(behResults, fullfile(cfg.outDir, "Behavior_LMM_Summary.csv"));

%% --------------------- FIT: EEG INDEX ~ PRESSURE --------------------------
idxResults = table();
Tidx = T(~ismissing(T.(cfg.eegIndexName)), :);

if height(Tidx) >= 30
    mdl_idx = fitlme(Tidx, idxFormula, 'FitMethod', cfg.fitMethod, 'DummyVarCoding', 'effects');
    a_idx = anova(mdl_idx, 'DFMethod','satterthwaite');
    pCond_idx = extract_term_pvalue(a_idx, cond);

    idxResults = table(pCond_idx, string(mdl_idx.Formula), height(Tidx), ...
        'VariableNames', {'p_Condition','Formula','N'});

    save(fullfile(cfg.outDir, "LMM_EEGIndex.mat"), "mdl_idx", "a_idx");
end

writetable(idxResults, fullfile(cfg.outDir, "EEGIndex_LMM_Summary.csv"));

%% --------------------- FIT: BEHAVIOR ~ PRESSURE + EEG INDEX --------------
behIdxResults = table();

for i = 1:numel(dvList)
    dv = dvList{i};
    Tij = T(~ismissing(T.(dv)) & ~ismissing(T.(cfg.eegIndexName)), :);

    if height(Tij) < 30
        continue;
    end

    % Nested comparison must use ML for fixed-effect change
    m0 = fitlme(Tij, baseFormula(dv),   'FitMethod','ML', 'DummyVarCoding','effects');
    m1 = fitlme(Tij, behIdxFormula(dv), 'FitMethod','ML', 'DummyVarCoding','effects');
    cmp = compare(m0, m1);

    % Final estimates with REML
    mdl = fitlme(Tij, behIdxFormula(dv), 'FitMethod',cfg.fitMethod, 'DummyVarCoding','effects');

    [pIdx, betaIdx] = extract_fixed_effect(mdl, cfg.eegIndexName);

    behIdxResults = [behIdxResults; table(string(dv), height(Tij), ...
        cmp.pValue(2), pIdx, betaIdx, string(mdl.Formula), ...
        'VariableNames', {'DV','N','p_LRT_AddEEGIndex','p_Wald_EEGIndex','beta_EEGIndex','Formula'})]; %#ok<AGROW>

    save(fullfile(cfg.outDir, "LMM_BehaviorPlusEEGIndex_" + dv + ".mat"), "mdl", "cmp");
end

writetable(behIdxResults, fullfile(cfg.outDir, "BehaviorPlusEEGIndex_LMM_Summary.csv"));

disp("DONE. Outputs saved to: " + cfg.outDir);

%% =========================================================================
%% LOCAL FUNCTIONS
%% =========================================================================


function eegS = load_eeg_subject_cluster(cfg, s, clusterName)
% EDIT to match your EEG TF storage.
%
% Return EMPTY TABLE if subject is not present in this cluster.
%
% Expected columns (epoch- or trial-level):
%   Trial, cfg.condVarName,
%   TF (cell): each cell [nF x nPct] containing either ratio R or power P
%   freqHz (cell): [nF x 1]
%   cyclePct (cell): [1 x nPct] or [nPct x 1]
%
% If cfg.TF_is_ratio=false, also provide:
%   baseF (cell): [nF x 1] baseline/reference vector B(f)

subStr = cfg.subID_as_string(s);
eegFile = fullfile(cfg.eegRoot, subStr, "TF_" + string(clusterName) + ".mat"); % example

if ~exist(eegFile, "file")
    eegS = table(); % subject not present in this cluster (or file missing)
    return;
end

S = load(eegFile);

% ---- MAP YOUR STRUCTURE HERE (EDIT) ----
% Example assumed fields:
%   S.trialID, S.pressure, S.tf, S.freqHz, S.cyclePct
eegS = table();
eegS.Trial = S.trialID(:);
eegS.(cfg.condVarName) = string(S.pressure(:));
eegS.TF = S.tf(:);

eegS.freqHz   = repmat({S.freqHz(:)}, numel(eegS.TF), 1);
eegS.cyclePct = repmat({S.cyclePct(:)'}, numel(eegS.TF), 1);

if isfield(S, "baseF")
    eegS.baseF = repmat({S.baseF(:)}, numel(eegS.TF), 1);
end

end

function eegFeat = extract_band_features_fullcycle_opt2(cfg, eegS)
% Extract band features using OPTION 2:
%   feature = 10*log10( mean( R(f,p) over band×cycle ) )
%
% R(f,p) is the normalized ratio P/B if cfg.TF_is_ratio=true, else it is computed as P./B.

freqHz   = eegS.freqHz{1}(:);
cyclePct = eegS.cyclePct{1}(:)'; % row

pidx = (cyclePct >= cfg.cycleWindowPct(1)) & (cyclePct <= cfg.cycleWindowPct(2));
assert(any(pidx), "cycleWindowPct has no overlap with cyclePct axis.");

nRows = height(eegS);

% Compute epoch-level scalar features per row
featPerRow = table();
featPerRow.Trial = eegS.Trial;
featPerRow.(cfg.condVarName) = eegS.(cfg.condVarName);

for b = 1:numel(cfg.bandNamesToUse)
    bn = cfg.bandNamesToUse(b);
    flim = cfg.bands.(bn);

    fidx = (freqHz >= flim(1)) & (freqHz <= flim(2));
    assert(any(fidx), "Band %s has no overlap with freqHz axis.", bn);

    v = nan(nRows,1);

    for i = 1:nRows
        X = eegS.TF{i};
        if ~isnumeric(X)
            continue;
        end

        % Convert to ratio R(f,p)
        if cfg.TF_is_ratio
            R = X;
        else
            B = eegS.baseF{i};    % [nF x 1]
            R = X ./ B;           % implicit expansion
        end

        % Safeguard positivity for log
        R = max(R, cfg.epsRatio);

        patch = R(fidx, pidx);

        % OPTION 2 (mean then log):
        %   - average normalized TF in linear space over (band×cycle)
        %   - then convert that scalar to dB
        v(i) = 10*log10(mean(patch, 'all', 'omitnan'));
    end

    featPerRow.("EEG_" + bn + "_opt2_meanFirstLog") = v;
end

% Aggregate epochs -> trials (mean across epochs of the scalar)
if cfg.aggregateEpochsToTrial
    eegFeat = aggregate_epoch_scalars_to_trial(cfg, featPerRow);
else
    eegFeat = featPerRow;
end

end

function eegT = aggregate_epoch_scalars_to_trial(cfg, featPerRow)
% Aggregates scalar features to one row per trial.
% Condition is assumed constant within each trial group.

[G, trialVals, condVals] = findgroups(featPerRow.Trial, featPerRow.(cfg.condVarName));

eegT = table();
eegT.Trial = trialVals;
eegT.(cfg.condVarName) = condVals;

featCols = setdiff(string(featPerRow.Properties.VariableNames), ["Trial", cfg.condVarName]);

for k = 1:numel(featCols)
    col = featCols(k);
    x = featPerRow.(col);

    out = nan(height(eegT),1);
    for g = 1:height(eegT)
        rows = (G == g);
        switch lower(cfg.trialAggregation)
            case "mean"
                out(g) = mean(x(rows), 'omitnan');
            case "median"
                out(g) = median(x(rows), 'omitnan');
            otherwise
                error("Unknown cfg.trialAggregation: %s", cfg.trialAggregation);
        end
    end
    eegT.(col) = out;
end
end

function T = zscore_within_subject(T, featureCols)
% Z-score each feature column within each subject (ignoring NaNs).
subs = unique(string(T.Subject));
for si = 1:numel(subs)
    idx = string(T.Subject) == subs(si);

    for j = 1:numel(featureCols)
        c = featureCols(j);
        x = T{idx, c};

        if all(ismissing(x)) || std(x, 'omitnan') == 0
            continue;
        end

        mu = mean(x, 'omitnan');
        sd = std(x,  'omitnan');
        T{idx, c} = (x - mu) ./ sd;
    end
end
end

function p = extract_term_pvalue(anovaTbl, termName)
% Extract p-value for a specific term from fitlme anova table.
p = NaN;
if isempty(anovaTbl); return; end
idx = strcmp(string(anovaTbl.Term), string(termName));
if any(idx)
    p = anovaTbl.pValue(find(idx,1,'first'));
end
end

function [p, beta] = extract_fixed_effect(mdl, effectName)
% Extract p-value and estimate for a fixed effect from mdl.Coefficients.
p = NaN; beta = NaN;
C = mdl.Coefficients;
idx = strcmp(string(C.Name), string(effectName));
if any(idx)
    p = C.pValue(find(idx,1,'first'));
    beta = C.Estimate(find(idx,1,'first'));
end
end
