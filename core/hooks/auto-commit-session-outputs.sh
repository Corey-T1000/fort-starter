#!/bin/bash
# Hook: PostToolUse
# Matcher: Write|Edit|MultiEdit
# Auto-commit session outputs to a daily session branch.
#
# Catches the most common Fort gap: /narrate, /distill, and /devlog writes
# that pile up uncommitted on main, then get lost when a session ends abruptly.
# Source Fort retro: ~73 of 155 dirty files in one cleanup audit were exactly
# this pattern. Auto-committing to a daily session/YYYY-MM-DD branch makes
# those writes durable without forcing the user to think about branching.
#
# v1 (Write): write-once session outputs
#   memory/session_YYYY-MM-DD_<slug>.md  (/narrate)
#   memory/feedback_<topic>.md           (/distill, new files)
#
# v2 (Edit|MultiEdit): topic-file extensions from /distill
#   memory/XX-<slug>.md  or  memory/XX.YY-<slug>.md   (JD topic files)
#   memory/feedback_<topic>.md   (already-tracked feedback file updates)
#   MEMORY.md is deliberately EXCLUDED — it's a high-conflict index file
#   that gets rows inserted in the middle; multiple parallel sessions
#   hitting it need coordinated manual commits. /eod handles it.
#
# Commits via commit-tree + update-ref so the user's HEAD and working tree
# are never touched. Pushes to origin.
#
# Conflict handling: skip on divergence (session branch's version of this
# file differs from the parent it was based on, indicating another session
# already committed a different edit). Log clearly. MVP avoids 3-way merge.
#
# EOD merge: `git merge --no-ff session/$(date +%F)` into main when ready.
#
# Stdin JSON: { tool_name, tool_input: { file_path, ... }, tool_response, ... }
# Silent on any failure. Log at scratch/.auto-commit.log.

set -u  # no -e — we never want to block the user

INPUT=$(cat)

# --- 1. Guard: only fire on matching paths ------------------------------

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0
[ ! -f "$FILE" ] && exit 0

# Only Fort root repo. Subproject repos (projects/*, worktrees/*) skip.
# FORT_ROOT must be set (exported by Fort bootstrap). Silent pass-through if not.
FORT_ROOT="${FORT_ROOT:-}"
[ -z "$FORT_ROOT" ] && exit 0

# MEMORY.md excluded — multi-session coordination nightmare, /eod handles it
case "$FILE" in
    "$FORT_ROOT"/memory/MEMORY.md) exit 0 ;;
esac

case "$FILE" in
    "$FORT_ROOT"/memory/session_*.md) KIND="narrate" ;;
    "$FORT_ROOT"/memory/feedback_*.md) KIND="distill" ;;
    # JD topic files: XX-slug.md or XX.YY-slug.md (not session_/feedback_/MEMORY)
    "$FORT_ROOT"/memory/[0-9]*.md) KIND="topic" ;;
    *) exit 0 ;;
esac

# --- 2. Derive identifiers ---------------------------------------------

BASENAME=$(basename "$FILE" .md)
case "$KIND" in
    narrate)
        # session_YYYY-MM-DD_<slug>.md → <slug>
        SLUG=$(echo "$BASENAME" | sed -E 's/^session_[0-9]{4}-[0-9]{2}-[0-9]{2}_//')
        MSG="auto(narrate): $SLUG"
        ;;
    distill)
        # feedback_<topic>.md → <topic>
        SLUG=$(echo "$BASENAME" | sed -E 's/^feedback_//')
        MSG="auto(distill): feedback_$SLUG"
        ;;
    topic)
        # XX-<slug>.md or XX.YY-<slug>.md → <slug> (with JD prefix)
        SLUG="$BASENAME"
        MSG="auto(topic): $SLUG"
        ;;
esac

TODAY=$(date +%Y-%m-%d)
SESSION_BRANCH="session/$TODAY"
LOG="$FORT_ROOT/scratch/.auto-commit.log"
LOCKDIR="/tmp/fort-autocommit.lock.d"
RELFILE="${FILE#$FORT_ROOT/}"

log() {
    mkdir -p "$(dirname "$LOG")"
    echo "$(date +%H:%M:%S) [$KIND] $*" >> "$LOG"
}

# --- 3. Serialize across parallel sessions ------------------------------
# macOS-portable mkdir-lock. Retry briefly since hook timeout is 10s.

# Portable mtime — macOS uses -f, Linux uses -c
lockdir_mtime() {
    if stat -f %m "$1" 2>/dev/null; then return; fi
    stat -c %Y "$1" 2>/dev/null || echo 0
}

LOCK_ACQUIRED=0
for attempt in 1 2 3 4 5; do
    if mkdir "$LOCKDIR" 2>/dev/null; then
        LOCK_ACQUIRED=1
        break
    fi
    # Stale lock check: if older than 30s, assume crashed holder and steal
    if [ -d "$LOCKDIR" ]; then
        AGE=$(( $(date +%s) - $(lockdir_mtime "$LOCKDIR") ))
        if [ "$AGE" -gt 30 ]; then
            rmdir "$LOCKDIR" 2>/dev/null
            continue
        fi
    fi
    sleep 0.5
done

if [ "$LOCK_ACQUIRED" = "0" ]; then
    log "skip $RELFILE — lock held after 5 retries"
    exit 0
fi

# Combined cleanup trap set AFTER lock acquired. Single trap, both cleanups.
# (Previously two traps — the second overwrote the first, leaking $LOCKDIR on
# every invocation, which caused cascading "lock held" false-skips under burst.)
TMPIDX=$(mktemp)
trap 'rm -f "$TMPIDX"; rmdir "$LOCKDIR" 2>/dev/null' EXIT

cd "$FORT_ROOT" 2>/dev/null || exit 0

# --- 4. Skip if file is already at the right state on session branch ----
#
# NOTE: previous v2 had a "divergence check" that skipped whenever session
# branch's blob differed from origin/main's blob for this file. That was
# broken: the hook's OWN earlier commit to session branch makes branch diverge
# from main, so every second edit of the day's topic file was silently
# dropped. Removed after code review. The race retry in section 7
# is the correct parallel-session safeguard — it handles CAS-failure by
# rebuilding atop the new branch tip. If a sibling session's intermediate
# edit DOES get clobbered (rare + only under true parallel edits of same
# file), the sibling's commit remains in git reflog and is recoverable.

CURRENT_BLOB=$(git hash-object "$FILE" 2>/dev/null || true)

if git show-ref --verify --quiet "refs/heads/$SESSION_BRANCH"; then
    BRANCH_BLOB=$(git rev-parse "refs/heads/$SESSION_BRANCH:$RELFILE" 2>/dev/null || true)

    # Idempotent skip — our working tree blob is already what the branch has
    if [ -n "$BRANCH_BLOB" ] && [ "$BRANCH_BLOB" = "$CURRENT_BLOB" ]; then
        log "skip $RELFILE — already on $SESSION_BRANCH"
        exit 0
    fi
fi

# --- 5. Determine parent commit ----------------------------------------

if git show-ref --verify --quiet "refs/heads/$SESSION_BRANCH"; then
    PARENT=$(git rev-parse "refs/heads/$SESSION_BRANCH")
else
    # First commit of the day — base off origin/main (fallback to main)
    PARENT=$(git rev-parse origin/main 2>/dev/null || git rev-parse main 2>/dev/null)
    if [ -z "$PARENT" ]; then
        log "skip $RELFILE — no main/origin-main reference"
        exit 0
    fi
fi

# --- 6. Build commit via ref-plumbing (no HEAD or working-tree changes) -
# ($TMPIDX allocated + trap set in section 3, after lock acquisition, so the
#  lock + tmpidx cleanup share one trap — don't overwrite here.)

if ! GIT_INDEX_FILE="$TMPIDX" git read-tree "$PARENT" 2>/dev/null; then
    log "skip $RELFILE — read-tree failed"
    exit 0
fi

if ! GIT_INDEX_FILE="$TMPIDX" git update-index --add "$RELFILE" 2>/dev/null; then
    log "skip $RELFILE — update-index failed"
    exit 0
fi

TREE=$(GIT_INDEX_FILE="$TMPIDX" git write-tree 2>/dev/null)
[ -z "$TREE" ] && { log "skip $RELFILE — write-tree failed"; exit 0; }

# Check: did the tree actually change? (Idempotency safety net.)
PARENT_TREE=$(git rev-parse "$PARENT^{tree}" 2>/dev/null)
if [ "$TREE" = "$PARENT_TREE" ]; then
    log "skip $RELFILE — no tree change"
    exit 0
fi

# Commit message: include file list in body so git log --oneline is readable
COMMIT_MSG="$MSG

file: $RELFILE
auto-committed by core/hooks/auto-commit-session-outputs.sh
EOD-merge: git merge --no-ff $SESSION_BRANCH"

COMMIT=$(echo "$COMMIT_MSG" | git commit-tree "$TREE" -p "$PARENT" 2>/dev/null)
[ -z "$COMMIT" ] && { log "skip $RELFILE — commit-tree failed"; exit 0; }

# --- 7. Advance branch ref ---------------------------------------------
# For new branches: 2-arg update-ref (no old-value check).
# For existing branches: 3-arg CAS with old-value to guard against races.

if git show-ref --verify --quiet "refs/heads/$SESSION_BRANCH"; then
    UPDATE_OK=0
    git update-ref "refs/heads/$SESSION_BRANCH" "$COMMIT" "$PARENT" 2>/dev/null && UPDATE_OK=1
else
    # Branch didn't exist when we computed PARENT. Race: another session might
    # have created it between then and now. Retry with full rebuild on race.
    UPDATE_OK=0
    git update-ref "refs/heads/$SESSION_BRANCH" "$COMMIT" "" 2>/dev/null && UPDATE_OK=1
fi

if [ "$UPDATE_OK" = "0" ]; then
    # Race: branch advanced beneath us. Rebuild commit on top of new tip.
    NEW_PARENT=$(git rev-parse "refs/heads/$SESSION_BRANCH" 2>/dev/null)
    if [ -z "$NEW_PARENT" ]; then
        log "skip $RELFILE — update-ref failed, no new parent"
        exit 0
    fi

    # If the new tip already has our file, we're done.
    NEW_BLOB=$(git rev-parse "$NEW_PARENT:$RELFILE" 2>/dev/null || true)
    CURRENT_BLOB=$(git hash-object "$FILE" 2>/dev/null || true)
    if [ -n "$NEW_BLOB" ] && [ "$NEW_BLOB" = "$CURRENT_BLOB" ]; then
        log "skip $RELFILE — already on $SESSION_BRANCH after race"
        exit 0
    fi

    # Rebuild — with error guards this time (matches section 6 hygiene)
    if ! GIT_INDEX_FILE="$TMPIDX" git read-tree "$NEW_PARENT" 2>/dev/null; then
        log "skip $RELFILE — race retry read-tree failed"
        exit 0
    fi
    if ! GIT_INDEX_FILE="$TMPIDX" git update-index --add "$RELFILE" 2>/dev/null; then
        log "skip $RELFILE — race retry update-index failed"
        exit 0
    fi
    NEW_TREE=$(GIT_INDEX_FILE="$TMPIDX" git write-tree 2>/dev/null)
    [ -z "$NEW_TREE" ] && { log "skip $RELFILE — race retry write-tree failed"; exit 0; }

    # No-op guard — don't create an empty commit on the rebuild path either
    NEW_PARENT_TREE=$(git rev-parse "$NEW_PARENT^{tree}" 2>/dev/null)
    if [ "$NEW_TREE" = "$NEW_PARENT_TREE" ]; then
        log "skip $RELFILE — no tree change after race rebuild"
        exit 0
    fi

    NEW_COMMIT=$(echo "$COMMIT_MSG" | git commit-tree "$NEW_TREE" -p "$NEW_PARENT" 2>/dev/null)
    if [ -n "$NEW_COMMIT" ] && git update-ref "refs/heads/$SESSION_BRANCH" "$NEW_COMMIT" "$NEW_PARENT" 2>/dev/null; then
        COMMIT="$NEW_COMMIT"
        log "commit $RELFILE @ ${COMMIT:0:7} (rebuilt after race)"
    else
        log "skip $RELFILE — race retry failed at update-ref"
        exit 0
    fi
else
    log "commit $RELFILE @ ${COMMIT:0:7}"
fi

# --- 8. Push (best-effort, non-blocking) -------------------------------

if git push origin "refs/heads/$SESSION_BRANCH":"refs/heads/$SESSION_BRANCH" 2>>"$LOG"; then
    log "push $SESSION_BRANCH → origin"
else
    log "push $SESSION_BRANCH failed — will retry next commit"
fi

# --- 9. Notify (priority=min so it doesn't buzz phone) ------------------

if command -v fort-notify &>/dev/null; then
    fort-notify "auto-captured $KIND: $SLUG ($SESSION_BRANCH)" --priority min 2>/dev/null || true
fi

exit 0
