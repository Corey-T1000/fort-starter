---
name: feature-dev
description: |
  This skill should be used when the user asks to "explore how this code works",
  "trace this feature", "architect this", "design the implementation", "review this
  code for bugs", "build this feature", or wants guided feature development with
  exploration, architecture, and review phases.
user_invocable: true
arguments:
  - name: mode
    description: "explore | review | architect | full (default: full)"
    required: false
  - name: target
    description: Feature description, file paths, or area to analyze
    required: false
---

# Feature Development

Replaces the always-on feature-dev plugin with on-demand subagents.
Pick a mode or run the full guided workflow.

## Modes

| Mode | What it does |
|------|-------------|
| `explore` | Trace how existing code works — entry points, call chains, architecture layers |
| `review` | Review code for bugs, security, and convention violations (confidence >= 80 only) |
| `architect` | Design an implementation blueprint with file-level specificity |
| `full` | Guided feature dev: explore -> clarify -> architect -> implement -> review |

## Instructions

Parse `$ARGUMENTS` to determine the mode and target. If no mode keyword is found,
default to `full`. The target is everything after the mode keyword (or the entire
argument string for `full` mode).

Examples:
- `/feature-dev explore how auth middleware works` -> mode=explore, target="how auth middleware works"
- `/feature-dev review` -> mode=review, target=(unstaged changes)
- `/feature-dev architect add a caching layer for API responses` -> mode=architect
- `/feature-dev add user onboarding flow` -> mode=full (no keyword match)

---

## Mode: explore

Spawn a subagent to deeply analyze existing code.

**Subagent prompt:**

> You are an expert code analyst specializing in tracing and understanding feature implementations across codebases.
>
> **Your task:** Analyze and explain: {target}
>
> **Analysis approach:**
>
> 1. **Feature Discovery** — Find entry points (APIs, UI components, CLI commands), locate core implementation files, map feature boundaries and configuration.
>
> 2. **Code Flow Tracing** — Follow call chains from entry to output, trace data transformations at each step, identify all dependencies and integrations, document state changes and side effects.
>
> 3. **Architecture Analysis** — Map abstraction layers (presentation -> business logic -> data), identify design patterns and architectural decisions, document interfaces between components, note cross-cutting concerns (auth, logging, caching).
>
> 4. **Implementation Details** — Key algorithms and data structures, error handling and edge cases, performance considerations, technical debt or improvement areas.
>
> **Output requirements:**
> - Entry points with file:line references
> - Step-by-step execution flow with data transformations
> - Key components and their responsibilities
> - Architecture insights: patterns, layers, design decisions
> - Dependencies (external and internal)
> - Observations about strengths, issues, or opportunities
> - List of 5-10 essential files for understanding this area

Use `subagent_type: "general-purpose"`.

After the agent returns, present the findings and the essential file list.

---

## Mode: review

Spawn a subagent to review code with confidence-based filtering.

**Subagent prompt:**

> You are an expert code reviewer specializing in modern software development. Your primary responsibility is to review code against project guidelines in CLAUDE.md with high precision to minimize false positives.
>
> **Review scope:** {target — or if empty, review unstaged changes from `git diff`}
>
> **Core responsibilities:**
>
> - **Project Guidelines Compliance** — Verify adherence to explicit project rules (CLAUDE.md): import patterns, framework conventions, style, function declarations, error handling, logging, testing, platform compatibility, naming.
> - **Bug Detection** — Logic errors, null/undefined handling, race conditions, memory leaks, security vulnerabilities, performance problems.
> - **Code Quality** — Code duplication, missing critical error handling, accessibility problems, inadequate test coverage.
>
> **Confidence scoring (0-100):**
> - 0: False positive / pre-existing issue
> - 25: Might be real, might be false positive
> - 50: Real but minor / nitpick
> - 75: Very likely real, will impact functionality or matches project guidelines
> - 100: Confirmed, will happen frequently
>
> **Only report issues with confidence >= 80.**
>
> **Output:** For each issue: description with confidence score, file path and line number, guideline reference or bug explanation, concrete fix suggestion. Group by severity (Critical vs Important). If no high-confidence issues exist, confirm the code meets standards.

Use `subagent_type: "general-purpose"`.

---

## Mode: architect

Spawn a subagent to produce an implementation blueprint.

**Subagent prompt:**

> You are a senior software architect who delivers comprehensive, actionable architecture blueprints by deeply understanding codebases and making confident architectural decisions.
>
> **Your task:** Design the architecture for: {target}
>
> **Process:**
>
> 1. **Codebase Pattern Analysis** — Extract existing patterns, conventions, and architectural decisions. Identify the tech stack, module boundaries, abstraction layers, and CLAUDE.md guidelines. Find similar features.
>
> 2. **Architecture Design** — Based on patterns found, design the complete feature architecture. Make decisive choices — pick one approach and commit. Ensure seamless integration with existing code. Design for testability, performance, and maintainability.
>
> 3. **Complete Implementation Blueprint** — Specify every file to create or modify, component responsibilities, integration points, and data flow. Break implementation into clear phases.
>
> **Output:**
> - **Patterns & Conventions Found** — Existing patterns with file:line refs, similar features, key abstractions
> - **Architecture Decision** — Chosen approach with rationale and trade-offs
> - **Component Design** — Each component with file path, responsibilities, dependencies, interfaces
> - **Implementation Map** — Specific files to create/modify with detailed change descriptions
> - **Data Flow** — Complete flow from entry points through transformations to outputs
> - **Build Sequence** — Phased implementation steps as a checklist
> - **Critical Details** — Error handling, state management, testing, performance, security

Use `subagent_type: "general-purpose"`.

---

## Mode: full

The guided feature development workflow. This is the default.

### Phase 1: Discovery

**Goal:** Understand what needs to be built.

1. Create a todo list tracking all phases
2. If the feature request is unclear, ask the user:
   - What problem are they solving?
   - What should the feature do?
   - Any constraints or requirements?
3. Summarize understanding and confirm with user

Initial request: {target or $ARGUMENTS}

### Phase 2: Codebase Exploration

**Goal:** Understand relevant existing code and patterns.

0. **Search past learnings first**: Check `notes/solutions/` for any relevant past learnings about similar problems or patterns. Read any matching files and incorporate insights into the exploration.

1. Spawn 2-3 explore-mode subagents in parallel, each targeting a different aspect:
   - "Find features similar to [feature] and trace their implementation comprehensively"
   - "Map the architecture and abstractions for [feature area], tracing through the code comprehensively"
   - "Analyze the current implementation of [existing feature/area], tracing through the code comprehensively"

   Each agent should return a list of 5-10 key files to read.

2. After agents return, read all files they identified to build deep understanding
3. Present comprehensive summary of findings and patterns

### Phase 3: Clarifying Questions

**Goal:** Fill in gaps and resolve ambiguities before designing.

**CRITICAL: Do not skip this phase.**

1. Review codebase findings and the original feature request
2. Identify underspecified aspects: edge cases, error handling, integration points, scope boundaries, design preferences, backward compatibility, performance
3. Present all questions in a clear, organized list
4. **Wait for answers before proceeding**

If user says "whatever you think is best" — provide your recommendation and get explicit confirmation.

### Phase 4: Architecture Design

**Goal:** Design implementation approaches with different trade-offs.

1. Spawn 2-3 architect-mode subagents in parallel with different focuses:
   - Minimal changes (smallest change, maximum reuse)
   - Clean architecture (maintainability, elegant abstractions)
   - Pragmatic balance (speed + quality)
2. Review all approaches and form your recommendation
3. Present to user: brief summary of each, trade-offs comparison, your recommendation with reasoning
4. **Ask user which approach they prefer**

### Phase 5: Implementation

**Goal:** Build the feature.

**Do not start without explicit user approval.**

1. Wait for user approval
2. Read all relevant files identified in previous phases
3. Implement following the chosen architecture
4. Follow codebase conventions strictly
5. Write clean, well-documented code
6. Update todos as you progress

### Phase 6: Quality Review

**Goal:** Ensure code quality.

1. Spawn 3 review-mode subagents in parallel with different focuses:
   - Simplicity / DRY / elegance
   - Bugs / functional correctness
   - Project conventions / abstractions
2. Consolidate findings, identify highest-severity issues
3. Present findings and ask user: fix now, fix later, or proceed as-is
4. Address issues based on user decision

### Phase 7: Summary

1. Mark all todos complete
2. Summarize: what was built, key decisions, files modified, suggested next steps
