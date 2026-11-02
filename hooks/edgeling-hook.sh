#!/bin/sh
# Claude Code hook -> Edgeling state file. Usage: edgeling-hook.sh <working|waiting|limit|end>
# Reads the hook JSON on stdin only to find session_id; writes "<state> <epoch>" atomically.
# Never blocks Claude Code: always exits 0, prints nothing.
dir="${EDGELING_STATE_DIR:-$HOME/.edgeling}/sessions"
mkdir -p "$dir" 2>/dev/null || exit 0
sid=$(sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 | tr -cd 'A-Za-z0-9_-')
[ -n "$sid" ] || sid=default
case "$1" in
  end) rm -f "$dir/$sid"; exit 0 ;;
  working|waiting|limit) ;;
  *) exit 0 ;;
esac
tmp="$dir/.$sid.$$"
printf '%s %s\n' "$1" "$(date +%s)" > "$tmp" && mv -f "$tmp" "$dir/$sid"
exit 0
