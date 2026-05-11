---
name: diff-view
description: Use when Corey says "diff view", "trace this against source", "compare to live", "where did this come from", "make a diff viewer for X", or wants to verify derivative content (one-pagers, decks, docs) against its source. Produces a single-file interactive HTML viewer with side-by-side LIVE | OURS columns, color-coded pair tinting, numbered pair badges, edit-type classification, word-level diff coloring, and slide-to-align click interaction.
user_invocable: true
context: fork
agent: general-purpose
---

# Diff View — Source Fidelity Tracer

Build a self-contained HTML viewer that lets Corey trace every block of derived content back to its source, with visual cues for what was lifted verbatim, trimmed, edited, or invented.

## When to Use

- **Verifying derivative content** — investor data room one-pagers vs live customer pages, slides vs source docs, summaries vs originals
- **VC-grade audits** — when you need a defensible artifact showing "every word traceable" or surfacing where editorial latitude was taken
- **Catching drift** — designed content that was iteratively trimmed/rephrased and you want to see where it diverged
- **Post-rebuild verification** — after rewriting docs as direct lifts from source, confirm each block landed
- **NOT for**: comparing two versions of the same file (use git diff), code review (use `/review-pr`), unstructured text similarity (use ad-hoc grep)

## Inputs Required

Ask user for:
1. **Item list** — what to compare. Each item is a (LIVE source, OURS derivative) pair:
   - LIVE: URL (https://...) or local file path (HTML, TSX, MD)
   - OURS: local file path (HTML, MD, etc.)
2. **Output path** — where to save the viewer (default: `scratch/playground/diff-<slug>/index.html` or alongside the source files)
3. **Item display names** — e.g., "Turo", "Matillion" (for the per-item card headers)

If user provides just a directory of files, auto-pair by name matching when possible.

## Reference Template

Working template lives at `plugins/fort-tools/skills/diff-view-references/template.html` — a 107KB single-file HTML with:
- Sticky-pill jump nav
- Per-item card with LIVE (warm cream bg) | OURS (cool grey bg) flex columns
- 12-color pastel palette for pair tinting (`data-pair` attr + CSS rules)
- Number badges (top-right, 20px circle, white pill)
- Edit-type badges per OURS block: `✓ VERBATIM` / `◐ TRIMMED` / `✎ EDITED` / `✦ NOVEL`
- Word-level diff: green-underlined `<span class="word-added">` for words not in source
- Dropped-from-source footnote per block (italic, capped at 12 + "more" count)
- Click-to-focus dimming + slide-to-align transform (350ms cubic-bezier ease)
- Hover tooltip showing source section + overlap %

**The template is the proven shape — adapt content, don't redesign the layout unless user asks.**

## Process

### 1. Confirm scope

Ask for the item list + output path. Convert relative paths to absolute. If a LIVE URL is provided, validate it's reachable (404 → ask user if they have a local fallback like a PR source file).

### 2. Extract content per side (parallel agents if 3+ items)

For each item, dispatch a sub-agent (or do inline if ≤2 items):

**LIVE side**:
- For URLs: `curl -sL <url>` → extract structured text (title, subtitle, H2 section headings in order, all body paragraphs, blockquotes + attribution, stats/integration tags)
- For TSX/JSX (React source): parse JSX-aware — extract H1/H2/H3 text + `<p>`, `<blockquote>`, `<Quote>`, `<Metric>` components. Decode `&rsquo;`, `&mdash;`, `{' '}`, etc.
- For Markdown: parse headings + paragraphs in order
- For HTML: parse DOM, extract by tag in document order

**OURS side**:
- Read local file, extract text in the same structural categories
- Preserve ordering — first OURS block should logically correspond to first LIVE block if structure mirrors

### 3. Pair OURS blocks with LIVE source

For each OURS block, compute Jaccard similarity (stopwords stripped, ≥3-char words, normalized for case + punctuation) against every LIVE block. The LIVE block with highest score becomes its paired source.

- Assign `data-pair-id` (incrementing integer) to each matched pair
- Assign `data-pair-num` = colorSlot + 1 (1-indexed display number, mod 12 for color cycle)
- If OURS block has Jaccard < 0.08 to all LIVE blocks → mark as NOVEL (no pair, grey background, "✦ no source match" badge)

### 4. Classify each OURS block

Compute word-level diff between paired OURS and LIVE blocks:
- **VERBATIM** — ≥95% of OURS words appear contiguously in LIVE
- **TRIMMED** — OURS is an ordered subset of LIVE words (75–95% overlap, no additions)
- **EDITED** — OURS has new/changed words vs LIVE (40–75% overlap or non-contiguous)
- **NOVEL** — already classified, no source

### 5. Word-level diff inside OURS blocks

For each OURS block:
- Tokenize both OURS and paired LIVE text into normalized words
- Compute LCS (longest common subsequence)
- Words in OURS NOT in the LCS = "added" → wrap in `<span class="word-added">` (green underline)
- Words in LIVE NOT in the LCS = "dropped" → list at the bottom of the OURS block as italic footnote: "Dropped from source: w1, w2, w3 ..." (cap at 12 + "more")

### 6. Render the template

Take the template from `plugins/fort-tools/skills/diff-view-references/template.html` and populate it with the extracted + analyzed content. Each item becomes a `<section class="customer">` (or `<section class="item">` for non-customer use cases).

DO NOT redesign the CSS or layout. Keep:
- Sticky jump nav
- Per-item card with LIVE | OURS flex grid
- Color tints (12-color palette modulo)
- Number badges
- Edit-type badges
- Word-diff spans
- Slide-to-align JS (transform: translateY, 350ms ease)
- Click-to-focus dim
- Hover tooltips
- Legend at top

### 7. Output

Save the populated HTML at the requested output path. Self-contained: inline CSS, inline JS, only external dep is Google Fonts (Inter).

Open the file via `open <path>` so user can verify.

### 8. Surface results

Report back in 200 words:
- Total items processed
- Per-item: block counts on each side (e.g., "Turo: 12 OURS / 44 LIVE blocks paired")
- Aggregate edit-type totals across all items: N VERBATIM / N TRIMMED / N EDITED / N NOVEL
- Path to the output HTML
- Any extraction caveats (e.g., "OpenAI page has no `<article>` wrapper; used deepest H2 common ancestor")

## Examples of Past Use

- **AuthZed Series B data room (2026-05-11)** — first build. Compared 6 customer one-pagers (Turo, Matillion, Netflix, Workday, OpenAI, Redpanda) against live authzed.com pages. Caught editorial drift, drove rebuild to direct verbatim lifts. Tool gave Corey VC-grade confidence ("every word traceable").

## Output Bar

The HTML viewer should let a reviewer:
1. See at a glance which OURS blocks are verbatim vs edited (color + badge)
2. Click any block and have its pair slide horizontally into view next to it
3. Hover any OURS block for a tooltip showing source section + overlap %
4. Spot novel content via grey background + ✦ badge
5. Pass it to a third party (CEO, VC) as a single file — fully portable

## Anti-Patterns

- ❌ Don't add per-item screenshots — text comparison is the point
- ❌ Don't replace the slide-to-align with regular scroll — the slide is the killer feature
- ❌ Don't add server-side rendering or external JS frameworks — single self-contained HTML
- ❌ Don't compute similarity at the document level — block-by-block is the unit

## File Locations

- Skill: `plugins/fort-tools/skills/diff-view.md` (this file)
- Template: `plugins/fort-tools/skills/diff-view-references/template.html`
- Reference build: `projects/data-room/design/onepagers/diff-viewer.html` (the original AuthZed one-pager diff that drove this skill)
