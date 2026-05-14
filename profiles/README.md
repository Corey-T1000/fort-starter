# profiles/

Per-user / per-machine overlays applied on top of `core/`.

A profile is a directory of overrides. `fort-bootstrap --profile <name>` reads `profiles/<name>/` and copies its contents into the destination Fort's live working tree, layered on top of the shared `core/` substrate.

## Available profiles

| Profile | Use case | Plugins beyond core | Hooks disabled |
|---------|----------|---------------------|----------------|
| `vanilla` | The public-safe baseline. Generic identity, conservative permissions, no project-specific tooling. | none | none |

fort-starter ships only the `vanilla` profile. Fork the repo and add your own (`profiles/<your-name>/`) when you want a customized overlay — the bootstrap script discovers profiles by directory name.

## Profile anatomy

Each profile directory contains some subset of:

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | Profile-specific CLAUDE overlay. Concatenated after `core/CLAUDE.base.md` to produce the final `./CLAUDE.md`. |
| `settings.json` | MCP servers, permissions, hook wiring. `__FORT_ROOT__` tokens are rewritten to absolute paths at install. |
| `commands/` | Slash command files installed to `.claude/commands/`. The profile decides which commands are exposed. |
| `plugins/` | Profile-specific Claude Code plugins (additive to `core/plugins/`). Empty in vanilla — a drop-in extension point. |
| `hooks-disabled/` | Sentinel files (matched by filename). Any `core/hooks/<name>.sh` with a matching marker is SKIPPED during install. Opt-OUT model. |

## Composition model

- **Hooks**: opt-out (core ships all; profile lists ones to skip)
- **Commands**: opt-in (profile lists exactly which slash commands to expose)
- **Plugins**: additive (core + profile both install)
- **CLAUDE.md**: layered concatenation (base + profile)
- **Rules / agents / bin scripts**: always installed from `core/`

Re-run `./fort-bootstrap --profile <name>` after editing a profile to re-assemble the live workspace.
