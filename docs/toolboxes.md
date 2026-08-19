# External toolboxes

None of these are bundled. Install them separately and either put them on the
MATLAB path — `ansymb_config` finds them automatically — or set the
corresponding `cfg` field explicitly in `config/ansymb_config.m`.

| Toolbox | Version used | Found via | `cfg` field |
| --- | --- | --- | --- |
| [EEGLAB](https://sccn.ucsd.edu/eeglab/) | 2026.0.0 | `eeglab.m` | `cfg.eeglab` |
| [FieldTrip](https://www.fieldtriptoolbox.org/) | 20231127 | `ft_defaults.m` | `cfg.fieldtrip` |
| [xdf-Matlab](https://github.com/xdf-modules/xdf-Matlab) | — | `load_xdf.m` | `cfg.xdf` |
| [BeMoBIL pipeline](https://github.com/BeMoBIL/bemobil-pipeline) | see below | `bemobil_process_all_EEG_preprocessing.m` | `cfg.bemobil` |

The published analysis ran under EEGLAB 2026.0.0; earlier stages were run under
2024.2.1, 2025.0.0 and 2025.1.0 as the project progressed. Results were not
observed to depend on the EEGLAB version, but the three forked EEGLAB functions
in `code/ersp_analysis` were taken from an older release — see the FORK NOTICE
in each of them for what that means.

### EEGLAB plugins

Required: **AMICA** (ICA decomposition), **ICLabel** (component
classification), **dipfit** (dipole fitting), **Zapline-Plus** (line-noise
removal), and the **FieldTrip** plugin, whose bundled AAL atlas
(`template/atlas/aal/ROI_MNI_V4.nii`) is what `add_anatomical_labels` reads.

**SIFT** is needed only for the connectivity analysis, which is not part of the
manuscript figures reproduced here.

### MathWorks toolboxes

Statistics and Machine Learning (`fitlme`, `meanEffectSize`, `mafdr`), Signal
Processing, Wavelet (`cwt`), Image Processing (`bwboundaries`), and Parallel
Computing. Bioinformatics is used only where `mafdr` is called. System
Identification is required by one supplementary script.

MATLAB R2025b or newer. The effect-size code uses `meanEffectSize` and
name=value syntax, neither of which exists in older releases.

---

## BeMoBIL

The import and preprocessing stage (`code/data_processing/Main.m`) is a thin
driver over the [BeMoBIL pipeline](https://github.com/BeMoBIL/bemobil-pipeline);
all of its parameters live in `code/data_processing/BeMoBIL_Configuration.m`,
which is the single source of truth for folder names, file names, channel
cleaning, AMICA, dipfit and ICLabel settings.

BeMoBIL is **not vendored into this repository**. In the original working tree
it was a git submodule; here it is an ordinary external dependency, so clone it
yourself and put it on the MATLAB path:

```
git clone https://github.com/BeMoBIL/bemobil-pipeline
```

Then either add it to the path before running anything, or set `cfg.bemobil` in
`config/ansymb_config.m`.

You only need BeMoBIL to re-run the pipeline from the raw recordings. Every
analysis that starts from the shipped derived tables runs without it.
