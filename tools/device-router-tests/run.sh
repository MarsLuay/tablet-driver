#!/bin/sh
# Compile and run the device-router unit tests against the real source files.
# The app has no XCTest target, so this builds a small executable
# from DeviceRouter.swift and its dependencies, plus the test main and runs it.
# Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
BIN_DIR="$(mktemp -d)"
trap 'rm -rf "$BIN_DIR"' EXIT

# Collect TabletKit sources
TK_SOURCES=$(find "$ROOT/TabletKit/Sources/TabletKit" -name "*.swift")

# Explicitly list the necessary MockTab dependencies
# DeviceRouter relies directly on these domain models and device types.
# Note: Since the test will be run on a macOS environment with swiftc,
# AppKit and IOKit imports in MockTab classes are expected to resolve.
MOCKTAB_SOURCES="
$ROOT/MockTab/Driver/Devices/DeviceRouter.swift
$ROOT/MockTab/Driver/Devices/DeviceContext.swift
$ROOT/MockTab/Driver/Devices/DeviceInstanceKey.swift
$ROOT/MockTab/Driver/Devices/TabletManager.swift
$ROOT/MockTab/Driver/Devices/WacomKnownDevice.swift
$ROOT/MockTab/Driver/Devices/WacomFallbackDevice.swift
$ROOT/MockTab/Driver/Devices/GenericHIDDigitizer.swift
$ROOT/MockTab/Driver/Devices/DeviceRegistry.swift
"

swiftc -parse-as-library -O $TK_SOURCES $MOCKTAB_SOURCES "$DIR/DeviceRouterTests.swift" -o "$BIN_DIR/device-router-tests"
"$BIN_DIR/device-router-tests"
