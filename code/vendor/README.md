# vendor/

Third-party code, and forks of third-party code, that the pipeline calls
directly. Nothing in here was written for this study from scratch. It sits in
its own folder so that the boundary between "our analysis" and "somebody
else's function we had to modify" is visible at a glance, and so that anyone
auditing the pipeline knows exactly which behaviour is not stock EEGLAB.

This folder is on the MATLAB path, unlike `archive/`, which is not. That is not
the same as every file in it being called. Two are called by the live pipeline
and three are kept for the reasons given against each below:

| File | Called by |
|---|---|
| `mod_std_precomp_v_forEEGlabv2021.m` | `precompute/run_ersp_precompute.m`, live |
| `std_stat_clusterpval.m` | `compute/ersp_cluster_stats.m`, live |
| `std_erspplot_myparams.m` | only `archive/my_plotERSPSfromSTUDY.m` |
| `repeated_clustering_and_evaluation_custom.m` | nothing at present, see its entry below |
| `vline.m` | only `archive/my_plotERSPSfromSTUDY.m` |

**The BeMoBIL pipeline is not here.** It runs unmodified, so it is tracked as
a git submodule under `external/bemobil-pipeline` and pinned to the commit the
analysis was run with. Only the one BeMoBIL function that was modified,
`repeated_clustering_and_evaluation_custom.m`, lives in this folder. See
`external/README.md`.

## Why forks exist at all

EEGLAB's STUDY functions were designed for stimulus-locked epochs of fixed
length. This study epochs on a movement cycle whose duration varies from trial
to trial and from participant to participant, so every epoch is linearly time
warped onto a common set of event latencies.

**Where the warping happens matters, and it is not where you would guess.**
The raw time series is never stretched. `newtimef` runs the wavelet transform
on the epoch as recorded, and warps afterwards, which its own help states:

> `'timewarp'` [eventms matrix] Time-warp amplitude and phase time-courses
> (following time/freq transform but before smoothing across trials).

So the order is: transform each trial, then stretch that trial's amplitude and
phase time courses so its events land on the target latencies, then average
over trials. EEGLAB implements it by passing `'timestretch'` down to
`timefreq`, which interpolates the time-frequency arrays.

The practical consequence, worth a sentence in the Methods: the wavelets see
real time, so the time-frequency smearing at a given frequency is fixed in
milliseconds of recorded time. After warping, that fixed smearing corresponds
to a different width in cycle-normalised units for a fast trial than for a
slow one. Warping the raw signal first would have the opposite property. This
is the standard approach for gait and movement ERSPs (Gwin et al., 2011).

Two things that EEGLAB does automatically then become wrong:

1. the warped latencies differ per participant, so a single `timewarpms`
   vector cannot be passed to `std_precomp` for the whole STUDY,
2. the baseline window has to be the whole warped cycle, and where that cycle
   ends is again a per-participant number.

The forks below exist to make those two numbers per-participant. They do not
change any signal processing.

## Files

### `mod_std_precomp_v_forEEGlabv2021.m`

Fork of EEGLAB's `std_precomp`. Written by Noelle Jacobsen and Amanda
Studnicki, following an earlier edit by Joe Gwinn. Used by
`precompute/run_ersp_precompute.m` to write the `.icatimef` files.

Two additions over stock `std_precomp`, both inside the per-participant loop,
implemented as three substitutions:

* **Per-participant warp latencies.** Two substitutions, each with its own
  placeholder, decided once at parse time:

  | Placeholder | Substituted with | In our call |
  |---|---|---|
  | `'timewarp', 0` | `ALLEEG(inds).timewarp.latencies`, that participant's own event times, the SOURCE of the warp | active |
  | `'timewarpms'` all zeros | `ALLEEG(inds).timewarp.warpto`, that participant's own TARGET times | not active |

  `precompute/run_ersp_precompute.m` passes `timewarp` as 0 and `timewarpms`
  as the group median rounded to 50 ms, so each participant contributes their
  own event latencies but everybody is warped onto one shared target vector.
  That is the point: per-participant targets would leave the time axes
  incomparable and the grand average meaningless, and it would give each
  participant a different baseline window. The `else` branch that handles this
  prints "Warping to group median event latencies", which is the line to look
  for in the log.

  Gwinn's version substituted `timewarp.latencies` for the target as well;
  Jacobsen corrected that to `warpto`, which is the right field for a target.
  That correction only bites if you ask for per-participant targets, which
  this study does not.
* **`'baseline', 'median latency baseline'`.** Stock `std_precomp` takes a
  numeric baseline window in milliseconds. This fork accepts that string and
  replaces it with `[0 median_latency]`, the median latency of the last event.
  In our call, which warps to the group target, that is the last element of
  `timewarpms`, so the baseline window is `[0 warpingvalues(end)]` and is
  identical for every participant. That is what makes the
  baseline the whole movement cycle: the single common reference that lets the
  three pressure conditions be compared against each other.

All three are gated on flags set at parse time (`local_tw_flag`,
`local_twms_flag`, `local_baseline_flag`), so calling this function with
ordinary numeric arguments behaves like stock `std_precomp`.

The stock function cannot be used instead: it has no hook for either
substitution, and running `std_precomp` once per participant to work around it
would produce `.icatimef` files that the STUDY cannot then read as one design.

The commented-out `AStud modification` block near the same place is Studnicki's
earlier attempt, kept as it was received.

### `std_stat_clusterpval.m`

Fork of EEGLAB's `std_stat`, again from the Jacobsen line. Used by
`compute/ersp_cluster_stats.m`.

Stock `std_stat` returns only `pcond`, `pgroup`, `pinter` and the three
`stats*` structures. This fork adds two outputs:

```matlab
[pcond, pgroup, pinter, statscond, statsgroup, statsinter, cluster_pval, F]
```

`cluster_pval` is the p-value of each FieldTrip cluster, and `F` is the whole
FieldTrip `stat` structure. Without them there is no way to report a cluster's
p-value, only whether it passed threshold, and no way to get at
`stat.posclusterslabelmat` for the effect-size calculation in
`compute/cluster_effect_size.m`.

**Read `applymask` before you trust `pcond`.** With a numeric
`fieldtripalpha`, `pcond` is `squeeze(F.mask)`, so **1 means significant**.
With `fieldtripalpha` set to NaN it is a p-value map instead, where small
means significant. The polarity flips on that one argument. An earlier version
of our plotting code read it the wrong way round and inverted two
significance masks; the docstring in `compute/ersp_cluster_stats.m` now says
this explicitly.

### `std_erspplot_myparams.m`

Fork of EEGLAB's `std_erspplot`, third from the Jacobsen line. Takes an extra
**third** positional argument, `myparams`, after `STUDY` and `ALLEEG`:

```matlab
[STUDY, allersp, alltimes, allfreqs, pgroup, pcond, pinter, events] = ...
    std_erspplot_myparams(STUDY, ALLEEG, myparams, varargin)
```

It overrides `paramsersp` with that argument at the two points where the stock
function would otherwise read the parameters stored in the STUDY (lines 253 and
444).

This matters because the parameters stored in a STUDY are whatever was last
written there by any GUI action, while the parameters the `.icatimef` files
were actually computed with are fixed at precompute time. Passing them
explicitly is the only way to be sure that what is plotted was read back with
the same settings it was written with. It also returns `events`, the warped
event latencies, so the event markers in Figures 3 and 4 land where the data
says they do.

Not called by the current figure code, which reads the `.icatimef` files
through `compute/compute_cluster_ersp.m` instead. Kept because it is the
function that produced the first-pass plots the analysis was developed
against, and because `archive/my_plotERSPSfromSTUDY.m` calls it.

### `repeated_clustering_and_evaluation_custom.m`

Fork of BeMoBIL's `bemobil_repeated_clustering_and_evaluation`.

**Nothing in the repository calls it.** `study/run_group_clustering.m` calls the
stock BeMoBIL function instead, at its line 250. Either this fork is a leftover
and the split described below is no longer how the region solutions are
produced, or `run_group_clustering.m` should be calling it and does not. Settle
which before relying on the paragraph that follows.

The BeMoBIL original does the repeated clustering, builds the multivariate
data, ranks the solutions and saves the top five in one call. This version
stops after `bemobil_create_multivariate_data_from_cluster_solutions` and
returns, leaving the ranking to `study/rank_clustering_solutions.m`. The
ranking block is still in the file, commented out, so the divergence from the
original is visible.

The split is what allows a region's clustering solutions to be computed once
and then scored several times under different weightings, which is how the
seven region solutions in `run_group_clustering.m` were tuned. Re-running the
clustering for each weighting would take hours and, since k-means is seeded
randomly, would not give the same set of candidate solutions to score.

### `vline.m` and `vline_license.txt`

Brandon Kuczenski, 2001, from the MATLAB File Exchange. Draws vertical lines
with optional labels. Unmodified. BSD 2-clause, licence text alongside it as
that licence requires.

**Called only by `archive/my_plotERSPSfromSTUDY.m`,** and by nothing that runs.
Twelve `vline(` occurrences appear in that file, but six of them are commented
out (lines 650, 653, 809, 812, 1220, 1222), so six are live calls (lines 651,
654, 810, 813, 1335, 1337). The current figure code draws its event markers in
`figures/draw_timewarp_events.m`, which does not use vline. It is kept here
rather than in `archive/` so that the archived plotting script can still be
run for comparison without hunting the File Exchange, and because a licence
file is easier to keep track of in the folder that exists for third-party
code.

If you ever see vline behave unexpectedly, run `which -all vline`: other
toolboxes ship functions of this name, and whichever is first on the path
wins.

## Provenance and licence

`mod_std_precomp_v_forEEGlabv2021.m`, `std_stat_clusterpval.m` and
`std_erspplot_myparams.m` come from Noelle Jacobsen's
[ExoAdapt-DualEEG-Processing](https://github.com/jacobsen-noelle/ExoAdapt-DualEEG-Processing),
which is GPL-3.0. Redistributing them means this repository is GPL-3.0 too.
See `Credits.md` at the repository root for the per-file attribution and what
GPL-3.0 requires in practice.

**The EEGLAB functions they fork are not what makes this repository copyleft.**
The headers of the vendored copies are BSD 2-Clause, Copyright Arnaud Delorme,
SCCN, INC, UCSD, which is permissive. EEGLAB's own top-level README still says
GPL, so the project's licensing is not stated consistently upstream; the
per-file header is the one that governs the file in front of you, and here it
is BSD. `vline.m` is BSD 2-Clause as well, and BeMoBIL's pipeline is MIT (Klug
et al., 2022).

The copyleft comes from one place only, Jacobsen's repository. Her
modifications to those EEGLAB functions, and her original files, are her
copyright and she released them under GPL-3.0. Shipping them, and files derived
from them, is what makes the combined work GPL-3.0.

Note that no file in this repository carries a per-file licensing notice, and
none of the upstream files grants "version 3 or, at your option, any later
version". The GNU project treats that permission as something the notice has to
state, not something a bare `LICENSE` file implies, so the identifier for this
work is **GPL-3.0-only** rather than GPL-3.0-or-later. See
<https://www.gnu.org/licenses/gpl-faq.html#VersionThreeOrLater> and
<https://www.gnu.org/licenses/gpl-howto.html>.

## References

Delorme, A., & Makeig, S. (2004). EEGLAB: an open source toolbox for analysis
of single-trial EEG dynamics. *Journal of Neuroscience Methods*, 134(1), 9-21.

Gwin, J. T., Gramann, K., Makeig, S., & Ferris, D. P. (2011). Electrocortical
activity is coupled to gait cycle phase during treadmill walking. *NeuroImage*,
54(2), 1289-1296. The time-warped ERSP over a movement cycle comes from here.

Klug, M., Jeung, S., Wunderlich, A., Gehrke, L., Protzak, J., Djebbara, Z.,
Argubi-Wollesen, A., Wollesen, B., & Gramann, K. (2022). The BeMoBIL Pipeline
for automated analyses of multimodal mobile brain and body imaging data.
*bioRxiv*.