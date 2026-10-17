// Headless check for fort-board.js: runs it inside cmux's own JS sidebar
// runtime (SidebarRuntime.js from the app bundle) under node, feeds fake
// workspaces, and asserts on the text the scene emits and the actions it sends.
//
//   node core/cmux/harness.mjs [board.js]
//
// CMUX_SIDEBAR_RUNTIME overrides the runtime path (non-default install).
// Exits 0 when every check passes, 1 on any failure, 2 when the runtime is missing.
import fs from "node:fs";
import vm from "node:vm";
import path from "node:path";
import { execFileSync } from "node:child_process";

const RUNTIME = process.env.CMUX_SIDEBAR_RUNTIME
  ?? "/Applications/cmux.app/Contents/Resources/CmuxSwiftRenderUI_CmuxSwiftRenderUI.bundle/Contents/Resources/SidebarRuntime.js";
const HERE = path.dirname(new URL(import.meta.url).pathname);
const BOARD = process.argv[2] ?? path.join(HERE, "fort-board.js");
const RELAY = path.join(HERE, "..", "bin", "fort-board-relay");

if (!fs.existsSync(RUNTIME)) {
  console.error("cmux sidebar runtime not found at " + RUNTIME + " (install cmux or set CMUX_SIDEBAR_RUNTIME)");
  process.exit(2);
}

const nodes = new Map(); // id -> props
const actions = [];
const errors = [];
const ctx = {
  console,
  __host_applyOps: (json) => {
    for (const op of JSON.parse(json)) {
      if (op.id === undefined) continue;
      const n = nodes.get(op.id) ?? {};
      if (op.props) Object.assign(n, op.props);
      if (op.op === "update") n[op.key] = op.value;
      if (op.op === "create") n.__type = op.type ?? op.kind;
      nodes.set(op.id, n);
    }
  },
  __host_action: (json) => actions.push(JSON.parse(json)),
  __host_log: (s) => errors.push(String(s)),
};
ctx.globalThis = ctx;
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(RUNTIME, "utf8"), ctx);

const T = 1_800_000_000;
const SID = "11111111-2222-3333-4444-555555555555";
const agent = (status, ago, extra = {}) => ({
  id: "a" + Math.random(), status, sinceEpoch: T - ago, lastActivityAt: T - ago, surfaceId: SID, ...extra,
});
const ws = (i, title, agents, label, extra = {}) => ({
  id: "w" + i, index: i, title, group: "g1", agents,
  progress: label === null ? null : { value: 0.3, label }, ...extra,
});
// Same hash as fort-board.js ackKey(): label + "|" + sinceEpoch.
const ackKey = (label, since) => {
  const s = label + "|" + since;
  let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h * 33) ^ s.charCodeAt(i)) >>> 0;
  return h.toString(36);
};
const ACKED = "Your move · Acked ask: answer later";
const workspaces = [
  ws(0, "fort:anchor", [], null, { description: "pin:2" }),
  ws(1, "fort:gist-you", [agent("needs_input", 300)], "Your move · Board gist: waiting on go-ahead", { pr: { number: 42, status: "open" } }),
  ws(2, "fort:gist-done", [agent("needs_input", 120)], "Done · Inventory: order list ready"),
  ws(3, "fort:gist-done-old", [agent("needs_input", 7200)], "Done · Chess tracker: analysis complete"),
  ws(4, "fort:gist-stalled", [agent("idle", 600)], "Stalled · Server deploy: blocked on ssh"),
  ws(5, "fort:interrupted", [agent("idle", 600)], "Cooking"),
  ws(6, "fort:cooking", [agent("working", 30)], "Cooking"),
  ws(7, "fort:permission", [agent("needs_input", 60)], "Needs you"),
  // Done and idle 25h: folds into the section's parked row.
  ws(8, "fort:parked-done", [agent("idle", 90000)], "Done · Old desk: shipped"),
  ws(9, "fort:legacy", [agent("idle", 5000)], null),
  ws(10, "fort:bare-you", [agent("needs_input", 60)], "Your move"),
  ws(11, "fort:ready", [agent("idle", 200)], "Ready to close · Board port: thread closed"),
  // Ack persisted in the description (survives reload): folds, not counted.
  ws(12, "fort:acked", [agent("needs_input", 400)], ACKED, { description: "ack:" + ackKey(ACKED, T - 400) + " · spawn · spawn/acked" }),
  // Stale ack (session took a new turn since): nags again.
  ws(13, "fort:ack-stale", [agent("needs_input", 90)], "Your move · New ask after ack", { description: "ack:zzz" }),
  // Promoted anchor: a live session became g2's header. Must stay a desk + flag.
  ws(14, "fort:promoted-anchor", [agent("needs_input", 100)], "Done · promoted anchor still listed", { group: "g2" }),
  // Ended desk: folds into the section's parked row.
  ws(16, "fort:old-ended", [agent("ended", 90000)], null),
  // Pinned order: g3's anchor sits last by index but pin:1 puts Home first.
  ws(17, "fort:anchor-home", [], null, { group: "g3", description: "pin:1" }),
  // "Your move?" = a bare yes/no answers it: yes / no / ack chips. Plain Your move: ack only.
  ws(18, "fort:approve", [agent("needs_input", 50)], "Your move? · commit the playground files now?"),
  ws(19, "fort:either-or", [agent("needs_input", 55)], "Your move · wait for the report or try something else?"),
  ws(20, "fort:open-q", [agent("needs_input", 58)], "Your move · Refs: what should we review next?"),
  // Gist-less: the Stop hook alone publishes "Done · <first line of the reply>".
  ws(22, "fort:plain-done", [agent("needs_input", 240)], "Done · Plain first line of the reply"),
  // Bare "Done" with no line: subtitle falls back to the last prompt.
  ws(23, "fort:bare-done", [agent("needs_input", 180)], "Done", { latestPrompt: "fix the login form" }),
  // A label the board does not know: shown as the subtitle, state from cmux.
  ws(24, "fort:unknown-label", [agent("needs_input", 360)], "Deploying · step 3 of 5"),
  ws(25, "fort:unknown-old", [agent("idle", 9000)], "Something else entirely"),
];
const set = (k, v) => ctx.__setData(k, JSON.stringify(v));
set("clock", { epoch: T });
set("workspaces", workspaces);
set("groups", [{ id: "g1", name: "Fort", collapsed: false, anchorId: "w0" }, { id: "g2", name: "Work", collapsed: false, anchorId: "w14" }, { id: "g3", name: "Home", collapsed: false, anchorId: "w17" }]);
set("selectedId", "w1");
set("unreadTotal", 0);
try {
  vm.runInContext(fs.readFileSync(BOARD, "utf8"), ctx);
} catch (e) {
  console.error("board threw:", e);
  process.exit(1);
}

const textsNow = () => [...nodes.values()].map((n) => n.text ?? n.content ?? n.label).filter((s) => typeof s === "string");
const texts = textsNow();
const has = (s) => texts.some((t) => t.includes(s));
// Group headers show bare colored numbers; the words live in the tooltip.
const helps = [...nodes.values()].map((n) => n.help).filter((s) => typeof s === "string");
const idsWithText = (t) => [...nodes.entries()].filter(([, n]) => n.text === t || n.content === t || n.label === t).map(([id]) => id);
const checks = [
  ["gist subtitle shown", has("Board gist: waiting on go-ahead")],
  ["Your move state text", has("Your move 5m")],
  ["Done fresh", has("Done 2m")],
  ["Done old keeps its name", has("Done 2h")],
  ["Stalled from hook", has("Stalled 10m")],
  ["interrupted Cooking reads Stalled", texts.filter((t) => t.startsWith("Stalled")).length >= 2],
  ["Needs you state text", texts.includes("Needs you 1m")],
  ["Cooking state text", texts.includes("Cooking 30s")],
  ["header counts your move", helps.includes("6 your move")],
  ["header skips acked desk", !helps.includes("7 your move")],
  ["yes/no ask text shown without the ?", has("commit the playground files now?") && !texts.some((t) => t.startsWith("Your move?"))],
  ["header counts need-you", helps.includes("1 need you")],
  ["legacy desk still Waiting", has("Waiting 1h")],
  ["24h+ Done folds into parked row", !has("Old desk: shipped") && !texts.includes("fort:parked-done")],
  ["ended desk folds into parked row", texts.includes("2 parked") && !has("fort:old-ended")],
  ["Ready state text", has("Ready 3m")],
  ["header counts ready", helps.includes("1 ready")],
  ["close-ready menu item", has("Close 1 ready desk (captured)")],
  ["acked desk folds (ask hidden)", !has("Acked ask: answer later")],
  ["stale ack nags again", has("New ask after ack")],
  ["ack prefix never shown", !texts.some((s) => s.startsWith("ack:"))],
  ["live anchor stays a desk", has("promoted anchor still listed")],
  ["live anchor flags its header", texts.includes("⚠")],
  ["generated anchor stays hidden", !texts.includes("fort:anchor")],
  ["selected card shows plain PR number", texts.includes("PR #42")],
  ["selected card shows ctx", texts.includes("ctx 30%")],
  // Gist-less (default install): the hook's plain labels carry the board.
  ["plain Done label: first reply line as subtitle", has("Plain first line of the reply") && has("Done 4m")],
  ["bare Done label falls back to last prompt", has("fix the login form") && has("Done 3m")],
  // Unknown labels fall back sanely.
  ["unknown label shown as subtitle", has("Deploying · step 3 of 5")],
  ["unknown label: fresh desk reads Done", has("Done 6m")],
  ["unknown label: old desk reads Waiting", has("Something else entirely") && has("Waiting 2h")],
  // Removed features stay removed.
  ["no Next up card, usage or meeting strip", !texts.includes("NEXT UP") && !texts.includes("USAGE")],
  // Quick replies: yes/no only on the "Your move?" ask (w18); ack on every open
  // Your move desk (w1, w10, w13, w18, w19, w20); none on Needs you.
  ["yes/no chips only on the yes/no ask", idsWithText("yes").length === 1 && idsWithText("no").length === 1],
  ["ack chip on every open Your move desk", idsWithText("ack").length === 6],
  ["say prefix never shown", !texts.some((s) => s.startsWith("say:"))],
];
// A chip writes "say:<surface>:<reply> · " for bin/fort-board-relay; the relay
// must read that exact string (same fixed replies, same shape).
const relayParse = (desc) => {
  try {
    return JSON.parse(execFileSync("python3", [RELAY, "--parse", desc], { encoding: "utf8" }));
  } catch (e) {
    return { error: String(e) };
  }
};
{
  actions.length = 0;
  const id = [...nodes.entries()].find(([, n]) => n.help === 'Reply "yes" without leaving this tab')?.[0];
  if (id !== undefined) ctx.__dispatch(id, "tap", "null");
  const say = actions.find((a) => a.method === "workspace.action" && a.params?.action === "set_description");
  const desc = say?.params?.description ?? "";
  checks.push(["chip writes a say request for the relay", desc.startsWith("say:" + SID + ":yes")]);
  checks.push(["chip never calls send_text (no sidebar scope)", !actions.some((a) => a.method === "surface.send_text")]);
  checks.push(["sent confirmation shows", textsNow().some((s) => s.includes('sent "yes"'))]);
  const r = relayParse(desc);
  checks.push(["relay parses the chip's request", r?.surface === SID.toUpperCase() && r?.reply === "yes" && r?.rest === ""]);
  const kept = relayParse("say:" + SID + ":no · spawn · spawn/x");
  checks.push(["relay keeps the rest of the description", kept?.reply === "no" && kept?.rest === "spawn · spawn/x"]);
  checks.push(["relay ignores replies the board never sends", relayParse("say:" + SID + ":rm -rf ~") === null]);
  // Every reply the board renders as a chip must be one the relay delivers.
  const boardReplies = helps.map((h) => /^Reply "(.+)" without leaving this tab$/.exec(h)?.[1]).filter(Boolean);
  const mismatch = boardReplies.filter((q) => relayParse("say:" + SID + ":" + q)?.reply !== q);
  checks.push(["relay replies match the board's QUICK_REPLIES", boardReplies.length === 2 && mismatch.length === 0]);
}
// Ack menu item writes the ack prefix onto the description.
const ackBtn = [...nodes.entries()].find(([, n]) => n.label === "Ack (quiet until next turn)" || n.text === "Ack (quiet until next turn)");
checks.push(["Ack menu item present", !!ackBtn]);
if (ackBtn) {
  actions.length = 0;
  ctx.__dispatch(ackBtn[0], "tap", "null");
  const a = actions.find((x) => x.method === "workspace.action" && x.params?.action === "set_description");
  checks.push(["Ack writes ack:<key> description", /^ack:[0-9a-z]+/.test(a?.params?.description ?? "")]);
}
{
  actions.length = 0;
  const id = [...nodes.entries()].filter(([, n]) => n.help === "Seen it: hide this desk until its next turn").at(-1)?.[0];
  if (id !== undefined) ctx.__dispatch(id, "tap", "null");
  const a = actions.find((x) => x.method === "workspace.action" && x.params?.action === "set_description");
  checks.push(["ack chip writes ack:<key>", /^ack:[0-9a-z]+/.test(a?.params?.description ?? "")]);
  checks.push(["ack never writes a say: request", !actions.some((x) => String(x.params?.description ?? "").startsWith("say:"))]);
}
{
  const fold = [...nodes.entries()].find(([, n]) => typeof n.help === "string" && n.help.startsWith("Ended desks and quiet ones"));
  if (fold) ctx.__dispatch(fold[0], "tap", "null");
  const after = textsNow();
  checks.push(["parked row opens on tap", after.includes("fort:old-ended") && after.includes("fort:parked-done")]);
  checks.push(["opened parked Done row is compact (bare age, no subtitle)", after.includes("1d") && !after.some((s) => s.includes("Old desk: shipped"))]);
}
// Pinned folder order: Home (pin:1) renders first, so the first header's menu is Home's.
{
  const btns = (label) => idsWithText(label);
  const descs = () => Object.fromEntries(actions.filter((a) => a.params?.action?.endsWith("_description")).map((a) => [a.params.workspace_id, a.params.description ?? ""]));
  checks.push(["host pins read (menu offers Unpin)", btns("Unpin folder order").length === 3]);
  actions.length = 0;
  ctx.__dispatch(btns("Move down")[0], "tap", "null");
  const mv = actions.find((a) => a.method === "workspace.group.move");
  checks.push(["pinned section sorts first (Move down acts on Home)", mv?.params?.group_id === "g3" && mv?.params?.before_group_id === "g2"]);
  const d = descs();
  checks.push(["move re-pins the new order, skips live anchor", d.w0 === "pin:1" && d.w17 === "pin:2" && !("w14" in d)]);
  actions.length = 0;
  ctx.__dispatch(btns("Unpin folder order")[0], "tap", "null");
  const u = descs();
  checks.push(["unpin clears both anchors", u.w0 === "" && u.w17 === "" && actions.filter((a) => a.params?.action === "clear_description").length === 2]);
  checks.push(["menu flips to Pin after unpin", btns("Pin folder order").length === 3]);
}
// Collapse: header tap folds the group through cmux, members disappear at once.
{
  actions.length = 0;
  const hdr = [...nodes.entries()].find(([, n]) => n.text === "FORT" || n.content === "FORT");
  const headerRow = hdr ? [...nodes.entries()].find(([, n]) => n.help === "Collapse" && n.__type !== "button") : null;
  if (headerRow) ctx.__dispatch(headerRow[0], "tap", "null");
  const c = actions.find((a) => a.method === "workspace.group.collapse");
  checks.push(["header tap collapses its group", !!c]);
}
let bad = 0;
for (const [name, ok] of checks) {
  console.log((ok ? "PASS " : "FAIL ") + name);
  if (!ok) bad++;
}
console.log("\n" + (checks.length - bad) + "/" + checks.length + " passed");
if (errors.length) console.log("host log:", errors.slice(0, 5));
if (bad) {
  console.log("\ntexts seen:\n" + [...new Set(texts)].filter(Boolean).join("\n"));
  process.exit(1);
}
