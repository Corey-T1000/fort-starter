#!/bin/bash
# Guard: Catch broad git add commands that could stage secrets
# Blocks: git add ., git add -A, git add --all
# Allows: git add <specific-file>
#
# Exit 0 + ask = prompts user for confirmation

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only check git add commands
if ! echo "$COMMAND" | grep -qE '^\s*git\s+add'; then
    exit 0
fi

# Block broad staging patterns
if echo "$COMMAND" | grep -qE 'git\s+add\s+(-A|--all|\.\s*$|\.$)'; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"Broad git add detected. This could stage .env files, credentials, or large binaries. Consider adding specific files instead.\"
  }
}"
    exit 0
fi

exit 0
