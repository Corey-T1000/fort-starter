# Tool Routing

## Tracking Work
**TaskCreate** — quick checklist for this session only
**`notes/parking-lot.md`** — durable cross-session follow-ups

## Executing Work
- **Background agent** (`run_in_background`) — research, analysis (default)
- **Sandbox** (`fort-sandbox` / `orb`) — untrusted code, isolation needed
- **Worktrees** (`git worktree`) — parallel git branches

## Browser
- **`agent-browser`** (default) — headless CLI, scraping, automation
- **Claude-in-Chrome** — user's real tabs, visual output needed

## Reference Lookups
- **Skills** (on-demand) — deep docs, saves context window
- **Read/Grep** — quick lookup in a known file
- **Explore agent** — broad multi-file investigation

Use local agents over global ones when a project has `.claude/agents/`.

## Design Skills
- `/frontend-design` — marketing sites, bold aesthetics
- `/interface-design:init` — dashboards, admin panels, functional UI
- `/design-lab` — explore options, show variations first
- `/playground` — visual recon, single-file HTML explorers. Quick and disposable.
- `/workbench` — structured prototyping with liftable code (Next.js, dashboard widget, standalone tool shapes)

**Output paths** (enforced — don't dump loose files):
- HTML explorations → `scratch/design-lab/<project-group>/` (group by project, not date)
- Structured prototypes → `scratch/playground/<name>/`
- One-off scripts → `scratch/scripts/`

For redesigns or uncertain direction: `/playground` first, then implement with the appropriate design skill.
For building something that should graduate to production: `/workbench` instead.
Before any design skill on an **existing** page, offer: "Want to explore variations first?"

When ambiguous → ask the user.

## Debugging

- "this is broken, figure out why" / "dig into why X isn't working" / "investigate this bug" / "the endpoint is broken" → `superpowers:systematic-debugging` (investigative, hypothesis-driven)
- "ugh, this errored" / "why doesn't X work" (friction expression, not investigation) → friction-reflex skill if installed (e.g. `/wtf` in the private Fort) — otherwise routes to `/retro` for deep zoom, or `/note` for footgun capture

`systematic-debugging` is for *finding the cause* of a known bug. Friction expressions are the *reflex* when something feels wrong — they pick the right destination downstream (which may itself be `systematic-debugging`).

## PR Review
- "review PR #X" / "look at this PR" / PR URL → `/review-pr` (multi-pass: security + code review + verification + context check)
- "review this" (own code) → `/requesting-code-review` (single-pass self-review)

## Workflow Chains
- "ship it" → `/ship` (orchestrates: review → verify → commit → PR)
  - After external review: `/iterate-pr`
- "iterate on PR" → `/iterate-pr`
- "build feature" → `/brainstorming` → `/writing-plans` → `/executing-plans`
- "finish branch" → `/verification-before-completion` → `/finishing-a-development-branch`

Always confirm chains with the user before starting.

## Optimization
- "optimize this" / "tune these params" / "run autoresearch" → `/autoresearch` (autonomous agent loop with locked evaluator, train/val split, TSV experiment log)
- Requires a `program.md` defining mutable surface, evaluator, metrics, and constraints
- Phases: config-only (1) → algorithm (2) → composition (3)

## User Preferences
- Use AskUserQuestion with concrete options — not open-ended questions
- Present skill options rather than picking silently
