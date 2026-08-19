% Put config on the MATLAB path first:  addpath('config')  -- see README.
% NOT SHIPPED: this panel plots one raw EEG trace, so it needs the epoched
% data rather than a derived table. Set cfg.raw to your copy of the dataset.
cfg = ansymb_config();
if isempty(cfg.raw)
    error(['This panel reads the epoched EEG for sub-12, which is not ' ...
           'shipped with the repository. Set cfg.raw in ' ...
           'config/ansymb_config.m.']);
end
load(fullfile(cfg.trialsInfo, 'sub-12', 'Epochs_Trial_based.mat'), ...
    'Epochs_Trial_based');


%% 
trial = 20;

ch = 23; % Cz if I'm not wrong
EEG = Epochs_Trial_based{trial}.EEG_stream.Preprocessed.Channels(ch, :);
EEG_time = Epochs_Trial_based{trial}.EEG_stream.Preprocessed.Times;

figure()
plot(EEG_time, EEG, 'LineWidth', 0.5, 'Color', 0.5*[1,1,1])
xlim([EEG_time(1) EEG_time(end)])

ax = gca;
ax.XTick = [];
ax.YTick = [];
ax.Box = 'off';
ax.YAxis.Visible = "off";
ax.XAxis.Visible = "off";


%% 

emg_ch = 3; % Cz if I'm not wrong
EMG = Epochs_Trial_based{trial}.EMG_stream.Sensors_Raw(emg_ch, :);
EMG_time = Epochs_Trial_based{trial}.EMG_stream.Times;

figure()
plot(EMG_time, EMG, 'LineWidth', 0.5, 'Color', 0.5*[1,1,1])
xlim([EMG_time(1) EMG_time(end)])

ax = gca;
ax.XTick = [];
ax.YTick = [];
ax.Box = 'off';
ax.YAxis.Visible = "off";
ax.XAxis.Visible = "off";


%% knee angle

angle = Epochs_Trial_based{trial}.EXP_stream.Encoder_angle;
angle_time = Epochs_Trial_based{trial}.EXP_stream.Times;

figure()
plot(angle_time, angle, 'LineWidth', 2, 'Color', 0.5*[1,1,1])
xlim([angle_time(1) angle_time(end)])

ax = gca;
ax.XTick = [];
ax.YTick = [];
ax.Box = 'off';
ax.YAxis.Visible = "off";
ax.XAxis.Visible = "off";