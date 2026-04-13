#!/usr/bin/env bash
# SessionStart hook: Validate critical skills are loadable.
# Catches broken symlinks, missing files, etc. before any work happens.
# Outputs a warning (not a block) so sessions can still start.

# Source Fort environment
_FORT_ENV="${FORT_ROOT:-$HOME/claudes-fort}/.fort-env"
[ -f "$_FORT_ENV" ] && . "$_FORT_ENV"
FORT_ROOT="${FORT_ROOT:-$HOME/claudes-fort}"
FORT_PROJECTS="$HOME/.claude/projects/-$(echo "$FORT_ROOT" | sed 's|^/||; s|/|-|g')"
CRITICAL_SKILLS=(
  "plugins/fort/skills/distill.md"
  "plugins/fort/skills/eod.md"
  "plugins/fort/skills/capture.md"
)

BROKEN=""
for skill in "${CRITICAL_SKILLS[@]}"; do
  FULL="$FORT_ROOT/$skill"
  if [ ! -r "$FULL" ]; then
    BROKEN="${BROKEN}\n  🔴 $skill"
  fi
done

if [ -n "$BROKEN" ]; then
  echo "⚠️  CRITICAL SKILLS BROKEN — distill pipeline will silently fail!${BROKEN}"
  echo ""
  echo "Fix: check symlinks and file permissions in plugins/fort/skills/"
fi
