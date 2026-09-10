# ersp_analysis

Paste into `README.md`, replacing whatever describes the ERSP code. It does not
cover `precompute/`, `study/` or `vendor/`, which I have not seen.

This folder does two separate jobs, and the split reflects that.

**`compute/`** produces `*_ersp_qc_results.mat`. Slow, run rarely.
**`figures/`** turns those .mat files into Figures 3, 4, 5 and the Results-section
reports. Fast, run repeatedly while iterating.

The interface between them is `*_ersp_qc_results.mat`. Nothing in `figures/`
reads raw data; nothing in `compute/` knows about figures. If you find yourself
wanting a figure script to recompute something, that is a sign the quantity
belongs in the .mat instead.

## Run order

```
compute/main_ersp_pipeline_qc.m       % per ROI -> *_ersp_qc_results.mat
figures/main_band_pvalue_family.m     % once -> band_pvalue_family.mat
figures/main_figure3_primary_motor.m
figures/main_figure4_parieto_occipital.m
```

`main_band_pvalue_family.m` must run before either figure, and again whenever the
reported cluster list, `nPerm`, `alpha`, `rngSeed` or the band edges change. The
figures verify this and refuse a stale family rather than silently drawing
uncorrected bars.

## Layout

```
ersp_params.m              every analysis and plotting choice, shared by both sides
                           (also marks the root -- the entry points find the path
                            by looking for this file)

compute/
  main_ersp_pipeline_qc.m  entry point
  qc/                      trial rejection, per-cluster ERSPs, result assembly
  build_stats_study.m      2D FieldTrip test setup
  plot_cluster_qc_sanity.m QC check on the computation, NOT a paper figure

figures/
  main_band_pvalue_family.m        entry point: builds the correction family
  main_figure3_primary_motor.m     entry point: sensorimotor pair
  main_figure4_parieto_occipital.m entry point: parieto-occipital pair
  load_cluster_pair_data.m         loads one left/right pair from the .mat files
  plot_cluster_pair_figure.m       THE figure implementation (both figures)
  report_cluster_pair_stats.m      prints every number the Results text needs
  bandstats/
    cluster_perm_1d.m              1D cluster permutation test
    compute_band_stats.m           runs it per band for one cluster
    build_band_pvalue_family.m     runs it for every reported cluster
    band_pvalue_fdr.m              Benjamini-Hochberg over the family
    band_family_settings.m         defines what makes a family stale
  debug/                           diagnostics, not part of any run
```

## Two rules this code is built around

**Figures 3 and 4 are drawn by one function.** They exist to be compared (a
regional dissociation: graded modulation in one pair, none in the other), and
that comparison only holds if they are rendered identically. Layout changes
belong in `plot_cluster_pair_figure.m`, never in a figure's own script. Two
copies would drift within a few edits and quietly destroy the argument.

**Figure, report and text read the same numbers.** `report_cluster_pair_stats`
reads the same `data` struct the figure draws from, and both threshold band
significance on the same FDR cutoff. Nothing is recomputed for the text.

## Things that are easy to get wrong

- The multiple-comparison family is the cluster list in
  `main_band_pvalue_family.m` section 2. Its length sets *m*, which sets the
  correction, which decides which bars appear. Listing fewer clusters than the
  paper reports makes the correction too lenient.
- Bands with no suprathreshold cluster enter the family as p = 1. They are still
  tests and they set *m*.
- `p.bandStats.rngSeed` is load-bearing. `compute_band_stats` runs twice, once
  in the family builder and once in the figure loader; the seed is what makes
  those two produce identical numbers instead of independent draws.
- Every panel uses one component per participant, selected upstream in whatever
  built `Subjects_ICs_in_clusters.mat`. The full clusters are larger (20 and 19
  components against n = 13 and 12). Methods must state both, and the selection
  criterion, which lives outside this codebase.
- `p.stats.oneIcPerSubject` is documentation. No code reads it.
- Colour limits and y limits are per cluster, so panel **a** and panel **b** are
  not on a common scale. The captions say so.

## Path setup

The entry points call `find_analysis_root`, which walks up looking for
`ersp_params.m` and then `genpath`s from there, putting both `compute/` and
`figures/` on the path. It is marker-based rather than a fixed number of
`fileparts()` calls on purpose: the previous fixed-depth version broke the moment
this split was introduced. If you move `ersp_params.m`, move the marker logic
with it.

## Known loose end

`precompute/` and `study/` look like compute-side folders but were left at the
root because their contents were not reviewed during the split. Move them under
`compute/` once you have confirmed nothing outside references them.
