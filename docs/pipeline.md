# Pipeline notes

How the recordings become the numbers behind the manuscript. Folder numbers
below are the pipeline stages: the code addresses them by these literal names,
under whatever you set as `cfg.raw`.

---

## The recording

Each participant (`sub-5` … `sub-18`) performed seated knee flexion–extension
angle-tracking while wearing a knee exoskeleton driven by a pneumatic artificial
muscle at three assistance pressures (1, 3, 6 bar → `P1`/`P3`/`P6`), rating each
trial for perceived difficulty on a 1–10 scale.

Three streams were captured together over LSL into one `.xdf` per session, three
sessions per participant:

| Stream | Channels | Rate |
| --- | --- | --- |
| EEG | 64 (LiveAmp) | 500 Hz |
| EMG | 6 (Delsys Trigno) | 2000 Hz |
| Experiment | knee encoder angle, reference angle, force sensor, beep/trigger | — |

Muscle order is positional everywhere and never stored by name alongside the
data: `Vastus_med_R`, `Rectus_femoris_R`, `Gastrocnemius_R`, `Biceps_femoris_R`,
`Trapezius_R`, `Trapezius_L`, from Delsys sensor ids `[2 3 4 5 6 7]`.

---

## Stages

| Stage folder | Produced by | Contents |
| --- | --- | --- |
| `0_source_data/sub-N/ses-S00X/eeg/*.xdf` | recording | raw LSL streams, plus `Subjects.xlsx` |
| `1_BIDS_data` | `Main.m` → `bemobil_xdf2bids` | BIDS export |
| `2_raw-EEGLAB` | `Main.m` → `bemobil_bids2set` | `sub-N_merged_EEG.set` |
| `3_EEG-preprocessing`, `4_spatial-filters/4-1_AMICA` | BeMoBIL wrappers | cleaning, ICA, dipole fitting |
| `5_single-subject-EEG-analysis` | BeMoBIL wrappers | `sub-N_cleaned_with_ICA.set`; `timewarp_test/Epoched_data` holds the epoched, time-warped sets and the `.icatimef` files |
| `6_0_Trials_Info_and_Events` | `Main_add_events` + `find_flexion_extension_events.mlapp` | `sub-N_Trials_encoder_events.mat` |
| `6_Trials_Info_and_Epoched_data` | `Main_evevnt_and_epoch_selection.m` | `Trials_Info.mat`, `Epochs_*_based.mat` |
| `7_STUDY` | `main_group_level_postprocessing.m` | EEGLAB `.study` files, `multiple_clustering/<ROI>/`, ERSP results |
| `8_Classification/ROIs_features` | classification analysis | `ROIs_*.mat` feature tables |
| `9_EXP_Analysis`, `10_Time_Frequency_Analysis` | `EXP_analysis`, `Time_Frequency_Analysis` | force/torque structures, TF content |

Point `cfg.raw` at the folder containing these and every script finds them.

---

## Order to run things

1. **`data_processing/Main.m`** — one subject at a time. Concatenates the `.xdf`
   sessions, exports to BIDS, converts to EEGLAB, drops the accelerometer
   channels 65–67, loads `chanlocs.ced`, derives events, rejects
   non-experimental periods, then runs BeMoBIL preprocessing and AMICA.
   All parameters live in `BeMoBIL_Configuration.m`.

2. **`Main_add_events.m`** — derives trial events from the experiment stream.
   Event types: `SB_Start_Beep`, `PC_Pressure_Change`, `SM_Start_Move`,
   `FB_Finish_Beep`, `SP_Score_Press`, and the movement events `FlxS`, `FlxE`,
   `ExtS`, `ExtE`. Each event's `desc` ends in `_<trialnumber>`, which is how
   everything downstream re-associates events with trials.

3. **`Main_evevnt_and_epoch_selection.m`** — builds `Trials_Info`, then cuts
   epochs. Only the flexion-to-flexion variant is enabled by default.

4. **`Group_Level_PostProcessing/main_group_level_postprocessing.m`** — builds
   the STUDY, preclusters (dipole weight 3, scalp 1), then runs repeated k-means
   clustering once per anatomical ROI. Each ROI is an MNI coordinate, a cluster
   count and a six-element quality-weight vector.

5. **Analyses**, branching off the epoched data:
   - `code/ersp_analysis/` — cluster time-frequency analysis (its own README)
   - `EMG_processing/main_EMG_processing.m` — RMS/iEMG features, time-warping
   - `Time_Frequency_Analysis/main_TF_analysis.m` — Morlet TF per IC per ROI
   - `Final_paper_plot_generation/` — the manuscript figures and statistics

---

## How to read these scripts

They are `%%`-section notebooks meant to be stepped through cell by cell in the
MATLAB editor, not turnkey programs. In several upstream scripts whole blocks
are commented out **on purpose**, because that stage was run once and its output
saved. Read the section headers before uncommenting anything.

Two stages need a person in the loop: `find_flexion_extension_events.mlapp` for
event verification, and the manual time-frequency outlier rejection in
`_NHB/manual_TF_outlier_removal/`.

---

## Things that will bite you

**Three index spaces, same field names.** `Trials_Info{1,i}.Events` mirrors the
same index fields three times over — once per stream: `EEG_stream.Raw` (indices
into the concatenated raw stream), `EEG_stream.Preprocessed` (latencies in the
cleaned `.set`, after non-experimental segments were cut), `EMG_stream` and
`EXP_stream`. Mixing them up is the single most common source of misalignment
bugs in this project.

**The protocol changed after sub-9.** The beep encoding differs (single vs.
double `diff` values on the trigger channel), the pressure change moves from 2 s
*before* the start beep to 2 s *after*, and epoch structures are saved
differently. Any code touching raw streams needs both branches, hence the
`subject_id > 9` tests scattered through the import stage.

**`Case` 3 vs 4** records whether a trial ends on a high or low encoder peak. It
decides whether the last flexion start is dropped when building flex-to-flex
cycles. Always handle both.

**Subject exclusions are per-analysis and are not interchangeable.** The nominal
list is 5–18. EMG analyses drop sub-10, which has no usable EMG recording.
Corticomuscular coherence drops sub-8 and sub-10. Force-sensor and PAM analyses
only have `[11 12 15 16 17 18]`. Copy the list from the analysis you are
extending rather than assuming.

**Fixed conventions across the manuscript.** Condition colours are
P1 `[1,115,178]/255`, P3 `[222,143,5]/255`, P6 `[148,73,92]/255`. EEG features
use alpha/mu `[8 14]` Hz and beta `[14 30]` Hz over a movement cycle
time-normalised to 0–100 %, where 0–50 % is flexion and 50–100 % is extension.
