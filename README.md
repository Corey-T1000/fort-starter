<p align="center">
  <img src="assets/logo-hero.svg" alt="fort-starter — persistent AI workspaces" width="440">
</p>

A template for building a persistent AI workspace on top of [Claude Code](https://docs.anthropic.com/en/docs/claude-code). It gives an AI agent persistent memory, enforced rules, and specialized tools -- all inside a git repo that you control. It's not a framework. It's a workspace template you fork and make your own.

This was extracted from a personal setup that's been in daily use since December 2025. The patterns here aren't theoretical -- they've survived five months of real work across dozens of projects.

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

## The five layers

```
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

Shell scripts that Claude Code executes at defined trigger points: before a tool runs (`PreToolUse`), after it runs (`PostToolUse`), or when a session ends (`Stop`). Each hook returns a JSON decision -- `allow`, `deny`, or `ask` (prompt the user). The starter includes ~10 hooks across security, workflow, and quality categories. The setup this was extracted from runs 40+.

### 3. Memory -- memory/ + MEMORY.md

Topic files organized with [Johnny Decimal](https://johnnydecimal.com/) numbering. `MEMORY.md` is a routing table that maps file paths to memory files -- when you start editing files in `projects/dashboard/`, the agent automatically loads `memory/60-dashboard.md` with prior context. Memory files hold operational knowledge: architecture decisions, API gotchas, deployment details. Knowledge that would otherwise be lost at the end of every session.

### 4. Skills -- skills/

Markdown files that define slash commands -- `/distill`, `/research`, `/ship`, `/garden`. Each skill is a structured prompt that Claude loads on demand (not on every session). Skills keep specialized workflows out of your base context window. You invoke them with `/skill-name` and they guide multi-step processes. The vanilla profile ships with ~20 starter skills.

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
  [ok] .claude/hooks/ -- 10 hooks installed
  [ok] memory/ -- starter structure created
  [ok] skills/ -- 20 starter skills linked
  [ok] bin/ -- utilities installed
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

```
my-workspace/
├── CLAUDE.md                  # Agent identity and top-level instructions
├── .claude/
│   ├── hooks/                 # Shell scripts -- deterministic enforcement
│   │   ├── guard-env-files.sh
│   │   ├── guard-secrets.sh
│   │   └── ...
│   └── rules/                 # Focused instruction files (auto-loaded)
│       ├── guardrails.md
│       ├── output-style.md
│       └── workflow-intelligence.md
├── memory/                    # Persistent knowledge (JD-numbered topic files)
│   ├── MEMORY.md              # Routing table: path prefix -> memory file
│   └── 60-example.md          # Template memory file
├── plugins/fort/skills/       # Slash command definitions (loaded on demand)
│   ├── distill.md
│   ├── research.md
│   └── ...
├── bin/                       # Shell utilities
├── notes/                     # Scratch notes, parking lot
├── logs/                      # Session logs (auto-generated)
├── projects/                  # Your active codebases
├── profiles/
│   └── vanilla/               # Minimal starter profile
├── fort-bootstrap             # Setup script
└── assets/                    # Logo and brand assets
```

---

## FAQ

**How is this different from just writing a good CLAUDE.md?**
A good CLAUDE.md gets you 80% of the way. The remaining 20% -- security enforcement, automatic memory loading, session-to-session knowledge transfer, workflow automation -- requires infrastructure around it.

**Does this work with other AI coding tools?**
The concepts (persistent memory, hook-based enforcement, skill-based workflows) are transferable. The implementation is specific to Claude Code's hook system and CLAUDE.md conventions.

**How much does this cost in context window?**
CLAUDE.md and rules load on every session -- budget ~2-3k tokens. Memory files load on demand. Skills load only when invoked. Designed to minimize baseline context usage.

**Can I use this for a team?**
Yes. The repo is git-based, so team conventions, shared hooks, and common memory files work naturally with branches and pull requests.

**What's Johnny Decimal?**
A numbering system for organizing topics. Each category gets a two-digit number (50-59 for infrastructure, 60-69 for projects). See [johnnydecimal.com](https://johnnydecimal.com/).

---

## Related projects

- [SpiceBox](https://github.com/authzed/spicebox) -- Fine-grained permissions and sandboxing for Claude Code. If fort-starter is the workspace, SpiceBox is the security perimeter: hook-based permission enforcement, macOS sandbox profiles, and network-level controls. Complementary approaches to the same goal of making AI coding agents production-grade.
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) -- Official docs for hooks, CLAUDE.md, and configuration
- [Johnny Decimal](https://johnnydecimal.com/) -- The numbering system used for memory organization
- [Conventional Commits](https://www.conventionalcommits.org/) -- The commit format enforced by the starter hooks

<p align="center"><em>Your fort. Your colors.</em></p>

<p align="center">
  <img src="assets/town.svg" alt="A neighborhood of forts in different palettes" width="660">
</p>

<p align="center"><sub>MIT License</sub></p>
