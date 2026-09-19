# Cortical and neuromuscular correlates of graded physical demand during knee-exoskeleton-assisted tracking

Analysis code for the KneeExo-EEG mobile brain/body imaging (MoBI) study.

Participants performed a seated knee flexion and extension angle-tracking task
while wearing a knee exoskeleton driven by a pneumatic artificial muscle (PAM)
at three assistance pressures (1, 3 and 6 bar). Each trial was rated for
perceived difficulty on a 1 to 10 scale. Recorded modalities: 64-channel EEG
(LiveAmp, 500 Hz), 6-channel EMG (Delsys Trigno, 2000 Hz), and knee encoder,
reference angle and force sensor signals, all captured together over LSL.

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

Released under **GPL-3.0-or-later**, see [LICENSE](LICENSE). The licence is not
a free choice: `code/vendor/` redistributes forked EEGLAB functions from Noelle
Jacobsen's GPL-3.0 repository, and GPL-3.0 is copyleft, so it applies to this
work as a whole. [`Credits.md`](Credits.md) records the provenance file by file
and what the licence requires in practice: the original copyright and author
notices stay intact in every file that came from upstream, each modified file
states what was changed, and the source stays available to anyone who receives
the code.

If you use this code, please cite the manuscript and this repository; see
[CITATION.cff](CITATION.cff).

---

## Notes and caveats

- Analyses reported here are a subset of those explored during the project.
  Superseded code is kept in `code/archive/`, which is never on the path, so
  that earlier answers stay recoverable. Analyses not reported in the
  manuscript are not included.
- Participant exclusions differ by analysis and are not interchangeable. The
  nominal list is 5 to 18; participants 1 to 4 lost most of their EEG
  recording. EMG analyses additionally exclude sub-10, which has no usable EMG.
  `cfg.subjects` and `cfg.subjectsEMG` carry the two lists, and each script
  states which it uses.
- The experimental protocol changed after sub-9, in the beep encoding and in
  the timing of the pressure change, so code touching raw streams branches on
  `subject_id > 9`.
- Two stages need a person in the loop and cannot be recomputed: the flexion
  and extension event editor, and the brain component review. A third, the
  AMICA decomposition, is unreproducible for a different reason: it starts from
  a random initialisation, so component numbering is valid only for the
  deposited decomposition. `code/README.md` explains all three.