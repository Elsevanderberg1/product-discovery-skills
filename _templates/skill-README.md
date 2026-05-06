# {Skill name}

> {One-line description from SKILL.md frontmatter}

Part of the [Product Discovery Skills](../../README.md) pipeline.

## What it does

{2-4 sentences describing the skill's purpose and where it sits in the pipeline. Lead with the user-visible outcome, not the internal mechanics. Mention the upstream skill (what it consumes) and the downstream skill (what consumes it).}

## Install

From the repo root:

```bash
./install.sh {skill-name}
```

Or manually:

```bash
cp -r skills/{skill-name} ~/.claude/skills/
```

## Usage

```
/{skill-name} <{argument-hint from SKILL.md}>
```

## Inputs

- {Input 1 — e.g. "A folder of .md interview transcripts"}
- {Input 2 — e.g. "An ICP definition (asked interactively if not present)"}
- {Input 3 — e.g. "A product metric (asked interactively if not provided)"}

## Outputs

- {Output 1 — e.g. "A new `icp-screened-TEMP-YYYY-MM-DD/` subfolder containing matching transcripts"}
- {Output 2 — e.g. "A `screening-overview.md` summarizing match / no-match / uncertain decisions"}

## Where it sits in the pipeline

- **Consumes:** {what the previous skill produces, or "raw transcripts" for the first skill}
- **Produces:** {what's consumed by the next skill}
- **Sibling skills:** {related skills, e.g. "`opportunity-analyst-reset` (cleanup), `phase-map-analyst` (upstream)"}

## Example

{Brief worked example showing input → output. Reference an example folder under `../../examples/` if available. A 5-line `tree` snippet showing before/after is usually enough.}

## Design notes

- {Notable design decisions, e.g. "Reads only the profiling section of each transcript for a cheap pass"}
- {Constraints or non-goals, e.g. "Does not extract opportunities — that's `opportunity-analyst`'s job"}
- {Anything a contributor would benefit from knowing before changing the skill}

## Source

The full skill instructions are in [`SKILL.md`](SKILL.md). The skill is invocable by Claude Code via the slash command `/{skill-name}`.
