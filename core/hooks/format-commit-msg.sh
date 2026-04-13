#!/bin/bash
# Guard: Check git commit messages for conventional commits format
# Expected: feat|fix|chore|docs|style|refactor|test|perf|ci|build|revert(scope)?: description
#
# Exit 0 + ask = prompts user for confirmation if message doesn't match

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only check git commit commands with -m
if ! echo "$COMMAND" | grep -qE 'git\s+commit\s+.*-m\s'; then
    exit 0
fi

# Extract the commit message — handle both direct and heredoc styles
# Heredoc style: git commit -m "$(cat <<'EOF' ... EOF )"
if echo "$COMMAND" | grep -qE "cat\s+<<"; then
    # Heredoc: grab the first non-empty line after the heredoc marker
    MSG=$(echo "$COMMAND" | sed -n '/<<.*EOF/,/EOF/{//!p;}' | sed '/^\s*$/d' | head -1 | sed 's/^[[:space:]]*//')
else
    # Direct style: git commit -m "message" or git commit -m 'message'
    # Try double quotes first, then single quotes (macOS-compatible, no grep -P)
    MSG=$(echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    if [ -z "$MSG" ]; then
        MSG=$(echo "$COMMAND" | sed -n "s/.*-m[[:space:]]*'\([^']*\)'.*/\1/p" | head -1)
    fi
    if [ -z "$MSG" ]; then
        # Unquoted or other format — grab what follows -m
        MSG=$(echo "$COMMAND" | sed -n 's/.*-m[[:space:]]*\([^[:space:]"'"'"'][^[:space:]]*\).*/\1/p' | head -1)
    fi
fi

# If we couldn't extract a message, skip
if [ -z "$MSG" ]; then
    exit 0
fi

# Check first line against conventional commits pattern
FIRST_LINE=$(echo "$MSG" | head -1)
if echo "$FIRST_LINE" | grep -qE '^(feat|fix|chore|docs|style|refactor|test|perf|ci|build|revert)(\(.+\))?!?: .+'; then
    exit 0
fi

echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"Commit message doesn't follow conventional commits format (type: description). Expected: feat|fix|chore|docs|style|refactor|test|perf|ci|build|revert. Proceed anyway?\"
  }
}"
exit 0
