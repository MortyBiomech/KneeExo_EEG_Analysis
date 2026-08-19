%% ========================================================================
% Assesment of added value of EEG features to be basline model
% baseline model: 
%   - Score ~ 1 + Pressure_cat + Error_z + EffortIndex_z 
%               + (1+Pressure_cat|Subject_cat)
% Augmented model:
%   - Score ~ 1 + Pressure_cat + Error_z + EffortIndex_z + EEG_feature_z
%               + (1+Pressure_cat|Subject_cat)
%
% EEG features:
%   - Bands: theta/alpha/beta
%   - Clusters: dACC, LPO, LPS, LPM (LM1), RPO, RPS, RPM (RM1)
%   - Cycle: whole cycle (0–100%)
%   - Log-feature definition: both normalized means and log transformed.
%       1) average normalized TF ratio over (band × full_cycle)
%       2) apply 10*log10 to that mean
%


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


%%  LOAD whole Brain EEG FEATURE ==========================================
eegfeatures = load(fullfile(eeg_path, "EEG_features_wholeBrain.mat"));
eegfeatures = eegfeatures.EEG_features_wholeBrain;


%%  MERGE BEHAVIOR + EEG FEATURES =========================================
T = create_the_main_table_wholeBrain(allBeh, eegfeatures);


%% ============================
%  Within-subject normalization
%  ============================

% List of EEG feature for per-subject z-score transform
VariableNames = T.Properties.VariableNames; 
eegVars = VariableNames(1, 12:53);

tbl0 = T;
% Error
tbl0 = withinSubjectZ(tbl0, 'Subject_cat', 'Error');
% EMG
tbl0 = withinSubjectZ(tbl0, 'Subject_cat', 'EffortIndex');

% EEG 
for k = 1:numel(eegVars)
    v = eegVars{k};
    tbl0 = withinSubjectZ(tbl0, 'Subject_cat', v);
end


% T_clean is the same tbl but some rows are removed. subject level outlier 
% removal on score values per condtion was applied on tbl.
[T_clean, M1] = score_pressure_model(tbl0); 



%% =============================================================
%  EEG-ADDED MODELS (cluster-specific subsets)
%  For each EEG feature:
%   - restrict to rows where EEG is observed (not NaN)
%   - fit baseline:  Score ~ Pressure + Error + EMG + (RE)
%   - fit eeg-added: Score ~ Pressure + Error + EMG + EEG + (RE)
%   - compare with likelihood ratio test (ML fits)
% ==============================================================
% List EEG feature columns you want to test (one per brain cluster)

eegVars_without_log = eegVars(1, 1:2:end);
eegVars_with_log = eegVars(1, 2:2:end);


allResults = [];

for k = 1:numel(eegVars_without_log)
    
    eegVar = eegVars_without_log{k};
    disp(eegVar)
    
    % Subset where EEG is available
    subMask = ~isnan(T_clean.(eegVar));
    tblSub  = T_clean(subMask,:);

    
    % Baseline behavioural model on SAME subset (for fair comparison)
    % baseFormula = ...
    %     ['Score ~ 1 + Pressure_cat + Error_z + EffortIndex_z ', ...
    %         '+ (1 + Pressure_cat | Subject_cat)'];  
    % baseFormula = ...
    %     ['Score ~ 1 + Pressure_cat + Error_z + EffortIndex_z ', ...
    %         '+ (1 | Subject_cat)'];  
    baseFormula = ...
        ['Score ~ 1 + Pressure_cat + Error + EffortIndex ', ...
            '+ (1 | Subject_cat)'];  
    lastwarn('');    
    baseLME = fitlme(tblSub, baseFormula, 'FitMethod', 'ML', 'CheckHessian', true);
    [wmsg, ~] = lastwarn;
    if ~isempty(wmsg)
        fprintf('WARNING (%s): %s\n', eegVar, wmsg);
    end

    % EEG-added model (fixed effects differ => compare() is valid under ML)
    % eegFormula = sprintf(['Score ~ 1 + Pressure_cat + Error_z + ', ...
    %     'EffortIndex_z + %s + (1 + Pressure_cat | Subject_cat)'], ...
    %     [eegVar, '_z']);
    % eegFormula = sprintf(['Score ~ 1 + Pressure_cat + Error_z + ', ...
    %     'EffortIndex_z + %s + (1 | Subject_cat)'], ...
    %     [eegVar, '_z']);
    eegFormula = sprintf(['Score ~ 1 + Pressure_cat + Error + ', ...
        'EffortIndex + %s + (1 | Subject_cat)'], ...
        [eegVar]);
    % eegFormula = sprintf(['Score ~ 1 + Pressure_cat + Error_z + ', ...
    %     'EffortIndex_z + %s + (1 + Pressure_cat | Subject_cat)'], ...
    %     eegVar);
    lastwarn('');    
    eegLME  = fitlme(tblSub, eegFormula, 'FitMethod', 'ML', 'CheckHessian', true);
    [wmsg, ~] = lastwarn;
    if ~isempty(wmsg)
        fprintf('WARNING (%s): %s\n', eegVar, wmsg);
    end

    
    AIC_base = baseLME.ModelCriterion.AIC;
    AIC_eeg  = eegLME.ModelCriterion.AIC;
    
    % Commonly reported:
    dAIC = AIC_base - AIC_eeg;   % positive => EEG model fits better (lower AIC);
   

    % compare models
    cmp = compare(baseLME, eegLME);   % returns a table (2 rows: base, eeg)
    % The LRT p-value is in the second row (the larger model vs previous)
    p_LRT = cmp.pValue(2);
    
    

    % Extract EEG coefficient
    coefTbl = eegLME.Coefficients;
    % eegRow = coefTbl(strcmp(coefTbl.Name, [eegVar, '_z']),:);
    eegRow = coefTbl(strcmp(coefTbl.Name, eegVar),:);


    
    switch 1
        case contains(eegVar, 'Dorsal_ACC')
            cluster = "Dorsal ACC";
        case contains(eegVar, 'Left_Parieto_Occipital')
            cluster = "Left PO";
        case contains(eegVar, 'Left_PreMot')
            cluster = "Left PS";
        case contains(eegVar, 'Left_Prim')
            cluster = "Left M1";
        case contains(eegVar, 'Right_Parieto')
            cluster = "Right PO";
        case contains(eegVar, 'Right_PreMot')
            cluster = "Right PS";
        case contains(eegVar, 'Right_Prim')
            cluster = "Right M1";
    end

    m = mod(k, 3);
    if m == 1
        band = "\theta";
    elseif m == 2
        band = "\alpha";
    else
        band = "\beta";
    end

   
    resultsRow = table( ...
        string(eegVar), cluster, band, eegRow.Estimate, eegRow.SE, ...
        eegRow.tStat, eegRow.pValue, eegRow.Lower, eegRow.Upper, ...
        AIC_base, AIC_eeg, dAIC, p_LRT, ...
        'VariableNames', ...
        {'EEGvar', 'Cluster', 'Band', 'Estimate', 'SE', ...
        't_stat', 'p_value', 'Lower', 'Upper', ...
        'AIC_base','AIC_eeg','dAIC','p_LRT'} );
    
    % Append to a results table you keep outside the loop:
    allResults = [allResults; resultsRow];


end

% FDR correction on the p_LRT
p = allResults.p_LRT;
q = mafdr(p, 'BHFDR', true);     % Benjamini-Hochberg FDR
allResults.q_FDR = q;



% (1) nested-ML sanity: must now hold for every feature
fprintf('%d / %d violate dAIC >= -2\n', sum(allResults.dAIC < -2-1e-6), height(allResults));

% (2) LRT should now track Wald
disp(allResults(:, {'EEGvar','p_value','p_LRT'}))


allResults.q_FDR_Wald = mafdr(allResults.p_value, 'BHFDR', true);
disp(sortrows(allResults(:, {'EEGvar','Estimate','Lower','Upper','p_value','q_FDR_Wald'}), 'p_value'))



%% Heat map and Forest plot showing the incremental improvement of model
%  fit with delta_AIC and marker on top for significant improvements. 
%  Forest plot showing the estimated LMM coefficient and its 95% CI


clusterOrder = {'Dorsal ACC', 'Left PO', 'Left PS', 'Left M1', ...
    'Right PO', 'Right PS', 'Right M1'};
bandOrder    = {'\theta','\alpha','\beta'};   

qThresh = 0.05;


%% BUILD MATRICES (dAIC and significance mask)
nC = numel(clusterOrder);
nB = numel(bandOrder);

dAICmat = NaN(nB, nC);
sigMat  = false(nB, nC);

% Make sure cluster/band are comparable (string is easiest)
cl = allResults.Cluster;
bd = allResults.Band;

for i = 1:nB
    for j = 1:nC
        idx = (cl == string(clusterOrder{j})) & (bd == string(bandOrder{i}));
        dAICmat(i,j) = allResults.dAIC(idx);
        sigMat(i,j)  = allResults.q_FDR(idx) < qThresh;
    end
end



%% PLOT HEATMAP (imagesc) 

monitors = get(0, 'MonitorPositions');
fig = figure('name', ...
    'EEG-augmented Model vs. Baseline Model', ...
    'InvertHardcopy', 'off', 'PaperType', 'a2', ...
    'PaperOrientation', 'landscape', 'Units', 'pixels');
set(fig, 'Position', ...
    [monitors(2,1)+monitors(2,3) monitors(2,2)+100 1500 800]);



N = 256;                                 % number of colors
bottom = [0	0 0.7];                    % blue
middle = [0.94 0.94 0.97];               % white-ish
top    = [0.5 0	0];                      % red
n1 = floor(N/2);
n2 = N - n1;
cmap1 = [linspace(bottom(1), middle(1), n1)', ...
         linspace(bottom(2), middle(2), n1)', ...
         linspace(bottom(3), middle(3), n1)'];
cmap2 = [linspace(middle(1), top(1), n2)', ...
         linspace(middle(2), top(2), n2)', ...
         linspace(middle(3), top(3), n2)'];
cmap = [cmap1; cmap2];

% N = 256;
% white = [0.94 0.94 0.97];
% red   = [0.6 0	0];
% cmap = [linspace(white(1), red(1), N)', ...
%         linspace(white(2), red(2), N)', ...
%         linspace(white(3), red(3), N)'];


% Tiled-Layout 
tiledlayout(10, 28)


fh1 = nexttile(1, [5, 10]);
imagesc(dAICmat);

set(gca, 'YDir','normal');  

colormap(cmap);           

clim1 = get(gca, 'CLim');
clim2 = round([-max(abs(clim1)), max(abs(clim1))]);
% clim2 = round([0, max(abs(clim1))]);
set(gca, 'CLim', clim2)



cb = colorbar;
cb_pos = cb.Position;
cb.Label.String = 'AIC_{baseline} - AIC_{EEG-augmented}';
cb.Label.Position(1) = cb.Label.Position(1) + 1;


xticks(1:nC); xticklabels(clusterOrder); 
set(gca, 'XTickLabelRotation', 45)

yticks(1:nB); yticklabels(bandOrder);

% ylabel
ylh =  ylabel('Frequency Band');
ylh.FontWeight = "bold";
ylh.Position(1) = ylh.Position(1) - 0.35;

set(gca, 'FontSize', 16)

% title
thd = title('EEG-augmented model vs. baseline model');
thd.Position(2) = thd.Position(2)*1.1;
thd.FontSize = 18;


ylim([0.5 3.5])

axis equal
axis tight

% Add subtle grid lines between cells
hold on;
for x = 0.5:1:(nC+0.5)
    xline(x, 'k-', 'LineWidth', 0.5, 'Alpha', 0.15);
end
for y = 0.5:1:(nB+0.5)
    yline(y, 'k-', 'LineWidth', 0.5, 'Alpha', 0.15);
end

% OVERLAY MARKERS FOR FDR-SIGNIFICANT CELLS 
[r, c] = find(sigMat);
scatter(c, r, 80, 'k', '*', 'LineWidth', 1);   % open circles



% ax = gca;
% lbl = ax.XTickLabel;                  % cell array of char (often)
% k = 2;                                % index of the label to bold
% lbl{k} = ['\bf' lbl{k}];              % bold only this one
% ax.TickLabelInterpreter = 'tex';
% ax.XTickLabel = lbl;

aspectratio = get(gca, 'PlotBoxAspectRatio');
fh1.PlotBoxAspectRatio = aspectratio*1.1;

hold off;


%% forest plot (LMM coefficient estimate + 95% CI)

fh2 = nexttile(13, [5, 16]);

yline(0, 'LineWidth', 0.5, 'LineStyle', '--'); hold on

Low = allResults.Estimate - allResults.Lower;
High = allResults.Upper - allResults.Estimate;
h1 = errorbar(fh2, 1:numel(dAICmat), allResults.Estimate, Low, High, 'o-', ...
    'Color', 0.7*[1 1 1], ...
    'MarkerFaceColor', 0.7*[1 1 1], ...
    'MarkerEdgeColor', 0.7*[1 1 1], ...
    'MarkerSize', 5, ...
    'LineStyle', 'none', ...
    'LineWidth', 2, ...
    'CapSize', 8);


% Font Size
set(gca, 'FontSize', 16)    


xlim([1-1, 21+1])
% ylim([-1 1])
ylim([-0.25 0.25])  % for z-score predictors

set(gca, 'XTick', 1:numel(dAICmat))
allResults.label = allResults.Cluster + " " + allResults.Band;
set(gca, 'XTickLabel', allResults.label)
set(gca, 'XTickLabelRotation', 45)


ax = gca;
lbl = ax.XTickLabel;                  % cell array of char (often)
k = 10;                               % index of the label to bold
lbl{k} = ['\bf' lbl{k}];              % bold only this one
ax.TickLabelInterpreter = 'tex';
ax.XTickLabel = lbl;


h2 = errorbar(fh2, k, allResults.Estimate(k), Low(k), High(k), 'o-', ...
    'Color', 'k', ...
    'MarkerFaceColor', 'k', ...
    'MarkerEdgeColor', 'k', ...
    'MarkerSize', 5, ...
    'LineStyle', 'none', ...
    'LineWidth', 2, ...
    'CapSize', 8);


fh2.PlotBoxAspectRatio = [5.272120200333891, 1, 1.327212020033389];
fh2.DataAspectRatio = [10.446938775510198,1,3.013836477987421];
% fh2.PlotBoxAspectRatio = [12.947624403183063,1,1.658879999999999];
% fh2.DataAspectRatio = [3.398306795892455,1,2.411265432098767];

% ylabel
ylh2 = ylabel('Coefficient Estimate');
ylh2.FontWeight = "bold";
ylh2.Position(1) = ylh2.Position(1) - 0.4;

% title
thd2 = title('EEG Features Coefficient in the LMM (Value \pm 95% CI)', 'Interpreter', 'tex');
thd2.Position(2) = thd2.Position(2)*1.2;



%% Third panel showing the effect size on delta_Score

% Subset where EEG is available

% % ==========================
% % with per-subject z-scoring
% % ==========================
% subMask = ~isnan(T_clean.Left_Prim_Motor_Theta_z);
% tblSub_z  = T_clean(subMask,:);
% lme_z = fitlme(tblSub_z, ['Score ~ 1 + Pressure_cat + Error_z + ', ...
%                       'EffortIndex_z + Left_Prim_Motor_Theta_z + ', ...
%                       '(1 + Pressure_cat | Subject_cat)'], ...
%                       'FitMethod', 'ML');
% 
% predNames = {'Error_z','EffortIndex_z','Left_Prim_Motor_Theta_z'}; 
% dz = 2.563;  % P90-P10 for standard normal
% 
% B  = lme_z.Coefficients.Estimate;
% CN = lme_z.CoefficientNames;
% V  = lme_z.CoefficientCovariance;  % covariance of fixed effects
% 
% effects_z = struct();
% 
% for k = 1:numel(predNames)
%     idx = find(strcmp(CN, predNames{k}));
%     beta = B(idx);
%     se_beta = sqrt(V(idx,idx));
% 
%     eff = beta * dz;
%     se_eff = se_beta * dz;
% 
%     effects_z.(predNames{k}).delta = eff;
%     effects_z.(predNames{k}).CI95  = eff + [-1 1]*1.96*se_eff;
% end
% 
% % Pressure contrasts
% contrasts = {'Pressure_cat_3','Pressure_cat_6'};  % Medium-Low, High-Low
% for k = 1:numel(contrasts)
%     idx = find(strcmp(CN, contrasts{k}));
%     beta = B(idx);
%     se_beta = sqrt(V(idx,idx));
%     effects_z.(contrasts{k}).delta = beta;  % already on Score scale
%     effects_z.(contrasts{k}).CI95  = beta + [-1 1]*1.96*se_beta;
% end


% % ========================
% % No per-subject z-scoring
% % ========================
% subMask = ~isnan(T_clean.Left_Prim_Motor_Theta);
% tblSub  = T_clean(subMask,:);
% lme = fitlme(tblSub, ['Score ~ 1 + Pressure_cat + Error + ', ...
%                       'EffortIndex + Left_Prim_Motor_Theta + ', ...
%                       '(1 + Pressure_cat | Subject_cat)'], ...
%                       'FitMethod', 'ML');
% 
% dx_err = prctile(tblSub.Error, 90) - ...
%     prctile(tblSub.Error, 10);
% 
% dx_emg = prctile(tblSub.EffortIndex, 90) - ...
%     prctile(tblSub.EffortIndex, 10);
% 
% dx_eeg = prctile(tblSub.Left_Prim_Motor_Theta, 90) - ...
%     prctile(tblSub.Left_Prim_Motor_Theta, 10);
% 
% dx = [dx_err, dx_emg, dx_eeg];
% predNames = {'Error','EffortIndex','Left_Prim_Motor_Theta'}; 
% 
% B  = lme.Coefficients.Estimate;
% CN = lme.CoefficientNames;
% V  = lme.CoefficientCovariance;  % covariance of fixed effects
% 
% effects = struct();
% 
% for k = 1:numel(predNames)
%     idx = find(strcmp(CN, predNames{k}));
%     beta = B(idx);
%     se_beta = sqrt(V(idx,idx));
% 
%     eff = beta * dx(k);
%     se_eff = se_beta * dx(k);
% 
%     effects.(predNames{k}).delta = eff;
%     effects.(predNames{k}).CI95  = eff + [-1 1]*1.96*se_eff;
% end
% 
% % Pressure contrasts
% contrasts = {'Pressure_cat_3','Pressure_cat_6'};  % Medium-Low, High-Low
% for k = 1:numel(contrasts)
%     idx = find(strcmp(CN, contrasts{k}));
%     beta = B(idx);
%     se_beta = sqrt(V(idx,idx));
%     effects.(contrasts{k}).delta = beta;  % already on Score scale
%     effects.(contrasts{k}).CI95  = beta + [-1 1]*1.96*se_beta;
% end


% %% ===================
% % Plot the third panel
% % ====================
% fh3 = nexttile(23, [1, 8]);
% 
% CI_L = [effects.Pressure_cat_3.CI95(1), ...
%     effects.Pressure_cat_6.CI95(1), ...
%     effects.Error.CI95(1), ...
%     effects.EffortIndex.CI95(1), ...
%     effects.Left_Prim_Motor_Theta.CI95(1)];
% CI_U = [effects.Pressure_cat_3.CI95(2), ...
%     effects.Pressure_cat_6.CI95(2), ...
%     effects.Error.CI95(2), ...
%     effects.EffortIndex.CI95(2), ...
%     effects.Left_Prim_Motor_Theta.CI95(2)];
% delta = [effects.Pressure_cat_3.delta, ...
%     effects.Pressure_cat_6.delta, ...
%     effects.Error.delta, ...
%     effects.EffortIndex.delta ...
%     effects.Left_Prim_Motor_Theta.delta];
% 
% Low = delta - CI_L;
% High = CI_U - delta;
% h1 = errorbar(fh3, 1:numel(delta), delta, Low, High, 'o-', ...
%     'Color', 0.1*[1 1 1], ...
%     'MarkerFaceColor', 0.1*[1 1 1], ...
%     'MarkerEdgeColor', 0.1*[1 1 1], ...
%     'MarkerSize', 5, ...
%     'LineStyle', 'none', ...
%     'LineWidth', 2, ...
%     'CapSize', 8);
% xlim([0 6])
% labels = {'P_{Medium} vs. P_{Low}', 'P_{High} vs. P_{Low}', 'Tracking Error', ...
%     'Effort Index', 'Left M1 \theta'};
% xticks(1:numel(delta))
% xticklabels(labels)
% set(gca, 'XTickLabelRotation', 45)
% set(gca, 'FontSize', 16)
% set(gca, 'Box', 'off')
% 
% fh3.PlotBoxAspectRatio = [2.072120200333891, 1, 1.327212020033389];
% fh3.DataAspectRatio = [13.446938775510198,1,3.013836477987421];
% 
% ylh3 = ylabel(fh3, 'Predicted \DeltaScore', 'FontWeight','bold');
% ylh3.Position(1) = ylh3.Position(1) - 0.3;
% 
% % title
% thd3 = title('Full LMM Predictors Effect Size', 'Interpreter', 'tex');
% thd3.Position(2) = thd3.Position(2)*1.15;



%% M1 Model
fh3 = nexttile(169, [4, 4]);


subMask = ~isnan(T_clean.Left_Prim_Motor_Theta);
tblSub  = T_clean(subMask,:);
M1 = fitlme(tblSub, ['Score ~ 1 + Pressure_cat + ', ...
                      '(1 + Pressure_cat | Subject_cat)'], ...
                      'FitMethod', 'ML');

B  = M1.Coefficients.Estimate;
CN = M1.CoefficientNames;
V  = M1.CoefficientCovariance;  % covariance of fixed effects

effects_M1 = struct();

% Pressure contrasts
contrasts = {'Pressure_cat_3','Pressure_cat_6'};  % Medium-Low, High-Low
for k = 1:numel(contrasts)
    idx = find(strcmp(CN, contrasts{k}));
    beta = B(idx);
    se_beta = sqrt(V(idx,idx));
    effects_M1.(contrasts{k}).delta = beta;  % already on Score scale
    effects_M1.(contrasts{k}).CI95  = beta + [-1 1]*1.96*se_beta;
end


CI_L = [effects_M1.Pressure_cat_3.CI95(1), ...
    effects_M1.Pressure_cat_6.CI95(1)];
CI_U = [effects_M1.Pressure_cat_3.CI95(2), ...
    effects_M1.Pressure_cat_6.CI95(2)];
delta = [effects_M1.Pressure_cat_3.delta, ...
    effects_M1.Pressure_cat_6.delta];

Low = delta - CI_L;
High = CI_U - delta;
h1 = errorbar(fh3, 1:numel(delta), delta, Low, High, 'o-', ...
    'Color', 0.1*[1 1 1], ...
    'MarkerFaceColor', 0.1*[1 1 1], ...
    'MarkerEdgeColor', 0.1*[1 1 1], ...
    'MarkerSize', 5, ...
    'LineStyle', 'none', ...
    'LineWidth', 2, ...
    'CapSize', 8);


yl = ylim(gca); dy = 0.03*range(yl);
for i = 1:numel(h1.XData)
    txt = sprintf('%.1f\n[%.1f, %.1f]', delta(i), CI_L(i), CI_U(i));
    text(h1.Parent, h1.XData(i), CI_U(i) + dy, txt, ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize', 12, 'BackgroundColor', 'none', 'Margin', 1, 'EdgeColor', 'none');
end

xlim([1-0.5 numel(delta)+0.5])
ylim([0 8])

labels = {'P_{Medium} vs. P_{Low}', 'P_{High} vs. P_{Low}'};
xticks(1:numel(delta))
xticklabels(labels)
set(gca, 'XTickLabelRotation', 45)
set(gca, 'FontSize', 16)
set(gca, 'Box', 'off')

% fh3.DataAspectRatio = [4, 7, 1];

% ylabel
ylh3 = ylabel(fh3, 'Predicted \DeltaRating', 'FontWeight','bold');
ylh3.Position(1) = ylh3.Position(1) - 0.3;

% title
thd3 = title('M1 Model', 'Interpreter', 'tex');
thd3.Position(2) = thd3.Position(2)*1.1;




%% M2 Model
fh4 = nexttile(173, [4, 6]);


subMask = ~isnan(T_clean.Left_Prim_Motor_Theta);
tblSub  = T_clean(subMask,:);
M2 = fitlme(tblSub, ['Score ~ 1 + Pressure_cat + Error + ', ...
                      '(1 + Pressure_cat | Subject_cat)'], ...
                      'FitMethod', 'ML');

dx_err = prctile(tblSub.Error, 90) - ...
    prctile(tblSub.Error, 10);


dx = [dx_err];
predNames = {'Error'}; 

B  = M2.Coefficients.Estimate;
CN = M2.CoefficientNames;
V  = M2.CoefficientCovariance;  % covariance of fixed effects

effects_M2 = struct();

k = 1;
idx = find(strcmp(CN, predNames{k}));
beta = B(idx);
se_beta = sqrt(V(idx,idx));

eff = beta * dx(k);
se_eff = se_beta * dx(k);

effects_M2.(predNames{k}).delta = eff;
effects_M2.(predNames{k}).CI95  = eff + [-1 1]*1.96*se_eff;


% Pressure contrasts
contrasts = {'Pressure_cat_3','Pressure_cat_6'};  % Medium-Low, High-Low
for k = 1:numel(contrasts)
    idx = find(strcmp(CN, contrasts{k}));
    beta = B(idx);
    se_beta = sqrt(V(idx,idx));
    effects_M2.(contrasts{k}).delta = beta;  % already on Score scale
    effects_M2.(contrasts{k}).CI95  = beta + [-1 1]*1.96*se_beta;
end


CI_L = [effects_M2.Pressure_cat_3.CI95(1), ...
    effects_M2.Pressure_cat_6.CI95(1), ...
    effects_M2.Error.CI95(1)];
CI_U = [effects_M2.Pressure_cat_3.CI95(2), ...
    effects_M2.Pressure_cat_6.CI95(2), ...
    effects_M2.Error.CI95(2)];
delta = [effects_M2.Pressure_cat_3.delta, ...
    effects_M2.Pressure_cat_6.delta, ...
    effects_M2.Error.delta];

Low = delta - CI_L;
High = CI_U - delta;
h4 = errorbar(fh4, 1:numel(delta), delta, Low, High, 'o-', ...
    'Color', 0.1*[1 1 1], ...
    'MarkerFaceColor', 0.1*[1 1 1], ...
    'MarkerEdgeColor', 0.1*[1 1 1], ...
    'MarkerSize', 5, ...
    'LineStyle', 'none', ...
    'LineWidth', 2, ...
    'CapSize', 8);

xlim([1-0.5 numel(delta)+0.5])
ylim([0 8])

y4 = ylim(gca); dy = 0.03*range(y4);
for i = 1:numel(h4.XData)
    txt = sprintf('%.1f\n[%.1f, %.1f]', delta(i), CI_L(i), CI_U(i));
    text(h4.Parent, h4.XData(i), CI_U(i) + dy, txt, ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize', 12, 'BackgroundColor', 'none', 'Margin', 1, 'EdgeColor', 'none');
end

labels = {'P_{Medium} vs. P_{Low}', 'P_{High} vs. P_{Low}', 'Tracking Error'};
xticks(1:numel(delta))
xticklabels(labels)
set(gca, 'XTickLabelRotation', 45)
set(gca, 'FontSize', 16)
set(gca, 'Box', 'off')

% fh4.PlotBoxAspectRatio = [2, 2, 1];
% fh4.DataAspectRatio = [2, 8, 1];

% title
thd4 = title('M2 Model', 'Interpreter', 'tex');
thd4.Position(2) = thd4.Position(2)*1.1;


%% M3 Model
fh5 = nexttile(179, [4, 8]);


M3 = fitlme(tblSub, ['Score ~ 1 + Pressure_cat + Error + EffortIndex + ', ...
                      '(1 + Pressure_cat | Subject_cat)'], ...
                      'FitMethod', 'ML');

dx_err = prctile(tblSub.Error, 90) - ...
    prctile(tblSub.Error, 10);

dx_emg = prctile(tblSub.EffortIndex, 90) - ...
    prctile(tblSub.EffortIndex, 10);

dx = [dx_err, dx_emg];
predNames = {'Error','EffortIndex'}; 

B  = M3.Coefficients.Estimate;
CN = M3.CoefficientNames;
V  = M3.CoefficientCovariance;  % covariance of fixed effects

effects_M3 = struct();

for k = 1:numel(predNames)
    idx = find(strcmp(CN, predNames{k}));
    beta = B(idx);
    se_beta = sqrt(V(idx,idx));

    eff = beta * dx(k);
    se_eff = se_beta * dx(k);

    effects_M3.(predNames{k}).delta = eff;
    effects_M3.(predNames{k}).CI95  = eff + [-1 1]*1.96*se_eff;
end

% Pressure contrasts
contrasts = {'Pressure_cat_3','Pressure_cat_6'};  % Medium-Low, High-Low
for k = 1:numel(contrasts)
    idx = find(strcmp(CN, contrasts{k}));
    beta = B(idx);
    se_beta = sqrt(V(idx,idx));
    effects_M3.(contrasts{k}).delta = beta;  % already on Score scale
    effects_M3.(contrasts{k}).CI95  = beta + [-1 1]*1.96*se_beta;
end


CI_L = [effects.Pressure_cat_3.CI95(1), ...
    effects.Pressure_cat_6.CI95(1), ...
    effects.Error.CI95(1), ...
    effects.EffortIndex.CI95(1)];
CI_U = [effects.Pressure_cat_3.CI95(2), ...
    effects.Pressure_cat_6.CI95(2), ...
    effects.Error.CI95(2), ...
    effects.EffortIndex.CI95(2)];
delta = [effects.Pressure_cat_3.delta, ...
    effects.Pressure_cat_6.delta, ...
    effects.Error.delta, ...
    effects.EffortIndex.delta];

Low = delta - CI_L;
High = CI_U - delta;
h5 = errorbar(fh5, 1:numel(delta), delta, Low, High, 'o-', ...
    'Color', 0.1*[1 1 1], ...
    'MarkerFaceColor', 0.1*[1 1 1], ...
    'MarkerEdgeColor', 0.1*[1 1 1], ...
    'MarkerSize', 5, ...
    'LineStyle', 'none', ...
    'LineWidth', 2, ...
    'CapSize', 8);

xlim([1-0.5 numel(delta)+0.5])
ylim([0 8])

y5 = ylim(gca); dy = 0.03*range(y5);
for i = 1:numel(h5.XData)
    txt = sprintf('%.1f\n[%.1f, %.1f]', delta(i), CI_L(i), CI_U(i));
    text(h5.Parent, h5.XData(i), CI_U(i) + dy, txt, ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize', 12, 'BackgroundColor', 'none', 'Margin', 1, 'EdgeColor', 'none');
end

labels = {'P_{Medium} vs. P_{Low}', 'P_{High} vs. P_{Low}', 'Tracking Error', ...
    'Effort Index'};
xticks(1:numel(delta))
xticklabels(labels)
set(gca, 'XTickLabelRotation', 45)
set(gca, 'FontSize', 16)
set(gca, 'Box', 'off')


% fh5.DataAspectRatio = [4, 20, 1];
% fh5.PlotBoxAspectRatio = [2, 4, 1];

% title
thd5 = title('M3 Model', 'Interpreter', 'tex');
thd5.Position(2) = thd5.Position(2)*1.1;




%% M4 Model
fh6 = nexttile(187, [4, 10]);


M4 = fitlme(tblSub, ['Score ~ 1 + Pressure_cat + Error + ', ...
                      'EffortIndex + Left_Prim_Motor_Theta + ', ...
                      '(1 + Pressure_cat | Subject_cat)'], ...
                      'FitMethod', 'ML');


dx_err = prctile(tblSub.Error, 90) - ...
    prctile(tblSub.Error, 10);

dx_emg = prctile(tblSub.EffortIndex, 90) - ...
    prctile(tblSub.EffortIndex, 10);

dx_eeg = prctile(tblSub.Left_Prim_Motor_Theta, 90) - ...
    prctile(tblSub.Left_Prim_Motor_Theta, 10);

dx = [dx_err, dx_emg, dx_eeg];
predNames = {'Error','EffortIndex','Left_Prim_Motor_Theta'}; 

B  = M4.Coefficients.Estimate;
CN = M4.CoefficientNames;
V  = M4.CoefficientCovariance;  % covariance of fixed effects

effects_M4 = struct();

for k = 1:numel(predNames)
    idx = find(strcmp(CN, predNames{k}));
    beta = B(idx);
    se_beta = sqrt(V(idx,idx));

    eff = beta * dx(k);
    se_eff = se_beta * dx(k);

    effects_M4.(predNames{k}).delta = eff;
    effects_M4.(predNames{k}).CI95  = eff + [-1 1]*1.96*se_eff;
end

% Pressure contrasts
contrasts = {'Pressure_cat_3','Pressure_cat_6'};  % Medium-Low, High-Low
for k = 1:numel(contrasts)
    idx = find(strcmp(CN, contrasts{k}));
    beta = B(idx);
    se_beta = sqrt(V(idx,idx));
    effects_M4.(contrasts{k}).delta = beta;  % already on Score scale
    effects_M4.(contrasts{k}).CI95  = beta + [-1 1]*1.96*se_beta;
end



CI_L = [effects_M4.Pressure_cat_3.CI95(1), ...
    effects_M4.Pressure_cat_6.CI95(1), ...
    effects_M4.Error.CI95(1), ...
    effects_M4.EffortIndex.CI95(1), ...
    effects_M4.Left_Prim_Motor_Theta.CI95(1)];
CI_U = [effects_M4.Pressure_cat_3.CI95(2), ...
    effects_M4.Pressure_cat_6.CI95(2), ...
    effects_M4.Error.CI95(2), ...
    effects_M4.EffortIndex.CI95(2), ...
    effects_M4.Left_Prim_Motor_Theta.CI95(2)];
delta = [effects_M4.Pressure_cat_3.delta, ...
    effects_M4.Pressure_cat_6.delta, ...
    effects_M4.Error.delta, ...
    effects_M4.EffortIndex.delta ...
    effects_M4.Left_Prim_Motor_Theta.delta];

Low = delta - CI_L;
High = CI_U - delta;
h6 = errorbar(fh6, 1:numel(delta), delta, Low, High, 'o-', ...
    'Color', 0.1*[1 1 1], ...
    'MarkerFaceColor', 0.1*[1 1 1], ...
    'MarkerEdgeColor', 0.1*[1 1 1], ...
    'MarkerSize', 5, ...
    'LineStyle', 'none', ...
    'LineWidth', 2, ...
    'CapSize', 8);

xlim([1-0.5 numel(delta)+0.5])
ylim([0 8])

y6 = ylim(gca); dy = 0.03*range(y6);
for i = 1:numel(h6.XData)
    txt = sprintf('%.1f\n[%.1f, %.1f]', delta(i), CI_L(i), CI_U(i));
    text(h6.Parent, h6.XData(i), CI_U(i) + dy, txt, ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontSize', 12, 'BackgroundColor', 'none', 'Margin', 1, 'EdgeColor', 'none');
end

labels = {'P_{Medium} vs. P_{Low}', 'P_{High} vs. P_{Low}', 'Tracking Error', ...
    'Effort Index', 'Left M1 \theta'};
xticks(1:numel(delta))
xticklabels(labels)
set(gca, 'XTickLabelRotation', 45)
set(gca, 'FontSize', 16)
set(gca, 'Box', 'off')


% ylh3 = ylabel(fh3, 'Predicted \DeltaScore', 'FontWeight','bold');
% ylh3.Position(1) = ylh3.Position(1) - 0.3;

% title
thd6 = title('M4 Model', 'Interpreter', 'tex');
thd6.Position(2) = thd6.Position(2)*1.1;

legend({'Value \pm 95% CI'}, 'Box', 'off')



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


% function eegS = load_eeg_subject_cluster(cfg, s, clusterName)
% % EDIT to match your EEG TF storage.
% %
% % Return EMPTY TABLE if subject is not present in this cluster.
% %
% % Expected columns (epoch- or trial-level):
% %   Trial, cfg.condVarName,
% %   TF (cell): each cell [nF x nPct] containing either ratio R or power P
% %   freqHz (cell): [nF x 1]
% %   cyclePct (cell): [1 x nPct] or [nPct x 1]
% %
% % If cfg.TF_is_ratio=false, also provide:
% %   baseF (cell): [nF x 1] baseline/reference vector B(f)
% 
% subStr = cfg.subID_as_string(s);
% eegFile = fullfile(cfg.eegRoot, subStr, "TF_" + string(clusterName) + ".mat"); % example
% 
% if ~exist(eegFile, "file")
%     eegS = table(); % subject not present in this cluster (or file missing)
%     return;
% end
% 
% S = load(eegFile);
% 
% % ---- MAP YOUR STRUCTURE HERE (EDIT) ----
% % Example assumed fields:
% %   S.trialID, S.pressure, S.tf, S.freqHz, S.cyclePct
% eegS = table();
% eegS.Trial = S.trialID(:);
% eegS.(cfg.condVarName) = string(S.pressure(:));
% eegS.TF = S.tf(:);
% 
% eegS.freqHz   = repmat({S.freqHz(:)}, numel(eegS.TF), 1);
% eegS.cyclePct = repmat({S.cyclePct(:)'}, numel(eegS.TF), 1);
% 
% if isfield(S, "baseF")
%     eegS.baseF = repmat({S.baseF(:)}, numel(eegS.TF), 1);
% end
% 
% end

% function eegFeat = extract_band_features_fullcycle_opt2(cfg, eegS)
% % Extract band features using OPTION 2:
% %   feature = 10*log10( mean( R(f,p) over band×cycle ) )
% %
% % R(f,p) is the normalized ratio P/B if cfg.TF_is_ratio=true, else it is computed as P./B.
% 
% freqHz   = eegS.freqHz{1}(:);
% cyclePct = eegS.cyclePct{1}(:)'; % row
% 
% pidx = (cyclePct >= cfg.cycleWindowPct(1)) & (cyclePct <= cfg.cycleWindowPct(2));
% assert(any(pidx), "cycleWindowPct has no overlap with cyclePct axis.");
% 
% nRows = height(eegS);
% 
% % Compute epoch-level scalar features per row
% featPerRow = table();
% featPerRow.Trial = eegS.Trial;
% featPerRow.(cfg.condVarName) = eegS.(cfg.condVarName);
% 
% for b = 1:numel(cfg.bandNamesToUse)
%     bn = cfg.bandNamesToUse(b);
%     flim = cfg.bands.(bn);
% 
%     fidx = (freqHz >= flim(1)) & (freqHz <= flim(2));
%     assert(any(fidx), "Band %s has no overlap with freqHz axis.", bn);
% 
%     v = nan(nRows,1);
% 
%     for i = 1:nRows
%         X = eegS.TF{i};
%         if ~isnumeric(X)
%             continue;
%         end
% 
%         % Convert to ratio R(f,p)
%         if cfg.TF_is_ratio
%             R = X;
%         else
%             B = eegS.baseF{i};    % [nF x 1]
%             R = X ./ B;           % implicit expansion
%         end
% 
%         % Safeguard positivity for log
%         R = max(R, cfg.epsRatio);
% 
%         patch = R(fidx, pidx);
% 
%         % OPTION 2 (mean then log):
%         %   - average normalized TF in linear space over (band×cycle)
%         %   - then convert that scalar to dB
%         v(i) = 10*log10(mean(patch, 'all', 'omitnan'));
%     end
% 
%     featPerRow.("EEG_" + bn + "_opt2_meanFirstLog") = v;
% end

% % Aggregate epochs -> trials (mean across epochs of the scalar)
% if cfg.aggregateEpochsToTrial
%     eegFeat = aggregate_epoch_scalars_to_trial(cfg, featPerRow);
% else
%     eegFeat = featPerRow;
% end
% 
% end

% function eegT = aggregate_epoch_scalars_to_trial(cfg, featPerRow)
% % Aggregates scalar features to one row per trial.
% % Condition is assumed constant within each trial group.
% 
% [G, trialVals, condVals] = findgroups(featPerRow.Trial, featPerRow.(cfg.condVarName));
% 
% eegT = table();
% eegT.Trial = trialVals;
% eegT.(cfg.condVarName) = condVals;
% 
% featCols = setdiff(string(featPerRow.Properties.VariableNames), ["Trial", cfg.condVarName]);
% 
% for k = 1:numel(featCols)
%     col = featCols(k);
%     x = featPerRow.(col);
% 
%     out = nan(height(eegT),1);
%     for g = 1:height(eegT)
%         rows = (G == g);
%         switch lower(cfg.trialAggregation)
%             case "mean"
%                 out(g) = mean(x(rows), 'omitnan');
%             case "median"
%                 out(g) = median(x(rows), 'omitnan');
%             otherwise
%                 error("Unknown cfg.trialAggregation: %s", cfg.trialAggregation);
%         end
%     end
%     eegT.(col) = out;
% end
% end
% 
% function T = zscore_within_subject(T, featureCols)
% % Z-score each feature column within each subject (ignoring NaNs).
% subs = unique(string(T.Subject));
% for si = 1:numel(subs)
%     idx = string(T.Subject) == subs(si);
% 
%     for j = 1:numel(featureCols)
%         c = featureCols(j);
%         x = T{idx, c};
% 
%         if all(ismissing(x)) || std(x, 'omitnan') == 0
%             continue;
%         end
% 
%         mu = mean(x, 'omitnan');
%         sd = std(x,  'omitnan');
%         T{idx, c} = (x - mu) ./ sd;
%     end
% end
% end
% 
% function p = extract_term_pvalue(anovaTbl, termName)
% % Extract p-value for a specific term from fitlme anova table.
% p = NaN;
% if isempty(anovaTbl); return; end
% idx = strcmp(string(anovaTbl.Term), string(termName));
% if any(idx)
%     p = anovaTbl.pValue(find(idx,1,'first'));
% end
% end
% 
% function [p, beta] = extract_fixed_effect(mdl, effectName)
% % Extract p-value and estimate for a fixed effect from mdl.Coefficients.
% p = NaN; beta = NaN;
% C = mdl.Coefficients;
% idx = strcmp(string(C.Name), string(effectName));
% if any(idx)
%     p = C.pValue(find(idx,1,'first'));
%     beta = C.Estimate(find(idx,1,'first'));
% end
% end
