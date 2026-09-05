#!/bin/sh
# Compile focused touch momentum checks against the production tracker.
set -eu

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SRC="$ROOT/MockTab/Driver/Injection/TouchStateTracker.swift"
TEST="$DIR/TouchMomentumTests.swift"
BIN="$(mktemp -d)/touch-momentum-tests"

(
  cd "$ROOT/TabletKit"
  swift build --quiet
)
MODULES="$(find "$ROOT/TabletKit/.build" -type d -path '*/debug/Modules' -print -quit)"
OBJECTS="$(find "$ROOT/TabletKit/.build" -type f -path '*/debug/TabletKit.build/*.swift.o' -print)"
[ -n "$MODULES" ] && [ -n "$OBJECTS" ]

swiftc -O -I "$MODULES" "$SRC" "$TEST" $OBJECTS -o "$BIN"
"$BIN"
