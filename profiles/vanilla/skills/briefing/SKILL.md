---
name: briefing
description: |
  This skill should be used when the user asks to "catch me up", "what's the state of things",
  "briefing", "what have I missed", "morning standup", "daily brief", "where are we",
  "what's been happening", or wants a quick rollup of all Fort persistence layers.
user_invocable: true
arguments:
  - name: focus
    description: "What to focus on: work, knowledge, or all (default: all)"
    required: false
  - name: days
    description: "How many days back to look (default: 7)"
    required: false
---

# Briefing

On-demand rollup of all Fort persistence layers. Fast, inline — no background agent needed. Produces a structured ~20-line brief covering active work, recent activity, knowledge, and suggested next steps.

## How to Use This Skill

When this skill is triggered, gather data from these sources and compile a brief. **Do this inline** — do not spawn a background agent.

### Data Sources

Gather in parallel where possible:

1. **Fort Memory retro** (recent activity):
   ```bash
   fort-memory retro <days> 2>/dev/null
   ```
   If this fails or is slow, fall back to:
   ```bash
   fort-memory query "SELECT COUNT(*) as sessions FROM sessions WHERE date >= DATE_SUB(CURDATE(), INTERVAL <days> DAY);"
   ```

2. **Auto-memory** (current state):
   Read Claude Code's project-scoped `memory/MEMORY.md` (at `$HOME/.claude/projects/-Users-$(whoami)-$(basename $FORT_ROOT)/memory/MEMORY.md`)

3. **Research notes** (recent research):
   ```bash
   ls -lt notes/research/ 2>/dev/null | head -5
   ```
   Read the Summary section from the most recent 2-3 files.

4. **Knowledge base** (stored facts):
   ```bash
   fort-memory knowledge 2>/dev/null
   ```

### Graceful Degradation

If any data source is unavailable (command fails, directory doesn't exist, etc.), **skip that section silently** and continue. A partial brief is better than an error.

### Focus Modes

- **work**: Fort Memory activity only
- **knowledge**: Knowledge table + research notes only
- **all** (default): Everything

## Output Format

```markdown
## Fort Briefing — <date>
Period: last <N> days

### Active Work
- <in-progress items from recent commits and session logs>

### Recent Activity
- <session count, commit count, key decisions from Fort Memory>
- <notable patterns or velocity changes>

### Knowledge & Research
- <knowledge topics with fact counts>
- <recent research files with 1-line summaries>

### Suggested Next Steps
- <2-3 actionable suggestions based on the data>
  (e.g., "3 issues are unblocked and ready to work on")
  (e.g., "Research on X has open questions worth investigating")
  (e.g., "No activity in 5 days on project Y")
```

Keep the total output to ~20 lines. Be concise — this is a briefing, not a report.

## Examples

- `/briefing` → full brief, last 7 days
- `/briefing --focus work` → just active work and activity
- `/briefing --days 14` → two-week lookback
- "catch me up" → triggers this skill with defaults
- "morning standup" → triggers this skill with defaults
