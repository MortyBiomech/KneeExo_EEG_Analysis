# Credits and provenance

Parts of this analysis are built on code written by other people. This file records
what came from where, so that the attribution survives independently of the comment
headers inside individual files.

**Do not strip the author headers from any file in `vendor/` or `archive/`.** They are the
primary attribution; this file is a summary of them.

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
GPL-3.0 applies to this work as well. Linking to her repository instead of shipping her
files would not change that, because a derived file carries the licence of what it was
derived from.

**This repository is therefore released under GPL-3.0.**

What that requires in practice:

1. A full `LICENSE` file containing the GPL-3.0 text at the repository root.
2. The original copyright and author notices left intact in every file that came from
   upstream. They are the primary attribution; this file only summarises them.
3. A note in each modified file saying what was changed and roughly when. The files in
   `vendor/` and `archive/` carry these already.
4. Source available to anyone who receives the code, which a public repository satisfies.

GPL-3.0 is a normal choice for this kind of work. FieldTrip is GPL, and much of the mobile
EEG tooling around it is too, so nothing downstream is blocked by it.

This is a reading of the licence, not legal advice. If TU Darmstadt has a technology
transfer or open-source office, a five-minute check with them costs nothing, and it is
worth telling Noelle Jacobsen that her code is being redistributed here under GPL-3.0
before the repository goes public.

### What derives from it

| File here | Origin |
|---|---|
| `vendor/mod_std_precomp_v_forEEGlabv2021.m` | EEGLAB `std_precomp`, modified by Jacobsen and Studnicki following Gwinn: per-participant or group-median warp latencies, and `'median latency baseline'` |
| `vendor/std_stat_clusterpval.m` | EEGLAB `std_stat`, modified to return cluster p-values as well as masks |
| `vendor/std_erspplot_myparams.m` | EEGLAB `std_erspplot`, modified to accept an ERSP parameter override |
| `precompute/run_epoching_timewarp.m` | derived from `Step5_epoching_timewarp.m` |
| `archive/my_plotERSPSfromSTUDY.m` | Jacobsen 2021, last modified by her 2023, adapted here 2025 |
| `archive/oneSubPerCluster.m` | Jacobsen |
| `archive/add_anatomical_labels.m` | Jacobsen |
| `archive/getplotParams.m`, `savethisfig.m`, `calldefinedcolormap.m` | Jacobsen |

The figures in the current manuscript are drawn by code written for this project, but the
statistical approach and the plotting conventions they inherit come from the files above.

### Papers to cite

- Jacobsen, N. A., & Ferris, D. P. (2023). Electrocortical activity correlated with
  locomotor adaptation during split-belt treadmill walking. *The Journal of Physiology*.
  https://doi.org/10.1113/JP284505
  `<confirm volume, issue and page range>`
- Jacobsen, N. A., & Ferris, D. P. (2024). Exploring electrocortical signatures of gait
  adaptation: differential neural dynamics in slow and fast gait adapters. *eNeuro*, 11(7),
  ENEURO.0515-23.2024. `<confirm author list>`

---

## Other third-party code

| File | Author, licence |
|---|---|
| `vendor/vline.m` | Brandon Kuczenski, 2001. BSD 2-clause. Ships with `vendor/vline_license.txt` |
| `archive/calc_clust_effectsize.m` | Adapted from Arnaud Delorme's cluster effect size code in the Donders Institute `infant-cluster-effectsize` repository |

---

## Toolboxes

Not redistributed here; cite them in the manuscript.

- **EEGLAB**. Delorme, A., & Makeig, S. (2004). EEGLAB: an open source toolbox for analysis
  of single-trial EEG dynamics including independent component analysis. *Journal of
  Neuroscience Methods*, 134(1), 9-21.
- **BeMoBIL pipeline**. Klug, M., Jeung, S., Wunderlich, A., Gehrke, L., Protzak, J.,
  Djebbara, Z., Argubi-Wollesen, A., Wollesen, B., & Gramann, K. (2022). The BeMoBIL
  Pipeline for automated analyses of multimodal mobile brain and body imaging data.
  *bioRxiv* 2022.09.29.510051. `<check for the published version>`
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

---

## Suggested manuscript acknowledgement

> Parts of the analysis pipeline, in particular the time-warped event-related spectral
> perturbation computation and the cluster-level statistics, were adapted from code
> developed by Noelle Jacobsen in the Human Neuromechanics Laboratory at the University of
> Florida, with contributions from Amanda Studnicki and Joe Gwinn. We thank them for making
> it available.

Adjust once you have confirmed with her how she would like to be credited, and whether the
associated papers should be cited in the Methods rather than the acknowledgements.

---

## This work

Analysis code for the knee exoskeleton EEG study by Morteza Khosrotabar, Lauflabor
Locomotion Lab, Institute of Sport Science, Technische Universität Darmstadt.

Funded by LOEWE "WhiteBox" and DFG RTG 2761 LokoAssist.