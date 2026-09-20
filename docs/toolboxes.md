# External toolboxes

**The version table lives in [`code/README.md`](../code/README.md).** It is the
single place the toolbox versions the analysis ran under are written down, so
that a second copy here cannot drift away from it. This file covers how
`kneeexo_config` finds each toolbox, which plugins are required, and the one
known clash.

---

## How they are located

Only BeMoBIL is included in this repository, as a git submodule. The rest are
installed separately. Put each on the MATLAB path and `kneeexo_config` finds it
automatically, or set the corresponding `cfg` field explicitly in
`config/local_paths.m`.

| Toolbox | Found via | `cfg` field |
| --- | --- | --- |
| [EEGLAB](https://sccn.ucsd.edu/eeglab/) | `which('eeglab.m')` | `cfg.eeglab` |
| [FieldTrip](https://www.fieldtriptoolbox.org/) | `which('ft_defaults.m')` | `cfg.fieldtrip` |
| [xdf-Matlab](https://github.com/xdf-modules/xdf-Matlab) | `which('load_xdf.m')` | `cfg.xdf` |
| [BeMoBIL pipeline](https://github.com/BeMoBIL/bemobil-pipeline) | see below | `cfg.bemobil` |

`config/local_paths.m` is gitignored, so your machine's paths never enter the
repository. Every field in it is optional.

---

## BeMoBIL

BeMoBIL runs unmodified, so it is tracked as a **git submodule** under
`external/bemobil-pipeline`, pinned to the commit the published analysis was
run with. `git submodule status` prints that commit. A fresh clone needs

```bash
git clone --recurse-submodules https://github.com/MortyBiomech/KneeExo_EEG_Analysis
# or, in a clone you already have:
git submodule update --init
```

`add_code_paths(cfg, 'bemobil')` puts it on the path, and only the two stages
that need it ask for it: `data_processing/run_preprocessing.m` and
`study/run_group_clustering.m`. It raises a named error, rather than failing
deep inside a load, if the submodule is missing or empty.

**Locating it is deliberately not a plain `which`.** If a copy of the pipeline
ever sits somewhere under `code/`, `which` finds that copy, `cfg.bemobil` then
points at it, and the repository silently runs something other than the pinned
commit. `locate_bemobil` checks `which('bemobil_process_all_EEG_preprocessing')`,
warns when it resolves outside `cfg.bemobil`, and falls back to
`external/bemobil-pipeline`. `kneeexo_config` refuses a BeMoBIL copy found
inside `cfg.code` outright.

The one BeMoBIL function that was modified does not live in `external/`. It is
`code/vendor/repeated_clustering_and_evaluation_custom.m`; see
`code/vendor/README.md`, which also records that nothing currently calls it.

You only need BeMoBIL to re-run the pipeline from the raw recordings. Every
analysis that starts from the committed derived data runs without it.

---

## EEGLAB plugins

Required: **AMICA** (ICA decomposition), **ICLabel** (component
classification), **dipfit** (dipole fitting), **Zapline-Plus** (line-noise
removal), and the **FieldTrip** plugin, whose bundled AAL atlas
(`template/atlas/aal/ROI_MNI_V4.nii`) is what `study/add_anatomical_labels.m`
reads.

**SIFT** is needed only for the connectivity analysis, which is not part of the
manuscript figures reproduced here.

The three forked EEGLAB functions are in `code/vendor/`, not in the toolbox
folder, each with a FORK NOTICE saying what was changed and why. They were
taken from an older EEGLAB release than the one the analysis ran under. Results
were not observed to depend on the EEGLAB version, but `code/vendor/README.md`
is where to look before assuming that.

---

## MathWorks toolboxes

| Toolbox | Needed for |
| --- | --- |
| Statistics and Machine Learning | `fitlme`, `fitrm`, `friedman`, `signrank`, `coefCI`, `isoutlier`, `mad`, `knnsearch`, `meanEffectSize`, `prctile`, `iqr`. Needed by nearly every folder |
| Signal Processing | `butter` and `filtfilt`, in `data_processing/extract_epochs.m` only, for the EMG linear envelope. Nothing else calls it, and `coupling/` deliberately avoids it because `xcorr_pearson` replaces `xcorr` |
| Image Processing | `bwboundaries`, in `compute/plot_qc_sanity.m`, for the significance mask outlines |
| Parallel Computing | `parfor`, in the bootstrap of `compute/cluster_effect_size.m`. Without it the loop still runs, serially |

**Not required, despite what earlier notes said.** The Wavelet Toolbox is not
used anywhere; `cwt` is never called, and the Morlet decomposition runs through
EEGLAB's own `newtimef` and `timefreq`. The Bioinformatics Toolbox is not used
either; `mafdr` appears once in the repository, in a comment in
`common/bh_fdr.m` explaining why that function exists instead of it. The System
Identification Toolbox is not used at all.

The functions in `coupling/` and `lmm21/` use `arguments` blocks for name and
value validation, which needs R2019b or later. The effect-size code uses
`meanEffectSize` with name and value syntax, which is considerably newer; the
version the analysis ran under is in `code/README.md`.

---

## One known clash

Cleanline depends on Chronux, which ships its own `jackknife()` that shadows
the MATLAB function. If `meanEffectSize` fails inside a bootstrap, that is why.

More generally, if anything resolves to the wrong file:

```matlab
which -all <function name>
```

More than one hit means a shadow. The usual causes are an old analysis folder
still in a saved MATLAB path, `code/archive/` added by hand, or a second copy
of a toolbox inside the repository.