#!/usr/bin/env bash
# Fort Memory: collect session data and write to Dolt on SessionEnd.
#
# Gathers: new commits since session start, beads issue changes,
# and writes a session record + commit records to the Dolt database.
set -euo pipefail

# Source Fort environment
_FORT_ENV="${FORT_ROOT:-$HOME/claudes-fort}/.fort-env"
[ -f "$_FORT_ENV" ] && . "$_FORT_ENV"
FORT_ROOT="${FORT_ROOT:-$HOME/claudes-fort}"
FORT_PROJECTS="$HOME/.claude/projects/-$(echo "$FORT_ROOT" | sed 's|^/||; s|/|-|g')"

MARKER_DIR="${FORT_PROJECTS}/memory/.session"
DOLT_DB="$FORT_ROOT/projects/fort-memory"

# Check if Dolt is available
if ! command -v dolt &>/dev/null; then
  echo "dolt not found, skipping fort-memory write"
  exit 0
fi

# Check if database exists
if [ ! -d "$DOLT_DB/.dolt" ]; then
  echo "fort-memory database not found, skipping"
  exit 0
fi

# Read session markers
if [ ! -f "$MARKER_DIR/session-id" ]; then
  echo "No session marker found, skipping fort-memory write"
  exit 0
fi

SESSION_ID=$(cat "$MARKER_DIR/session-id")
START_TIME=$(cat "$MARKER_DIR/start-time" 2>/dev/null || echo "")
START_COMMIT=$(cat "$MARKER_DIR/start-commit" 2>/dev/null || echo "")

cd "$DOLT_DB"

# --- Collect new commits since session start ---
NEW_COMMITS=""
COMMIT_SQL=""
FILE_SQL=""
COMMIT_COUNT=0
FILE_COUNT=0

if [ -n "$START_COMMIT" ]; then
  NEW_COMMITS=$(git -C "$FORT_ROOT" log --format='%H|%ai|%s' "$START_COMMIT..HEAD" 2>/dev/null || echo "")
fi

escape_sql() {
  echo "$1" | sed "s/'/''/g"
}

parse_type() {
  echo "$1" | sed -n 's/^\([a-z]*\).*/\1/p'
}

parse_scope() {
  echo "$1" | sed -n 's/^[a-z]*(\([^)]*\)).*/\1/p'
}

if [ -n "$NEW_COMMITS" ]; then
  while IFS='|' read -r hash timestamp message; do
    [ -z "$hash" ] && continue

    commit_type=$(parse_type "$message")
    scope=$(parse_scope "$message")
    clean_msg=$(escape_sql "$message")

    total_added=0
    total_removed=0
    total_files=0

    while IFS=$'\t' read -r added removed filepath; do
      [ -z "$filepath" ] && continue
      [ "$added" = "-" ] && added=0
      [ "$removed" = "-" ] && removed=0
      total_added=$((total_added + added))
      total_removed=$((total_removed + removed))
      total_files=$((total_files + 1))

      clean_path=$(escape_sql "$filepath")
      FILE_SQL="${FILE_SQL}INSERT IGNORE INTO commit_files VALUES ('${hash}', '${clean_path}', ${added}, ${removed});"
      FILE_COUNT=$((FILE_COUNT + 1))
    done < <(git -C "$FORT_ROOT" show --numstat --format="" "$hash" 2>/dev/null)

    # Strip timezone offset for MySQL TIMESTAMP compatibility
    clean_ts=$(echo "$timestamp" | sed 's/ [-+][0-9]*$//')
    COMMIT_SQL="${COMMIT_SQL}INSERT IGNORE INTO commits VALUES ('${hash}', '${clean_ts}', '${commit_type}', '${scope}', '${clean_msg}', ${total_files}, ${total_added}, ${total_removed}, '${SESSION_ID}');"
    COMMIT_COUNT=$((COMMIT_COUNT + 1))
  done <<< "$NEW_COMMITS"
fi

# --- Detect project from commits ---
PROJECT="unknown"
if [ -n "$NEW_COMMITS" ]; then
  # Check which project directory had the most file changes
  DOMINANT=$(git -C "$FORT_ROOT" diff --name-only "$START_COMMIT..HEAD" 2>/dev/null \
    | sed -n 's|^projects/\([^/]*\)/.*|\1|p' \
    | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
  [ -n "$DOMINANT" ] && PROJECT="$DOMINANT"
fi

# --- Build session record ---
END_TIME=$(date -u +"%Y-%m-%d %H:%M:%S")
START_TIME_SQL=$(echo "$START_TIME" | sed 's/T/ /;s/Z//')

SESSION_SQL="INSERT IGNORE INTO sessions VALUES (
  '${SESSION_ID}',
  '$(date +%Y-%m-%d)',
  '$(escape_sql "$PROJECT")',
  NULL,
  'completed',
  0,
  ${COMMIT_COUNT},
  '${START_TIME_SQL}'
);"

# --- Write to Dolt ---
ALL_SQL="${SESSION_SQL}${COMMIT_SQL}${FILE_SQL}"

if [ -n "$ALL_SQL" ]; then
  dolt sql -q "$ALL_SQL" 2>/dev/null

  # Commit the data
  dolt add . 2>/dev/null
  dolt commit -m "session: ${SESSION_ID} — ${COMMIT_COUNT} commits, ${FILE_COUNT} file changes (${PROJECT})" 2>/dev/null

  echo "Fort Memory: recorded session ${SESSION_ID} (${COMMIT_COUNT} commits, ${FILE_COUNT} files)"
else
  echo "Fort Memory: no new data to record"
fi

# remote server sync removed (2026-02-19) — was causing SSH permission prompts on
# every session close. All data stays local. To manually sync if needed:
#   rsync -az projects/fort-memory/.dolt remote-server:~/fort-memory/
#   rsync -az .beads/issues.jsonl remote-server:~/fort-data/beads/

# Cleanup markers
rm -rf "$MARKER_DIR"
