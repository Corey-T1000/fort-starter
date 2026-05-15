---
name: skill-health
description: Run regression checks on Fort skill and rules file integrity. Audits slash-command registration coverage and measures the per-session token budget.
user_invocable: true
---

# Skill Health Check

Quick smoke test for Fort skill and rules file integrity. Two checks:

1. **Slash-command registration audit** — every plugin skill marked `user_invocable: true` should have a matching wrapper in `profiles/<profile>/commands/`. Skills with no wrapper aren't slash-invokable from the prompt. Catches half-registered skills the moment they ship.
2. **Token budget** — measures the per-session input-token cost from rules + CLAUDE.md + memory index, so growth doesn't silently bloat every conversation.

> The private Fort this template was extracted from also has a Step 1 that runs a deterministic scenario evaluator (`scratch/autoresearch-skills/evaluate.mjs`) against routing scenarios. That evaluator and its scenarios aren't bundled here because they're tuned to one user's workflow. Treat skill-health below as the load-bearing portion that's universally useful; add a scenario evaluator if/when you have routing scenarios worth testing.

## Step 1: Slash-Command Registration Audit

Verify every `user_invocable: true` plugin skill has a matching wrapper in the active profile's commands directory. Flag stale wrappers without a backing plugin skill.

```bash
echo "=== Slash-Command Registration ==="

# Resolve which profile to audit. Vanilla is the default in this template.
PROFILE_COMMANDS="${PROFILE_COMMANDS:-profiles/vanilla/commands}"

# Skills marked invocable but missing a profile-command wrapper.
missing=()
for f in core/plugins/fort/skills/*.md; do
  name=$(basename "$f" .md)
  if grep -q "^user_invocable: true" "$f" 2>/dev/null; then
    if [ ! -f "$PROFILE_COMMANDS/$name.md" ]; then
      missing+=("$name")
    fi
  fi
done

# Stale profile-command entries (no backing plugin skill).
# Some are intentional command-only skills — extend KNOWN_COMMAND_ONLY for your fork.
KNOWN_COMMAND_ONLY="assistant bod briefing calendar compress distill eod garden pulse README skill-health switch"
stale=()
for cmd in $PROFILE_COMMANDS/*.md; do
  name=$(basename "$cmd" .md)
  if [ -f "core/plugins/fort/skills/$name.md" ]; then continue; fi
  if echo " $KNOWN_COMMAND_ONLY " | grep -q " $name "; then continue; fi
  stale+=("$name")
done

if [ "${#missing[@]}" -eq 0 ] && [ "${#stale[@]}" -eq 0 ]; then
  echo "  🟢 All user_invocable plugin skills have command wrappers; no stale entries"
fi
if [ "${#missing[@]}" -gt 0 ]; then
  echo "  🔴 Plugin skills marked user_invocable: true with NO command wrapper:"
  for n in "${missing[@]}"; do echo "      - $n"; done
  echo "      → /skill_name will not be invokable. Decide: dispatch-only (drop user_invocable flag) OR create wrapper at $PROFILE_COMMANDS/<name>.md (typically a copy of the plugin skill)."
fi
if [ "${#stale[@]}" -gt 0 ]; then
  echo "  🟡 Profile-command entries with no backing plugin skill (not in KNOWN_COMMAND_ONLY allowlist):"
  for n in "${stale[@]}"; do echo "      - $n"; done
  echo "      → either add to KNOWN_COMMAND_ONLY in this skill, restore the plugin skill, or delete the wrapper."
fi
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
