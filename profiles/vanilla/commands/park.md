---
name: park
description: |
  Use when the user says "park this", "save this idea", "not now but later", "idea for later",
  "backlog this", "someday", or has an idea that shouldn't derail current work.
  Lighter than beads, more structured than scratch. Surfaced in /weekly-review.
user_invocable: true
arguments:
  - name: idea
    description: "The idea to park (can also be provided conversationally)"
    required: false
---

# Park

Quick-capture for ideas that are too small for a beads issue but too important to forget. A curated parking lot that feeds into `/weekly-review`.

## When to Use

- "Park this for later"
- "I had an idea but don't want to derail what we're doing"
- "Not now, but eventually..."
- Random inspiration mid-session that doesn't belong to current work
- Feature ideas, "what if" thoughts, things to try someday

## What Goes Here vs. Elsewhere

| Destination | When |
|-------------|------|
| **`/park`** | Idea, inspiration, "what if", something to try later. No urgency, no blockers. |
| **Beads** (`bd create`) | Concrete work item with clear scope. Has a definition of done. |
| **`/note`** | Knowledge or fact to remember. Not an idea to act on. |
| **`scratch/`** | Throwaway experiments. Won't be reviewed. |

## Storage

All parked ideas live in `notes/parking-lot.md`. One file, append-only, simple format.

## Workflow

### Step 1: Capture the Idea

If idea was provided as argument, use it directly. Otherwise ask: "What's the idea?"

### Step 2: Classify (Optional)

Quickly tag with a project area if obvious. Don't ask — just infer from context:

- `[frontend]`, `[api]`, `[infra]`, `[fort]`, etc.
- `[general]` if it doesn't map to a project
- `[meta]` for workflow/process ideas

### Step 3: Append

Add to `notes/parking-lot.md`:

```markdown
- [ ] **[tag]** Idea description — _YYYY-MM-DD_
```

If the file doesn't exist, create it with:

```markdown
# Parking Lot

Ideas to revisit. Surfaced weekly via `/weekly-review`.

- [ ] **[tag]** Idea description — _YYYY-MM-DD_
```

### Step 4: Confirm

> **Parked.** [one-line echo of the idea]

That's it. No follow-up questions, no routing decisions. Speed is the point.

## Lifecycle

Ideas leave the parking lot in three ways:

1. **Promoted** → Created as a beads issue when ready to act. Check the box and note `→ beads-XXX`
2. **Done** → Shipped without needing a beads issue. Check the box.
3. **Dropped** → No longer relevant. Check the box and note `dropped`

The parking lot is a living checklist — checked items are history, unchecked items are the active backlog.

## Integration with /weekly-review

`/weekly-review` should read `notes/parking-lot.md` and surface:
- How many ideas are parked (unchecked)
- Any ideas older than 2 weeks (aging — promote or drop?)
- Recently parked ideas worth discussing

This is the feedback loop that prevents the parking lot from becoming a graveyard.

## Browsing the Lot

If the user says "what's parked?" or "show me the parking lot":
1. Read `notes/parking-lot.md`
2. Show only unchecked items
3. Group by tag
4. Flag anything older than 2 weeks
