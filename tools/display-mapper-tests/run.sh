#!/bin/sh
# Compile and run the DisplayMapper mapping checks against the real source files.
# The app has no XCTest target, so this builds a small executable from
# the required module files plus the test main and runs it. Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"

# Gather the required source files for compilation dynamically using find
SRC_FILES=$(find \
    "$ROOT/MockTab/Settings/Model" \
    "$ROOT/TabletKit/Sources/TabletKit/Registry" \
    "$ROOT/TabletKit/Sources/TabletKit/Core" \
    -name "*.swift")

# Include the specific App level sources needed
SRC_FILES="$SRC_FILES \
$ROOT/MockTab/Driver/Mapping/DisplayMapper.swift \
$ROOT/MockTab/Driver/Injection/InjectionSnapshot.swift \
$ROOT/MockTab/Settings/TabletSettings.swift \
$ROOT/MockTab/Settings/TabletSettings+Presets.swift \
$ROOT/MockTab/Settings/TabletSettings+AppOverrides.swift \
$ROOT/MockTab/Settings/TabletSettings+Persistence.swift \
$ROOT/MockTab/Driver/Devices/DeviceInstanceKey.swift"

TEST="$DIR/DisplayMapperTests.swift"
BIN="$(mktemp -d)/display-mapper-tests"

swiftc -O $SRC_FILES "$TEST" -o "$BIN"
"$BIN"
