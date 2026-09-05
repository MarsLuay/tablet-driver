#!/bin/sh
set -e

if ! command -v swiftc >/dev/null 2>&1; then
    echo "swiftc not found, skipping hid-capture-tests (Linux sandbox)"
    exit 0
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"

SRC="$ROOT/MockTab/Driver/HID/HIDCapture.swift"
TEST="$DIR/HIDCaptureTests.swift"
BIN="$(mktemp -d)/hid-capture-tests"

swiftc -O "$SRC" "$TEST" -o "$BIN"
"$BIN"
