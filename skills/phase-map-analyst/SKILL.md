---
name: phase-map-analyst
description: "Build a phase map for a Job-to-be-Done (JTBD) before opportunity extraction. Drafts top-down with the user, then validates against 3 deterministically sampled ICP-screened transcripts. Outputs a phase-map artifact inside the TEMP folder, ready for opportunity-analyst to use as a controlled vocabulary for tagging opportunities to phases."
argument-hint: "<path-to-icp-screened-temp-folder>"
allowed-tools: Read, Write, Edit, Glob, Bash
---

# Phase Map Analyst

You build a **phase map** for a Job-to-be-Done (JTBD) before opportunity extraction. The phase map is a stable, shared vocabulary of 3-8 phases that downstream skills (especially `opportunity-analyst`) use to tag every opportunity to a specific phase.

The flow is **deductive then inductive**:

1. **Top-down.** User sketches phases; you stress-test the draft against five risk checks and the Outcome-Driven Innovation (ODI) universal eight-step completeness checklist.
2. **Bottom-up.** You validate the candidate map against 3 deterministically sampled transcripts from the ICP-screened folder.
3. **Nuanced response.** You surface fit signal, misfits, vocabulary mismatches, and granularity flags. User revises and approves.
4. **Artifact.** Save the final phase map inside the TEMP folder.

You work **interactively** with the user. You do **not** extract opportunities — that is the job of `opportunity-analyst`, which is run separately after this skill produces its artifact.

## Usage

```
/phase-map-analyst <path-to-icp-screened-temp-folder>
```

The folder is typically the `icp-screened-TEMP-[YYYY-MM-DD]` produced by the `icp-screener` skill.

## Prerequisites

1. **An ICP-screened folder.** Contains transcripts plus a `screening-overview.md`. The screening overview is where this skill reads the Ideal Customer Profile (ICP) from.
2. **A JTBD.** Either provided by the user, inferable from folder context, or elicited interactively.
3. **The user is available to sketch and approve.** This skill is collaborative, not batch.

## Workflow

### 1. Validate the folder

- Confirm the folder exists. If not, stop and ask.
- **Folder-name guard:** if the folder name does NOT match `icp-screened-TEMP-*`, list a few sample filenames inside, state that the folder name does not match the expected pattern, and require an explicit "yes, proceed" before continuing.

### 2. Read the ICP

- Read `screening-overview.md` from the folder. Extract the ICP definition.
- Surface to the user in one or two sentences: "This map will cover {ICP}. Confirm or correct?"
- If `screening-overview.md` is missing or the ICP cannot be extracted, stop and ask the user to provide the ICP manually before proceeding.

### 3. Confirm the JTBD

- Propose a JTBD based on folder context (e.g. parent folder named `Talent` → "find a fitting job in tech"). Use customer-voice phrasing, not interviewer vocabulary.
- Ask the user to confirm or replace.
- The JTBD must be a single sentence describing the **core functional job** — not an emotional, social, or consumption-chain job.

### 4. Detect prior state and branch

Check for two artifacts that, if present, change the flow:

- **Existing phase map.** Use Glob to find any `phase-map-*.md` files inside the TEMP folder.
- **Existing opportunity-analyst output.** Use Bash (e.g. `grep -l "## Opportunity Analyst Skill detected Opportunities and Insights"`) to count how many transcripts in the TEMP folder contain the analyst's appended section.

Then branch based on what you find. Each branch sets a `mode` that step 5 uses to choose its starting point.

**Case 1: No phase map exists.** Set `mode = fresh`. Proceed to step 5.

**Case 2: Phase map exists, opportunity-analyst has not run yet (or only on a few transcripts).** Surface: "I see an existing phase map at {path}, and opportunity-analyst hasn't run yet. Use this map as your draft, or start fresh?" Set `mode = existing-as-draft` (use the loaded map as the candidate) or `mode = fresh` per the user's choice. Proceed to step 5.

**Case 3: Phase map exists AND opportunity-analyst has run on most transcripts.** This is the revise-from-evidence path. Read each transcript's analyst section. Aggregate:

- Per-phase opportunity counts (how many opportunities are tagged to each phase across all transcripts)
- Misfits (opportunities in the "Doesn't fit any phase" bucket), with verbatim quotes and source transcript filenames
- Misfit rate (misfits / total opportunities, across all transcripts)

Surface to the user:

> I see an existing phase map at {path}, and opportunity-analyst has run on {N} of {M} transcripts. Aggregate state:
>
> - Per-phase opportunity counts: {Phase 1: x, Phase 2: y, ...}
> - Misfits: {Y} opportunities did not fit any phase ({rate}% misfit rate)
> - Top misfit themes (quick clustering): {brief, e.g. "Salary negotiation (3 misfits across 2 transcripts), Onboarding (2 misfits)"}
>
> What would you like to do?
> (a) Revise the phase map based on the analyst's evidence (especially the misfit bucket)
> (b) Stress-test the existing map without revising
> (c) Start fresh (rare - only if the JTBD has changed)
> (d) Quit

If misfit count is 0 or 1 across all transcripts, do not offer (a); say "Misfit rate is low - revision unlikely to help" and offer only (b) and (d).

Set mode based on choice:

- (a) → `mode = revise-from-misfits`
- (b) → `mode = stress-test-only`
- (c) → `mode = fresh`
- (d) → exit cleanly without proceeding

Proceed to step 5.

### 5. Build a candidate phase map

The starting point depends on the `mode` set in step 4:

- **`fresh` mode (default for first-time runs):** User sketches first. Ask: "What 5-8 phases come to mind for this JTBD? Verb-led names work well — e.g. 'Define ideal role', 'Find vacancies', 'Prepare application'." If the user opts out ("you draft for me" or similar), the skill ideates a candidate using folder context, ICP, and JTBD. Surface it as a starting point, not the final answer.
- **`existing-as-draft` mode:** Use the loaded existing phase map as the candidate. No sketching needed.
- **`stress-test-only` mode:** Use the loaded existing phase map as the candidate. Run the risk tests below as a sanity check, but do **not** run step 5c (revision proposals).
- **`revise-from-misfits` mode:** Use the loaded existing phase map as the starting candidate. Run step 5c (revision proposals from analyst evidence) **before** the risk tests, so the risk tests run on the already-revised candidate.

Once you have a candidate map, **stress-test it** using the checks below. Surface findings as structural feedback; let the user decide whether to act.

#### 5a. Five risk tests

1. **Granularity.** Each phase should feel homogeneous. If a phase looks like it splinters into 3+ obvious sub-themes, flag: "Phase X may be too coarse — splinters into {sub-themes}. Split, or keep coarse?"
2. **Customer vocabulary.** Phase names should match how customers narrate. (Cannot fully check this until step 6 transcript validation, but flag obviously interviewer-flavored names early — e.g. "Negotiate compensation package" is corporate-speak; customers may say "salary chat".)
3. **Single population.** A phase map covers one customer journey. If the ICP plausibly contains two journeys (e.g. first-time job seekers vs. mid-career switchers), surface: "Your ICP may contain two journeys: {A} and {B}. Split into two maps, scope down, or proceed with one?"
4. **MECE.** Phases must be Mutually Exclusive (no two phases cover the same moment) AND Collectively Exhaustive (every moment in the job belongs to exactly one phase). If two phases overlap, flag: "Phases X and Y overlap on {moment}. Merge, or sharpen the boundary." If the map has a gap, flag: "{Moment Z} doesn't fit any phase. Add a phase, or expand an existing one's scope."
5. **Solution-agnostic.** Phases should describe what the customer is trying to _get done_ (a needs view), not what they are _doing_ with a specific tool, channel, or solution (a solution view). The map should describe the job independent of any current solution. Flag any phase name that bakes in a tool, channel, or specific artifact - e.g. "Update CV in Word" and "Browse LinkedIn jobs" are solution-flavored; "Prepare application" and "Find vacancies" are needs-flavored. Ask: "Phase X names {tool/channel/artifact}. Reframe to the underlying need?"

#### 5b. ODI job map mental model

The phase map is not the same as Ulwick's Job map, however the mental model of the Job map can help us identify blind spots, and move away from solution-based language.
Cross-check the candidate map against ODI's universal eight-step template — **as a mental model to help find the distinct phases, not as a rigid "must follow"**

1. **Define** — plan / define what needs to happen
2. **Locate** — gather / locate inputs needed
3. **Prepare** — organize / prepare inputs
4. **Confirm** — verify readiness
5. **Execute** — carry out the core task
6. **Monitor** — monitor execution
7. **Modify** — make adjustments
8. **Conclude** — finish and wrap up

For each step that's **absent** from the candidate map, ask: "Is {step} genuinely not part of this job, or is it an oversight?" Do not force-fit. Per Ulwick: jobs consist of "some or all" of these steps, not all eight.

#### 5c. Revise from analyst evidence (only in `revise-from-misfits` mode)

Skip this section unless the mode set in step 4 is `revise-from-misfits`. In all other modes, go straight to step 6.

When you reach this section, the existing phase map is loaded as the candidate, and the aggregated analyst evidence (per-phase counts, misfit list with quotes, misfit rate) was surfaced in step 4. Now propose specific map revisions:

1. **Cluster the misfit bucket.** Group the "Doesn't fit any phase" opportunities by theme - similarity of moment, context, or underlying need. Each cluster of 2+ misfits is a candidate for a new phase. Single-occurrence misfits are usually noise unless the user flags them as important.

2. **Spot density anomalies.** If a phase has unusually many opportunities relative to others (e.g. 3x the average across phases), it may need splitting into sub-phases. Surface this as a candidate revision.

3. **Spot vocabulary mismatches.** Re-read the analyst's "moment within the phase" fields per opportunity. If customers consistently describe a phase using different words than the phase name, propose a rename.

4. **Propose specific revisions.** Examples:
   - "Add a new phase: '{Theme}' between phases {X} and {Y}. Covers {N} misfits: {sample quotes}."
   - "Split phase {X} into {X-a} and {X-b}. Density of {n} opportunities suggests internal sub-themes: {brief}."
   - "Rename phase {X} to '{new name}'. Customer vocabulary suggests {new name} fits better."

5. **Ask the user to approve, edit, or reject each proposal.** The user can also propose their own revisions independent of the analyst evidence; accept those alongside the proposed ones.

6. **Update the candidate map** based on the user's decisions. Then proceed to step 5a (risk tests) and 5b (ODI mental model) on the revised candidate. The risk tests apply to the revised map, not the original.

Important: the existing phase map is the **starting point**, not a constraint. If the user wants to make sweeping changes, that's allowed - the skill should not anchor too hard on preserving the current map.

### 6. Bottom-up: validate against 3 transcripts

**Pick 3 transcripts deterministically:**

- Use Glob to list all `.md` files in the TEMP folder, excluding `screening-overview.md` and `phase-map-*.md`.
- Sort alphabetically by filename.
- Pick transcripts at zero-indexed positions `floor(n × 0.2)`, `floor(n × 0.5)`, `floor(n × 0.8)`. This gives a reproducible spread across the folder — re-runs in the same session pick the same 3.
- If `n < 3`, use all available and note the small sample.

**For each sampled transcript:**

Read fully. Then check:

- **Per-phase fit:** Which moments / opportunities map cleanly to which candidate phase?
- **Misfits:** Which moments don't fit any phase? Capture the verbatim quote and a short note.
- **Vocabulary check:** Does the customer's wording for each phase match the candidate phase name? Capture the customer's actual phrasing.
- **Phase coverage:** Are any phases entirely unrepresented in this transcript? (Could be sample bias, could be a phase that doesn't actually exist.)

### 7. Nuanced response

Present findings to the user in this shape:

```
Validation against 3 transcripts (sampled deterministically):
- {filename A} (position ~20%)
- {filename B} (position ~50%)
- {filename C} (position ~80%)

Per-phase fit signal:
- Phase 1 (Define ideal role): 3/3 transcripts had moments here
- Phase 2 (Find vacancies): 2/3
- Phase 3 (Prepare application): 3/3
- ...

Misfits ({N} moments did not fit any phase):
- "{quote}" ({transcript filename}) — possible new phase or sub-theme
- ...

Vocabulary mismatches:
- Phase X: candidate name "Negotiate conditions"; customers said "salary chat" / "comp talk"

Granularity flags:
- Phase Y splinters into: {sub-theme 1}, {sub-theme 2}, {sub-theme 3}

Caveats:
- Sample of 3 is small; sampled transcripts may not represent the full ICP.
- Misfit rate: {M%} (rule of thumb: > 30% suggests the map needs revision)
```

Ask the user: revise, approve, or stop here?

### 8. Loop or save

- **User revises:** re-run step 6 validation on the **same 3 transcripts** (cheap re-check; does not change the sample).
- **User approves:** save the final artifact (step 9).
- **Misfit rate stays > 30% after a revision attempt:** recommend stopping and re-interviewing rather than approving a forced map. A forced map silently corrupts downstream analysis.

### 9. Save the artifact

**Path:** inside the TEMP folder, named `phase-map-{slug}-{YYYY-MM-DD}.md` where `{slug}` is a short kebab-case derivative of the JTBD (e.g. "find a fitting job in tech" → `find-fitting-tech-job`).

**Format — use this exact structure.** `opportunity-analyst` will read this artifact and extract phase names from the `## Phases` section, so the structure must be stable across runs:

```markdown
# Phase Map: {JTBD}

_Created on {YYYY-MM-DD}. Validated against 3 sampled transcripts._

## Job-to-be-Done

{One-sentence JTBD in the customer's voice.}

## ICP slice

{One or two sentences. Reference: see {path-to-screening-overview.md} for the full ICP.}

## Phases

1. **{Phase name}** — {one-line description}
2. **{Phase name}** — {one-line description}
3. **{Phase name}** — {one-line description}
   ...

## Out of scope

- Emotional jobs not covered: {e.g. "managing rejection anxiety"}
- Consumption-chain jobs not covered: {e.g. "researching individual companies"}
- Sub-populations not covered: {e.g. "first-time job seekers"}

## Validation summary

Sampled transcripts (deterministic):

- {filename A} (position ~20%)
- {filename B} (position ~50%)
- {filename C} (position ~80%)

Per-phase fit signal:

- Phase 1: {X}/3
- Phase 2: {X}/3
- ...

Misfits at time of approval ({N}):

- "{quote}" — {note}

Caveats:

- Sample of 3 is small. The map is a working hypothesis; revise as more transcripts are tagged.
- {anything else specific to this run}
```

### 10. Final report

The message depends on the mode set in step 4.

**Modes `fresh`, `existing-as-draft`, or `stress-test-only` (analyst has not been run on these transcripts under this map yet):**

```
Phase map saved to: {path}
{N} phases. {M} misfits flagged at approval. 3 transcripts sampled.

You can now run /opportunity-analyst on the same folder. The analyst will use this map to tag the moment / job-step for each opportunity, with a "doesn't fit any phase" bucket for misfits.
```

**Mode `revise-from-misfits` (analyst has already run; the previous tagging is now stale):**

```
Phase map revised and saved to: {path}
{N} phases. {M} misfits flagged at approval. 3 transcripts sampled.

NEXT STEPS — the previous opportunity-analyst output is now stale (tagged to the old map):
1. Run /opportunity-analyst-reset <TEMP-folder> to strip the previous tagging
2. Run /opportunity-analyst <TEMP-folder> to re-tag against the revised map

Both commands require explicit confirmation per their own safety guardrails. Do NOT auto-chain — surface the next steps and let the user run them.
```

## Guardrails

- **Never silently use the ICP or JTBD.** Always read the screening-overview, surface to the user, get confirmation.
- **Never force-fit the eight ODI steps.** They are a checklist — surface absences, let the user decide whether each absence is intentional.
- **User sketches first by default.** Skill ideates only when the user explicitly opts out.
- **Three transcripts is a small sample.** Always include the small-sample caveat in the validation summary, and remind the user the map is a working hypothesis.
- **Do not run opportunity-analyst from this skill.** This skill writes the map. The analyst is a separate skill, run separately.
- **Do not modify transcripts.** This skill only writes the phase-map artifact. Transcripts are read-only here.
- **If the misfit rate stays high after a revision attempt, prefer pausing over approving.** A forced map silently corrupts downstream analysis.
- **Keep step names short and verb-led** (e.g. "Define ideal role", not "The phase where the candidate figures out what they want").

## Sibling relationship

`phase-map-analyst` and `opportunity-analyst` are designed to work together:

- `phase-map-analyst` produces a phase-map artifact (this skill).
- `opportunity-analyst` reads the artifact and constrains the `moment / job step` field per opportunity to the listed phases. Misfit opportunities go in a "doesn't fit any phase" bucket.

Run `phase-map-analyst` **first**, then `opportunity-analyst` on the same folder.

> **Note:** `opportunity-analyst` will need a small update to read this artifact and use it as a controlled vocabulary. That update is a separate change to `opportunity-analyst/SKILL.md` and its subagent prompt template.

## What this skill does NOT do

- **Does not extract opportunities.** That is `opportunity-analyst`'s job.
- **Does not modify transcripts.** Transcripts are read-only here.
- **Does not chain into `opportunity-analyst` or `opportunity-analyst-reset` automatically.** After a phase-map revision (in `revise-from-misfits` mode), the user must run reset and analyst as separate commands - per their own safety guardrails. The skill surfaces the next steps; it does not execute them.
- **Does not produce per-story story maps.** This is a single, study-level phase map for the JTBD, not a Torres-style per-transcript story map.
- **Does not score or prioritize phases.** Counting opportunities per phase to find the highest-friction phase is the job of `opportunity-sizer` (downstream).
