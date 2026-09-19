# behaviour/

Perceived difficulty, tracking error, muscular effort, and the mediation that
connects them. This is Figure 2 and the behavioural half of the Results.

It is a **branch**, not a link in the EEG chain. It reads the per-trial data
from stage 2 and never rejoins: stage 3 goes back to the cleaned datasets from
stage 1. You can skip this folder entirely and still produce Figures 3 and 4,
and you can run this folder without ever touching AMICA or the STUDY.

```
stage 2: epoched trial data (EEG, EMG, EXP)
   │  run_build_masters.m                                        B1
   ▼
emg_master_*.mat   trk_master_*.mat   behaviour_table.mat
   │  run_results_behaviour.m                                    B2
   ▼
Figure 2, statistics, mediation, paste-ready LaTeX
```

## The one idea worth reading before the code

**Every raw trial and every raw epoch gets a row. No row is ever removed.**
Quality is recorded as boolean columns, and the screening happens once, later,
in `screen_epochs`.

That is not tidiness. The pipeline this replaced compacted trial indices in
the EMG builder but not in the tracking one, so the two disagreed for
participants 9, 11, 12 and 18. Inside a trial it read signals at the raw epoch
index but event boundaries at a compacted one, so every epoch after the first
skipped one was warped on a neighbour's reversal point. Neither fault
announces itself. The values stay valid and simply attach to the wrong row,
which is the kind of error that survives every plot you look at.

The key is `(SubjectID, RawTrial, RawEpoch)`, assigned before anything is
judged good or bad. Position never carries identity.

## Files

| File | What it does |
|---|---|
| `run_build_masters.m` | **Entry point B1.** Runs the three builders in order, with a flag each |
| `build_emg_master.m` | one row per raw EMG epoch, unnormalised iEMG, twelve quality flags |
| `build_tracking_master.m` | same key, encoder and reference angle stored raw |
| `screen_epochs.m` | the single definition of a valid trial |
| `build_behaviour_table.m` | epochs to trials, normalise within subject, join the modalities |
| `run_results_behaviour.m` | **Entry point B2.** Statistics, all three rows of Figure 2, mediation |
| `build_stamp.m` | the provenance struct saved beside every table: when, by which builder, that builder's file date, the git commit, the subject list |
| `checks/` | one-off diagnostics, not on the run path. See below |

`build_stamp` is no longer only a behaviour helper. `lmm21/` calls it directly,
for both the feature cache and the results file, and `coupling/` carries a local
`coupling_stamp` that mirrors it because `build_stamp` cannot yet take an
arbitrary builder path. If it is ever generalised, it belongs in `../common/`
with `bh_fdr` and `within_subject_scale`, and the coupling copy should be
deleted in the same change.

Run order: `run_build_masters` once, then `checks/acceptance_test`, then
`run_results_behaviour`.

## Three decisions that are easy to get wrong

**The subject list includes sub-10.** `cfg.subjects` is 5 to 18 and the
builders take all of it. Sub-10's EMG stream exists but contains only zeros,
and that is recorded as `SignalHasVariance = false` rather than by omitting
the participant. The old pipeline handled it with a hand-edited list and a
comment, where it was invisible and could not be revisited. Use
`cfg.subjectsEMG`, which drops sub-10, in analyses, never in the builders.

**The screening policy is `'intersection'`.** A trial counts only if it
survives both streams. This costs data: the tracking-only set holds about 13
per cent more trials. It is the right default anyway, because the mediation
needs a rating, an EMG value and a tracking value on the same trial and so
runs on the intersection regardless, and behavioural means quoted from a
larger set would not reconcile with the models printed beside them. If you
report a tracking-only analysis, the Methods must state both counts.

One asymmetry inside that policy is deliberate: a participant with no usable
EMG is kept for the behavioural and kinematic analyses. A missing EMG
recording is a fact about the EMG, not about that person's ratings.

**Error is a mean absolute difference, not a root-mean-square.** The masters
store the encoder and reference angles rather than a derived error, precisely
so the definition is visible where it is used, and the behaviour table carries
both `Error` (mean absolute) and `RMSError`. Per-epoch RMS runs 1.216 times
larger: 7.01, 7.49, 7.63 against the published 5.73, 6.06, 6.19. **The
published numbers are right and the manuscript's description of them as
root-mean-square is wrong.** `checks/error_definition_check.m` is what
established that, by evaluating four candidate definitions on one grouping.

## checks/

Nothing here is on the run path. Each answers a question that came up once,
and each is kept because the answer is load-bearing somewhere.

| File | The question it answers |
|---|---|
| `acceptance_test.m` | does the rebuild reproduce the validated condition means? |
| `epoch_correspondence_check.m` | do the streams agree on epoch counts, so one key serves every modality? |
| `error_definition_check.m` | which error definition produced the published values? |
| `expdata_alignment_check.m` | does the Trials_Info duplication reach the epoched data too? |
| `subject10_emg_check.m` | is sub-10's EMG real, so effort is n = 14 rather than n = 13? |

**Run `acceptance_test.m` before building anything on the masters.** It checks
the rebuilt pipeline against values validated from the old one, with a
tolerance per measure set at roughly a tenth of that measure's
between-subject SD. A pass means the old numbers were sound and only the
plumbing was fragile, so the manuscript text stands. A fail means one of the
two is wrong and which has to be settled before any number reaches the paper.

`subject10_emg_check.m` is still open, and it changes a number in the paper.
The old pipeline excluded that participant by hand; the rebuilt master finds
2375 epochs across 179 trials for them with all four muscles located. Both
cannot be true. If the recording is real, the effort analysis gains a
fourteenth participant.

## Outputs

Under `cfg.masters`, which is `<cfg.raw>/7_Master_Tables/` and therefore sits
with your data, not in the repository:

```
emg_master_sub-<N>.mat      E, Tr, Sig, Tim, muscles      gigabytes
trk_master_sub-<N>.mat      X, Tr, Enc, Ref, Tim
emg_master_index.mat        epoch and trial tables, no signals, plus stamp
trk_master_index.mat        the same for tracking
behaviour_table.mat         T, one row per trial, info, stamp
```

**The last three are also committed**, in `data/derived/`, together with
`figure2_precomputed.mat`, which holds the cycle curves and the permutation
results. With those four, a fresh clone runs `run_results_behaviour` end to
end, Figure 2 included, without downloading anything: the curves would
otherwise need the gigabyte per-subject files, and the permutation tests take
minutes.

Each carries a `stamp` struct recording what built it, and the precomputed
file also stores the screening policy, warp grid, permutation count and seed
it was built under, so a settings change is refused rather than plotted.
Rebuild and re-commit them in the same commit as any change to a builder or to
`screen_epochs`. See `data/README.md`.

Figures go to `cfg.figures`, at the repository root, with Figures 3 and 4.
The old code wrote them into the data tree under `8_Figures`.

## Requires

Statistics and Machine Learning Toolbox: `isoutlier` in the screening,
`fitlme` and `friedman` and `signrank` and `fitrm` in the results, `coefCI`
for the mediation intervals.

## References

Maris, E., & Oostenveld, R. (2007). Nonparametric statistical testing of EEG-
and MEG-data. *Journal of Neuroscience Methods*, 164(1), 177-190. The
cluster-based permutation test used on the cycle-resolved curves.

Rouder, J. N., Speckman, P. L., Sun, D., Morey, R. D., & Iverson, G. (2009).
Bayesian t tests for accepting and rejecting the null hypothesis.
*Psychonomic Bulletin & Review*, 16(2), 225-237. Behind the JZS Bayes factors,
if the equivalence analysis is brought back in.