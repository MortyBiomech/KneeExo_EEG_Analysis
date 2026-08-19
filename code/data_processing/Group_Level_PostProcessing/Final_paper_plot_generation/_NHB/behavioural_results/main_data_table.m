clc
clear

%% Add paths
addpath(genpath('D:\Morteza\MyProjects\ANSYMB2024\Code'))
data_path = 'D:\Morteza\MyProjects\ANSYMB2024\data\';
epoched_data_path = [data_path, '6_Trials_Info_and_Epoched_data\'];

final_EMG_data_path = [...
'D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab\data_processing', ...
'\Group_Level_PostProcessing\Final_paper_plot_generation\', ...
'Detailed_Analysis_on_EMG\'];
final_Error_data_path = [
    'D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab\data_processing\', ...
    'Group_Level_PostProcessing\Final_paper_plot_generation\', ...
    'Tracking_error_across_cycle\'];

current_path = ['D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab', ...
    '\data_processing\Group_Level_PostProcessing\', ...
    'Final_paper_plot_generation\_NHB\behavioural_results\'];

P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255; %[148, 73, 92]/255;
colors = [P1_color; P3_color; P6_color];


%% Load and manage EMG data for the final table
EMG_subjects = load_emg_data(final_EMG_data_path, current_path);


%% Load and manage tracking error data for the final table
cd(final_Error_data_path)
load("Subjects_Tracking_Error.mat")
cd(current_path)

% ------------------------------------------------------------------------
% Because the outliers were removed separately from EMG and tracking error
% data, now we find the intersect of these two structures and make a common
% dataset with the same trials
% ------------------------------------------------------------------------

subject_list = 5:18;
Err_EMG_subjects = ...
    repmat({struct('trial', [], 'pressure', [], 'score', [], ...
    'rmsErr', [], 'iEMG', [])}, ...
    length(subject_list), 1);
for sub = 1:length(subject_list)
    A = EMG_subjects{sub, 1}.trial;
    B = unique(Subject_Tracking_Error{sub, 1}.trial);
    [C, ia, ib] = intersect(A, B);
    % C  = common values
    % ia = indices in A
    % ib = indices in B
    Err_EMG_subjects{sub}.trial = C;
    Err_EMG_subjects{sub}.pressure = EMG_subjects{sub, 1}.pressure(ia);
    Err_EMG_subjects{sub}.score = EMG_subjects{sub, 1}.score(ia);
    
    Err_EMG_subjects{sub}.iEMG = EMG_subjects{sub, 1}.iEMG_norm(ia, :);

    % filling the Err part
    rmsErr = [];
    for i = 1:length(ib)
        trial = B(ib(i));
        trial_idx = find(Subject_Tracking_Error{sub, 1}.trial == trial);
        rmsErr_epochs = cellfun(@(x) sqrt(mean(x, 2)), ...
            Subject_Tracking_Error{sub, 1}.tracking_error(trial_idx), ...
            'UniformOutput', false);
        rmsErr = cat(1, rmsErr, mean(cell2mat(rmsErr_epochs)));
    end
    Err_EMG_subjects{sub}.rmsErr = rmsErr;

end



%% Creating the Table for LMM analysis
Subject = [];
Trial = [];
Pressure = [];
Error = [];
VastusMed = [];
Recfem = [];
Gastroc = [];
BicepFem = [];
KneeFlexorIndex = [];
KneeExtensorIndex = [];
EffortIndex = []; 
Score = [];

for sub = 1:length(subject_list)
    if isempty(Err_EMG_subjects{sub}.iEMG), continue; end;

    count = length(Err_EMG_subjects{sub}.trial);
    Subject = cat(1, Subject, repmat(subject_list(sub), count, 1));
    Trial = cat(1, Trial, Err_EMG_subjects{sub}.trial);
    Pressure = cat(1, Pressure, Err_EMG_subjects{sub}.pressure);
    Error = cat(1, Error, Err_EMG_subjects{sub}.rmsErr);
    
    VastusMed = cat(1, VastusMed, Err_EMG_subjects{sub}.iEMG(:, 1));
    Recfem = cat(1, Recfem, Err_EMG_subjects{sub}.iEMG(:, 2));
    Gastroc = cat(1, Gastroc, Err_EMG_subjects{sub}.iEMG(:, 3));
    BicepFem = cat(1, BicepFem, Err_EMG_subjects{sub}.iEMG(:, 4));
    
    KneeFlexorIndex = cat(1, KneeFlexorIndex, ...
        Err_EMG_subjects{sub}.iEMG(:, 1) + Err_EMG_subjects{sub}.iEMG(:, 2));
    KneeExtensorIndex = cat(1, KneeExtensorIndex, ...
        Err_EMG_subjects{sub}.iEMG(:, 3) + Err_EMG_subjects{sub}.iEMG(:, 4));

    EffortIndex = cat(1, EffortIndex, ...
        Err_EMG_subjects{sub}.iEMG(:, 1) + ...
        Err_EMG_subjects{sub}.iEMG(:, 2) + ...
        Err_EMG_subjects{sub}.iEMG(:, 3) + ...
        Err_EMG_subjects{sub}.iEMG(:, 4));


    Score = cat(1, Score, Err_EMG_subjects{sub}.score);
end


Error_c = Error - mean(Error);
EffortIndex_c = EffortIndex - mean(EffortIndex);
Pressure_c = Pressure - mean(Pressure);

T = table(Subject, Trial, Pressure, Pressure_c, Error, Error_c, ...
    VastusMed, Recfem, Gastroc, BicepFem, ...
    KneeFlexorIndex, KneeExtensorIndex, ...
    EffortIndex, EffortIndex_c, Score, ...
    'VariableNames', ...
    {'SubjectID', 'Trial', 'Pressure', 'Pressure_c', ...
    'Error', 'Error_c', ...
    'VastusMed', 'Recfem', 'Gastroc', 'BicepFem', ...
    'FlexorIndex', 'ExtensorIndex', ...
    'EffortIndex', 'EffortIndex_c', 'Score'});

T.SubjectID = categorical(T.SubjectID);
T.Pressure  = categorical(T.Pressure);



% save the Behaviour table
save([current_path, 'behavior_table.mat'], "T");



%% Mixed-effects model: Score ~ Pressure + (1|Subject)
formula1 = 'Score ~ Pressure + (1|SubjectID)';
lme_score_pressure = fitlme(T, formula1);

disp(lme_score_pressure)



%% Mixed-effects model: Error ~ Pressure + (1|Subject)
formula2 = 'Error ~ Pressure + (1|SubjectID)';
lme_err_pressure = fitlme(T, formula2);

disp(lme_err_pressure)



%% Mixed-effects model: Score ~ Error + (1|SubjectID)
formula3 = 'Score ~ Error_c + (1|SubjectID)';
lme_score_error = fitlme(T, formula3);

disp(lme_score_error)



%% Full integration model with centred predictors
formula_full = ['Score ~ Pressure + Error_c + EffortIndex_c ' ...
                '+ (1|SubjectID)'];
lme_full = fitlme(T, formula_full);

disp(lme_full)






%% Model Comparison
% Pressure-only
formula_P = 'Score ~ Pressure + (1|SubjectID)';
lme_P = fitlme(T, formula_P);

% Error-only
formula_E = 'Score ~ Error_c + (1|SubjectID)';
lme_E = fitlme(T, formula_E);

% Pressure + Error (without EMG)
formula_PE = 'Score ~ Pressure + Error_c + (1|SubjectID)';
lme_PE = fitlme(T, formula_PE);

% Pressure + Error + EMG (full)
formula_PEE = 'Score ~ Pressure + Error_c + EffortIndex_c + (1|SubjectID)';
lme_PEE = fitlme(T, formula_PEE);

formular_PEMuscles = 'Score ~ Pressure + Error + VastusMed + Recfem + Gastroc + BicepFem + (1|SubjectID)';
lme_PEMuscles = fitlme(T, formular_PEMuscles);


% Compare P vs PE
compare(lme_P, lme_PE)

% Compare PE vs PEE (does EMG add explanatory power?)
compare(lme_PE, lme_PEE)

% Compare E vs PE
compare(lme_E, lme_PE)

compare(lme_PE, lme_PEMuscles)






%% clustering subjects by weights

% % Map categorical pressure to numeric levels
% % Option A: simple ordinal 1/2/3
% pressureLevels = categories(T.Pressure);  % should be {'Low','Med','High'} in order
% % Define numeric codes (you can also use real torque values here)
% pressureCode = containers.Map(pressureLevels, [1 3 6]);  % adapt if needed
% 
% PressureNum = zeros(height(T),1);
% for i = 1:height(T)
%     PressureNum(i) = pressureCode(char(T.Pressure(i)));
% end
% 
% % Add to table and centre it
% T.PressureNum   = PressureNum;
% T.PressureNum_c = T.PressureNum - mean(T.PressureNum);


subs  = categories(T.SubjectID);
nSubs = numel(subs);

betaTable = table('Size',[nSubs 4], ...
    'VariableTypes', {'categorical','double','double','double'}, ...
    'VariableNames', {'SubjectID','b_Pressure','b_Error','b_Effort'});

for s = 1:nSubs
    sid = subs{s};
    idx = T.SubjectID == sid;
    Ts  = T(idx, :);

    % Fit per-subject linear model
    % You can add 'RobustOpts','on' if you want robust regression
    mdl = fitlm(Ts, 'Score ~ PressureNum_c + Error_c + EffortIndex_c', ...
        'RobustOpts','off');

    % Extract coefficients (ignore intercept)
    coefs = mdl.Coefficients.Estimate;
    names = mdl.Coefficients.Row;

    bP = NaN; bE = NaN; bEMG = NaN;
    for k = 1:numel(names)
        switch names{k}
            case 'PressureNum_c'
                bP = coefs(k);
            case 'Error_c'
                bE = coefs(k);
            case 'EffortIndex_c'
                bEMG = coefs(k);
        end
    end

    betaTable.SubjectID(s) = sid;
    betaTable.b_Pressure(s) = bP;
    betaTable.b_Error(s)    = bE;
    betaTable.b_Effort(s)   = bEMG;
end

disp(betaTable)


% Matrix of weights: rows = subjects, columns = [Pressure, Error, Effort]
W = [betaTable.b_Pressure, betaTable.b_Error, betaTable.b_Effort];

% Z-score each column (so all predictors have comparable scale)
Wz = zscore(W);   % same size as W

% Choose number of clusters (start with k=2 or 3)
k = 3;

% Run k-means with multiple replicates for stability
rng(1);  % for reproducibility
[idx_clusters, C] = kmeans(Wz, k, 'Replicates', 100);

% Add cluster labels back to table
betaTable.Cluster = categorical(nan(height(betaTable),1));
betaTable.Cluster = categorical(idx_clusters);
disp(betaTable)

colorClusters = lines(6);
figure;
gscatter(W(:,1), W(:,3), idx_clusters, colorClusters(4:6, :));
xlabel('Pressure weight');
ylabel('Effort weight');
title('Clusters in Pressure vs Effort weight space');
grid on;
axis square

figure;
gscatter(W(:,2), W(:,3), idx_clusters, [], 'o', 8);
xlabel('Error weight');
ylabel('Effort weight');
title('Clusters in Error vs Effort weight space');
grid on;
axis square



clusterMeans = zeros(k,3);
for c = 1:k
    clusterMeans(c,:) = mean(W(idx_clusters == c, :), 1);
end

figure;
bar(clusterMeans');
set(gca, 'XTickLabel', {'Pressure','Error','Effort'});
xlabel('Predictor');
% ylabel('Mean weight (z-score)');
ylabel('Mean weight');
legend(arrayfun(@(x) sprintf('Cluster %d',x), 1:k, 'UniformOutput', false));
title('Average evaluation weights per cluster');
grid on;

sil = silhouette(Wz, idx_clusters);
meanSil = mean(sil)

[coeff,score,~,~,expl] = pca(Wz);
figure; gscatter(score(:,1), score(:,2), idx_clusters);
xlabel(sprintf('PC1 (%.1f%%)', expl(1)));
ylabel(sprintf('PC2 (%.1f%%)', expl(2)));
title('Subject clusters in PCA space');
grid on;


grpstats(T.Score, betaTable.Cluster)




%% Mediation Analysis
% (1) Total effect: Difficulty ~ Pressure
lme_tot = fitlme(T, 'Score ~ PressureNum_c + (1|SubjectID)');
disp(lme_tot)

% (2) Path a: Effort ~ Pressure
lme_a = fitlme(T, 'EffortIndex_c ~ PressureNum_c + (1|SubjectID)');
disp(lme_a)

% (3) Paths b & c': Difficulty ~ Pressure + Effort
lme_b = fitlme(T, ...
    'Score ~ PressureNum_c + EffortIndex_c + (1|SubjectID)');
disp(lme_b)



% Get coefficients
a  = getFE(lme_a,  'PressureNum_c');       % Pressure -> Effort
b  = getFE(lme_b,  'EffortIndex_c');       % Effort -> Score (controlling Pressure)
c  = getFE(lme_tot,'PressureNum_c');       % total effect
cp = getFE(lme_b,  'PressureNum_c');       % direct effect (c')

indirect_ab = a * b;

fprintf('Total effect c        = %.4f\n', c);
fprintf('Direct effect c''      = %.4f\n', cp);
fprintf('Indirect effect a*b   = %.4f\n', indirect_ab);




%% mediation analysis within each cluster, including (recommended) 
% subject-level bootstrap CIs for the indirect effect

% Ensure SubjectID types are compatible
T.SubjectID = categorical(T.SubjectID);
betaTable.SubjectID = categorical(betaTable.SubjectID);

% Map SubjectID -> Cluster
[tf, loc] = ismember(T.SubjectID, betaTable.SubjectID);
assert(all(tf), 'Some SubjectIDs in T are missing from betaTable.');

T.Cluster = betaTable.Cluster(loc);  % adds cluster label per trial
T.Cluster = categorical(T.Cluster);

% Sanity check:
summary(T.Cluster)
groupsummary(T, {'Cluster','PressureNum_c'}, 'numel', 'Score');



% Set reference level to the largest cluster (change as needed)
% Suppose clusters are '1','2','3' and you want '3' as reference:
% reference becomes first category in MATLAB coding
T.Cluster = reordercats(T.Cluster, {'3','1','2'});  


lme_effInt = fitlme(T, ...
    'Score ~ PressureNum_c + Error_c + EffortIndex_c*Cluster + (1|SubjectID)');

disp(lme_effInt)
anova(lme_effInt)  % omnibus tests for fixed effects

% Fixed effects and names
fe = fixedEffects(lme_effInt);
cn = lme_effInt.CoefficientNames;

% Helper: get coefficient by name
getb = @(name) fe(strcmp(cn,name));

% Base (reference cluster) effort slope
b_eff_ref = getb('EffortIndex_c');

% Differences for other clusters (names depend on your category labels)
% Inspect cn to confirm exact strings.
b_eff_cl1 = b_eff_ref + getb('EffortIndex_c:Cluster_1');
b_eff_cl2 = b_eff_ref + getb('EffortIndex_c:Cluster_2');

fprintf('Effort slope (Cluster ref=3): %.4f\n', b_eff_ref);
fprintf('Effort slope (Cluster 1):     %.4f\n', b_eff_cl1);
fprintf('Effort slope (Cluster 2):     %.4f\n', b_eff_cl2);



% Formal test: Do effort slopes differ across clusters?
% This is the omnibus test for the interaction. Best practice is to 
% compare models with and without the interaction:

lme_noInt = fitlme(T, ...
    'Score ~ PressureNum_c + Error_c + EffortIndex_c + Cluster + (1|SubjectID)');

compare(lme_noInt, lme_effInt)  % LR test for adding Effort*Cluster


% Interaction Model B: Does pressure→effort differ by cluster?
% Model:
%         Effort∼Pressure×Cluster+(1∣Subject)

lme_pressEffInt = fitlme(T, ...
    'EffortIndex_c ~ PressureNum_c*Cluster + (1|SubjectID)');

disp(lme_pressEffInt)
anova(lme_pressEffInt)



% Model comparison (interaction vs no interaction)
lme_pressEff_noInt = fitlme(T, ...
    'EffortIndex_c ~ PressureNum_c + Cluster + (1|SubjectID)');

compare(lme_pressEff_noInt, lme_pressEffInt)


% Extract pressure→effort slopes per cluster
fe2 = fixedEffects(lme_pressEffInt);
cn2 = lme_pressEffInt.CoefficientNames;
getb2 = @(name) fe2(strcmp(cn2,name));

b_p_ref = getb2('PressureNum_c');
b_p_cl1 = b_p_ref + getb2('PressureNum_c:Cluster_1');
b_p_cl2 = b_p_ref + getb2('PressureNum_c:Cluster_2');

fprintf('Pressure->Effort slope (Cluster ref=3): %.4f\n', b_p_ref);
fprintf('Pressure->Effort slope (Cluster 1):     %.4f\n', b_p_cl1);
fprintf('Pressure->Effort slope (Cluster 2):     %.4f\n', b_p_cl2);




%% Bootstrapping 

% SETTINGS
nBoot = 2000;
rng(1);

T.SubjectID = categorical(T.SubjectID);
subs = categories(T.SubjectID);
nS   = numel(subs);

% Preallocate
ab_boot   = nan(nBoot,1);
c_boot    = nan(nBoot,1);
cp_boot   = nan(nBoot,1);
a_boot    = nan(nBoot,1);
b_boot    = nan(nBoot,1);
prop_boot = nan(nBoot,1);


for it = 1:nBoot
    % Resample subjects WITH replacement
    resSubs = subs(randi(nS, nS, 1));

    % Build bootstrap table Tb by concatenating trials for each sampled subject
    Tb = T([],:);  % empty table with same vars
    for s = 1:nS
        sid = resSubs{s};
        Tb  = [Tb; T(T.SubjectID == sid, :)]; %#ok<AGROW>
    end

    % Fit mediation models on Tb
    lme_tot = fitlme(Tb, 'Score ~ PressureNum_c + (1|SubjectID)');
    lme_a   = fitlme(Tb, 'EffortIndex_c ~ PressureNum_c + (1|SubjectID)');
    lme_dir = fitlme(Tb, 'Score ~ PressureNum_c + EffortIndex_c + (1|SubjectID)');

    c  = getCoef(lme_tot,'PressureNum_c');
    a  = getCoef(lme_a,  'PressureNum_c');
    b  = getCoef(lme_dir,'EffortIndex_c');
    cp = getCoef(lme_dir,'PressureNum_c');

    c_boot(it)  = c;
    a_boot(it)  = a;
    b_boot(it)  = b;
    cp_boot(it) = cp;

    ab_boot(it) = a*b;

    if abs(c) > 1e-12
        prop_boot(it) = (a*b)/c;
    end
end

% Summaries
CI = @(x) prctile(x,[2.5 50 97.5]);

CI_ab = CI(ab_boot);
CI_c  = CI(c_boot);
CI_cp = CI(cp_boot);

prop_ok = prop_boot(isfinite(prop_boot));
CI_prop = prctile(prop_ok,[2.5 50 97.5]);

fprintf('Indirect a*b: median %.4f, 95%% CI [%.4f, %.4f]\n', CI_ab(2), CI_ab(1), CI_ab(3));
fprintf('Total c:      median %.4f, 95%% CI [%.4f, %.4f]\n', CI_c(2),  CI_c(1),  CI_c(3));
fprintf('Direct c'':   median %.4f, 95%% CI [%.4f, %.4f]\n', CI_cp(2), CI_cp(1), CI_cp(3));
fprintf('Prop med:     median %.3f, 95%% CI [%.3f, %.3f]\n', CI_prop(2), CI_prop(1), CI_prop(3));




















%%
figure()
plot(Subject(Pressure == 1)-0.15, EffortIndex(Pressure == 1), ...
    'Marker', 'o', 'LineStyle', 'none', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', colors(1, :));
hold on
plot(Subject(Pressure == 3), EffortIndex(Pressure == 3), ...
    'Marker', 'o', 'LineStyle', 'none', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', colors(2, :));
plot(Subject(Pressure == 6)+0.15, EffortIndex(Pressure == 6), ...
    'Marker', 'o', 'LineStyle', 'none', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', colors(3, :));

figure()
plot(Subject(Pressure == 1)-0.15, Error(Pressure == 1), ...
    'Marker', 'o', 'LineStyle', 'none', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', colors(1, :));
hold on
plot(Subject(Pressure == 3), Error(Pressure == 3), ...
    'Marker', 'o', 'LineStyle', 'none', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', colors(2, :));
plot(Subject(Pressure == 6)+0.15, Error(Pressure == 6), ...
    'Marker', 'o', 'LineStyle', 'none', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', colors(3, :));

figure()
plot(Subject(Pressure == 1)-0.15, BicepFem(Pressure == 1), ...
    'Marker', 'o', 'LineStyle', 'none', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', colors(1, :));
hold on
plot(Subject(Pressure == 3), BicepFem(Pressure == 3), ...
    'Marker', 'o', 'LineStyle', 'none', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', colors(2, :));
plot(Subject(Pressure == 6)+0.15, BicepFem(Pressure == 6), ...
    'Marker', 'o', 'LineStyle', 'none', 'MarkerEdgeColor', 'none', ...
    'MarkerFaceColor', colors(3, :));












%%
fs = 5000;        % example: 500 Hz sampling rate
t = 0:1/fs:20;
x  = sin(2*pi*1*t); % your time-series vector

% Parameters (you can tune these)
% winLen   = 10 * fs;            % window length in samples (e.g. 2-second windows)
% window   = hamming(winLen);   % window function
% noverlap = round(0.5 * winLen); % 50% overlap
% nfft     = [];                % [] lets MATLAB choose, or set e.g. nfft = 2^nextpow2(winLen);

% % Compute PSD
% [Pxx, f] = pwelch(x, window, noverlap, nfft, fs);
% 
% % Plot
% figure;
% plot(f, 10*log10(Pxx));
% xlim([0 2])

% [Px_per, f_per] = periodogram(x, [], [], fs);
% 
% figure;
% plot(f_per, 10*log10(Px_per));
% xlim([0 2])

N = length(x);     % number of samples

% Optional: remove mean to avoid a large DC peak
x = x - mean(x);

% Compute FFT
X = fft(x);        % complex spectrum, length N

% Frequency vector (two-sided, from 0 to fs-Δf)
f = (0:N-1) * (fs/N);


% Single-sided spectrum
Nhalf = floor(N/2) + 1;

X_single = X(1:Nhalf);           % keep positive frequencies
f_single = f(1:Nhalf);

% Scale amplitude to preserve signal energy
A_single = abs(X_single) / N;    % basic normalization

% For amplitude spectrum of real signal, multiply non-DC/non-Nyquist bins by 2
A_single(2:end-1) = 2 * A_single(2:end-1);

% Plot
figure;
plot(f_single, A_single);
xlim([0 2])










