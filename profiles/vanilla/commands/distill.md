---
name: distill
description: Use when ending a session, wrapping up work, or before saying "done". Captures session learnings into JD-numbered memory topic files and flushes beads.
user_invocable: true
context: fork
agent: general-purpose
---

# Session Distillation

Capture what matters from this session into the right JD-numbered memory files.

## Dispatch Rule (MANDATORY)

**Always run distill as a background sub-agent.** The dozens of Read/Bash/Edit/Grep calls clutter the main chat and push real answers off-screen. When `/distill` is invoked (manually or by hook):

1. Dispatch the entire process below to a sub-agent via Agent tool with `run_in_background: true`, `mode: "auto"`, and `model: "sonnet"`
2. The sub-agent has NO conversation context. You MUST include a **Session Summary** in the prompt covering:
   - What was worked on (projects, features, bugs)
   - Key decisions, gotchas, and fixes discovered
   - Files modified (from git diff/status)
   - Any API quirks, deploy issues, or config values learned
   - Which JD topics are likely relevant (e.g., "52-automation, 53-claude-code")
3. When the agent returns, surface ONLY the final summary block to the user — nothing else
4. If the session was trivial (config tweaks, memory edits only), tell the agent to take the Fast Path

**Prompt template for the sub-agent:**
```
You are running /distill. Read your full instructions from:
${FORT_ROOT}/plugins/fort/skills/distill.md

## Session Summary
[paste summary here]

## Files Changed
[paste git diff --stat or key files]

Execute the distill process. Return ONLY the final summary block.
```

If running inside a sub-agent already, proceed directly with the steps below.

## Output Rules (MANDATORY)

**Do all evaluation silently.** Use tool calls (Read, Bash, Edit, Grep) with no narration between them. The ONLY text you output to the user is the final summary block in Step 5. No numbered lists of learnings, no reasoning about what to keep/skip, no "already documented" commentary, no intermediate status updates. Work silently, report once.

## When This Runs

- **Automatically** — Stop and PreCompact hooks block until this runs
- **Manually** — `/distill` when switching contexts or capturing something mid-session

## Fast Path (Trivial Sessions)

If the session only involved config tweaks, memory edits, symlinks, or minor changes with no new operational learnings:

1. Run `touch` on the marker
2. Say **only**: "Nothing to distill." — no summary block, no git commands, no ceremony
3. Stop here. Do NOT proceed to the full process below.

## The Process (all steps silent — no text output until Step 5)

### 1. Gather Session Activity

Run these in parallel (silently):

```bash
git diff --stat HEAD~3..HEAD 2>/dev/null || git diff --stat
git status
bd list --status=in_progress 2>/dev/null
bd list --status=closed 2>/dev/null | tail -5
```

Also review the conversation for gotchas, patterns, decisions, and fixes.

### 2. Classify What's Worth Keeping

**Keep:** Operational knowledge that saves future sessions time
- Deploy gotchas, config values, API quirks
- Patterns that worked (or failed)
- Architecture decisions with rationale
- New project setup details

**Skip:** Session-specific noise
- Intermediate debugging steps that led nowhere
- Obvious things (standard library usage)
- Anything already in CLAUDE.md or existing memory

If nothing worth keeping → skip to Step 6 (Flush & Close).

### 2b. Detect Design Intent (Conditional)

Check if this session involved UI/design work. Signals (any one triggers):
- Files modified in `scratch/design-lab/`, `scratch/playground/`, or design-related project dirs
- HTML/CSS/component files created or heavily modified
- `/design-lab`, `/interface-design`, `/frontend-design`, or `/playground` invoked during session
- Conversation references layout decisions, color choices, interaction patterns, or visual exploration

**If design work detected**, extract a Design Intent block by reviewing the conversation for:
- **Direction chosen & why** — what design approach was selected and the reasoning
- **Alternatives rejected** — what was explored and discarded, and what felt wrong about it
- **Key visual/UX decisions** — specific choices about layout, spacing, interaction, color, typography with rationale
- **Unresolved questions** — design tensions or open questions to revisit next session

Store this as a structured section to include when writing the relevant topic file in Step 4:

```markdown
### Design Intent — {date}
- **Chosen direction**: {what and why}
- **Rejected alternatives**: {what and why not}
- **Key decisions**: {specific choices with rationale}
- **Open questions**: {unresolved tensions}
```

If no design work detected, skip this step silently — no mention in output.

### 3. File by JD Number

Read the memory index to find the right destination:
```
memory/MEMORY.md  → JD index (find the right file)
memory/XX-topic.md → Topic files (write here)
```

**JD Quick Reference:**
| Range | Area |
|-------|------|
| 50 | Infrastructure & Deploy |
| 51 | Fort CLI & Scripts |
| 52 | Automation & Workflows |
| 53 | Claude Code Config |
| 54 | Fort Memory System |
| 55 | Notifications & Monitoring |
| 60+ | Projects (see MEMORY.md index) |

If a learning doesn't fit any existing category:
1. Create a new topic file (`memory/XX-new-topic.md`)
2. Add it to the MEMORY.md index table

### 4. Write Updates

Edit the appropriate `memory/XX-topic.md` file(s). Rules:
- **Append or update** — don't duplicate existing entries
- **Be specific** — include actual values, commands, paths
- **Note the date** if time-sensitive (API versions, temporary workarounds)
- **Cross-reference** by JD number when linking topics ("see `50` for Docker details")

### 5. Queue Facts for Background Memory Sync

Instead of writing to memory synchronously (which blocks session close), write a JSONL queue file that `distill-background` will process asynchronously.

For each learning written to a topic file, extract a one-line fact and add it to the queue:

```bash
QUEUE_DIR="$HOME/.claude/projects/-Users-$(whoami)-$(basename "${FORT_ROOT:-claudes-fort}")/memory/.distill-queue"
mkdir -p "$QUEUE_DIR"
QUEUE_FILE="$QUEUE_DIR/$(date +%Y%m%d-%H%M%S).jsonl"
```

Write a single JSON object to the queue file with this structure:
```json
{
  "session_id": "<from .claude/projects/.../memory/.session/session-id>",
  "date": "YYYY-MM-DD",
  "facts": [
    {"topic": "53-claude-code", "fact": "One-line fact extracted from this session"},
    {"topic": "54-fort-memory", "fact": "Another fact from a different topic"}
  ],
  "memory_files_updated": ["53-claude-code.md", "54-fort-memory.md"],
  "knowledge_base_topics": ["53", "54"]
}
```

Use `jq` or `cat <<EOF` to write valid JSON. **Verify the file is valid JSON** after writing:
```bash
jq empty "$QUEUE_FILE" || echo "ERROR: Invalid queue file" >&2
```

The background processor (`distill-background`) handles:
- Memory saves + flush
- Remote backup verification
- Queue cleanup

It runs automatically on next session start, or manually via `distill-background`.

### 6. Knowledge Base Synthesis (Conditional — Fast Path)

For topics where meaningful learnings were captured (not trivial config notes), write a synthesized note to the knowledge base's matching JD directory. This is the human-readable version — not atomic facts, but connected insights useful for browsing.

**Knowledge base JD path mapping** (set `$FORT_KNOWLEDGE_BASE` to your knowledge base directory):
- `50-59` → `$FORT_KNOWLEDGE_BASE/50 Fort Infrastructure/{XX}.01 {Topic Name}/`
- `60-73` → `$FORT_KNOWLEDGE_BASE/60 Fort Projects/{XX}.01 {Topic Name}/`

**Writing rules:**
- Check for existing notes in the target directory first — update if related, create new if distinct
- Title notes by *what happened*, not by date (e.g., "Notification Architecture Refactor" not "2026-03-07 Session Notes")
- Write for the human reader, not agent Claude — explain the *why*, connect to broader context
- Include implications: "this means X for future Y work"
- Keep concise — a few paragraphs, not a wall of text
- Use markdown (wikilinks `[[]]` are fine for Obsidian-compatible knowledge bases)

**Skip knowledge base write when:**
- Only trivial config/setup facts were captured
- The learnings are purely agent-operational (hook tweaks, memory file formatting)
- An existing knowledge base note already covers this ground

**Format:**
```markdown
# {Descriptive Title}

{2-3 paragraphs synthesizing what was learned, why it matters, and what it implies}

## Key Details
- Specific values, commands, or gotchas worth remembering

---
*Distilled from Fort session {date}*
```

### 7. Flush & Close

```bash
# Mark distill as complete (prevents hooks from re-triggering)
touch "$HOME/.claude/projects/-Users-$(whoami)-$(basename "${FORT_ROOT:-claudes-fort}")/memory/.distill-ran"
```

**This is the ONLY text output for the entire skill.** Present a single status block:

```
┌─ 💾 DISTILL ─────────────────────────┐
│ 🔵 Staging: N files                  │
│ 🟢 Updated: XX-topic.md              │
│   one-line summary of what was added  │
│ 🎨 Design Intent: {direction chosen} │
│   → captured in XX-topic.md          │
│ 🟣 Knowledge base: {note title}      │
│   → {JD dir path}                    │
│ 🔵 Skipped: N (already documented)   │
└───────────────────────────────────────┘
```

Adapt the rows to fit what happened:
- One `🟢 Updated` row per memory file touched, with a brief content summary below it
- One `🟢 Created` row if a new topic file was added
- One `🎨 Design Intent` row if design rationale was captured, with the chosen direction
- One `🟣 Knowledge base` row per note written to the knowledge base, with target path
- One `🔵 Skipped` row with count if learnings were already documented
- Omit rows that don't apply (no "Skipped: 0")
- If nothing was captured: just show `🔵 Nothing to capture`

## Common Mistakes

- **Over-capturing**: Not everything is worth remembering. If grep would find it easily, skip it.
- **Wrong JD slot**: When unsure, check the index. Don't shove infra into a project file.
- **Forgetting to update the index**: If you create a new topic file, MEMORY.md must know about it.
- **Duplicating**: Read the target file first. The info might already be there.
- **Narrating the process**: All evaluation is silent. Only the final summary block is shown.
