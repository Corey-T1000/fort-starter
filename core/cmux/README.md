# Fort Board (cmux sidebar)

A cmux custom sidebar that lists every desk (cmux workspace) and whose turn it is. Useful once you run more than two or three Claude Code sessions at once: you look at one column instead of cycling tabs.

| File | What it is |
|------|------------|
| `fort-board.js` | The sidebar. Runs in cmux's JS sidebar runtime. |
| `harness.mjs` | Headless test: runs the board inside cmux's own runtime under node with fake desks. |
| `../hooks/desk-status.sh` | Claude Code hook that publishes each desk's state for the board. |
| `../bin/fort-board-relay` | Delivers quick replies (yes / no chips) to the asking terminal. Runs as a launchd agent. |
| `../bin/com.fort.board-relay.plist` | launchd template for the relay (bootstrap fills in `__FORT_ROOT__`). |
| `../bin/fort-desk-gist` | Optional. Asks a local model for a one-line gist of the session. Off by default. |

## What it shows

One card per desk, grouped by cmux workspace group:

- **Line 1:** state dot, desk title, state + how long (`Your move 5m`).
- **Line 2:** the first line of Claude's last reply, or the gist if you turned gists on.
- **Selected desk:** branch (`●` = uncommitted changes), port, PR number, context fill.
- **Group header:** counts per state (hover for the words). Right-click for collapse, section order, and "Close N ended / ready desks" (two-step confirm, never closes pinned, dirty or selected desks).
- **Parked fold:** ended desks and Done/Stalled desks idle 24h+ fold into one "N parked" row per section. Tap to open.
- **Context meter:** a bar shows on a card once its context window passes 70% (amber), red past 85%.

Drag cards to reorder or move them between groups. A desk whose description ends in ` · from <parent workspace uuid>` nests under that parent.

### State legend

| Mark | State | Meaning |
|------|-------|---------|
| red dot | Needs you | Claude is blocked on a permission prompt |
| amber dot | Your move | Claude's reply ends in a question |
| green dot | Done | Turn finished in the last 30 min |
| green ring | Done | Finished, older than 30 min |
| blue dot | Ready | Done, and a `/narrate` capture for this session landed after your last prompt: safe to close |
| orange dot | Cooking | Claude is working |
| grey dot | Stalled | The gist said it's blocked, or the turn was interrupted (Esc) |
| grey ring | Waiting | No hook verdict and quiet for 30+ min |
| grey ring | Acked | You acked a Your move; it stays quiet until the next turn |
| no dot | Ended | No live Claude session in the desk |

**Quick replies:** a Your move card whose question a bare yes or no answers (label `Your move? · …`) gets `yes` and `no` chips. Tap one and the reply is typed into that desk's terminal and submitted, without leaving the tab you are on. Then the card shows `↳ sent "yes"` until the next turn. Either/or and open questions (which, what, how…) get only `ack`, and so does Needs you: a permission prompt is a picker, and typed words would pick the wrong option. Chips need the relay below.

**Ack:** an open Your move card has an `ack` chip (also in the right-click menu). It hides the nag until that session's next turn. The ack is stored as an `ack:<key> · ` prefix on the workspace description, so it survives sidebar reloads.

## Install

```bash
mkdir -p ~/.config/cmux/sidebars
cp core/cmux/fort-board.js ~/.config/cmux/sidebars/fort-board.js
cmux sidebar validate fort-board
cmux right-sidebar set custom fort-board --no-focus
```

The board lives in the right sidebar so it shows on every desk. Roll back with `cmux right-sidebar set files`. cmux hot-reloads the file on save.

Then wire the hook (see "How the hook feeds it") and start Claude Code from a cmux terminal so cmux tracks the session.

### Quick-reply relay

yes / no chips only show when Claude runs in one terminal on that desk. The
"Your move?" label belongs to the whole workspace, so with two Claude panes
the board can't tell which one asked, and the other might be sitting on a
permission prompt where Enter approves.

A cmux custom sidebar cannot type into a terminal. Its action scopes cover select, close, split, zoom, navigate and opening URLs, with no send-text, so a chip's direct send would be dropped silently. Instead a chip writes a request in front of the desk's workspace description:

```
say:<surface-uuid>:<label-key>:<epoch>:<reply> · <rest of the description>
```

`label-key` is a hash of the label the chip answered (`Your move? · <question>`) and `epoch` is the tap time. `bin/fort-board-relay` polls `cmux workspace list` every second and strips the request first, so it fires at most once. It then types the reply and presses Enter (`cmux send` + `cmux send-key enter`) only if:

- the reply is one of the board's fixed replies (`yes`, `no`)
- the request is at most 2 minutes old, so a tap left over from a sleeping Mac or a stopped relay is dropped, never replayed later
- the desk's progress label is still exactly the `Your move?` label that was tapped. If the desk has moved on, the request is dropped. That covers a new question, `Cooking` because you answered in the terminal, and `Needs you`, where Enter would pick a permission prompt's default.
- the surface belongs to that workspace

Every dropped request and every failed cmux call is logged as one line to stderr (the launchd log). Each distinct message is logged at most once every 5 minutes.

**Socket access (read this first).** The relay talks to cmux over its control socket. cmux's default automation mode, "cmux processes only", accepts only processes started inside cmux terminals, so **a relay started by launchd is refused on a stock install**. Pick one:

1. **Run it inside cmux (no settings change).** Open a tab in a desk you keep around and run `bin/fort-board-relay` there. It works while that tab is open.
2. **Run it under launchd.** Let outside processes in with a password. In `~/.config/cmux/cmux.json`:

   ```json
   "automation": { "socketControlMode": "password", "socketPassword": "<pick a password>" }
   ```

   Then `cmux reload-config`, and put the same value in `.fort-env` as `CMUX_SOCKET_PASSWORD="<that password>"`. The relay reads it from there, so the secret never goes in the plist. cmux also has an `allowAll` mode (any local process, set via `CMUX_SOCKET_MODE=allowAll` in cmux's environment); avoid it on shared machines.

Check it from a terminal outside cmux (for example Terminal.app):

```bash
bin/fort-board-relay --check     # "ok: cmux reachable, N workspaces" or the error and this pointer
```

Install as a launchd agent (after `fort-bootstrap`, which copies the plist to `bin/` with your path filled in):

```bash
cp bin/com.fort.board-relay.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.fort.board-relay.plist
```

- **Stop it:** `launchctl bootout gui/$(id -u)/com.fort.board-relay`
- **Logs:** `logs/fort-board-relay.log`
- **Other modes:** `bin/fort-board-relay --once` runs one sweep. `bin/fort-board-relay --parse '<description>' --label '<label>' --now <epoch>` shows how a request is read and whether it would be delivered, without calling cmux.
- **PATH:** the plist includes cmux's bundled CLI at `/Applications/cmux.app/Contents/Resources/bin`. Edit it if cmux lives elsewhere.

Without the relay the board still works, but chips do nothing beyond showing "sent".

## How the hook feeds it

Custom sidebars have no filesystem, network or timers. The only data they see is what cmux tracks: workspaces, groups, agents, descriptions and the progress bar. `desk-status.sh` writes the workspace **progress label** (the state) and **progress value** (context fill, 0..1):

| Hook event | Command | Label |
|------------|---------|-------|
| `UserPromptSubmit` | `desk-status.sh working` | `Cooking` |
| `PermissionRequest` | `desk-status.sh blocked` | `Needs you` |
| `Notification` (matcher `permission_prompt`) | `desk-status.sh blocked` | `Needs you` |
| `Stop` | `desk-status.sh done` | `Done · <first line of the reply>`, or `Your move · <question>` when the reply's last line is a question (`Your move? · <question>` when a bare yes or no answers it: not an either/or, not a which/what/how question), or `Ready to close · …` when a matching `$FORT_ROOT/memory/session_*.md` (`originSessionId: <session id>`) is newer than your last prompt |

The vanilla profile already wires all four; nothing to add. For a profile of your own, add them to its `settings.json` `hooks` block, merged into any lists that event already has (bootstrap replaces `__FORT_ROOT__`; the quotes keep a path with spaces working):

```json
"UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "\"__FORT_ROOT__/.claude/hooks/desk-status.sh\" working", "timeout": 5000 }] }],
"PermissionRequest": [{ "hooks": [{ "type": "command", "command": "\"__FORT_ROOT__/.claude/hooks/desk-status.sh\" blocked", "timeout": 5000 }] }],
"Notification": [{ "matcher": "permission_prompt", "hooks": [{ "type": "command", "command": "\"__FORT_ROOT__/.claude/hooks/desk-status.sh\" blocked", "timeout": 5000 }] }],
"Stop": [{ "hooks": [{ "type": "command", "command": "\"__FORT_ROOT__/.claude/hooks/desk-status.sh\" done", "timeout": 5000 }] }]
```

Outside cmux (no `CMUX_WORKSPACE_ID`) or without the `cmux` CLI the hook exits 0 and does nothing, so it is safe to leave wired everywhere.

The board also reads any other label sanely: an unknown label shows as the subtitle, and the state comes from cmux's own agent status.

## Optional: model-written gists

The plain label is the reply's first line, which is often the last micro-step rather than the topic. With a local model you get `<topic>: <where it stands>` instead, plus a better read of whose turn it is (including Stalled) and of which asks are yes/no. Set both in `.fort-env`:

```bash
FORT_GIST_URL="http://localhost:11434/api/generate"   # any Ollama-style /api/generate endpoint
FORT_GIST_MODEL="llama3.2:3b"                          # any small model you have pulled
```

On Stop the hook runs `bin/fort-desk-gist` detached, so the hook never waits on the model. It publishes only if the desk has not moved on since (a per-desk nonce in `~/.cache/fort/gist-nonce/`), and any error or timeout leaves the plain label in place. Results are cached in `~/.cache/fort/gist/<session_id>.json`.

Try it on a transcript without publishing anything:

```bash
bin/fort-desk-gist --dry-run ~/.claude/projects/<project>/<session>.jsonl
```

With the variables unset it prints a `skipped` line and makes no call.

## Test

```bash
node core/cmux/harness.mjs
```

It loads `SidebarRuntime.js` from the installed cmux app (override with `CMUX_SIDEBAR_RUNTIME=<path>`), renders the board against fixture desks, taps menu items and chips, and checks the text and the cmux actions that come out. It also feeds the description a `yes` chip writes to `bin/fort-board-relay --parse`. It checks delivery while the ask stands, and drops when stale, on `Needs you`, after a new ask, or once you answered. Board and relay must hash labels identically, emoji included. This keeps them from drifting apart on the request format or the reply list. Needs `node` and `python3`. Exit 0 = all pass.

## Known limits

- The board trusts cmux's agent record for live/ended. A Claude started without cmux's wrapper (for example in a terminal that predates cmux's per-panel shim, or after the OS cleaned the shim out of `$TMPDIR`) is not registered, and its desk reads Ended. Open a new tab in that desk and resume the session there.
- Ready only flips on the desk's own Stop. A capture written later from another session does not repaint it.
- Folds and the "Other" section's collapse are in-memory and reset when the sidebar reloads.
