---
name: pre-mortem
description: |
  This skill should be used when the user asks "what could go wrong", "before we
  deploy", "pre-mortem this", "find potential failures", "what might break", "check
  for risks", or wants to systematically predict where code could fail before shipping.
user_invocable: true
arguments:
  - name: scope
    description: What to analyze (file path, feature name, or "recent" for uncommitted changes)
    required: false
---

# Pre-Mortem

Predict where code could fail before it ships. This is reverse prompting —
instead of testing what works, systematically imagine what breaks.

## How It Works

1. Identify the scope (specific files, a feature, or recent changes)
2. Analyze the code through multiple failure lenses
3. Report findings ranked by likelihood and severity
4. Suggest specific fixes for the highest-risk items

## Failure Lenses

Analyze through each of these perspectives:

### 1. Input Boundaries
- What happens with empty, null, undefined, or unexpected input?
- Are there type coercions that could silently corrupt data?
- What if external data (API responses, user input) has a different shape than expected?

### 2. State & Timing
- Race conditions between async operations?
- Stale state after navigation or re-renders?
- What if a dependency (API, database, service) is slow or unavailable?

### 3. Error Paths
- Are errors caught and handled, or do they silently fail?
- Do catch blocks swallow useful context?
- What happens after an error — is the system in a recoverable state?

### 4. Security
- Injection vectors (SQL, XSS, command injection)?
- Authentication/authorization edge cases?
- Secrets or credentials that could leak through logs or error messages?

### 5. Data Integrity
- Can data be partially written and leave inconsistent state?
- Are there operations that should be atomic but aren't?
- What if the same operation runs twice (idempotency)?

### 6. Deployment & Environment
- Will this work in production (different env vars, paths, permissions)?
- Does it depend on local state that won't exist on the server?
- Are there hard-coded values that should be configurable?

## Output Format

```
## Pre-Mortem Report: [scope]

### Critical (fix before shipping)
- [Finding] — [Why it matters] — [Suggested fix]

### Warning (likely to cause issues)
- [Finding] — [Why it matters] — [Suggested fix]

### Watch (low probability but high impact)
- [Finding] — [Why it matters] — [Suggested fix]

### Clean
- [Areas that look solid and why]
```

## Instructions

1. If no scope is provided, run `git diff` and `git diff --cached` to find recent changes
2. Read all relevant files thoroughly before analyzing
3. Be specific — reference exact lines and functions, not vague warnings
4. Don't pad the report with obvious or unlikely issues. Only report things that could actually bite.
5. The "Clean" section is important — confirm what looks solid so the user knows where NOT to worry
6. If you find a Critical issue, ask if the user wants you to fix it right now
