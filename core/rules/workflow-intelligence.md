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

## Knowledge Base Cross-Check (Read Path)

When answering questions or making claims about a JD topic from memory, also check the external knowledge base for relevant notes:

```bash
# Find recent knowledge base notes for a JD topic
find "${FORT_KNOWLEDGE_BASE}" -path "*/{JD}.01 *" -name "*.md" -newer <7-days-ago> 2>/dev/null
```

**Knowledge base JD path mapping** (set `$FORT_KNOWLEDGE_BASE` to your knowledge base directory):
- `50-59` → `$FORT_KNOWLEDGE_BASE/50 Fort Infrastructure/{XX}.01 {Topic Name}/`
- `60-73` → `$FORT_KNOWLEDGE_BASE/60 Fort Projects/{XX}.01 {Topic Name}/`

**When to cross-check:**
- Before making confident claims about a topic's current state
- When memory facts feel sparse or stale for the topic
- When the question is "how does X work" or "what's our setup for Y"

**What to do with findings:**
- If the knowledge base has content not in memory: read it, incorporate it, flag the gap
- If the knowledge base contradicts memory: surface the conflict to the user
- If the knowledge base is empty for the topic: proceed normally, no mention needed

Don't cross-check for trivial lookups or topics you just wrote to.

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
