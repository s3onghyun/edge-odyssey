#!/bin/sh
# Claude Code hook -> Edge Odyssey state file. Usage: edge-odyssey-hook.sh <working|waiting|limit|end>
# Reads hook JSON on stdin; writes "<state> <epoch>" plus optional repo metadata atomically.
# Never blocks Claude Code: always exits 0, prints nothing.
dir="${EDGE_ODYSSEY_STATE_DIR:-$HOME/.edge-odyssey}/sessions"
mkdir -p "$dir" 2>/dev/null || exit 0
payload=$(cat)
sid=$(printf '%s' "$payload" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 | tr -cd 'A-Za-z0-9_-')
[ -n "$sid" ] || sid=default
case "$1" in
  end) rm -f "$dir/$sid"; exit 0 ;;
  working|waiting|limit) ;;
  *) exit 0 ;;
esac
tmp="$dir/.$sid.$$"
cwd=$(printf '%s' "$payload" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
repo=
branch=
if [ -n "$cwd" ]; then
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root=
  [ -n "$root" ] && repo=$(basename "$root")
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null | head -n 1)
fi
{
  printf '%s %s\n' "$1" "$(date +%s)"
  [ -n "$cwd" ] && printf 'cwd %s\n' "$cwd"
  [ -n "$repo" ] && printf 'repo %s\n' "$repo"
  [ -n "$branch" ] && printf 'branch %s\n' "$branch"
} > "$tmp" && mv -f "$tmp" "$dir/$sid"
exit 0
