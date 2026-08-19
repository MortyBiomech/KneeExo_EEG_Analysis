% plot the Figure1-b panel of the main paper
% Author: Morteza Khosrotabar, 05.08.2026


load(['D:\Morteza\MyProjects\ANSYMB2024\Code\Matlab\data_processing\', ...
    'Group_Level_PostProcessing\Final_paper_plot_generation\', ...
    'PAM_engagement_moments\Subjects_Force_Angle_warped.mat']);
S = 4;
pressures = Subject_Force_Angle_warped{S,2}.pressure;
P1_indx = find(pressures == 1);
P3_indx = find(pressures == 3);
P6_indx = find(pressures == 6);

angle_P1 = mean(Subject_Force_Angle_warped{S,2}.angle(P1_indx, :), 1);
angle_P3 = mean(Subject_Force_Angle_warped{S,2}.angle(P3_indx, :), 1);
angle_P6 = mean(Subject_Force_Angle_warped{S,2}.angle(P6_indx, :), 1);

figure()
cycle = linspace(0,100, 100);
plot(cycle, angle_P1)
hold on
plot(cycle, angle_P3)
plot(cycle, angle_P6)

force_P1 = mean(Subject_Force_Angle_warped{S,2}.force(P1_indx, :), 1);
force_P3 = mean(Subject_Force_Angle_warped{S,2}.force(P3_indx, :), 1);
force_P6 = mean(Subject_Force_Angle_warped{S,2}.force(P6_indx, :), 1);

figure()
cycle = linspace(0,100, 100);
plot(cycle, force_P1-min(force_P1))
hold on
plot(cycle, force_P3-min(force_P3))
plot(cycle, force_P6-min(force_P6))


%%
figure()

P1_color = [1, 115, 178]/255;
P3_color = [222, 143, 5]/255;
P6_color = [148, 73, 92]/255;

LinS = 5; % line Size
yyaxis right
plot(cycle, angle_P1, 'LineWidth', LinS, 'Color', P1_color, 'LineStyle', '--')
hold on
plot(cycle, angle_P3, 'LineWidth', LinS, 'Color', P3_color, 'LineStyle', '--')
plot(cycle, angle_P6, 'LineWidth', LinS, 'Color', P6_color, 'LineStyle', '--')
set(gca, 'YTick', [])
min_angle = min([angle_P1, angle_P3, angle_P6]);
max_angle = max([angle_P1, angle_P3, angle_P6]);
ylim([min_angle-0.05*abs(max_angle-min_angle) max_angle+0.05*abs(max_angle-min_angle)])


yyaxis left
plot(cycle, force_P1-min(force_P1)+1, 'LineWidth', LinS, 'Color', P1_color, 'LineStyle', '-')
hold on
plot(cycle, force_P3-min(force_P3)+1, 'LineWidth', LinS, 'Color', P3_color, 'LineStyle', '-')
plot(cycle, force_P6-min(force_P6)+1, 'LineWidth', LinS, 'Color', P6_color, 'LineStyle', '-')
set(gca, 'YTick', [])
max_force = max([force_P1-min(force_P1), force_P3-min(force_P3), force_P6-min(force_P6)]);
ylim([-1 max_force+5])

set(gca, 'Box', 'off')
set(gca, 'XTick', [0, 25, 50, 75, 100])

set(gca, 'FontName', 'Arial', 'FontSize', 22)

xlabel('Cycle (%)')
ax = gca;
ax.YAxis(1).Visible = 'off';   
ax.YAxis(2).Visible = 'off';  

ax.TickLength = [0.005 0.025];
ax.LineWidth = 4;
box off