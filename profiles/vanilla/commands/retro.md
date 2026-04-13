---
name: retro
description: |
  Use when the user says "retro", "retrospective", "what did we learn", "post-mortem",
  "what went wrong", "debrief", or wants to reflect on a specific event.
  Deep zoom into one event — what happened, what surprised, what to change.
user_invocable: true
arguments:
  - name: subject
    description: "What to retro on — a feature, incident, bug, or decision (auto-detected from recent work if omitted)"
    required: false
---

# Retrospective

Focused reflection on a single event — a feature that shipped, a bug that bit, a decision that played out, or an incident that happened. Deeper than weekly review, narrower in scope.

## When to Use

- After shipping something significant
- After a painful debugging session
- After an incident or outage
- After a decision plays out (well or poorly)
- "Let's retro on that", "what did we learn from that"

## When NOT to Use

- For broad weekly reflection — use `/weekly-review`
- For quick gotcha capture — use `/capture` or the hookify prompt
- For routine work that went smoothly — not everything needs a retro

## Workflow

### Step 1: Identify the Subject

If subject was provided as argument, use it.

If invoked bare, look at recent work:
```bash
# Recent significant commits
git log --oneline -10

# Recently closed beads
bd list --status=closed
```

Ask the user: "What are we retro-ing on?" with recent items as options.

### Step 2: Gather Context

Based on the subject, collect relevant data:

**For a shipped feature:**
- Commits involved: `git log --oneline --all --grep="<keyword>"`
- Related beads issues
- Time span from first commit to ship
- Files touched: `git diff --stat <first-commit>..<last-commit>`

**For a bug/incident:**
- The symptoms — what went wrong
- The investigation path — what was tried
- The root cause — what actually broke
- The fix — what resolved it

**For a decision:**
- What was decided and when
- What alternatives were considered
- How it played out

### Step 3: Structured Reflection

Walk through these questions with the user. Don't just generate answers — have a brief conversation for each:

**1. What happened?**
Concise summary. 2-3 sentences max.

**2. What went well?**
What worked, what saved time, what was satisfying. Reinforce good patterns.

**3. What surprised us?**
Unexpected complexity, hidden dependencies, things that took longer than expected, lucky breaks.

**4. What would we change?**
If we did this again, what would we do differently? Be specific — not "plan better" but "check the API rate limits before designing the polling interval."

**5. What should we remember?**
Concrete takeaways that future sessions should know about. These become memory entries or hookify rules.

### Step 4: Capture Outputs

The retro produces three types of output:

**Memory entries** (operational knowledge for future sessions):
- Route to the appropriate `memory/XX-topic.md` using the JD index
- Format as dated entries with context
- Same as `/capture` but sourced from reflection rather than research

**Hookify candidates** (preventable gotchas):
- If a surprise or mistake could be caught by a hook, offer: "This could be a hookify rule. Worth it?"
- Only for genuine, repeatable gotchas — not one-offs
- If accepted, invoke `/hookify` with the specific pattern

**Beads issues** (follow-up work identified):
- If the retro surfaces work that should happen, offer to create beads issues
- "The retro surfaced 2 follow-up items. Create beads issues?"

### Step 5: Write the Retro

Save to `notes/retros/YYYY-MM-DD-subject.md`:

```markdown
# Retro: [Subject]
_YYYY-MM-DD_

## What Happened
[Summary]

## What Went Well
- [Good patterns to reinforce]

## Surprises
- [Unexpected things]

## Changes
- [What we'd do differently]

## Takeaways
- [Concrete learnings]
- Memory updated: [files]
- Hookify rules: [any created]
- Follow-up beads: [any created]
```

Create `notes/retros/` if it doesn't exist.

### Step 6: Summary

> **Retro complete** on [subject].
> [count] memory entries saved, [count] hookify rules created, [count] follow-up beads.
> Full retro: `notes/retros/YYYY-MM-DD-subject.md`

## Depth Calibration

Match the retro depth to the event size:

| Event | Depth | Time |
|-------|-------|------|
| Small bug fix | Quick — identify subject, capture outputs, write retro (skip context-gathering and reflection) | 2 min |
| Feature ship | Standard — all steps | 5-10 min |
| Incident/outage | Deep — thorough conversation at each reflection question | 15+ min |

Don't over-retro small things. A 30-second bug doesn't need a 10-minute reflection.
