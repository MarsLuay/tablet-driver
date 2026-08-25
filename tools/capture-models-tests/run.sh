#!/bin/sh
# Compile and run the capture models checks against the real source file.
# The app has no XCTest target, so this builds a small executable.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SRC="$ROOT/MockTab/Driver/Discovery/CaptureModels.swift"
TEST="$DIR/CaptureModelsTests.swift"
BIN="$(mktemp -d)/capture-models-tests"

if ! command -v swiftc >/dev/null 2>&1; then
    echo "swiftc not found, skipping compilation in sandbox environment"
    exit 0
fi

swiftc -O "$SRC" "$TEST" -o "$BIN"
"$BIN"