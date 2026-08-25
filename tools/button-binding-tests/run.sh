#!/bin/sh
# Compile and run the ButtonBinding checks against the real source files.
# Exits non-zero on failure. Gracefully exits if swiftc is absent.
set -e

if ! command -v swiftc >/dev/null 2>&1; then
    echo "swiftc not found, skipping ButtonBinding tests."
    exit 0
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SETTINGS="$ROOT/MockTab/Settings"
TEST="$DIR/main.swift"
BIN="$(mktemp -d)/button-binding-tests"

swiftc -O \
    "$SETTINGS/Serialization/UnknownFieldsCodable.swift" \
    "$SETTINGS/Model/ButtonBinding.swift" \
    "$TEST" \
    -o "$BIN"

"$BIN"
