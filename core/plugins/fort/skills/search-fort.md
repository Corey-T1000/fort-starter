---
name: search-fort
description: |
  Forensic search across the Fort knowledge base — memory files, session narratives,
  assistant state, notes, plans, and logs. Uses frontmatter + ripgrep, no vector DB.
  Invoke when the user asks "where's that session where...", "what did we decide about...",
  "find everything tagged X", "what spawned Y", or needs to locate a file by relationship
  rather than filename. Frontmatter v2 search infrastructure.
user_invocable: true
argument-hint: "[query | --tag=X --status=X --jd=X --related-to=SLUG]"
arguments:
  - name: query
    description: "NL query or filter flags (see flag list)"
    required: false
---

# Search Fort

Thin wrapper around `bin/fort-search` (Python + ripgrep). No embeddings, no index — relies on frontmatter v2 schema + wikilinks + content grep.

## When to Use

- "Where was that session where we debugged X?" → content + title search
- "All finished `budget` work" → `--tag=budget --status=shipped`
- "Anything related to `escape-hatch`" → `--related-to=escape-hatch`
- "Files under JD 53.06" → `--jd=53.06`
- NOT `/capture` (structured research dump), NOT `/note` (fresh capture) — this is READ-ONLY discovery.

## Usage

```
fort-search "natural language content"
fort-search --tag=infra --status=shipped
fort-search --jd=53.06
fort-search --related-to=escape-hatch
fort-search "1password" --limit=10
fort-search "session" --json        # for pipelines
```

Combine flags with a positional query to narrow: `fort-search --tag=betbud "clv"` first filters by tag then ripgreps for `clv` within that set.

## Scope

**Searched**: `memory/`, `notes/`, `scratch/assistants/`, `scratch/research/`, `docs/plans/`, `logs/`
**Excluded**: `notes/compaction-extracts/`, `scratch/.board/`, `scratch/transcripts/`, `scratch/archive/`

## Rank Tiers

| Tier | Label | What matched |
|------|-------|--------------|
| 1 | `slug` | Filename stem or frontmatter `Slug` equals query |
| 2 | `title` | Query substring in `Focus`/`Title`/`name`/`description` |
| 3 | `content` | Query matched in file body (first line only per file) |
| 4 | `fm` / `filter-match` | Query matched in a frontmatter field, or filter flags matched without a query |

Output sorted by tier ascending, then alphabetical path.

## Workflow

### Step 1: Run fort-search

```bash
bin/fort-search [flags] [query]
```

Default limit is 20. Read the stderr summary (`N hit(s)`) to decide if escalation is needed.

### Step 2: Decide escalation

- If ≤20 hits and top results answer the question → return them.
- If >20 hits or tiers are mostly 3/4 (content scatter, no structured match) and the query is natural-language → dispatch an **Explore** sub-agent.

```
Agent({
  subagent_type: "Explore",
  description: "Rank Fort hits for: <query>",
  prompt: "Here is the candidate set from fort-search (paste the --json output).
           Read each, rank them for relevance to <query>, and return top 3 with a
           one-line reason each."
})
```

Pre-filter with `fort-search --json --limit=50 <query>` so the sub-agent doesn't rescan the whole Fort.

### Step 3: Present

For each top result: file path, one-line reason, and the tier label so the user sees whether we matched on slug/title/content/fm. Don't narrate the search — just return the hits.

## Gotchas

- **New files ≠ v2 frontmatter automatically.** If a file is pre-v2, slug/title rank tiers won't fire — falls through to content match. Dogfood path: opportunistically upgrade when you touch an old file.
- **Wikilink resolution** is literal `[[slug]]` match. No fuzzy slug matching. If the user typed the slug wrong, say so ("no hits for `escape-hach` — did you mean `escape-hatch`?").
- **Tags are case-insensitive** but must match exactly (no partial). `fort-search --tag=budg` will not match `budget`.
- **JD values** match as strings (`53.06` vs `53` vs `53.6` are all distinct).

## Reference

- Script: `bin/fort-search` (Python 3)
- Frontmatter v2 search infrastructure
