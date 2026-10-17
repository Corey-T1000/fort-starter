---
name: spawn
description: |
  Branch a side-thread into its own worktree desk and a fresh Claude session,
  without derailing the current one. Use when the user says "spawn", "spawn a
  session for X", "branch this off", "spin up a session", "take this tangent
  elsewhere", "new worktree for X", or has a side-idea mid-conversation that
  deserves its own branch. Wraps `bin/fort-spawn`: new worktree off the default
  branch plus a session seeded with a short warm brief built from THIS
  conversation. The current session stays put. /despawn is the inverse.
user_invocable: true
arguments:
  - name: topic
    description: "What the new desk is about. Becomes the slug (worktree + branch spawn/<slug>)."
    required: false
  - name: focus
    description: "Optional explicit first turn. Omit and the skill writes a brief from the conversation."
    required: false
---

# Spawn

Fork a tangent into its own desk: a git worktree at `worktrees/<slug>` on
branch `spawn/<slug>`, with a new Claude session already running there and
already briefed. Then come back to the current thread unchanged.

## When to Use

- A side-idea that will produce committed work, or any stream you'd want on
  its own branch and its own commit history
- The current conversation should keep its focus

## When NOT to Use

- A quick question or a one-off lookup: answer it here
- More work on a feature that already has a desk: open another terminal in
  that worktree instead (same branch, just don't double-commit)
- Continuing an existing branch: `/spawn` always starts fresh off the default branch

## What to Do

1. **Pick the slug.** Lowercase letters, digits and dashes, short and specific
   (`auth-refactor`, not `stuff`). `fort-spawn` refuses anything else and
   suggests a cleaned version. No topic given → ask for it in one line; don't
   invent one.

2. **Look for context the new session would otherwise rediscover** (a minute,
   not a research project): the matching `memory/` topic file, `notes/`, the
   project directory, recent `logs/`. Note the 3-5 facts that matter.

3. **Write the warm brief** to a temp file. The new session reads it as its
   first turn, before anything else, so inline the facts instead of only
   pointing at files. Keep it to a short structured paragraph, plain ASCII:

   ```
   Focus: <one sentence: what this desk is for and why it branched off>.
   Context: <the facts from step 2, inline: paths, numbers, decisions made so far>.
   Read first: <2-4 files, each with why it matters>.
   Constraints: <what not to touch, open questions, decisions already made>.
   Deliver: <the concrete output and where it goes>, then commit on this branch.
   ```

   If the user gave an explicit `focus`, use it verbatim instead.

4. **Fire it:**

   ```bash
   bin/fort-spawn <slug> /path/to/brief.md
   # or: printf '%s\n' "$BRIEF" | bin/fort-spawn <slug> -
   ```

   The launcher picks itself: a new cmux workspace when running inside cmux, a
   new tmux window inside tmux, otherwise it prints the exact command to paste
   into a new terminal. Relay that command verbatim when it prints one.

   Options (env vars):
   - `FORT_SPAWN_EFFORT=low|medium|high|xhigh|max`: `high` for code and
     research, `low` for a chat fork
   - `FORT_SPAWN_RC=1`: start the session with Remote Control
     (`--remote-control <slug>`), so it shows up in claude.ai/code and the
     Claude mobile app under the slug. Use when the user wants to pick it up
     on their phone.
   - `FORT_SPAWN_LAUNCHER=print`: never open anything, just print the command

5. **Confirm and stay put.** One line for the worktree and launcher, then 3-5
   bullets of what the brief asks for and where it delivers. Don't switch focus
   or load the new topic's memory here; that belongs to the new session.

   > Spawned `worktrees/<slug>` (branch `spawn/<slug>`), opened in a new tmux window. Still on <current focus> here.

## Failure Handling

- **Slug already exists** (branch, folder or registered worktree): relay it
  and offer a more specific slug. Never delete the old one to make room.
- **Not a clean slug**: use the suggestion `fort-spawn` prints.
- **cmux or tmux refused**: the script falls back to printing the command.
  Relay it; don't retry in a loop.

## Notes

- The brief file lives under `.git/fort-spawn/`, so it never dirties the
  worktree or the default branch.
- `fort-spawn` adds `/worktrees/` to `.git/info/exclude` if nothing ignores it
  yet, so desks don't show up in `git status` on the default branch.
- `FORT_SPAWN_AGENT` swaps the CLI that gets launched (default `claude`).
- `/despawn <slug>` merges the desk back and tears it down when it's done.
