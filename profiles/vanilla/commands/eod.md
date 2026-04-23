---
name: eod
description: |
  Use when the user says "end of day", "wrap up", "done for the day", "EOD", "closing out",
  "call it a day", or is finishing a work session. Reviews the day's work, writes a daily log,
  surfaces tomorrow's focus, then runs /distill for memory capture.
user_invocable: true
requires: optional — fort-mail server (not bundled in starter); skill degrades gracefully if absent
---

# End of Day

Comprehensive day wrap-up that reviews what shipped, captures the daily log, and sets up tomorrow. Runs `/distill` at the end for memory capture.

> Note: this skill optionally checks a `fort-mail` HTTP service for queued cross-session messages. The fort-mail server is not bundled with fort-starter — if you don't have one running, the mail-check step is silently skipped and the rest of the workflow proceeds normally.

## When to Use

- End of a working day
- the user says "wrap up", "done for the day", "EOD"
- Before a long break from the Fort

## Workflow

### Step 0: Surface Reminders

Check for pending reminders before anything else:

```bash
cat scratch/reminders-$(date +%Y-%m-%d).md 2>/dev/null
```

If there are unchecked reminders, present them:

> **Pending reminders:**
> - [reminder 1]
> - [reminder 2]

Use **AskUserQuestion**:
- Header: "Reminders"
- Question: "Handle these before wrapping up?"
- Options:
  - **Done** — "Mark all as complete"
  - **Snooze** — "Push uncompleted ones to tomorrow"
  - **Review** — "Go through them one by one"

After handling, clean up: mark items as `[x]` in the file. If all items are done, the file stays as a record.

### Step 1: Gather Today's Activity

Run these commands to build a picture of the day:

Run these in parallel:

```bash
git log --since="today 00:00" --oneline --all --no-merges
```
```bash
git diff --stat HEAD~5
```

Also note any deploys or infrastructure changes made today.

### Step 1.5: Linear Reconciliation

Dispatch a sub-agent to check the user's Linear issues against today's activity:

1. Get all In Progress issues assigned to the user
2. Compare against today's git commits and conversation — did any of these get shipped?
3. Check for untracked work (commits/deploys that don't match any Linear issue)

Present a reconciliation summary:

> **Linear sync:**
> - WEB-10 (Blog redesign) — 3 commits today, still in progress
> - DES-68 (YT Thumbnail) — delivered in Slack, not updated → **move to Done?**
> - Untracked: deployed devlog changes (no issue) → **create retroactive?**

Use **AskUserQuestion** with multiSelect to let the user batch-confirm:
- Which issues to move to Done
- Which untracked work to skip (don't force tracking on everything)

If Linear MCP is unavailable or there's nothing to reconcile, skip silently.

### Step 1.7: Deploy Health Reconciliation

Check if any deploy changes shipped today:

```bash
git log --since="today 00:00" --all --diff-filter=M -- "deploy/" --oneline
```

If no deploy commits today — skip silently.

If deploys happened, extract the service names from the changed paths (e.g., `deploy/fort-watchdog/` → `fort-watchdog`) and check each:

```bash
# Container status
ssh ${FORT_REMOTE_HOST} "docker ps --filter name=<service> --format '{{.Names}}: {{.Status}}'"

# Health endpoint (derive port from known service mappings)
ssh ${FORT_REMOTE_HOST} "curl -sf http://localhost:<port>/health && echo OK || echo UNREACHABLE"
```

Report inline (no AskUserQuestion — just surface the status):

> **Deploy health:**
> - fort-watchdog: healthy (Up 4 hours)
> - fort-stats: UNREACHABLE — container running but health endpoint down

If any service is unhealthy or unreachable, flag it with `fort-notify "<service> unhealthy at EOD" --priority default` and note it in the daily log blockers section.

Carry the deploy status forward into Step 2's daily log template as a `## Deploys` section.

### Step 2: Write the Daily Log

Create or update `logs/YYYY-MM-DD.md` with today's date.

Format:

```markdown
# YYYY-MM-DD

## Shipped
- [What got done — commits, features, fixes, deploys]

## In Progress
- [What's still open — uncommitted work, open branches, parked items]

## Decisions
- [Any architectural or design decisions made today]

## Blockers
- [Anything stuck or waiting on external input]

## Deploys
- [Service name: healthy / unhealthy / unreachable — from Step 1.7]
- [Skip this section if no deploys today]

## Linear
- [Issues updated today — status changes, new issues created, issues closed]
- [Skip this section if no Linear activity]

## Tomorrow
- [Top priorities for next session based on open work and momentum]
```

Keep it concise — this is a reference log, not a journal. Bullet points, not paragraphs. Skip sections that have nothing to report (except Shipped — always include that, even if it's just "config tweaks").

### Step 2.5: Enrich Daily Note

Update today's daily note in the knowledge base with Fort activity:

```bash
DAILY_NOTE="${FORT_KNOWLEDGE_BASE}/41 Daily Notes/$(date +%Y-%m-%d).md"
```

If the file doesn't exist, create it (same template as `/bod` Step 2.5).

**Enrich these sections:**

1. **Fort Activity** — Replace the placeholder with a bullet list of what we worked on today:
   - Use the git log data from Step 1
   - Focus on outcomes, not process: "Built bidirectional daily notes integration" not "edited 4 skill files"
   - Keep to 3-6 bullets

2. **Accomplishments** — Append any shipped items that aren't already listed (the user may have added some manually)

3. **Tomorrow's Focus** — Append Fort-suggested focus items from Step 4 alongside any the user already wrote

**Important:** Preserve anything the user wrote in these sections — append, don't overwrite. Read the file first, check for existing content, and merge.

### Step 3: Generate Devlog Entry

Run `/devlog` to generate today's devlog entry from the session data gathered in Step 1. This captures the day's work as a blog-style entry in the knowledge base and `notes/devlog/`.

### Step 4: Tomorrow's Focus

Surface the top priorities for the next session:

1. Pull from open branches, parked items, and momentum from today's work
2. Include any in-progress threads that should continue
3. Present as a brief "tomorrow's plate" summary

If there are more than 5 items, highlight the top 3 and note the rest exist.

### Step 5: Run /distill

Invoke `/distill` to capture any session learnings into Fort Memory. This handles:
- Extracting operational knowledge from the session
- Filing into JD-numbered memory topic files

### Step 6: Clean Up Session Files

```bash
# Remove assistant state file (session-scoped, not needed after EOD)
rm -f scratch/assistant-state.md
```

### Step 7: Summary

Close with a brief day summary:

> **Day wrapped.** 3 commits, daily log written.
> Tomorrow's focus: [top 1-2 items]

## Relationship to /distill

`/eod` is the superset — it handles the full day wrap-up including the daily log, review, and tomorrow's planning. It calls `/distill` as one of its steps for memory capture. You don't need to run both separately.

If the user just wants memory capture without the full day review, `/distill` alone is fine. `/eod` is for when the day is actually done.
