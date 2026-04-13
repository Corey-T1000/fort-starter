---
name: bod
description: |
  Use when the user says "morning", "start of day", "BOD", "what's on my plate",
  "where was I", "what should I work on", or is starting a new work session.
  Shows recent state, open work, and helps set today's focus. Supports quick and full modes.
user_invocable: true
argument-hint: "[quick|full]"
arguments:
  - name: mode
    description: "quick (context dump + focus question) or full (guided walkthrough with triage)"
    required: false
---

# Beginning of Day

Context loading and intent setting for the start of a work session. Two modes: quick for a fast start, full for a thorough walkthrough.

## When to Use

- Start of a new day or work session
- the user says "what's on my plate", "where was I", "morning"
- Returning after time away from the Fort

## Workflow

### Step 1: Choose Mode

If mode was provided as argument, use it. Otherwise:

Use **AskUserQuestion**:
- Header: "Morning"
- Question: "How do you want to start today?"
- Options:
  - **Quick start (Recommended)** — "Context dump + 'what's your focus?' — 30 seconds"
  - **Full walkthrough** — "Review yesterday, triage open items, pick focus — guided flow"

---

## Quick Mode

### Step 2: Load Recent Context

Find and read the most recent daily log:

```bash
ls -t logs/*.md | head -1
```

Read it and extract:
- What shipped yesterday
- What was in progress
- Tomorrow's focus items (from yesterday's EOD)
- Any blockers noted

### Step 2.5: Daily Note

Create or read today's daily note in the knowledge base:

```bash
DAILY_NOTE="${FORT_KNOWLEDGE_BASE}/41 Daily Notes/$(date +%Y-%m-%d).md"
```

**If the file doesn't exist** — create it from the template:

```bash
mkdir -p "${FORT_KNOWLEDGE_BASE}/41 Daily Notes"
cat > "$DAILY_NOTE" << 'TEMPLATE'
---
tags: [daily-notes]
date: YYYY-MM-DD
type: daily-note
---

# YYYY-MM-DD

## Tasks
### Work
- [ ]

### Personal
- [ ]

## Notes
-

## Fort Activity
> *Auto-populated by the Fort throughout the day.*

## Accomplishments
-

## Tomorrow's Focus
- [ ]

## Links
- Related: [[]]
TEMPLATE
# Replace YYYY-MM-DD with actual date
sed -i '' "s/YYYY-MM-DD/$(date +%Y-%m-%d)/g" "$DAILY_NOTE"
```

**If the file already exists** — read it and surface anything the user jotted:

```bash
cat "$DAILY_NOTE"
```

If there are non-empty Notes, Tasks, or other human-written content, surface briefly:
> **Daily note**: You've got [N tasks / some notes] jotted already.

If the daily note is fresh/empty, skip silently.

### Step 2.6: Devlog Status

Check if last night's automated devlog generated:

```bash
ls -t notes/devlog/*.md | head -1
```

If the most recent devlog is from yesterday (or today), mention it briefly:
> "Last night's devlog generated — [1-line summary of what it covered]"

If no recent devlog exists, skip silently.

### Step 3: Current State

Run in parallel:

```bash
bd ready 2>/dev/null
```
```bash
bd list --status=in_progress 2>/dev/null
```
```bash
git log --since="yesterday" --oneline --all --no-merges
```

### Step 3.5: Memory Health Check

Quick silent check for memory system failures:

```bash
# Knowledge staleness — last memory knowledge entry
fort-memory knowledge 2>/dev/null | tail -1
```

If the latest memory knowledge entry is older than 3 days, surface a warning:
> 🔴 **Memory alert**: Memory knowledge hasn't been updated since [date]. `/distill` may not be running.

If healthy, skip silently.

### Step 3.6: Linear Status (if `/linear` is available)

Dispatch a sub-agent to pull the user's active Linear issues:
- In Progress issues across all teams
- Todo issues marked High priority
- Any issues tagged `ideate` (candidates for exploration)

Keep it brief — 5 issues max, grouped by team. This is a status glance, not a full board review.

**Resilience**: If the Linear sub-agent times out or MCP returns errors, surface briefly rather than skipping:
> 🟡 **Linear**: Status unavailable — MCP may need reconnection

Don't block the briefing on Linear failures — proceed to Step 4.

### Step 4: Present Summary

Concise summary format:

> **Yesterday**: [1-2 sentence recap]
>
> **Open work** (X ready, Y in progress):
> - [Top items by priority]
>
> **Linear**: [brief status from Step 3.5 if available]
>
> **Yesterday's "tomorrow" focus**: [what EOD said to focus on]

### Step 5: Set Focus

Ask: "What's your focus today?"

One question, free text. Based on the answer:
1. Load the relevant memory file (use the workflow-intelligence routing table, or `/switch` project registry for name→path mapping)
2. Set tab title with `tab-title "fort:focus-topic"`
3. If a beads issue matches, offer to mark it in_progress
4. Pull relevant knowledge from memory (see Step 5.5)

### Step 5.5: Memory Knowledge Recall

After focus is set, query memory for relevant facts:

```bash
fort-memory recall "<focus-topic>" 2>/dev/null
```

Map the focus to a memory topic using the JD slug (e.g., focus on "dashboard" → `fort-memory recall "home-dashboard"`). If the focus doesn't map cleanly, try a keyword search:

```bash
fort-memory recall "%<keyword>%" 2>/dev/null
```

If results come back, surface the top 3-5 most relevant facts as a compact block:

> **Memory recall** (N facts on topic):
> - [most relevant fact]
> - [second most relevant]
> - [third if useful]

If no results or the topic isn't in memory, skip silently. Don't mention the absence.

### Step 6: Focus Drift Detection (Background)

For longer sessions, consider starting a background ambient check:

```
/loop 2h /pulse
```

This fires `/pulse` every 2 hours to catch beads drift, new mail, and reminders without the user having to ask. The loop is session-scoped — dies on exit, no cleanup needed. Only start this when the session is expected to last 2+ hours.

---

## Full Mode

### Steps 2-4: Same as Quick Mode

Load context, gather state, present summary.

### Step 5: Triage Open Items

If 5 or fewer in_progress beads issues: triage individually with AskUserQuestion.
If more than 5: present all in a summary table and let the user batch-respond.

For individual triage, use **AskUserQuestion**:
- Header: "Triage"
- Question: "[Issue title] — what's the play?"
- Options:
  - **Continue** — "Keep working on this today"
  - **Defer** — "Park it, not today's priority"
  - **Close** — "Actually, this is done"
  - **Blocked** — "Waiting on something external"

### Step 6: Pick Focus

After triage, present the refined list:

> **Today's plate**:
> - Continuing: [items marked continue]
> - Ready to start: [unblocked beads by priority]

Ask: "Pick your top 1-3 for today" (or let the user free-text a focus).

### Step 7: Load and Set Up

For each focus item:
1. Load the matching memory file
2. Show relevant context (recent commits, related files)
3. Set tab title based on primary focus

> **Ready.** Memory loaded for [project]. [X beads issues] in your focus.

### Step 8: Focus Drift Detection (Background)

For longer sessions, consider starting a background ambient check:

```
/loop 2h /pulse
```

This fires `/pulse` every 2 hours to catch beads drift, new mail, and reminders without the user having to ask. The loop is session-scoped — dies on exit, no cleanup needed. Only start this when the session is expected to last 2+ hours.

---

## Context Recovery

If there's no recent daily log (first time using `/eod`, or after a gap):
- Fall back to `git log` and `bd list` for context
- Note: "No daily log found — you might want to start using `/eod` to close out days."
- Don't block on missing logs — provide what context is available
