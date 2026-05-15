# profiles/vanilla/commands/

The 20 slash commands vanilla exposes. Installed to `.claude/commands/` by `fort-bootstrap`.

## Inventory

Grouped by purpose:

| Group | Commands |
|-------|----------|
| **Daily rhythm** | `/bod`, `/pulse`, `/briefing`, `/eod` |
| **Knowledge capture** | `/capture`, `/note`, `/park`, `/distill`, `/narrate` |
| **Retrieval & navigation** | `/search-fort`, `/recall`, `/switch` |
| **Reflection & maintenance** | `/retro`, `/garden`, `/reminders` |
| **Work** | `/research`, `/assistant` |
| **External integrations** | `/calendar` |
| **Utilities** | `/compress`, `/tab-name` |

## How they install

These are regular `.md` files (not symlinks). `fort-bootstrap` copies each one to `.claude/commands/` with `cp -f`. The profile's `commands/` directory is the canonical source for which slash commands a profile exposes — switching profiles changes the command set wholesale (the bootstrap clears `.claude/commands/` before copying).

## Customizing

The bootstrap copies, never symlinks, so editing a command after install gives you a local override that lives in `.claude/commands/<name>.md`. That local copy will be overwritten the next time you run `fort-bootstrap --refresh` — if you want the change to stick, edit the source here in `profiles/vanilla/commands/` (or in a forked profile) and re-bootstrap.

## What's NOT here

Some commands referenced in the project README's "flows" — `/brainstorming`, `/writing-plans`, `/executing-plans`, `/design-lab`, `/review-pr`, `/ship`, `/devlog`, `/weekly-review` — are part of the upstream personal Fort and aren't bundled in vanilla. Add them via fork, or wait for upcoming PRs that promote stabilized skills into the starter.
