#!/bin/sh
# Compile and run the InjectionSnapshot tests against the real source files.
# The app has no XCTest target, so this builds a small executable from
# the required model files plus the test main and runs it. Exits non-zero on failure.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"

SRC1="$ROOT/MockTab/Driver/Injection/InjectionSnapshot.swift"
SRC2="$ROOT/MockTab/Settings/Model/CalibrationData.swift"
SRC3="$ROOT/MockTab/Settings/Model/TabletOrientation.swift"
SRC4="$ROOT/MockTab/Settings/Model/ButtonBinding.swift"
SRC5="$ROOT/MockTab/Settings/Model/ControlSlot.swift"
SRC6="$ROOT/MockTab/Settings/TabletSettings.swift"
SRC7="$ROOT/MockTab/Settings/Model/ToolSettings.swift"
SRC8="$ROOT/MockTab/Settings/Model/CalibrationSample.swift"
SRC9="$ROOT/MockTab/Settings/Model/CalibrationTransform.swift"

TEST="$DIR/InjectionSnapshotTests.swift"
BIN="$(mktemp -d)/injection-snapshot-tests"

swiftc -O "$SRC1" "$SRC2" "$SRC3" "$SRC4" "$SRC5" "$SRC6" "$SRC7" "$SRC8" "$SRC9" "$TEST" -o "$BIN"
"$BIN"
