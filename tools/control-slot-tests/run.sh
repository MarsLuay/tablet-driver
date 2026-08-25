#!/bin/sh
# Compile and run ControlSlot tests using standalone testing.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SETTINGS="$ROOT/MockTab/Settings"
TEST="$DIR/main.swift"
BIN="$(mktemp -d)/control-slot-tests"

swiftc -O \
    "$SETTINGS/Serialization/UnknownFieldsCodable.swift" \
    "$SETTINGS/Model/ButtonBinding.swift" \
    "$SETTINGS/Model/ControlSlot.swift" \
    "$TEST" \
    -o "$BIN"
"$BIN"
