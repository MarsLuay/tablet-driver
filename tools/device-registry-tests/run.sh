#!/bin/sh
# Compile and run the device-registry checks against the real source files.
# The app has no XCTest target, so this builds a small executable.
# Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"

# We compile DeviceRegistry.swift and DeviceInstanceKey.swift
SRC1="$ROOT/MockTab/Driver/Devices/DeviceRegistry.swift"
SRC2="$ROOT/MockTab/Driver/Devices/DeviceInstanceKey.swift"

TEST="$DIR/DeviceRegistryTests.swift"
BIN="$(mktemp -d)/device-registry-tests"

swiftc -O "$SRC1" "$SRC2" "$TEST" -o "$BIN"
"$BIN"
