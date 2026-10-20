---
name: pulse
description: |
  Lightweight status check the assistant runs at natural breaks.
  Checks Fort Mail, active workers, and pending reminders.
  Use when the user says "pulse", "quick check", "anything happening?", or called by the assistant at natural breaks.
user_invocable: true
context: fork
agent: general-purpose
model: sonnet
---

# Pulse

Fast, lightweight status check. Designed to run at natural conversation breaks without disrupting flow. Returns a compact one-liner summary — not a dashboard.

## When to Run

- **Assistant calls it** at natural breaks (topic change, after a task completes, when conversation goes quiet)
- **the user says** "pulse", "quick check", "anything happening?"
- **NOT** during active work — don't interrupt focused coding or discussion

## Checks

Run all in parallel:

### Fort Mail
```bash
curl -s -H "Authorization: Bearer $(cat ~/.fort-env 2>/dev/null | grep FORT_MAIL_API_KEY | cut -d= -f2)" "http://${FORT_REMOTE_IP:-127.0.0.1}:8080/api/agents/$(grep -o '"claudes-fort-[^"]*"' "${FORT_ROOT:-$HOME/claudes-fort}/mail/agents.json" 2>/dev/null | head -1 | tr -d '"' || echo "claudes-fort")/inbox" 2>/dev/null
```
Report: count of unread messages since last check. Skip if zero.

### Active Workers
```bash
git worktree list 2>/dev/null | grep -v "bare\|main"
```
Report: count of active worktrees. Skip if none.

### Reminders
```bash
cat scratch/reminders-$(date +%Y-%m-%d).md 2>/dev/null
```
Report: count of unchecked reminders for today. Skip if none.

## Output Format

Compact, one line per finding. Skip anything with nothing to report:

> **Pulse**: 2 new mail | 1 worker active (`auth-feature`) | 3 reminders pending

If everything is clear:

> **Pulse**: All clear.

## What Pulse Does NOT Do

- **Not a dashboard** — use `fort-status` for that
- **Not a briefing** — use `/briefing` for comprehensive status
- **No actions** — pulse only reports. It doesn't offer to fix things, open mail, or clear reminders. The assistant handles follow-up if the user reacts to a pulse finding.
- **No context window bloat** — don't read full mail messages. Counts only.

## Background Mode

The assistant can wire pulse as a periodic background check:

```
/loop 10m /pulse
```

**Background behavior differs from interactive:**
- Only surface findings when something **changed** since the last check (new mail, new reminder)
- If everything is still "all clear", stay **silent** — don't output "All clear" every 10 minutes
- Recommended: start during `/bod` when the session is expected to be long
- The loop is session-scoped — dies when the session ends, no cleanup needed

This makes the "assistant calls pulse at natural breaks" promise concrete rather than aspirational.
