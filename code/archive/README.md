# archive/

**Nothing in this folder is on the run path.** No file in `code/` calls
anything here. It is kept so that the history of the analysis is recoverable:
if a number in the paper looks surprising, or if somebody wants to know why a
choice was made, the superseded version that produced the earlier answer is
still readable.

Do not add this folder to the MATLAB path. Several files here share a name or
a purpose with a live function, and shadowing is the likeliest way to get a
wrong result quietly.

If you are looking for the function that actually runs, see `code/README.md`.

## Two entries that do not match their file

**`results_behaviour_sep07.m` was called `RESULTS_BEHAVIOUR.m`** in the working
tree, and it is renamed here because it cannot keep that name. This folder
already holds `results_behaviour.m`, and the two differ only in case. Git
stores both happily, being case sensitive, but Windows and macOS checkouts
cannot hold both in one folder: one silently overwrites the other and `git
status` then reports a modification that cannot be cleared. Any future file
added here needs the same check against the names already present.

**`show_gui_for_file_selection.m` is not archived.** It is live at
`data_processing/show_gui_for_file_selection.m`, so the paragraph below
describing it as removed from the pipeline is out of date and should be checked
against what the file now does.

Separately, `tracking_error_analysis.m` is in neither place. It is the only
code in the project carrying the TOST equivalence tests and the JZS Bayes
factors, and the note at the end of this file records it as pending a port
rather than superseded. It is not in the repository at all, so it currently
exists only in the original working tree.

## Superseded entry points

### `main.m`
The original combined script: ERSP precompute in the top half, cluster
plotting in the bottom half. Split into `precompute/run_ersp_precompute.m` and
the `figures/` entry points, because the two halves need different inputs,
take very different amounts of time, and were never actually run together.
Useful if you want to see the original order of operations in one place.

### `precompute_timewarped_ersp.m`
`[STUDY, ALLEEG] = precompute_timewarped_ersp(STUDY, ALLEEG, p, warpMode)`, the
direct ancestor of `precompute/run_ersp_precompute.m`. It took a `warpMode` of
`'groupmedian'` or `'subject'`, so the choice the live pipeline fixes, warping
every participant onto the group median latencies, was a runtime argument here.
Kept because it is where that choice is visible as a choice.

### `std_precomp_timewarp.m`
A second fork of EEGLAB's `std_precomp` in the repository. The one that runs is
`vendor/mod_std_precomp_v_forEEGlabv2021.m`; this file is a rename of it, and
its own FORK NOTICE says so.

**It is not simply an older copy.** Ignoring comments and blank lines the two
still differ in about ninety lines, and the difference is in the flag detection
that decides whether the per-participant substitutions fire at all. This file
guards them, requiring `isscalar(tw_value) && tw_value == 0` for the warp
placeholder and testing `~isempty(g.erspparams)`; the vendor copy tests
`isfield(g, 'erspparams')` and compares `g.erspparams{i+1} == 0` without a
scalar guard, which is an array comparison if a vector is ever passed. This
file also errors out when called with fewer than three arguments and carries
the documented FORK NOTICE.

So the archived file is arguably the tidier of the two and the live pipeline
runs the other one. That is the reverse of what this folder is supposed to
mean, and it should be resolved rather than left as a note: either promote
this version into `vendor/` under the name the pipeline calls, or record why
the looser one is the one that ran.

**Meanwhile this is exactly the shadowing hazard the warning at the top of this
file is about.** Two files fork the same EEGLAB function, they do not behave
identically, and `which -all` is the only way to find out which one a call
reached. Do not put `archive/` on the path.

### `Main_epoch_selection.m` and its four variants
`main_epoch_selection_TrialsBased.m`, `main_epoch_selection_FlexionsBased.m`,
`main_epoch_selection_ExtensionsBased.m`,
`main_epoch_selection_FlextoFlexBased.m`.

Four epoching schemes were tried: whole trial, flexion-locked,
extension-locked, and full cycle from one flexion start to the next.
`Main_epoch_selection.m` is the dispatcher, with three of the four calls
commented out because the study settled on the full cycle. They are merged
into `data_processing/extract_epochs.m`, which takes a `basis` argument
(`'flextoflex'` by default) and shares the slicing, the reference angle and
the EMG envelope between the four.

Kept because the three unused schemes are what the full-cycle choice was
decided against, and because someone reworking the epoching will want to see
that the alternatives were written and run, not just considered.

## Superseded group-stage functions

### `cortical_ICs_indentifier.m`
Replaced by `study/screen_brain_components.m`. The old version passed the `ICs`
table to the review GUI by value and then saved its own untouched copy, so the
file it wrote had an empty third column: the accepted borderline components
only ever reached the base workspace, through `assignin`. Shipped copies of
`Brain_PotentialBrain_AcceptedPotentialBrain.mat` that look as though nobody
accepted anything were written by this file.

### `ic_selection_gui.m`
Replaced by `study/review_components_gui.m`. Same bug seen from the other
side: it wrote its result to the base workspace with `assignin` and did not
return it, and it did not block, so the caller carried on before the review
was finished.

### `oneSubPerCluster.m`
Replaced by `study/keep_one_ic_per_subject.m`. Same reduction, same rule (keep
the first component a participant contributes to a cluster, move the rest to
the outlier cluster). Kept because it is short enough to diff against the
replacement and confirm that the reduction rule did not change.

Note what neither version does: it does not recompute the cluster centroid
after removing components. See the header of
`study/add_anatomical_labels.m`.

### `clustering_rank_solutions_custom.m`
Replaced by `study/rank_clustering_solutions.m`. The scoring is arithmetically
the same: six measures, each divided by its own maximum, weighted and summed.
Only the naming, the comments and the weight-count check are new. Kept so that
the ranked solutions in the paper can be reproduced with the file that
produced them.

## Superseded statistics and effect size

### `erspStats.m`
Replaced by `compute/ersp_cluster_stats.m`. The old version pulled its
statistics settings out of `STUDY.etc.statistics` wherever it found them,
which means the result depended on whatever a GUI had last written into the
STUDY. The replacement takes an explicit parameter struct from
`config/ersp_params.m` and builds its statistics STUDY once, in
`compute/build_stats_study.m`.

### `calc_clust_effectsize.m`
Replaced by `compute/cluster_effect_size.m`. Noelle Jacobsen's adaptation of
Arnaud Delorme's cluster effect-size code from the Donders
`infant-cluster-effectsize` repository. It hardcodes `p < 0.05` when choosing
which cluster to measure, which is the wrong cutoff for this study. Kept for
the provenance chain: it is the direct ancestor of the live function, and the
Donders code it derives from is the published reference for the method.

### `gettimes.m`
A copy of EEGLAB's internal `gettimes`, a subfunction of `timefreq`. Almost
certainly copied out during debugging, to work out which time points
`newtimef` was actually going to return for a given `frames`, `tlimits` and
window size. Not modified. Kept because that question comes up again every
time somebody wonders why the ERSP time axis has the length it has, and this
is the function that answers it.

## Superseded plotting

### `my_plotERSPSfromSTUDY.m`
The original cluster ERSP figure code, 62,175 bytes of it. Replaced by
`figures/plot_cluster_pair_figure.m` together with
`figures/load_cluster_pair_data.m` and `figures/report_cluster_pair_stats.m`.

This is the file that contained the inverted significance masks: it read
`pcond` as though 1 meant "not significant", when with a numeric
`fieldtripalpha` set it is FieldTrip's `stat.mask`, where 1 means significant.
See `vendor/README.md`.

It calls `vendor/std_erspplot_myparams.m`, which is why that fork is still on
the run path even though the current figure code does not use it.

### `calldefinedcolormap.m`
Replaced by `figures/ersp_colormap.m`. There were eighteen copies of this
function across the old folders.

**Sixteen of them are in this folder**, `calldefinedcolormap.m` plus
`calldefinedcolormap2.m` through `calldefinedcolormap16.m`, not the single
reference copy an earlier version of this paragraph claimed. They are not
byte-for-byte identical: each declares its own function and output name, the
files run from 3,769 to 9,350 bytes, and no two md5 sums match. What matters is
the table inside, and comparing those numerically gives three groups:

| Files | Table |
|---|---|
| `calldefinedcolormap.m`, `2` to `10`, `13`, `14`, `15` | 256 x 3, all thirteen numerically identical to the last digit |
| `calldefinedcolormap11.m` | 256 x 3, but up to 0.0588 per channel away from the reference, about 15 of 255 steps |
| `calldefinedcolormap12.m` | 256 x 3, but up to 0.415 per channel away, about 106 of 255 steps |
| `calldefinedcolormap16.m` | not a colormap. One row of 201 negative values, a different quantity under a `calldefinedcolormap*` name |

So the thirteen are safe to treat as one table and the last three are not.
**11 and 12 are visibly different colormaps**, not rounding variants, so any
figure drawn with either does not share the reference palette. Worth resolving
before the set is reduced to one file.

`calldefinedcolormap.m` is the reference the paragraph below compares against.

`ersp_colormap.m` reproduces this table from seven anchor colours and
interpolation. The two agree to a maximum of 4.85e-7 per channel, which is
0.0001 of an 8-bit step, and no row differs by as much as 1/255. The
substitution is therefore invisible in any rendered figure. Kept so that claim
can be checked rather than believed.

One property both share: the palest row is row 125 of 256, not row 128.5, so
the colour midpoint sits about 1.4 percent of the range below zero, which is
roughly 0.04 dB at the +/- 1.5 dB limits used in the figures. Not worth
changing, worth knowing.

### `debug_dipplot_contents.m`
Replaced by `figures/debug/debug_dipole_objects.m`. A scratch script for
finding out what graphics objects `dipplot` leaves in a figure, so that the
dipole panels could be restyled after the fact. Superseded but the same idea.

### `show_gui_for_file_selection.m`
A `uifigure` for picking and ordering XDF files by hand before loading. Removed
from the pipeline deliberately: the manual choice it captured is now made by
choosing which XDF files to place in the raw data folder in the first place,
which is a decision that survives in the deposited data instead of living in a
dialog box. Kept because it documents what that manual step used to ask.

## Superseded behaviour, EMG and tracking code

All of these predate `code/behaviour/`. They fall into two groups, and the
distinction matters: the first group was merged into one file, the second
group **cannot run at all** against the rebuilt masters.

### Merged into `behaviour/run_results_behaviour.m`

`results_behaviour.m` holds the statistics, all three rows of Figure 2 and the
mediation in one run, deliberately: an analysis script and a figure script are
tidier but let the p value in a bracket drift away from the p value in the
sentence. These five are the stages it was assembled from.

- **`make_figure2.m`** drew rows 1 and 2 and computed only what the
  annotations needed.
- **`results_section.m`** added the statistics sections and the paste-ready
  LaTeX, plus the cluster cache. It is `make_figure2` with the numbers.
- **`results_mediation.m`** fitted the two-mediator model and wrote
  `mediation_results.mat`. Its categorical sensitivity check survives in the
  merged file at section 7.
- **`mediation_row.m`** drew row 3 from that saved file. Its path diagram
  survives as the `drawBox` and `drawArrow` local functions.
- **`results_behaviour_sep07.m`** (the 7 September copy, named
  `RESULTS_BEHAVIOUR.m` in the working tree) is an earlier state of the merged
  file itself. Kept because `figures/bandstats/cluster_perm_1d.m` was ported
  verbatim from it, so the EEG band statistics and Figure 2 use identical code,
  and this is the file that proves it.

### Built on the old trial numbering, cannot be run

Each reads `Subject_Tracking_Error.mat`, the old `behavior_table.mat`, or
`T.Trial`, which held indices compacted by the EMG builder. That numbering
diverged from the tracking pipeline's raw indices for participants 9, 11, 12
and 18. The rebuilt masters removed the divergence by keying everything on
`(SubjectID, RawTrial, RawEpoch)`, which also removed the ground these files
stand on.

- **`build_trial_index_map.m`** reconstructed the raw-to-compacted mapping so
  the two numbering schemes could be reconciled. It documents exactly how the
  compaction happened, which is why the rebuild was necessary.
- **`tracking_mismatch_map.m`** located which trials disagreed, searching
  shifts outward from zero so the smallest explanation wins. Its own header
  records the answer: subject 9 was a uniform shift of one, while 11, 12 and
  18 were partial, at 0.79, 0.70 and 0.53 agreement.
- **`emg_table_join_check.m`** asked which of the two candidate identifier
  columns in `EMG_Data_timewarped` joined to the behaviour table. Answered,
  then made moot.
- **`tracking_cycle_and_row1.m`** drew row 1 of Figure 2 from the legacy
  structures, warping the tracking error itself because no warped copy
  survived. Superseded by the merged file. Its note on why tracking and EMG
  agree on a 50:50 flexion split, 0.515 against 0.503, is worth keeping for
  the Methods.
- **`behaviour_ratings_analysis.m`** analysed the ratings alone. Its rating
  validity screen and its variance consistency check (pooled SD must be at
  least the mean within-subject SD, or the two quantities came from different
  data) are the checks that originally exposed the corrupted `meanScores`
  variables.
- **`emg_cycle_and_effort_analysis.m`** built the EMG cycle curves from
  `EMG_Data_timewarped`. Its header records a selection problem worth
  remembering: the plotting script it replaced dropped score-by-pressure cells
  with few trials, which is a selection on the outcome variable, and the
  condition statistics inherited that filter from the same arrays.

**Not archived:** `tracking_error_analysis.m`. It contains the TOST
equivalence testing and the JZS Bayes factors, which nothing else does, so it
is pending a port rather than superseded.

## If you are deleting things

Anything here can be deleted without breaking the pipeline. Before deleting,
check that the reason it was kept has been written down somewhere else: for
most of these files, the reason is a bug or a decision explained in the
header of the function that replaced it.