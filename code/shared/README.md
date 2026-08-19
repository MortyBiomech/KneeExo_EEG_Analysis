# Shared helpers

Small functions used by more than one analysis. They lived inside the ERSP
folder before, which meant every other script that used them depended on that
folder being on the path.

| File | What it is |
| --- | --- |
| `vline.m`, `hline.m` | Vertical/horizontal reference lines. Brandon Kuczenski, MATLAB File Exchange (BSD, see `license.txt`). |
| `savethisfig.m` | Original figure-saving helper, kept unchanged because several manuscript scripts call it. New code should use `ersp_analysis/plotting/save_figure.m`, which does the same thing without changing the working directory. |
| `calldefinedcolormap.m`, `calldefinedcolormap2.m` | Compatibility shims delegating to `ersp_analysis/plotting/ersp_colormap.m`. |
| `oneSubPerCluster.m` | Compatibility shim delegating to `ersp_analysis/study/one_ic_per_subject.m`. |

The shims exist so that the manuscript figure scripts keep working unchanged
after the ERSP code was reorganised. They are one-line forwarders; nothing
calls the old implementations any more.
