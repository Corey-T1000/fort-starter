#!/bin/bash
# Stop hook: Auto-run /distill before session close
# Blocks until /distill captures all current changes.
# Uses timestamp-based staleness: if files changed after last distill, blocks again.
# Skips trivial sessions (under 2 minutes or no meaningful file changes).
#
# Contract: stdin JSON has stop_hook_active (bool)
# To block: output {"decision": "block", "reason": "..."} on stdout
# To allow: exit 0 with no output

INPUT=$(cat)

# Prevent infinite loops — if stop hook is already active, exit immediately
ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$ACTIVE" = "true" ]; then
    exit 0
fi

# Source Fort environment
_FORT_ENV="${FORT_ROOT:-$HOME/claudes-fort}/.fort-env"
[ -f "$_FORT_ENV" ] && . "$_FORT_ENV"
FORT_ROOT="${FORT_ROOT:-$HOME/claudes-fort}"
FORT_PROJECTS="$HOME/.claude/projects/-$(echo "$FORT_ROOT" | sed 's|^/||; s|/|-|g')"

MEMORY_DIR="${FORT_PROJECTS}/memory"
MARKER="${MEMORY_DIR}/.distill-ran"
# Active worktree paths added temporarily — see beads issue for proper fix
NOISE_PATTERN='\.beads/|\.claude/|memory/|\.distill|logs/|node_modules/|nano-banana-renders/|parking-lot\.md|plugins/fort/skills/distill\.md|projects/home-bud/'

# Duration gate: skip trivial sessions under 2 minutes
START_TIME_FILE="${MEMORY_DIR}/.session/start-time"
if [ -f "$START_TIME_FILE" ]; then
    START_TS=$(TZ=UTC0 date -j -f "%Y-%m-%dT%H:%M:%SZ" "$(cat "$START_TIME_FILE")" +%s 2>/dev/null)
    NOW_TS=$(date +%s)
    if [ -n "$START_TS" ] && [ $(( NOW_TS - START_TS )) -lt 120 ]; then
        exit 0
    fi
fi

# Collect meaningful changes new to this session
BASELINE="${MEMORY_DIR}/.session/baseline-files"
CURRENT_FILES=$(mktemp)
{
  git -C "$FORT_ROOT" diff --name-only HEAD 2>/dev/null
  git -C "$FORT_ROOT" ls-files --others --exclude-standard 2>/dev/null
} | sort -u > "$CURRENT_FILES"

if [ -f "$BASELINE" ]; then
    NEW_FILES=$(comm -13 "$BASELINE" "$CURRENT_FILES" | grep -vE "$NOISE_PATTERN")
else
    # No baseline means SessionStart hook didn't fire (cmux, crash, /tmp cleared).
    # Regenerate baseline now so future stop checks work, and allow this close —
    # we can't distinguish session work from pre-existing dirt without a baseline.
    cp "$CURRENT_FILES" "$BASELINE" 2>/dev/null
    mkdir -p "$(dirname "$BASELINE")" && cp "$CURRENT_FILES" "$BASELINE" 2>/dev/null
    NEW_FILES=""
fi
rm -f "$CURRENT_FILES"

# No meaningful changes this session — allow close
if [ -z "$NEW_FILES" ]; then
    exit 0
fi

FILE_COUNT=$(echo "$NEW_FILES" | grep -c '.' 2>/dev/null || echo "0")

# Verify distill skill is actually loadable before telling Claude to run it
DISTILL_SKILL="$FORT_ROOT/plugins/fort/skills/distill.md"
if [ ! -r "$DISTILL_SKILL" ]; then
    echo "{
      \"decision\": \"block\",
      \"reason\": \"🔴 DISTILL SKILL IS BROKEN — file missing or unreadable at plugins/fort/skills/distill.md. ${FILE_COUNT} files modified. To close anyway: bash .claude/hooks/emergency-distill.sh\"
    }"
    exit 0
fi

# If distill never ran, block
if [ ! -f "$MARKER" ]; then
    echo "{
      \"decision\": \"block\",
      \"reason\": \"🔴 STOP — Do NOT close. ${FILE_COUNT} files modified. Run /distill IMMEDIATELY as your very next action. Invoke the Skill tool with skill='distill' RIGHT NOW before any text output.\"
    }"
    exit 0
fi

# Distill ran — refresh baseline to absorb external changes (worktree agents,
# background tasks) that appeared mid-session but aren't from this conversation.
if [ "$MARKER" -nt "$BASELINE" ]; then
    CURRENT_FILES=$(mktemp)
    {
        git -C "$FORT_ROOT" diff --name-only HEAD 2>/dev/null
        git -C "$FORT_ROOT" ls-files --others --exclude-standard 2>/dev/null
    } | sort -u > "$CURRENT_FILES"
    cp "$CURRENT_FILES" "$BASELINE"
    NEW_FILES=$(comm -13 "$BASELINE" "$CURRENT_FILES" | grep -vE "$NOISE_PATTERN")
    rm -f "$CURRENT_FILES"
    if [ -z "$NEW_FILES" ]; then
        exit 0
    fi
fi

# Check if any remaining file changed AFTER the marker (stale distill)
STALE=""
while IFS= read -r f; do
    [ -z "$f" ] && continue
    FULL="$FORT_ROOT/$f"
    if [ -f "$FULL" ] && [ "$FULL" -nt "$MARKER" ]; then
        STALE="$f"
        break
    fi
done <<< "$NEW_FILES"

if [ -n "$STALE" ]; then
    echo "{
      \"decision\": \"block\",
      \"reason\": \"🔴 STOP — Do NOT close. Files changed since last /distill (e.g. $STALE). Run /distill IMMEDIATELY as your very next action. Invoke the Skill tool with skill='distill' RIGHT NOW before any text output.\"
    }"
    exit 0
fi

# Dolt writes are now deferred to distill-background (runs on next session start).
# No freshness check needed — memory files are the source of truth.

# Distill is fresh for all current changes — allow close
exit 0
