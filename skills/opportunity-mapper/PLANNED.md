# opportunity-mapper

> Cluster opportunities across transcripts into a tree (Phases → Parent opportunities → Customer feedback). Sibling-merge logic, parent identification.

**Status: planned (target: week of 2026-05-04, v0.2 of this repo).**

This skill is part of the [Product Discovery Skills](../../README.md) pipeline. Its job will be to cluster opportunities extracted by `opportunity-analyst` across many transcripts into a tree, with phases as the first level.

When implemented, it will:

- Read `opportunity-analyst` output across all transcripts in the TEMP folder
- Cluster opportunities that are the same, with manual review of boundary cases
- Identify parent opportunities for related-but-distinct siblings
- Map opportunities into a tree where the first level is the Phases (from `phase-map-analyst`)
- Roll customer-feedback counts up the tree (each parent inherits children's counts)

## Where it will sit in the pipeline

- **Consumes:** the `icp-screened-TEMP-YYYY-MM-DD/` folder produced by `icp-screener` and processed by `phase-map-analyst` and `opportunity-analyst`. Each transcript should already have an appended detected-items section.
- **Produces:** a single markdown opportunity tree at `opportunity-tree-YYYY-MM-DD.md` in the TEMP folder.
- **Sibling skill:** [`opportunity-sizer`](../opportunity-sizer/) — currently does both clustering and scoring; v0.2 of this repo will split clustering into this `opportunity-mapper` and reduce `opportunity-sizer` to scoring only.

## Until then

For clustering plus scoring functionality today, use [`opportunity-sizer`](../opportunity-sizer/) — it handles both in a monolithic flow.
