#!/bin/bash
# Hook: PreToolUse
# Matcher: Write|Edit|MultiEdit
# Guard: prevent direct edits to Fort main worktree on `main` branch.
#
# Reinforce the "never edit main directly — always worktree" pattern.
# Pairs with auto-commit-session-outputs.sh: that hook makes memory writes
# auto-committed to a session branch (so they're allowed through here);
# this hook blocks accidental code/config edits on main, prompting for a
# worktree instead.
#
# Allowed paths (session outputs — Hook A captures these to session branch):
#   memory/  notes/  scratch/  logs/  CLAUDE.md
# Blocked paths (feature-work, config): everything else on main worktree.
#
# Escape: export FORT_ALLOW_MAIN=1  (per-session), or pick "ask"→allow inline.
#
# Returns "ask" permission decision — user can override per-attempt.
# Exit 0 on non-matching: silent pass-through.

INPUT=$(cat)

FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0

# Escape hatch — explicit opt-in for this session
if [ "${FORT_ALLOW_MAIN:-0}" = "1" ]; then
    exit 0
fi

# FORT_ROOT must be set (exported by Fort bootstrap). Silent pass-through if not.
FORT_ROOT="${FORT_ROOT:-}"
[ -z "$FORT_ROOT" ] && exit 0

# Canonicalize file path. Tools sometimes pass `./foo` or `~/fort/foo` or
# symlinks; literal prefix matching would false-negative and skip the guard.
# Use python3 realpath (widely available + matches symlinks correctly);
# fall back to original if python3 missing.
if command -v python3 >/dev/null 2>&1; then
    CANON=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$FILE" 2>/dev/null)
    [ -n "$CANON" ] && FILE="$CANON"
fi

# Also canonicalize FORT_ROOT so prefix comparison is apples-to-apples
if command -v python3 >/dev/null 2>&1; then
    CANON_ROOT=$(python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$FORT_ROOT" 2>/dev/null)
    [ -n "$CANON_ROOT" ] && FORT_ROOT="$CANON_ROOT"
fi

# Only guard files inside the Fort main worktree, not subdirectories like
# worktrees/* (those are their own workspaces) or project subdirs with their
# own git (projects/*).
case "$FILE" in
    "$FORT_ROOT"/worktrees/*) exit 0 ;;  # named worktree — free pass
    "$FORT_ROOT"/projects/*) exit 0 ;;   # project subrepo — has own git
    "$FORT_ROOT"/*) ;;                    # in main worktree — check further
    *) exit 0 ;;                          # outside Fort — not our concern
esac

# Allowed session-output paths (Hook A auto-commits these to session branch)
RELPATH="${FILE#$FORT_ROOT/}"
case "$RELPATH" in
    memory/*|notes/*|scratch/*|logs/*|CLAUDE.md) exit 0 ;;
esac

# Check Fort repo current branch. Handle detached HEAD and mid-rebase:
#   - symbolic-ref errors on detached HEAD → fall through to rev-parse check
#   - mid-rebase leaves .git/rebase-apply or .git/rebase-merge
#   - if HEAD == main's tip (detached at main or rebasing main), treat as main
cd "$FORT_ROOT" 2>/dev/null || exit 0

BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "DETACHED")
HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
MAIN_SHA=$(git rev-parse main 2>/dev/null || echo "")
IN_REBASE=0
[ -d .git/rebase-apply ] || [ -d .git/rebase-merge ] && IN_REBASE=1

# Apply guard if:
#   - current branch is literally `main`, OR
#   - detached HEAD is at main's tip (common during cherry-pick/rebase), OR
#   - mid-rebase with main as the base (conservative: rebase of main → guard)
ON_MAIN=0
if [ "$BRANCH" = "main" ]; then
    ON_MAIN=1
elif [ -n "$HEAD_SHA" ] && [ "$HEAD_SHA" = "$MAIN_SHA" ]; then
    ON_MAIN=1
elif [ "$IN_REBASE" = "1" ]; then
    # Check if rebase is onto main. `.git/rebase-apply/onto` or rebase-merge/onto
    ONTO=""
    [ -f .git/rebase-apply/onto ] && ONTO=$(cat .git/rebase-apply/onto 2>/dev/null)
    [ -f .git/rebase-merge/onto ] && ONTO=$(cat .git/rebase-merge/onto 2>/dev/null)
    [ "$ONTO" = "$MAIN_SHA" ] && ON_MAIN=1
fi

if [ "$ON_MAIN" = "0" ]; then
    exit 0
fi

# On main, editing non-session-output file → prompt
jq -n --arg path "$RELPATH" '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: ("Editing " + $path + " directly on Fort main. Recommended: `git worktree add -b <branch> worktrees/<slug> main` then edit there. Set FORT_ALLOW_MAIN=1 to disable this prompt.")
    }
}'

exit 0
