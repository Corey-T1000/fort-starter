<p align="center">
  <img src="assets/logo-hero.svg" alt="fort-starter — persistent AI workspaces" width="440">
</p>

A template for building a persistent AI workspace on top of [Claude Code](https://docs.anthropic.com/en/docs/claude-code). It gives an AI agent persistent memory, enforced rules, and specialized tools -- all inside a git repo that you control. It's not a framework. It's a workspace template you fork and make your own.

This was extracted from a personal setup that's been in daily use since December 2025. The patterns here aren't theoretical -- they've survived five months of real work across dozens of projects.

> _Heads up: this is a WIP and an ever-evolving project. The setup it was extracted from changes weekly, and this template tracks along with it. Pin a commit if you need stability._

---

## Why infrastructure, not just a prompt

Claude Code reads a `CLAUDE.md` file at the root of your project and follows the instructions in it. This works surprisingly well -- about 95% of the time. That last 5% is the problem.

Instructions in CLAUDE.md are **probabilistic**. The model follows them with high reliability, but not certainty. Shell hooks are **deterministic**. They run every time, with no exceptions.

Here's a concrete example. You could put this in your CLAUDE.md:

```markdown
## Security
- Never commit .env files or files containing API keys
- Always use specific file paths with git add, never git add .
```

And Claude will follow it. Almost always. But "almost always" isn't good enough for security. So instead, this workspace includes a shell hook:

```bash
#!/bin/bash
# guard-env-files.sh -- Blocks Write/Edit to .env, credentials.json, *.pem, *.key
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
BASENAME=$(basename "$FILE")
case "$BASENAME" in
    .env|.env.*|credentials.json|*.pem|*.key)
        # Return a hard deny -- Claude cannot bypass this
        echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",
          "permissionDecisionReason":"Blocked: writing to sensitive file. Manage manually."}}'
        ;;
esac
```

The hook fires on every file write, every time, regardless of what the model decides. CLAUDE.md handles the 95% -- shaping behavior, setting tone, defining workflows. Hooks handle the 5% where failure isn't acceptable.

This distinction -- probabilistic vs. deterministic -- is the organizing principle behind everything in this repo.

---

## Framing — the 'fort' is a bit of a dim factory (and why we like the big lights off)

the fort runs with real autonomy. hooks fire without asking, memory auto-loads, `/distill` queues itself after sessions, agents dispatch other agents. cost accumulates live in the statusline while work happens in parallel worktrees.

manufacturing has a term for a plant that runs lights-out with no humans on the floor: the "dark factory." the fort isnt that. its more like a *dim* factory — mostly autonomous, with me in the loop for anything consequential, and the autonomous bits set up to fail safe.

**Why im OK with this split for my uses:**

- **Single user, local first.** the fort runs on my machine. no one elses data, no one elses workflow, no one elses deploy pipeline. blast radius is me.
- **Git is the safety net.** every autonomous action lands in a diff i can see and revert. hooks never auto-commit to main. agents never push without my hand on the trigger.
- **Layered trust, anchored in SpiceBox.** three fences: tool scope at the agent layer (the reviewer literally doesnt have `Write` in its tool list), hooks at the intercept layer (blocking risky commands before they run), and SpiceBox at the kernel layer (OS sandbox handling filesystem scope and network allowlists). SpiceBox is the actual trust boundary, the line an agent cant cross. before SpiceBox was in the stack, hooks carried the whole trust story — which worked, right up until a hook pattern had a gap and something slipped through. hooks still do good work above SpiceBox (behavior, workflow, the probabilistic-to-deterministic promotion from Pattern 1). but they arent the right place to land your final trust decision.
- **Observable.** statusline shows cost live. audit trails capture what happened. Fort Board surfaces every parallel session so i never lose track of whats running.
- **Failures are loud.** silent failure is the enemy — its burned me once and theres a retro about it. any autonomous step that fails pings Discord, watchdogs escalate, no-ops show up in the status.
- **Right-sized stakes.** nobodys healthcare depends on this. a scheduled job missing a run is annoying, not catastrophic. the autonomy envelope matches the consequences.

would i hand this setup to someone running a production financial system? no. would i run it on a shared corporate box with team data? also no. but for a solo-designer-who-codes-through-AI building personal tools and exploring? yeah, and the productivity compound from handing off the routine stuff is kinda the whole point.

**The honest risk:** a dim factory trusts its envelope. if the envelope cracks (a hook silently breaks, a scope gate has a bug, an agent escapes its tool list) damage can happen fast because no ones watching. thats why the observable layer (statusline + audit trail + Fort Board) is load-bearing — without it you cant run dim at all.

---

## The invisible-infrastructure check

running **42 hooks, 87 memory topics, a kernel-level sandbox, a routing table that auto-loads context on file paths, and workers dispatching on three model tiers in the background**. you'd expect friction. there isnt any.

- hooks that deny run silently on the 95% of commands they dont care about. the 5% they catch, i was gonna regret anyway.
- memory auto-loads on the first file edit that matches a route — zero extra reads, no UI, no prompt. i find out it loaded when the agent mentions a gotcha before i hit it.
- workers dispatch in the background on their own model tiers. i dont think about which model is running, the agent picks.
- SpiceBox enforces at the syscall layer. unless im trying to escape the project root, i never feel it.
- `/distill` runs after the session closes, not before. whatever i was doing is already saved by the time extraction starts.

if any of it felt heavy i wouldnt still be using it 5 months later. the design spec for each layer is "do the work, stay out of the way." most of the receipts below (hook count, memory count, stream entries) i only know because i just counted them for this doc.

---

## The five layers

```
                               ⚑
                               │
┌─────────────────────────────────────────────────────────────┐
│  5. CLI            bin/                  Shell utilities     │
├─────────────────────────────────────────────────────────────┤
│  4. Skills         skills/               Slash commands      │
├─────────────────────────────────────────────────────────────┤
│  3. Memory         memory/ + MEMORY.md   Persistent context  │
├─────────────────────────────────────────────────────────────┤
│  2. Hooks          .claude/hooks/        Deterministic rules  │
├─────────────────────────────────────────────────────────────┤
│  1. Config         CLAUDE.md + rules/    Identity & behavior  │
└─────────────────────────────────────────────────────────────┘
```

> The logo is the stack. Five pieces, darkest at the foundation, lightest at the top. The door is an invitation.

### 1. Config -- CLAUDE.md + rules/

Your CLAUDE.md is the agent's identity document. It tells Claude who it's working with, how to communicate, what workflows exist, and where things live. The `rules/` directory breaks this into focused files (output style, tool routing, guardrails) that Claude Code loads automatically. Think of it as the probabilistic layer -- behavioral guidance that shapes 95% of interactions.

### 2. Hooks -- .claude/hooks/

Shell scripts that Claude Code executes at defined trigger points: before a tool runs (`PreToolUse`), after it runs (`PostToolUse`), or when a session ends (`Stop`). Each hook returns a JSON decision -- `allow`, `deny`, or `ask` (prompt the user). The starter includes ~23 hooks across security, workflow, and quality categories. The setup this was extracted from runs 42.

### 3. Memory -- memory/ + MEMORY.md

Topic files organized with [Johnny Decimal](https://johnnydecimal.com/) numbering. `MEMORY.md` is a routing table that maps file paths to memory files -- when you start editing files in `projects/dashboard/`, the agent automatically loads `memory/60-dashboard.md` with prior context. Memory files hold operational knowledge: architecture decisions, API gotchas, deployment details. Knowledge that would otherwise be lost at the end of every session.

### 4. Skills -- skills/

Markdown files that define slash commands -- `/distill`, `/research`, `/garden`, `/eod`. Each skill is a structured prompt that Claude loads on demand (not on every session). Skills keep specialized workflows out of your base context window. You invoke them with `/skill-name` and they guide multi-step processes. The vanilla profile ships **17 user-invocable skills in `profiles/vanilla/commands/`** plus **13 plugin skills in `core/plugins/fort/skills/`** (loaded by skill name, not as slash commands). (See "The skill stack" section below for the full taxonomy and how they compose.)

### 5. CLI -- bin/

Shell utilities that support the workspace from outside Claude Code. Status dashboards, notification wrappers, memory linting, session streaming. These run in your terminal, in cron jobs, or get called by hooks. They're the glue between the AI workspace and your existing dev environment.

---

## Three patterns worth stealing

Even if you don't use this template, these patterns transfer to any AI coding setup.

### Pattern 1: Hook taxonomy

Not all hooks serve the same purpose. Categorizing them by intent makes the system easier to reason about and extend.

**Security hooks** -- Hard deny. Cannot be bypassed.

| Hook | What it does |
|------|-------------|
| `guard-env-files.sh` | Blocks writes to `.env`, `credentials.json`, `*.pem`, `*.key` |
| `guard-secrets.sh` | Scans file content for API key patterns and blocks the write |
| `guard-git-add.sh` | Flags `git add .` and `git add -A` -- forces specific file staging |

**Workflow hooks** -- Automation. Silently modify or augment agent actions.

| Hook | What it does |
|------|-------------|
| `enforce-draft-pr.sh` | Injects `--draft` into every `gh pr create` command |
| `format-commit-msg.sh` | Validates conventional commits format |

**Quality hooks** -- Catching mistakes before they ship.

| Hook | What it does |
|------|-------------|
| `guard-push-rebase.sh` | Blocks push if your branch is behind remote |
| `stop-lint-check.sh` | Runs linter on recently modified files before session ends |

The mental model: **if you'd be upset when it fails, make it a hook.**

This workspace uses [SpiceBox](https://github.com/authzed/spicebox) alongside these hooks. Hooks handle the behavioral side -- what the agent should and shouldn't do. SpiceBox handles the permission side -- what the agent *can* and *can't* do at the OS and network level. Different layers, same goal.

### Pattern 2: Memory routing

The memory system solves a specific problem: Claude Code sessions are stateless. Every new session starts fresh. Memory routing makes context loading automatic instead of manual.

`MEMORY.md` contains a routing table:

```markdown
| Path prefix              | Memory file            | Tab title           |
|--------------------------|------------------------|---------------------|
| projects/dashboard/      | memory/60-dashboard.md | workspace:dashboard |
| projects/api/            | memory/61-api.md       | workspace:api       |
| deploy/                  | memory/50-infra.md     | workspace:infra     |
```

When the agent first edits a file matching a path prefix, it loads the corresponding memory file:

```markdown
# 60 -- Dashboard

## Known gotchas
- The chart library silently drops data points over 10k rows
- CSS grid gap doesn't work in the kiosk browser -- use margin instead

## Recent decisions
- 2025-03-15: Switched from polling to SSE for live updates (reduced CPU 40%)
```

**How to write good memory files:**
- Record the "why," not just the "what." Future sessions can read the code for "what."
- Capture gotchas -- the things that cost you 30 minutes to debug once and would cost 30 minutes again.
- Include dates on decisions so you know how stale the context is.

### Pattern 3: Probabilistic vs. deterministic

The decision framework for everything in the workspace:

| If failure means... | Then use... | Example |
|---|---|---|
| Nothing serious | CLAUDE.md instruction | "Use conventional commit messages" |
| Annoying but recoverable | Hook with `ask` | "Confirm before deploying" |
| Genuinely bad | Hook with `deny` | "Never write API keys to files" |

Rules of thumb:

- **Security** is always a hook. No exceptions.
- **Style and tone** are always CLAUDE.md. Hooks can't judge prose quality.
- If you find yourself repeating a CLAUDE.md instruction because it keeps getting ignored, that's a sign it should be a hook.

---

## Worker agent profiles — cost discipline through model routing

This is the single biggest unlock in the setup this was extracted from, and it directly answers the "this workflow burns tokens" concern.

Claude Code lets you define named sub-agents with specific models and tool scopes. The starter ships four:

| Agent | Model | Tools | Dispatch for |
|-------|-------|-------|--------------|
| `worker-mechanical` | Haiku | Read, Grep, Glob, Bash | Fact lookups, file existence, config values |
| `worker-research` | Sonnet | +Write, WebSearch, WebFetch | Investigation, competitive research, codebase exploration |
| `worker-editor` | Sonnet | +Edit, Write | Scoped code changes from a brief |
| `worker-reviewer` | Opus | Read, Grep, Glob, Bash | Senior review, security audit, pre-merge verification |

**Why this matters for cost:**

A naive setup runs every sub-agent on the coordinator's model. If your coordinator is Opus, every "what port does this service use?" lookup burns Opus tokens. That's 10-20x more expensive than Haiku for a task Haiku nails.

Routing by job keeps the bill honest:

- **Mechanical** (Haiku) — cheap and fast, for tasks where the answer shape is "a fact"
- **Research / Editor** (Sonnet) — the workhorse tier, good judgment at a reasonable rate
- **Reviewer** (Opus) — reserved for senior-level review where cost is worth it

**Why this matters for safety:**

Each agent's tool list is a scope gate. The reviewer can't write files — the definition doesn't include `Edit` or `Write`, so the tool isn't available at all. The editor can't run web searches. The mechanical worker can't touch the internet. Behavior-by-construction, not behavior-by-instruction.

Pair this with SpiceBox for OS-level permission enforcement (different filesystem scopes per agent, network allowlists, sandboxing) and you get defense-in-depth without writing a single hook.

**Where they live:**

`core/agents/*.md`. Bootstrap copies them to `.claude/agents/`. Edit, add, or delete — the four here are starting points, not prescriptions.

---

## The compounding loop — a workspace that teaches itself

The infrastructure above is the scaffolding. What makes the setup actually compound over time is a handful of skills that feed signal back into the system. The Fort is semi self-improving — every session leaves the next session smarter.

A typical session generates a lot of signal: decisions, gotchas, research findings, surprises. Without a capture layer, that signal evaporates when the session closes. The "Knowledge capture" skills in the section below exist to turn sessions into durable context. Memory then loads on demand via the routing table (see Pattern 2 above). Next session's context window is pre-loaded with everything relevant before you type a word.

**The loop has two tiers:**

1. **Knowledge loop (fast).** Research → capture → memory → auto-load next session. Days.
2. **Infrastructure loop (slow).** When a CLAUDE.md instruction keeps getting ignored, promote it to a hook. When a multi-step workflow stabilizes across several sessions, extract it into a skill. When a failure mode bites twice, write a memory entry with the fix. Weeks to months.

Five months in, the compound is real. New sessions on known topics start productive in seconds because the gotchas, decisions, and architectural patterns are already loaded. The template you're looking at is itself the output of that loop — patterns that earned their way in by proving useful across dozens of real projects.

Your fork will do the same for your work.

---

## The skill stack — core verbs and how they compose

Skills are slash commands that wrap a specific workflow. The starter ships a bunch — grouped below by when they fire.

### Daily rhythm

Skills that bracket the day. These set and close context so sessions start and end cleanly.

| Skill | When it fires | What it does |
|-------|--------------|--------------|
| `/bod` | start of day | Reads last session log, recent git, open PRs, parking-lot. Sets focus for the day. |
| `/pulse` | mid-session breaks | Lightweight status check — mail, workers, reminders. One-line summary. |
| `/briefing` | "catch me up" | Longer rollup across all persistence layers when returning from time away. |
| `/eod` | end of day | Reviews the day, writes daily log, surfaces tomorrow's focus, runs `/distill`. |

### Work skills (divergent → convergent)

Skills that do the actual work.

| Skill | Phase | What it does |
|-------|-------|--------------|
| `/research` | explore | Dispatches `worker-research` to investigate a topic, writes structured findings to `scratch/research/`. |

> The vanilla profile keeps the work-skill set narrow on purpose — `/research` plus the daily-rhythm and capture skills cover the core loop. Other workflow skills referenced in flows below (`/brainstorming`, `/writing-plans`, `/executing-plans`, `/design-lab`, `/review-pr`, `/ship`) are part of Corey's full Fort and are **not bundled in vanilla**. Add them via fork, install from the upstream Fort, or wait for upcoming PRs that promote stabilized skills into the starter.

### Knowledge capture (the compounding loop)

Skills that feed signal back into memory — the layer that turns sessions into durable context.

| Skill | What it captures |
|-------|-----------------|
| `/capture` | Research findings → routed to right JD memory file |
| `/note` | Quick mid-session observation → memory or scratch |
| `/park` | "Not now but later" → parking-lot |
| `/distill` | Session-end extraction → memory |
| `/compound` | Feature-level `/distill` — patterns, surprises, decisions (plugin skill) |
| `/retro` | Post-incident deep zoom — what happened, what surprised, what to change |
| `/garden` | Periodic maintenance — stale memory, orphaned scratch, broken refs |

> `/devlog` and `/weekly-review` referenced elsewhere in the docs are not bundled in vanilla — add via fork or wait for upcoming PRs.

### `/assistant` — the persistent dispatcher

`/assistant` is the one that ties it all together. It's not a task runner, it's a *conversational partner* that holds the thread while routing work out to everything above.

**What it does:**

- Keeps the main conversation responsive — heavy lifting goes to sub-agents via dispatch
- Routes casual-language intent to the right skill ("check my calendar" → `/calendar`, "what's the status" → `/pulse`)
- Writes a per-assistant state file to `scratch/assistants/<slug>.md` so focus survives compaction
- Announces what skill it's reaching for before dispatching ("reaching for `/research` here")

**Different modes it runs in:**

- **Dispatch mode (default).** You talk, it routes. Calls `/research` / `/capture` / `/note` on your behalf and results come back into the conversation.
- **Task-taker mode.** When a brain dump starts — "oh also i need to..." items — it captures to `notes/task-dump.md` with timeline buckets (Now / This Week / Later / Someday) instead of derailing focus.
- **Multi-assistant.** Supports 2-4 parallel `/assistant` sessions — one focused, one always-on for random asks, a third while waiting on sub-agents. Each is keyed by focus slug. No cross-session bleed.
- **Named resume.** `/assistant dashboard` re-enters the named assistant at `scratch/assistants/dashboard.md` with full prior context. Ultra-light if < 4hrs old, standard resume otherwise.

**How the skills interact through `/assistant`:**

```
               ⚑
               │
   ┌─ /bod ────┴──────────── sets daily context
   │
   └─► /assistant ──────────── you talk to this all day
          │
          ├─ routes to ─► /research     (dispatch to worker-research)
          ├─ routes to ─► /pulse        (lightweight status check)
          ├─ routes to ─► /briefing     (longer rollup, "catch me up")
          ├─ routes to ─► /switch       (context switch between projects)
          │
          ├─ captures  ─► /note / /park / /capture (mid-thread)
          ├─ tracks    ─► task-dump (brain dump capture)
          │
   ┌─────┘
   │
   └─► /eod → /distill ────── closes the session, writes to memory
          │
          └─► next session starts with that memory auto-loaded
```

> Flows below also show `/design-lab`, `/review-pr`, `/ship`, and the `/brainstorming → /writing-plans → /executing-plans` chain. Those skills are not bundled in the vanilla profile — they live in the upstream Fort and may land in future PRs. The flows are kept here as illustrations of how `/assistant` can route once you add them.

The whole point of `/assistant` is that you don't have to remember which skill to reach for. Say what you want in natural language and it picks the right one (or asks if it's ambiguous). The skills are the individual tools, `/assistant` is the one that knows which tool fits the job.

---

## Receipts — five months in

The setup this was extracted from, today:

| Thing | Count |
|-------|-------|
| Hooks running | **42** (security / workflow / quality) |
| Memory topic files | **87** (JD-indexed) |
| Agents | **12** (4 worker profiles + 8 skill-specialized) |
| Skills invokable | **45+** |
| Commits since Dec 2025 | **229** |
| Session logs captured | **53** |
| Semantic stream entries (decisions / deploys / ships / research captured via `fort-stream`) | **284** |
| Concurrent worktrees running on any given day | **2–4** |

The starter ships lighter on purpose — **23 hooks, 17 skills, 4 worker agents**. It grows with you, not at you.

**Model routing — the pricing that makes worker agents a cost lever:**

| Model | Input (per 1M tokens) | Output (per 1M tokens) | Vs Opus |
|-------|----------------------|------------------------|---------|
| Haiku 4.5 | $1 | $5 | **15× cheaper** |
| Sonnet 4 | $3 | $15 | **5× cheaper** |
| Opus 4 | $15 | $75 | baseline |

On Max plan subscriptions the routing shows up as **headroom**, not dollars saved — every token not burned on a Haiku-sized task is a token available for another parallel dispatch or a longer iteration cycle before hitting usage ceilings. On API billing the same routing is a ~15× discount on that slice of the bill.

---

## What it actually looks like

### Setup

```
$ git clone https://github.com/your-username/fort-starter.git my-workspace
$ cd my-workspace
$ ./fort-bootstrap --profile=vanilla

fort-starter bootstrap v1.0

  Profile:  vanilla (minimal starter)
  Target:   ./

  Assembling workspace...
  [ok] CLAUDE.md written
  [ok] .claude/hooks/ -- 23 hooks installed
  [ok] .claude/agents/ -- 4 worker agents (Haiku/Sonnet/Opus routed)
  [ok] memory/ -- starter structure created
  [ok] skills/ -- 17 starter skills linked
  [ok] bin/ -- utilities installed (including statusline.sh)
  [ok] settings.json configured

  Ready. Run `claude` to start your first session.
```

### Memory auto-loading

```
$ claude

> I need to update the dashboard's chart component to handle empty datasets

  Loaded memory for dashboard (60).

  Note from memory: the chart library silently drops data points over 10k rows.
  Your empty dataset case might hit the same codepath. Let me check.
```

### Hook blocking a mistake

```
> Let me commit these changes

  $ git add .

  Hook: guard-git-add.sh
  Broad git add detected. This could stage .env files, credentials,
  or large binaries. Consider adding specific files instead.

  Good catch. Let me add the specific files instead.
  $ git add src/components/Chart.tsx src/lib/data.ts
```

---

## Flows — real sessions that show the value

Eight scenarios, each showing a specific value prop. Expand the ones that interest you.

<details>
<summary><b>Flow 1 — Memory auto-load saves the re-learning tax</b></summary>

**Situation:** opening a session on a project i havent touched in 3 weeks. the chart component needs an update.

**Flow:**
```
$ claude
> hey need to update the chart on the dashboard

  Loaded memory for dashboard (60).
  Note from memory: chart library silently drops data points over 10k rows.
  Also: CSS grid gap breaks in the kiosk browser — use margin.
```

**Payoff:** no re-learning. the two gotchas that wouldve cost me 45 min of "wait why is this broken" are loaded before i type anything.

</details>

<details>
<summary><b>Flow 2 — Worker agent routing keeps a research-to-ship session efficient</b></summary>

**Situation:** building a new section for the marketing site. need competitive research, then design exploration, then implementation, then review.

**Flow:**
```
> research how other permission-system companies handle first-session
  onboarding

  [dispatches worker-research on Sonnet]
  [returns 15 min later with notes at scratch/research/onboarding-comp.md]

> /design-lab for 5 variations of the onboarding hero

  [dispatches 5 variations to scratch/design-lab/]
  [pick winner]

> /brainstorming → /writing-plans → /executing-plans

  [editor worker on Sonnet scoped to projects/web/]

> /review-pr

  [4-pass review, reviewer on Opus]
  [flags one a11y issue, one copy nit]

> /ship
```

**Payoff:** mechanical lookups hit Haiku (~15× cheaper per token than Opus). editor on Sonnet (5× cheaper). only the reviewer burns Opus, and only for the ~10 min review window. on Max the savings show up as headroom; on API as a ~10× bill cut for the same output.

</details>

<details>
<summary><b>Flow 3 — The recurring gotcha that graduated into a hook</b></summary>

**Situation:** kept having claude commit directly to `main` instead of the feature branch when working in worktrees. added a CLAUDE.md instruction. it got ignored ~1 in 8 times anyway.

**Flow:**
```
[week 1] "always check you're on the right branch before commit"
         in CLAUDE.md
[week 2] it happened again
[week 3] it happened AGAIN
[week 3] wrote guard-worktree-branch.sh:
         - PreToolUse hook on Bash
         - if command matches `git commit` AND cwd is a worktree
           AND HEAD is main/master → deny with message
[week 4+] never happened again
```

**Payoff:** CLAUDE.md was saying "dont do X" and ~1/8 times it did X anyway. the hook made "dont do X" into "cant do X." havent force-pushed to main since.

</details>

<details>
<summary><b>Flow 4 — Research once, benefit for months</b></summary>

**Situation:** spent 2 hours reverse-engineering a sketchy vendor API. cookies, session tokens, undocumented endpoints.

**Flow:**
```
[session 1]
> /research the vendor API auth flow

  [worker-research dispatches, 90 min of back-and-forth]
  [findings land in scratch/research/vendor-api.md]

> /capture

  "Save findings? Routes to memory/67-vendor-apis.md (JD 67)."
  [yes]

[3 months later, new session touching projects/vendor-client/]

  Loaded memory for vendor-apis (67).
  Auth flow: login → /api/v2/sessions → cookie → CSRF header required.
  Gotcha: session expires silently after 20 min, re-auth without prompt.
```

**Payoff:** three months later, starting a new integration, i dont re-derive any of it. the silent-expiration trap especially — if i hit that fresh it wouldve been another long afternoon.

</details>

<details>
<summary><b>Flow 5 — Design lab for UI direction</b></summary>

**Situation:** tasked with refreshing a page but not sure which direction to go. i have opinions but want to see variations before committing.

**Flow:**
```
> /design-lab for the homepage hero — 5 directions, varied

  [generates 5 HTML variations in scratch/design-lab/homepage/]
  [each has a different typographic + layout approach]

> [open all 5 in browser, compare]
> "i like #3's typography and #1's layout combined"

> /design-lab synthesize 3+1

  [generates a synthesis, writes an implementation plan]

> /executing-plans
```

**Payoff:** got to see a few directions before committing. if id just built what came to mind first id have landed somewhere safe, fine, forgettable. this way i have the ability to Nx my concepts in and find novel ideas.

</details>

<details>
<summary><b>Flow 6 — Multi-pass review catches what one pass missed</b></summary>

**Situation:** solo project, no team review. built a new sync pipeline. want to ship but unsure of quality.

**Flow:**
```
> /review-pr

  [dispatches 4 specialized agents in parallel:]
  [- security-auditor on Opus: checks secrets, injection, permissions]
  [- code-reviewer on Opus: correctness, style, patterns]
  [- verifier on Sonnet: runs tests, lints, type-checks]
  [- context-checker on Sonnet: reads memory for this area, flags drift]

  [synthesizes report — 1 critical, 3 suggestions]
  [critical: race condition in the token refresh, exact file:line]

> fix critical, suggestions deferred

> /ship
```

**Payoff:** caught a race condition in the token refresh that i never wouldve spotted. four agents looking at the same code from different angles, one found it. costs more than skipping review, costs way less than a prod race condition.

</details>

<details>
<summary><b>Flow 7 — The compounding payoff at month 5</b></summary>

**Situation:** month 5 of the setup. starting a new feature on a project i havent touched in 10 weeks.

**Flow:**
```
> claude
> need to add a new sync strategy to the pipeline

  Loaded memory for data-pipelines (57).
  Recent decisions: 15min poll interval, exponential backoff on 429s.
  Active bug: timestamp field gets truncated to seconds in postgres —
   use stored_at_ms for millisecond precision.
  Known gotchas: 8 listed.
```

**Payoff:** "new session on old topic" used to feel like "oh no, i have to page everything back in." now it feels like "cool, what are we doing today." five months in, this is the biggest shift in how i work.

</details>

<details>
<summary><b>Flow 8 — /distill catches what i didnt know was worth saving</b></summary>

**Situation:** end of a long debugging session. fixed the bug, exhausted.

**Flow:**
```
[stop hook detects session ended without /distill, queues for next session]

[next session start]
  Previous session queued distill.
  [runs /distill as background agent]

  Captured to memory/57-data-pipelines.md:
  - the scraper was dropping rows silently when upstream API returned 429
  - root cause: retry loop didnt log exhaustion
  - fix: alert on all-keys-exhausted (commit abc1234)
  - gotcha: exhaustion alerts once per container lifecycle, not per run
```

**Payoff:** i wasnt gonna remember any of that. the commit has the fix. the WHY — "silent drop" as a signature, the specific retry loop behavior — wouldve been gone by next month. distill caught it without me having to sit down and write a postmortem.

</details>

---

## Getting started

### 1. Clone and bootstrap

```bash
git clone https://github.com/your-username/fort-starter.git my-workspace
cd my-workspace
./fort-bootstrap --profile=vanilla
```

### 2. Start your first session

```bash
claude
```

### 3. What to do first

**Create your first memory file.** Pick a project you're actively working on. Create `memory/60-your-project.md` and write down three things: what the project is, one architecture decision you've made, and one gotcha you've hit. Add a route to `MEMORY.md`. Now every future session that touches that project starts with context.

**Customize your CLAUDE.md.** The vanilla profile gives you a minimal starting point. Add your communication preferences, your workflow conventions, your project structure. This is the single most impactful file in the workspace -- spend time on it.

**Write your first hook.** Start with something simple. Copy an existing hook from `.claude/hooks/`, modify the pattern matching, and change the response message. See the [Claude Code hooks documentation](https://docs.anthropic.com/en/docs/claude-code/hooks) for the full API.

**Explore the skills.** Type `/` in Claude Code to see available slash commands. Try `/research` for deep investigation, `/distill` at the end of a session to capture what you learned.

### 4. Growing the workspace

- **Week 1**: Customize CLAUDE.md, create 2-3 memory files for active projects
- **Week 2**: Write your first custom hook, start using `/distill` to capture session learnings
- **Month 1**: Build project-specific skills, establish your memory routing table
- **Month 2+**: The workspace reflects how you think. New sessions start productive immediately because the memory system carries forward what matters.

---

## Project structure

The repo ships **sources** under `core/` and `profiles/`. Running `fort-bootstrap` assembles those into the live `.claude/`, `plugins/`, `memory/`, and `bin/` directories your sessions actually use.

```
my-workspace/
├── CLAUDE.base.md             # Base CLAUDE.md template (copied to CLAUDE.md by bootstrap)
├── fort-bootstrap             # Setup script: assembles core + profile → live workspace
├── core/                      # Canonical sources (don't edit live copies — edit here)
│   ├── agents/                # Worker agent profiles (model routing + tool scoping)
│   ├── bin/                   # Shell utilities (includes statusline.sh)
│   ├── hooks/                 # Shell scripts -- deterministic enforcement
│   ├── plugins/               # Plugin sources (e.g., core/plugins/fort/skills/)
│   └── rules/                 # Focused instruction files (auto-loaded)
├── profiles/
│   └── vanilla/               # Minimal starter profile
│       ├── CLAUDE.md          # Profile-specific CLAUDE.md addendum
│       ├── settings.json      # Profile-specific settings
│       ├── commands/          # User-invocable slash commands (17 in vanilla)
│       ├── plugins/           # Per-profile plugin overrides (extension point)
│       └── hooks-disabled/    # Per-profile hook opt-outs (extension point)
├── memory/                    # Persistent knowledge (JD-numbered topic files)
├── notes/                     # Scratch notes, parking lot
├── logs/                      # Session logs (auto-generated)
├── projects/                  # Your active codebases
└── assets/                    # Logo and brand assets
```

### Customizing your profile

Two extension points let you adapt a profile without touching `core/`:

- **`profiles/<name>/plugins/<plugin-name>/`** — drop a plugin subdirectory here to **override or extend** the same-named plugin under `core/plugins/`. During bootstrap, profile plugins win over core plugins of the same name. Use this when you want a profile-specific variant of a shared plugin.
- **`profiles/<name>/hooks-disabled/<hook-name>.sh`** — `touch` an empty file with the same name as a `core/hooks/<hook-name>.sh` file to **opt this profile out** of that hook. Bootstrap skips any hook that has a matching disabled marker. Use this when a core hook doesn't fit the profile (e.g., disabling a betting-domain hook in a non-betting profile).

Both are searched at bootstrap time — no further wiring needed. Add files, re-run `./fort-bootstrap --profile=<name>`, done.

---

## FAQ

**How is this different from just writing a good CLAUDE.md?**
A good CLAUDE.md gets you 80% of the way. The remaining 20% -- security enforcement, automatic memory loading, session-to-session knowledge transfer, workflow automation -- requires infrastructure around it.

**Does this work with other AI coding tools?**
The concepts (persistent memory, hook-based enforcement, skill-based workflows) are transferable. The implementation is specific to Claude Code's hook system and CLAUDE.md conventions.

**How much does this cost in context window?**
CLAUDE.md and rules load on every session -- budget ~2-3k tokens. Memory files load on demand. Skills load only when invoked. Designed to minimize baseline context usage.

**What about overall token usage?**
This is a token-heavy workflow. Sub-agent dispatch, automatic memory loading, and session-end `/distill` cycles all spend tokens -- a session that fans out two or three parallel research agents can easily 5-10x a chat-style session. Plan accordingly: Claude Max's higher tier for daily use, or watch your billing if you're on the API. The tradeoff is intentional -- the template optimizes for depth and continuity, not minimum spend.

Three things keep costs honest:

- **Worker agent profiles with model routing** -- see the "Worker agent profiles" section above. Routing mechanical work to Haiku and reserving Opus for senior review is the single biggest cost lever in the setup.
- **Bundled statusline** -- `core/bin/statusline.sh` ships with the template and is wired up by `fort-bootstrap`. It renders a live two-line bar: context %, token count, and working directory on top; model, session duration, and accumulated cost on the bottom. Color tiers (green → amber → red) trigger at thresholds so you catch runaway sessions before the bill lands.
- **[Claude Usage Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker)** -- separate project by @hamed-elfayome that gives you longitudinal usage reports (per session, per day, per model). Good complement to the in-session statusline when you want a weekly rollup.

**Can I use this for a team?**
Yes. The repo is git-based, so team conventions, shared hooks, and common memory files work naturally with branches and pull requests.

**What's Johnny Decimal?**
A numbering system for organizing topics. Each category gets a two-digit number (50-59 for infrastructure, 60-69 for projects). See [johnnydecimal.com](https://johnnydecimal.com/).

---

## Related projects

- [SpiceBox](https://github.com/authzed/spicebox) -- Fine-grained permissions and sandboxing for Claude Code. If fort-starter is the workspace, SpiceBox is the security perimeter: hook-based permission enforcement, macOS sandbox profiles, and network-level controls. Complementary approaches to the same goal of making AI coding agents production-grade.
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) -- Official docs for hooks, CLAUDE.md, and configuration
- [Claude Usage Tracker](https://github.com/hamed-elfayome/Claude-Usage-Tracker) -- Longitudinal usage reports by @hamed-elfayome, complements the bundled statusline
- [Johnny Decimal](https://johnnydecimal.com/) -- The numbering system used for memory organization
- [Conventional Commits](https://www.conventionalcommits.org/) -- The commit format enforced by the starter hooks

<p align="center"><em>Your fort. Your colors.</em></p>

<p align="center">
  <img src="assets/town.svg" alt="A neighborhood of forts in different palettes" width="660">
</p>

<p align="center"><sub>MIT License</sub></p>
