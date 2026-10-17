# profiles/vanilla/skills/

Skills only the vanilla profile ships. `fort-bootstrap` installs them to `.claude/skills/<name>/` together with every skill in `core/plugins/*/skills/`. Each is a directory holding a `SKILL.md`; the directory name is the slash command.

## Inventory (vanilla + core, as installed)

| Group | Skills |
|-------|--------|
| **Daily rhythm** | `/bod`, `/pulse`, `/briefing`, `/eod` (vanilla) |
| **Knowledge capture** | `/distill` (vanilla); `/note`, `/park`, `/narrate` (core) |
| **Retrieval & navigation** | `/switch` (vanilla); `/search-fort`, `/recall` (core) |
| **Parallel work** | `/spawn`, `/despawn` (core) |
| **Reflection & maintenance** | `/garden` (vanilla); `/retro`, `/reminders`, `/skill-health` (core) |
| **Work** | `/assistant` (vanilla); `/research`, `/feature-dev`, `/pre-mortem`, `/security-audit`, `/verify-sdk`, `/workbench` (core) |
| **External integrations** | `/calendar` (vanilla) |
| **Utilities** | `/compress` (vanilla); `/tab-name`, `/diff-view` (core) |

## Overriding

To change a core skill for this profile only, add a directory with the same name here; it wins at install. To drop a core skill, `touch ../skills-disabled/<name>`. Re-run `./fort-bootstrap --refresh` after either.

Editing `.claude/skills/<name>/SKILL.md` directly works as a local override until the next refresh replaces it.

## What's NOT here

Some flows referenced in the project README (`/brainstorming`, `/writing-plans`, `/ship`, `/review-pr`, `/devlog`, `/weekly-review`) belong to the upstream personal setup and aren't bundled. Add them as `<name>/SKILL.md` directories in a fork.
