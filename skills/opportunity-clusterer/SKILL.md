---
name: opportunity-clusterer
description: "Cluster opportunities across ICP-screened transcripts into a deduplicated list, with each cluster carrying a customer-voice label, a phase, and a list of supporting interviewees with verbatim quotes. Hard-partitions by phase (Torres' moments-in-time rule). Writes one artifact in the TEMP folder, ready for opportunity-sizer downstream."
argument-hint: "<path-to-icp-screened-temp-folder>"
allowed-tools: Read, Write, Glob, Bash, Agent
---

# Opportunity Clusterer

You take the per-transcript opportunity lists produced by `opportunity-analyst` and cluster them across transcripts into a deduplicated, phase-partitioned list. Output is a flat, evidence-grounded list of overarching opportunities, each one supported by the specific interviewees and quotes it came from. Feeds `opportunity-sizer` (scoring) downstream.

You do **not** rank, score, or build a tree. Those are other skills' jobs.

## Usage

```
/opportunity-clusterer <path-to-icp-screened-temp-folder>
```

Typically the folder is the `icp-screened-TEMP-[YYYY-MM-DD]` produced by `icp-screener` and tagged by `opportunity-analyst`.

## Prerequisites

1. **Folder exists.** If not, stop and ask.
2. **Phase map present.** A `phase-map-*.md` file inside the folder, used as the hard partition. If absent, stop and tell the user to run `/phase-map-analyst` first.
3. **Analyst output present.** At least `min(3, total_transcripts)` transcripts must have a `## Opportunity Analyst Skill detected Opportunities and Insights` section.
4. **All analyst sections tagged against the current phase map.** Mixing phase-map versions silently corrupts clustering, so this is a hard abort.

If a prerequisite is missing, stop and tell the user what to run. Don't run upstream skills automatically.

## Workflow

### 1. Validate folder

Confirm it exists. If the folder name doesn't match `icp-screened-TEMP-*`, list sample filenames inside, flag the mismatch, and require explicit "yes, proceed" before continuing.

### 2. Load phase map

Glob `phase-map-*.md` in the folder. None → stop. Multiple → list and ask. Read the chosen map; extract phase names verbatim from `## Phases`. Record the absolute path.

### 3. Detect transcripts and validate analyst state

Glob all `.md` files (skip `screening-overview.md`, `phase-map-*.md`, any existing `clustered-opportunities-*.md`). For each, check whether it has a `## Opportunity Analyst Skill detected Opportunities and Insights` section, and whether that section's `Phase map used:` path matches the map from step 2.

Bucket transcripts:
- **Tagged-current** - section exists, phase map matches.
- **Tagged-stale** - section exists, phase map path differs.
- **Untagged** - no section.

Handle:
- **Stale → hard abort.** Report stale filenames; tell the user to run `/opportunity-analyst-reset` then `/opportunity-analyst` then re-run this skill.
- **Tagged-current < min(3, total) → halt.** Report counts; tell the user to run `/opportunity-analyst` on the untagged transcripts.
- **Some untagged but Tagged-current >= min → ask.** "Proceed with the {T} tagged transcripts only, or stop so you can run /opportunity-analyst first?" Excluded transcripts are recorded in the footer.
- **All Tagged-current → proceed silently.**

### 4. Detect existing artifact

Glob `clustered-opportunities-*.md` in the folder. If one exists, ask: overwrite, save with new date suffix, or abort? Never silently overwrite.

### 5. Collect the opportunity pool

For each Tagged-current transcript, parse its analyst section. For every opportunity under `### Opportunities` and `### Doesn't fit any phase`, capture:

- `interviewee` - transcript filename minus `.md`
- `statement` - the bolded line (label candidate only, not cluster signal)
- `phase` - verbatim phase tag, or `__no-phase__` for "Doesn't fit any phase" items
- `moment` - the moment-within-the-phase sentence
- `key_players` - if listed
- `importance` - 1-5 or "not stated"
- `quote` - the verbatim supporting quote

Skip `### Non-priority opportunities (goal-misaligned)` and `### Solved / addressed (not counted)`; count them per-transcript for the footer.

Surface the tally to the user before fan-out:

```
Pool collected:
- Phase 1 ({name}): {N} opportunities across {M} transcripts
- ...
- No phase ("Doesn't fit any phase"): {N} across {M}

Skipped from clustering: {N} non-priority, {M} solved

Proceed to clustering? (Phase-by-phase, fan-out parallel.)
```

### 6. Fan out: one subagent per phase

Spawn one `general-purpose` subagent per non-empty phase (including the `__no-phase__` bucket), all in a single message so they run concurrently. Giving each subagent only one phase's items eliminates the chance of cross-phase merge.

Skip phases with zero items. For a one-item phase, spawn the subagent anyway (produces a one-of-one cluster).

**Subagent prompt template** (must be fully self-contained - subagents don't see parent context):

```
You are clustering customer opportunities for one phase of a discovery study.

Phase: {VERBATIM PHASE NAME, or "Doesn't fit any phase" for the no-phase bucket}
Phase description: {one-line description from the phase-map artifact, or "items the analyst could not fit to any phase"}
Today's date: {YYYY-MM-DD}

Items to cluster ({N} total, from {M} interviewees):

{INLINE EACH ITEM AS A NUMBERED ENTRY:
[1]
  Interviewee: {name}
  Statement: {analyst's bolded line}
  Moment: {moment within the phase}
  Key players: {key players, or "not listed"}
  Importance: {1-5 or "not stated"}
  Quote: "{verbatim supporting quote}"

[2]
  ...
}

YOUR JOB: Group these items into clusters of underlying need. Then write one markdown section for the phase, formatted exactly per the OUTPUT FORMAT below.

{INLINE THE FOLLOWING SECTIONS FROM SKILL.md VERBATIM:
 - "Clustering Rules"
 - "Subagent Output Format"}

Return only the markdown section. No preamble. No commentary.
```

### 7. Stitch, validate, scan, and write

1. **Validate** each subagent's output: count distinct bold-row interviewee names per cluster. If any interviewee appears as a bold row more than once in a single cluster, the subagent violated "one row per interviewee per cluster." Re-prompt that phase's subagent with the correction, or fix manually (collapse to one row with nested sub-bullets if same need, split into separate clusters if not). Don't proceed until this passes.

2. **Assemble** the artifact body:
   1. Header (metadata)
   2. One `## Phase: {name}` section per phase, in phase-map order. Insert each subagent's markdown verbatim.
   3. The `__no-phase__` subagent's output goes under `## Non-phase-anchored opportunities`.

3. **Cross-phase recurrence scan.** Build a map of interviewee → list of `(phase, cluster label)` pairs from the assembled body. For each interviewee appearing in 2+ phases, evaluate each cross-phase pair against the test: **would a single solution address both moments?** If yes, it's a recurrence (flag it). If no, two distinct opportunities (Torres' moments-in-time rule). Emit one entry per qualifying pair into `## Cross-phase recurrences`, placed between `## Non-phase-anchored opportunities` and the footer.

   This scan does NOT merge clusters across phases - it surfaces persistent needs as a separate signal so the sizer can dedup prevalence for the same person's persistent need and the mapper (if used) can position recurrent siblings under a shared parent.

4. **Append the footer** (counts, including recurrence and skipped-bucket counts).

5. **Write** to `clustered-opportunities-{slug}-{YYYY-MM-DD}.md` in the folder. The `{slug}` matches the phase-map filename's slug.

### 8. Final report

```
Clustering complete. Artifact saved to: {path}

- {N} opportunities across {M} transcripts → {K} clusters
- Per phase: Phase 1 ({n1}→{k1}), Phase 2 ({n2}→{k2}), ...
- Non-phase-anchored: {n}→{k}
- Skipped from clustering: {non-priority}, {solved}
- Excluded (no analyst output): {U} transcripts (if any)
- Implied-only clusters flagged: {count}
- Cross-phase recurrences flagged: {count}

Next: review the artifact. When ready, run /opportunity-sizer {folder} to rank.
```

## Clustering Rules

These rules govern how a subagent decides what's the same vs distinct, and how to label a cluster. Derived from Teresa Torres' opportunity solution tree work (moments-in-time and sibling-distinctness rules).

### What to cluster on

**Cluster signal: `quote + moment + phase`.** Quote is ground truth (verbatim). Moment specifies when in the phase. Phase is fixed - you only see one phase's items, never compare across phases.

The `statement` field is the analyst's interpretation. Use it only as a label candidate, never as the cluster signal.

### Distinctness checks

For any candidate cluster, all of these must be true:

1. **Underlying need test.** Every member's quote, on its own, supports the same underlying need. If you have to stretch, the member doesn't belong.
2. **Sibling test.** Could the team work on member A's issue without addressing member B's? If yes, split.
3. **Smallest-tent label.** The cluster label must be a phrase every member could plausibly have said. If no single phrase fits all, the cluster is too broad - split.
4. **Phase wall.** Never invent cross-phase relationships. Same words + different phase = different opportunities by design.

### Generic-vs-specific collapse

If a cluster mixes a generic phrasing with specific instances that fully account for it, prefer the more specific framing as the label but keep the generic's evidence (quote + interviewee) in the cluster's member list.

### How to label

Cluster label = verbatim statement of the most representative member. Do not synthesize.

Pick the most representative member by:
1. Highest importance score (5 > 4 > ...). Ties go to:
2. The member whose statement best fits all other members' quotes (smallest-tent test).

If no single member's statement fits all others without stretching, the cluster is too broad - split it.

### Implied flag

A quote is **explicit** if it contains a direct expression of a wish/pain/desire ("I want," "I hate," "I'd pay for"). It's **implicit** if the need is inferred from situational context.

Set `Implied: yes` when **all** members are implicit; `Implied: no` otherwise. The flag tells reviewers to scrutinize all-implicit clusters carefully (higher overreach risk).

### Singletons

Single-member clusters are valid. Don't drop them, don't force-merge them.

### One row per interviewee per cluster

Each interviewee appears at most once per cluster. If two items from the same person both fit one cluster:
- **Same underlying need:** keep one row, nest all relevant quotes as sub-bullets. Preserve every quote - quotes are evidence.
- **Different underlying needs:** split into separate clusters.

When collapsing multiple quotes into one row, use the **max** of that person's importance values across the collapsed items.

Don't split into thin singletons just to satisfy this rule - collapse-into-sub-bullets first when same person + same need.

### Median importance per cluster

- Exclude `not stated` from the median. Report `Median importance: 4 (of 3 rated members; 1 not stated)`.
- Odd N: middle value. Even N: midpoint of two middle values.
- All "not stated": report `Median importance: not stated`.
- For multi-quote rows, use the row's max-importance value (already set when collapsing).

### Member ordering

Within a cluster, sort members by importance descending. "Not stated" sorts last. Ties: alphabetical by interviewee name.

## Subagent Output Format

Each subagent returns markdown for one phase, in this exact shape (no preamble, no commentary):

```markdown
### {Cluster label - verbatim statement of the most representative member}

Members: {N}. Importance range: {min-max, or "not stated"}. Median importance: {X} (of {R} rated members; {U} not stated). Implied: {yes | no}.

- **{Interviewee A}** (importance: {x}): "{verbatim quote}" - {moment within the phase}
- **{Interviewee B}** (importance: {max across their quotes}):
  - "{verbatim quote 1}" - {moment 1}
  - "{verbatim quote 2}" - {moment 2}
- ...

### {Next cluster label}

...
```

Row format rules:
- Single-quote rows use the inline form (Interviewee A above).
- Multi-quote rows nest each quote as a sub-bullet under the interviewee's bold row (Interviewee B above).
- One row per interviewee per cluster, always.
- `Members: {N}` counts rows (= unique interviewees), not quotes.

If the phase had zero items, return `_None._`.

## Final Artifact Format

The orchestrator stitches subagent outputs into one file:

```markdown
# Clustered Opportunities - {JTBD or folder slug}

_Generated on {YYYY-MM-DD}. Source folder: {absolute path}. Phase map: {path}._

_Pipeline: feeds opportunity-sizer._

## Phase: {Phase 1 name}

{Subagent output for Phase 1}

## Phase: {Phase 2 name}

{Subagent output for Phase 2}

...

## Non-phase-anchored opportunities

_Items the analyst tagged "Doesn't fit any phase". Clustered without phase partitioning._

{Subagent output for the no-phase bucket, or `_None._`}

## Cross-phase recurrences

_Same interviewee, semantically similar opportunities expressed across 2+ phases. Persistent needs flagged here for downstream consumers (sizer: dedup prevalence for the same interviewee's persistent need; mapper: consider as siblings under shared parent). NOT merged - different moments = different solution surfaces per Torres._

- **{Interviewee}**: Phase {N} ({phase name}) "{Cluster label A}" ↔ Phase {M} ({phase name}) "{Cluster label B}". {One-line rationale}.
- ...

_None detected._ {if no recurrences}

## Footer

- Transcripts processed: {N} - {filename list}
- Transcripts excluded (no analyst output): {U} - {filename list, omit line if zero}
- Total opportunities clustered: {N}
- Total clusters: {K}
- Implied-only clusters: {count}
- Cross-phase recurrences flagged: {count}
- Skipped (not clustered): {N} non-priority, {N} solved (preserved in source transcripts)
```

## Guardrails

- **Phase is a hard partition.** Never merge across phases, even post-hoc. Same-words-different-phase is two distinct opportunities by design.
- **Quote is ground truth.** Never paraphrase a customer quote. Verbatim only. Truncate only with `[...]` for overlong quotes - never silently shorten.
- **Cluster labels are not synthesized.** Always a verbatim member statement.
- **One row per interviewee per cluster.** Orchestrator validates before writing.
- **Singletons are valid.** Don't drop, don't force-merge.
- **Skipped buckets stay skipped.** Non-priority and solved items aren't clustered. Counts go in the footer; content stays in source transcripts.
- **Don't score, rank, build a tree, or modify transcripts.** This skill produces one artifact - the clustered opportunities list. Sizer scores. Mapper builds tree. Analyst output stays untouched.
- **Don't run upstream skills automatically.** If a prerequisite is missing, stop and tell the user what to run.
