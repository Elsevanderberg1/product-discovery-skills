# Customer Opportunity Analyst

A [Claude Code](https://claude.com/claude-code) skill that extracts and prioritizes customer opportunities from ICP-screened interview transcripts. It applies filters, scores each opportunity by importance and prevalence, and outputs a ranked markdown report.

## What it does

Given a folder of interview transcripts from ICP-matching interviewees, the skill:

1. Reads each transcript in full
2. Extracts candidate opportunities (pain points, friction, wishes, desires) framed from the customer's perspective
3. Filters out pain points the interviewee has already solved
4. Flags opportunities that don't plausibly drive the primary product metric as non-priority
5. Scores each opportunity on **importance** (1-4) and **prevalence** (fraction of interviewees)
6. Writes a ranked markdown report alongside the transcripts

## Prerequisites

Before running, the skill needs:

- **ICP (Ideal Customer Profile)** - for context on who is being analyzed
- **Primary product metric** - the single metric opportunities should plausibly drive
- **ICP-screened transcripts** - only transcripts from interviewees who match the ICP

If any of these are missing, the skill will ask before proceeding.

## Installation

Clone this repo into your Claude Code skills folder:

```bash
cd ~/.claude/skills
git clone https://github.com/Elsevanderberg1/customer-opportunity-analyst.git
```

After cloning you should have `~/.claude/skills/opportunity-analyst/SKILL.md` on disk. Claude Code will pick it up automatically on the next session.

## Usage

```
/opportunity-analyst <path-to-transcripts-folder>
```

The ranked report is written to the same folder as the transcripts.

## Scoring

`Score = (importance x 2) + (prevalence x 1)`

- **Importance** (1-4): how big, recurring, or urgent the problem is for customers who experience it
- **Prevalence** (0-1): fraction of ICP interviewees who mention the opportunity or a closely related one

Opportunities are ranked by combined score, highest first.

## License

MIT
