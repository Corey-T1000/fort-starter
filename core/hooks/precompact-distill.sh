#!/bin/bash
# PreCompact hook: Run /distill before context compaction
# Blocks compaction until Claude runs /distill, preserving learnings while
# full context is still available.
#
# Uses timestamp-based staleness: if any meaningful file changed AFTER
# the last /distill run, blocks again — even if distill already ran
# earlier in the session. Fixes the "distill once, lose everything after" bug.

INPUT=$(cat)

# Source Fort environment
_FORT_ENV="${FORT_ROOT:-$HOME/claudes-fort}/.fort-env"
[ -f "$_FORT_ENV" ] && . "$_FORT_ENV"
FORT_ROOT="${FORT_ROOT:-$HOME/claudes-fort}"
FORT_PROJECTS="$HOME/.claude/projects/-$(echo "$FORT_ROOT" | sed 's|^/||; s|/|-|g')"

MARKER="${FORT_PROJECTS}/memory/.distill-ran"
NOISE='\.claude/|memory/|\.distill|logs/|node_modules/|nano-banana-renders/'

# Collect meaningful changes (tracked diffs + untracked files)
CHANGED=$({
    git -C "$FORT_ROOT" diff --name-only HEAD 2>/dev/null
    git -C "$FORT_ROOT" ls-files --others --exclude-standard 2>/dev/null
} | grep -vE "$NOISE")

# No meaningful changes at all — allow compaction
if [ -z "$CHANGED" ]; then
    exit 0
fi

# Verify distill skill is actually loadable
DISTILL_SKILL="$FORT_ROOT/plugins/fort/skills/distill.md"
if [ ! -r "$DISTILL_SKILL" ]; then
    echo "{
      \"decision\": \"block\",
      \"reason\": \"🔴 DISTILL SKILL IS BROKEN — file missing or unreadable at plugins/fort/skills/distill.md. To proceed anyway: bash .claude/hooks/emergency-distill.sh\"
    }"
    exit 0
fi

# If distill never ran this session, block
if [ ! -f "$MARKER" ]; then
    echo "{
      \"decision\": \"block\",
      \"reason\": \"🔴 STOP — Do NOT respond to the user. Run /distill IMMEDIATELY as your very next action. Knowledge is being lost. Invoke the Skill tool with skill='distill' RIGHT NOW before any text output.\"
    }"
    exit 0
fi

# Distill ran — check if any file changed AFTER the marker (stale distill)
STALE=""
while IFS= read -r f; do
    [ -z "$f" ] && continue
    FULL="$FORT_ROOT/$f"
    if [ -f "$FULL" ] && [ "$FULL" -nt "$MARKER" ]; then
        STALE="$f"
        break
    fi
done <<< "$CHANGED"

if [ -n "$STALE" ]; then
    echo "{
      \"decision\": \"block\",
      \"reason\": \"🔴 STOP — Do NOT respond to the user. Files changed since last /distill (e.g. $STALE). Run /distill IMMEDIATELY as your very next action. Invoke the Skill tool with skill='distill' RIGHT NOW before any text output.\"
    }"
    exit 0
fi

# Distill is fresh — allow compaction
exit 0
