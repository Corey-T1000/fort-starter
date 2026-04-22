# Workflow Intelligence

Behavioral conventions that bridge gaps between sessions, tools, and memory.
No hooks — these require semantic judgment that shell scripts can't make.

## Research Capture (HIGHEST PRIORITY)

Research context degrades at compaction. Don't wait for `/distill`.

After web searches, codebase investigation, or API exploration that produced useful findings:
1. Proactively offer: "Save these findings to `memory/XX-topic.md`?"
2. Match findings to the right JD number from MEMORY.md index
3. If no matching topic exists, propose a new JD number and file
4. Write immediately if accepted — compaction can happen at any time

What counts as "useful findings":
- API behavior, quirks, or undocumented gotchas
- Library version differences or breaking changes
- Architecture decisions with rationale
- Debugging solutions that took multiple steps to find
- Configuration that required trial and error

What doesn't count (skip the prompt):
- Quick lookups with obvious answers
- Reading files that are already in memory
- Confirming something already documented

## Retrieval Routing (Read Path)

Three layers answer "what do we know about X", each with a different cost/shape profile. Route by question shape; escalate only when the cheaper layer comes up short.

### Layer 1 — `memory/XX-topic.md` (always first)

Operational, current, loaded on demand by the MEMORY.md routing table. Queried via `Read` / `Grep` / `/search-fort`. Use this for: "what's our setup for Y", "what did we decide about Z". If the topic file is thin (fewer than 5 facts) or stale (>7 days since update), escalate to Layer 2.

### Layer 2 — Your durable synthesis layer

Whatever long-form knowledge base you keep alongside the workspace — Obsidian vault, Notion, a separate git repo of human-edited notes. The starter doesn't bundle one; point `$FORT_KNOWLEDGE_BASE` at yours if you have it.

```bash
# Example: find recent knowledge base notes for a JD topic
find "${FORT_KNOWLEDGE_BASE}" -path "*/{JD}.01 *" -name "*.md" -newer <7-days-ago> 2>/dev/null
```

Suggested JD path mapping (mirror your memory numbering):
- `50-59` → `$FORT_KNOWLEDGE_BASE/50 Infrastructure/{XX}.01 {Topic Name}/`
- `60-69` → `$FORT_KNOWLEDGE_BASE/60 Projects/{XX}.01 {Topic Name}/`

Use Layer 2 when: the memory file is thin/stale, the question is "how does X work" or "what's our setup for Y", or before making confident claims about a topic's current state.

### Layer 3 — Semantic / vibe recall

Questions with **no keyword handle**: "that session where things went sideways", "which session had the pattern of X", "who worked on Y and when". Escalate to Layer 3 when Layers 1-2 return empty or the query is inherently impressionistic.

The floor is `/recall` — agent-as-retriever. The agent scans `memory/session_*.md` narratives directly, optionally filtered by `Flags:` frontmatter. No infrastructure required.

When the narrative corpus outgrows agent-scan budgets (typically several hundred session files), graduate to a vector-backed semantic store. The personal Fort uses MemPalace (ChromaDB-backed) — see [Corey's Fort](https://github.com/Corey-T1000/claudes-fort) for the install pattern. Until then, `/recall` is enough.

### What to do with findings across layers

- **Found in Layer 1 (sufficient)**: use it; stop.
- **Layer 2 has content not in Layer 1**: incorporate it, flag the gap.
- **Layer 2 contradicts Layer 1**: surface the conflict to the user; don't silently reconcile.
- **Layer 3 hit with no L1/L2 counterpart**: treat as recall pointer — go back and read the actual file it referenced; don't quote a vector summary as fact.
- **All three empty**: proceed normally, no mention needed.

Don't escalate for trivial lookups, topics you just wrote to, or crisp-term queries that grep handles well.

## Session Narrative Flags (AAAK vocabulary)

Session-narrative files (written by `/narrate`) carry a `Flags: [...]` field in frontmatter. The flags label *what mattered* in the session so future retrieval can find load-bearing moments without re-reading every file. Five values, applied at write time:

- `PIVOT` — course change, reframing, the moment when the approach flipped
- `DECISION` — load-bearing choice with rationale; future-you needs to find this
- `ORIGIN` — first-mention of a pattern or concept that becomes load-bearing later
- `CORE` — fundamental concept underlying multiple downstream decisions
- `SENSITIVE` — sharp-edge moments; mistakes, retros, lessons-from-pain (and auth/PII content with sharing constraints)

**Typical counts:**
- Most sessions: 1-2 flags (usually `DECISION`)
- Big pivots: 2-3 flags (`PIVOT, DECISION, CORE`)
- Pure execution / no reframings: `[]` is fine — don't flag for flag's sake

**Vocabulary discipline.** This is a closed set on purpose. The signal-to-noise ratio collapses if every session invents new flags. Grow the vocabulary deliberately through usage review, not from individual narrate runs.

**Consumed by:** `/recall` (filter narratives by flag) and `/search-fort` (boost ranking on flag matches). Both layers know how to read the field.

## Proactive Memory Loading & Tab Naming

Before the first Write/Edit in a project directory, check the routing table in MEMORY.md and load the matching memory file. Set tab title on first match.
Brief mention: "Loaded memory for home-dashboard (60)."

**Tab title rules:**
- Set via `tab-title "<tab title>"` (only once per session, first match wins)
- If no path matches but topic is clear from conversation, use `fort:<short-topic>`
- `/switch` also sets tab titles — same source of truth, no conflict
- Don't set for quick one-off questions

Only load once per project per session — don't re-read on every edit.

## Beads-Aware Skill Chains

Keep this lightweight. One question each, not a process.

**Before substantive work** (new feature, multi-file change, investigation):
- Run `bd list --status=open` silently
- If a matching issue exists: "Found beads-XXX for this — marking in_progress?"
- If no match: "Create a beads issue for this work?"
- "Just ship it" or similar bypasses the check entirely

**After shipping work** (commit, PR, deploy):
- Run `bd list --status=in_progress` silently
- If a matching issue exists: "Close beads-XXX?"
- If no match: move on silently

Don't prompt for trivial work (config tweaks, typo fixes, one-line changes).

## Compaction Recovery

After compaction or `/clear`, check `scratch/assistant-state.md`. If it exists with a `Skill:` field, re-invoke that skill immediately before responding to the user.

## Post-Debug Hookify Prompt

After debugging reveals a non-obvious gotcha — something that could bite again:
- One question: "This gotcha could be prevented with a hook. Worth `/hookify`?"
- Only for genuine gotchas: wrong API usage, silent failures, footguns
- NOT for: typos, missing imports, obvious errors, things linters catch
- If declined, move on silently. Don't ask twice in the same session.
