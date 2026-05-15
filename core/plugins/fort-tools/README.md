# fort-tools

General-purpose utility skills for the Fort.

## Why a separate plugin from `fort`?

The `fort` plugin is the **core workflow** — capture, recall, retro, park, narrate, distill, etc. Skills that are part of the daily rhythm of working in a persistent AI workspace.

`fort-tools` is for **reusable utilities** that aren't part of the workflow itself — comparison tools, audit utilities, verification scaffolds. Things you reach for occasionally, often across different projects, that don't fit the daily-driver rhythm of `fort`.

The split keeps the `fort` plugin focused (and easier to reason about as the canonical persistent-workspace pattern) while giving room for general-purpose tools to evolve without bloating the core.

## Current skills

### `/diff-view`

Build a self-contained HTML viewer that traces every block of derived content back to its source. Side-by-side LIVE | OURS columns, color-coded pair tinting, edit-type classification (verbatim / trimmed / edited / novel), word-level diff coloring, click-to-slide alignment.

**Use it for** any source-vs-derivative verification — one-pagers vs the live pages they derive from, decks vs source docs, summaries vs originals, etc.

See `skills/diff-view.md` for the full skill definition and `skills/diff-view-references/template.html` for the canonical UI shape.

## Adding skills here

If you're building a utility that:
- Is reusable across projects (not Fort-workflow-specific)
- Has a portable output (single file, self-contained, easy to share)
- Doesn't depend on Fort state (memory, sessions, parking lot, etc.)

→ it probably belongs in `fort-tools`.

If it's tightly integrated with how you persist + recall knowledge across sessions → it belongs in `fort`.
