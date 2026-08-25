#!/bin/sh
# Compile and run the InputInjector tests against the real source file.
# The app has no XCTest target, so this builds a small executable
# from the real InputInjector.swift plus the test main and runs it.
# Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SRC="$ROOT/MockTab/Driver/Injection/InputInjector.swift"
TEST="$DIR/InputInjectorTests.swift"
BIN="$(mktemp -d)/input-injector-tests"

if command -v swiftc >/dev/null 2>&1; then
    # We compile the real InputInjector.swift and its dependent snapshot object
    SRC2="$ROOT/MockTab/Driver/Injection/InjectionSnapshot.swift"
    swiftc -O "$SRC" "$SRC2" "$TEST" -o "$BIN"
    "$BIN"
else
    echo "swiftc not found. Skipping execution since this requires a macOS/Swift environment."
fi
