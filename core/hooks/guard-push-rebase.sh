#!/bin/bash
# Guard: Check if branch needs rebase before pushing
# Fetches remote and compares — denies push if local is behind
#
# Exit 0 + deny = blocked with explanation

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only check git push commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+push'; then
    exit 0
fi

# Extract the remote and branch from the push command, or use defaults
REMOTE=$(echo "$COMMAND" | grep -oP 'git\s+push\s+\K\S+' || echo "origin")
BRANCH=$(git branch --show-current 2>/dev/null)

if [ -z "$BRANCH" ]; then
    exit 0  # Detached HEAD, let git handle it
fi

# Fetch silently to check remote state
git fetch "$REMOTE" "$BRANCH" --quiet 2>/dev/null

# Check if we're behind the remote
BEHIND=$(git rev-list --count "HEAD..${REMOTE}/${BRANCH}" 2>/dev/null)

if [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ]; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"Branch '${BRANCH}' is ${BEHIND} commit(s) behind ${REMOTE}/${BRANCH}. Pull or rebase first: git pull --rebase ${REMOTE} ${BRANCH}\"
  }
}"
    exit 0
fi

exit 0
