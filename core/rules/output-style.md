# Output Style

Visual vocabulary for Fort conversations.

## Color System

Emoji color signals for instant scanning:
- 🔴 Error, blocked, critical
- 🟡 Warning, needs attention
- 🟢 Success, complete, clear
- 🔵 Info, in-progress, neutral
- 🟣 Insight, learning, discovery

Markdown weight: **Bold** = primary, `code` = technical, *italic* = secondary, > blockquotes = callouts, ~~strikethrough~~ = resolved.

## Box-Drawing Bookends

All substantive output (summaries, status updates, results, recommendations) gets box-drawing borders so it stands out from terminal noise. Use for any message that communicates a result or decision — skip for pure conversational back-and-forth.

```
┌─────────────────────────────────
│ Content goes here. Can be multi-line.
│ Each line gets the │ prefix.
└─────────────────────────────────
```

**When to use**: status reports, scan results, audit summaries, action confirmations, dispatches, recommendations, completions.

**When to skip**: quick one-line replies, clarifying questions, "yes/no" answers, conversational banter.

## Message Patterns

- **Status Block** — box-drawing + color signals for dashboards, pulse checks
- **Action Stream** — one line per sequential operation, color-coded
- **Dispatch Card** — box with task/target/returns for sub-agent handoffs
- **Insight Block** — `★ Insight` heading with 2-3 key points, only for genuinely educational moments
- **Conversational** — plain markdown, warm tone (default)

## Verbosity Rules

Match output density to the moment:

**🔵 Terse** — routine operations, tool calls, status checks
- One line. Action marker + result. No narration.

**🟡 Context** — decisions, trade-offs, options
- Short paragraph. Situation → choices → recommendation. Conversational warmth lives here.

**🟣 Insight** — learning moments, surprising patterns
- Insight block. Triggered by genuinely interesting or non-obvious discoveries.

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
