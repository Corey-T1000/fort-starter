---
name: reminders
description: |
  Use when the user says "remind me", "set a reminder", "what are my reminders",
  "clear reminders", "snooze that", or needs to manage session and persistent reminders.
  Integrates with fort-notify for phone push and scratch files for session persistence.
user_invocable: true
arguments:
  - name: action
    description: "create, list, clear, or snooze (default: create if content provided, list if bare)"
    required: false
  - name: content
    description: "Reminder text for create action"
    required: false
  - name: when
    description: "When to surface: eod, tomorrow, specific time description, or persistent (default: eod)"
    required: false
---

# Reminders

Structured reminder management for the assistant. Supports session reminders (surface at EOD), next-session reminders (survive across sessions), and phone push (immediate via ntfy).

## Storage

All reminders live in date-stamped files: `scratch/reminders-YYYY-MM-DD.md`

Format:
```markdown
# Reminders — YYYY-MM-DD

## Active
- [ ] Reminder text — _when: eod_ (set HH:MM)
- [ ] Another reminder — _when: tomorrow_ (set HH:MM)

## Done
- [x] Completed reminder — _surfaced and acknowledged_
```

## Actions

### Create

Trigger: "remind me to X", "don't forget Y", or `/reminders create`

1. Determine timing:
   - **eod** (default): Surface when the user says "wrap up" or before `/eod`
   - **tomorrow**: Write to tomorrow's date file (`reminders-YYYY-MM-DD.md` for tomorrow)
   - **persistent**: Push to phone via `fort-notify` AND write to file
   - **now**: Push to phone immediately via `fort-notify`, don't write to file

2. Write to the appropriate reminders file
3. Confirm: "Reminder set for [when]."

For persistent/now:
```bash
fort-notify "Reminder: [content]"
```

### List

Trigger: "what are my reminders?", "any reminders?", or `/reminders list`

1. Read all `scratch/reminders-*.md` files
2. Show only unchecked items, grouped by date
3. If no reminders: "No active reminders."

Format:
> **Reminders:**
> - [today] Check on the deploy — _eod_
> - [tomorrow] Follow up with X — _tomorrow_

### Clear

Trigger: "clear reminders", "done with reminders", or `/reminders clear`

Use **AskUserQuestion**:
- Header: "Clear"
- Question: "Which reminders to clear?"
- Options:
  - **All today's** — "Mark all of today's reminders as done"
  - **Pick individually** — "Choose which to clear"
  - **All files** — "Clear all reminder files (today + future)"

Mark cleared items as `[x]` rather than deleting — preserves history.

### Snooze

Trigger: "snooze that", "push that to tomorrow", or `/reminders snooze`

1. If context makes it clear which reminder: move it to tomorrow's file
2. If ambiguous: list active reminders and ask which to snooze
3. Remove from today's file, add to tomorrow's with `(snoozed from YYYY-MM-DD)` note

## Integration Points

### Assistant
The assistant checks reminders during activation (Step 2) and before `/eod`. The assistant calls `/reminders list` — it doesn't reimplement listing logic.

### EOD
`/eod` surfaces reminders as part of its closing flow. After surfacing:
1. Ask the user which are done vs. snooze to tomorrow
2. Update the file accordingly

### Garden
`/garden` catches orphaned reminder files (older than 3 days with unchecked items).

### Fort-Notify
For anything that must survive session end, push to phone. The reminder still gets written to file as a record, but the phone notification is the actual delivery mechanism.
