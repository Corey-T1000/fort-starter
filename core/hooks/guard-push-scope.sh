#!/bin/bash
# Guard: Flag potentially unrelated changes before pushing
# Shows what's about to be pushed and warns if commits touch
# too many unrelated areas (sign of branch contamination)
#
# Exit 0 + ask = prompts user for confirmation

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only check git push commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+push'; then
    exit 0
fi

REMOTE=$(echo "$COMMAND" | grep -oP 'git\s+push\s+\K\S+' || echo "origin")
BRANCH=$(git branch --show-current 2>/dev/null)

if [ -z "$BRANCH" ]; then
    exit 0
fi

# Get commits ahead of remote (what we're about to push)
AHEAD=$(git rev-list --count "${REMOTE}/${BRANCH}..HEAD" 2>/dev/null)

# If no remote tracking or nothing to push, skip
if [ -z "$AHEAD" ] || [ "$AHEAD" -eq 0 ]; then
    exit 0
fi

# Get the file stat summary for commits being pushed
STAT=$(git diff --stat "${REMOTE}/${BRANCH}..HEAD" 2>/dev/null | tail -1)
FILES_CHANGED=$(echo "$STAT" | grep -oP '^\s*\K\d+' || echo "0")

# Get unique top-level directories touched
DIRS=$(git diff --name-only "${REMOTE}/${BRANCH}..HEAD" 2>/dev/null | cut -d'/' -f1-2 | sort -u | wc -l | tr -d ' ')

# Build a short summary of what's being pushed
COMMIT_LOG=$(git log --oneline "${REMOTE}/${BRANCH}..HEAD" 2>/dev/null | head -5)
if [ "$AHEAD" -gt 5 ]; then
    COMMIT_LOG="${COMMIT_LOG}\n  ... and $((AHEAD - 5)) more"
fi

# Flag if scope looks unusually broad
if [ "$FILES_CHANGED" -gt 30 ] || [ "$DIRS" -gt 8 ]; then
    REASON="Large push scope: ${AHEAD} commit(s), ${FILES_CHANGED} files across ${DIRS} directories. This might include unrelated changes.\n\nCommits:\n${COMMIT_LOG}\n\nSummary: ${STAT}"
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": $(echo "$REASON" | jq -Rs .)
  }
}"
    exit 0
fi

exit 0
