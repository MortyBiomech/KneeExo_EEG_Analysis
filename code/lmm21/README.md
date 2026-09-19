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

## The model, and what is tested

The baseline in every fit is `run_results_behaviour`'s mediation model `mdlB`,
term for term, which is what the Results sentence "building on the mediation
model" claims:

```
Score ~ 1 + Pressure_ord + EffortIndex_w + Error_w + Error_b + Trial_z + ...
           + (1 | Subject_cat)
```

*Pressure is ordinal*, 0 1 2, not a three-level factor. The mediation fits
`Xord` and uses the categorical coding once, as an equal-step check.
Specification `categorical` carries the two-degree-of-freedom version.

*Effort and error are split* into within- and between-participant components.
With only a random intercept, a raw trial-level covariate conflates the two
slopes. `EffortIndex_b` is absent because the effort index is normalised within
participant and so has no between-participant variance by construction;
`lmm21_derive_terms` detects that rather than assuming it.

*Trial number is a covariate.* The learning effect on tracking error is large,
about −0.45° per SD of trial number, so leaving it in the residual widens every
interval and weakens the bound.

The within and between terms are computed on the rows entering each model, not
once on the widest set, so no within term carries a between-participant residue.

### The test: seven clusters

```
... + EEG_theta + EEG_alpha + EEG_beta + (1 | Subject_cat)
```

with a joint Wald test on the three band coefficients. Seven tests, Benjamini
and Hochberg corrected across the seven. **The family is the clusters, not the
21 features.**

Three reasons. Testing the bands one at a time has little power against an
effect spread across them. The bands of one component are correlated through
1/f structure and spectral leakage, which inflates each coefficient's standard
error while leaving a joint test unaffected, and a correlated block is exactly
what a joint test is for. And the cluster-level question is the one the
manuscript asks, which is about regions.

One model containing all 21 features is not an option: only three participants
contribute a component to all seven clusters, so it would run on three people.

What this rules out is forming a weighted composite per cluster with signs
chosen after seeing the coefficients, which is what the old `EEGIndex_new` did.

### The bound: 21 intervals

One model per feature, the feature alone, reported as an estimate and a 95%
interval with **no p and no q**. `fit_lmm21_models` renames the uncorrected p
column so it cannot be lifted into a table by accident, and `check_lmm21`
asserts that the feature table carries no `q`.

These are the precision statement the Discussion needs. The coefficient here is
a total effect; a band coefficient inside a joint model is adjusted for the
other two bands and has a wider interval because they are correlated. "How much
could left M1 alpha matter" is naturally a total, so the bound comes from this
pass and the claim comes from the other one.

The feature is centred within participant in the primary specification, matching
"within-subject centred" in the prose, so a coefficient is rating points per dB.
Specification `zfeature` repeats it z scored, and that is where the standardised
bound comes from, since a bound in dB has no scale on which to meet 5.20 rating
points.

**There is no model comparison anywhere in this folder.** No likelihood ratio, no
AIC, no BIC, and neither fitting function returns AIC or BIC columns so the
comparison cannot creep back in. The earlier version of this analysis reported
one; it was a convergence artifact, with random-slope models fitting singular,
an impossible negative dAIC, and the likelihood ratio disagreeing with the Wald
test by orders of magnitude. Those numbers must not be used.

Seven specifications run: `primary`, `zfeature`, `categorical`, `notrial`,
`rawcov`, `nocov`, `randslope`.

### Why the random intercept is primary, and what `randslope` does

`primary` uses a by-participant random intercept because that is the
random-effects structure of the mediation model these cortical terms are added
to. Keeping it makes the cluster test an addition to the model the manuscript
already reports rather than a different model.

**It is not because the random slope fails. It does not fail.** `randslope`
fits all seven clusters without a singular fit, and it does not agree with
`primary` about what survives correction. That disagreement is a result, it is
reported in the Results and in the supplement, and it is why the closing
paragraphs describe an unresolved finding with a bound rather than a clean null.

Two things follow. Do not promote `randslope` to primary on the strength of it.
And do not let any version of the old sentence, that random slope models did not
converge, return to the Methods or to a comment in this folder: it was true of
the superseded likelihood-ratio analysis and is false of this one. The paragraph
above about the convergence artifact is about that superseded analysis, not this
one, and the two must not be run together.

`report_lmm21` prints which specifications disagree with the primary about what
survives. That is the guard that matters: a re-run that quietly changed the
answer under some specification would otherwise leave the manuscript describing
a result the code no longer produces.

### What the manuscript has to say differently

"FDR-corrected across 21 features" becomes "across the seven cortical clusters".
"No cortical feature predicted perceived difficulty" becomes "no cortical
cluster contributed to perceived difficulty". The 21 still appear, as the
features behind the seven tests and as the interval table, but they are no
longer the family.

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
| `lmm21_derive_terms.m` | the mediation's within/between split and trial term |
| `fit_lmm21_models.m` | both passes: the seven cluster tests and the 21 intervals |
| `fit_cluster_lmm.m` | one cluster, three bands together, the joint Wald test |
| `fit_feature_lmm.m` | one feature, one model, one row |
| `report_lmm21.m` | the report, the manuscript numbers, the cluster and interval LaTeX tables |
| `report_lmm21_supplement.m` | the supplementary tables: the sensitivity grid, the build audit, and the intervals under every specification |
| `checks/check_lmm21.m` | the acceptance test, needs no data |

`run_lmm21` calls `report_lmm21_supplement` immediately after `report_lmm21`.
It is what makes the standardised bound traceable to a file rather than to the
console, in `lmm21_feature_intervals_all.csv`.

`bh_fdr` and `within_subject_scale` are in `../common/` because they are generic.
`bh_fdr` is also what should close the open item in the manuscript's pending
Methods notes, where the Benjamini-Hochberg values in the Figure 5 paragraph
were computed by hand. Those notes are kept with the manuscript, not in this
repository.

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

Outputs go to `<repo>/figures/LMM21/`, alongside `ERSP_QC/` and `Figure5/`. That
is the output folder at the repository root, `cfg.figures`, not the code folder
`code/figures/`.

| Written by | File |
|---|---|
| `run_lmm21` | `lmm21_cluster_tests.csv`, `lmm21_feature_intervals.csv`, `lmm21_sensitivity.csv`, `lmm21_results.mat` |
| `report_lmm21` | `lmm21_stats_report.txt`, `lmm21_cluster_table.tex`, `lmm21_supplementary_table.tex`, `lmm21_feature_audit.csv` |
| `report_lmm21_supplement` | `lmm21_sensitivity_table.tex`, `lmm21_audit_table.tex`, `lmm21_feature_intervals_all.csv` |

Both tables are ordered by the cluster order of `lmm21_config`, not by p, so
that the left and right of a pair sit together and the reader is not invited to
read the ranking as the finding.

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