#!/bin/bash
# Claude Code statusline — trimmed starter
#
# What it shows (matches the FAQ's "stay aware of what you're spending"):
#   line 1:  CTX% [bar] · tokens  │  cwd
#   line 2:  model  │  duration · cost
#
# Color tiers are the whole point — the eye catches amber/red faster than numbers.
# Drop this in .claude/ and wire it up in settings.json:
#
#   "statusLine": {
#     "type": "command",
#     "command": "~/.claude/statusline.sh",
#     "padding": 0
#   }
#
# Claude Code pipes a JSON blob on stdin with context.usage, cost, model, etc.
# Spec: https://docs.anthropic.com/en/docs/claude-code/statusline

set -u

# ─── Appearance detection (macOS → dark/light follows system) ───
if defaults read -g AppleInterfaceStyle &>/dev/null 2>&1; then
    _MODE=dark
else
    _MODE=light
fi

RESET='\033[0m'
if [[ "$_MODE" == "dark" ]]; then
    C_BRIGHT='\033[38;5;252m'   # primary
    C_DIM='\033[38;5;246m'      # secondary
    C_FAINT='\033[38;5;240m'    # structure (separators)
    C_GREEN='\033[38;5;114m'    # healthy
    C_AMBER='\033[38;5;215m'    # warning
    C_RED='\033[38;5;203m'      # danger
    C_TRACK='\033[38;5;240m'    # bar track
else
    C_BRIGHT='\033[38;5;235m'
    C_DIM='\033[38;5;243m'
    C_FAINT='\033[38;5;249m'
    C_GREEN='\033[38;5;28m'
    C_AMBER='\033[38;5;166m'
    C_RED='\033[38;5;160m'
    C_TRACK='\033[38;5;249m'
fi

DOT="${C_FAINT} · ${RESET}"
SEP=" ${C_FAINT}│${RESET} "

# ─── Parse Claude Code JSON from stdin (single jq call) ───
# Bash 3.2 doesn't support fractional `read -t`, so we use perl for a 100ms stdin read.
input=$(perl -e '
    use IO::Select;
    my $s = IO::Select->new(\*STDIN);
    if ($s->can_read(0.1)) {
        my $line = <STDIN>;
        chomp $line if defined $line;
        print $line // "";
    }
' 2>/dev/null)

ctx_pct="" model_name="" duration_ms="" input_tokens="" cache_read="" cache_creation="" cost_usd=""
if [[ -n "$input" ]] && command -v jq >/dev/null 2>&1; then
    IFS=$'\t' read -r ctx_pct model_name duration_ms input_tokens cache_read cache_creation cost_usd <<< \
        "$(echo "$input" | jq -r '[
            (.context_window.used_percentage // "" | tostring | split(".")[0]),
            (.model.display_name // ""),
            (.cost.total_duration_ms // "" | tostring),
            (.context_window.current_usage.input_tokens // "" | tostring),
            (.context_window.current_usage.cache_read_input_tokens // "" | tostring),
            (.context_window.current_usage.cache_creation_input_tokens // "" | tostring),
            (.cost.total_cost_usd // "" | tostring)
        ] | join("\t")' 2>/dev/null)"
fi

# ─── Context bar (8-char braille, color by tier) ───
ctx_display=""
if [[ -n "$ctx_pct" ]] && [[ "$ctx_pct" =~ ^[0-9]+$ ]] && [[ "$ctx_pct" -gt 0 ]]; then
    if   [[ "$ctx_pct" -ge 85 ]]; then ctx_color="$C_RED"
    elif [[ "$ctx_pct" -ge 60 ]]; then ctx_color="$C_AMBER"
    else                                ctx_color="$C_GREEN"
    fi
    filled=$(( (ctx_pct * 8 + 50) / 100 ))
    [[ "$filled" -gt 8 ]] && filled=8
    [[ "$filled" -lt 0 ]] && filled=0
    bar_filled="" bar_empty=""
    for ((i=0; i<filled; i++)); do bar_filled+="⣿"; done
    for ((i=filled; i<8; i++)); do bar_empty+="⣀"; done
    ctx_display="${ctx_color}${ctx_pct}%${RESET} ${ctx_color}${bar_filled}${RESET}${C_TRACK}${bar_empty}${RESET}"
fi

# ─── Token count (12.3k / 1.2M) ───
tokens_display=""
if [[ -n "$input_tokens" ]] && [[ "$input_tokens" =~ ^[0-9]+$ ]]; then
    total=$((input_tokens + ${cache_read:-0} + ${cache_creation:-0}))
    if   [[ "$total" -ge 1000000 ]]; then tokens_str="$((total/1000000)).$(((total%1000000)/100000))M"
    elif [[ "$total" -ge 1000 ]];    then tokens_str="$((total/1000)).$(((total%1000)/100))k"
    elif [[ "$total" -gt 0 ]];       then tokens_str="${total}"
    else tokens_str=""
    fi
    [[ -n "$tokens_str" ]] && tokens_display="${C_DIM}${tokens_str}${RESET}"
fi

# ─── Session duration (Xh Ym / Ym) ───
dur_display=""
if [[ -n "$duration_ms" ]] && [[ "$duration_ms" =~ ^[0-9]+$ ]] && [[ "$duration_ms" -gt 0 ]]; then
    mins=$((duration_ms / 60000))
    if   [[ "$mins" -ge 60 ]]; then dur_display="${C_DIM}$((mins/60))h$((mins%60))m${RESET}"
    else                             dur_display="${C_DIM}${mins}m${RESET}"
    fi
fi

# ─── Cost ($X.YY, color by tier) ───
cost_display=""
if [[ -n "$cost_usd" ]] && [[ "$cost_usd" != "null" ]] && [[ "$cost_usd" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    cost_fmt=$(printf '$%.2f' "$cost_usd" 2>/dev/null)
    cost_whole=${cost_usd%.*}; [[ -z "$cost_whole" ]] && cost_whole=0
    if   [[ "$cost_whole" -ge 5 ]]; then cost_clr="$C_RED"
    elif [[ "$cost_whole" -ge 1 ]]; then cost_clr="$C_AMBER"
    else                                  cost_clr="$C_DIM"
    fi
    cost_display="${cost_clr}${cost_fmt}${RESET}"
fi

# ─── Working directory (short form: ~/path) ───
cwd="${PWD/#$HOME/~}"
cwd_display="${C_DIM}${cwd}${RESET}"

# ─── Model ───
model_display=""
[[ -n "$model_name" ]] && model_display="${C_BRIGHT}${model_name}${RESET}"

# ─── Compose (2 lines) ───
line1=""
[[ -n "$ctx_display" ]]    && line1+="$ctx_display"
[[ -n "$tokens_display" ]] && { [[ -n "$line1" ]] && line1+="$DOT"; line1+="$tokens_display"; }
[[ -n "$cwd_display" ]]    && { [[ -n "$line1" ]] && line1+="$SEP"; line1+="$cwd_display"; }

line2=""
[[ -n "$model_display" ]] && line2+="$model_display"
[[ -n "$dur_display" ]]   && { [[ -n "$line2" ]] && line2+="$SEP"; line2+="$dur_display"; }
[[ -n "$cost_display" ]]  && { [[ -n "$line2" ]] && line2+="$DOT"; line2+="$cost_display"; }

[[ -n "$line1" ]] && printf "%b\n" "$line1"
[[ -n "$line2" ]] && printf "%b"   "$line2"
