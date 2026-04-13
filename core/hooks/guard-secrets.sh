#!/bin/bash
# Guard: Block writes containing potential secrets/credentials
# Catches API keys, tokens, and credential patterns in file content
#
# Exit 0 + deny = blocked with explanation
# Matches: Write, Edit

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')

# Get the content being written
if [ "$TOOL" = "Write" ]; then
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""')
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
elif [ "$TOOL" = "Edit" ]; then
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""')
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
else
    exit 0
fi

# Skip check for hook scripts themselves (they mention patterns)
case "$FILE" in
    */.claude/hooks/*) exit 0 ;;
    */node_modules/*) exit 0 ;;
esac

# Patterns that indicate hardcoded secrets
# Each pattern is intentionally specific to reduce false positives
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
    if echo "$CONTENT" | grep -qE "$PATTERN"; then
        MATCH=$(echo "$CONTENT" | grep -oE "$PATTERN" | head -1)
        # Show first 8 chars only
        PREVIEW="${MATCH:0:8}..."

        echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"Blocked: content contains what looks like a hardcoded secret ($PREVIEW) in $FILE. Use environment variables instead.\"
  }
}"
        exit 0
    fi
done

exit 0
