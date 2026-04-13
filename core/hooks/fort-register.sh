#!/bin/bash
# Fort Mail Auto-Registration Hook
# Registers this Claude session with Fort Mail on startup
#
# Fort Mail runs on the remote server
# Override with FORT_MAIL_URL env var if needed

# Source Fort environment
_FORT_ENV="${FORT_ROOT:-$HOME/claudes-fort}/.fort-env"
[ -f "$_FORT_ENV" ] && . "$_FORT_ENV"
FORT_ROOT="${FORT_ROOT:-$HOME/claudes-fort}"
FORT_PROJECTS="$HOME/.claude/projects/-$(echo "$FORT_ROOT" | sed 's|^/||; s|/|-|g')"

# SECURITY: Prefer env var over hardcoded IP. Set FORT_MAIL_URL in ~/.zshrc for portability.
if [ -z "$FORT_MAIL_URL" ]; then
    echo "Warning: FORT_MAIL_URL not set. Falling back to default. Add to ~/.zshrc: export FORT_MAIL_URL=\"http://${FORT_REMOTE_IP:-127.0.0.1}:8080\""
    FORT_MAIL_URL="http://${FORT_REMOTE_IP:-127.0.0.1}:8080"
fi

# Auth header for Fort Mail API
AUTH_HEADER=""
if [ -n "$FORT_MAIL_API_KEY" ]; then
    AUTH_HEADER="Authorization: Bearer $FORT_MAIL_API_KEY"
fi

FORT_DIR="$FORT_ROOT"

# Generate a meaningful agent name
# Format: {project}-{short-id}
# Examples: claudes-fort-a3f2, web-b7c1, fort-ui-d4e5

# Get project name from current directory
PROJECT_DIR=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Clean up project name (lowercase, remove special chars, max 15 chars)
PROJECT_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | cut -c1-15)

# Get short unique suffix (4 chars)
if [ -n "$CLAUDE_CONVERSATION_ID" ]; then
    SHORT_ID="${CLAUDE_CONVERSATION_ID: -4}"
else
    SHORT_ID=$(printf '%04x' $RANDOM)
fi

# Build agent name
SESSION_NAME="${PROJECT_NAME}-${SHORT_ID}"

# Check if Fort Mail is running (status endpoint is unauthenticated)
if ! curl -s "${FORT_MAIL_URL}/api/status" &>/dev/null; then
    # Fort Mail not running - silently skip
    exit 0
fi

# Register this session as an agent
CURL_ARGS=(-s -X POST "${FORT_MAIL_URL}/api/agents" -H "Content-Type: application/json")
if [ -n "$AUTH_HEADER" ]; then
    CURL_ARGS+=(-H "$AUTH_HEADER")
fi
RESPONSE=$(curl "${CURL_ARGS[@]}" \
    -d "{\"name\": \"$SESSION_NAME\", \"program\": \"claude-code\"}" 2>/dev/null)

if echo "$RESPONSE" | grep -q '"name"'; then
    AGENT_NAME=$(echo "$RESPONSE" | grep -o '"name":"[^"]*"' | cut -d'"' -f4)

    # Store agent name for later use
    echo "$AGENT_NAME" > "${FORT_DIR}/.current-agent"

    echo "Fort Mail: $AGENT_NAME"
fi
