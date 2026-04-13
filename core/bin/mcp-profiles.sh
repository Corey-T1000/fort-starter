#!/usr/bin/env bash
# mcp-profiles.sh — Toggle MCP server profiles for context management
# Modifies enabledMcpjsonServers in settings.local.json
# Requires: jq

set -euo pipefail

# Source Fort environment
_FORT_ENV="${FORT_ROOT:-$HOME/claudes-fort}/.fort-env"
[ -f "$_FORT_ENV" ] && . "$_FORT_ENV"
FORT_ROOT="${FORT_ROOT:-$HOME/claudes-fort}"

FORT_DIR="$FORT_ROOT"
SETTINGS="$FORT_DIR/.claude/settings.local.json"
PROJECT_MCP="$FORT_DIR/.mcp.json"
PROFILE_FILE="$FORT_DIR/.claude/.mcp-profile"

# Tool count lookup (approximate)
tool_count() {
  case "$1" in
    playwright) echo "22" ;;
    nano-banana) echo "1" ;;
    figma) echo "10" ;;
    *) echo "?" ;;
  esac
}

# Check if profile wants chrome disabled
profile_wants_chrome() {
  case "$1" in
    lean|creative|design) echo "no" ;;
    browser|full) echo "yes" ;;
    *) echo "yes" ;;
  esac
}

usage() {
  cat <<'EOF'
Usage: mcp-profiles.sh <command>

Profiles:
  lean       No MCP servers, no Chrome (~40+ tools freed)
  browser    Playwright + Chrome (~40 tools)
  creative   Nano Banana only, no Chrome (~1 tool)
  design     Figma only, no Chrome (~10 tools)
  full       Everything on (~41 tools)

Commands:
  status     Show current MCP state
  on <name>  Enable a specific server
  off <name> Disable a specific server
  launch     Print the right `claude` command for current profile
EOF
}

show_status() {
  local current_profile
  current_profile=$(cat "$PROFILE_FILE" 2>/dev/null || echo "unknown")

  echo "=== MCP Profile Status ==="
  echo "Active profile: $current_profile"
  echo ""

  # Available servers in .mcp.json
  echo "Available (in .mcp.json):"
  if [ -f "$PROJECT_MCP" ]; then
    jq -r '.mcpServers | keys[]' "$PROJECT_MCP" 2>/dev/null | while read -r name; do
      tools=$(tool_count "$name")
      echo "  $name (~${tools} tools)"
    done
  else
    echo "  (no .mcp.json found)"
  fi
  echo ""

  # Currently enabled
  echo "Enabled project servers:"
  if [ -f "$SETTINGS" ]; then
    enabled=$(jq -r '.enabledMcpjsonServers // [] | .[]' "$SETTINGS" 2>/dev/null)
    if [ -z "$enabled" ]; then
      echo "  (none)"
    else
      echo "$enabled" | while read -r name; do
        tools=$(tool_count "$name")
        echo "  $name (~${tools} tools)"
      done
    fi
  else
    echo "  (no settings.local.json found)"
  fi
  echo ""

  # Chrome status
  local chrome_flag
  chrome_flag=$(profile_wants_chrome "$current_profile")
  echo "Claude-in-Chrome (~18 tools): $([ "$chrome_flag" = "yes" ] && echo "ON" || echo "OFF (use --no-chrome)")"
  echo ""

  # Plugin-provided MCP servers
  echo "Always on (lightweight):"
  echo "  context7 (~2 tools)"
  echo "  cco-mcp (~1 tool)"
  echo ""

  # Launch hint
  echo "Launch command:"
  print_launch "$current_profile"
}

print_launch() {
  local profile="${1:-$(cat "$PROFILE_FILE" 2>/dev/null || echo "full")}"
  local chrome_flag
  chrome_flag=$(profile_wants_chrome "$profile")

  if [ "$chrome_flag" = "no" ]; then
    echo "  claude --no-chrome"
  else
    echo "  claude"
  fi
}

set_profile() {
  local profile="$1"
  local servers

  case "$profile" in
    lean)
      servers='[]'
      ;;
    browser)
      servers='["playwright"]'
      ;;
    creative)
      servers='["nano-banana"]'
      ;;
    design)
      servers='["figma"]'
      ;;
    full)
      servers='["playwright", "nano-banana"]'
      ;;
    *)
      echo "Unknown profile: $profile"
      usage
      exit 1
      ;;
  esac

  # Update settings.local.json
  jq --argjson servers "$servers" '.enabledMcpjsonServers = $servers' "$SETTINGS" > "$SETTINGS.tmp"
  mv "$SETTINGS.tmp" "$SETTINGS"

  # Save current profile name
  echo "$profile" > "$PROFILE_FILE"

  local chrome_flag
  chrome_flag=$(profile_wants_chrome "$profile")

  echo "Switched to '$profile' profile"
  echo ""

  # Show what changed
  if [ "$servers" = "[]" ]; then
    echo "  Project MCP servers: none"
  else
    echo "  Project MCP servers: $(echo "$servers" | jq -r 'join(", ")')"
  fi

  if [ "$chrome_flag" = "no" ]; then
    echo "  Claude-in-Chrome: OFF"
  else
    echo "  Claude-in-Chrome: ON"
  fi
  echo ""

  echo "To apply, restart with:"
  print_launch "$profile"
}

toggle_server() {
  local action="$1"
  local server="$2"

  # Verify server exists in .mcp.json
  if ! jq -e ".mcpServers[\"$server\"]" "$PROJECT_MCP" > /dev/null 2>&1; then
    echo "Server '$server' not found in .mcp.json"
    echo "Available: $(jq -r '.mcpServers | keys | join(", ")' "$PROJECT_MCP")"
    exit 1
  fi

  if [ "$action" = "on" ]; then
    jq --arg s "$server" '.enabledMcpjsonServers = ((.enabledMcpjsonServers // []) + [$s] | unique)' "$SETTINGS" > "$SETTINGS.tmp"
    mv "$SETTINGS.tmp" "$SETTINGS"
    echo "Enabled: $server"
  else
    jq --arg s "$server" '.enabledMcpjsonServers = [.enabledMcpjsonServers[] | select(. != $s)]' "$SETTINGS" > "$SETTINGS.tmp"
    mv "$SETTINGS.tmp" "$SETTINGS"
    echo "Disabled: $server"
  fi

  echo "Restart session to apply."
}

# Main
case "${1:-}" in
  status)
    show_status
    ;;
  lean|browser|creative|design|full)
    set_profile "$1"
    ;;
  on|off)
    if [ -z "${2:-}" ]; then
      echo "Usage: mcp-profiles.sh $1 <server-name>"
      exit 1
    fi
    toggle_server "$1" "$2"
    ;;
  launch)
    print_launch
    ;;
  *)
    usage
    exit 1
    ;;
esac
