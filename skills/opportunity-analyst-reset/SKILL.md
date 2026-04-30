---
name: opportunity-analyst-reset
description: "Strip the 'Opportunity Analyst Skill detected Opportunities and Insights' section from every transcript in a folder, so the opportunity-analyst skill can be re-run cleanly. Sibling skill to opportunity-analyst."
argument-hint: "<path-to-transcripts-folder>"
allowed-tools: Read, Glob, Edit, Bash
---

# Opportunity Analyst Reset

Removes the appended detected-opportunities section from every transcript in a folder, so you can re-run the `opportunity-analyst` skill cleanly - for example after a rubric change, or after running an older buggy version of the analyst.

This is a **sibling skill** to `opportunity-analyst`. It only strips the section that the analyst appended; it never touches the original transcript content above it. If a transcript has no such section, the file is left untouched.

## Usage

```
/opportunity-analyst-reset <path-to-transcripts-folder>
```

Typically the folder is the `icp-screened-TEMP-[YYYY-MM-DD]` folder produced by the `icp-screener` skill - which is also the folder `opportunity-analyst` operates on.

## What gets removed

The analyst appends a section with this exact shape to the bottom of each transcript:

```
---

## Opportunity Analyst Skill detected Opportunities and Insights

_Extracted on [date]. Product metric used for Filter 2: [metric]._

### Opportunities
... (bullets) ...

### Non-priority opportunities (goal-misaligned)
...

### Solved / addressed (not counted)
...

### Insights
...
```

This skill removes everything from the `---` separator (or the `##` heading if no separator is present) through the end of the file.

## Workflow

1. **Validate the folder.**
   - Confirm the folder exists. If not, stop and ask.
   - **Folder-name guard:** if the folder name does NOT match the pattern `icp-screened-TEMP-*`, do not proceed silently. List a few sample filenames inside, state that the folder name doesn't match the expected pattern, and require an explicit "yes, proceed" from the user before continuing. This guards against accidentally pointing at raw transcripts or some other unintended folder.
2. **Find transcripts.** Use Glob to find all `.md` files in the folder. Exclude `screening-overview.md` and any other non-transcript files.
3. **Dry-run scan (always first).** For each file:
   - Read the file.
   - Find the first line matching `## Opportunity Analyst Skill detected Opportunities and Insights` (exact heading text).
   - Look back at the 1-2 lines immediately above the heading. If a `---` separator is there (allowing one blank line between), the deletion starts at the `---`. Otherwise the deletion starts at the heading itself.
   - Deletion ends at the end of file.
   - Record: filename, start line, end line.
   - If the heading is not found, record the file as "skipped (no section found)".
4. **Show the dry-run report and ask for confirmation.** Format:

   ```
   Dry run on <folder>:
   - <N> files would be modified
   - <M> files would be skipped (no detected section found)

   Files to modify (filename - lines removed):
   - file-1.md - lines 142-198
   - file-2.md - lines 87-134
   ...

   Proceed with deletion? (yes/no)
   ```

5. **Wait for explicit confirmation.** Per the user's change-safety rules, do not proceed without a clear yes.
6. **Strip the section.** For each file with a match, use Edit to remove the identified content (replace the matched block with an empty string). Process files sequentially - this is fast enough that fan-out adds no value.
7. **Report.** Final summary:

   ```
   Done. <N> files modified, <M> files skipped.
   You can now re-run /opportunity-analyst <folder>.
   ```

## Safety

- **Dry-run first, always.** Never edit before showing the user what would be removed and getting confirmation. The dry-run is the primary safety mechanism for this skill.
- **No silent skips.** Every file in the folder must be accounted for in the report - either as "modified" or "skipped" with the reason.
- **Folder-name guard.** Require explicit override if the folder name doesn't match the expected `icp-screened-TEMP-*` pattern.
- **Idempotent.** Running the skill twice in a row on the same folder is safe: the second run finds nothing to remove and skips every file.
- **Conservative match.** Only match the exact heading text. Do not match approximate or older variants without asking the user first - if the heading text has changed across versions, surface that to the user rather than silently catching the variant.

## What this skill does NOT do

- **No snapshot.** The dry-run and folder-name guard are the safety mechanisms. If you want a backup, take one before invoking. (See the design discussion: snapshots accumulate as untouched folders unless someone cleans them up, and the upstream `icp-screener` output is itself a copy, so re-screening recovers the originals if needed.)
- **No modification above the detected section.** Original transcript content is never touched.
- **Does not chain into the analyst.** This skill resets only. Run `/opportunity-analyst <folder>` afterward when you're ready.

## Sibling relationship

`opportunity-analyst` and `opportunity-analyst-reset` are designed to be used together:

- `opportunity-analyst` appends.
- `opportunity-analyst-reset` removes the appended section so the analyst can be re-run cleanly.

Keep both skills' output formats in sync: if the analyst's appended section heading text changes, update the matching heading in this skill at the same time.
