#!/usr/bin/env bash
# Fort Memory: record session start time for SessionEnd hook.
# Runs on SessionStart alongside fort-register.sh.

# Source Fort environment
_FORT_ENV="${FORT_ROOT:-$HOME/claudes-fort}/.fort-env"
[ -f "$_FORT_ENV" ] && . "$_FORT_ENV"
FORT_ROOT="${FORT_ROOT:-$HOME/claudes-fort}"
FORT_PROJECTS="$HOME/.claude/projects/-$(echo "$FORT_ROOT" | sed 's|^/||; s|/|-|g')"

# Session markers in project-local storage (survives sandbox scoping and /tmp cleanup)
MARKER_DIR="${FORT_PROJECTS}/memory/.session"
mkdir -p "$MARKER_DIR"

# Ensure custom tools are on PATH regardless of how Claude Code was launched (cmux, etc.)
export PATH="$FORT_ROOT/bin:$PATH"

# Write session start timestamp + generate a session ID
SESSION_ID="session-$(date +%Y-%m-%d)-$(openssl rand -hex 3)"
echo "$SESSION_ID" > "$MARKER_DIR/session-id"
date -u +"%Y-%m-%dT%H:%M:%SZ" > "$MARKER_DIR/start-time"
git -C "$FORT_ROOT" rev-parse HEAD > "$MARKER_DIR/start-commit" 2>/dev/null

# Snapshot dirty files at session start so stop hook can detect only new changes
{
  git -C "$FORT_ROOT" diff --name-only HEAD 2>/dev/null
  git -C "$FORT_ROOT" ls-files --others --exclude-standard 2>/dev/null
} | sort -u > "$MARKER_DIR/baseline-files"

# Clean up distill markers from previous session
# The stop hook checks .distill-ran to avoid nagging; clearing it here ensures
# each session gets its own distill check.
MEMORY_DIR="${FORT_PROJECTS}/memory"
rm -f "${MEMORY_DIR}/.distill-ran"

# Drain any pending distill queue from previous session (background Dolt sync)
QUEUE_DIR="${FORT_PROJECTS}/memory/.distill-queue"
PENDING_COUNT=$(find "$QUEUE_DIR" -maxdepth 1 -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
if [[ "${PENDING_COUNT:-0}" -gt 0 ]]; then
  distill-background 2>/dev/null &
  echo "Draining $PENDING_COUNT distill queue item(s) in background"
fi

# Inject recent context — only when there's actual activity (saves ~550 tokens on quiet days)
RETRO_OUTPUT=$(fort-memory retro 1 2>/dev/null)
DATA_ROW=$(echo "$RETRO_OUTPUT" | grep -A2 '| sessions' | tail -1)
COMMITS=$(echo "$DATA_ROW" | awk -F'|' '{print $3}' | tr -d ' ')
ISSUES=$(echo "$DATA_ROW" | awk -F'|' '{print $6}' | tr -d ' ')

if [ "${COMMITS:-0}" != "0" ] || [ "${ISSUES:-0}" != "0" ]; then
    echo "Fort Memory — recent activity (${COMMITS} commits, ${ISSUES} issues)"
    echo "$RETRO_OUTPUT" | head -10
fi
