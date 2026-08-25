#!/bin/sh
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SRC1="$ROOT/MockTab/Driver/Injection/PanScrollTracker.swift"
SRC2="$ROOT/TabletKit/Sources/TabletKit/Smoothing/PanSmoother.swift"
TEST="$DIR/PanScrollTrackerTests.swift"
BIN="$(mktemp -d)/pan-scroll-tracker-tests"

swiftc -O "$SRC1" "$SRC2" "$TEST" -o "$BIN"
"$BIN"
