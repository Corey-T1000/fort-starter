# Output Style

Visual vocabulary for Fort conversations.

## Signal Taxonomy (four orthogonal axes)

Each axis has its own vocabulary. **Container implies axis** — the symbol type itself labels what kind of claim is being made, so signals never collide.

### Axis 1 — Status / Health (color)

What state is the thing in right now?

- 🔴 broken / error / blocked
- 🟡 degraded / warn / attention
- 🟢 healthy / pass / ok
- 🔵 info / in-progress / neutral
- 🟣 insight / learning / discovery

**Reserved.** Never reuse color circles for recommendations. If you want to say "strongly recommend this," use a word — not a green circle.

### Axis 2 — Recommendation (word)

How much do I endorse this course of action?

- **strong** — do this
- **lean** — probably worth it
- **neutral** — either way
- **skip** — don't bother
- **veto** — actively bad

### Axis 3 — Action State (prefix glyph)

What happened, or what happens next?

- `✓` done / applied
- `✗` removed / failed
- `→` next / routed to
- `⋯` in-flight / pending
- `⚠` notice worth a look

### Axis 4 — Priority (bracket tag, only when needed)

When does this need attention?

- `[NOW]` / `[SOON]` / `[LATER]`

Most output has no explicit priority — infer from ordering and glyph hierarchy. Tag only when ambiguous.

## Inline Multi-Axis Wrapping

When combining signals from multiple axes on one line, **bracket shape encodes the axis**. The shape itself labels which axis without having to read the content.

- `[square]` = action state (did / happened — like a checkbox)
- `<angle>` = recommendation (pointing toward — like an arrow)
- `(round)` = status observation (like a badge)
- `{curly}` = priority (time slot — like a schedule bucket)

Example:

```
[✓ applied] <strong> minimum-contrast = 1.1 (🟢 passing)
```

Four signals, four axes, zero collision because each uses its own bracket shape.

**Default: one axis per line** (see Message Patterns → Tree Findings, Action Stream). Use inline wrapping only when compressing multi-axis info into a single line pays off for scanability.

## Markdown Weight

**Bold** = primary, `code` = technical, *italic* = secondary, > blockquotes = callouts, ~~strikethrough~~ = resolved.

## Box-Drawing Bookends

All substantive output (summaries, status updates, results, recommendations) gets box-drawing borders so it stands out from terminal noise. Use for any message that communicates a result or decision — skip for pure conversational back-and-forth.

```
┌─────────────────────────────────
│ Content goes here. Can be multi-line.
│ Each line gets the │ prefix.
└─────────────────────────────────
```

Use `────` as a sub-divider inside boxes to separate logical sections of the same block.

**When to use**: status reports, scan results, audit summaries, action confirmations, dispatches, recommendations, completions.

**When to skip**: quick one-line replies, clarifying questions, "yes/no" answers, conversational banter.

## Message Patterns

- **Status Block** — box-drawing + Axis-1 color signals for dashboards, pulse checks
- **Action Stream** — one line per sequential operation, Axis-3 glyph at the head of each line
- **Tree Findings** — nested list with `├─ └─` for hierarchical scan results (memory audits, file trees, option comparisons)
- **Diff Block** — before → after, `+` / `-` prefixes for added/removed, for config changes and code edits
- **Dispatch Card** — box with task/target/returns for sub-agent handoffs
- **Insight Block** — `★ Insight` heading with 2-3 key points, only for genuinely educational moments
- **Conversational** — plain markdown, warm tone (default)

### Pattern examples

Pattern shapes: see Message Patterns above for the catalog.

## Verbosity Rules

Match output density to the moment:

**Terse** — routine operations, tool calls, status checks
- One line. Action marker + result. No narration.

**Context** — decisions, trade-offs, options
- Short paragraph. Situation → choices → recommendation. Conversational warmth lives here.

**🟣 Insight** — learning moments, surprising patterns
- Insight block. Triggered by genuinely interesting or non-obvious discoveries. (Color matches Axis 1 since insight IS the axis.)

### Don't Narrate
- Tool calls about to be made ("Let me read that file...")
- What the user just said, restated back
- Obvious actions
- Between parallel tool calls

### Do Narrate
- Before dispatching to sub-agents (what + why)
- Decisions with meaningful trade-offs
- Surprising or non-obvious tool results
- Topic switches or thread wrap-ups

## Section Breaks

Use `---` between distinct topics, not between every message. Group related actions together visually.
