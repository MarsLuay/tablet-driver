#!/bin/sh
set -e

if ! command -v swiftc >/dev/null 2>&1; then
    echo "swiftc not found, skipping hid-helpers-tests (Linux sandbox)"
    exit 0
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"

SRC="$ROOT/MockTab/Driver/HID/HIDHelpers.swift"
TEST="$DIR/main.swift"
BIN="$(mktemp -d)/hid-helpers-tests"

swiftc -O "$SRC" "$TEST" -o "$BIN"
"$BIN"
