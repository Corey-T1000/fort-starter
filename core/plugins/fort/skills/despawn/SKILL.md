---
name: despawn
description: |
  The deliberate inverse of /spawn: capture the desk's session, merge its
  branch into the default branch, then remove the worktree and delete the
  branch. Use when the user says "despawn", "despawn X", "tear down the X
  worktree", "fold X back in", "X is done, clean it up", or "retire the X
  branch". Destructive on purpose, so it dry-runs first and asks once.
  Wraps `bin/fort-despawn`. Nothing is pushed.
user_invocable: true
arguments:
  - name: slug
    description: "The desk name under worktrees/ (branch spawn/<slug>). Required."
    required: true
---

# Despawn

`/spawn` opens a branch, a worktree and a session. `/despawn` closes all three
in order: capture, merge, teardown. `bin/fort-despawn` does the git work; this
skill runs the capture the script can't, asks once before anything
destructive, and reports.

## When to Use

- A desk's work is finished and belongs on the default branch
- The worktree is only taking up space

## When NOT to Use

- As a checkpoint. Run `/distill` or `/narrate` instead; they leave everything
  in place.
- While the desk's session is still running. The script refuses when any
  process has its working directory inside the worktree (checked with `lsof`,
  or `/proc` on Linux; with neither, it refuses until `--force`).
- From a shell inside the worktree being removed. The script refuses that too;
  run it from the repo root.

## What to Do

1. **Dry-run first, always.** It changes nothing and prints the whole plan
   plus every blocker:

   ```bash
   bin/fort-despawn <slug>
   ```

   Lines to read: `blocker:` (anything that stops `--yes`), `merge:`
   (fast-forward, merge commit, or nothing), `capture:`.

2. **Capture if it's missing.** `capture: WARNING` means no
   `memory/session_*.md` from this desk landed since the spawn.
   - The desk's session is still open: ask the user to run `/narrate` (and
     `/distill`, if installed) there, commit, and exit the session.
   - The session is gone and the work is worth keeping: run `/narrate` and
     `/distill` here for that slug, from what the branch's commits and files
     show.
   - The desk was trivial: say so and move on. The warning never blocks.

3. **Clear blockers**, never around them:
   - Uncommitted changes (exit 3): commit them in the worktree, or discard by
     hand only when the user says they are junk.
   - Live process (exit 2): the user exits that session.
   - No way to check for live processes (exit 2, "no lsof and no /proc"):
     install `lsof`, or have the user confirm every session in the desk is
     closed and re-run with `--force`. `--force` skips only that one check.
   - Default branch not checked out at the repo root, or a merge, cherry-pick,
     revert, rebase or bisect half done there (exit 1): the user finishes or
     aborts it. Never abort the user's operation yourself.
   - Conflict predicted (exit 5): merge the default branch into the desk
     inside the worktree, resolve, commit, re-run the dry run.

4. **Ask once** with the dry-run summary: what merges (commit count, ff or
   merge commit), what gets removed (worktree, branch), capture status. Then:

   ```bash
   bin/fort-despawn <slug> --yes
   ```

   The script re-checks every guard, merges with `git merge --ff` (a merge
   commit when the branches diverged, never a force or a rebase), confirms the
   branch is contained in the default branch, deletes the desk's brief file
   from `.git/fort-spawn/` (the dry run lists it), unlinks the Fort symlinks
   `/spawn` put in the desk (their targets are untouched), removes the
   worktree with plain `git worktree remove` and deletes the branch with
   `git branch -d`. A merge the script started and that fails is aborted, git's
   own output is printed, and nothing is removed.

5. **Report the `done:` line verbatim.** Nothing is pushed; say so if the
   user expects the merge on a remote.

## Exit Codes

| rc | meaning | what to do |
|----|---------|------------|
| 0 | done, or a clean dry run | report |
| 1 | usage, unknown slug, shell inside the worktree, wrong branch or unfinished operation at root | fix and re-run |
| 2 | a process still has its cwd in the worktree, or no way to check | exit that session; `--force` only when there is no checker |
| 3 | uncommitted changes in the worktree | commit, or discard on the user's say-so |
| 5 | merge conflict or failed merge (aborted) | resolve in the worktree |
| 6 | teardown incomplete | read the message; the merge stands, the worktree or branch may remain |

## Notes

- Never `git worktree remove --force` or `git branch -D` around the script.
  The guards are the point.
- `/spawn` opens what this closes.
