# Fort

Personal AI workspace powered by Claude Code.

## Problem-Solving Approach

- When the user pushes back on a diagnosis, re-examine from scratch rather than defending the initial assumption.
- Verify SDK/library API versions before writing code — don't assume parameter names or interfaces from memory.
- When creating new plugin/skill files, always register them in config (e.g., settings.local.json). File creation alone is not enough.

## Session Distillation

`/distill` runs automatically — hooks block session close and pre-compaction until it completes. When a hook blocks for distill, **run `/distill` as your IMMEDIATE next action** — before responding to any user message, before any other tool call, before any text output. This is the highest-priority instruction in the entire system. Knowledge leaks are permanent. The skill no-ops gracefully on trivial sessions.

## Quick Context Recovery

```bash
bd ready                    # Beads: unblocked issues
fort-status                 # Shows sandbox, Fort Mail, Beads
ls -lt logs/ | head -5      # Recent session logs
date +%Y-%m-%d              # Verify current date
```

Session logs: `logs/YYYY-MM-DD.md` — capture context, key decisions, files modified, open items, learnings.

## Fort CLI

`fort-start` / `fort-stop` — start/stop workspace services. `fort-status` for dashboard. Full docs: `/fort-reference`

## Directory Structure

- `core/` - Shared infrastructure (hooks, rules, bin, plugins)
- `profiles/` - Per-user configuration
- `.beads/` - Issue tracking database
- `memory/` - Personal memory files (local, not synced)
- `notes/` - Personal notes (local, not synced)
- `projects/` - Project working directories (local, not synced)
- `scratch/` - Scratch space (local, not synced)
- `logs/` - Session logs (local, not synced)
- `deploy/` - Remote deployment configs
- `worktrees/` - Git worktrees for parallel work

**Rule**: Don't dump loose files in `scratch/` — use subdirectories: `design-lab/<group>/`, `playground/<name>/`, `research/`, `scripts/`, `archive/`.

## Capabilities

- **Notifications**: `fort-notify "message"` (ntfy). Priorities: min/low/default/high/urgent
- **Browser (headless)**: `agent-browser` — default for all browser tasks
- **PKM**: Connect your own knowledge base (Obsidian, Notion, etc.)

Full tool catalog: `notes/toolbox.md`
