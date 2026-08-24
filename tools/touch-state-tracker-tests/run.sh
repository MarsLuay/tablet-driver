#!/bin/sh
# Compile and run the touch-state tracker checks against the real source file.
# The app has no XCTest target, so this builds a small executable from
# TouchStateTracker.swift plus the test main and runs it.
# Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
SRC="$ROOT/MockTab/Driver/Injection/TouchStateTracker.swift"
TEST="$DIR/TouchStateTrackerTests.swift"
TEMP_DIR="$(mktemp -d)"
BIN="$TEMP_DIR/touch-state-tracker-tests"

trap 'rm -rf "$TEMP_DIR"' EXIT

# Mock the TabletKit TouchContact to avoid needing to link the whole Swift Package
cat << 'MOCK_EOF' > "$DIR/MockTabletKit.swift"
public struct TouchContact: Equatable {
    public let id: Int
    public let x: Int
    public let y: Int
    public let contactArea: Int?

    public init(id: Int, x: Int, y: Int, contactArea: Int?) {
        self.id = id
        self.x = x
        self.y = y
        self.contactArea = contactArea
    }
}
MOCK_EOF

# Remove "import TabletKit" from TouchStateTracker.swift temporarily for tests
TEMP_SRC="$TEMP_DIR/TouchStateTracker.swift"
grep -v "import TabletKit" "$SRC" > "$TEMP_SRC"

swiftc -O "$TEMP_SRC" "$DIR/MockTabletKit.swift" "$TEST" -o "$BIN"
"$BIN"
