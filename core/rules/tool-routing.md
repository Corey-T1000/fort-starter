# Tool Routing

## Tracking Work
**Beads** (`bd create`) — multi-session, has blockers, needs follow-up
**TaskCreate** — quick checklist for this session only

When in doubt → Beads.

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

## PR Review
- "review PR #X" / "look at this PR" / PR URL → `/review-pr` (multi-pass: security + code review + verification + context check)
- "review this" (own code) → `/requesting-code-review` (single-pass self-review)

## Workflow Chains
- "ship it" → `/ship` (orchestrates: review → verify → commit → PR → beads cleanup)
  - After external review: `/iterate-pr`
- "iterate on PR" → `/iterate-pr`
- "build feature" → check/create beads issue → `/brainstorming` → `/writing-plans` → `/executing-plans`
- "finish branch" → `/verification-before-completion` → `/finishing-a-development-branch` → check beads for closeable issues

Always confirm chains with the user before starting.

## Optimization
- "optimize this" / "tune these params" / "run autoresearch" → `/autoresearch` (autonomous agent loop with locked evaluator, train/val split, TSV experiment log)
- Requires a `program.md` defining mutable surface, evaluator, metrics, and constraints
- Phases: config-only (1) → algorithm (2) → composition (3)

## User Preferences
- Use AskUserQuestion with concrete options — not open-ended questions
- Present skill options rather than picking silently
