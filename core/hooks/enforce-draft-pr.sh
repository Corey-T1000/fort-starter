#!/bin/bash
# Guard: Silently inject --draft into gh pr create commands
# Ensures all PRs are created as drafts first (triggers Vercel preview)
#
# Exit 0 + allow + updatedInput = silently modifies the command

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only care about gh pr create commands
if ! echo "$COMMAND" | grep -qE 'gh\s+pr\s+create'; then
    exit 0
fi

# Already has --draft, nothing to do
if echo "$COMMAND" | grep -qE '\-\-draft'; then
    exit 0
fi

# Inject --draft right after "gh pr create"
FIXED_COMMAND=$(echo "$COMMAND" | sed -E 's/(gh[[:space:]]+pr[[:space:]]+create)/\1 --draft/')

echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"allow\",
    \"updatedInput\": {
      \"command\": $(printf '%s' "$FIXED_COMMAND" | jq -Rs .)
    }
  }
}"
exit 0
