#!/bin/bash
# Guard: Confirm before deploying to remote server or running deploy scripts.
# Catches: deploy.sh, rsync to a remote IP, ssh + docker on a remote, docker compose -d.
#
# Configure via env (set in your .fort-env):
#   FORT_REMOTE_IP        — your deploy target IP/hostname (e.g. 192.168.1.42)
#   FORT_REMOTE_HOSTNAME  — your deploy target SSH alias (e.g. my-server)
#   FORT_DEPLOY_ALLOWLIST — pipe-separated project names to label in the prompt
#                           (e.g. "home-dashboard|api-gateway")
#
# Exit 0 + ask = prompts user for confirmation.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

REMOTE_IP="${FORT_REMOTE_IP:-}"
REMOTE_HOST="${FORT_REMOTE_HOSTNAME:-remote-server}"
ALLOWLIST="${FORT_DEPLOY_ALLOWLIST:-}"

# Build the deploy-pattern regex dynamically so users without FORT_REMOTE_IP
# still catch the generic patterns (deploy.sh, ssh-to-host docker, compose -d).
PATTERN="(deploy\.sh|rsync.*${REMOTE_HOST}|ssh\s+${REMOTE_HOST}.*docker|docker\s+compose.*up.*-d)"
if [ -n "$REMOTE_IP" ]; then
    ESCAPED_IP=$(echo "$REMOTE_IP" | sed 's/\./\\./g')
    PATTERN="(deploy\.sh|rsync.*${REMOTE_HOST}|rsync.*${ESCAPED_IP}|ssh\s+${REMOTE_HOST}.*docker|docker\s+compose.*up.*-d)"
fi

if echo "$COMMAND" | grep -qE "$PATTERN"; then
    TARGET="$REMOTE_HOST"
    # Label by project if it matches the user's allowlist.
    if [ -n "$ALLOWLIST" ] && echo "$COMMAND" | grep -qE "$ALLOWLIST"; then
        MATCHED=$(echo "$COMMAND" | grep -oE "$ALLOWLIST" | head -1)
        TARGET="$MATCHED on $REMOTE_HOST"
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
