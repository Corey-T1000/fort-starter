#!/bin/bash
# Guard: Detect rsync commands without --dry-run
# Prompts user to add --dry-run to preview changes first
#
# Exit 0 + ask = prompts user for confirmation

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only care about rsync commands
if ! echo "$COMMAND" | grep -qE '(^|\s|&&|\|)rsync\s'; then
    exit 0
fi

# Already has --dry-run or -n flag, nothing to do
if echo "$COMMAND" | grep -qE '\-\-dry-run|\s-[a-zA-Z]*n'; then
    exit 0
fi

echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"rsync command without --dry-run detected. Add --dry-run to preview changes first?\"
  }
}"
exit 0
