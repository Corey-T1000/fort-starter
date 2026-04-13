#!/bin/bash
# Guard: Catch bash commands containing literal API keys/tokens
# Prompts user to use $ENV_VAR references instead of hardcoded secrets
#
# Exit 0 + ask = prompts user for confirmation

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Skip if empty command
if [ -z "$COMMAND" ]; then
    exit 0
fi

# Skip commands operating on hook scripts themselves (they mention patterns)
if echo "$COMMAND" | grep -qE '\.claude/hooks/'; then
    exit 0
fi

# Secret patterns — same as guard-secrets.sh but applied to bash commands
PATTERNS=(
    'sk-[a-zA-Z0-9]{20,}'           # OpenAI/Anthropic API keys
    'AKIA[0-9A-Z]{16}'              # AWS access keys
    'ghp_[a-zA-Z0-9]{36}'           # GitHub personal tokens
    'gho_[a-zA-Z0-9]{36}'           # GitHub OAuth tokens
    'xoxb-[0-9]+-[0-9]+'            # Slack bot tokens
    'xoxp-[0-9]+-[0-9]+'            # Slack user tokens
    'sk_live_[a-zA-Z0-9]{24,}'      # Stripe live keys
    'rk_live_[a-zA-Z0-9]{24,}'      # Stripe restricted keys
    'ya29\.[a-zA-Z0-9_-]+'          # Google OAuth tokens
    'AIza[0-9A-Za-z_-]{35}'         # Google API keys
)

for PATTERN in "${PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qE "$PATTERN"; then
        MATCH=$(echo "$COMMAND" | grep -oE "$PATTERN" | head -1)
        # Show first 8 chars only
        PREVIEW="${MATCH:0:8}..."

        echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"Command contains what appears to be a literal secret ($PREVIEW). Consider using \$ENV_VAR reference instead.\"
  }
}"
        exit 0
    fi
done

exit 0
