---
name: compound
description: |
  Capture learnings after completing work. Use when finishing a feature, fixing a bug,
  or after any meaningful development session. Triggers: 'what did we learn', 'compound
  this', 'capture learnings', 'retrospective'.
user_invocable: true
context: fork
agent: general-purpose
model: sonnet
---

# Compound — Capture & Compound Learnings

After completing work, run this skill to extract and persist learnings.

## Process

### Step 1: Reflect
Ask the user three questions using AskUserQuestion (present as multiple choice with an "Other" option):

1. **What problem did we solve?**
   Options based on what was done in the session (infer from context, offer 3-4 specific descriptions)

2. **What approach worked?**
   Options: "First approach worked", "Had to iterate", "Found an unexpected solution", "Combined multiple approaches"

3. **What should we do differently next time?**
   Options: "Nothing — went smoothly", "Research more upfront", "Break into smaller steps", "Test earlier", "Different tool/library choice"

### Step 2: Write to notes/solutions/
Create a markdown file at `notes/solutions/{topic-slug}.md` with this format:

```markdown
# {Topic Title}

**Date**: {YYYY-MM-DD}
**Problem**: {answer to Q1}
**Approach**: {answer to Q2}
**Lesson**: {answer to Q3}

## Context
{Brief description of what was built/fixed, key files involved}

## Key Decisions
{Any notable technical decisions made during the work}

## Gotchas
{Things that tripped us up or would trip someone up in the future}
```

If the file already exists (same topic-slug), append a new dated section rather than overwriting.

### Step 3: Write to Fort Memory
Queue the learning for background memory sync (same pattern as `/distill`):
```bash
QUEUE_DIR="$HOME/.claude/projects/-Users-$(whoami)-$(basename "${FORT_ROOT:-claudes-fort}")/memory/.distill-queue"
mkdir -p "$QUEUE_DIR"
QUEUE_FILE="$QUEUE_DIR/$(date +%Y%m%d-%H%M%S)-compound.jsonl"

cat > "$QUEUE_FILE" <<QEOF
{
  "session_id": "$(cat "$HOME/.claude/projects/-Users-$(whoami)-$(basename "${FORT_ROOT:-claudes-fort}")/memory/.session/session-id" 2>/dev/null || echo 'unknown')",
  "date": "$(date +%Y-%m-%d)",
  "facts": [{"topic": "{topic}", "fact": "{approach + lesson summary}"}],
  "memory_files_updated": [],
  "knowledge_base_topics": []
}
QEOF

jq empty "$QUEUE_FILE" 2>/dev/null || echo "WARNING: Queue file may be malformed"
```

The fact will be saved to memory on next session start via `distill-background`.

### Step 4: Summary
Output a brief confirmation: what was saved, where, and suggest reviewing `notes/solutions/` periodically for patterns.
