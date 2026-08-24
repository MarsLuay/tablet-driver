#!/bin/sh
# Compile and run the profile serialization checks against the real source files.
# Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SETTINGS="$ROOT/MockTab/Settings"
TEST="$DIR/main.swift"
BIN="$(mktemp -d)/profile-serialization-tests"

swiftc -O \
    "$SETTINGS/Serialization/UnknownFieldsCodable.swift" \
    "$SETTINGS/Model/ButtonBinding.swift" \
    "$SETTINGS/Model/BezierCurve.swift" \
    "$SETTINGS/Serialization/Profile.swift" \
    "$TEST" \
    -o "$BIN"
"$BIN"
