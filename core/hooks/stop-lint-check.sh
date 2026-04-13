#!/bin/bash
# Stop hook: Run lint check on recently modified files before stopping
# Prevents finishing a session with lint errors in the working tree
#
# Contract: stdin JSON has stop_hook_active (bool) and transcript_path (string)
# To block: output {"decision": "block", "reason": "..."} on stdout
# To allow: exit 0 with no output

INPUT=$(cat)

# Prevent infinite loops — if stop hook is already active, exit immediately
ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$ACTIVE" = "true" ]; then
    exit 0
fi

# Find recently modified source files (last 5 minutes)
RECENT_FILES=$(find . -maxdepth 6 \
    \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.next/*" \
    -not -path "*/dist/*" \
    -not -path "*/.claude/*" \
    -newer /tmp/.stop-lint-check-marker 2>/dev/null)

# Create the marker file if it doesn't exist (5 min window)
if [ ! -f /tmp/.stop-lint-check-marker ]; then
    touch -t "$(date -v-5M '+%Y%m%d%H%M.%S' 2>/dev/null || date -d '5 minutes ago' '+%Y%m%d%H%M.%S' 2>/dev/null)" /tmp/.stop-lint-check-marker 2>/dev/null
    # Retry with find -mmin if touch fails
    RECENT_FILES=$(find . -maxdepth 6 \
        \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
        -not -path "*/node_modules/*" \
        -not -path "*/.next/*" \
        -not -path "*/dist/*" \
        -not -path "*/.claude/*" \
        -mmin -5 2>/dev/null)
fi

# Fallback: use -mmin directly (more portable)
if [ -z "$RECENT_FILES" ]; then
    RECENT_FILES=$(find . -maxdepth 6 \
        \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) \
        -not -path "*/node_modules/*" \
        -not -path "*/.next/*" \
        -not -path "*/dist/*" \
        -not -path "*/.claude/*" \
        -mmin -5 2>/dev/null)
fi

# No recent files — nothing to lint
if [ -z "$RECENT_FILES" ]; then
    exit 0
fi

# Check if project has a lint script in package.json
if [ ! -f "package.json" ]; then
    exit 0
fi

HAS_LINT=$(jq -r '.scripts.lint // empty' package.json 2>/dev/null)
if [ -z "$HAS_LINT" ]; then
    exit 0
fi

# Run lint and capture output
LINT_OUTPUT=$(pnpm lint 2>&1 | tail -5)
LINT_EXIT=$?

if [ $LINT_EXIT -ne 0 ]; then
    echo "{
  \"decision\": \"block\",
  \"reason\": $(printf "Lint errors found in recently modified files. Please fix these before finishing:\n%s" "$LINT_OUTPUT" | jq -Rs .)
}"
    exit 0
fi

# Lint passed — allow stop
exit 0
