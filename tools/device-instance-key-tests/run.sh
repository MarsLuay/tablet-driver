#!/bin/sh
# Compile and run the standalone DeviceInstanceKey tests against the real
# source file. The app has no XCTest target, so this builds a small
# executable from DeviceInstanceKey.swift plus the test main and runs it.
# Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SRC="$ROOT/MockTab/Driver/Devices/DeviceInstanceKey.swift"
TEST="$DIR/DeviceInstanceKeyTests.swift"
BIN="$(mktemp -d)/device-instance-key-tests"

swiftc -O "$SRC" "$TEST" -o "$BIN"
"$BIN"
