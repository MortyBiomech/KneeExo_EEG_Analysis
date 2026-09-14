# `code/coupling/`

Coupling between parieto-occipital band power and knee tracking error across the
movement cycle. Produces Figure 5.

## The question, and why the obvious analysis does not answer it

Theta and alpha power in the parieto-occipital clusters rise and fall twice per
movement cycle. So does the tracking error. Two signals that share a cyclic
structure correlate strongly whether or not they have anything to do with each
other, so a high correlation between their mean waveforms is a statement about
the task, not about the brain.

The question worth asking is the trial-level one: when the error on a particular
trial is larger than that participant's usual waveform, is the power on that same
trial also displaced, and if so, does the displacement lead or follow?

The analysis therefore runs three modes on the same prepared data.

| Mode | What is correlated | What it shows |
|---|---|---|
| `mean` | the mean cyclic waveform of each participant and condition | the shared cyclic structure, nothing more |
| `actual` | every trial as recorded | dominated by the same cyclic structure |
| `residual` | condition mean removed from both signals first | trial-to-trial covariation, which is the answer |

`actual` and `residual` are tested against a null built by permuting the trial
labels of the power within each participant. That null leaves every marginal
property of both signals untouched, including the cyclic waveform, the trial
count and the condition structure. Only the pairing changes, so the test asks
exactly one question: does the power of *this* trial know about the error of
*this* trial.

The `mean` mode has one waveform per participant and condition, so there are no
trial labels left to permute and no null is computed for it.

## Where the settings live

All of them are in `coupling_config.m`, including which cluster is analysed and
the three raw data folders. Both the entry point and the audit script read it,
so the two can never disagree about what they are working on. They carry only
run-time choices: whether to rebuild a cache, and whether to reuse a stored
result.

The three raw folders are spelled out there rather than looked up in `cfg` by a
generic field name. A name such as `epoched` means the single-subject EEG epochs
in one part of this project and the epoched experiment streams in another, so a
config lookup can silently resolve to the wrong tree and the analysis then reads
the right file name out of it. `coupling_config` therefore checks, before
anything else runs, that each folder holds the file that identifies it, for
every participant, and names what is missing if it does not.

## Two ways in

```matlab
epoch_pairing_check        % in checks/, audits the join between the streams
run_cross_correlation      % entry C1, the analysis and the figure
```

Either can be run first. Both call `ensure_coupling_inputs`, which builds the
cached inputs when they are missing and loads them when they are not, so the
audit is not waiting on the analysis to produce something for it to audit. On a
clean checkout the first of the two to run pays the build cost, which needs
EEGLAB for the pairing step, and the second reads the caches.

Run the audit first. It is the cheaper of the two and it is what tells you
whether the join is sound before any correlation is computed.

## Pipeline

| Step | File | Output |
|---|---|---|
| 1 | `build_epoch_pairing.m` | which EEG epoch is which experiment epoch |
| 2 | `build_warped_tracking_error.m` | error on the EEG movement-cycle axis |
| 3 | `load_cluster_power.m` | single-trial power of the cluster component |
| 4 | `prepare_trial_matrices.m` | band averaged, aggregated, split by condition |
| 5 | `crosscorr_permutation.m` | group statistic and its null |
| 6 | `plot_figure5_coupling.m` | the figure |

Supporting files: `coupling_config.m` holds the settings,
`ensure_coupling_inputs.m` builds or loads steps 1 to 3, `read_cycle_axis.m`
reads the movement-cycle axis from a time-frequency file without loading any
component data, and `xcorr_pearson.m` is the numerical core used by step 5.

Steps 1 and 2 are the slow ones and are cached in `data/derived`. Step 1 reads
the `urevent` tables of the per-participant datasets rather than any cluster
solution, so **its result is shared by every cluster** and does not need
rebuilding when the cluster changes. Step 2 is rebuilt automatically if the
cached error sits on a different cycle axis from the one the EEG uses.

## The problem step 1 solves

Each stream was cleaned on its own terms. The EEG lost epochs to artefact and
component rejection, the experiment stream lost epochs to its own completeness
criteria, and neither file carries an index into the other. The two survivor sets
are different subsets of the same movement cycles, so joining them by position
would silently compare the power of one cycle against the error of another.

The join goes through the event tables. Every epoch in the single-trial
time-frequency file records `trialinfo.init_index`, the index of the event that
opened it. The same index appears in `EEG.urevent` alongside the event latency in
samples. Converting that latency to milliseconds gives the absolute onset of the
epoch, which is matched against the first time sample of every surviving
experiment epoch by nearest neighbour. `build_epoch_pairing` returns the residual
distance of every match, and `epoch_pairing_check` reports its distribution, so
the quality of the join is auditable rather than assumed.

This belongs in the Methods of the paper. It is the step that makes the coupling
analysis defensible at all.

## What changed relative to the original scripts

The original pair was `main_cross_correlation_data_preparation.m` (438 lines) and
`main_cross_correlation_analysis.m` (1,464 lines). The analysis ran four
near-duplicate copies of the same code, labelled Options 1A, 1B, 2A and 2B.

### Corrections

**The two signals now share one cycle axis.** The EEG was warped to a group
target derived from the EEG epoching, and the original warped the tracking error
to a second group target derived independently from the experiment stream. Two
medians of the same physical landmark, taken over different epoch subsets, do not
coincide, so mapping both onto a nominal 0 to 100 percent axis left the flexion to
extension transition at two different places. That displaces the peak of any
cross-correlation by exactly that difference. The error is now warped to the
landmark fraction the EEG actually uses, taken from `timewarpms`, which is the
only choice under which a lag of zero means physical simultaneity.
`epoch_pairing_check` reports the size of the gap so its effect on the original
numbers can be judged.

**The error is interpolated onto the right grid.** The original interpolated with
`interp1(1:size(Err,2), Err', new_times)`, whose sample grid runs `1:nSamples`
while the query points run 0 to 100 percent of the cycle. Unless the two happen
to coincide, that reads a fraction of the warped waveform and stretches it across
the whole cycle, and returns `NaN` wherever the query falls below 1. The warp is
now a single piecewise linear map from epoch time straight onto the EEG percent
axis, which also removes one of the two interpolations the original performed.

**Correlations are Pearson, over the overlap.** The original used
`xcorr(..., "normalized")`, which does not remove the mean of either signal, so
with raw spectral power and an unsigned tracking error the result is dominated by
the product of the two means. It also normalises every lag by the full-length
norms while the sum at lag L runs over only `nTime - |L|` products, so the
estimate decays towards zero as the lag grows even when the true correlation is
constant. On a 180-sample cycle at a lag of 60 samples this shrinks a true
correlation of 1.0 to 0.67, which pulls any peak-lag estimate towards zero.
`xcorr_pearson` removes both means and normalises by the actual overlap. It is
FFT based, so it is no slower, and it needs no Signal Processing Toolbox.

**The claim is now tested.** The original computed per-participant peak markers
with `max` over 101 lags of the signed correlation. A maximum over many lags is
positively biased even under a true null, and a maximum of a signed correlation
can never be negative, so those markers cannot support a statement that something
is near zero, in either direction. The group mean curve is now tested against a
trial-shuffled null, with the maximum absolute group mean over lags as the
omnibus statistic, which controls the family-wise error rate across lags without
a further correction.

**Participants are selected by membership, not by row number.** The original
removed row 10 of the cell arrays with `R_theta_mean_abs(10, :) = []`, repeated
eight times. That is correct for the left parieto-occipital cluster, where
participant 14 is the one without a component, and wrong for any other cluster.

**`rLags_trials_alpha` is preallocated.** In Options 1A and 2A it was not, so it
kept its size from the previous condition. Where a later condition had fewer
trials, the trailing rows of the earlier condition survived into the alpha
result. Theta was unaffected. This silently contaminated the alpha residual
analysis, which is one of the two results the paper rests on.

**`Subject_sigend_R` is no longer reset inside the plotting loop.** In Options 2A
and 2B it was re-initialised on every iteration, discarding what had accumulated.

**Subject numbers come from the participant list.** The original used
`SUBJECTS_ICS{...}.Subjects + 4`, hard-coding the offset between cluster indices
and participant numbers.

**Epochs are matched by trial and epoch number, not by row position.** The
original relied on the surviving experiment epochs, in experiment order, being
the same sequence as the time-frequency epochs in time-frequency order. That is
usually true and fails silently when it is not.

### Simplifications

**Four options became two flags.** `AGGREGATE` chooses the observation level and
the three modes are computed in one pass. Options 1 and 2 of the original differed
only by a divisive baseline applied before the band average. A Pearson correlation
is invariant to positive rescaling, so that baseline cannot change a correlation
except through the relative weighting of frequencies inside a band. It is kept as
`BASELINE = 'divisive'` for comparison, not because it should matter. The original
section header called it dB, but no logarithm was taken anywhere.

**Paths come from `cfg`.** No `cd`, no `D:\Morteza\...`, no `addpath(genpath(...))`.

**Every assumption fails loudly.** Dataset to participant lookup, `init_index`
uniqueness, match residuals, one-to-one pairing, shared frequency and time axes,
epoch counts, and mixed pressure within a trial all raise a named error rather
than producing a plausible wrong number.

The original pair holds 1,187 executable lines and this folder holds 1,286, but
the original had one analysis where this has three modes, no statistical test
where this has a permutation null, no caching, no audit script, and no error
checking. Counting only the cross-correlation and plotting itself, the four
duplicated option blocks collapse from 923 lines to 106.

## Choices the Methods must state

These are decisions the code makes that a reader cannot infer from the figure.

- **`AGGREGATE`**. With `'trial'`, the movement cycles of a trial are averaged
  before correlating, so a residual is a **trial-to-trial** fluctuation. With
  `'epoch'`, every cycle is its own observation and a residual is a
  **cycle-to-cycle** fluctuation. The original averaged within trial, so the
  comment in it describing cycle-to-cycle fluctuations did not match what it did.
  The manuscript wording has to follow the flag.
- **`DROP_ZERO_SCORE`**. Trials with a recorded score of zero are excluded. The
  reason for that exclusion belongs in the Methods.
- **Which cluster**. Only one cluster is analysed per run. The Figure 4 text
  describes both parieto-occipital clusters, so either run both and report both,
  or restrict the sentence.
- **Sign convention**. A positive lag means power follows error.
- **The lag window is half a period, not a whole one.** Both signals complete two
  cycles per movement, so their lagged correlation is itself periodic with a
  period of about 50% of the cycle. At a lag of 50% each bump aligns with the
  next bump, which returns a correlation as high as the one at lag zero, so a
  peak searched over plus or minus 50% cannot distinguish simultaneity from a
  whole period of displacement. `C.maxLagPct` is therefore 25.

## The figure

Three panels, not one per condition and band.

| Panel | Shows | Claim |
|---|---|---|
| a | mean cyclic waveforms of error and of each band, percent change from the cycle mean, s.e.m. across participants, peak offsets marked | both signals cycle twice per movement |
| b | lagged correlation, mean waveforms against trial-wise residuals, permutation null shaded | cycle-locked, not trial-locked |
| c | peak r per condition and band, both modes, against the same null | pressure changes neither |

The per-condition curves are near copies of one another, which is itself a
result, so the figure states it once in panel c rather than nine times. Two
things are deliberately absent. The per-participant peak marker, because a
maximum over many lags is positively biased under a true null and a maximum of a
signed correlation can never be negative, so it cannot be read as evidence
either way. And a second y axis in panel a: the alignment of two y scales is
arbitrary, so both signals go on one axis as percent change from their own cycle
mean instead.

## Outputs

| File | Location | Size |
|---|---|---|
| `epoch_pairing_map.mat` | `data/derived` | small, ship it |
| `tracking_error_warped.mat` | `data/derived` | about 15 MB, ship it |
| `figure5_coupling_<cluster>.mat` | `data/derived` | small, ship it |
| `figure5_coupling_<cluster>.pdf` | `figures/` | the figure |

With those three `.mat` files present the figure redraws without the
`.icatimef` files, the same way `figure2_precomputed.mat` works for Figure 2.
The inputs that stay in the data deposit are the per-participant `.icatimef`
files and the epoched experiment data.

## Dependencies

EEGLAB is needed only for step 1, which reads the `urevent` tables through
`pop_loadstudy`. Steps 2 to 6 need only base MATLAB plus `prctile` and `iqr` from
the Statistics and Machine Learning Toolbox. The Signal Processing Toolbox is not
needed: `xcorr_pearson` replaces `xcorr`.

The functions use `arguments` blocks for name-value validation, which needs
MATLAB R2019b or later.

## Note on `coupling_stamp`

`ensure_coupling_inputs.m` carries a local `coupling_stamp` that mirrors
`behaviour/build_stamp.m`. If `build_stamp` is ever generalised to take an
arbitrary builder path, delete the local copy and call it instead.
