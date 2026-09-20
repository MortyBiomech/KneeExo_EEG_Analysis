# Pipeline notes

How the recordings become the numbers behind the manuscript.

**The stage table lives in [`code/README.md`](../code/README.md), not here.**
That file is the single place the entry points, their order and their inputs
are written down. This file covers the two things it does not: how the data is
laid out on disk under `cfg.raw`, and the conventions that will bite you.

---

## The recording

Fourteen participants, numbered `sub-5` to `sub-18`, performed a seated
visuomotor pursuit-tracking task with the right leg while wearing a knee
exoskeleton actuated by a pneumatic artificial muscle. The PAM **imposed
demand** at three supply pressures, Low 1 bar, Medium 3 bar and High 6 bar,
written `P1`, `P3` and `P6` in the code. Each trial was rated for perceived
difficulty from 1 (easy) to 10 (difficult).

Three streams were captured together over LSL into the `ses-S00X` folders of
each participant:

| Stream | Channels | Rate |
| --- | --- | --- |
| EEG | 64 (actiCAP slim, LiveAmp, online reference FCz) | 500 Hz |
| EMG | 6 sensors worn, 4 analysed (Trigno Avanti) | 2000 Hz |
| Experiment | knee angle from the hinge encoder, PAM force in six participants only, auditory cues, pressure level and score | no fixed rate |

**The experiment stream has no nominal sample rate.** Samples were pushed to
LSL as they became available, so anything aligning it to the other two streams
has to use its per-sample LSL timestamps rather than assume a rate.

**"Session" means two different things.** The protocol has four blocks of 30
trials in one day, separated by rests of 5, 15 and 5 minutes, which is what the
manuscript calls sessions and what gives 40 trials per pressure level and 120
in total. The raw data is organised into `ses-S00X` recording folders, and
`load_xdf_sessions` documents those as `ses-S001` to `ses-S003`. The two counts
are not the same thing and are not expected to match. The loader discovers the
folders with `dir` rather than assuming a number, and concatenates several
`.xdf` files within one folder, so the recording layout can vary per
participant without the code caring.

**Six EMG sensors were worn and four are analysed.** Muscle order is positional
everywhere and is never stored by name alongside the data. The six, from Delsys
sensor ids `[2 3 4 5 6 7]`, are `Vastus_med_R`, `Rectus_femoris_R`,
`Gastrocnemius_R`, `Biceps_femoris_R`, `Trapezius_R`, `Trapezius_L`. The four
the analyses use are named in `cfg.muscles`, which stops at
`Biceps_femoris_R`. `data_processing/extract_epochs.m` carries the full list of
six because it slices the raw array; anything downstream should read
`cfg.muscles`.

---

## Stage folders under `cfg.raw`

The code addresses these by these literal names, under whatever you set as
`local.raw` in `config/local_paths.m`.

| Stage folder | Written by | Contents |
| --- | --- | --- |
| `0_source_data/sub-N/ses-S00X/eeg/*.xdf` | the recording | raw LSL streams, plus `Subjects.xlsx` |
| `1_BIDS_data` | `data_processing/run_preprocessing.m` via `bemobil_xdf2bids` | BIDS export |
| `2_raw-EEGLAB` | the same, via `bemobil_bids2set` | `sub-N_merged_EEG.set` |
| `3_EEG-preprocessing`, `4_spatial-filters/4-1_AMICA` | BeMoBIL wrappers | cleaning, ICA, dipole fitting |
| `5_single-subject-EEG-analysis` | BeMoBIL wrappers, then `precompute/` | `sub-N_cleaned_with_ICA.set`; the epoched time-warped sets and the `.icatimef` files |
| `6_0_Trials_Info_and_Events` | `data_processing/add_events.m` plus the manual editor | `sub-N_Trials_encoder_events.mat` |
| `6_Trials_Info_and_Epoched_data` | `data_processing/run_multimodal_trials.m` | `Trials_Info.mat`, the per-trial EEG, EMG and experiment data |
| `7_STUDY` | `study/run_group_clustering.m` | EEGLAB `.study` files, `multiple_clustering/<ROI>/` |
| `7_Master_Tables` | `behaviour/run_build_masters.m` | `emg_master_sub-N.mat`, `trk_master_sub-N.mat` and the index tables |
| `8_Classification/ROIs_features` | the classification analysis | `ROIs_*.mat` feature tables, not part of this manuscript |
| `9_EXP_Analysis`, `10_Time_Frequency_Analysis` | earlier exploratory stages | force and torque structures, time-frequency content |

Point `cfg.raw` at the folder containing these and every script finds them.
Two small per-participant files from `6_0_Trials_Info_and_Events` are also
copied into `data/derived/Events/` so that a reproducer has them without the
rest; `resolve_derived_file` checks the shipped folder first and the working
one second, which is what lets both layouts coexist.

---

## Things that will bite you

**Three index spaces, same field names.** `Trials_Info{1,i}.Events` mirrors the
same index fields three times over, once per stream: `EEG_stream.Raw`, indices
into the concatenated raw stream; `EEG_stream.Preprocessed`, latencies in the
cleaned `.set` after non-experimental segments were cut; then `EMG_stream` and
`EXP_stream`. Mixing them up is the single most common source of misalignment
bugs in this project.

**Two trial numberings, and they disagree.** The experiment stream's trial
number and the one `trialinfo` carries are different countings. The old EMG
builder compacted its trial indices while the tracking one did not, so the two
diverged for participants 9, 11, 12 and 18. The rebuilt masters key everything
on `(SubjectID, RawTrial, RawEpoch)`, assigned before anything is judged good
or bad, which removed the divergence. Anything joining across modalities uses
the experiment side. See `code/behaviour/README.md`.

**The protocol changed after sub-9.** The beep encoding differs, single against
double `diff` values on the trigger channel; the pressure change moves from 2 s
*before* the start beep to 2 s *after*; and epoch structures are saved
differently. Any code touching raw streams needs both branches, hence the
`subject_id > 9` tests through the import stage.

**`Case` 3 against `Case` 4** records whether a trial ends on a high or a low
encoder peak. It decides whether the last flexion start is dropped when
building flexion-to-flexion cycles. Always handle both.

**Participant exclusions are per-analysis and are not interchangeable.** Two
lists exist on purpose and both come from `cfg`. `cfg.subjects` is 5 to 18, the
group analysis; participants 1 to 4 lost most of their EEG recording.
`cfg.subjectsEMG` additionally drops sub-10, which has no usable EMG. Use
`cfg.subjectsEMG` in analyses and never in the builders: sub-10 is kept in the
masters with `SignalHasVariance = false`, so the exclusion stays visible and
revisable instead of living in a hand-edited list. Other analyses outside this
manuscript drop other participants; copy the list from the analysis you are
extending rather than assuming.

**One component can appear in two clusters.** The clustering solutions are
separate runs over the same component set, each seeded at its own ROI, so a
near-midline component can be claimed by two of them. Among the seven clusters
the trial-level LMM analyses this happens once, participant 11's IC 29, in both
premotor clusters. `Prime_Visual` overlaps `Right_Parieto_Occipital` heavily
enough that it is excluded from that family altogether. See
`code/lmm21/README.md`.

**AMICA cannot be reproduced.** It starts from a random initialisation, so two
runs on identical input give different unmixing matrices and different
component numbering. `SUBJECTS_ICS` stores integer component indices and is
therefore valid only for the deposited decomposition. Re-run AMICA and then
apply that file, and you analyse the wrong components, silently and plausibly.
This is why the post-AMICA datasets are published rather than only the raw
data.

**Fixed conventions across the manuscript.** All of them are defined once, in
`config/kneeexo_config.m`, and should be read from `cfg` rather than retyped:

- Condition colours, `cfg.colors`: P1 `[1,115,178]/255`, P3 `[222,143,5]/255`,
  P6 `[148,73,92]/255`. `config/ersp_params.m` repeats them in the design order
  Low, Medium, High.
- Frequency bands, `cfg.bands`: theta `[4 8]`, alpha and mu `[8 14]`, beta
  `[14 30]` Hz.
- A movement cycle is time-normalised to 0 to 100 percent, where 0 to 50 is
  flexion and 50 to 100 is extension.

---

## How to read the upstream scripts

The entry points named in `code/README.md` follow one shape: a single subject
list from `cfg`, stage switches beside it, a per-participant `try` and `catch`
so one broken participant does not end an overnight run, and no `cd`, file
pickers or dialogs.

`archive/` is different. The superseded scripts kept there are `%%`-section
notebooks meant to be stepped through cell by cell in the MATLAB editor, and in
several of them whole blocks are commented out **on purpose**, because that
stage was run once and its output saved. Read the section headers before
uncommenting anything, and do not put `archive/` on the MATLAB path.

Two stages in the live pipeline still need a person in the loop:
`find_flexion_extension_events.mlapp` for event verification, and
`review_components_gui` for the borderline brain components. Both write their
decisions into `data/derived/`, so you only run them for a participant nobody
has screened. `code/README.md` describes both.