// Fort Board: a cmux custom sidebar that shows every desk (cmux workspace)
// and whose turn it is, so you can run several Claude Code sessions at once
// without polling each tab.
//
//   - one card per desk: state dot + title + state/age, then one subtitle line
//   - sections come from cmux workspace groups (collapse, reorder, pin order)
//   - drag to reorder desks or move them between groups
//   - a desk whose description ends in " · from <parent workspace uuid>"
//     nests one level under that parent when both sit in the same section
//   - context meter from progress.value (hook-published context fill, 0..1;
//     0 or absent = unknown, no bar)
//   - quick replies: yes / no / ack chips on Your move cards (needs the
//     bin/fort-board-relay launchd agent to deliver the text)
//   - group header right-click: "Close N ended desks" / "Close N ready
//     desks", two-step confirm
//
// States, one mark each:
//   red dot Needs you (permission prompt) · amber dot Your move (Claude asked
//   you something) · green dot Done (<30 min), green ring after · orange dot
//   Cooking · grey dot Stalled (said it's blocked, or interrupted mid-turn) ·
//   grey ring Waiting (no hook verdict, 30+ min) · grey ring Acked (you
//   dismissed a Your move until its next turn) · blue dot Ready (done AND a
//   /narrate capture landed after the last prompt: safe to close) · no dot Ended
//
// The data bus is the workspace progress label, written by
// .claude/hooks/desk-status.sh (and optionally refined by bin/fort-desk-gist):
//   "Cooking" | "Needs you" | "Waiting" | "<Turn>" | "<Turn> · <line>"
//   Turn = Your move | Your move? | Done | Stalled | Ready to close
// "Your move?" marks an ask a bare yes or no fully answers: those cards get
// yes / no quick-reply chips (delivered by bin/fort-board-relay), every other
// Your move card gets only ack.
// Any other label is shown as the subtitle and the state comes from cmux's
// own agent status. Done and Stalled desks fold to one line after 24h.
//
// Runtime facts (cmux 0.64.x JS sidebar runtime):
//   - no filesystem, network or timers: data arrives only through cmux
//     (workspace description, progress label/value, agents, groups)
//   - the program runs once; every live value is a function-valued prop
//   - no conditional view: If() below is a 0-or-1 item ForEach
//   - `.frame()` takes an object; bind individual keys, not the whole spec
//   - the close-confirm window is measured against data.clock()

// --- constants -----------------------------------------------------------------
const RED = "#E5484D";
const GREEN = "#30A46C";
const ORANGE = "#F76B15";
const GREY = "#8A8A8A";
const AMBER = "#F5A623";
const PURPLE = "#7A4FD8";
const BLUE = "#3E8ED0";
const CLEAR = "#00000000";
const CTX_BAR_W = 120;
const ARM_SECONDS = 5;

// --- small utilities -------------------------------------------------------------
const now = () => data.clock()?.epoch ?? Math.floor(Date.now() / 1000);

// Conditional view: mounts build() while cond() is true, nothing otherwise.
function If(cond, build) {
  return ForEach({ items: () => (cond() ? [1] : []), key: () => "on" }, () => build());
}

// Fixed-width transparent spacer (keeps columns aligned).
function indent(w) {
  return Rectangle().fill(CLEAR).frame({ width: w, height: 1 });
}

function ago(since, t) {
  const d = Math.max(0, t - since);
  return d < 60 ? d + "s" : d < 3600 ? Math.floor(d / 60) + "m" : d < 86400 ? Math.floor(d / 3600) + "h" : Math.floor(d / 86400) + "d";
}

// --- optimistic UI -------------------------------------------------------------------
// Local state flips the same frame; the data context (~1s) reconciles and each
// override clears itself once the host agrees.
let selectOverride = null;
const [selectTick, setSelectTick] = signal(0);

function selectedId() {
  selectTick();
  const host = data.selectedId() ?? allWorkspaces().find((w) => w.selected)?.id ?? null;
  if (selectOverride) {
    if (host === selectOverride) selectOverride = null;
    else return selectOverride;
  }
  return host;
}

// The whole-card tap. Keep it exactly workspace.select + workspace_id: an
// extra surface_id param makes the card unclickable.
function selectDesk(id) {
  if (!id) return;
  selectOverride = id;
  setSelectTick(selectTick() + 1);
  cmux("workspace.select", { workspace_id: id });
}

const closedOverride = new Set();
const [closeTick, setCloseTick] = signal(0);

function closeDesk(id) {
  closedOverride.add(id);
  setCloseTick(closeTick() + 1);
  cmux("workspace.close", { workspace_id: id });
}

const collapseOverride = new Map();
const [collapseTick, setCollapseTick] = signal(0);

function isCollapsed(g) {
  collapseTick();
  if (!g) return false;
  if (collapseOverride.has(g.id)) {
    const v = collapseOverride.get(g.id);
    if (v === !!g.collapsed) collapseOverride.delete(g.id);
    else return v;
  }
  return !!g.collapsed;
}

// "Other" (ungrouped desks) has no cmux group to collapse, so its fold is
// board-local and in-memory (resets when the sidebar reloads).
const [otherCollapsed, setOtherCollapsed] = signal(false);
const isSectionCollapsed = (gid) => (gid ? isCollapsed(groupById(gid)) : otherCollapsed());
const toggleSection = (gid) => (gid ? toggleCollapse(groupById(gid)) : setOtherCollapsed(!otherCollapsed()));

function toggleCollapse(g) {
  if (!g) return;
  const next = !isCollapsed(g);
  collapseOverride.set(g.id, next);
  setCollapseTick(collapseTick() + 1);
  cmux(next ? "workspace.group.collapse" : "workspace.group.expand", { group_id: g.id });
}

// Pinned folder order. Sections otherwise follow anchor positions, which new
// desks and drags can shift. A pinned section carries "pin:<n>" on its anchor
// workspace's description and sorts by it; unpinned sections follow by
// position, "Other" stays last. Live anchors are real desks: never pinned.
const PIN_RE = /(?:^| · )pin:(\d+)(?= · |$)/;
const pinOverride = new Map(); // groupId -> pin | null until the host agrees
const [pinTick, setPinTick] = signal(0);

function writeAnchor(g, pin) {
  if (!g?.anchorId) return;
  cmux("workspace.action", pin != null
    ? { workspace_id: g.anchorId, action: "set_description", description: "pin:" + pin }
    : { workspace_id: g.anchorId, action: "clear_description" });
}

// Pins every section in `list` order (unpin = clear them all).
function setPins(list, unpin = false) {
  let n = 0;
  for (const g of list) {
    if (isLiveAnchor(g)) continue;
    const pin = unpin ? null : ++n;
    pinOverride.set(g.id, pin);
    writeAnchor(g, pin);
  }
  setPinTick(pinTick() + 1);
}

// --- data ------------------------------------------------------------------------
const allWorkspaces = computed(() => {
  closeTick();
  const ws = data.workspaces() ?? [];
  for (const id of Array.from(closedOverride)) {
    if (!ws.some((w) => w.id === id)) closedOverride.delete(id);
  }
  return ws.filter((w) => !closedOverride.has(w.id));
});

const wsIndex = computed(() => new Map(allWorkspaces().map((w) => [w.id, w])));

// Real groups, normalised. If the host ships an empty `groups` (the Swift
// runtime does), derive them from `w.group`: the anchor is the lowest-index
// member and carries the group's name.
const groupList = computed(() => {
  const ws = allWorkspaces();
  const byId = new Map(ws.map((w) => [w.id, w]));
  const raw = data.groups() ?? [];
  const firstMember = (gid) => {
    let best = null;
    for (const w of ws) if (w.group === gid && (!best || w.index < best.index)) best = w;
    return best;
  };
  let out;
  if (raw.length > 0) {
    out = raw.map((g) => {
      const anchorId = g.anchorId ?? firstMember(g.id)?.id ?? null;
      return {
        id: g.id,
        name: g.name ?? byId.get(anchorId)?.title ?? "Group",
        collapsed: !!g.collapsed,
        anchorId,
      };
    });
  } else {
    const ids = [];
    for (const w of ws) if (w.group && !ids.includes(w.group)) ids.push(w.group);
    out = ids.map((gid) => {
      const a = firstMember(gid);
      return { id: gid, name: a?.title ?? "Group", collapsed: false, anchorId: a?.id ?? null };
    });
  }
  const pos = (g) => byId.get(g.anchorId)?.index ?? firstMember(g.id)?.index ?? 1e9;
  pinTick();
  for (const g of out) {
    const a = byId.get(g.anchorId);
    const m = a && !(a.agents ?? []).length ? PIN_RE.exec(a.description ?? "") : null;
    const host = m ? Number(m[1]) : null;
    if (pinOverride.has(g.id) && pinOverride.get(g.id) === host) pinOverride.delete(g.id);
    g.pin = pinOverride.has(g.id) ? pinOverride.get(g.id) : host;
  }
  const key = (g) => g.pin ?? 1e6 + pos(g);
  return out.sort((a, b) => key(a) - key(b));
});

const groupById = (id) => groupList().find((g) => g.id === id);

// A section's header is its anchor workspace. cmux-made anchors have no
// agents; if a real session got promoted to anchor (the generated one was
// closed), keep it listed as a desk and flag the header so the section can be
// rebuilt.
const anchorWs = (g) => allWorkspaces().find((w) => w.id === g.anchorId);
const isLiveAnchor = (g) => ((anchorWs(g)?.agents ?? []).length > 0);
const anchorIds = computed(() => new Set(groupList().filter((g) => !isLiveAnchor(g)).map((g) => g.anchorId).filter(Boolean)));

const isDeskWs = (w) => !anchorIds().has(w.id);

// --- desk state ----------------------------------------------------------------------
function agentStatus(w) {
  const ags = w.agents;
  if (!ags || ags.length === 0) return "none";
  if (ags.some((a) => a.status === "working")) return "working";
  if (ags.some((a) => a.status === "needs_input")) return "needs_input";
  if (ags.some((a) => a.status === "idle")) return "idle";
  return "ended";
}

// When the newest live agent entered its current state (0 if unknown).
function liveSince(w) {
  const live = (w.agents ?? []).filter((a) => a.status !== "ended");
  if (live.length === 0) return 0;
  return live[0].sinceEpoch ?? live[0].lastActivityAt ?? 0;
}

const hookLabel = (w) => w.progress?.label ?? "";

// "<Turn> · <line>" -> { turn, text }. Turn: you | done | stalled | ready.
const TURN_PREFIX = [["Your move?", "you"], ["Your move", "you"], ["Done", "done"], ["Stalled", "stalled"], ["Ready to close", "ready"]];
// Bare labels the hook publishes that carry no subtitle of their own.
const BARE_LABELS = new Set(["", "Cooking", "Needs you", "Waiting"]);
function hookTurn(w) {
  const l = hookLabel(w);
  for (const [p, turn] of TURN_PREFIX) {
    if (l === p) return { turn, text: "" };
    if (l.startsWith(p + " · ")) return { turn, text: l.slice(p.length + 3).trim() };
  }
  return { turn: "", text: "" };
}
// A label the board does not know (another tool's progress text) is shown
// as-is; the state then comes from cmux's agent status alone.
const unknownLabel = (w) => { const l = hookLabel(w); return !BARE_LABELS.has(l) && !hookTurn(w).turn ? l : ""; };
const hookSummary = (w) => hookTurn(w).text || unknownLabel(w);

// Ack: "I've seen this Your move, stop nagging." An acked desk folds to a
// grey line and drops out of the header count until the session's next turn
// rewrites its label or its agent changes state. Stored as an "ack:<key> · "
// prefix on the workspace description, so cmux keeps it across sidebar
// reloads and restarts; descBody() strips it for every other reader.
const ACK_RE = /^ack:([0-9a-z]+)(?: · |$)/;
// A pending quick reply ("say:<surface>:<label key>:<epoch>:<reply> · ", see
// sendReply) sits in front.
const SAY_RE = /^say:[0-9A-Fa-f-]{36}:[0-9a-z]+:\d+:[a-z ]+(?: · |$)/;
const stripSay = (d) => (d ?? "").replace(SAY_RE, "");
const descBody = (w) => stripSay(w.description).replace(ACK_RE, "");
function hash36(s) { // djb2-xor, base 36; bin/fort-board-relay label_key() matches it
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h * 33) ^ s.charCodeAt(i)) >>> 0;
  return h.toString(36);
}
// Short stable hash of the ask + when the agent entered this state.
const ackKey = (w) => hash36(hookLabel(w) + "|" + liveSince(w));
const ackOverride = new Map(); // wsId -> key ("" = un-acked) until the host agrees
const [ackTick, setAckTick] = signal(0);
function storedAck(w) {
  ackTick();
  const host = ACK_RE.exec(stripSay(w.description))?.[1] ?? "";
  if (ackOverride.has(w.id)) {
    if (ackOverride.get(w.id) === host) ackOverride.delete(w.id);
    else return ackOverride.get(w.id);
  }
  return host;
}
const isAcked = (w) => { const k = storedAck(w); return k !== "" && k === ackKey(w); };
function toggleAck(w) {
  if (!w?.id) return;
  const body = descBody(w);
  let key = "";
  if (!isAcked(w)) {
    if (hookTurn(w).turn !== "you") return;
    key = ackKey(w);
  }
  ackOverride.set(w.id, key);
  setAckTick(ackTick() + 1);
  const desc = key ? (body ? "ack:" + key + " · " + body : "ack:" + key) : body;
  cmux("workspace.action", desc
    ? { workspace_id: w.id, action: "set_description", description: desc }
    : { workspace_id: w.id, action: "clear_description" });
}

// needs_you | your_move | acked | ready | done | done_old | stalled | cooking | waiting | ended
function deskState(w, t) {
  const raw = agentStatus(w);
  if (raw === "working") return "cooking";
  if (raw === "ended" || raw === "none") return "ended";
  const since = liveSince(w);
  const fresh = t - since < 1800;
  const hook = hookLabel(w);
  if (hook === "Needs you") return "needs_you";
  const { turn } = hookTurn(w);
  if (turn === "you") return isAcked(w) ? "acked" : "your_move";
  if (turn === "stalled") return "stalled";
  if (turn === "ready") return "ready";
  if (turn === "done") return fresh ? "done" : "done_old";
  // Still "Cooking" but the agent stopped: interrupted (Esc), no Stop hook ran.
  if (hook === "Cooking" && since > 0 && t - since > 90) return "stalled";
  if (hook === "" && raw === "needs_input" && fresh) return "needs_you";
  return fresh ? "done" : "waiting";
}

const STATE_COLOR = {
  needs_you: RED, your_move: AMBER, acked: GREY, ready: BLUE, done: GREEN, done_old: GREEN,
  stalled: GREY, cooking: ORANGE, waiting: GREY, ended: GREY,
};
const STATE_NAME = {
  needs_you: "Needs you", your_move: "Your move", acked: "Acked", ready: "Ready", done: "Done", done_old: "Done",
  stalled: "Stalled", cooking: "Cooking", waiting: "Waiting", ended: "Ended",
};
const DOT_FILLED = new Set(["needs_you", "your_move", "ready", "done", "stalled", "cooking"]);
const DOT_RING = new Set(["done_old", "waiting", "acked"]);
// Older than this, a desk folds to one dim line (unless selected). Desks
// waiting on you (your_move / waiting / ready) stay full size.
const PARK_AFTER = { acked: 0, done_old: 86400, stalled: 86400 };

const isLive = (st) => st !== "ended";
const isParked = (st, since, t) => PARK_AFTER[st] !== undefined && since > 0 && t - since > PARK_AFTER[st];

// Terminal to land on: the agent that is asking, or the newest live one.
function jumpSurface(w, st) {
  if (st !== "needs_you" && st !== "your_move" && st !== "acked" && st !== "done") return "";
  const ags = w.agents ?? [];
  const asking = ags.find((a) => a.status === "needs_input" && a.surfaceId);
  if (asking) return asking.surfaceId;
  const live = ags.filter((a) => a.status !== "ended");
  return live.length > 0 && live[0].surfaceId ? live[0].surfaceId : "";
}

function runningSubs(w) {
  const busy = (w.agents ?? []).find((a) => a.status === "working");
  return busy ? (busy.children ?? []).filter((c) => c.running === true).length : 0;
}

function stateText(w, st, since, t) {
  if (isParked(st, since, t)) return ago(since, t);
  const base = since > 0 ? STATE_NAME[st] + " " + ago(since, t) : STATE_NAME[st];
  const subs = st === "cooking" ? runningSubs(w) : 0;
  return subs > 0 ? base + " · " + subs + " sub" : base;
}

// Subtitle: hook line > hand-written description (an auto "spawn · …" one is
// skipped) > last prompt (not "<…" payloads or "/commands") > latestMessage
// (not a copy of the prompt) > live agent's first prompt.
function taskSummary(w) {
  const hs = hookSummary(w);
  if (hs) return hs;
  const d = descBody(w);
  if (d && !d.startsWith("spawn · ")) return d;
  const p = w.latestPrompt ?? "";
  if (p && !p.startsWith("<") && !p.startsWith("/")) return p;
  const m = w.latestMessage ?? "";
  if (m && !m.startsWith("<") && m !== p) return m;
  const live = (w.agents ?? []).filter((a) => a.status !== "ended");
  if (live.length > 0 && live[0].title) return live[0].title;
  return "";
}

// Live = working, or not ended and active in the last 12h. Sessions a /clear
// or fork left behind stay registered as idle for days and would double every desk.
function liveAgents(w, t) {
  return (w.agents ?? []).filter((a) => a.status === "working" || (a.status !== "ended" && t - (a.lastActivityAt ?? 0) < 43200));
}

// "… · from <parent-workspace-uuid>" -> parent uuid.
function spawnParent(w) {
  const m = /· from ([0-9A-Fa-f-]{36})\s*$/.exec(descBody(w));
  return m ? m[1].toUpperCase() : "";
}

// Context-window fill 0..1 from the hook bus; 0 means unknown.
function ctxFill(w) {
  const v = Number(w.progress?.value ?? 0);
  return Number.isFinite(v) && v > 0 ? Math.min(1, v) : 0;
}

const ctxColor = (v) => (v > 0.85 ? RED : v >= 0.7 ? AMBER : "#8A8A8AAA");

// Parked folds start closed; open state is per section and in-memory.
const parkOpenSet = new Set();
const [parkTick, setParkTick] = signal(0);
const parkOpen = (k) => { parkTick(); return parkOpenSet.has(k); };
function toggleParked(k) {
  if (parkOpenSet.has(k)) parkOpenSet.delete(k); else parkOpenSet.add(k);
  setParkTick(parkTick() + 1);
}

function parkedRow(e) {
  const entry = e();
  return HStack({ spacing: 6 }, [
    indent(4),
    Image("chevron.right").font(8).color("tertiary")
      .rotation(() => (parkOpen(entry.foldKey) ? 90 : 0)).frame({ width: 10 }),
    Text(() => e().count + " parked").font(11).color("tertiary"),
    Spacer(),
  ])
    .padding(4)
    .frame({ maxWidth: "infinity", alignment: "leading" })
    .background("#FFFFFF02")
    .help("Ended desks and quiet ones idle 24h+. Tap to show.")
    .onTap(() => toggleParked(entry.foldKey));
}

// --- board model -------------------------------------------------------------------
// One flat entry list: section headers (fixed) + desk rows, in render order.
// Rows carry only ids and layout flags so the keyed reconcile touches a row
// only when its structure changes; each row binds its own live fields.
const board = computed(() => {
  const t = now();
  const ws = allWorkspaces();
  const groups = groupList();
  const known = new Set(groups.map((g) => g.id));
  const desks = ws.filter(isDeskWs);
  const gsig = groups.map((g) => g.id).join(",");
  const stateOf = new Map(desks.map((w) => [w.id, deskState(w, t)]));
  // Manual order only: state is shown by the dot, never by moving the row.
  const sortKey = (w) => w.index;

  // Parent-first order within a section: a child nests (one level) under its
  // top-most ancestor that lives in the same section.
  const nestOrder = (list) => {
    const byId = new Map(list.map((w) => [w.id, w]));
    const rootOf = (w) => {
      const seen = new Set([w.id]);
      let cur = w;
      for (;;) {
        const p = spawnParent(cur);
        if (!p || !byId.has(p)) return cur;
        if (seen.has(p)) return w; // cycle: treat as unnested
        seen.add(p);
        cur = byId.get(p);
      }
    };
    const sorted = [...list].sort((a, b) => sortKey(a) - sortKey(b));
    const kids = new Map();
    const roots = [];
    for (const w of sorted) {
      const r = rootOf(w);
      if (r.id === w.id) roots.push(w);
      else {
        if (!kids.has(r.id)) kids.set(r.id, []);
        kids.get(r.id).push(w);
      }
    }
    const out = [];
    for (const r of roots) {
      out.push({ w: r, nested: false });
      for (const k of kids.get(r.id) ?? []) out.push({ w: k, nested: true });
    }
    return out;
  };

  const deskEntry = (w, groupId, nested) => {
    return {
      kind: "desk",
      // Menus are built once per mount, so what the menu lists (the other
      // groups) is in the key. Nothing that flips often may be: a remount
      // orphans any If() child mounted after the row (runtime quirk), so a
      // state-driven key would leak effects every turn.
      id: "d:" + w.id + "|" + (groupId ?? "") + "|" + gsig,
      wsId: w.id,
      groupId,
      nested,
    };
  };

  const stats = {};
  const entries = [];
  const sectionStats = (key, members) => {
    stats[key] = {
      size: members.length,
      needs: members.filter((w) => stateOf.get(w.id) === "needs_you").length,
      move: members.filter((w) => stateOf.get(w.id) === "your_move").length,
      ready: members.filter((w) => stateOf.get(w.id) === "ready").length,
      done: members.filter((w) => stateOf.get(w.id) === "done").length,
    };
  };

  // Parked: ended desks, and quiet ones (done/stalled) idle 24h+, fold into
  // one "N parked" row at the end of their section. Never the selected desk,
  // never a root that still has a live kid.
  const sel = selectedId();
  const isParkable = (w) => {
    if (w.id === sel) return false;
    const st = stateOf.get(w.id);
    if (st === "ended") return true;
    const since = liveSince(w);
    return (st === "done_old" || st === "stalled") && since > 0 && t - since > 86400;
  };
  const pushSection = (list, groupId) => {
    const order = nestOrder(list);
    const parkedIds = new Set(order.filter(({ w }) => isParkable(w)).map(({ w }) => w.id));
    // A parked root with a live kid stays out: the kid nests under it.
    for (let i = 0; i < order.length; i++) {
      if (order[i].nested || !parkedIds.has(order[i].w.id)) continue;
      for (let j = i + 1; j < order.length && order[j].nested; j++) {
        if (!parkedIds.has(order[j].w.id)) { parkedIds.delete(order[i].w.id); break; }
      }
    }
    const live = order.filter(({ w }) => !parkedIds.has(w.id));
    const parked = order.filter(({ w }) => parkedIds.has(w.id));
    for (const { w, nested } of live) entries.push(deskEntry(w, groupId, nested && !parkedIds.has(w.id)));
    if (parked.length > 0) {
      const pk = "p:" + (groupId ?? "other");
      entries.push({ kind: "parked", id: pk + "|" + parked.length, foldKey: pk, groupId, count: parked.length });
      if (parkOpen(pk)) for (const { w } of parked) entries.push(deskEntry(w, groupId, false));
    }
  };

  for (const g of groups) {
    const members = desks.filter((w) => w.group === g.id);
    sectionStats(g.id, members);
    entries.push({ kind: "header", id: "h:" + g.id, groupId: g.id });
    if (!isCollapsed(g)) pushSection(members, g.id);
  }
  const loose = desks.filter((w) => !w.group || !known.has(w.group));
  sectionStats("other", loose);
  if (loose.length > 0) {
    if (groups.length > 0) entries.push({ kind: "header", id: "h:other", groupId: null });
    if (groups.length === 0 || !otherCollapsed()) pushSection(loose, null);
  }

  return {
    entries,
    stats,
    deskCount: desks.length,
    dirtyCount: desks.filter((w) => w.dirty === true).length,
  };
});

const entries = computed(() => board().entries);

// A Fort desk: a Claude session here went through the Fort's hooks or the
// board, so it carries a desk-status label (cmux keeps the last one after
// Claude exits), an ack or quick-reply prefix, or a spawn description. A plain
// shell workspace (dev server, ssh) has none of these, and cmux reports it as
// agent-less, which the board reads as Ended.
function isFortDesk(w) {
  const l = hookLabel(w);
  if (l === "Cooking" || l === "Needs you" || l === "Waiting" || hookTurn(w).turn) return true;
  const d = w.description ?? "";
  return SAY_RE.test(d) || ACK_RE.test(stripSay(d)) || descBody(w).startsWith("spawn · ");
}

// Desks a header's "Close N … desks" may close: in that state, Fort desks
// only, and never pinned, dirty, selected or an anchor. Closing a workspace
// kills its processes, so a plain shell workspace is never offered.
// which: "ended" (dead desks) | "ready" (captured, nothing owed).
function closableIn(groupId, which = "ended") {
  const t = now();
  const sel = selectedId();
  return allWorkspaces().filter((w) =>
    isDeskWs(w)
    && isFortDesk(w)
    && (groupId ? w.group === groupId : (!w.group || !groupById(w.group)))
    && deskState(w, t) === which
    && !w.pinned && w.dirty !== true && !w.selected && w.id !== sel);
}

// Two-step close: the first click arms for ARM_SECONDS (measured on the data
// clock, there are no timers), the second click inside the window closes.
const [armed, setArmed] = signal(null); // { key, at }

function isArmed(key) {
  const a = armed();
  return !!a && a.key === key && now() - a.at <= ARM_SECONDS;
}

function armOrClose(key, groupId, which = "ended") {
  const ids = closableIn(groupId, which).map((w) => w.id);
  if (ids.length === 0) { setArmed(null); return; }
  if (isArmed(key)) {
    setArmed(null);
    for (const id of ids) closeDesk(id);
    return;
  }
  setArmed({ key, at: now() });
}

// --- drag and drop -----------------------------------------------------------------
// `index` is the dragged row's slot in the flat list with the row removed.
// The row above decides the container (a header means "into that section",
// even a folded one). Crossing sections only files the desk (group add /
// remove, cmux places it); inside a section it reorders next to its new
// neighbour. Rows sort by cmux index alone, so a drag always sticks.
function handleMove(key, index) {
  const list = entries();
  const moving = list.find((e) => e.id === key);
  if (!moving || moving.kind !== "desk") return;
  const rest = list.filter((e) => e.id !== key);
  const prev = index > 0 ? rest[index - 1] : null;
  const next = index < rest.length ? rest[index] : null;
  const container = prev ? prev.groupId : (next ? next.groupId : moving.groupId);

  const ws = data.workspaces() ?? [];
  const dragged = ws.find((w) => w.id === moving.wsId);
  if (!dragged) return;
  const current = dragged.group && groupById(dragged.group) ? dragged.group : null;

  if (current !== container) {
    if (container) cmux("workspace.group.add", { group_id: container, workspace_id: dragged.id });
    else cmux("workspace.group.remove", { workspace_id: dragged.id });
    return;
  }
  const d = dragged.index;
  const nextDesk = next && next.kind === "desk" && next.groupId === container ? ws.find((w) => w.id === next.wsId) : null;
  const prevDesk = prev && prev.kind === "desk" && prev.groupId === container ? ws.find((w) => w.id === prev.wsId) : null;
  let target = null;
  if (nextDesk) target = d < nextDesk.index ? nextDesk.index - 1 : nextDesk.index;
  else if (prevDesk) target = d < prevDesk.index ? prevDesk.index : prevDesk.index + 1;
  if (target !== null && target !== d) cmux("workspace.reorder", { workspace_id: dragged.id, index: target });
}

// --- views: desk card ------------------------------------------------------------
function statusDot(stFn) {
  return Circle({ size: 7 })
    .fill(() => { const s = stFn(); return DOT_FILLED.has(s) ? STATE_COLOR[s] : CLEAR; })
    .stroke(() => { const s = stFn(); return DOT_RING.has(s) ? STATE_COLOR[s] : CLEAR; })
    .strokeWidth(1.5)
    .help(() => STATE_NAME[stFn()]);
}

function agentRow(a) {
  return HStack({ spacing: 6 }, [
    Text(() => a().title || a().name || "")
      .font(12).color("secondary").lineLimit(1).truncation("tail")
      .help(() => a().title || a().name || ""),
    Spacer(),
    Text(() => (a().sinceEpoch ? ago(a().sinceEpoch, now()) : ""))
      .font(11).color("secondary").layoutPriority(2),
  ])
    .frame({ maxWidth: "infinity" })
    .onTap(() => { if (a().surfaceId) cmux("surface.focus", { surface_id: a().surfaceId }); });
}

// Selected card's one detail line: branch (● = dirty) · port · PR · ctx NN% + bar.
function metaRow(w) {
  const prColor = () => {
    const s = w().pr?.status;
    return s === "merged" ? "#B49AEF" : s === "closed" ? RED : GREEN;
  };
  const ctx = () => ctxFill(w());
  return HStack({ spacing: 8 }, [
    Text(() => { const b = w().branch; return b ? (w().dirty ? b + " ●" : b) : ""; })
      .font(11).monospaced().lineLimit(1).truncation("tail")
      .color(() => (w().dirty ? AMBER : "secondary"))
      .help(() => { const b = w().branch ?? ""; return w().dirty ? b + ": uncommitted changes" : b; }),
    Spacer(),
    Text(() => ((w().ports ?? []).length > 0 ? ":" + w().ports[0] : ""))
      .font(11).color("secondary").layoutPriority(2),
    Text(() => (w().pr ? "PR #" + w().pr.number : ""))
      .font(11).color(prColor).layoutPriority(2),
    Text(() => (ctx() > 0 ? "ctx " + Math.round(ctx() * 100) + "%" : ""))
      .font(11).lineLimit(1).layoutPriority(2).color(() => (ctx() >= 0.7 ? ctxColor(ctx()) : "tertiary")),
    If(() => ctx() > 0, () => ctxBar(ctx, 36)),
  ]).frame({ maxWidth: "infinity" });
}

function ctxBar(ctx, width) {
  return HStack({ spacing: 0 }, [
    Rectangle().fill(() => ctxColor(ctx())).frame({ width: () => Math.round(width * ctx()), height: 3 }),
    Rectangle().fill("#8080802E").frame({ width: () => width - Math.round(width * ctx()), height: 3 }),
  ]).cornerRadius(1.5).help(() => "context " + Math.round(ctx() * 100) + "%");
}

function deskMenu(entry) {
  const id = entry.wsId;
  const w = () => wsIndex().get(id) ?? {};
  const items = [
    Button("Focus", () => selectDesk(id)),
  ];
  // Always listed (menus cannot hide items without a remount, see board()).
  // Lands on the asking / just-finished terminal, else the newest live agent's.
  items.push(Button("Jump to terminal", () => {
    const sid = jumpSurface(w(), deskState(w(), now())) || liveAgents(w(), now())[0]?.surfaceId || "";
    if (sid) cmux("surface.focus", { surface_id: sid });
  }));
  const moveItems = groupList()
    .filter((g) => g.id !== entry.groupId)
    .map((g) => Button(() => groupById(g.id)?.name ?? g.name, () =>
      cmux("workspace.group.add", { group_id: g.id, workspace_id: id })));
  if (entry.groupId) {
    if (moveItems.length > 0) moveItems.push(Divider());
    moveItems.push(Button("No group", () => cmux("workspace.group.remove", { workspace_id: id })));
  }
  items.push(
    Button(() => (w().pinned ? "Unpin" : "Pin"), () =>
      cmux("workspace.action", { workspace_id: id, action: w().pinned ? "unpin" : "pin" })),
    Button(() => (isAcked(w()) ? "Un-ack" : "Ack (quiet until next turn)"), () => toggleAck(w())),
    Button("Mark read", () => cmux("workspace.action", { workspace_id: id, action: "mark_read" })),
    Menu("Move to", moveItems),
    Button("Move up", () => cmux("workspace.action", { workspace_id: id, action: "move_up" })),
    Button("Move down", () => cmux("workspace.action", { workspace_id: id, action: "move_down" })),
    Divider(),
    Button("Close", () => closeDesk(id)).destructive(),
  );
  return items;
}

// --- quick replies -----------------------------------------------------------------
// Answer a Your move desk without switching to it. A sidebar has no send-text
// action scope (cmux sidebars may only select/close/split/zoom/navigate/open
// URLs), so a chip puts "say:<surface>:<reply> · " in front of the desk's
// description and bin/fort-board-relay (a launchd agent) types the reply +
// Enter into that terminal, then strips the prefix. The request carries a hash
// of the label it answered and the tap time: the relay drops it when it is
// over two minutes old or the desk's label has changed since (a new ask, or
// "Needs you", where Enter would pick a permission prompt's default). Your move only: a
// "Needs you" permission prompt is a picker, and typed words would pick wrong.
// yes / no only on "Your move?" asks (a bare yes or no answers them); every
// open Your move card also gets ack.
const QUICK_REPLIES = ["yes", "no"]; // keep in sync with REPLIES in bin/fort-board-relay
const asksYesNo = (w) => hookLabel(w).startsWith("Your move? · ");
const sentReply = new Map(); // wsId -> { key, text } until the desk's turn changes
const [sentTick, setSentTick] = signal(0);
function sentFor(w) {
  sentTick();
  const s = sentReply.get(w.id);
  return s && s.key === ackKey(w) ? s.text : "";
}
function sendReply(w, text) {
  const sid = jumpSurface(w, "your_move");
  if (!sid || sentFor(w)) return;
  sentReply.set(w.id, { key: ackKey(w), text });
  setSentTick(sentTick() + 1);
  const d = stripSay(w.description);
  const req = "say:" + sid + ":" + hash36(hookLabel(w)) + ":" + now() + ":" + text;
  cmux("workspace.action", { workspace_id: w.id, action: "set_description", description: req + (d ? " · " + d : "") });
}
function replyChip(w, text) {
  return Text(text).font(11).color("secondary").lineLimit(1)
    .paddingHorizontal(8).paddingVertical(2)
    .background("#8080801F").hoverBackground("#80808040").cornerRadius(9)
    .help("Reply \"" + text + "\" without leaving this tab")
    .onTap(() => sendReply(w(), text));
}

// One-tap ack on an open Your move card (same as the menu item).
function ackChip(w) {
  return Text("ack").font(11).color("tertiary").lineLimit(1)
    .paddingHorizontal(8).paddingVertical(2)
    .background("#8080801F").hoverBackground("#80808040").cornerRadius(9)
    .help("Seen it: hide this desk until its next turn")
    .onTap(() => toggleAck(w()));
}

function deskRow(e) {
  const entry = e(); // wsId, groupId and the menu branches are fixed per key
  const id = entry.wsId;
  const w = () => wsIndex().get(id) ?? { id, title: "", agents: [] };
  const st = computed(() => deskState(w(), now()));
  const since = computed(() => liveSince(w()));
  const sel = computed(() => selectedId() === id);
  const parked = computed(() => isParked(st(), since(), now()));
  const compact = () => parked() && !sel();
  const sub = computed(() => taskSummary(w()));
  const ctx = computed(() => ctxFill(w()));
  const live = computed(() => liveAgents(w(), now()));
  const chipMode = computed(() => {
    if (st() !== "your_move" || compact() || sentFor(w()) !== "") return "";
    return asksYesNo(w()) && jumpSurface(w(), st()) !== "" ? "approve" : "ack";
  });

  const stateLabel = () => (isLive(st()) ? stateText(w(), st(), since(), now()) : "");
  const stateTint = () => { const s = st(); return s === "waiting" || s === "done_old" || s === "stalled" ? "tertiary" : STATE_COLOR[s]; };
  const unreadLabel = () => ((w().unread ?? 0) > 0 ? "● " + w().unread : "");

  // Two lines: title + state/age, then the ask or where it stands. The context
  // bar only shows as a warning (70%+); the selected card gets one meta line
  // (branch · port · PR · ctx) instead.
  return VStack({ spacing: 3 }, [
    HStack({ spacing: 6 }, [
      statusDot(st),
      Text(() => w().title ?? "")
        .font(() => (compact() ? 12 : 13))
        .weight(() => (sel() ? "semibold" : "regular"))
        .color(() => (compact() ? "secondary" : "primary"))
        .lineLimit(1).truncation("tail").layoutPriority(1),
      Spacer({ minLength: 4 }),
      Text(unreadLabel).font(11).color(RED).lineLimit(1).layoutPriority(2),
      Text(stateLabel).font(11).lineLimit(1).color(stateTint).layoutPriority(2),
    ]).frame({ maxWidth: "infinity" }),
    If(() => sub() !== "" && !compact(), () => HStack({ spacing: 6 }, [
      indent(7),
      Text(sub).font(12).color("secondary").lineLimit(1).truncation("tail").help(sub),
      Spacer({ minLength: 0 }),
    ]).frame({ maxWidth: "infinity" })),
    If(() => chipMode() === "approve", () => HStack({ spacing: 5 }, [
      indent(7),
      ...QUICK_REPLIES.map((r) => replyChip(w, r)),
      ackChip(w),
      Spacer({ minLength: 0 }),
    ]).frame({ maxWidth: "infinity" })),
    If(() => chipMode() === "ack", () => HStack({ spacing: 5 }, [
      indent(7), ackChip(w), Spacer({ minLength: 0 }),
    ]).frame({ maxWidth: "infinity" })),
    If(() => sentFor(w()) !== "", () => HStack({ spacing: 6 }, [
      indent(7),
      Text(() => "↳ sent \"" + sentFor(w()) + "\"").font(11).color(GREEN).lineLimit(1),
      Spacer({ minLength: 0 }),
    ]).frame({ maxWidth: "infinity" })),
    If(() => ctx() >= 0.7 && !compact() && !sel(), () => HStack({ spacing: 6 }, [
      indent(7), ctxBar(ctx, CTX_BAR_W), Spacer(),
    ]).frame({ maxWidth: "infinity" })),
    If(sel, () => VStack({ spacing: 4 }, [
      // One row per live agent only; a lone agent is already the desk's status.
      ForEach({ items: () => (live().length > 1 ? live().slice(0, 4) : []), key: (a) => a.id }, (a) => agentRow(a)),
      HStack({ spacing: 6 }, [indent(7), metaRow(w)]).frame({ maxWidth: "infinity" }),
    ]).frame({ maxWidth: "infinity", alignment: "leading" })),
  ])
    .padding(() => (compact() ? 5 : 8))
    .frame({ maxWidth: "infinity", alignment: "leading" })
    .background(() => (sel() ? "#7A4FD82E" : "#FFFFFF02"))
    .hoverBackground(() => (sel() ? "#7A4FD82E" : "#7f7f7f14"))
    .cornerRadius(7)
    .opacity(() => (sel() || isLive(st()) ? 1 : 0.55))
    .marginLeading(() => (e().nested ? 16 : 0))
    .onTap(() => selectDesk(id))
    .contextMenu(deskMenu(entry));
}

// --- views: section header -----------------------------------------------------------
function groupHeader(e) {
  const entry = e();
  const gid = entry.groupId; // null = "Other"
  const key = entry.id;
  const g = () => (gid ? groupById(gid) : null);
  const stats = () => board().stats[gid ?? "other"] ?? { size: 0, needs: 0, move: 0, ready: 0, done: 0 };
  const readyKey = key + ":ready";
  const armedKind = () => (isArmed(key) ? "ended" : isArmed(readyKey) ? "ready" : null);
  const armedNow = () => armedKind() !== null;
  const closable = (which) => closableIn(gid, which ?? armedKind() ?? "ended").length;

  const children = [
    Image("chevron.right").font(9).color("tertiary")
      .rotation(() => (isSectionCollapsed(gid) ? 0 : 90))
      .frame({ width: 10 }),
    Text(() => (gid ? (g()?.name ?? "") : "Other").toUpperCase())
      .font(11).weight("semibold").color("secondary").lineLimit(1).truncation("tail"),
    Text(() => (gid && g() && isLiveAnchor(g()) ? "⚠" : "")).font(10).color(AMBER)
      .help("This section's header is a live session. Rebuild: ungroup, then cmux workspace-group create --name <Name> and re-add members."),
    Text(() => String(stats().size)).font(11).color("tertiary"),
    Spacer(),
    Text(() => (!armedNow() && stats().needs > 0 ? String(stats().needs) : ""))
      .font(11).weight("semibold").color(RED).layoutPriority(2)
      .help(() => stats().needs + " need you"),
    Text(() => (!armedNow() && stats().move > 0 ? String(stats().move) : ""))
      .font(11).weight("semibold").color(AMBER).layoutPriority(2)
      .help(() => stats().move + " your move"),
    Text(() => (!armedNow() && stats().ready > 0 ? String(stats().ready) : ""))
      .font(11).weight("semibold").color(BLUE).layoutPriority(2)
      .help(() => stats().ready + " ready"),
    Text(() => (!armedNow() && stats().done > 0 ? String(stats().done) : ""))
      .font(11).weight("semibold").color(GREEN).layoutPriority(2)
      .help(() => stats().done + " done"),
    Text(() => (armedNow() ? "Tap to close " + closable() : ""))
      .font(11).weight("semibold").color("white")
      .paddingHorizontal(() => (armedNow() ? 6 : 0))
      .paddingVertical(() => (armedNow() ? 1 : 0))
      .background(() => (armedNow() ? RED : null))
      .cornerRadius(5)
      .layoutPriority(3)
      .onTap(() => (armedKind() === "ready" ? armOrClose(readyKey, gid, "ready") : armOrClose(key, gid))),
  ];

  const menu = [];
  menu.push(Button(() => (isSectionCollapsed(gid) ? "Expand" : "Collapse"), () => toggleSection(gid)), Divider());
  // Section order. cmux moves the whole group block via workspace.group.move,
  // and every move pins the resulting order so new desks and drags can't
  // reshuffle it. "Other" has no group and always sits last.
  if (gid) {
    const moveTo = (to) => {
      const list = groupList();
      const i = list.findIndex((x) => x.id === gid);
      const j = to === "end" ? list.length - 1 : to(i);
      if (i < 0 || j < 0 || j >= list.length || j === i) return;
      const next = list.filter((x) => x.id !== gid);
      next.splice(j, 0, list[i]);
      const before = next[j + 1];
      cmux("workspace.group.move", before ? { group_id: gid, before_group_id: before.id } : { group_id: gid, after_group_id: next[j - 1].id });
      setPins(next);
    };
    const pinned = () => groupList().some((g) => g.pin != null);
    menu.push(
      Button("Move up", () => moveTo((i) => i - 1)),
      Button("Move down", () => moveTo((i) => i + 1)),
      Button("Move to top", () => moveTo(() => 0)),
      Button("Move to bottom", () => moveTo("end")),
      Button(() => (pinned() ? "Unpin folder order" : "Pin folder order"), () => setPins(groupList(), pinned())),
      Divider(),
    );
  }
  menu.push(
    Button(() => {
      const n = closable("ready");
      if (armedKind() === "ready") return "Confirm: close " + n + " ready desk" + (n === 1 ? "" : "s");
      return n > 0 ? "Close " + n + " ready desk" + (n === 1 ? "" : "s") + " (captured)" : "No ready desks to close";
    }, () => armOrClose(readyKey, gid, "ready")).destructive(),
    Button(() => {
      const n = closable("ended");
      if (armedKind() === "ended") return "Confirm: close " + n + " ended desk" + (n === 1 ? "" : "s");
      return n > 0 ? "Close " + n + " ended desk" + (n === 1 ? "" : "s") : "No ended desks to close";
    }, () => armOrClose(key, gid)).destructive(),
  );

  return HStack({ spacing: 5 }, children)
    .padding(6)
    .frame({ maxWidth: "infinity", alignment: "leading" })
    .background("#FFFFFF02")
    .fixed()
    .onTap(() => toggleSection(gid))
    .help(() => (isSectionCollapsed(gid) ? "Expand" : "Collapse"))
    .contextMenu(menu);
}

// --- root ------------------------------------------------------------------------
sidebar(() =>
  VStack({ spacing: 0 }, [
    HStack({ spacing: 6 }, [
      Image("building.columns.fill").font(12).color(PURPLE),
      Text("Fort Board").font(12).weight("semibold"),
      Spacer(),
      Text(() => (board().dirtyCount > 0 ? board().dirtyCount + " dirty" : ""))
        .font(11).color(AMBER),
      Text(() => ((data.unreadTotal() ?? 0) > 0 ? data.unreadTotal() + " unread" : ""))
        .font(11).color(RED),
    ]).padding(7).frame({ maxWidth: "infinity", alignment: "leading" }),

    Divider(),

    Reorderable(
      { items: entries, key: (e) => e.id, spacing: 4, onMove: handleMove },
      (e) => (e().kind === "header" ? groupHeader(e) : e().kind === "parked" ? parkedRow(e) : deskRow(e)),
    ).frame({ maxWidth: "infinity" }),
  ]).frame({ maxWidth: "infinity", alignment: "leading" })
);
