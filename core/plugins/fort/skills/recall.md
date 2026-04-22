---
name: recall
description: |
  Vibe-anchored recall over Fort narrative memory (session_*.md, feedback_*.md).
  Dispatches a sub-agent to read-and-judge — no vector DB.
  Use when asked to "recall the session where...", "find the feedback rule about...",
  "remember when we...", "which conversation had...", or any query with no clean
  keyword handle. Complements /search-fort (crisp keywords) and direct memory reads
  (known JD). Validated at 7/8 hit rate in source Fort dry-run.
user_invocable: true
argument-hint: "<vibe-anchored query in natural language>"
---

# /recall

Agent-as-retriever. Answers vibe queries by dispatching a sub-agent to scan narrative memory files. Zero infrastructure — Claude is the embedding model.

Reach for `/recall` when the query has **no clean keyword handle** — feelings, arcs, patterns, "the time we...", "the session that felt...", or when you know it's in there but can't remember the term.

## When to use

- "find the session where we..."
- "which feedback rule was about..."
- "recall the time we kept bumping into..."
- "what was that pattern where X felt Y"
- Any query where grep would return zero hits but you KNOW it's documented

## When NOT to use

- Known file path → `Read`
- Known keyword → `rg` or `/search-fort`
- Known JD topic → read the topic file directly
- Meta-temporal ("what's the oldest session") → filesystem (`ls -t ${FORT_ROOT}/memory/session_*.md`)
- Curated index ("list all projects") → `MEMORY.md`

## Flow

### Step 1: Resolve relative dates

If the query contains a relative date phrase ("yesterday", "last Monday", "mid-April", "this week"), resolve it against today's date BEFORE pre-filtering. Use `date +%Y-%m-%d` for today; back-resolve weekday names against today. Carry the resolved range into Step 2's filter. If the resolution is ambiguous (e.g., "Tuesday" could be this week or last), surface both candidates to the user before dispatching.

### Step 2: Parse the query, pick a pre-filter

Route by signal:

| Query has… | Pre-filter by… | Example |
|---|---|---|
| time phrase | filename date (resolved in Step 1) | "the session last Tuesday where…" |
| Flag word (PIVOT, DECISION, ORIGIN, CORE, SENSITIVE) | frontmatter `Flags:` | "find the PIVOT about…" |
| project/topic name | `Tags:` or JD path | "the betbud session where…" |
| pure vibe / no anchor | none (full scan) | "when things went sideways" |

Multiple anchors → intersect.

**Coverage caveat**: Tag/Flag pre-filters only see files with v2 frontmatter. Older narrative files (pre-v2 rollout) lack these fields and are invisible to those filters. If a Tag/Flag pre-filter returns suspiciously few candidates, fall back to a wider net (filename + body grep) and let the agent disambiguate. To backfill old files run `${FORT_ROOT}/bin/fort-frontmatter-upgrade`.

### Step 3: Assemble candidate file list

```bash
# narrative corpus
find ${FORT_ROOT}/memory -maxdepth 1 -name "session_*.md" -o -name "feedback_*.md"

# pre-filter examples
# time:  find ... -newermt "2026-04-19" -not -newermt "2026-04-22"
# flag:  rg -l 'Flags:.*PIVOT' ${FORT_ROOT}/memory/session_*.md
# tag:   rg -l 'Tags:.*betbud' ${FORT_ROOT}/memory/session_*.md ${FORT_ROOT}/memory/feedback_*.md
```

### Step 4: Dispatch

- Candidates ≤ 30 → single agent, read all
- Candidates 31-90 → 3 agents in parallel, alphabetical slices of ~30 files each
- Candidates > 90 → require a tighter filter or pre-filter via `/search-fort` first

Use `general-purpose` sub-agent. Prompt template below.

### Step 5: Merge results

Each agent returns top 1-3 hits with file path + 2-sentence why + short excerpt. Surface all hits; if multiple agents flagged the same file, promote to `★`. Deduplicate on path.

## Sub-agent prompt template

Fill `{{query}}`, `{{count}}`, `{{file_list}}` and dispatch:

```
You're helping answer a vibe-anchored recall query over a curated narrative corpus.

QUERY: {{query}}

CONTEXT:
- Files are session_*.md (conversational arcs) and feedback_*.md (patterns/rules)
  under ${FORT_ROOT}/memory/.
- Each file has YAML frontmatter (Tags/Flags on newer files; older files have only
  name/description/type) and prose body.
- Flags vocabulary: PIVOT (course change), DECISION (load-bearing choice),
  ORIGIN (first-mention), CORE (fundamental), SENSITIVE (sharp moment).

FILES TO SCAN ({{count}}):
{{file_list}}

WHAT TO DO:
1. Skim each file's frontmatter (`name:` and `description:`). Filter to candidates
   whose framing suggests relation to the query.
2. For survivors, read the body. Judge: does this match the VIBE of the query,
   even if the keywords aren't there?
3. Return top 1-3 hits with:
   - Path (relative to repo root)
   - 2-sentence "why"
   - 1-2 line literal excerpt

FORMAT:
## Top hits

### ★ <path>
**Why**: <2 sentences>
**Excerpt**: "<literal quote>"

### · <path>
**Why**: <2 sentences>
**Excerpt**: "<literal quote>"

If zero matches: "Scanned {{count}} files. No strong matches. Consider tightening
the filter or trying /search-fort for keyword surface."

BUDGET:
- Don't speculate. If the match isn't in the files, say nothing.
- Don't summarize the whole corpus. Only what answers the query.
- Don't reach. Honest "no match" beats a forced weak hit.
- Response target: under 300 words.
```

## Output format (parent agent)

```
┌─ Recall: "<query>"
│ Filter: <pre-filter strategy> | Scanned: N files
│
│ ★ memory/session_2026-04-08_silence-incident.md
│   Why: pattern-matches "silence is a bug" — 3 sessions each picked up each other's
│   loose ends, one commit was dropped. Became a named rule afterward.
│   Excerpt: "...absence of a ping was treated as 'probably fine' when it was..."
│
│ · memory/feedback_silence_is_a_bug.md
│   Why: codified rule from the incident above.
└─
```

`★` = strongest match, `·` = weaker-but-relevant.

## Cost actuals

Validated 2026-04-22 in source Fort (109-file corpus); per-query average ~55k input tokens (well under single-agent budget). Wall-clock parallel ~45s for 8 queries. Slicing wasn't needed — pre-filters collapsed candidate lists in every case. Your numbers will vary with corpus size and query shape.

## Failure modes

- **Agent hallucinates a file path** → parent verifies path exists before surfacing
- **Agent reaches for weak matches** → prompt says "don't reach"; reinforced by validation
- **Query is actually crisp** → before dispatching, run a quick `rg` on obvious keywords; if it returns ≤ 5 hits, suggest `/search-fort` instead
- **Date resolution ambiguity** → surface both candidate ranges, let the user pick

## Upgrade path

If the corpus outgrows agent-scan budgets (rule of thumb: >150 narrative files AND queries are frequent), reach for vector-backed semantic recall. In the personal Fort that's MemPalace; see `${FORT_ROOT}/memory/reference_mempalace_spike_phase1.md` for spike findings and `${FORT_ROOT}/services/mempalace-bridge/` for the install pattern. For starter users without that infrastructure, sqlite-vec + Anthropic embeddings is the lighter alternative.
