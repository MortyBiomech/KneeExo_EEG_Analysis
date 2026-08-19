# Cluster ERSP analysis

Time-frequency analysis of the IC clusters: how spectral power over a knee
flexion–extension cycle changes with PAM assistance pressure, and where those
changes are statistically reliable. This produces the ERSP figures in the
manuscript.

Run `main_ersp_pipeline.m` section by section.

---

## What the analysis does

**Epochs are movement cycles, not fixed windows.** Each epoch runs from one
flexion onset to the next. Cycles differ in duration within and between
subjects, so before any time-frequency decomposition they are time-warped onto
a common set of event latencies (flexion start → extension start → extension
end). Without that, averaging across cycles would smear exactly the
movement-locked structure the analysis is about. The x axis of every figure is
therefore percent of cycle, not milliseconds.

**The baseline is the cycle itself.** The task is continuous and cyclical, with
no rest period, so there is no pre-stimulus window to baseline against. Instead
the baseline is the whole warped cycle, `[0 lastEventLatency]`. Stock EEGLAB
cannot express that, which is why `std_precomp_timewarp` exists.

**One IC per subject per cluster.** A subject can contribute several components
to the same cluster. Left alone, that subject would be weighted more heavily
than the others and the cluster statistics — which assume one observation per
subject — would be wrong. `one_ic_per_subject` keeps the lowest-numbered IC,
i.e. the one accounting for most of that subject's variance.

**Statistics are cluster-based permutation tests** (FieldTrip Monte-Carlo,
10 000 randomisations, paired, α = 0.01), run first as an omnibus test across
the three pressures and then pairwise against the reference condition P1. The
test forms clusters over the time-frequency plane; a single component means
there are no channel neighbours to cluster over.

---

## Pipeline

| Stage | File | Cost |
| --- | --- | --- |
| 1. Load an ROI STUDY | `main_ersp_pipeline.m` §2 | seconds |
| 2. Precompute time-warped ERSPs → `.icatimef` | `precompute/precompute_timewarped_ersp.m` | **hours, once** |
| 3. Read back the wavelet parameters actually used | `main_ersp_pipeline.m` §3 | seconds |
| 4. Per ROI: design, atlas labels, one IC per subject | `study/prepare_study_for_ersp.m` | seconds |
| 5. Per cluster: read ERSPs, test, plot, save | `plotting/plot_cluster_ersp.m` | minutes |

Stage 2 writes to disk and only has to run once; stage 5 reads those files back
and can be re-run freely.

Every number that defines the analysis — wavelet parameters, α, the number of
randomisations, the frequency range, the ROI list, the figure fonts — lives in
`ersp_params.m`.

---

## Layout

```
main_ersp_pipeline.m     entry point, run section by section
ersp_params.m            every analysis parameter, in one struct

precompute/
  precompute_timewarped_ersp.m   builds the parameter list, calls the fork
  std_precomp_timewarp.m         FORK of EEGLAB std_precomp

study/
  prepare_study_for_ersp.m       design + labels + one IC per subject
  add_anatomical_labels.m        AAL atlas lookup for each cluster centroid
  one_ic_per_subject.m           drop duplicate ICs into the outlier cluster

plotting/
  plot_cluster_ersp.m            the two figures and the statistics behind them
  ersp_colormap.m                the diverging colormap used in the paper
  draw_timewarp_events.m         event lines and their labels
  save_figure.m                  png/fig/svg without changing directory

stats/
  ersp_cluster_stats.m           cluster-based permutation test
  cluster_effect_size.m          Cohen's d per significant cluster
  std_stat_clusterpval.m         FORK of EEGLAB std_stat

vendor/
  std_erspplot_myparams.m        FORK of EEGLAB std_erspplot
  vline.m, license.txt           File Exchange, BSD
```

---

## The three EEGLAB forks

Three EEGLAB functions are forked rather than called. Each carries a **FORK
NOTICE** at the top of the file stating exactly what was changed and why; this
is the summary.

| Fork | Of | Deliberate change |
| --- | --- | --- |
| `std_precomp_timewarp` | `std_precomp` | Accepts three placeholder values — `'timewarp',0`, an all-zero `'timewarpms'`, and `'baseline','median latency baseline'` — and substitutes per-subject time-warp latencies and a cycle-length baseline. |
| `std_erspplot_myparams` | `std_erspplot` | Takes an extra argument holding the ERSP parameters, so the plot is described by the parameters the `.icatimef` data were actually computed with rather than by whatever is in the STUDY. |
| `std_stat_clusterpval` | `std_stat` | Returns the raw cluster p-value map alongside the thresholded mask, which stock `std_stat` discards. Needed to report cluster-level p-values and to restrict effect sizes to one cluster. |

The time-warp and baseline modifications originate with Noelle Jacobsen
(University of Florida) and J. Gwin.

Each fork also differs from current EEGLAB in incidental ways, because it was
taken from an older release. Those differences are listed in the notices and
none of them affect the values computed.

---

## Changes from the version that produced the published figures

The original lived in a folder named `test_eeglab_way_of_ERSP_PSD` and held 76
files, about 17 000 lines. Roughly 10 000 of those lines were instrumented
copies of EEGLAB internals, named `decoding_*`, made in order to trace what
EEGLAB does step by step. They were never called by the analysis. They are not
reproduced here; they remain in the project's working repository.

**The figures this module produces are the published ones.** Nothing was
changed that affects a plotted value. What did change:

- **A significance-mask polarity error.** With an alpha set, `std_stat` returns
  a logical mask where 1 means *significant*. Three places treated it as a
  p-value and tested `mask < alpha`, which selects the complement. The
  consequence was that `erspDiff.masked` retained the non-significant pixels,
  and the effect sizes were computed over non-significant clusters. **The
  figures were never affected** — they draw the unmasked difference and outline
  significance with `bwboundaries` on the mask itself, which is correct — and
  nothing downstream consumed the affected fields; the manuscript's figures
  recompute their statistics from scratch. Corrected here, so the effect sizes
  and masked fields are now meaningful.

- **A wrong effect-size window.** `calc_clust_effectsize` reported the extent
  of each cluster by indexing the axis vector with a *logical* mask element,
  which returned the first axis value whenever the first pixel happened to be
  in the cluster and errored otherwise. It never described the cluster. The
  extent is now resolved with `ind2sub` and reported as a real time window and
  frequency window.

- **α was declared once and then reassigned three times** inside the loop that
  used it, with a comment warning that it was "hard coded in places". Now a
  single value in `ersp_params.m`. 0.01 is the value that was in force for
  every published figure.

- **The ERSP parameter override was mutated inside the cluster loop**, so a
  second cluster in the same call would have errored. This survived only
  because each ROI selects exactly one cluster. Converted once, before the
  loop.

- **A `timewarpms` detection bug**: the test was nested inside the `timewarp`
  test, and an absent `timewarpms` key set the flag true by accident (`all()`
  of an empty array is true), which would have silently switched a run to
  subject-specific warping. The tests are now independent.

- **Dead code removed**: a `catch` block starting with `rethrow`, so its
  recovery code could never run; three local plotting functions left over from
  the gait study this was forked from; a local `erspStats` shadowing an
  identical file of the same name; a branch in `erspStats` guarded by a
  variable hardcoded empty two lines above, which referenced three
  out-of-scope variables and would have errored had it run.

- **Sixteen near-identical colormap files** (about 140 kB of pasted numeric
  literals) replaced by one `ersp_colormap` function. Every live call site used
  the same matrix; it is exactly piecewise-linear through seven anchor colours,
  and the function reproduces it to 5e-7 — far below one step of 24-bit colour.

- **Event markers** were placed by pulling every text object out of the figure
  with `findobj` and nudging objects 1, 2 and 3 by hardcoded offsets chosen
  with `mod(k,3)`. That worked only while exactly three events existed and no
  other text had been drawn first. Labels are now placed by the same call that
  draws the line.

- **Figure saving no longer changes the working directory.** `savethisfig` did
  `cd` to the destination and never came back, so the working directory
  depended on how many figures had been saved.

- Absolute paths are gone; everything comes from `ansymb_config()`.

### One thing to know before regenerating figures

The colormap's pale midpoint sits at index 125 of 256, not 128. It is
off-centre in the original and is deliberately kept off-centre so that
regenerated figures match the published ones. A symmetric colour limit
therefore does *not* put white exactly at zero — white lands slightly below it.
Do not read fine structure near zero off an ERSP image.
