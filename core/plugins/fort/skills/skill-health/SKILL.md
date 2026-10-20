---
name: skill-health
description: Run regression checks on Fort skill and rules file integrity. Audits the skills/<name>/SKILL.md layout and measures the per-session token budget.
user_invocable: true
---

# Skill Health Check

Quick smoke test for Fort skill and rules file integrity. Two checks:

1. **Skill layout audit**: every skill is a directory, `skills/<name>/SKILL.md`, whose frontmatter `name` matches the directory and has a `description`. The directory name is the slash command, so a malformed one silently isn't invokable. Also flags installed copies in `.claude/skills/` that drifted from source, and stale `.claude/commands/<name>.md` files that shadow a skill.
2. **Token budget**: measures the per-session input-token cost from rules + CLAUDE.md + memory index, so growth doesn't silently bloat every conversation.

> The private Fort this template was extracted from also runs a deterministic scenario evaluator against routing scenarios. That evaluator and its scenarios aren't bundled here because they're tuned to one user's workflow. Add one if/when you have routing scenarios worth testing.

## Step 1: Skill Layout Audit

```bash
echo "=== Skill Layout ==="
bad=0
for d in core/plugins/*/skills/*/ profiles/*/skills/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d"); f="$d/SKILL.md"
  if [ ! -f "$f" ]; then echo "  🔴 $d has no SKILL.md"; bad=1; continue; fi
  fm_name=$(awk '/^---/{n++; next} n==1 && /^name:/{sub(/^name:[ ]*/,""); print; exit}' "$f")
  [ "$fm_name" = "$name" ] || { echo "  🔴 $f: frontmatter name '$fm_name' != dir '$name'"; bad=1; }
  awk '/^---/{n++; next} n==1' "$f" | grep -q '^description:' || { echo "  🔴 $f: no description"; bad=1; }
done
# Flat .md files directly in a skills/ dir are the pre-2026-10 layout and won't load as skills.
for f in core/plugins/*/skills/*.md profiles/*/skills/*.md; do
  [ -f "$f" ] && [ "$(basename "$f")" != README.md ] && { echo "  🔴 flat skill file (move to <name>/SKILL.md): $f"; bad=1; }
done
# Installed copies vs source, and stale commands shadowing a skill.
for d in .claude/skills/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  src=$(ls -d profiles/${FORT_PROFILE:-vanilla}/skills/$name core/plugins/*/skills/$name 2>/dev/null | head -1)
  [ -n "$src" ] && ! diff -rq "$src" "$d" >/dev/null && echo "  🟡 .claude/skills/$name differs from $src (local edit, or run ./fort-bootstrap --refresh)"
  [ -f ".claude/commands/$name.md" ] && echo "  🟡 .claude/commands/$name.md shadows the skill; delete it"
done
[ "$bad" = 0 ] && echo "  🟢 Every skill is <name>/SKILL.md with a matching name and a description"
```

## Step 2: Token Budget

Measure the total system prompt cost — every file in this list is loaded into every session.

```bash
echo ""
echo "=== Token Budget ==="
for f in core/rules/*.md profiles/vanilla/CLAUDE.md; do
  words=$(wc -w < "$f" 2>/dev/null || echo 0)
  tokens=$(echo "$words * 1.3" | bc | cut -d. -f1)
  printf "  %-45s ~%s tokens\n" "$f" "$tokens"
done

echo ""
total_words=$(cat core/rules/*.md profiles/vanilla/CLAUDE.md 2>/dev/null | wc -w)
total_tokens=$(echo "$total_words * 1.3" | bc | cut -d. -f1)
echo "  TOTAL (rules + CLAUDE.md): ~${total_tokens} tokens"

if [ -f memory/MEMORY.md ]; then
  mem_words=$(wc -w < memory/MEMORY.md 2>/dev/null || echo 0)
  mem_tokens=$(echo "$mem_words * 1.3" | bc | cut -d. -f1)
  echo "  MEMORY.md index:           ~${mem_tokens} tokens"
  grand=$((total_tokens + mem_tokens))
  echo "  GRAND TOTAL (every session): ~${grand} tokens"
fi
```

## Step 3: Report

Present results in a status block:

```
┌─────────────────────────────────
│ SKILL HEALTH CHECK
│
│ Slash registration: [🟢 / count missing / count stale]
│ Token budget:       ~[N] tokens/session
│
│ [🟢 All clear / 🟡 Issues found / 🔴 Regression detected]
│ [List any issues]
└─────────────────────────────────
```

Thresholds:
- 🟢 zero missing-wrapper skills, zero stale wrappers
- 🟡 stale wrappers OR token budget growing past your usual baseline
- 🔴 any missing-wrapper skills (skills shipped but not invokable)
