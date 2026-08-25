#!/bin/sh
# Compile and run the HID descriptor reader checks against the real source file.
# The app has no XCTest target, so this builds a small executable from
# HIDDescriptorReader.swift plus the test main and runs it. Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SRC="$ROOT/MockTab/Driver/HID/HIDDescriptorReader.swift"
TEST="$DIR/HIDDescriptorReaderTests.swift"
BIN="$(mktemp -d)/hid-descriptor-reader-tests"

swiftc -O "$SRC" "$TEST" -o "$BIN"
"$BIN"
