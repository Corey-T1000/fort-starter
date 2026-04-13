#!/bin/bash
# Guard: Block Write/Edit to sensitive files (.env, credentials, keys, certs)
# Hard deny — these files should be managed manually
#
# Exit 0 + deny = blocked with explanation
# Matches: Write, Edit

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name')

# Get the file path based on tool type
if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ]; then
    FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
else
    exit 0
fi

# Skip if no file path
if [ -z "$FILE" ]; then
    exit 0
fi

# Extract just the filename for pattern matching
BASENAME=$(basename "$FILE")

# Check against sensitive file patterns
BLOCKED=false
REASON=""

case "$BASENAME" in
    .env)
        BLOCKED=true
        REASON=".env"
        ;;
    .env.*)
        BLOCKED=true
        REASON="$BASENAME"
        ;;
    credentials.json)
        BLOCKED=true
        REASON="credentials.json"
        ;;
    *.pem)
        BLOCKED=true
        REASON="$BASENAME (PEM certificate/key)"
        ;;
    *.key)
        BLOCKED=true
        REASON="$BASENAME (private key)"
        ;;
esac

if [ "$BLOCKED" = true ]; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"deny\",
    \"permissionDecisionReason\": \"Blocked: writing to sensitive file ($REASON). These files should be managed manually, not by Claude.\"
  }
}"
    exit 0
fi

exit 0
