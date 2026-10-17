---
name: security-audit
description: |
  Run a comprehensive security audit on the project. Checks CLAUDE.md for injection risks,
  scans for secrets, reviews plugin inventory, and audits hook permissions. Triggers: 'audit
  security', 'check for vulnerabilities', 'security scan', 'run security checks'.
user_invocable: true
arguments:
  - name: scope
    description: "full | quick | hooks-only (default: full)"
    required: false
---

# Security Audit

Run a multi-layered security scan on the current project and Fort infrastructure.

## Audit Layers

### Layer 1: CLAUDE.md Injection Audit (always run)
Run AgentShield if available:
```bash
npx ecc-agentshield audit ./CLAUDE.md 2>&1
```
If npx command fails (not installed), note it and continue.

Also manually check:
- CLAUDE.md files for suspicious instructions (override, ignore, bypass patterns)
- `.claude/settings.local.json` for overly broad permissions
- Any `*.md` files in `.claude/` that could influence behavior

### Layer 2: Secret Scanning (always run)
Run fort-scan YARA rules if available:
```bash
${FORT_ROOT:-$HOME/claudes-fort}/bin/fort-scan . 2>&1
```
If not available, do a manual grep for common secret patterns:
- API keys (sk-, AKIA, ghp_, etc.)
- Hardcoded passwords
- Private keys in non-key files
- .env files not in .gitignore

### Layer 3: Plugin Inventory (full scope only)
List all installed plugins and their sources:
- Read `.claude/settings.local.json` for enabledPlugins and extraKnownMarketplaces
- For each plugin, check if source is `directory` (local) or `github` (remote)
- Flag any plugins from unknown/untrusted sources
- Check for plugins with broad tool permissions

### Layer 4: Hook Permissions Review (full scope only)
Review all hooks in `.claude/settings.local.json`:
- List all hook events and their matchers
- Flag hooks that run with no matcher (global hooks)
- Check for hooks that use `permissionDecision: "allow"` (auto-approving)
- Verify all hook script paths exist and have proper permissions
- Check for hooks that modify tool input (updatedInput)

### Layer 5: Seatbelt Sandbox Status (full scope only)
Check if seatbelt sandboxing is active:
```bash
sandbox-exec -n /dev/null echo "seatbelt available" 2>&1
```
Report on the two-layer security model:
- Layer 1: Seatbelt (macOS sandbox, filesystem restrictions)
- Layer 2: Orbstack VM (fort-sandbox, full isolation)

## Output Format

Present results as a structured report:

```
## Security Audit Report — {date}

### Summary
- Layers checked: {N}/5
- Issues found: {count by severity}
- Overall status: PASS / WARN / FAIL

### Findings
#### Critical (must fix)
...
#### Warning (should review)
...
#### Info (awareness)
...

### Recommendations
...
```

## Scope Behavior

- **full** (default): Run all 5 layers
- **quick**: Run layers 1 and 2 only (CLAUDE.md + secrets)
- **hooks-only**: Run layer 4 only (hook permissions review)
