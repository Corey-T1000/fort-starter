---
name: calendar
description: |
  Google Calendar integration. Use when the user says "check my calendar",
  "what's on my schedule", "am I free", "create a meeting", "block time",
  or any calendar/scheduling request.
user_invocable: true
---

# Calendar

Interface to Google Calendar via MCP sub-agent. The Google Calendar MCP server is NOT loaded in the main session — it lives only in dispatched sub-agents to avoid context bloat (~12 tools).

## When to Use

- "Check my calendar" / "what's on my schedule today"
- "Am I free at 3pm?" / "when am I free this week"
- "Block off time for [thing]"
- "Create a meeting with [person] at [time]"
- "Move my 2pm to 3pm" / "cancel the standup"
- "What do I have tomorrow / this week / next Monday"

## Architecture

**Sub-agent only.** The `/calendar` skill classifies intent, then dispatches a sub-agent with Google Calendar MCP tools. The main session never loads Calendar MCP tools.

The sub-agent has:
- Full Google Calendar MCP tools (`mcp__google-calendar__*`)
- Read-only access to Fort files (for context)
- No Write/Edit to Fort codebase

## Intent Classification

### Free-flowing (sub-agent acts autonomously)

- **List events**: `list-events` — show today's schedule or a date range
- **Check availability**: `get-freebusy` — find open slots in a time range
- **Search events**: `search-events` — find events by keyword
- **List calendars**: `list-calendars` — show available calendars
- **Get current time**: `get-current-time` — timezone-aware current time
- **View single event**: `get-event` by ID

### Confirm before submitting (sub-agent drafts, presents for approval)

- **Create event**: Draft with title, time, duration, attendees, calendar — show preview, wait for confirmation
- **Update event**: Show current details, present proposed changes, confirm
- **Respond to event**: Show invitation details, confirm accept/decline

### Guarded (sub-agent must get explicit go-ahead)

- **Delete event**: Show event title + time, require "yes"
- **Bulk operations**: Always surface full list, require explicit confirmation

## Sub-Agent Dispatch

When invoked, dispatch using the Agent tool:

```
subagent_type: general-purpose
description: Google Calendar [action] query
prompt: |
  You have access to the Google Calendar MCP server (tools prefixed mcp__google-calendar__).

  Task: [classified intent + user's request]

  Guidelines:
  - For read operations: return concise formatted results
  - For write operations: draft the change, present it clearly, then execute if confirmed
  - Format events as:
    HH:MM - HH:MM  Event Title
      Calendar: Name | Location: Place (if set)
  - Group by day when showing multi-day ranges
  - For free/busy queries, show open slots clearly:
    FREE: 10:00 - 12:00 (2 hours)
  - Use the user's local timezone (get-current-time if unsure)
  - If a request is ambiguous, ask for clarification

  Guardrail level: [free / confirm / guarded — based on classification above]
```

## Output

The sub-agent returns results to the main session. The assistant surfaces them directly — no reformatting needed if the sub-agent followed the format guidelines.

For daily schedules, use a clean timeline:

```
09:00 - 09:30  Team standup
10:00 - 11:00  Design review
12:00 - 13:00  Lunch (blocked)
14:00 - 15:00  1:1 with Manager
```

## Troubleshooting

- **Auth issues**: Run `GOOGLE_OAUTH_CREDENTIALS="$GOOGLE_OAUTH_CREDENTIALS" npx @cocal/google-calendar-mcp auth` to re-authenticate
- **Token expired**: Tokens expire weekly in GCP test mode — publish consent screen to production to fix
- **MCP not connecting**: Verify `google-calendar` exists in `.mcp.json` and env var is set
- **Tools not found**: Check that the server isn't in `disabledMcpjsonServers` in `settings.local.json`
