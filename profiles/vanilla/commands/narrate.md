---
name: narrate
description: Use to capture the conversational arc of a session — implicit acceptances, one-line reframings, rejected alternatives, the how-we-got-here. Runs as a fork sub-agent against the transcript. Complementary to /distill (files ↔ facts); /narrate captures the reasoning that never hit a file. Triggers include "narrate this session", "capture the arc", "what pushed back on my thinking", or automatic dispatch from /eod alongside /distill.
user_invocable: true
context: fork
agent: general-purpose
---

# Session Narration

Capture conversational arc into `memory/session_YYYY-MM-DD_<slug>.md`. This is the reasoning trail that `/distill` can't extract — because `/distill` reads files and git, not the conversation itself.

## When to Use

- User says "narrate this session", "capture the arc", "what pushed back on my thinking"
- Auto-dispatched from `/eod` alongside `/distill` — both fire in parallel, write different files
- Start-hook reports "Previous session queued capture" → run `/narrate` AND `/distill` as parallel background agents
- Mid-session when reframings are piling up (several short user pushbacks that redirected the plan) and context is approaching compaction
- Session closing where the HOW (rejected alternatives, implicit acceptances, the arc) matters more than the WHAT — complement to `/distill`, never a substitute
- NOT for assistant-led sessions with no reframings — the skill will correctly write "None identified" rather than fabricate
- NOT `/distill` — that writes JD-indexed operational knowledge from files/git; `/narrate` writes a single `session_<date>_<slug>.md` from the transcript

## Why this exists

`/distill` extracts from file diffs, commits, and session-digest. Even when it runs perfectly, **conversation-only content drops**: implicit acceptances ("yes do it"), one-line reframings that shape the work, rejected alternatives, the how-we-got-here narrative.

This skill captures that signal so it survives compaction and shows up in future retrieval.

## Dispatch Rule

Always run `/narrate` as a fire-and-forget background sub-agent, same as `/distill`. Both can run in parallel on the same transcript — they write different files.

1. Resolve the transcript path:
   ```bash
   FORT_ROOT="$(git rev-parse --show-toplevel)"
   FORT_PROJECTS="$HOME/.claude/projects/-$(echo "$FORT_ROOT" | sed 's|^/||; s|/|-|g')"
   # Current session's transcript, if known
   SESSION_ID=$(cat "$FORT_PROJECTS/memory/.session/session-id" 2>/dev/null | sed 's/session-[0-9-]*-//')
   TRANSCRIPT=$(ls -t "$FORT_PROJECTS/"*.jsonl 2>/dev/null | head -1)
   ```

2. Dispatch via Agent tool with `run_in_background: true`, `mode: "auto"`, `model: "sonnet"`, prompt template below.

3. Tell the user **once**: "Narrate running in background" — don't wait for the agent.

**Prompt template for the sub-agent:**
```
You are running /narrate. Read your full instructions from:
${FORT_ROOT}/core/plugins/fort/skills/narrate.md

Transcript: <absolute path to session JSONL>

Focus slug (2-3 words, dash-separated): <derive from session focus / tab title / active assistant>

When finished, return ONLY the single-line summary block described at the end.
```

If running inside a sub-agent already, proceed directly with the steps below.

## The Process (silent until final summary)

### 1. Read the transcript

```bash
TRANSCRIPT=<path passed in>
wc -l "$TRANSCRIPT"  # size check
```

Parse the JSONL. For each entry:
- `type=user` with `role=user` and non-system content → a user utterance
- `type=assistant` with `role=assistant` → an assistant turn

Skip `type=system`, `type=attachment`, `stop_hook_active` markers, and `system-reminder` wrapper messages.

### 2. Extract the arc

Scan for four classes of content:

**A. One-line reframings** (highest-value signal)
- User messages that *redirected* the work: short questions or pushbacks that changed the plan.
- Heuristics: user message < 200 chars, contains a question mark or imperative verb, and the following assistant turn visibly shifts direction (new tool calls on different files, new approach announced, apology/correction).
- Examples: "seems like a holistic problem, do your suggestions fix this?", "why a week and not at once?", "when you say archive what do you mean?"

**B. Rejected alternatives**
- Options the assistant surfaced (A/B/C style) where the user chose one and the others were dropped.
- Capture *why* the chosen path won, if stated.

**C. Implicit acceptances**
- User messages that accepted a proposal without explicit reasoning ("yes", "do it", "looks good", "ship it").
- Pair each with the proposal it accepted — the accepted-thing is the decision, the acceptance is just the trigger.

**D. How-we-got-here narrative**
- The session's opening signal (what triggered it — a pivot, a curiosity, a bug report).
- Key mid-session pivots (topic switches, scope changes).
- How the session closed (shipped / parked / deferred).

### 3. Check for duplicates

Before writing, check `memory/session_YYYY-MM-DD_*.md` for the same date. If one already exists for this session's slug, APPEND to it under a new `## Continuation — <time>` section rather than overwriting. A session can have multiple narrate runs (mid-session /narrate, then /eod /narrate).

### 4. Write the narrative file

Path: `${FORT_ROOT}/memory/session_YYYY-MM-DD_<slug>.md`

Template:

```markdown
---
name: Session narrative — <focus> (YYYY-MM-DD)
description: <one-sentence arc summary>
type: project
originSessionId: <session UUID if known, else omit>
Slug: <slug-from-parent-assistant>   # enables [[wikilink]] references
Status: published
JD: <XX or XX.YY if applicable, else null>
Tags: [<2-5 lowercase-dash tags>]
Related: [<other assistant slugs this touches>]
Flags: [<AAAK flags — see below>]
---

# Session Narrative — YYYY-MM-DD <slug>

<One-paragraph preamble: what this session was, why the narrative matters. Reference any companion files that captured durable artifacts (`memory/project_X.md`, `docs/plans/Y.md`) — this file complements those by capturing the HOW.>

## Arc

**Start**: <opening trigger + first move>

<2-4 paragraphs narrating the session chronologically. Highlight pivots. Reference tool calls / sub-agents / decisions by their visible effect, not their mechanics.>

## Reframings (shape-altering pushbacks)

One-line user questions that redirected the work:

1. **"<verbatim user quote>"** → <what it redirected, what the new direction became>
2. **"<quote>"** → <…>

(If none, write "No explicit reframings this session — assistant-led throughout.")

## Rejected alternatives

- <option A considered>: <why it was dropped>
- <option B considered>: <why it was dropped>

(Omit section if none.)

## Decisions captured in files (durable artifacts)

- `memory/project_X.md` — <what was captured>
- `docs/plans/Y.md` — <what was captured>

## Open threads / deferred

- <thread 1> — <where it was parked, who owns next>
- <thread 2> — <…>
```

**Rules:**
- Verbatim quotes only — don't paraphrase user reframings. The exact wording IS the signal.
- No fabrication — if you can't identify a reframing, write "None identified" rather than manufacture one.
- Keep it tight. 200-400 lines for most sessions. Long sessions (>2hr, >50 turns) can go longer if the reframing density is real.
- Cross-reference companion memory files by their filename — don't duplicate what lives in `project_*.md` or `feedback_*.md`.

**AAAK flags (apply at write time):**

Pick 0-3 flags from this controlled vocabulary that best describe what mattered in this session:

- `PIVOT` — thread changed direction mid-session (reframing so sharp the prior plan was abandoned)
- `DECISION` — a choice was made with rationale worth preserving (usually means a commit message captures the "what" but not the "why")
- `ORIGIN` — a project, idea, or convention first appeared here
- `CORE` — a load-bearing mental-model moment (something you'll want to reason from later)
- `SENSITIVE` — auth, secrets, PII, or content with sharing constraints (triggers extra care on share / publish)

Typical counts:
- **Most sessions**: 1-2 flags (usually `DECISION`)
- **Big pivots**: 2-3 flags (`PIVOT, DECISION, CORE`)
- **Pure execution / no reframings**: `[]` is fine — don't flag for flag's sake

These are schema-reserved. Don't invent new values; the vocabulary grows deliberately from usage review, not from this skill.

### 5. Close

```bash
# Touch a narrate marker so gather/audit can see this ran.
# Also clear the .narrate-needed queue marker that the stop/session-end
# hooks may have written. Marker stays in place until /narrate actually
# runs — if the agent skips the dispatch, next session re-announces.
FORT_PROJECTS="$HOME/.claude/projects/-$(echo "$FORT_ROOT" | sed 's|^/||; s|/|-|g')"
touch "$FORT_PROJECTS/memory/.narrate-ran"
rm -f "$FORT_PROJECTS/memory/.narrate-needed"
```

Return ONE line: `Narrate: memory/session_<date>_<slug>.md — <N reframings, M decisions>`

## When this runs

- **Automatically** — `/eod` dispatches `/narrate` alongside `/distill`.
- **Manually** — `/narrate` mid-session to capture an arc before context grows too long; `/narrate` at session end as an alternative to waiting for `/eod`.

## Interaction with /distill

Both skills dispatch against the same transcript, but they write to different places:

| | /distill | /narrate |
|---|---|---|
| Source | git diff + session log + memory tails | transcript JSONL |
| Target | `memory/XX-topic.md` (JD-indexed) | `memory/session_<date>_<slug>.md` |
| Captures | operational knowledge, gotchas, config values | reasoning, reframings, how-we-got-here |
| If skipped | file-level learnings drop | conversation-level reasoning drops |

Ship both. They complement, not overlap.

## Common mistakes

- **Paraphrasing quotes**: the user's exact wording is the signal. Preserve it.
- **Fabricating reframings**: If the session was assistant-led with no pushback, say so — don't invent a reframing to fill the section.
- **Duplicating /distill content**: If a decision lives in a `project_*.md` file, link to it rather than re-summarize.
- **Skipping for "short" sessions**: A 30-turn session with 2 real reframings is narrate-worthy. Length isn't the gate; reframing density is.
