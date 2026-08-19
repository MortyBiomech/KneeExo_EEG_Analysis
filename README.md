# Cortical and neuromuscular correlates of graded physical demand during knee-exoskeleton-assisted tracking

Analysis code for the ANSYMB2024 mobile brain/body imaging (MoBI) study.

Participants performed a seated knee flexion/extension angle-tracking task while
wearing a knee exoskeleton driven by a pneumatic artificial muscle (PAM) at three
assistance pressures (1, 3 and 6 bar). Each trial was rated for perceived
difficulty on a 1–10 scale. Recorded modalities: 64-channel EEG (LiveAmp,
500 Hz), 6-channel EMG (Delsys Trigno, 2000 Hz), and knee encoder, reference
angle and force-sensor signals, all captured together via LSL.

> **Status.** This repository accompanies a manuscript in preparation. Figure
> and section numbers refer to that manuscript and may change before
> publication.

---

## What is here

```
code/            analysis code
  ersp_analysis/ cluster time-frequency analysis (has its own README)
  shared/        helpers used by more than one analysis
  data_processing/  the rest, mirroring the original working tree
config/          ansymb_config.m — every path this analysis needs
data/derived/    derived tables that regenerate the figures (see below)
docs/            pipeline notes and toolbox setup
figures/         output directory, created on first run
```

The raw recordings are not in this repository — they are far too large. **The
derived tables in `data/derived/` reproduce every manuscript figure except
Fig. 1d**, without them; see *What you can run without the dataset* below.
Re-running the pipeline from raw data additionally requires the dataset (see
*Data availability*).

---

## Quick start

```matlab
addpath(genpath('code'));
addpath('config');
cfg = ansymb_config();
```

Nothing needs editing to run from the shipped derived tables. To re-run any
stage from the recordings, set `cfg.raw` in `config/ansymb_config.m` to your
copy of the dataset; every script builds its paths from there, and the ones that
need it say so with a clear error rather than failing deep in a load.

### What you can run without the dataset

| | |
| --- | --- |
| **Runs from `data/derived/`** | Fig. 1a, 1b, 1c, 1e, 1f, Figs. 2–3, Supplementary |
| **Needs `cfg.raw`** | Fig. 1d, the Fig. 1e concept panel (`concep_figure_panel_c.m`, which plots one raw EEG trace), and every upstream stage |

Fig. 1d is the one gap. Its plotting script reads `EMG_Data_timewarped.mat`,
an intermediate of about **2.1 GB** — far past what belongs in a git repository.
Regenerate it by running `main_EMG_detailed_analysis.m` with `cfg.raw` set; it
writes the file into `data/derived/`, after which `main_EMG_detailed_plot.m`
runs normally.

### Further reading

- [docs/pipeline.md](docs/pipeline.md) — how the recordings become the numbers:
  the stages, the order to run them in, and the conventions that will bite you
  (three index spaces sharing field names, the protocol change after sub-9,
  per-analysis subject exclusions).
- [docs/toolboxes.md](docs/toolboxes.md) — external dependencies and how
  `ansymb_config` locates them, including BeMoBIL.
- [code/ersp_analysis/README.md](code/ersp_analysis/README.md) — the cluster
  time-frequency analysis behind Figs. 2–3, and the three EEGLAB forks it uses.

---

## Reproducing the manuscript

| Manuscript element | Script |
| --- | --- |
| Fig. 1a — perceived difficulty by condition | `code/data_processing/Group_Level_PostProcessing/Final_paper_plot_generation/Behavioral_results/main_behavioral_results_plot.m` |
| Fig. 1b — trial RMS tracking error, difference + equivalence tests | `code/.../\_NHB/behavioural_results/main_tracking_error_equivalence.m` |
| Fig. 1c — within-cycle error profile | `code/.../Tracking_error_across_cycle/main_tracking_error_across_cycle.m` |
| Fig. 1d — normalised muscle activity by condition | `code/.../Detailed_Analysis_on_EMG/main_EMG_detailed_analysis.m` |
| Fig. 1e — within-cycle EMG vs PAM engagement | `code/.../PAM_engagement_moments/main_finding_PAM_start_end_engagement.m` |
| Fig. 1f — mediation of difficulty via effort and error | `code/.../\_NHB/full_LMM_Analysis_Err_EMG_EEG/FULL_LMM_PIPELINE_wholeBrainFeatures.m` |
| Figs. 2–3 — cluster ERSPs, RM-ANOVA + cluster permutation | `code/ersp_analysis/main_ersp_pipeline.m`, then `code/.../\_NHB/manual_TF_outlier_removal/rm_anova_cluster_based.m` and `final_figure_for_paper.m` |
| Supplementary — per-subject ratings and error | `code/.../\_NHB/Supplementary_section/plot_perSubject_score_trackErr.m` |

Upstream stages, needed only to regenerate the derived tables from raw data:

| Stage | Script |
| --- | --- |
| 1. Import, preprocessing, AMICA, dipole fitting | `Main.m`, parameters in `BeMoBIL_Configuration.m` |
| 2. Event extraction from the experiment stream | `Main_add_events.m`, `Event_Selection/` |
| 3. Trial info and epoching | `Main_evevnt_and_epoch_selection.m`, `Epoch_Selection/` |
| 4. Group-level repeated k-means clustering per ROI | `Group_Level_PostProcessing/main_group_level_postprocessing.m` |
| 5. EMG structuring, time-warping, feature extraction | `EMG_processing/main_EMG_processing.m` |
| 6. Time-frequency decomposition | `Time_Frequency_Analysis/main_TF_analysis.m` |

### How these scripts are meant to be run

**They are `%%`-section notebooks, not turnkey programs.** They are written to be
stepped through cell by cell in the MATLAB editor, and in several upstream
scripts whole blocks are commented out on purpose because that stage was run
once and its output saved. Pressing *Run* on `main_EMG_processing.m` or
`main_group_level_postprocessing.m` will not reproduce anything — read the
section headers and uncomment the stage you want.

This is how the analysis was actually conducted, and we would rather say so than
present a false façade of one-click reproducibility. The figure-generating
scripts in the table above *do* run directly from the shipped derived data.

Two stages additionally require manual interaction: `find_flexion_extension_events.mlapp`
(event verification) and the manual time-frequency outlier rejection in
`_NHB/manual_TF_outlier_removal/`.

---

## Requirements

MATLAB R2025b or newer, with:

- Statistics and Machine Learning Toolbox
- Signal Processing Toolbox
- Wavelet Toolbox
- Image Processing Toolbox
- Parallel Computing Toolbox
- Bioinformatics Toolbox (for `mafdr`)
- System Identification Toolbox

External toolboxes, not included here — install separately and let
`ansymb_config` find them on the path:

| Toolbox | Version used |
| --- | --- |
| [EEGLAB](https://sccn.ucsd.edu/eeglab/) | 2026.0.0 |
| [FieldTrip](https://www.fieldtriptoolbox.org/) | 20231127 |
| [xdf-Matlab](https://github.com/xdf-modules/xdf-Matlab) | — |
| [BeMoBIL pipeline](https://github.com/BeMoBIL/bemobil-pipeline) | see [docs/toolboxes.md](docs/toolboxes.md) |

EEGLAB plugins: AMICA, ICLabel, dipfit, Zapline-Plus.

---

## Data availability

The derived tables needed to reproduce the figures are in `data/derived/`;
`MANIFEST.csv` records where each came from in the analysis tree. The one
exception is Fig. 1d, noted above.

The raw recordings are not distributed here. See the Data Availability statement
of the manuscript for their location and access conditions.

---

## Licence and citation

Code released under the MIT Licence — see [LICENSE](LICENSE).

If you use this code, please cite the manuscript and this repository; see
[CITATION.cff](CITATION.cff).

---

## Notes and caveats

- Analyses reported here are a subset of those explored during the project.
  Analyses not reported in the manuscript are not included in this repository.
- Subject exclusions differ by analysis and are not interchangeable. The nominal
  list is 5–18; EMG analyses exclude sub-10, which has no usable EMG recording.
  Each script states the list it uses.
- The experimental protocol changed after sub-9 (beep encoding and the timing of
  the pressure change), so code touching raw streams branches on `subject_id > 9`.
