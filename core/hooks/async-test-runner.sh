#!/bin/bash
# PostToolUse hook (async): Run tests in background after file writes/edits
# Catches test regressions immediately after source changes
#
# Matcher: Write|Edit
# Receives: tool_name, tool_input on stdin
# Returns: systemMessage with test results

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Bail if no file path
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Skip test files themselves — don't trigger tests-on-tests
case "$FILE_PATH" in
    *.test.*|*.spec.*|*__tests__/*)
        exit 0
        ;;
esac

# Skip non-source files
case "$FILE_PATH" in
    *.ts|*.tsx|*.js|*.jsx)
        ;; # continue
    *)
        exit 0
        ;;
esac

# Find the nearest package.json by walking up from the file
DIR=$(dirname "$FILE_PATH")
PKG_DIR=""
while [ "$DIR" != "/" ] && [ "$DIR" != "." ]; do
    if [ -f "$DIR/package.json" ]; then
        PKG_DIR="$DIR"
        break
    fi
    DIR=$(dirname "$DIR")
done

if [ -z "$PKG_DIR" ]; then
    exit 0
fi

# Check if project has a test script
HAS_TEST=$(jq -r '.scripts.test // empty' "$PKG_DIR/package.json" 2>/dev/null)
if [ -z "$HAS_TEST" ]; then
    exit 0
fi

# Run tests from the project directory
cd "$PKG_DIR" || exit 0
TEST_OUTPUT=$(pnpm test --run 2>&1 | tail -20)
TEST_EXIT=$?

if [ $TEST_EXIT -eq 0 ]; then
    SUMMARY="Tests passed."
else
    SUMMARY="Tests FAILED. Recent output:\n${TEST_OUTPUT}"
fi

echo "{
  \"hookSpecificOutput\": {
    \"hookEventName\": \"PostToolUse\",
    \"systemMessage\": $(echo "Test results: $SUMMARY" | jq -Rs .)
  }
}"
exit 0
