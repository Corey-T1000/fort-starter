---
name: capture
description: |
  Use when the user says "capture this", "save these findings", "save this research",
  "persist this", or after a research session with valuable findings that should survive compaction.
  Structures findings with sources, confidence, and routes to the right memory topic file.
user_invocable: true
context: fork
agent: general-purpose
argument-hint: "[topic]"
arguments:
  - name: topic
    description: "What the research was about (auto-detected from conversation if omitted)"
    required: false
---

# Research Capture

Structured capture of research findings — web searches, API exploration, codebase investigation, documentation deep-dives. Designed to save context before compaction wipes it.

Complement to `/research` (which initiates investigation). `/capture` preserves what was found.

## When to Use

- After a research session that produced useful findings
- the user says "save this research", "capture these findings"
- The workflow-intelligence rule prompted for research capture and the user accepted
- Before compaction when there's valuable research in the conversation

## Why This Exists

Research context is the most compaction-vulnerable knowledge. Web search results, API exploration findings, and "aha moments" from investigation disappear completely when the context window compresses. This skill structures and persists that knowledge immediately.

## Workflow

### Step 1: Identify the Research

If a topic was provided as argument, use it to focus the capture.

If invoked bare, scan the current conversation for research activity:
- Web searches performed (WebSearch, WebFetch calls)
- API calls or curl commands that revealed behavior
- File exploration that uncovered architecture or patterns
- Documentation lookups that clarified usage
- Debugging sessions that revealed root causes

Summarize what was investigated and ask the user to confirm the scope:

> I see research on [topic]. Capturing findings about:
> - [finding 1]
> - [finding 2]
> - [finding 3]
>
> Anything to add or remove?

### Step 2: Structure the Findings

Organize into this format:

```markdown
### YYYY-MM-DD — [Research Topic]

**Sources**: [URLs, files, commands used]
**Confidence**: [Verified | Likely | Speculative]

**Key Findings**:
- Finding 1 — with enough context to be useful later
- Finding 2 — include specific values, versions, parameters
- Finding 3 — note any gotchas or surprising behavior

**Implications**: [How this affects our work, if applicable]
```

#### Confidence Levels

- **Verified**: Tested and confirmed. Code ran, API responded, behavior observed.
- **Likely**: Strong evidence but not directly tested. Documentation says X, multiple sources agree.
- **Speculative**: Inferred from partial evidence. "Probably works this way based on..."

Always tag confidence — future-you needs to know how much to trust these findings.

### Step 3: Route to JD Topic

Read `memory/MEMORY.md` and match the research to a topic:

1. **Exact match**: Research is clearly about an existing topic → append to that file
2. **Adjacent match**: Related to an existing topic but tangential → append with a sub-heading
3. **No match**: New topic area → propose a new JD number and file

For new topics:
- Pick the next available number in the appropriate range (50-59 for infrastructure, 60-70+ for projects)
- Propose: "This doesn't match an existing topic. Create `memory/XX-new-topic.md`?"
- Update `memory/MEMORY.md` index after creating

### Step 4: Write

Append the structured findings to the target memory file. Place under a dated section header so findings accumulate chronologically within each topic.

If the file doesn't exist yet, create it with:

```markdown
# XX — Topic Name

Operational notes for [topic]. See MEMORY.md for index.

### YYYY-MM-DD — [Research Topic]

[findings here]
```

### Step 5: Synthesize to Knowledge Base

If the research produced insights worth preserving for human consumption (not just agent-operational facts), write a synthesized note to the external knowledge base.

**Knowledge base JD path mapping** (set `$FORT_KNOWLEDGE_BASE` to your knowledge base directory):
- `50-59` → `$FORT_KNOWLEDGE_BASE/50 Fort Infrastructure/{XX}.01 {Topic Name}/`
- `60-73` → `$FORT_KNOWLEDGE_BASE/60 Fort Projects/{XX}.01 {Topic Name}/`

**Writing approach:**
- Title by the research question or discovery, not by date
- Synthesize — don't dump raw findings. Explain what was learned and why it matters
- Include implications for future work
- Keep it concise: a few focused paragraphs

**Skip when:** findings are purely agent-operational, trivial, or an existing knowledge base note already covers this.

### Step 6: Confirm

> **Research captured** to `memory/XX-topic.md`
> - [count] findings, confidence: [level]
> - Sources: [brief list]
> - Knowledge base: `{note title}` → `{JD path}` (or "skipped — agent-operational only")

## Relationship to Other Skills

| Skill | Role |
|-------|------|
| `/research` | **Initiates** investigation — spawns agent to go find things |
| `/capture` | **Preserves** findings — structures and saves what was found |
| `/compound` | **Post-work capture** — captures learnings after completing a feature |
| `/note` | **Quick capture** — single thoughts, less structured |
| `/distill` | **Session-end** — extracts learnings broadly, not research-specific |

`/capture` is more structured than `/note` (sources, confidence, implications) and more targeted than `/distill` (specific research vs. general session learnings).

## Relationship to Workflow Intelligence

The `workflow-intelligence.md` rule already prompts for research capture proactively. This skill is the structured version — when the prompt fires and the user says yes, `/capture` is what runs. They work together:

- **Workflow intelligence**: Detects research happened, asks "save these findings?"
- **`/capture`**: Does the actual structured capture

If the user invokes `/capture` directly, skip the detection step — they know what they want to capture.
