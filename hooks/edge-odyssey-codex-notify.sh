#!/bin/sh
# Codex `notify` adapter -> Edge Odyssey state file.
# Codex passes a JSON notification payload as an argument; stdin is also accepted for wrappers.
# A notification means Codex is waiting for its user. Never blocks Codex: exits 0, prints nothing.
payload=${1-}
[ -n "$payload" ] || payload=$(cat)
dir="${EDGE_ODYSSEY_STATE_DIR:-$HOME/.edge-odyssey}/sessions"
mkdir -p "$dir" 2>/dev/null || exit 0

# `thread_id` is used by current Codex payloads; accept the hook-style spellings too.
sid=$(printf '%s' "$payload" | sed -n -e 's/.*"thread_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
                                             -e 's/.*"thread-id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
                                             -e 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1 | tr -cd 'A-Za-z0-9_-')
[ -n "$sid" ] || sid=codex-default
cwd=$(printf '%s' "$payload" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
repo=
branch=
if [ -n "$cwd" ]; then
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root=
  [ -n "$root" ] && repo=$(basename "$root")
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null | head -n 1)
fi
tmp="$dir/.$sid.$$"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
{
  printf 'waiting %s\n' "$(date +%s)"
  [ -n "$cwd" ] && printf 'cwd %s\n' "$cwd"
  [ -n "$repo" ] && printf 'repo %s\n' "$repo"
  [ -n "$branch" ] && printf 'branch %s\n' "$branch"
  : # optional branch metadata must not make the state-file write fail
} > "$tmp" && mv -f "$tmp" "$dir/$sid"
exit 0
