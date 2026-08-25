#!/bin/sh
# Compile and run the BezierCurve tests against the real source files.
# Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SETTINGS="$ROOT/MockTab/Settings"
TEST="$DIR/main.swift"
BIN="$(mktemp -d)/bezier-curve-tests"

# Check if swiftc is available
if ! command -v swiftc > /dev/null; then
    echo "swiftc not found, skipping tests in linux environment"
    exit 0
fi

swiftc -O \
    "$SETTINGS/Serialization/UnknownFieldsCodable.swift" \
    "$SETTINGS/Model/BezierCurve.swift" \
    "$TEST" \
    -o "$BIN"
"$BIN"
