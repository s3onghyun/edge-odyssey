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
  ! rg -q '^branch ' "$state/sessions/$id"
done
printf '{"session_id":"codex-non-git"}\n' | EDGE_ODYSSEY_STATE_DIR="$state" "$claude" end
! test -e "$state/sessions/codex-non-git"
! find "$state/sessions" -name '.*' -type f | rg -q .
