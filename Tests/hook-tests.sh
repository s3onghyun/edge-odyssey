#!/bin/sh
# Exercise the hook contract where Git metadata is unavailable: both hooks must still publish
# their state atomically and leave no temporary state files behind.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/edge-odyssey-hook-tests.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
state="$scratch/state"

run_non_git() {
  name=$1 script=$2 input=$3
  cwd="$scratch/not-a-repo-$name"
  mkdir -p "$cwd"
  if [ "$name" = claude ]; then
    printf '{"session_id":"%s","cwd":"%s"}\n' "$input" "$cwd" | EDGE_ODYSSEY_STATE_DIR="$state" "$script" working
  else
    EDGE_ODYSSEY_STATE_DIR="$state" "$script" "{\"thread_id\":\"$input\",\"cwd\":\"$cwd\"}"
  fi
}

run_detached() {
  name=$1 script=$2 input=$3
  cwd="$scratch/detached-$name"
  mkdir -p "$cwd"
  git -C "$cwd" init -q
  : > "$cwd/file"
  git -C "$cwd" add file
  git -C "$cwd" -c user.name=Test -c user.email=test@example.invalid commit -qm fixture
  git -C "$cwd" checkout --detach -q
  if [ "$name" = claude ]; then
    printf '{"session_id":"%s","cwd":"%s"}\n' "$input" "$cwd" | EDGE_ODYSSEY_STATE_DIR="$state" "$script" waiting
  else
    EDGE_ODYSSEY_STATE_DIR="$state" "$script" "{\"thread_id\":\"$input\",\"cwd\":\"$cwd\"}"
  fi
}

claude="$here/hooks/edge-odyssey-hook.sh"
codex="$here/hooks/edge-odyssey-codex-notify.sh"
run_non_git claude "$claude" claude-non-git
run_non_git codex "$codex" codex-non-git
run_detached claude "$claude" claude-detached
run_detached codex "$codex" codex-detached

for id in claude-non-git codex-non-git claude-detached codex-detached; do
  test -f "$state/sessions/$id"
  ! rg -q '^branch ' "$state/sessions/$id"
done
! find "$state/sessions" -name '.*' -type f | rg -q .
