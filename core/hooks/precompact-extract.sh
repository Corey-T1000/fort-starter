#!/bin/bash
# PreCompact hook: Extract decisions and insights from transcript before compaction
# Saves valuable context that would otherwise be lost during memory compaction
#
# Reads transcript_path from stdin JSON, scans for decision-language patterns,
# writes extracted lines to notes/compaction-extracts/

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // ""')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    echo "No transcript found, skipping extraction."
    exit 0
fi

# Source Fort environment
_FORT_ENV="${FORT_ROOT:-$HOME/claudes-fort}/.fort-env"
[ -f "$_FORT_ENV" ] && . "$_FORT_ENV"
FORT_ROOT="${FORT_ROOT:-$HOME/claudes-fort}"
FORT_PROJECTS="$HOME/.claude/projects/-$(echo "$FORT_ROOT" | sed 's|^/||; s|/|-|g')"

EXTRACT_DIR="$FORT_ROOT/notes/compaction-extracts"
mkdir -p "$EXTRACT_DIR"

# Search for decision-language and insight patterns
PATTERNS='decided to|chose |went with|approach:|trade-off|tradeoff|because |instead of|lesson:|learned:|mistake:|insight:|pattern:'

# Extract matching lines, deduplicate, limit to 30
MATCHES=$(grep -iE "$PATTERNS" "$TRANSCRIPT" 2>/dev/null \
    | grep -v '^\s*$' \
    | sed 's/^[[:space:]]*//' \
    | sort -u \
    | head -30)

COUNT=$(echo "$MATCHES" | grep -c '.')

if [ "$COUNT" -eq 0 ] || [ -z "$MATCHES" ]; then
    echo "No decisions or insights found in transcript."
    exit 0
fi

# Generate filename with timestamp
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
DATE_DISPLAY=$(date '+%Y-%m-%d %H:%M')
FILENAME="${TIMESTAMP}.md"
FILEPATH="${EXTRACT_DIR}/${FILENAME}"

# Build the markdown file
{
    echo "# Compaction Extract — ${DATE_DISPLAY}"
    echo ""
    echo "## Decisions & Insights"
    echo ""
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            echo "- $line"
        fi
    done <<< "$MATCHES"
} > "$FILEPATH"

echo "Extracted ${COUNT} insights to notes/compaction-extracts/${FILENAME}"
exit 0
