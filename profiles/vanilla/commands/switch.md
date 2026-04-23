---
name: switch
description: |
  Use when the user says "switch to", "jump to", "let's work on", "context switch",
  "move to", or wants to transition between Fort projects mid-session.
  Snapshots current state, loads target project memory, sets tab title.
user_invocable: true
argument-hint: "[project]"
arguments:
  - name: project
    description: "Target project name (e.g., frontend, api-service, dashboard)"
    required: false
---

# Project Context Switch

Clean transition between projects mid-session. Captures where you are, loads where you're going.

## When to Use

- the user says "let's switch to frontend", "jump to dashboard", "context switch"
- Moving between project directories
- Starting work on a different project mid-session

## Project Registry

**Source of truth**: `workflow-intelligence.md` routing table (path prefixes, memory files, JD numbers, tab titles).

Fuzzy aliases for `/switch` argument matching:

| Project | Fuzzy Matches |
|---------|---------------|
| dashboard | dash |
| frontend | fe, web |
| api-service | api, backend |
| fort-infra | infra, claude |
| deploy | server, remote |

Add your own projects to this table as you set them up.

## Workflow

### Step 1: Identify Target

If project was provided as argument, match it against the registry (fuzzy match is fine — "fe" → frontend, "dash" → dashboard).

If invoked bare, use **AskUserQuestion**:
- Header: "Switch to"
- Question: "Which project?"
- Options: [top 4 most recently active projects based on git log]

### Step 2: Snapshot Current State

Briefly assess current state (don't spend time on this — it's a snapshot, not a review):

```bash
# Any uncommitted changes?
git status --short
```

Report concisely:

> **Current state**: [clean / X uncommitted files].

If there are uncommitted changes, note them but **do not auto-commit or stash**. Just make the user aware.

### Step 3: Load Target Context

1. **Read memory file**: Load the target project's memory file from the registry
2. **Recent activity**: `git log --oneline -5 -- <path-prefix>` for recent commits in that project area

### Step 4: Set Up

```bash
tab-title "fort:<tab-title>"
```

### Step 5: Present

> **Switched to [project]** (JD [number])
> Memory loaded from `memory/XX-topic.md`
>
> **Recent**:
> - [last 2-3 commits in this area]
>
> What are we working on?

## Handling Unknown Projects

If the project doesn't match the registry:
1. Check if there's a matching directory in the Fort
2. Check `memory/MEMORY.md` for a JD match
3. If nothing matches: "I don't have [project] in the registry. Want me to add it?"
4. If yes, gather the path prefix and memory file info, then update both this skill's registry and the workflow-intelligence routing table

## No Auto-Commit Policy

This skill never commits, stashes, or modifies git state. It's a context switch, not a branch switch. If the user needs to commit before switching, they'll say so.
