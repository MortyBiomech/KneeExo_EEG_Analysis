# external/

Unmodified third-party toolboxes, tracked as git submodules. A submodule
records a URL and one exact commit, so the repository states which version the
analysis was run against without copying the code in.

Contrast with `code/vendor/`, which holds files that **were** modified. A
modified file has no upstream to point at, so it has to travel with the
repository. An unmodified toolbox has a maintainer, a version history and a
licence of its own, and pointing at it is both smaller and more honest.

## What is here

| Folder | Upstream | Licence |
|---|---|---|
| `bemobil-pipeline/` | https://github.com/BeMoBIL/bemobil-pipeline | MIT |

## Getting it

A fresh clone leaves submodule folders empty. Either clone with them:

```bash
git clone --recurse-submodules <this repository>
```

or, in a clone you already have:

```bash
git submodule update --init
```

`config/add_code_paths.m` checks for the empty folder and prints that second
command, so nobody has to know this in advance.

## How the code finds it

`config/kneeexo_config.m` sets `cfg.bemobil`, in this order:

1. `local.bemobil` from `config/local_paths.m`, if you set it,
2. whatever is already on the MATLAB path, found through
   `bemobil_process_all_EEG_preprocessing.m`,
3. this folder.

So a colleague who already keeps BeMoBIL in their toolbox folder does not have
to check the submodule out at all. Setting `local.bemobil` is also how you test
the analysis against a different BeMoBIL version without touching the pinned
commit.

The path is added only by the two stages that need it,
`data_processing/run_preprocessing.m` and `study/run_group_clustering.m`,
through `add_code_paths(cfg, 'bemobil')`. It is deliberately not on the path
everywhere: BeMoBIL is a large tree, and a toolbox on the path in a stage that
never asked for it is a toolbox that can shadow a function in that stage.

## Which commit, and changing it

The commit this repository points at is the one the published analysis was run
with. `git submodule status` prints it. To move to a newer BeMoBIL:

```bash
cd external/bemobil-pipeline
git fetch && git checkout <new commit>
cd ../..
git add external/bemobil-pipeline && git commit
```

That is a change to the analysis, not to the housekeeping. If you do it, re-run
at least one participant through preprocessing and check that the result still
matches, then say in the commit message which BeMoBIL version the repository
now describes.

## Why not just copy it in

Copying would mean shipping thousands of lines identical to a public
repository, with no way for a reader to tell at a glance that they are
untouched, and no way to pick up an upstream fix without redoing the copy. It
would also put our one genuine modification,
`code/vendor/repeated_clustering_and_evaluation_custom.m`, next to a full copy
of the function it forks, which is exactly the situation the `vendor/` and
`external/` split exists to prevent.

## Reference

Klug, M., Jeung, S., Wunderlich, A., Gehrke, L., Protzak, J., Djebbara, Z.,
Argubi-Wollesen, A., Wollesen, B., & Gramann, K. (2022). The BeMoBIL Pipeline
for automated analyses of multimodal mobile brain and body imaging data.
*bioRxiv*. https://doi.org/10.1101/2022.09.29.510051