# core/plugins/

Shared Claude Code plugins. Two ship with fort-starter; both install into every profile.

## Inventory

| Plugin | What it provides | Internal layout |
|--------|------------------|-----------------|
| `fort` | Workflow skills — capture, recall, narrate, distill, retro, park, research, etc. The persistent-workspace toolkit. | `skills/` |
| `fort-tools` | Reusable utility skills that aren't tied to the daily Fort rhythm. Currently: `diff-view` (source-vs-derivative HTML viewer). | `.claude-plugin/plugin.json`, `skills/`, `README.md` |

See `fort-tools/README.md` for the rationale on the `fort` vs `fort-tools` split.

## How discovery works

Claude Code discovers plugins by scanning `./plugins/` in the live working tree (NOT `core/plugins/` directly). A plugin is any subdirectory containing a manifest at `.claude-plugin/plugin.json`, or a recognized skill layout. `fort-bootstrap` copies `core/plugins/*` into `./plugins/` during assembly — the live copy is what Claude Code reads.

## Canonical skill location

`core/plugins/fort/skills/` is the source of truth for fort-plugin skills. The 16 skills here are loaded by name (referenced from rules, agents, or other skills) rather than invoked as slash commands. User-invocable slash commands live in `profiles/<name>/commands/` instead — see `profiles/vanilla/commands/README.md`.

Profile-specific plugins go in `profiles/<name>/plugins/` and install additively alongside core plugins (see `profiles/README.md`).
