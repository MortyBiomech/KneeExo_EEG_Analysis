# KneeExo-EEG: analysis code

EEG during a tracking task with a pneumatically actuated knee exoskeleton, at three
levels of physically imposed demand.

This folder holds every analysis step from the raw recordings to the figures in the
manuscript. Two steps required a person's judgement and cannot be recomputed, and a third
cannot be reproduced even by re-running it; their results ship as derived data and the code
reads them back. See **Manual steps** below.

Paths in this document are relative to this folder, `code/`, unless they begin with
`data/`, `docs/` or `external/`, which sit at the repository root:

```
<repo>/
├── code/         this folder, every analysis step
│   └── figures/  the figure and report entry points, stages 7 and 8
├── config -> code/config
├── data/derived/ committed derived data (cfg.derived)
├── figures/      OUTPUT directory written by stage 8 (cfg.figures), not tracked
└── external/     third-party toolboxes as git submodules
```

**Two different folders are called `figures`.** `code/figures/` holds the code.
`<repo>/figures/` is where that code writes its output and is not tracked, because a
figure is rebuilt from the data rather than stored. The stage 7 and 8 entry points named
below are in `code/figures/`; `cfg.figures` points at the output folder.

The distinction matters in `.gitignore`. The rule that hides the output folder must be
anchored, `/figures/` and not `figures/`, because an unanchored pattern matches a folder
of that name at any depth and silently excludes `code/figures/` as well.

---

## Quick start

**To reproduce Figures 3 and 4** you need tier 2 of the data release and nothing else.
Open `figures/run_figure3.m`, press Run, and the script puts itself on the path. No
preprocessing, no AMICA, no clustering.

**Three analyses need nothing at all**, because their inputs are committed in
`data/derived/`:

| Run this | Produces | Reads |
|---|---|---|
| `behaviour/run_results_behaviour.m` | Figure 2, its statistics, the mediation | four small tables |
| `coupling/run_cross_correlation.m` | Figure 5, left parieto-occipital | the pairing, the warped error, the stored result |
| `lmm21/run_lmm21.m` | the closing Results paragraphs and the supplementary tables | the cached feature table |

Each of the three rebuilds its inputs from the decompositions instead if you ask it to,
which needs tier 2; rebuilding the behaviour tables from the raw data needs tiers 3 and 4.

**To re-run the whole chain**, work down the stage table in order. Budget several hours per
participant for AMICA and several hours for the ERSP precompute, and expect to sit in front
of the machine twice in total: once for the flexion and extension editor in stage 2, once
for the component review GUI in stage 4.

You do not need to configure anything to reproduce figures. You need
`config/local_paths.m` only to reach the raw recordings. See **Configuration**.

---

## The pipeline

```
raw XDF
  │  data_processing/run_preprocessing.m                        stage 1
  ▼
BIDS ──► EEGLAB .set ──► events added ──► cleaned ──► AMICA + DIPFIT + ICLabel
  │                                                    │
  │                                                    └──► data_processing/
  │                                                         run_multimodal_trials.m
  │                                                            stage 2, branches off
  │                                                              │
  │                                                              ▼
  │                                                         behaviour/
  │                                                         run_build_masters.m       B1
  │                                                         run_results_behaviour.m   B2
  │                                                              │
  │                                                              ▼
  │                                                         Figure 2, mediation
  │  precompute/run_epoching_timewarp.m                        stage 3
  ▼
epoched datasets carrying EEG.timewarp
  │  study/run_group_clustering.m                              stage 4
  ▼
STUDY ──► preclustered STUDY ──► one clustering solution per region
  │  precompute/run_ersp_precompute.m                          stage 5
  ▼
.icatimef time-frequency decompositions
  │                                                    │
  │                                                    ├──► coupling/
  │                                                    │    run_cross_correlation.m     C1
  │                                                    │       Figure 5
  │                                                    │
  │                                                    └──► lmm21/run_lmm21.m          L1
  │                                                            closing Results paragraphs
  │  compute/run_ersp_stats.m                                  stage 6
  ▼
<Region>_ersp_qc_results.mat            one file per cluster
  │  figures/run_band_pvalue_family.m                          stage 7
  ▼
band_pvalue_family.mat                  one FDR cutoff across clusters x bands
  │  figures/run_figure3.m, figures/run_figure4.m              stage 8
  ▼
figures, statistics reports, manuscript numbers
```

| # | Stage | Entry point | Reads | Writes |
|---|---|---|---|---|
| 1 | Import and preprocessing | `data_processing/run_preprocessing.m` | raw XDF | `sub-N_cleaned_with_ICA.set` |
| 2 | Multimodal trial extraction | `data_processing/run_multimodal_trials.m` | cleaned `.set`, EMG, experiment log | per-trial EEG, EMG and experiment data |
| 3 | Epoching and time warping | `precompute/run_epoching_timewarp.m` | cleaned `.set` | `sub-N_..._epoched.set` with `EEG.timewarp` |
| 4 | STUDY and clustering | `study/run_group_clustering.m` | epoched `.set` | STUDY files, clustering solutions, `SUBJECTS_ICS` |
| 5 | ERSP precompute | `precompute/run_ersp_precompute.m` | STUDY, epoched `.set` | `S<N>.icatimef` |
| 6 | ERSP statistics | `compute/run_ersp_stats.m` | `.icatimef`, STUDY, `SUBJECTS_ICS` | `<Region>_ersp_qc_results.mat` |
| 7 | Band p-value family | `figures/run_band_pvalue_family.m` | every `<Region>_ersp_qc_results.mat` | `band_pvalue_family.mat` |
| 8 | Figures and reports | `figures/run_figure3.m`, `run_figure4.m` | the QC results and the family file | figures, statistics reports |

The behaviour branch, which runs off stage 2 and never rejoins:

| # | Stage | Entry point | Reads | Writes |
|---|---|---|---|---|
| B1 | Master tables | `behaviour/run_build_masters.m` | per-trial EEG, EMG and experiment data | `emg_master_*.mat`, `trk_master_*.mat`, `behaviour_table.mat` |
| B2 | Behaviour results | `behaviour/run_results_behaviour.m` | the masters and the behaviour table | Figure 2, statistics, mediation |

Two further analyses hang off stage 5 rather than continuing the chain. Both read the
single-trial decompositions, and neither feeds anything downstream:

| # | Analysis | Entry point | Reads | Writes | README |
|---|---|---|---|---|---|
| C1 | Power against tracking error across the movement cycle | `coupling/run_cross_correlation.m` | `.icatimef` (stage 5), the epoched experiment data (stage 2), the STUDY (stage 4), `SUBJECTS_ICS` | Figure 5, `epoch_pairing_map.mat`, `tracking_error_warped.mat`, `figure5_coupling_<cluster>.mat` | [`coupling/README.md`](coupling/README.md) |
| L1 | Does trial-level cortical band power predict the rating? | `lmm21/run_lmm21.m` | `.icatimef` (stage 5), `behaviour_table.mat` (B1), `SUBJECTS_ICS`, `epoch_pairing_map.mat` (C1) | `lmm21_features.mat`, the cluster tests, the 21 intervals, the sensitivity grid, two LaTeX tables | [`lmm21/README.md`](lmm21/README.md) |

**Their dependencies differ, which matters if you are running only one of them.** C1 needs
stage 2, stage 4 and stage 5 but never touches the behaviour tables. L1 needs stage 5 and
the behaviour table from B1, and it needs the epoch pairing, which is a C1 artefact: it is
built by `coupling/build_epoch_pairing.m` and cached in `data/derived`. So L1 is downstream
of both branches, while C1 is downstream of neither.

C1 and L1 share `coupling/load_cluster_power.m`, the reader for the single-trial
decompositions, deliberately. One reader for both is what lets the Methods say that the
cross-correlation and the trial-level null describe the same signal. The pairing is shared
for the same reason, and because it reads the `urevent` tables rather than any cluster
solution it is built once and does not need rebuilding when the cluster changes.

**Stage 2 is a branch, not a link in the chain.** It produces the per-trial EEG, EMG and
experiment data that the behaviour branch consumes. Stage 3 goes back to the cleaned
datasets from stage 1. You can skip stage 2 and the whole B branch and still reach the
ERSP figures, and you can run the B branch without ever touching AMICA or the STUDY.

Stages 1, 4 and 5 are the slow ones. Stage 5 runs for hours and writes several gigabytes.

**Stage 7 must see every cluster before stage 8 draws any of them.** The FDR correction runs
across all clusters and all frequency bands at once and collapses to a single cutoff, so
adding or removing a cluster changes the threshold for the clusters that stay. Change the
set of reported clusters and you re-run stage 7 and redraw every figure.

---

## Folders

| Folder | Contents |
|---|---|
| `config/` | `kneeexo_config.m`, the single place any path is written down, plus `add_code_paths.m` and `ersp_params.m` |
| `data_processing/` | XDF import, BIDS conversion, event construction, cleaning, AMICA, per-trial extraction |
| `precompute/` | epoching, time warping, and the ERSP precompute that writes `.icatimef` |
| `study/` | STUDY construction, component screening, preclustering, repeated clustering, anatomical labels |
| `compute/` | ERSP statistics, producing the `.mat` files the figures read |
| `figures/` | the manuscript figures, the statistics reports, and the FDR family. Its output goes to `<repo>/figures/`, which is a different folder |
| `behaviour/` | perceived difficulty, tracking error, muscular effort, mediation, Figure 2. See `behaviour/README.md` |
| `coupling/` | parieto-occipital band power against tracking error across the movement cycle, Figure 5. See `coupling/README.md` |
| `lmm21/` | whether trial-level cortical band power predicts perceived difficulty over and above pressure, error and effort. No figure; it produces the closing Results paragraphs and a supplementary table. See `lmm21/README.md` |
| `common/` | helpers that more than one analysis needs and that belong to none of them: `bh_fdr.m`, Benjamini and Hochberg; `within_subject_scale.m`, within-participant centring and z scoring |
| `vendor/` | third-party and forked functions that run, each with its licence. See `vendor/README.md` |
| `archive/` | superseded code, kept for the record, **never on the path**. See `archive/README.md` |

`../external/` sits outside this folder and holds unmodified toolboxes as git submodules.
See `external/README.md` for why it is not in `vendor/`.

---

## Configuration

`config/kneeexo_config.m` is the only file in the repository that knows a path. Every entry
point calls it. No other script should contain a drive letter.

Each entry point starts with the same three lines, which is why you can press Run on any of
them from a fresh MATLAB:

```matlab
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))), 'config'));
cfg = kneeexo_config();
add_code_paths(cfg);        % or add_code_paths(cfg, 'bemobil') in stages 1 and 4
```

`add_code_paths` adds this folder recursively **except `archive/`**, and adds BeMoBIL only
in the two stages that use it. Do not replace it with `addpath(genpath(...))`: that puts the
superseded code on the path, where `which` will find functions you did not mean to call.

Do not save the repository folders into your MATLAB path. A saved path survives moving or
re-cloning the repository and then silently runs a copy you are not editing.

**To reach the raw data**, copy `config/local_paths_example.m` to `config/local_paths.m` and
set `local.raw`. That file is gitignored, so your machine's paths never enter the
repository. Every field is optional; the toolboxes are auto-detected from the MATLAB path.

---

## Conventions

Every entry point follows the same shape, so a script you have not read before is still
predictable:

- A single `subjects` list at the top, taken from `cfg`, so two stages cannot disagree about
  who is being processed.
- Stage switches next to it, so a later stage can be re-run without repeating an earlier one.
- A per-participant `try`/`catch`, so one broken participant does not end an overnight run.
  Failures are collected and printed at the end.
- No `cd`, no file pickers, no dialogs, except at the two manual steps below.

Two participant lists exist on purpose. `cfg.subjects` is 5 to 18, the group analysis.
Participants 1 to 4 lost most of their EEG recording and are excluded for that reason.
`cfg.subjectsEMG` additionally drops sub-10, which has no usable EMG.

Frequency bands are defined once, in `cfg.bands`: theta 4 to 8, alpha and mu 8 to 14, beta
14 to 30 Hz, plus a gamma band that the reported analyses do not use. The stage 7 FDR
family, `coupling/` and `lmm21/` all read the edges from there and none of them declares
its own, so the three cannot drift apart and then be compared as though they had not.

One detail is not uniform and is worth knowing before you compare numbers across folders.
`coupling/prepare_trial_matrices.m` and `lmm21/lmm21_trial_features.m` take the lower edge
as inclusive and the upper as exclusive, so adjacent bands never share a bin.
`compute/flag_bad_trials.m` includes both edges. That is the only place the convention
differs, and it screens trials rather than forming a feature.

---

## Manual steps

**1. Flexion and extension events (stage 2).** `detect_encoder_peaks` finds the encoder
peaks bounding each knee flexion and extension automatically. The one manual step is
`find_flexion_extension_events.mlapp`, where the experimenter discards the peaks the
detector got wrong. Every movement cycle in the analysis descends from its output.

```
data/derived/Events/sub-N/events_with_FlxExt.txt
data/derived/6_0_Trials_Info_and_Events/sub-N/sub-N_Trials_encoder_events.mat
```

With `rebuild_events = false`, the default, `add_events.m` imports the text file and the app
never opens.

**2. Brain component selection (stage 4).** Components with a dipole inside the brain at 15
percent residual variance or less are screened by ICLabel: taken automatically when the top
class is Brain above 0.5 probability, otherwise placed in a borderline pool that was
inspected one component at a time in `review_components_gui`.

```
data/derived/brain_ic_selection/Brain_PotentialBrain_AcceptedPotentialBrain.mat
data/derived/brain_ic_selection/sub-N/*.png        the accept and reject record
```

`load_brain_ic_selection` reads it back, so you only run the GUI for a participant nobody
has screened. The PNGs are the audit trail for every borderline decision.

The behaviour branch has no manual step. Everything from the per-trial data to Figure 2
runs unattended.

**3. The AMICA decomposition itself.** Not a manual step, but equally impossible to
reproduce. AMICA starts from a random initialisation, so two runs on identical input give
different unmixing matrices and different component numbering. `SUBJECTS_ICS` stores integer
component indices and is therefore valid only for the deposited decomposition: re-running
AMICA and then applying it would analyse the wrong components. This is why the post-AMICA
datasets are published rather than only the raw data.

---

## Data release

| Tier | Contents | Where | Reproduces |
|---|---|---|---|
| 1 | code, event tables, encoder events, component selection, the three behaviour tables, the precomputed Figure 2 curves, the epoch pairing, the warped tracking error, the stored Figure 5 result and the `lmm21` feature cache | this repository | the later stages given tier 2, and on its own the whole behavioural Results including Figure 2, Figure 5 for the left parieto-occipital cluster, and the whole trial-level cortical LMM |
| 2 | `.icatimef`, `SUBJECTS_ICS`, the STUDY files | DOI `<fill in>` | Figures 3 and 4 exactly, Figure 5 for any other cluster, and a rebuild of the `lmm21` features |
| 3 | `sub-N_cleaned_with_ICA.set` with AMICA weights, DIPFIT and ICLabel, the epoched EEG datasets, and the per-subject master files | DOI `<fill in>` | clustering onwards, and the cycle-resolved panels of Figure 2 |
| 4 | raw recordings in BIDS, and the stage 2 per-trial data | `<OpenNeuro accession>` | everything except the manual steps |

Start from tier 2. Download it and point `cfg.raw` at it in `config/local_paths.m`.

---

## Dependencies

| Toolbox | Purpose | Version used |
|---|---|---|
| [EEGLAB](https://github.com/sccn/eeglab) | data structures, ICA, dipole fitting, STUDY | `2026.1.0` |
| [BeMoBIL pipeline](https://github.com/BeMoBIL/bemobil-pipeline) | BIDS import, preprocessing and AMICA wrappers, repeated clustering | commit `4161fd5` (submodule) |
| [xdf-Matlab](https://github.com/xdf-modules/xdf-Matlab) | reading the raw LSL recordings | `v1.14.0` |
| [FieldTrip](https://github.com/fieldtrip/fieldtrip) | dipole fitting, atlas lookup, cluster-based permutation tests | `Fieldtrip-lite 250523` |
| AMICA plugin | ICA decomposition | EEGLAB plugin manager |
| ICLabel plugin | component classification | EEGLAB plugin manager |

BeMoBIL is a git submodule. A fresh clone needs

```bash
git clone --recurse-submodules <this repository>
# or, in a clone you already have:
git submodule update --init
```

MATLAB R2025b, which is the version the Methods section names. Nothing here is known to
need it specifically, but `meanEffectSize` and the `arguments` blocks in `coupling/` and
`lmm21/` both rule out older releases, so treat R2025b as the tested version rather than
the minimum.

MATLAB toolboxes: Statistics and Machine Learning (`knnsearch`, `meanEffectSize`), Image
Processing (`bwboundaries`), Parallel Computing (bootstrap effect sizes).

One known clash: Cleanline depends on Chronux, which ships its own `jackknife()` that
shadows the MATLAB function. If `meanEffectSize` fails inside a bootstrap, that is why.

---

## If something resolves to the wrong file

```matlab
which -all <function name>
```

More than one hit means a shadow. The usual causes are an old analysis folder still in a
saved MATLAB path, `archive/` added by hand, or a second copy of a toolbox inside the
repository. `add_code_paths` warns when BeMoBIL resolves outside `cfg.bemobil`, and
`kneeexo_config` refuses a BeMoBIL copy found inside `cfg.code`.

---

## Citation

`<fill in on acceptance>`

Analysis code by Morteza Khosrotabar, Lauflabor Locomotion Lab, TU Darmstadt.
Several functions derive from work by Noelle Jacobsen, Amanda Studnicki and Joe Gwinn. See
`Credits.md` at the repository root, and the headers in `vendor/` and `archive/`.

Released under GPL-3.0-or-later, because the forked functions it redistributes are
GPL-3.0. See `LICENSE` and `Credits.md` at the repository root.