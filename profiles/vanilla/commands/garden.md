---
name: garden
description: |
  Use when the user says "garden", "clean up", "hygiene", "prune", "tidy up",
  "things feel messy", or wants periodic codebase maintenance.
  Finds stale branches, orphaned scratch files, old worktrees, and stale memory files.
user_invocable: true
context: fork
agent: general-purpose
model: sonnet
argument-hint: "[scan|full]"
arguments:
  - name: mode
    description: "scan (report only, no cleanup) or full (interactive triage, default)"
    required: false
---

# Garden

Periodic codebase hygiene. Scans for cruft across multiple categories, presents findings, and offers to clean up with confirmation.

## When to Use

- End of week, alongside `/weekly-review`
- "Things feel messy", "time to clean up"
- Before starting a big new effort — clear the decks first
- When the user says "garden", "hygiene", "clean up"

## Workflow

**Model selection**: Scan mode runs on Haiku (default via frontmatter). For `full` mode, the dispatcher should override with `model: "opus"` since triage decisions need judgment.

**Scan-only mode**: If mode is `scan`, run Step 1 (Scan Everything) and Step 2 (Present the Report) only — skip Steps 3-5 (no triage, no cleanup, no confirmation prompts). Write findings to `scratch/garden-report.md` and optionally `fort-notify` a one-line summary. Designed for automated/scheduled use.

### Step 1: Scan Everything

Run these checks in parallel to build a hygiene report:

**Stale branches:**
```bash
# Local branches merged into main
git branch --merged main | grep -v "main\|master\|\*"

# Branches with no commits in 2+ weeks
git for-each-ref --sort=-committerdate --format='%(refname:short) %(committerdate:relative)' refs/heads/
```

**Orphaned scratch files:**
```bash
# Everything in scratch/ with modification times
ls -lt scratch/ 2>/dev/null

# Scratch subdirectories and their age
find scratch/ -maxdepth 2 -type d -not -name scratch | while read d; do
  echo "$(stat -f '%Sm' -t '%Y-%m-%d' "$d") $d"
done 2>/dev/null | sort
```

**Orphaned reminder files:**
```bash
# Reminder files older than today (should have been cleared by /eod)
find scratch/ -name "reminders-*.md" -not -name "reminders-$(date +%Y-%m-%d).md" 2>/dev/null
```
Flag any with unchecked items — these are reminders that were never surfaced.

**Orphaned assistant state:**
```bash
# Assistant state file that survived past EOD
ls scratch/assistant-state.md 2>/dev/null
```
If it exists, it means `/eod` didn't run or didn't clean up. Safe to delete.

**Stale worktrees:**
```bash
# List worktrees and their status
git worktree list
```

**Memory freshness:**
```bash
# Memory files sorted by modification date (oldest first)
ls -lt memory/*.md 2>/dev/null | tail -10
```

**Untracked file bloat:**
```bash
# Large untracked files or directories
git status --short | grep "^??" | head -20
```

**Instruction budget:**
```bash
# Total lines across always-loaded instruction surfaces
wc -l CLAUDE.md .claude/rules/*.md ~/.claude/projects/*/memory/MEMORY.md 2>/dev/null
```
Target ceiling: **350 lines** combined. Flag if exceeded.
Scan for: duplicate rules across files, rules a linter/hook should enforce, vague rules with no measurable effect, rules compensating for old model behavior that current models handle natively.
*With every model release, look at what you can remove.*

### Step 2: Present the Report

Group findings by category with clear severity:

```
## Garden Report

### Branches (X to prune)
- `feat/old-thing` — merged, last commit 3 weeks ago
- `fix/that-bug` — merged, last commit 1 month ago

### Scratch (X items, Y old)
- scratch/design-lab/old-experiment/ — last modified 2 weeks ago
- scratch/random-test.html — last modified 1 month ago

### Worktrees (X stale)
- worktrees/old-feature — branch merged, safe to remove

### Memory (X stale files)
- memory/68-trmnl.md — not updated in 6 weeks

### Untracked (X items)
- Large or forgotten untracked files

### Reminders (X orphaned)
- scratch/reminders-2026-02-28.md — 2 unchecked items, never surfaced

### Instruction Budget (X / 350 lines)
- X lines total (Y over/under ceiling)
- Duplicates: [any found across files]
- Model-version pruning: [rules that current models handle natively]
```

Skip categories with nothing to report.

### Step 3: Triage

Use **AskUserQuestion** for each category that has findings:

- Header: "Garden"
- Question: "X stale branches found. Clean up?"
- Options:
  - **Clean all** — "Delete all merged/stale branches"
  - **Pick individually** — "I'll choose which to keep"
  - **Skip** — "Leave branches alone"

For destructive actions (deleting branches, removing worktrees), always confirm before acting. Never auto-delete.

### Step 4: Execute Cleanup

Based on the user's choices:

**Branches**: `git branch -d <branch>` (safe delete, only merged)
**Worktrees**: `git worktree remove <path>`
**Scratch**: Move old items to trash or delete (confirm first)
**Memory**: Flag for review, don't auto-modify

### Step 5: Summary

> **Garden done.** Pruned X branches, cleaned Y scratch items, flagged Z stale memory files.
> Next garden recommended: [1-2 weeks from now]

## What Garden Does NOT Do

- **Auto-delete anything** — always confirms
- **Touch committed code** — this is meta-hygiene, not refactoring
- **Modify memory files** — only flags stale ones for review
- **Run in the background** — this is interactive, needs the user's judgment

## Pairing with /weekly-review

Natural flow: `/weekly-review` first (what happened this week), then `/garden` (clean up after it). The weekly review might surface aging issues that garden can then help triage.

## Scheduled Use

Garden scan mode can be triggered on a schedule for proactive hygiene awareness:

```
/loop 7d /garden scan
```

The report in `scratch/garden-report.md` persists for the user to review interactively later. Pair with `/weekly-review` — the weekly review reads the garden report if it exists to surface hygiene trends alongside shipping metrics.
