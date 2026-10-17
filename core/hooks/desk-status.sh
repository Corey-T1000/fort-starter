#!/bin/bash
# Publish this desk's state to cmux so Fort Board (core/cmux/fort-board.js)
# can show whose turn it is. Writes the workspace progress label + value.
#
# Usage (wired in settings.json):
#   desk-status.sh working   UserPromptSubmit                -> "Cooking"
#   desk-status.sh blocked   PermissionRequest, Notification -> "Needs you"
#   desk-status.sh done      Stop -> "Done · <first line of the reply>"
#       "Your move · <q>"    when the reply's last line <q> is a question
#       "Your move? · <q>"   when <q> is one a bare yes or no answers (the
#                            board then offers yes / no quick-reply chips)
#       "Ready to close · …" when a /narrate capture for this session
#                            (memory/session_*.md carrying "originSessionId:
#                            <id>", in the desk's own worktree or in
#                            $FORT_ROOT) landed after the last prompt
#
# The progress VALUE is the context-window fill (0..1), estimated from the
# transcript tail's latest usage block; the board draws it as a meter.
#
# On Stop, when FORT_GIST_URL and FORT_GIST_MODEL are set, bin/fort-desk-gist
# runs detached and may replace the label with a model-written
# "<topic>: <where it stands>". Unset (the default) = no model call, the plain
# label above stays.
#
# Exits 0 silently outside cmux (no CMUX_WORKSPACE_ID) or without the cmux CLI.
# Never fails the hook.

[ -z "${CMUX_WORKSPACE_ID:-}" ] && exit 0
case "$CMUX_WORKSPACE_ID" in *[!A-Za-z0-9-]*) exit 0 ;; esac
command -v cmux >/dev/null 2>&1 || exit 0

# FORT_ROOT: settings export it inside Claude; otherwise the repo this hook
# lives in (<root>/.claude/hooks/ when installed, <root>/core/hooks/ in source).
FORT_ROOT="${FORT_ROOT:-$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd -P)}"
_FORT_ENV="$FORT_ROOT/.fort-env"
[ -f "$_FORT_ENV" ] && . "$_FORT_ENV"

status="${1:-done}"
STATE_DIR="$HOME/.cache/fort/desk"
mkdir -p -m 700 "$STATE_DIR" 2>/dev/null

hook_json=""
[ ! -t 0 ] && hook_json=$(cat 2>/dev/null)

# One python pass over the hook JSON prints four lines:
#   skip flag (a Notification that is not a permission prompt) · ctx fill ·
#   reply's first line · turn (you|done|ready)
out=$(FORT_HOOK_STATUS="$status" FORT_ROOT="$FORT_ROOT" python3 -c '
import json, os, re, sys
from datetime import datetime

try:
    hook = json.loads(sys.stdin.read() or "{}")
except Exception:
    hook = {}
status = os.environ.get("FORT_HOOK_STATUS")
ntype = str(hook.get("notification_type") or "")
print("skip" if status == "blocked" and ntype and ntype != "permission_prompt" else "")
path = hook.get("transcript_path") or ""

def tail_lines(p, n=400, chunk=1 << 20, cap=16 << 20):
    """Last ~n complete lines without reading a whole (often 10MB+) transcript."""
    try:
        with open(p, "rb") as f:
            f.seek(0, 2)
            size = f.tell()
            pos, buf = size, b""
            while pos > 0 and buf.count(b"\n") <= n and size - pos < cap:
                step = min(chunk, pos)
                pos -= step
                f.seek(pos)
                buf = f.read(step) + buf
    except Exception:
        return []
    lines = buf.split(b"\n")
    if pos > 0:
        lines = lines[1:]  # first piece is a partial line
    return [l.decode("utf-8", "replace") for l in lines[-n:] if l.strip()]

tail = []
for line in tail_lines(path) if path else []:
    try:
        tail.append(json.loads(line))
    except Exception:
        pass
assistant = [d for d in reversed(tail) if d.get("type") == "assistant"]

# Context fill: input + cache + output tokens of the newest usage block over
# the window. 1M when the configured model says so or the count already
# overflows 200k (transcripts do not reliably record the 1M flag).
ctx = ""
for d in assistant:
    msg = d.get("message") or {}
    u = msg.get("usage")
    if not u:
        continue
    tokens = sum(int(u.get(k) or 0) for k in (
        "input_tokens", "cache_read_input_tokens",
        "cache_creation_input_tokens", "output_tokens"))
    if tokens <= 0:
        continue
    model = str(msg.get("model") or "")
    try:
        with open(os.path.expanduser("~/.claude/settings.json")) as f:
            model += " " + str(json.load(f).get("model") or "")
    except Exception:
        pass
    window = 1_000_000 if ("1m" in model.lower() or tokens > 200_000) else 200_000
    ctx = "%.2f" % min(1.0, max(0.0, tokens / window))
    break
print(ctx)

if status != "done":
    sys.exit(0)

text = hook.get("last_assistant_message") or ""
if not text:
    for d in assistant:
        parts = [c.get("text", "") for c in (d.get("message") or {}).get("content") or []
                 if isinstance(c, dict) and c.get("type") == "text"]
        text = "\n".join(p for p in parts if p.strip())
        if text:
            break
clean = [re.sub(r"\s+", " ", re.sub(r"[*_`#>]+", "", raw).strip(" -|")).strip()
         for raw in text.splitlines()]
clean = [l for l in clean if l]
turn = "you" if clean and clean[-1].endswith("?") else "done"

def plain_yesno(ask):
    """A question a bare yes or no answers: not an either/or, not a wh-question."""
    t = ask.lower().strip()
    if not t.endswith("?") or re.search(r"\bor\b", t):
        return False
    return not re.match(r"(what|which|how|where|why|who|when)\b", t.rsplit(": ", 1)[-1])

# On Your move the subtitle is the question itself (the last line); a yes/no
# one becomes "Your move?" so the board offers yes / no chips.
line = clean[-1] if turn == "you" else (clean[0] if clean else "")
if turn == "you" and plain_yesno(line):
    turn = "youyn"
print(line[:110] + ("…" if len(line) > 110 else ""))

def human(d):
    if d.get("type") != "user" or d.get("isMeta") or d.get("isSidechain"):
        return False
    c = (d.get("message") or {}).get("content")
    if isinstance(c, list):
        if any(isinstance(x, dict) and x.get("type") == "tool_result" for x in c):
            return False
        c = " ".join(x.get("text", "") for x in c if isinstance(x, dict) and x.get("type") == "text")
    return isinstance(c, str) and bool(c.strip()) and not c.strip().startswith("<")

# Ready to close: done, and a /narrate file for this session is newer than
# the last typed prompt. /narrate writes to the memory/ of the repo it runs in,
# which for a spawned desk is its worktree, so check that root and FORT_ROOT.
sid = str(hook.get("session_id") or "")
if turn == "done" and re.fullmatch(r"[A-Za-z0-9-]+", sid):
    last_ts = 0
    for d in reversed(tail):
        if human(d):
            try:
                last_ts = datetime.fromisoformat(str(d.get("timestamp")).replace("Z", "+00:00")).timestamp()
            except Exception:
                pass
            break
    roots = []
    cwd = str(hook.get("cwd") or "")
    if cwd and os.path.isdir(cwd):
        try:
            import subprocess
            top = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                                 capture_output=True, text=True, timeout=2).stdout.strip()
            if top:
                roots.append(top)
        except Exception:
            pass
    if os.environ.get("FORT_ROOT"):
        roots.append(os.environ["FORT_ROOT"])
    needle = "originSessionId: " + sid
    files = []
    for mem in dict.fromkeys(os.path.join(os.path.realpath(r), "memory") for r in roots):
        try:
            files += [os.path.join(mem, n) for n in os.listdir(mem) if n.startswith("session_") and n.endswith(".md")]
        except Exception:
            pass
    for p in files:
        try:
            if last_ts and os.path.getmtime(p) > last_ts and needle in open(p, errors="replace").read(4096):
                turn = "ready"
                break
        except Exception:
            pass
print(turn)
' <<<"$hook_json" 2>/dev/null)

skip=$(printf '%s\n' "$out" | sed -n 1p)
ctx=$(printf '%s\n' "$out" | sed -n 2p)
summary=$(printf '%s\n' "$out" | sed -n 3p)
turn=$(printf '%s\n' "$out" | sed -n 4p)
[ "$skip" = "skip" ] && exit 0

# Context fill persists per desk so a hook without a usable transcript keeps
# the last known value instead of resetting the meter.
ctx_file="$STATE_DIR/$CMUX_WORKSPACE_ID.ctx"
[ -L "$ctx_file" ] && rm -f "$ctx_file"
if [ -n "$ctx" ]; then
  printf '%s\n' "$ctx" > "$ctx_file" 2>/dev/null
else
  ctx=$(cat "$ctx_file" 2>/dev/null)
fi
case "$ctx" in ''|*[!0-9.]*) ctx=0 ;; esac

# Any state change invalidates a pending gist: fort-desk-gist publishes only
# while this nonce is unchanged, so a slow model call never repaints a desk
# that has already moved on to its next turn. Private 0700 dir, not /tmp.
nonce="$$-$(date +%s)"
nonce_dir="$HOME/.cache/fort/gist-nonce"
mkdir -p -m 700 "$nonce_dir" 2>/dev/null
[ -L "$nonce_dir/$CMUX_WORKSPACE_ID" ] && rm -f "$nonce_dir/$CMUX_WORKSPACE_ID"
printf '%s\n' "$nonce" > "$nonce_dir/$CMUX_WORKSPACE_ID" 2>/dev/null

case "$status" in
  working) label="Cooking" ;;
  blocked) label="Needs you" ;;
  done)
    case "$turn" in
      you)   label="Your move" ;;
      youyn) label="Your move?" ;;
      ready) label="Ready to close" ;;
      *)     label="Done" ;;
    esac
    [ -n "$summary" ] && label="$label · $summary" ;;
  *) exit 0 ;;
esac

# Detached so a slow cmux socket never holds up the hook.
( cmux set-progress "$ctx" --label "$label" --workspace "$CMUX_WORKSPACE_ID" ) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

if [ "$status" = "done" ] && [ -n "${FORT_GIST_URL:-}" ] && [ -n "${FORT_GIST_MODEL:-}" ] && [ -n "$hook_json" ]; then
  gist=""
  for g in "$FORT_ROOT/bin/fort-desk-gist" "$(dirname "$0")/../../bin/fort-desk-gist"; do
    [ -x "$g" ] && { gist="$g"; break; }
  done
  if [ -n "$gist" ]; then
    ( printf '%s' "$hook_json" | FORT_GIST_NONCE="$nonce" FORT_CTX="$ctx" FORT_ROOT="$FORT_ROOT" \
        FORT_GIST_URL="$FORT_GIST_URL" FORT_GIST_MODEL="$FORT_GIST_MODEL" "$gist" ) </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
fi
exit 0
