#!/bin/sh
# Exercise the shared Claude Code/Codex hook contract where Git metadata is unavailable.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/edge-odyssey-hook-tests.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
state="$scratch/state"

run_non_git() {
  name=$1 input=$2
  cwd="$scratch/not-a-repo-$name"
  mkdir -p "$cwd"
  printf '{"session_id":"%s","cwd":"%s"}\n' "$input" "$cwd" | EDGE_ODYSSEY_STATE_DIR="$state" "$claude" working
}

run_detached() {
  name=$1 input=$2
  cwd="$scratch/detached-$name"
  mkdir -p "$cwd"
  git -C "$cwd" init -q
  : > "$cwd/file"
  git -C "$cwd" add file
  git -C "$cwd" -c user.name=Test -c user.email=test@example.invalid commit -qm fixture
  git -C "$cwd" checkout --detach -q
  printf '{"session_id":"%s","cwd":"%s"}\n' "$input" "$cwd" | EDGE_ODYSSEY_STATE_DIR="$state" "$claude" waiting
}

claude="$here/hooks/edge-odyssey-hook.sh"
run_non_git claude claude-non-git
run_non_git codex codex-non-git
run_detached claude claude-detached
run_detached codex codex-detached

for id in claude-non-git codex-non-git claude-detached codex-detached; do
  test -f "$state/sessions/$id"
  ! grep -q '^branch ' "$state/sessions/$id"
done
printf '{"session_id":"codex-non-git"}\n' | EDGE_ODYSSEY_STATE_DIR="$state" "$claude" end
! test -e "$state/sessions/codex-non-git"
! find "$state/sessions" -name '.*' -type f | grep -q .

mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }   # GNU, then BSD/macOS

# The state folder and every file in it are this account's only, whatever the caller's umask.
umask 022
run_non_git perms perms-non-git
test "$(mode "$state")" = 700
test "$(mode "$state/sessions")" = 700
test "$(mode "$state/sessions/perms-non-git")" = 600
statusline="$here/hooks/edge-odyssey-statusline.sh"
usage_state="$scratch/usage-state"
printf '{"rate_limits":{"five_hour":{"used_percentage":42}}}\n' | EDGE_ODYSSEY_STATE_DIR="$usage_state" "$statusline"
test "$(mode "$usage_state")" = 700
test "$(mode "$usage_state/usage")" = 600
# ...while the next status-line command keeps the caller's umask
printf '{"rate_limits":{"five_hour":{"used_percentage":42}}}\n' \
  | EDGE_ODYSSEY_STATE_DIR="$usage_state" EDGE_ODYSSEY_STATUSLINE_NEXT='umask' "$statusline" | grep -qx '0*22'

# Only the top-level session_id and cwd count, never a nested one in tool_input or tool_response,
# both with the JSON parser and with the first-match fallback when python3 is unavailable.
decoy_cwd="$scratch/real-cwd"
mkdir -p "$decoy_cwd"
decoy() {
  printf '{"session_id":"real-sid","cwd":"%s","tool_input":{"session_id":"forged_sid","cwd":"/nonexistent/forged"},"tool_response":{"session_id":"forged2","cwd":"/nonexistent/forged2"}}\n' "$decoy_cwd"
}
nopy="$scratch/no-python"
mkdir -p "$nopy"
printf '#!/bin/sh\nexit 127\n' > "$nopy/python3"
chmod +x "$nopy/python3"
for path in "$PATH" "$nopy:$PATH"; do
  decoy | PATH="$path" EDGE_ODYSSEY_STATE_DIR="$state" "$claude" working
  test -f "$state/sessions/real-sid"
  ! test -e "$state/sessions/forged_sid"
  ! test -e "$state/sessions/forged2"
  grep -qxF "cwd $decoy_cwd" "$state/sessions/real-sid"
  ! grep -q forged "$state/sessions/real-sid"
  rm -f "$state/sessions/real-sid"
done

# A repository folder whose name holds a newline (reached through a symlink) still yields one repo line and one branch line.
nl_repo="$scratch/proj
branch injected"
mkdir -p "$nl_repo"
git -C "$nl_repo" init -q -b main
ln -s "$nl_repo" "$scratch/nl-link"
printf '{"session_id":"newline-repo","cwd":"%s"}\n' "$scratch/nl-link" \
  | EDGE_ODYSSEY_STATE_DIR="$state" "$claude" working
test "$(grep -c '^repo ' "$state/sessions/newline-repo")" = 1
test "$(grep -c '^branch ' "$state/sessions/newline-repo")" = 1
grep -qx 'branch main' "$state/sessions/newline-repo"
