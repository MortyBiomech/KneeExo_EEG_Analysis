# data/

What lives here: **anything a reproducer needs that they cannot regenerate
from what they have.** Mostly that means the decisions a person made by hand,
which no amount of computing recovers. It also covers tables and caches that
are computable in principle but only from data most people will never
download.

Everything else is either a large input you fetch from the deposit or an
output the code writes, and neither belongs in the repository.

```
data/
└── derived/                                    tracked in git, about 66 MB
    ├── Events/                                                         23 MB
    │   └── sub-<N>/
    │       ├── events_with_FlxExt.txt          the event table add_events imports
    │       └── sub-<N>_Trials_encoder_events.mat   the curated encoder events
    ├── brain_ic_selection/                                             20 MB
    │   ├── Brain_PotentialBrain_AcceptedPotentialBrain.mat
    │   └── sub-<N>/
    │       ├── Brain_ICs_50percentUp - Accepted_potential_Brain_ICs - sub-<N>.mat
    │       ├── accepted_subject_<N>_IC_<k>.png
    │       └── rejected_subject_<N>_IC_<k>.png
    ├── Subjects_ICs_in_clusters.mat            SUBJECTS_ICS            29 kB
    ├── emg_master_index.mat                    tables and flags, no signals  1.2 MB
    ├── trk_master_index.mat                                            1.2 MB
    ├── behaviour_table.mat                     one row per trial       0.2 MB
    ├── figure2_precomputed.mat                 cycle curves and permutation results  0.4 MB
    ├── epoch_pairing_map.mat                   EEG epoch to experiment epoch  0.4 MB
    ├── tracking_error_warped.mat               error on the EEG cycle axis   20.2 MB
    ├── figure5_coupling_Left_Parieto_Occipital.mat   the stored Figure 5 result  0.5 MB
    └── lmm21_features.mat                      the 21 trial-level features  0.4 MB
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

## The eight committed outputs

Eight files here are outputs, and they are committed anyway. Together they mean
that three whole analyses run on a fresh clone with nothing downloaded:

| Committed for | Files | Lets you run |
|---|---|---|
| behaviour | `emg_master_index.mat`, `trk_master_index.mat`, `behaviour_table.mat`, `figure2_precomputed.mat` | `behaviour/run_results_behaviour.m`, so every behavioural number, every statistic, the whole mediation and all of Figure 2 |
| coupling | `epoch_pairing_map.mat`, `tracking_error_warped.mat`, `figure5_coupling_Left_Parieto_Occipital.mat` | `coupling/run_cross_correlation.m`, so Figure 5 redraws for the left parieto-occipital cluster |
| the trial-level LMM | `lmm21_features.mat` | `lmm21/run_lmm21.m`, so the cluster tests, the 21 intervals and the sensitivity grid all run |

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

**`epoch_pairing_map.mat`**
Which EEG epoch is which experiment epoch. The two streams were cleaned on
their own terms and neither file carries an index into the other, so the join
goes through the event tables and is matched by nearest neighbour on absolute
onset. Built once by `coupling/build_epoch_pairing.m`, which needs EEGLAB and
the per-participant datasets. It reads the `urevent` tables rather than any
cluster solution, so **the same map serves every cluster** and does not need
rebuilding when the cluster changes. `lmm21/` reads it too. See
`code/coupling/README.md` for why this step is what makes the coupling analysis
defensible at all.

**`tracking_error_warped.mat`**
The tracking error resampled onto the movement-cycle axis the EEG actually
uses, taken from `timewarpms`. At 20.2 MB it is much the largest file here and
the one place this folder breaks its own size rule; see **Anything large**
below. It is rebuilt automatically if the cached error sits on a different
cycle axis from the EEG.

**`figure5_coupling_Left_Parieto_Occipital.mat`**
The stored cross-correlation result, so Figure 5 redraws without the
`.icatimef` files, the same way `figure2_precomputed.mat` works for Figure 2.
One file per cluster, and only the left parieto-occipital cluster is committed,
because only one cluster is analysed per run. Running another cluster needs
tier 2.

**`lmm21_features.mat`**
The 21 trial-level cortical features, seven clusters by three bands, with the
build audit. Rebuilding needs tier 2 and a few minutes per cluster, so the
cache is what lets the model run on a fresh clone. It carries a feature version
and a cluster list, and `run_lmm21` **refuses** a cache that does not match the
configuration rather than loading it and misreading it, which is the strongest
form of the staleness guard described next.

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

**Anything large, from now on.** New files over a few MB go to the deposit, not
into git. Everything already here stays: the decision is about what gets added,
not a cleanup of what is committed.

`data/derived/` is about **66 MB**, which is past what that rule intends and
worth knowing before you add to it. It breaks down as roughly 23 MB of
`Events/`, 20 MB of `brain_ic_selection/` of which 19 MB is PNGs, and 20.2 MB
in `tracking_error_warped.mat` alone. The first two are the audit trail for the
two manual steps and are the reason this folder exists, and they are large only
in aggregate; no single file in them reaches 2.1 MB.

`tracking_error_warped.mat` is the one genuinely large file, and it is
grandfathered rather than justified. **Figure 5 does not need it.**
`run_cross_correlation` loads `figure5_coupling_<cluster>.mat`, 0.5 MB, and
returns before `ensure_coupling_inputs` is ever called, so the redraw path never
touches the warped error. It is needed only to rebuild the analysis, and a
rebuild needs the single-trial decompositions as well, so anyone doing that has
the deposit already. If this folder ever has to shrink, this file is the first
thing to move and the cheapest to lose.

Binary `.mat` files do not delta well in git, so every rebuild of that file adds
another 20 MB to the history permanently. Rebuild it deliberately, not as a side
effect of a styling change, and if you do rebuild it, consider not committing
the new copy at all.

## Files that used to be here

The pre-rebuild working copy of this folder held more files than this one. None
is deleted lightly and none should come back, so here is where each went.

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

### They are deleted from the working tree, not from git

`git rm` removes a file from the current commit. Every earlier commit still
references the blob, so a fresh clone still downloads it. Five of the files
above are still in this repository's history and account for most of its size:

| Still in history | Size | Versions |
|---|---|---|
| `data/derived/Subjects_Tracking_Error.mat` | 42.3 MB | 2 |
| `data/derived/All_scores_trackErr.mat` | 15.0 MB | 1 |
| `data/derived/Subjects_Force_Angle.mat` | 10.1 MB | 1 |
| `data/derived/Subjects_Force_Angle_warped.mat` | 5.9 MB | 1 |
| `data/derived/EEG_features_wholeBrain.mat` | 2.0 MB | 1 |

That is **75.4 MB of files the project no longer contains**, against a `.git`
of about 69 MB compressed. Note that `All_scores_trackErr.mat` holds the
corrupted `meanScores` and `stdScores` described above, so it is not merely
large but actively misleading to anyone who digs it out of history.

**Before publication, purge them.** This rewrites every commit, so it has to
happen before the repository is public, before the Zenodo DOI is minted and
before the DOIs in `code/README.md` are filled in. Once anyone has cloned or
forked it, the cost rises sharply.

```bash
pip install git-filter-repo
git clone --mirror https://github.com/MortyBiomech/KneeExo_EEG_Analysis purge.git
cd purge.git

git filter-repo \
  --path data/derived/Subjects_Tracking_Error.mat \
  --path data/derived/All_scores_trackErr.mat \
  --path data/derived/Subjects_Force_Angle.mat \
  --path data/derived/Subjects_Force_Angle_warped.mat \
  --path data/derived/EEG_features_wholeBrain.mat \
  --invert-paths

git push --force --mirror https://github.com/MortyBiomech/KneeExo_EEG_Analysis
```

Check the result with `git count-objects -vH` before pushing; expect the clone
to fall to roughly 10 MB. Everyone with an existing clone must re-clone
afterwards, because every commit hash changes. Add
`data/derived/tracking_error_warped.mat` to that list as well if you decide the
one large committed file should live in the deposit instead.

Do not use `git gc` or `git prune` for this. They only drop unreachable
objects, and these blobs are reachable from commits that are still in the
history.

## The data release

The repository is tier 1 of a four-tier release. The other three are
downloads, and `config/local_paths.m` is where you point at them:

| Tier | Contents | Reproduces |
|---|---|---|
| 1 | this folder, plus the code | the whole behavioural Results including Figure 2, Figure 5 for the left parieto-occipital cluster, and the whole trial-level cortical LMM, all on its own. Then the later stages, given tier 2 |
| 2 | `.icatimef`, `SUBJECTS_ICS`, the STUDY files | Figures 3 and 4 exactly, Figure 5 for any other cluster, and a rebuild of the `lmm21` features. The behavioural numbers already come from tier 1 |
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

The part of the root `.gitignore` that governs this folder:

```
*.mat                       blanket, so no stray .mat is committed by accident

data/*                      then everything under data/ is ignored
!data/*.md                  and only these are let back in
!data/derived/
!data/derived/*/
!data/derived/*.mat
!data/derived/*/*.mat
!data/derived/*/*/*.mat
!data/derived/MANIFEST.csv
```

**The blanket `*.mat` is why the whitelist has one line per depth.** Adding a
`.mat` file at a depth that is not listed, `data/derived/a/b/c/x.mat` for
example, means git ignores it and `git add` reports nothing wrong. If a file
you expect to be committed is not showing up, run

```bash
git check-ignore -v data/derived/<path>
```

`.png` and `.txt` are not matched by any ignore rule, so the component-review
PNGs and the `events_with_FlxExt.txt` files are tracked normally and a new one
is picked up without a whitelist entry.

`!data/derived/MANIFEST.csv` whitelists a file that does not exist. Either
write the manifest or drop the line.

**The whitelist cuts both ways, and nothing enforces the size policy.**
`!data/derived/*.mat` re-includes every `.mat` at this level whatever its size,
so git will not stop a large intermediate from being committed here. The rule
that new large files go to the deposit is a habit, not a mechanism. GitHub
refuses anything over 100 MB and a rejected push is where you would find out,
so check the size yourself before adding a `.mat`:

```bash
git diff --cached --name-only | xargs -r du -h | sort -rh | head
```

`EMG_Data_timewarped.mat`, the 2.1 GB file in the table above, used to have an
ignore line of its own. That line was already doing nothing, because a later
negation wins in gitignore and the whitelist sits below it, so it has been
removed rather than left as false reassurance. That file does not live here
anyway.

If you want the policy enforced rather than remembered, a `pre-commit` hook
rejecting staged files over about 10 MB is the usual way, kept in a versioned
`.githooks/` and switched on once per clone with
`git config core.hooksPath .githooks`.

One rule elsewhere in the same file is worth knowing about from here.
`/figures/` is anchored with a leading slash on purpose: unanchored, it matched
a folder called `figures` at any depth and silently excluded `code/figures/`
along with the output directory it was meant to hide.