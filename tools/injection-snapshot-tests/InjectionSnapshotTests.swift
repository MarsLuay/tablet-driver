// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

// InjectionSnapshotTests.swift — Standalone checks for InjectionSnapshot.
//
// The app has no XCTest target (by design — see the project's test conventions),
// so this runs as a small executable compiled against the real file.
// Run via tools/injection-snapshot-tests/run.sh. Exits non-zero on the first failure.

import Foundation

// MARK: - Tiny assertion harness

private var failures = 0
private var checks = 0

private func expect(_ condition: Bool, _ message: @autoclosure () -> String,
                    file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition {
        failures += 1
        FileHandle.standardError.write(Data("FAIL (\(file):\(line)): \(message())\n".utf8))
    }
}

// MARK: - Tests

private func testCalibrationLookup() {
    let entry1 = CalibrationEntry(
        key: CalibrationKey(orientation: 0, displayUUID: "uuid-1"),
        samples: [],
        transform: CalibrationTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0),
        calibratedAt: Date(),
        maxResidual: 0
    )

    let entry2 = CalibrationEntry(
        key: CalibrationKey(orientation: 1, displayUUID: "uuid-2"),
        samples: [],
        transform: CalibrationTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0),
        calibratedAt: Date(),
        maxResidual: 0
    )

    let activeTool = InjectionSnapshot.Tool(
        pressureLUT: [], smoothingStrength: 0, pressureSmoothingStrength: 0,
        panScrollSpeed: 0, panScrollMomentum: false,
        tipBinding: ButtonBinding(type: .mouseButton, actionValue: 0),
        eraserBinding: ButtonBinding(type: .mouseButton, actionValue: 0),
        penButton1Binding: ButtonBinding(type: .mouseButton, actionValue: 0),
        penButton2Binding: ButtonBinding(type: .mouseButton, actionValue: 0),
        penButton3Binding: ButtonBinding(type: .mouseButton, actionValue: 0),
        penButton4Binding: ButtonBinding(type: .mouseButton, actionValue: 0),
        penButton5Binding: ButtonBinding(type: .mouseButton, actionValue: 0),
        useRotationAsTilt: false, rotationTiltOffsetDegrees: 0, rotationTiltMagnitude: 0
    )

    let snapshot = InjectionSnapshot(
        tabletOrientation: .landscape,
        activeAreaX: 0, activeAreaY: 0, activeAreaWidth: 100, activeAreaHeight: 100,
        proportionalMapping: false,
        targetDisplayIndex: 0,
        toggleDisplayIDs: [],
        calibrationEntries: [entry1, entry2],
        parallaxOffsetX: 0, parallaxOffsetY: 0,
        invertRotation: false, relativeCursorMovement: false,
        tipUpAssistDelay: 0, dragThreshold: 0, doubleClickDistance: 0, doubleClickInterval: 0.5,
        activeTool: activeTool,
        expressKeyBindings: [], bezelButtonBindings: [],
        touchRingButtonBinding: ButtonBinding(type: .mouseButton, actionValue: 0),
        touchRingSlots: [], touchRingActiveSlotIndex: 0,
        touchEnabled: false, touchSensitivity: 0, tapToClick: false,
        twoFingerScroll: false, reverseScrollDirection: false, twoFingerScrollMomentum: false,
        touchAreaX: 0, touchAreaY: 0, touchAreaWidth: 0, touchAreaHeight: 0
    )

    expect(snapshot.calibration(for: .landscape, displayUUID: "uuid-1") == entry1,
           "Should resolve exact match for orientation 0 and uuid-1")
    expect(snapshot.calibration(for: .portrait, displayUUID: "uuid-2") == entry2,
           "Should resolve exact match for orientation 1 and uuid-2")
    expect(snapshot.calibration(for: .landscape, displayUUID: "uuid-2") == nil,
           "Should return nil when display UUID matches but orientation differs")
    expect(snapshot.calibration(for: .portrait, displayUUID: "uuid-1") == nil,
           "Should return nil when orientation matches but display UUID differs")
    expect(snapshot.calibration(for: .landscape, displayUUID: "unknown") == nil,
           "Should return nil for unknown display UUID")
    expect(snapshot.calibration(for: .landscape, displayUUID: "") == nil,
           "Should return nil for empty display UUID (early exit path)")
}

// MARK: - Runner

@main
enum InjectionSnapshotTestRunner {
    static func main() {
        testCalibrationLookup()

        if failures == 0 {
            print("ok — \(checks) checks passed")
            exit(0)
        } else {
            FileHandle.standardError.write(Data("\(failures) of \(checks) checks failed\n".utf8))
            exit(1)
        }
    }
}
