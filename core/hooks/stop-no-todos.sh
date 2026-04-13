#!/bin/bash
# Stop hook: Check for TODO/FIXME comments in modified files
# Ensures loose ends are cleaned up or tracked before ending a session
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

# Get files modified in the working tree (staged + unstaged vs HEAD)
MODIFIED=$(git diff --name-only HEAD 2>/dev/null)

if [ -z "$MODIFIED" ]; then
    # Also check untracked files that are new
    MODIFIED=$(git diff --name-only --cached 2>/dev/null)
fi

if [ -z "$MODIFIED" ]; then
    exit 0
fi

# Filter to supported file extensions
CHECKED_FILES=""
while IFS= read -r file; do
    case "$file" in
        .claude/hooks/*) ;; # Skip hook scripts (they reference TODO/FIXME in comments)
        *.ts|*.tsx|*.js|*.jsx|*.sh|*.py)
            if [ -f "$file" ]; then
                CHECKED_FILES="$CHECKED_FILES $file"
            fi
            ;;
    esac
done <<< "$MODIFIED"

if [ -z "$CHECKED_FILES" ]; then
    exit 0
fi

# Search for TODO/FIXME in those files
TODOS=""
for file in $CHECKED_FILES; do
    MATCHES=$(grep -nE '\bTODO\b|\bFIXME\b' "$file" 2>/dev/null)
    if [ -n "$MATCHES" ]; then
        while IFS= read -r line; do
            TODOS="$TODOS\n  $file:$line"
        done <<< "$MATCHES"
    fi
done

if [ -z "$TODOS" ]; then
    exit 0
fi

echo "{
  \"decision\": \"block\",
  \"reason\": $(printf "Found TODO/FIXME comments in modified files:%s\n\nClean these up or convert to beads issues before finishing." "$TODOS" | jq -Rs .)
}"
exit 0
