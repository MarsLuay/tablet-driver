#!/bin/sh
# Compile and run the TabletOrientation checks against the real source file.
# The app has no XCTest target, so this builds a small executable from
# TabletOrientation.swift plus the test main and runs it. Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SRC="$ROOT/MockTab/Settings/Model/TabletOrientation.swift"
TEST="$DIR/TabletOrientationTests.swift"
BIN="$(mktemp -d)/tablet-orientation-tests"

swiftc -O "$SRC" "$TEST" -o "$BIN"
"$BIN"