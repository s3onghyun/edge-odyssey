#!/bin/sh
# Runs the motion-math tests (Tests/MotionTests). With only the Command Line Tools installed,
# Swift Testing lives outside the default search path, so point the compiler and linker at it.
set -eu
cd "$(dirname "$0")"
fw="$(xcode-select -p)/Library/Developer/Frameworks"
if [ -d "$fw/Testing.framework" ]; then
  swift test -Xswiftc -F -Xswiftc "$fw" -Xlinker -F -Xlinker "$fw" -Xlinker -rpath -Xlinker "$fw" "$@"
else
  swift test "$@"
fi
exec "$PWD/Tests/hook-tests.sh"
