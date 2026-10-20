# core/plugins/

Skill sources, grouped as Claude Code plugins. Two ship with fort-starter.

## Inventory

| Plugin | What it provides |
|--------|------------------|
| `fort` | Workflow skills: capture, recall, narrate, retro, park, research, spawn/despawn, skill-health, and more. The persistent-workspace toolkit. |
| `fort-tools` | Utility skills not tied to the daily rhythm. Currently `diff-view` (source-vs-derivative HTML viewer). |

See `fort-tools/README.md` for the rationale on the split.

## Layout

Every skill is a directory: `<plugin>/skills/<name>/SKILL.md`, with `name: <name>` and a `description:` in its frontmatter. Supporting files (templates, references) sit next to `SKILL.md` inside that directory. The directory name is the slash command. Each plugin also carries a manifest at `.claude-plugin/plugin.json`, so `claude plugin validate core/plugins/<name>` works.

## How they install

`fort-bootstrap` copies every skill directory from here, plus the profile's own `profiles/<profile>/skills/`, into `.claude/skills/<name>/`. That is the directory Claude Code reads; there is no `.claude/commands/` mirror. A profile skill with the same name wins over a core one, and `profiles/<profile>/skills-disabled/<name>` skips one.

Edit the source here and run `./fort-bootstrap --refresh`; edits made directly in `.claude/skills/` are local overrides that the next refresh replaces. `/skill-health` flags malformed skill directories and drifted installed copies.
