# core/

Shared Fort infrastructure. Profile-agnostic — the same files install regardless of which profile you pick. Per-profile differences live one level up in `profiles/`.

## Layout

| Path | What it is |
|------|------------|
| `agents/` | Worker sub-agent definitions — `worker-mechanical` (Haiku), `worker-research` / `worker-editor` (Sonnet), `worker-reviewer` (Opus). Installed to `.claude/agents/`. |
| `bin/` | CLI tools (`fort-status`, `fort-notify`, `fort-search`, `tab-title`, etc.). Copied to `./bin/` during bootstrap. |
| `hooks/` | PreToolUse / PostToolUse / SessionStart / Stop / PreCompact hooks. Opt-OUT model — profiles list hooks to skip in `hooks-disabled/`, not hooks to enable. |
| `plugins/` | Shared Claude Code plugins. `fort` (workflow skills) and `fort-tools` (general-purpose utilities). See `plugins/README.md`. |
| `rules/` | Markdown files loaded into the system prompt — `guardrails.md`, `output-style.md`, `tool-routing.md`, `workflow-intelligence.md`. |
| `CLAUDE.base.md` | Base CLAUDE.md. Concatenated with `profiles/<name>/CLAUDE.md` at install time to produce the final `./CLAUDE.md`. |

## Source-of-truth contract

`core/` is the source. `fort-bootstrap` (at the repo root) reads from here and copies — never symlinks — files into the live working tree (`bin/`, `plugins/`, `.claude/hooks/`, `.claude/rules/`, `.claude/agents/`, `CLAUDE.md`). Edit `core/` and re-run `fort-bootstrap --refresh` to push changes; edits to live copies will be overwritten on the next refresh.

## How profiles compose with core

`fort-bootstrap` assembles a live workspace by layering a profile on top of `core/`:

- **Hooks**: opt-out (all of `core/hooks/` installs unless `profiles/<name>/hooks-disabled/<hook>.sh` exists)
- **Plugins**: additive (core plugins + profile plugins both install)
- **Commands**: profile-only (the profile decides which slash commands are exposed)
- **Rules / agents / bin**: always installed from `core/`
- **CLAUDE.md**: concatenated (base + profile overlay)

Full profile model: `profiles/README.md`.
