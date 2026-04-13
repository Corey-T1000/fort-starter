#!/bin/bash
# Guard: Warn when installing packages not already in project dependencies
# Catches npm install, pnpm add, pip install, npx of unknown packages
#
# Exit 0 + ask = prompts user for confirmation
# Only fires on NEW packages — bare `npm install` (from lockfile) passes silently

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Skip if empty command
if [ -z "$COMMAND" ]; then
    exit 0
fi

# Detect package install commands and extract package names
# npm install <pkg>, npm i <pkg>, npm add <pkg>
# pnpm add <pkg>, pnpm install <pkg>
# yarn add <pkg>
# pip install <pkg>, pip3 install <pkg>
# npx <pkg> (running a package directly)

PACKAGES=""
MANAGER=""

# npm/pnpm/yarn install with specific packages
if echo "$COMMAND" | grep -qE '(^|[[:space:]])(npm|pnpm) (install|i|add) '; then
    # Extract package names (skip flags starting with -)
    PACKAGES=$(echo "$COMMAND" | grep -oE '(npm|pnpm) (install|i|add) .+' | sed -E 's/(npm|pnpm) (install|i|add) //' | tr ' ' '\n' | grep -v '^-' | grep -v '^$' | head -5)
    MANAGER="npm/pnpm"
elif echo "$COMMAND" | grep -qE '(^|[[:space:]])yarn add '; then
    PACKAGES=$(echo "$COMMAND" | grep -oE 'yarn add .+' | sed 's/yarn add //' | tr ' ' '\n' | grep -v '^-' | grep -v '^$' | head -5)
    MANAGER="yarn"
elif echo "$COMMAND" | grep -qE '(^|[[:space:]])pip3? install '; then
    # Skip -r requirements.txt installs
    if echo "$COMMAND" | grep -qE 'pip3? install -r '; then
        exit 0
    fi
    PACKAGES=$(echo "$COMMAND" | grep -oE 'pip3? install .+' | sed -E 's/pip3? install //' | tr ' ' '\n' | grep -v '^-' | grep -v '^$' | head -5)
    MANAGER="pip"
elif echo "$COMMAND" | grep -qE '(^|[[:space:]])npx '; then
    # npx runs packages directly — extract the package name
    PACKAGES=$(echo "$COMMAND" | grep -oE 'npx [^ ]+' | sed 's/npx //' | grep -v '^-')
    MANAGER="npx"
fi

# No packages detected (bare `npm install`, etc.) — allow silently
if [ -z "$PACKAGES" ]; then
    exit 0
fi

# Check if packages are already in project deps
NEW_PACKAGES=""
for PKG in $PACKAGES; do
    # Strip version specifiers (@latest, @^1.0, etc.)
    PKG_NAME=$(echo "$PKG" | sed -E 's/@[^@\/]+$//')

    # Skip scoped packages' scope-only part
    if [ -z "$PKG_NAME" ]; then
        continue
    fi

    # Look for package in nearest package.json or requirements.txt
    FOUND=false

    if [ "$MANAGER" = "pip" ]; then
        # Check requirements*.txt and pyproject.toml
        for REQ in requirements.txt requirements-dev.txt pyproject.toml; do
            if [ -f "$REQ" ] && grep -qi "$PKG_NAME" "$REQ" 2>/dev/null; then
                FOUND=true
                break
            fi
        done
    else
        # Check package.json in current dir and parent dirs
        DIR="$PWD"
        while [ "$DIR" != "/" ]; do
            if [ -f "$DIR/package.json" ]; then
                if jq -e "(.dependencies[\"$PKG_NAME\"] // .devDependencies[\"$PKG_NAME\"] // .peerDependencies[\"$PKG_NAME\"]) != null" "$DIR/package.json" >/dev/null 2>&1; then
                    FOUND=true
                fi
                break
            fi
            DIR=$(dirname "$DIR")
        done
    fi

    if [ "$FOUND" = false ]; then
        NEW_PACKAGES="$NEW_PACKAGES $PKG_NAME"
    fi
done

# Trim whitespace
NEW_PACKAGES=$(echo "$NEW_PACKAGES" | xargs)

if [ -n "$NEW_PACKAGES" ]; then
    echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PreToolUse\",
    \"permissionDecision\": \"ask\",
    \"permissionDecisionReason\": \"Installing NEW package(s) not in project deps: $NEW_PACKAGES (via $MANAGER). Verify these are the correct package names before approving.\"
  }
}"
    exit 0
fi

# All packages already in deps — allow silently
exit 0
