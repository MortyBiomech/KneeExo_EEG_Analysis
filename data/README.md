# data/

What lives here: **anything a reproducer needs that they cannot regenerate
from what they have.** Mostly that means the decisions a person made by hand,
which no amount of computing recovers. It also covers three small tables that
are computable in principle but only from data most people will never
download.

Everything else is either a large input you fetch from the deposit or an
output the code writes, and neither belongs in the repository.

```
data/
└── derived/                                    tracked in git, a few MB
    ├── Events/
    │   └── sub-<N>/
    │       ├── events_with_FlxExt.txt          the event table add_events imports
    │       └── sub-<N>_Trials_encoder_events.mat   the curated encoder events
    ├── brain_ic_selection/
    │   ├── Brain_PotentialBrain_AcceptedPotentialBrain.mat
    │   └── sub-<N>/
    │       ├── Brain_ICs_50percentUp - Accepted_potential_Brain_ICs - sub-<N>.mat
    │       ├── accepted_subject_<N>_IC_<k>.png
    │       └── rejected_subject_<N>_IC_<k>.png
    ├── Subjects_ICs_in_clusters.mat
    ├── emg_master_index.mat                    tables and flags, no signals
    ├── trk_master_index.mat
    ├── behaviour_table.mat                     one row per trial
    └── figure2_precomputed.mat                 cycle curves and permutation results
```

`cfg.derived` points here. Nothing in the code writes a path to this folder by
hand.

## What each one is, and why it cannot be recomputed

**`Events/sub-<N>/events_with_FlxExt.txt`**
Tab-separated: type, latency, description. Every movement cycle in the
analysis descends from this file. `detect_encoder_peaks` finds the encoder
peaks automatically, but `find_flexion_extension_events.mlapp` is where the
experimenter discarded the ones the detector got wrong, and that judgement
exists nowhere else. `add_events.m` imports this file whenever
`rebuild_events = false`, which is the default, and the apps never open.

Ship `events_basic.txt` only if you want to; `add_events` writes it on the way
and it is fully derivable.

**`Events/sub-<N>/sub-<N>_Trials_encoder_events.mat`**
The same events per trial, in the form `build_trial_info` and the epoching
read. Same provenance as the text file, so the two sit side by side.

In the working tree these live under `6_0_Trials_Info_and_Events`, a folder
named after the pipeline stage that writes them. That numbering is useful
while you are computing and useless to somebody reading the deposit, so the
published copy drops it. `resolve_derived_file` checks the shipped folder
first and the working one second, which is what lets both layouts coexist.

**`brain_ic_selection/`**
`Brain_PotentialBrain_AcceptedPotentialBrain.mat` holds the `ICs` table:
column 1 taken automatically by ICLabel, column 2 the borderline pool, column
3 the borderline components a person accepted after looking at each one in
`pop_prop_extended`. Column 3 is the irreplaceable part.

The PNGs are the audit trail: one image per accept and per reject decision.
They make a judgement call inspectable by someone who was not in the room,
which is the only thing that can be offered in place of reproducibility. Keep
them.

**A warning about that file.** If its third column is empty, it was saved by
the old `cortical_ICs_indentifier`, which passed the table to the GUI by value
and then wrote its own untouched copy; the accepted components only ever
reached the base workspace through `assignin`. Rebuild the combined file from
the per-participant files instead. `load_brain_ic_selection` errors with this
explanation rather than running on an empty column.

**`Subjects_ICs_in_clusters.mat`**
`SUBJECTS_ICS`: which single component each participant contributes to each
cluster. This is the one that is irreplaceable for a subtle reason. AMICA
starts from a random initialisation, so re-running it gives different
component numbering. These integer indices are valid **only** for the
deposited decomposition. Re-run AMICA and apply this file, and you analyse the
wrong components, silently and plausibly.

It must also come from the same clustering as the `.study` files in
`p.roiStudyFiles`. A stale copy is the single easiest way to get quietly wrong
results in stage 6.

## The four committed outputs

Four files here are outputs, and they are committed anyway. Together they mean
a fresh clone runs `behaviour/run_results_behaviour.m` end to end, producing
every behavioural number, every statistic, the whole mediation and all of
Figure 2, with nothing downloaded at all.

The test they pass is not "cannot be recomputed". It is **cannot be recomputed
by somebody who has only the repository**, which is the version of the
question that matters to a reader.

**`emg_master_index.mat`, `trk_master_index.mat`, `behaviour_table.mat`**
Every row and every quality flag, but no waveforms, which is why they are
small. Recomputing them needs the stage 2 per-trial data.

**`figure2_precomputed.mat`**
The per-subject condition curves for the four muscles and for tracking error,
plus the cluster-based permutation results and the effect-size traces. It
exists because its two inputs are both expensive in different ways: the curves
are built from the per-subject master files, which run to gigabytes, and the
permutation tests take minutes and get rerun on every styling change. The
result is a few hundred kB, since a curve is 13 participants by 4 muscles by
200 samples by 3 conditions.

It also carries the settings it was built under: the screening policy, the
warp grid, the permutation count and the random seed. `run_results_behaviour`
compares them against its own and refuses the file if any differ, rather than
plotting a curve that describes a different analysis. Set
`USE_PRECOMPUTED = false` to rebuild, which needs the per-subject masters.

**A committed output can go stale silently.** Change a flag in a builder and
the committed table still loads, still has the right columns, and is quietly
wrong. Nothing about it looks off. So each table carries a `stamp` struct
saying when it was built, by which builder, that builder's file date, the git
commit, and the subject list:

```matlab
S = load(fullfile(cfg.masters, 'emg_master_index.mat'), 'stamp');
disp(S.stamp)
```

If `builderModified` is older than `build_emg_master.m` on disk, the table
predates the code and should be rebuilt. Rebuild after any change to a
builder or to `screen_epochs`, and commit the new files in the same commit as
the code change, so the two never separate. `figure2_precomputed.mat` goes
further and enforces this for its own settings, but a stamp still has to be
read by a person.

Keep an eye on size. Binary `.mat` files do not delta well in git, so every
rebuild adds its full size to the history. A few MB each is fine; if an index
table grows past about twenty, move it to the deposit instead.

## What does not go here

**Anything under `cfg.raw`.** The recordings and their intermediates are tens
to hundreds of gigabytes and live wherever you set `local.raw` in
`config/local_paths.m`, outside the repository entirely:

```
0_source_data   1_BIDS_data   2_raw-EEGLAB   3_EEG-preprocessing
4_spatial-filters   5_single-subject-EEG-analysis
6_0_Trials_Info_and_Events   6_Trials_Info_and_Epoched_data
7_STUDY   7_Master_Tables   8_Classification   9_EXP_Analysis
10_Time_Frequency_Analysis
```

The event files are the one deliberate duplication. The full working copy of
`6_0_Trials_Info_and_Events` sits under `cfg.raw` with everything else it
holds; the two small per-participant files are copied into `data/derived/Events/`
so a reproducer has them without the rest. `resolve_derived_file` looks in the
shipped folder first and falls back to the working one.

**Anything the code writes.** The `.icatimef` files, the `.set` datasets, the
`*_ersp_qc_results.mat` files and `band_pvalue_family.mat` are outputs.
Outputs are regenerated, not tracked; figures go to `<repo>/figures`.

The master tables are the clearest case. `cfg.masters` is
`<cfg.raw>/7_Master_Tables`, so they sit **inside your data folder, not inside
the repository**, and a fresh clone has none of them. That is correct:
`run_build_masters.m` rebuilds all three from the stage 2 trial data in a few
minutes, and `emg_master_sub-<N>.mat` carries every epoch's raw signal, so the
set runs to gigabytes. Depositing them would be depositing a cache.

If `behaviour/` reports that a master is missing, the answer is always to run
`run_build_masters.m`, never to copy a `.mat` file into `data/derived`.

**Anything large.** If a file is over a few MB, it is almost certainly an
intermediate and belongs in the data release rather than in git. The whole of
`data/derived/` should be a few megabytes, dominated by the PNGs.

## Files that used to be here

The pre-rebuild working copy of this folder held fourteen more files. None is
deleted lightly and none should come back, so here is where each went.

| File | Replaced by |
|---|---|
| `EMG_Data_timewarped.mat` (2.1 GB) | `emg_master_sub-<N>.mat` under `cfg.masters` |
| `Subjects_Tracking_Error.mat` | `trk_master_sub-<N>.mat` |
| `Subjects_Force_Angle.mat`, `..._warped.mat` | not read by any current analysis |
| `Subjective_Scores.mat`, `Tracking_Errors.mat` | columns of `behaviour_table.mat` |
| `behaviour_table.mat` | rebuilt by `run_build_masters`, and the current copy is committed with a provenance stamp |
| `EEG_features.mat`, `EEG_features_wholeBrain.mat` | the classification stage, not this manuscript |
| `stats.mat` | nothing reads it |

**`All_scores_trackErr.mat` is the one to understand rather than just delete.**
Its `meanScores` and `stdScores` were corrupted: they systematically
underestimated the Medium and High condition means for subjects 11 to 18, by
up to 1.49 rating points. The fault was found through a variance consistency
check, since pooling trials adds between-subject variance to within-subject
variance and so the pooled SD can never be smaller than the mean
within-subject SD. It was, which meant the two quantities had been computed
from different data. Do not reintroduce those variables, and treat any
analysis that used them as needing to be re-run.

**Why the big ones cannot stay.** `EMG_Data_timewarped.mat` alone is 2.1 GB.
GitHub refuses any file over 100 MB, so the repository cannot be pushed while
it is present. Everything on that list is either regenerable from the masters
or belongs to an analysis outside this manuscript, which is why none of it is
a loss.

## The data release

The repository is tier 1 of a four-tier release. The other three are
downloads, and `config/local_paths.m` is where you point at them:

| Tier | Contents | Reproduces |
|---|---|---|
| 1 | this folder, plus the code | the later stages, given tier 2 |
| 2 | `.icatimef`, `SUBJECTS_ICS`, the STUDY files | Figures 3 and 4 exactly. The behavioural numbers already come from tier 1 |
| 3 | cleaned `.set` with AMICA, DIPFIT and ICLabel; the epoched EEG datasets; the per-subject `emg_master_sub-<N>.mat` and `trk_master_sub-<N>.mat` | clustering onwards, and the cycle-resolved panels of Figure 2 |
| 4 | raw recordings in BIDS, and the stage 2 per-trial data | everything except the manual steps |

Most people want tier 2, and then they never run anything in
`data_processing/` at all.

**Why the masters are split.** The index tables carry every row and flag but
no signals, so they come to a few MB, answer every question the Results
paragraphs ask, and ship with the code. The per-subject files carry `Sig`,
each epoch's raw four-channel EMG, so they run to gigabytes and are needed for
one thing only: the cycle-resolved curves and their cluster permutation tests.
Charging a reproducer gigabytes for the condition means would be the wrong
default.

The per-subject masters are deposited rather than left to be rebuilt because
the stage 2 trial data they come from also holds the EEG epochs and so is
considerably larger. Depositing the extract is cheaper than depositing its
source. If tier 4 is published in full, the masters become a convenience
rather than a necessity.

## .gitignore

```
data/raw/
data/**/*.set
data/**/*.fdt
data/**/*.icatimef
data/**/*.study
code/config/local_paths.m
```

The first line is defensive: nobody should put raw data under `data/`, and if
somebody does, git should not take it.