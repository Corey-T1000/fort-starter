# profiles/vanilla/

The fort-starter base profile. Public-safe, zero PII, no infra dependencies.

This is what `./fort-bootstrap --profile=vanilla` installs. Generic assistant identity, conservative permissions, the 20 slash commands that cover the daily-rhythm + capture loop. Anyone should be able to clone the repo, run the bootstrap, and end up with a working Claude Code workspace.

## What's inside

| Path | Contents |
|------|----------|
| `CLAUDE.md` | Generic CLAUDE overlay — points at `notes/about-me.md` for identity, names the daily distill ritual. Concatenated onto `core/CLAUDE.base.md` at install. |
| `settings.json` | Conservative permissions (read-only Bash allows, web search). All core hooks wired up. `__FORT_ROOT__` tokens are rewritten to absolute paths at install. |
| `commands/` | 20 slash commands. See `commands/README.md` for the inventory and grouping. |
| `plugins/` | Empty by design (`.gitkeep` only). User additions land here. See `plugins/README.md`. |
| `hooks-disabled/` | Empty by design (`.gitkeep` only). Vanilla runs all core safety hooks. |

## Setup

Repo root → `./fort-bootstrap --profile=vanilla`. Then `claude` to start your first session. Full installation steps and the broader template walkthrough live in the [project README](../../README.md).

## Customizing without forking core

Two extension points let you adapt vanilla in place:

- `plugins/` — drop a Claude Code plugin directory here; it installs additively alongside `core/plugins/`.
- `hooks-disabled/` — `touch hooks-disabled/<hook-name>.sh` to skip a core hook that doesn't fit your workflow.

Re-run `./fort-bootstrap --profile=vanilla` after either change.
