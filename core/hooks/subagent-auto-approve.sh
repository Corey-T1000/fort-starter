#!/bin/bash
# Auto-approve safe tool calls from subagents.
# Layered ON TOP of existing guards — those still fire independently.
# This hook runs in PreToolUse, before the permission prompt.
#
# Auto-approves when ALL of:
# - Caller is a subagent (agent_type != "main")
# - Tool is in the safe list (Read, Grep, Glob, or safe Bash)
# - For Bash: command doesn't match dangerous patterns

set -euo pipefail

INPUT=$(cat)

# Only act on subagent calls
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // "main"' 2>/dev/null)
if [ "$AGENT_TYPE" = "main" ] || [ -z "$AGENT_TYPE" ]; then
  exit 0  # Not a subagent — let normal flow handle it
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

case "$TOOL_NAME" in
  Read|Grep|Glob)
    # Auto-approve read-only tools for subagents
    echo '{"hookSpecificOutput":{"permissionDecision":"approve","permissionDecisionReason":"subagent read-only auto-approve"}}'
    exit 0
    ;;
  Bash)
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

    # Deny list — these always need human approval, even from subagents
    DANGEROUS='(ssh |rm -rf|git push|git reset --hard|git checkout -- |deploy|rsync |scp |curl.*-X (POST|PUT|DELETE|PATCH))'
    if echo "$COMMAND" | grep -qE "$DANGEROUS"; then
      exit 0  # Don't approve — let normal permission flow handle it
    fi

    # Auto-approve safe bash commands from subagents
    echo '{"hookSpecificOutput":{"permissionDecision":"approve","permissionDecisionReason":"subagent safe-bash auto-approve"}}'
    exit 0
    ;;
  Write|Edit)
    # Auto-approve file writes for subagents (existing guards like guard-secrets still fire separately)
    echo '{"hookSpecificOutput":{"permissionDecision":"approve","permissionDecisionReason":"subagent file-write auto-approve"}}'
    exit 0
    ;;
  *)
    exit 0  # Unknown tool — let normal flow handle it
    ;;
esac
