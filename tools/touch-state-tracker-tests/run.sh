#!/bin/sh
# Compile and run touch-state intent checks against the real source file.
# The app has no XCTest target, so this builds a small executable from
# TouchStateTracker.swift plus the test main and runs it.
# Exits non-zero on failure.
set -eu

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SRC="$ROOT/MockTab/Driver/Injection/TouchStateTracker.swift"
TEST="$DIR/TouchStateTrackerTests.swift"
TEMP_DIR="$(mktemp -d)"
BIN="$TEMP_DIR/touch-state-tracker-tests"

trap 'rm -rf "$TEMP_DIR"' EXIT

(
  cd "$ROOT/TabletKit"
  swift build --quiet
)
MODULES="$(find "$ROOT/TabletKit/.build" -type d -path '*/debug/Modules' -print -quit)"
OBJECTS="$(find "$ROOT/TabletKit/.build" -type f -path '*/debug/TabletKit.build/*.swift.o' -print)"
if [ -z "$MODULES" ] || [ -z "$OBJECTS" ]; then
  echo "TabletKit Swift module was not built" >&2
  exit 1
fi

swiftc -O -I "$MODULES" "$SRC" "$TEST" $OBJECTS -o "$BIN"
"$BIN"
