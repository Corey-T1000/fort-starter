#!/bin/bash
# Guard: Scrub credentials from permissions allow list on session start
# Scans settings.local.json for hardcoded secrets in Bash() permission entries
# and replaces them with $ENV_VAR placeholders
#
# Runs on SessionStart — self-healing, no manual intervention needed

# Source Fort environment
_FORT_ENV="${FORT_ROOT:-$HOME/claudes-fort}/.fort-env"
[ -f "$_FORT_ENV" ] && . "$_FORT_ENV"
FORT_ROOT="${FORT_ROOT:-$HOME/claudes-fort}"
FORT_PROJECTS="$HOME/.claude/projects/-$(echo "$FORT_ROOT" | sed 's|^/||; s|/|-|g')"

SETTINGS="$FORT_ROOT/.claude/settings.local.json"

if [ ! -f "$SETTINGS" ]; then
    exit 0
fi

# Pass path to Python via environment variable
export FORT_SETTINGS_PATH="$SETTINGS"

# Use python for reliable JSON manipulation + regex
python3 << 'PYEOF'
import json, re, sys, os

settings_path = os.environ["FORT_SETTINGS_PATH"]

with open(settings_path) as f:
    raw = f.read()

# Secret patterns (same as guard-secrets.sh)
patterns = [
    (r'sk-[a-zA-Z0-9]{20,}', '$API_KEY'),
    (r'AKIA[0-9A-Z]{16}', '$AWS_ACCESS_KEY_ID'),
    (r'ghp_[a-zA-Z0-9]{36}', '$GITHUB_TOKEN'),
    (r'gho_[a-zA-Z0-9]{36}', '$GITHUB_OAUTH_TOKEN'),
    (r'xoxb-[0-9]+-[0-9A-Za-z]+', '$SLACK_BOT_TOKEN'),
    (r'xoxp-[0-9]+-[0-9A-Za-z]+', '$SLACK_USER_TOKEN'),
    (r'sk_live_[a-zA-Z0-9]{24,}', '$STRIPE_KEY'),
    (r'rk_live_[a-zA-Z0-9]{24,}', '$STRIPE_RESTRICTED_KEY'),
    (r'ya29\.[a-zA-Z0-9_-]+', '$GOOGLE_OAUTH_TOKEN'),
    (r'AIza[0-9A-Za-z_-]{35}', '$GOOGLE_API_KEY'),
    # JWT tokens (common in Turso, auth tokens, etc.)
    (r'eyJ[a-zA-Z0-9_-]{20,}\.eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}', '$AUTH_TOKEN'),
]

found = []
cleaned = raw
for pattern, placeholder in patterns:
    matches = re.findall(pattern, cleaned)
    for match in matches:
        found.append((match[:12] + '...', placeholder))
        cleaned = cleaned.replace(match, placeholder)

if found:
    # Write cleaned version
    # Verify it's still valid JSON before writing
    try:
        json.loads(cleaned)
    except json.JSONDecodeError:
        # If cleaning broke JSON, don't write — just warn
        print(f"WARNING: Found {len(found)} credential(s) in allow list but auto-clean would break JSON. Manual cleanup needed.")
        sys.exit(0)

    with open(settings_path, 'w') as f:
        f.write(cleaned)

    items = ", ".join(f"{preview} -> {repl}" for preview, repl in found[:5])
    print(f"Scrubbed {len(found)} credential(s) from permissions allow list: {items}")
else:
    # Silent when clean
    pass
PYEOF

exit 0
