# `code/lmm21/`

Does trial-level cortical band power predict perceived difficulty, over and above
imposed pressure, tracking error and muscular effort? Produces the closing
paragraph of the Results and its supplementary table. There is no figure.

## The question, and why it is not the same as Figures 3 and 4

Sensorimotor alpha and beta power scale with demand across conditions, and the
mediation shows that only about a fifth of the demand-to-difficulty path runs
through muscular effort. Neither result says the cortical signal is the trace of
the experience. That is a trial-level question: on a trial where a participant's
cortical power is unusual for them, is the rating they give also unusual?

Condition-level and trial-level are different scales, and a graded
condition-level signature can coexist with no trial-level relationship. Keeping
them apart is what stops the paper drifting into the stronger claim.

## The 21 features

Seven clusters by three bands, named `<abbr>_<band>`.

| Cluster | Prefix |
|---|---|
| `Left_Prim_Motor` | `LM1` |
| `Right_Prim_Motor` | `RM1` |
| `Left_PreMot_SuppMot` | `LPM` |
| `Right_PreMot_SuppMot` | `RPM` |
| `Left_Parieto_Occipital` | `LPO` |
| `Right_Parieto_Occipital` | `RPO` |
| `Left_Dorsal_ACC` | `LdACC` |

Bands are read from `cfg.bands`, not declared here, so this analysis and the
stage 7 FDR family cannot drift apart: theta 4 to 8, alpha 8 to 14, beta 14 to
30 Hz. Lower edge inclusive, upper edge exclusive, as in `coupling_config`, so
adjacent bands never share a bin.

**`Prime_Visual` is excluded, because it is not an independent source.** Seven
of its twelve components are the same (participant, IC) pairs that
`Right_Parieto_Occipital` contributes. The eight clustering solutions are
separate runs over the same component set, each seeded at its own ROI, so a
component can land in more than one of them. A family carrying the same signal
twice is not 24 tests of 24 sources; it is 21 sources with three of them counted
twice, and the Benjamini-Hochberg correction would then describe a family the
data do not have. A redundant cluster makes the correction look stricter while
adding no evidence.

`Prime_Visual` shares nothing with `Left_Parieto_Occipital`, so the redundancy
is with the right-hemisphere cluster specifically.

One overlap survives among the seven kept: participant 11's IC 29 is in both
`Left_PreMot_SuppMot` and `Right_PreMot_SuppMot`, one of eight components in
each. A single equivalent dipole cannot sit in both hemispheres, so this is a
near-midline component that two differently seeded runs both claimed. At one in
eight it belongs in the Methods as a caveat, not as a reason to drop a cluster.

`check_lmm21` recomputes every overlap on each run and prints it, so none of
these numbers can go stale here.

## The feature

```
feature = 10 * log10( mean over band and cycle of P(f,t) / B(f) )
```

with the movement cycles of a trial averaged before the logarithm.

`B` is `compute_cluster_ersp`'s baseline: the mean over the three conditions of
each condition's mean over QC-surviving trials, averaged over the cycle. A
feature here is therefore the same quantity as a pixel of the published ERSP,
averaged over a band and the cycle instead of over trials. Two properties of
that baseline carry the analysis, and `check_lmm21` asserts both.

It is **common across trials**, not per trial. A per-trial baseline divides each
trial by its own power and removes exactly the variation the model exists to
test.

It is **condition balanced**. A plain mean over trials would let a participant
with more trials in one condition shift their own reference, and the
between-condition difference is the effect the figures report.

Trials flagged by `flag_bad_trials` are dropped, per participant and condition,
exactly as the published ERSPs drop them. Turning that off means the null is
computed on a different set of trials from the figures, which would then have to
be stated.

**Which trial number.** The key is the trial number of the experiment stream,
from the pairing, not the one `trialinfo` carries. The two are different
countings and they disagreed for the participants whose EMG builder compacted its
index. The behaviour table keys on the experiment side, so that is the side used
here, and the audit reports how often the two disagree.

## The model

```
Score ~ 1 + Pressure_cat + Error + EffortIndex + EEGfeat + (1 | Subject_cat)
```

REML, one fit per feature, the feature z scored inside each participant so a
coefficient is rating points per within-participant standard deviation. Each
feature is judged by a Wald test on its own coefficient with Satterthwaite
denominator degrees of freedom, then Benjamini and Hochberg across the 21.

**There is no model comparison anywhere in this folder.** No likelihood ratio, no
AIC, no BIC, and `fit_feature_lmm` deliberately does not return AIC or BIC
columns so the comparison cannot creep back in. The earlier version of this
analysis reported one; it was a convergence artifact, with random-slope models
fitting singular, an impossible negative dAIC, and the likelihood ratio
disagreeing with the Wald test by orders of magnitude. Those numbers must not be
used.

Specification `randslope` re-fits every feature with
`(1 + Pressure_cat | Subject_cat)` and records which fail, so the Methods
sentence about non-convergence rests on a logged count. Three other
specifications run as sensitivity: feature centred instead of z scored, no
covariates, and covariates z scored too.

## Reading the result

The null is exclusionary only if the intervals are narrow. A large `q` with a
wide interval says nothing was measured; a large `q` with an interval inside a
few tenths of a rating point is a substantive ruling out, which is the form the
Discussion argument takes against the 5.20 rating point demand effect. The report
prints the intervals beside the `q` values for that reason, and the bound is
computed rather than eyeballed.

## Files

| File | What it does |
|---|---|
| `run_lmm21.m` | entry point L1. Open it and press Run |
| `lmm21_config.m` | every setting, and the checks that fail before a long run |
| `build_lmm21_features.m` | the 21 features from the `.icatimef` files |
| `lmm21_trial_features.m` | the feature definition for one component |
| `lmm21_feature_names.m` | the 21 names and their labels, in one place |
| `fit_lmm21_models.m` | the loop over features and specifications, plus the FDR |
| `fit_feature_lmm.m` | one feature, one model, one row |
| `report_lmm21.m` | the report, the manuscript numbers, the LaTeX table |
| `checks/check_lmm21.m` | the acceptance test, needs no data |

`bh_fdr` and `within_subject_scale` are in `../common/` because they are generic.
`bh_fdr` is also what should close the open item in `methods-pending.md`, where
the Benjamini-Hochberg values in the Figure 5 paragraph were computed by hand.

The reader is `load_cluster_power`, borrowed from `coupling/` unchanged. Using one
reader for both analyses is what lets the Methods say the null and the
cross-correlation describe the same signal.

## Running it

```matlab
check_lmm21        % about a minute, needs no data
run_lmm21          % open it and press Run
```

`run_lmm21` uses the cached feature table in `data/derived/lmm21_features.mat`,
so it runs on a fresh clone. Set `REBUILD_FEATURES = true` to rebuild from the
`.icatimef` files, which needs tier 2 and a few minutes per cluster. The cache
carries a version and a cluster list, and the entry point refuses a cache that
does not match the configuration rather than loading it and misreading it.

Outputs go to `figures/LMM21/`, alongside `ERSP_QC/` and `Figure5/`.

## What is not in this folder any more

An earlier version of this analysis carried its own path resolution, its own
`.icatimef` reader, its own `SUBJECTS_ICS` parser, its own epoch-pairing adapter
and its own behaviour-table loader. All five duplicated something the repository
already had, and two of them had guessed the wrong shape: the component variable
is `comp<N>`, not `comp<N>_timef`, and `SUBJECTS_ICS` is a cell array keyed by
cluster name rather than a struct. They are gone.

`withinSubjectZ` and `withinSubjectCenter` from the original working tree are
superseded by `within_subject_scale`. The z version created a new column with a
`_z` suffix while the centring version wrote back into the same column, so
running both in one session destroyed the raw column with no warning. Neither
had a minimum trial count guard, and the z version mean-centred silently when a
participant's standard deviation was zero, returning a column of zeros that then
entered a model as a predictor carrying no information.