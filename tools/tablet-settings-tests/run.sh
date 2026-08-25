#!/bin/sh
# Compile and run the tablet settings serialization checks.
# Due to dependencies we extract the required structs out of TabletSettings.swift
# Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SETTINGS="$ROOT/MockTab/Settings"
TEST="$DIR/main.swift"
BIN_DIR="$(mktemp -d)"
BIN="$BIN_DIR/tablet-settings-tests"

if ! command -v swiftc >/dev/null 2>&1; then
    # CI environments like the sandbox might not have swiftc.
    echo "swiftc not found, exiting with success"
else
    # we create a file with just the parts we want to test to avoid the AppKit/TabletKit dependencies.
    # extract the structs by matching the start and stopping at the first line that matches exactly 4 spaces and a closing brace.
    sed -n '/^    struct Profile: Identifiable, Codable, Equatable/,/^    \}/p' "$SETTINGS/TabletSettings.swift" > "$BIN_DIR/extracted.swift"
    echo "" >> "$BIN_DIR/extracted.swift"
    sed -n '/^    struct AppProfileBinding: Identifiable, Codable, Equatable/,/^    \}/p' "$SETTINGS/TabletSettings.swift" >> "$BIN_DIR/extracted.swift"
    echo "" >> "$BIN_DIR/extracted.swift"
    sed -n '/^    struct AppOverride: Identifiable, Codable, Equatable/,/^    \}/p' "$SETTINGS/TabletSettings.swift" >> "$BIN_DIR/extracted.swift"

    # wrap them in a pseudo TabletSettings namespace so the test passes
    cat << 'END' > "$BIN_DIR/test_wrapper.swift"
import Foundation
enum TabletSettings {
END
    cat "$BIN_DIR/extracted.swift" >> "$BIN_DIR/test_wrapper.swift"
    echo "}" >> "$BIN_DIR/test_wrapper.swift"

    swiftc -O \
        "$SETTINGS/Serialization/UnknownFieldsCodable.swift" \
        "$BIN_DIR/test_wrapper.swift" \
        "$TEST" \
        -o "$BIN"
    "$BIN"
fi
