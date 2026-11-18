#!/bin/sh
# Claude Code hook -> Edge Odyssey state file. Usage: edge-odyssey-hook.sh <working|waiting|limit|end>
# Reads hook JSON on stdin; writes "<state> <epoch>" plus optional repo metadata atomically.
# Never blocks Claude Code: always exits 0, prints nothing.
umask 077   # the state folder and its files are readable by this account only
dir="${EDGE_ODYSSEY_STATE_DIR:-$HOME/.edge-odyssey}/sessions"
mkdir -p "$dir" 2>/dev/null || exit 0
payload=$(cat)
# Only the top-level session_id and cwd count, never a same-named key nested in tool_input or
# tool_response: parse the JSON when python3 can, else take the first match (Claude Code and
# Codex emit the top-level keys first). Control characters are dropped from every value.
if fields=$(printf '%s' "$payload" | python3 -I -c '
import json, re, sys
d = json.loads(sys.stdin.buffer.read())
d = d if isinstance(d, dict) else {}
for k in ("session_id", "cwd"):
    v = d.get(k)
    v = re.sub(r"[\x00-\x1f\x7f]", "", v) if isinstance(v, str) else ""
    sys.stdout.buffer.write(v.encode("utf-8", "replace") + b"\n")
' 2>/dev/null); then
  sid=$(printf '%s\n' "$fields" | sed -n 1p)
  cwd=$(printf '%s\n' "$fields" | sed -n 2p)
else
  first() {
    printf '%s' "$payload" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -n 1 \
      | sed 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//' | tr -d '\000-\037\177'
  }
  sid=$(first session_id)
  cwd=$(first cwd)
fi
sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9_-')
[ -n "$sid" ] || sid=default
case "$1" in
  end) rm -f "$dir/$sid"; exit 0 ;;
  working|waiting|limit) ;;
  *) exit 0 ;;
esac
tmp="$dir/.$sid.$$"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
repo=
branch=
if [ -n "$cwd" ]; then
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root=
  [ -n "$root" ] && repo=$(basename "$root" | tr -d '\000-\037\177')
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null | head -n 1 | tr -d '\000-\037\177')
fi
{
  printf '%s %s\n' "$1" "$(date +%s)"
  [ -n "$cwd" ] && printf 'cwd %s\n' "$cwd"
  [ -n "$repo" ] && printf 'repo %s\n' "$repo"
  [ -n "$branch" ] && printf 'branch %s\n' "$branch"
  : # optional branch metadata must not make the state-file write fail
} > "$tmp" && mv -f "$tmp" "$dir/$sid"
exit 0
