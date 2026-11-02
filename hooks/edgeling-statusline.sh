#!/bin/sh
# Optional status-line wrapper: records the 5-hour usage percentage for the "near limit"
# signal, then hands the same JSON to your existing status-line command (if any).
#   EDGELING_STATUSLINE_NEXT="~/.claude/statusline.sh"   # your current statusLine command
input=$(cat)
dir="${EDGELING_STATE_DIR:-$HOME/.edgeling}"
pct=$(printf '%s' "$input" | sed -n 's/.*"five_hour"[[:space:]]*:[[:space:]]*{[^}]*"used_percentage"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' | head -n 1)
if [ -n "$pct" ] && mkdir -p "$dir" 2>/dev/null; then
  printf '%s %s\n' "$pct" "$(date +%s)" > "$dir/.usage.$$" && mv -f "$dir/.usage.$$" "$dir/usage"
fi
[ -n "${EDGELING_STATUSLINE_NEXT:-}" ] && printf '%s' "$input" | sh -c "$EDGELING_STATUSLINE_NEXT"
exit 0
