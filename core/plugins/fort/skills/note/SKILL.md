---
name: note
description: |
  Use when the user says "note this", "remember this", "save this", "write this down",
  "jot this down", or wants to capture a thought, fact, or observation mid-session.
  Auto-routes to memory, knowledge base, notes, or scratch based on content type.
user_invocable: true
argument-hint: "[content]"
arguments:
  - name: content
    description: "The note content or topic to capture"
    required: false
---

# Note Capture

Single entry point for capturing thoughts, findings, and knowledge. Auto-routes to the right destination based on content type.

## When to Use

- the user says "note this down", "remember this", "save this"
- Mid-conversation insight worth preserving
- Quick thought that needs a home
- Any time content should persist beyond this session

## Routing Rules

Classify the note into one of four destinations:

| Destination | When | Example |
|-------------|------|---------|
| `memory/XX-topic.md` | Operational knowledge about a Fort project — how things work, gotchas, patterns | "The React Query cache invalidates on window focus by default" |
| Knowledge base (`pkm:save-note`) | Durable personal knowledge, learnings, references — things useful beyond Fort | "Strudel uses a mini-notation DSL for rhythm patterns" |
| `notes/` | Meeting notes, conversation summaries, longer-form thinking | "Call with X about Y — key takeaways..." |
| `scratch/` | Temporary thoughts, experiments, things to revisit later | "Idea: what if the dashboard had a mood ring mode" |
| **Daily note** (`41 Daily Notes/`) | Quick thoughts, tasks, observations meant for today's running log | "note: need to follow up on the API integration" |

### Classification Heuristics

- Quick thought, task, observation, or "jot this down" with no clear project home → **daily note**
- Mentions a specific Fort project by name → **memory/**
- General knowledge, learning, technique, reference → **Knowledge base**
- Structured summary of a conversation or meeting → **notes/**
- Half-baked idea, experiment, "what if" → **scratch/**
- When ambiguous between daily note and memory/, prefer **daily note** for thoughts and **memory/** for facts

## Workflow

### Step 1: Get the Content

If content was provided as an argument, use it directly. If invoked bare (`/note`), ask:
- "What do you want to capture?" — simple text input

### Step 2: Classify and Route

Apply the routing rules above. Determine the destination silently.

**For memory/ routing:**
1. Read `memory/MEMORY.md` to find the right JD topic
2. Match content to an existing topic file
3. If no match exists, propose a new JD number following the index conventions

**For knowledge base routing:**
1. Use `pkm:save-note` agent to save to the external knowledge base
2. Suggest a folder path based on the knowledge base's JD structure

**For notes/ routing:**
1. Use a descriptive filename: `notes/YYYY-MM-DD-topic.md`
2. If a file for today's topic already exists, append to it

**For daily note routing:**
1. Path: `${FORT_KNOWLEDGE_BASE}/41 Daily Notes/YYYY-MM-DD.md`
2. If the daily note doesn't exist yet, create it from the template (same as `/bod` Step 2.5)
3. Append under the `## Notes` section
4. Format: `- HH:MM — [content]` (timestamp helps when reviewing the day)

**For scratch/ routing:**
1. Use a short descriptive filename: `scratch/topic.md`
2. Don't overthink organization — scratch is meant to be messy

### Step 3: Write

Write or append the content to the destination. For memory files, add under a dated section:

```markdown
### YYYY-MM-DD — [brief topic]

- Key point 1
- Key point 2
```

For new files, include a clear title and context about why this was captured.

### Step 4: Confirm

Brief confirmation message:

> Saved to `memory/60-example.md` under today's date.

If the classification feels uncertain, add:

> (If this belongs somewhere else, just say — I can move it.)

## Examples

**"note that the external API has a 500 request/month limit on the free tier"**
→ Routes to `memory/60-example.md` (matches a known project domain)

**"note: learned that CSS container queries work in all modern browsers now"**
→ Routes to the knowledge base (general web dev knowledge, not Fort-specific)

**"note down the key points from our architecture discussion"**
→ Routes to `notes/YYYY-MM-DD-architecture.md` (conversation summary)

**"note: what if we used WebGL for the chart animations?"**
→ Routes to `scratch/chart-webgl.md` (experimental idea)
