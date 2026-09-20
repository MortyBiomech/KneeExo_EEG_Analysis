# Cortical and neuromuscular correlates of graded physical demand in human-exoskeleton interaction

Analysis code for the KneeExo-EEG mobile brain/body imaging (MoBI) study.

Fourteen participants performed a seated visuomotor pursuit-tracking task with
the right leg while wearing a custom single-degree-of-freedom knee exoskeleton
actuated by a pneumatic artificial muscle (PAM). Knee angle set the vertical
position of a marker on a display, a reference sinusoid scrolled past at a
constant rate, and the task was to keep the marker on the reference. The
reference was individualised for each participant beforehand, from one minute
of free movement in the exoskeleton with the PAM detached, so the movement to
be tracked was the same at every level of demand.

**The exoskeleton imposed demand.** The PAM was routed over
the anterior aspect of the knee, so pressurising it produced a knee-extension
torque that the wearer worked against during flexion and restrained during
early extension. Supply pressure was set to Low (1 bar), Medium (3 bar) or High
(6 bar), a six-fold range. Because only the imposed load changed while the
reference stayed fixed, differences across the three levels are read as
physical demand rather than as a change in the required movement.

After each 20-second trial, participants verbally rated perceived difficulty
from 1 (easy) to 10 (difficult). Each participant completed 120 trials, 40 per
level, in permuted blocks of three across four sessions in one day.

Three streams were recorded and synchronised through the Lab Streaming Layer.
64-channel EEG (actiCAP slim with a LiveAmp amplifier, 500 Hz, referenced
online to FCz), surface EMG of four right-leg muscles (Trigno Avanti, 2000 Hz),
and an experiment stream carrying knee angle from a rotary encoder at the
hinge, the auditory cues, and each trial's pressure level and reported score.
PAM force was recorded from a load cell in six participants only, and the
manuscript does not report force. The experiment stream has no fixed sample
rate, because samples were pushed as they became available, so aligning it
rests on its per-sample LSL timestamps.

> **Status.** This repository accompanies a manuscript in preparation. Figure
> and section numbers refer to that manuscript and may change before
> publication.

---

## Start here

**[`code/README.md`](code/README.md) is the operational guide.** It holds the
stage table, the entry point for every analysis, the configuration rules and
the manual steps. This file is the front door: what the study is, what is in
the repository, and what you can run.

---

## What is here

```
code/          all analysis code, one folder per stage or analysis
config -> code/config   kneeexo_config.m, the only file that knows a path
data/derived/  derived data committed so the analyses run without a download
docs/          pipeline notes and toolbox setup
external/      unmodified third-party toolboxes, as git submodules
figures/       output directory, created on first run, not tracked
```

The raw recordings are not in this repository; they are far too large. What is
committed in `data/derived/` is enough to reproduce a substantial part of the
manuscript on a fresh clone, with nothing downloaded.

Note that `figures/` at the repository root is the **output** directory and is
not tracked. The figure **code** lives in `code/figures/`, which is tracked
like every other code folder.

---

## What runs on a fresh clone

| | Needs nothing | Needs the data release |
|---|---|---|
| Figure 2, its statistics and the mediation | yes | |
| Figure 5, left parieto-occipital cluster | yes, redraws from the committed coupling files | tier 2 to rebuild from the decompositions, or to run another cluster |
| The trial-level cortical LMM (closing Results paragraphs) | yes, from the committed feature cache | tier 2 to rebuild the features |
| Figures 3 and 4, the cluster ERSPs | | tier 2 |
| Every upstream stage: import, cleaning, AMICA, clustering, precompute | | tiers 3 and 4 |

```matlab
% the whole behavioural Results, no download
addpath('code/config'); cfg = kneeexo_config(); add_code_paths(cfg);
run_results_behaviour
```

`code/README.md` explains the tiers and how to point the configuration at a
copy of the data.

---

## The analyses

| Folder | Produces | Its own README |
|---|---|---|
| `code/behaviour/` | perceived difficulty, tracking error, muscular effort, the mediation, Figure 2 | [yes](code/behaviour/README.md) |
| `code/coupling/` | parieto-occipital power against tracking error across the movement cycle, Figure 5 | [yes](code/coupling/README.md) |
| `code/lmm21/` | whether trial-level cortical band power predicts perceived difficulty, the closing Results paragraphs | [yes](code/lmm21/README.md) |
| `code/figures/` | Figures 3 and 4, the cluster ERSPs, and the statistics reports | |

The stages that feed them, from raw XDF to the time-frequency decompositions,
are in `code/data_processing/`, `code/precompute/`, `code/study/` and
`code/compute/`. The stage table in `code/README.md` gives the order.

---

## Further reading

- [`code/README.md`](code/README.md). The stage table, entry points,
  configuration, conventions, manual steps, the data release tiers and the
  dependency table.
- [`docs/pipeline.md`](docs/pipeline.md). How the recordings become the
  numbers: the stage folders on disk, and the conventions that will bite you
  (three index spaces sharing field names, the protocol change after sub-9,
  per-analysis participant exclusions).
- [`docs/toolboxes.md`](docs/toolboxes.md). External dependencies and how
  `kneeexo_config` locates them, including BeMoBIL.
- [`Credits.md`](Credits.md). What came from where, and what the licence
  requires in practice.

---

## Requirements

MATLAB, with the Statistics and Machine Learning, Signal Processing, Image
Processing and Parallel Computing toolboxes. The external toolboxes and the
versions the analysis ran under are listed once, in the dependency table of
[`code/README.md`](code/README.md), so that the two cannot drift apart.

BeMoBIL is a git submodule. A fresh clone needs

```bash
git clone --recurse-submodules https://github.com/MortyBiomech/KneeExo_EEG_Analysis
# or, in a clone you already have:
git submodule update --init
```

---

## Data availability

The derived data needed to reproduce Figure 2, Figure 5 and the trial-level
cortical LMM is committed in `data/derived/`; see
[`data/README.md`](data/README.md) for what each file is and what wrote it.

The rest is distributed in tiers, described in `code/README.md`. The raw
recordings are not in this repository. See the Data Availability statement of
the manuscript for their location and access conditions.

---

## Licence and citation

Copyright (c) 2026 Morteza Khosrotabar.

Released under **GPL-3.0-only**, see [LICENSE](LICENSE).

The licence is not a free choice. `code/vendor/` ships forked EEGLAB functions
taken from Noelle Jacobsen's repository, and `code/precompute/`, `code/study/`
and `code/archive/` hold files derived from the same source. That repository is
GPL-3.0, GPL-3.0 is copyleft, and it therefore applies to this work as a whole.
The EEGLAB originals are not the reason. Their own headers are BSD 2-Clause,
which is permissive, so it is Jacobsen's modifications and her repository
licence that bind, not EEGLAB's.

The identifier is `GPL-3.0-only` rather than `GPL-3.0-or-later` because no file
in the chain grants the "or, at your option, any later version" permission, and
the GNU project treats that permission as something a licensing notice must
state explicitly.

[`Credits.md`](Credits.md) records the provenance file by file and what the
licence requires in practice. The original copyright and author notices stay
intact in every file that came from upstream, each modified file states what was
changed, and the source stays available to anyone who receives the code.

If you use this code, please cite the manuscript and this repository; see
[CITATION.cff](CITATION.cff).

---

## Notes and caveats

- Analyses reported here are a subset of those explored during the project.
  Superseded code is kept in `code/archive/`, which is never on the path, so
  that earlier answers stay recoverable. Analyses not reported in the
  manuscript are not included.
- **Fourteen participants, numbered `sub-5` to `sub-18`.** The numbering starts
  at 5 because participants 1 to 4 were preliminary and lost most of their EEG
  recording; they are not part of the study and are not mentioned in the
  manuscript. The highest number being 18 is not a participant count.
  `cfg.subjects` carries that list of 14. `cfg.subjectsEMG` additionally drops
  sub-10, which has no usable EMG, so every analysis involving the effort index
  rests on 13. Each script states which list it uses, and the two are not
  interchangeable.
- The experimental protocol changed after sub-9, in the beep encoding and in
  the timing of the pressure change, so code touching raw streams branches on
  `subject_id > 9`.
- Two stages need a person in the loop and cannot be recomputed: the flexion
  and extension event editor, and the brain component review. A third, the
  AMICA decomposition, is unreproducible for a different reason: it starts from
  a random initialisation, so component numbering is valid only for the
  deposited decomposition. `code/README.md` explains all three.
