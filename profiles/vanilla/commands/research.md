---
name: research
description: |
  This skill should be used when the user asks to "research this", "investigate",
  "dig into", "go find out about", "look into", "what do we know about", "learn about",
  or wants deep exploration of a topic without filling the context window.
user_invocable: true
context: fork
agent: Explore
arguments:
  - name: topic
    description: What to research (required)
    required: true
  - name: mode
    description: "Research mode: web, codebase, docs, or all (default: all)"
    required: false
  - name: depth
    description: "Research depth: quick, standard, or deep (default: standard)"
    required: false
---

# Research

Spawn a background research agent that investigates a topic deeply, writes structured findings to `notes/research/`, saves key facts to Fort Memory, and returns only a brief summary to keep this context window light.

## How to Use This Skill

When this skill is triggered, you should:

1. **Parse the request** to extract:
   - `topic` (required): The subject to research
   - `mode` (optional): `web` | `codebase` | `docs` | `all` (default: `all`)
   - `depth` (optional): `quick` | `standard` | `deep` (default: `standard`)

2. **Announce**: Tell the user what you're researching and at what depth

3. **Spawn the agent**: Use the Task tool to launch the `fort:researcher` agent:
   ```
   Task tool:
     subagent_type: general-purpose
     run_in_background: true
     prompt: |
       You are a research agent. Read your full instructions from:
       ${FORT_ROOT}/plugins/fort/agents/researcher.md

       Research topic: <topic>
       Mode: <mode>
       Depth: <depth>

       Execute the research process described in your instructions.
   ```

4. **Report back**: When the agent completes, relay its summary to the user and mention:
   - The file path where full findings are saved
   - How many facts were saved to Fort Memory
   - Any open questions worth pursuing

## Deep Mode

When `depth` is `deep`, the research agent runs iterative passes instead of a single shot:

1. **Pass 1**: Initial broad research across all specified modes
2. **Pass 2+**: Evaluate coverage gaps from prior passes, refine search terms, target missing areas
3. Each iteration appends a `### Pass N` section to the same research file with findings and remaining gaps
4. **Stop condition**: Two consecutive passes yield no new substantial facts (diminishing returns)
5. **Hard cap**: Maximum 5 passes to prevent runaway research

The agent reads its own prior output between passes to avoid repeating searches and to identify what's still missing. The final summary notes how many passes were needed and overall coverage assessment.

## Examples

- `/research "SQLite WAL mode"` → researches with all modes, standard depth
- `/research "React Server Components" --mode web --depth deep` → web-only deep dive
- `/research "auth middleware" --mode codebase` → codebase investigation only
- "dig into how Turso replication works" → triggers this skill, mode: all, depth: standard

## After Research

Suggest follow-up actions:
- "Want me to dig deeper into any of these findings?"
- "I can recall these facts later with `fort-memory recall <topic>`"
- "There are open questions — want me to research those next?"
