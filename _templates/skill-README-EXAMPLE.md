# opportunity-analyst

> Extract customer opportunities and insights from each ICP-screened interview transcript. Appends a bulleted detected-items section to the bottom of every transcript file. Does not rank or prioritize - pair with opportunity-sizer for cross-transcript scoring.

Part of the [Product Discovery Skills](../../README.md) pipeline.

## What it does

For every interview transcript in a folder, extracts candidate opportunities (pain points, frictions, wishes, desires) and insights (anything else worth remembering). Each opportunity is tagged to a phase from the phase map produced upstream by `phase-map-analyst`, with a "Doesn't fit any phase" bucket for opportunities that don't belong to the journey as currently mapped. The output is appended to each transcript file in a clearly-labelled section, so it's easy to verify by hand.

The skill works one transcript at a time and does not rank, score, or compare across transcripts — that's `opportunity-sizer`'s job downstream.

## Install

From the repo root:

```bash
./install.sh opportunity-analyst
```

Or manually:

```bash
cp -r skills/opportunity-analyst ~/.claude/skills/
```

## Usage

```
/opportunity-analyst <path-to-transcripts-folder>
```

The folder is typically the `icp-screened-TEMP-YYYY-MM-DD/` produced by `icp-screener` and the `phase-map-*.md` artifact produced by `phase-map-analyst`.

## Inputs

- A folder of ICP-screened transcripts (each as a `.md` file)
- A `phase-map-*.md` artifact inside the same folder (controlled vocabulary for tagging)
- The product metric (asked interactively, used for the goal-alignment filter)

## Outputs

- An appended section at the bottom of each transcript file, labelled `## Opportunity Analyst Skill detected Opportunities and Insights`. Contains five sub-sections: Opportunities, Doesn't fit any phase, Non-priority opportunities (goal-misaligned), Solved/addressed, Insights.
- An aggregate count printed by the orchestrator (opportunities, misfits, insights) — workflow signal, not narrative.

## Where it sits in the pipeline

- **Consumes:** the TEMP folder produced by `icp-screener` plus the `phase-map-*.md` produced by `phase-map-analyst`.
- **Produces:** in-place updates to each transcript file (appended detected-items section).
- **Sibling skills:** `opportunity-analyst-reset` (strip prior output for a clean re-run), `phase-map-analyst` (upstream — defines the phase vocabulary), `opportunity-mapper` (downstream — clusters extracted opportunities across transcripts).

## Example

Before:

```
icp-screened-TEMP-2026-04-21/
├── screening-overview.md
├── phase-map-find-fitting-tech-job-2026-04-30.md
├── Jonas Weber - Senior Fullstack Engineer.md
├── Lena Fischer - Senior Software Engineer.md
└── Paul Becker - Senior Backend Engineer.md
```

After running `/opportunity-analyst`:

```
icp-screened-TEMP-2026-04-21/
├── screening-overview.md
├── phase-map-find-fitting-tech-job-2026-04-30.md
├── Jonas Weber - Senior Fullstack Engineer.md     # appended: detected-items section
├── Lena Fischer - Senior Software Engineer.md     # appended: detected-items section
└── Paul Becker - Senior Backend Engineer.md       # appended: detected-items section
```

The aggregate report looks like:

```
Opportunity-analyst run complete on 3 transcripts.

Aggregate counts:
- 21 opportunities (tagged to a phase)
- 5 misfits (didn't fit any phase) — 19% misfit rate
- 25 insights
```

## Design notes

- **One transcript at a time.** The skill fans out one subagent per transcript, all in parallel. No cross-transcript work happens at this stage — that's deferred to `opportunity-mapper`.
- **Phase names verbatim.** Subagents are forbidden from paraphrasing or inventing phases; if no phase fits, the opportunity goes in the "Doesn't fit any phase" bucket.
- **Misfits are evidence, not noise.** A high misfit rate is the trigger to re-run `phase-map-analyst` (which detects existing analyst output and offers to revise the map based on misfit clusters).
- **Filter 2 is the goal-alignment gate.** Each opportunity is asked: "would resolving this plausibly move the primary product metric?" Opportunities that don't pass are still captured, but in the "Non-priority" bucket — useful context for the team without polluting the prioritization.
- **Importance is inferred, not invented.** A 1-4 score is added only when the customer's words clearly signal it (intensity language, repetition, stated stakes). Absence is left as "not stated" rather than guessing a middle value.

## Source

The full skill instructions are in [`SKILL.md`](SKILL.md). The skill is invocable by Claude Code via the slash command `/opportunity-analyst`.
