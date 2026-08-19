S5_icatimef = load('-mat', 'S5.icatimef');
S6_icatimef = load('-mat', 'S6.icatimef');
S7_icatimef = load('-mat', 'S7.icatimef');
S8_icatimef = load('-mat', 'S8.icatimef');
S9_icatimef = load('-mat', 'S9.icatimef');
S10_icatimef = load('-mat', 'S10.icatimef');
S11_icatimef = load('-mat', 'S11.icatimef');
S12_icatimef = load('-mat', 'S12.icatimef');
S13_icatimef = load('-mat', 'S13.icatimef');
S14_icatimef = load('-mat', 'S14.icatimef');
S15_icatimef = load('-mat', 'S15.icatimef');
S16_icatimef = load('-mat', 'S16.icatimef');
S17_icatimef = load('-mat', 'S17.icatimef');
S18_icatimef = load('-mat', 'S18.icatimef');


%% checking the TF content

icatimef = S17_icatimef;
comp = 'comp9';
trial_info = icatimef.trialinfo;
conditions = cellfun(@(x) str2double(x), {trial_info.cond} );

timesout = icatimef.times;
freqs = icatimef.freqs;

p1_indx = find(conditions == 1);
p3_indx = find(conditions == 3);
p6_indx = find(conditions == 6);

data = icatimef.(comp);
power = data.*conj(data);

[power_baseline_corrected, baseln, mbase] = ...
    newtimefbaseln(power, timesout, 'baseline', [0 2000], 'verbose', 'off');


power_p1 = power_baseline_corrected(:, baseln, p1_indx);
power_p3 = power_baseline_corrected(:, baseln, p3_indx);
power_p6 = power_baseline_corrected(:, baseln, p6_indx);

mean_power_p1 = mean(power_p1, 3);
mean_power_p3 = mean(power_p3, 3);
mean_power_p6 = mean(power_p6, 3);

mean_power_p1 = 10*log10(mean_power_p1);
mean_power_p3 = 10*log10(mean_power_p3);
mean_power_p6 = 10*log10(mean_power_p6);


% figure;imagesc(timesout, freqs, flipud(mean_power_p1));
% figure; plot(freqs, mbase); xlim([4, 120])

%%
newfreqs = freqs;
newfreqs([18, 57, 89, 133, 172, 212]) = [4, 8, 14, 30, 60, 120];
figure()
tiledlayout(1, 3)

nexttile
pcolor(mean_power_p1, "EdgeColor", "none")
set(gca, 'YTick', [18, 57, 89, 133, 172, 212],'YTickLabel', newfreqs([18, 57, 89, 133, 172, 212]))

nexttile
pcolor(mean_power_p3, "EdgeColor", "none")
set(gca, 'YTick', [18, 57, 89, 133, 172, 212],'YTickLabel', newfreqs([18, 57, 89, 133, 172, 212]))

nexttile
pcolor(mean_power_p6, "EdgeColor", "none")
set(gca, 'YTick', [18, 57, 89, 133, 172, 212],'YTickLabel', newfreqs([18, 57, 89, 133, 172, 212]))
