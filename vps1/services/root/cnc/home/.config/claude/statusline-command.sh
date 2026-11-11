#!/bin/bash
# Claude Code statusLine script
# Left side (pipe-separated):
#   1. model display name
#   2. thinking/reasoning effort level (only shown if the model/session reports one)
#   3. workspace.project_dir, falling back to current_dir (with $HOME shortened to ~)
# Right side (pipe-separated, right-aligned when terminal width is known):
#   1. percent of context window used
#   2. total context window size in tokens
#   3. percent of 5-hour usage limit used
#   4. percent of 7-day usage limit used

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name')
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')
project_dir=$(printf '%s' "$input" | jq -r '.workspace.project_dir // .workspace.current_dir')
used_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size_raw=$(printf '%s' "$input" | jq -r '.context_window.context_window_size // empty')
ctx_size=$(numfmt --to=si $ctx_size_raw)
five_hour=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Shorten $HOME to ~ in the displayed project dir.
case "$project_dir" in
  "$HOME") project_dir="~" ;;
  "$HOME"/*) project_dir="~${project_dir#$HOME}" ;;
esac

join() {
  local sep=" | " out=""
  for p in "$@"; do
    if [ -z "$out" ]; then
      out="$p"
    else
      out="$out$sep$p"
    fi
  done
  printf '%s' "$out"
}

left_parts=("$model $effort")
left_parts+=("$project_dir")

right_parts=()
[ -n "$used_pct" ] && right_parts+=("$(printf '%.0f' "$used_pct")% of ${ctx_size}")
[ -n "$five_hour" ] && right_parts+=("5h limit: $(printf '%.0f' "$five_hour")%")
[ -n "$seven_day" ] && right_parts+=("7d limit: $(printf '%.0f' "$seven_day")%")

left=$(join "${left_parts[@]}")
right=$(join "${right_parts[@]}")

if [ -z "$right" ]; then
  printf '%s' "$left"
  exit 0
fi

cols=$(tput cols 2>/dev/null)
[ -z "$cols" ] && cols="${COLUMNS:-0}"

# Safety margin: the status line's rendered width can be a few columns
# narrower than what `tput cols` reports (UI chrome/prefix reserved by
# Claude Code, or a stale/inaccurate terminal size in the hook's
# execution context). Reserve a margin so we never overflow and wrap.
margin=6
usable=$(( cols - margin ))

pad=$(( usable - ${#left} - ${#right} ))
if [ "$usable" -gt 0 ] && [ "$pad" -ge 1 ]; then
  printf '%s%*s%s' "$left" "$pad" "" "$right"
else
  printf '%s   %s' "$left" "$right"
fi
