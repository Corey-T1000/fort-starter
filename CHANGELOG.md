# Changelog

## 2026-10: parallel desks

The template now covers running several Claude Code sessions side by side, not just one good session.

### Added
- **`/spawn` and `/despawn`.** Branch a side thread into its own git worktree and a fresh, pre-briefed Claude session (cmux workspace, tmux window, or a printed command). `FORT_SPAWN_RC=1` turns on Remote Control so the desk is reachable from your phone. `/despawn` captures the session, merges the branch back and removes the worktree; it previews first and never pushes.
- **Fort Board** (`core/cmux/`). A cmux sidebar showing every desk and whose turn it is: Needs you, Your move, Cooking, Done, Ready to close, Stalled. Fed by the new `desk-status.sh` hook. Ships with a headless test harness.
- **Quick replies.** Yes / no / ack chips on Your move cards, delivered by `bin/fort-board-relay` (launchd template included).
- **Desk gist (optional).** Point `FORT_GIST_URL` + `FORT_GIST_MODEL` at any Ollama-style endpoint for a one-line summary per desk. Unset means plain labels; nothing breaks.
- `profiles/<name>/skills-disabled/` to opt out of a core skill.
- CI: a fresh-clone bootstrap smoke test on every PR.

### Changed
- **Skills are directories:** `<name>/SKILL.md`, installed to `.claude/skills/`. There is no `.claude/commands/` mirror any more. Sources live in `core/plugins/*/skills/` and `profiles/<name>/skills/`.
- `/skill-health` audits the skill layout instead of command wrappers.

### Fixed
- Hooks pointed at `${FORT_ROOT}/core/hooks/...`, and nothing set `FORT_ROOT` for Claude Code, so every hook failed on a fresh install. Hook paths are now resolved at install time.
- `./fort-bootstrap --profile=vanilla` (the README's own quick start) was rejected as an unknown option.
- On macOS, plugin install flattened every plugin into `plugins/`.
- Installs at a path with a space or `&` broke hooks and the status line.
- `fort-drift` crashed under bash 3.2.
- Startup and pre-compact hooks checked a distill path that never existed.

### Upgrading from an earlier clone
```bash
git pull
./fort-bootstrap --refresh
```
Refresh installs every shipped skill into `.claude/skills/` and deletes the old `.claude/commands/<name>.md` copy of each one. Commands you wrote yourself are left alone; move them to `.claude/skills/<name>/SKILL.md` when convenient. A backup of the previous state lands in `.fort-backup/`.
