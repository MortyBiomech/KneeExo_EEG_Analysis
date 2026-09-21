%% check_pam_force_units.m
%  Per-subject diagnostic for the force-angle figure. Plots the stored
%  Force_sensor_TimeWarped raw, sign as stored, against Knee_Angle_TimeWarped,
%  one panel per participant, and prints its range next to F_cal for the
%  same trial and cycle so the two can be compared.

clear; clc;

thisFile = mfilename('fullpath');
if isempty(thisFile) || contains(thisFile, 'LiveEditorEvaluationHelper')
    thisFile = which('check_pam_force_units.m');
end
addpath(fullfile(fileparts(fileparts(thisFile)), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);

subjectsForce = [11 12 15 16 17 18];
colors = [cfg.colors.P1; cfg.colors.P3; cfg.colors.P6];

figure('Color','w','Units','centimeters','Position',[2 2 24 14]);
tiledlayout(2,3,'TileSpacing','compact');

fprintf('%-7s %-4s %-6s %-22s %-22s %-14s\n', 'sub','P','trial', ...
        'warped raw [min max]','F_cal [min max]','warped/F_cal');

for s = 1:numel(subjectsForce)
    sub = subjectsForce(s);
    subDir = ['sub-' num2str(sub)];
    TF = loadOne(fullfile(cfg.expAnalysis, subDir, 'KneeTorque_ForceSensor_data.mat'));
    CF = loadOne(fullfile(cfg.expAnalysis, subDir, 'calibrated_Force.mat'));

    ax = nexttile; hold(ax,'on'); box(ax,'off');
    title(ax, subDir, 'FontWeight','normal');

    for c = 1:3
        % fifth experiment trial at this pressure
        idx = find(cellfun(@(t) strcmp(t.Description,'Experiment') && ...
                                 t.Pressure == cfg.pressures(c), TF));
        if numel(idx) < 5, continue; end
        j = idx(5);
        t = TF{1,j};

        ang = double(t.Knee_Angle_TimeWarped);
        frc = double(t.Force_sensor_TimeWarped);
        for k = 1:size(frc,1)
            plot(ax, ang(k,:), frc(k,:), '-', 'Color', colors(c,:), 'LineWidth', 0.6);
        end

        % compare cycle 1 of this trial with F_cal
        fc = [];
        if j <= numel(CF.F_cal) && ~isempty(CF.F_cal{j})
            fc = double(CF.F_cal{j}{1});
        end
        w = frc(1,:);
        if isempty(fc)
            fprintf('%-7s %-4d %-6d [%8.2f %8.2f]   (no F_cal for this trial)\n', ...
                    subDir, cfg.pressures(c), j, min(w), max(w));
        else
            ratio = range(w) / range(fc);
            fprintf('%-7s %-4d %-6d [%8.2f %8.2f]   [%8.2f %8.2f]   range ratio %.4f\n', ...
                    subDir, cfg.pressures(c), j, min(w), max(w), min(fc), max(fc), ratio);
        end
    end
    xlabel(ax, 'Knee\_Angle\_TimeWarped'); ylabel(ax, 'Force\_sensor\_TimeWarped (as stored)');
end
fprintf('\ncalibration a, b per subject:\n');
for s = 1:numel(subjectsForce)
    CF = loadOne(fullfile(cfg.expAnalysis, ['sub-' num2str(subjectsForce(s))], 'calibrated_Force.mat'));
    fprintf('  sub-%d  a = %.4f  b = %.4f\n', subjectsForce(s), CF.params.a, CF.params.b);
end

function v = loadOne(f)
    S = load(f); n = fieldnames(S); v = S.(n{1});
end