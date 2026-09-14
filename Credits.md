# Credits and provenance

Parts of this analysis are built on code written by other people. This file records
what came from where, so that the attribution survives independently of the comment
headers inside individual files.

The author headers in `code/vendor/` and `code/archive/` are the primary attribution.
This file summarises them; it does not replace them, and they are not to be stripped.

---

## Upstream: the Ferris Lab pipeline

The ERSP precompute, the movement-cycle epoching with time warping, the cluster-level
statistics and the ERSP plotting all derive from work by **Noelle Jacobsen** (Human
Neuromechanics Laboratory, Daniel Ferris, University of Florida), with contributions by
**Amanda Studnicki** and **Joe Gwinn**.

Public repository: <https://github.com/jacobsen-noelle/ExoAdapt-DualEEG-Processing>

### Licence

That repository is released under **GPL-3.0**, a copyleft licence.

This repository both redistributes files from it and contains files derived from it, so
GPL-3.0 applies to this work as well. Linking to that repository instead of shipping the
files would not change it, because a derived file carries the licence of what it was
derived from.

**This repository is released under GPL-3.0.** The full licence text is in `LICENSE` at
the repository root.

Accordingly: the original copyright and author notices are left intact in every file that
came from upstream, each modified file states what was changed, and the source is
available to anyone who receives the code.

### What derives from it

| File here | Origin |
|---|---|
| `code/vendor/mod_std_precomp_v_forEEGlabv2021.m` | EEGLAB `std_precomp`, modified by Jacobsen and Studnicki following Gwinn: per-participant event latencies, and `'median latency baseline'` |
| `code/vendor/std_stat_clusterpval.m` | EEGLAB `std_stat`, modified to return cluster p-values and the FieldTrip stat structure as well as the masks |
| `code/vendor/std_erspplot_myparams.m` | EEGLAB `std_erspplot`, modified to accept an ERSP parameter override |
| `code/precompute/run_epoching_timewarp.m` | derived from Jacobsen's epoching and time-warp step |
| `code/study/add_anatomical_labels.m` | Jacobsen, AAL lookup of cluster centroids |
| `code/study/keep_one_ic_per_subject.m` | derived from Jacobsen's `oneSubPerCluster` |
| `code/archive/my_plotERSPSfromSTUDY.m` | Jacobsen 2021, last modified by her 2023, adapted here 2025 |
| `code/archive/oneSubPerCluster.m` | Jacobsen, as received |
| `code/archive/calldefinedcolormap.m` | Jacobsen |

The figures in the manuscript are drawn by code written for this project, but the
statistical approach and the plotting conventions they inherit come from the files above.

### Associated papers

- Jacobsen, N. A., & Ferris, D. P. (2023). Electrocortical activity correlated with
  locomotor adaptation during split-belt treadmill walking. *The Journal of Physiology*.
  https://doi.org/10.1113/JP284505
- Jacobsen, N. A., & Ferris, D. P. (2024). Exploring electrocortical signatures of gait
  adaptation: differential neural dynamics in slow and fast gait adapters. *eNeuro*, 11(7),
  ENEURO.0515-23.2024.

---

## Other third-party code

| File | Author, licence |
|---|---|
| `code/vendor/vline.m` | Brandon Kuczenski, 2001. BSD 2-clause. Ships with `vline_license.txt` |
| `code/archive/calc_clust_effectsize.m` | Adapted from Arnaud Delorme's cluster effect-size code in the Donders Institute `infant-cluster-effectsize` repository |

---

## Toolboxes

Not redistributed here, except the BeMoBIL pipeline, which is included as a git submodule
under `external/` and remains under its own MIT licence.

- **EEGLAB**. Delorme, A., & Makeig, S. (2004). EEGLAB: an open source toolbox for analysis
  of single-trial EEG dynamics including independent component analysis. *Journal of
  Neuroscience Methods*, 134(1), 9-21.
- **BeMoBIL pipeline**. Klug, M., Jeung, S., Wunderlich, A., Gehrke, L., Protzak, J.,
  Djebbara, Z., Argubi-Wollesen, A., Wollesen, B., & Gramann, K. (2022). The BeMoBIL
  Pipeline for automated analyses of multimodal mobile brain and body imaging data.
  *bioRxiv*. https://doi.org/10.1101/2022.09.29.510051 (preprint)
- **AMICA**. Palmer, J. A., Kreutz-Delgado, K., & Makeig, S. (2011). AMICA: An adaptive
  mixture of independent component analyzers with shared components. Technical report,
  Swartz Center for Computational Neuroscience, UCSD.
- **ICLabel**. Pion-Tonachini, L., Kreutz-Delgado, K., & Makeig, S. (2019). ICLabel: An
  automated electroencephalographic independent component classifier, dataset, and website.
  *NeuroImage*, 198, 181-197.
- **FieldTrip**. Oostenveld, R., Fries, P., Maris, E., & Schoffelen, J.-M. (2011).
  FieldTrip: open source software for advanced analysis of MEG, EEG, and invasive
  electrophysiological data. *Computational Intelligence and Neuroscience*, 2011, 156869.
- **AAL atlas**. Tzourio-Mazoyer, N., et al. (2002). Automated anatomical labeling of
  activations in SPM using a macroscopic anatomical parcellation of the MNI MRI
  single-subject brain. *NeuroImage*, 15(1), 273-289.
- **Cluster-based permutation testing**. Maris, E., & Oostenveld, R. (2007). Nonparametric
  statistical testing of EEG- and MEG-data. *Journal of Neuroscience Methods*, 164(1),
  177-190.
- **Time-warped ERSP over a movement cycle**. Gwin, J. T., Gramann, K., Makeig, S., &
  Ferris, D. P. (2011). Electrocortical activity is coupled to gait cycle phase during
  treadmill walking. *NeuroImage*, 54(2), 1289-1296.

---

## Acknowledgement

Parts of the analysis pipeline, in particular the time-warped event-related spectral
perturbation computation and the cluster-level statistics, were adapted from code
developed by Noelle Jacobsen in the Human Neuromechanics Laboratory at the University of
Florida, with contributions from Amanda Studnicki and Joe Gwinn.

---

## This work

Analysis code for the knee exoskeleton EEG study by Morteza Khosrotabar, Lauflabor
Locomotion Lab, Institute of Sport Science, Technische Universität Darmstadt.

Funded by LOEWE "WhiteBox" and DFG RTG 2761 LokoAssist.