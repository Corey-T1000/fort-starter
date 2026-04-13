#!/bin/bash
# Guard: Confirm before deploying to remote server or running deploy scripts
# Catches: deploy.sh, rsync to remote-server, docker compose on remote-server
#
# Exit 0 + ask = prompts user for confirmation

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Patterns that indicate deployment actions
if echo "$COMMAND" | grep -qE '(deploy\.sh|rsync.*remote-server|rsync.*192\.168\.50\.176|ssh\s+remote-server.*docker|docker\s+compose.*up.*-d)'; then
    # Extract a short description of what's being deployed
    TARGET="remote server"
    if echo "$COMMAND" | grep -q 'home-dashboard'; then
        TARGET="Home Dashboard on remote server"
    elif echo "$COMMAND" | grep -q 'fort-mail'; then
        TARGET="Fort Mail on remote server"
    fi

    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"Deploy to $TARGET detected. This affects shared infrastructure. Confirm to proceed.\"
  }
}"
    exit 0
fi

exit 0
