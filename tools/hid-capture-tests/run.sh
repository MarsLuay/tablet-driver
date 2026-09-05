#!/bin/sh
# Compile and run the HIDCapture tests against the real source file.
# Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SRC="$ROOT/MockTab/Driver/HID/HIDCapture.swift"
TEST="$DIR/HIDCaptureTests.swift"
BIN="$(mktemp -d)/hid-capture-tests"

if command -v swiftc >/dev/null 2>&1; then
    swiftc -O "$SRC" "$TEST" -o "$BIN"
    "$BIN"
else
    echo "swiftc not found. Skipping execution since this requires a macOS/Swift environment."
fi
