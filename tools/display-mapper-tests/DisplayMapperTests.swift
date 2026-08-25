// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

// DisplayMapperTests.swift — Standalone checks for DisplayMapper mapping logic.
//
// The app has no XCTest target (by design — see the project's test conventions),
// so these run as a small executable compiled against the real DisplayMapper.swift.
// Run via tools/display-mapper-tests/run.sh. Exits non-zero on the first failure.

import Foundation
import CoreGraphics
import AppKit

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

private func expectClose(_ a: Double, _ b: Double, _ tol: Double = 1e-9,
                         _ message: @autoclosure () -> String,
                         file: StaticString = #file, line: UInt = #line) {
    expect(abs(a - b) <= tol, "\(message()) — got \(a), expected \(b) (±\(tol))",
           file: file, line: line)
}

// MARK: - Tests

@MainActor
private func testMapToScreenDefault() {
    var mapper = DisplayMapper()
    let point = TabletPoint(
        x: 500, y: 500, maxX: 1000, maxY: 1000,
        pressure: 0, maxPressure: 1023, tiltX: 0, tiltY: 0,
        penButton1: false, penButton2: false, eraser: false,
        inProximity: true, hoverDistance: 0
    )
    let snapshot = InjectionSnapshot(
        tabletOrientation: .landscape,
        activeAreaX: 0.0,
        activeAreaY: 0.0,
        activeAreaWidth: 1.0,
        activeAreaHeight: 1.0,
        proportionalMapping: false,
        targetDisplayIndex: 1, // Assumes main display in test environment
        toggleDisplayIDs: [],
        calibrationEntries: [],
        parallaxOffsetX: 0,
        parallaxOffsetY: 0,
        invertRotation: false,
        relativeCursorMovement: false,
        tipUpAssistDelay: 0,
        dragThreshold: 0,
        doubleClickDistance: 0,
        doubleClickInterval: 0,
        activeTool: InjectionSnapshot.Tool(
            pressureLUT: [], smoothingStrength: 0, pressureSmoothingStrength: 0,
            panScrollSpeed: 0, panScrollMomentum: false,
            tipBinding: .none, eraserBinding: .none, penButton1Binding: .none,
            penButton2Binding: .none, penButton3Binding: .none,
            penButton4Binding: .none, penButton5Binding: .none,
            useRotationAsTilt: false, rotationTiltOffsetDegrees: 0,
            rotationTiltMagnitude: 0
        ),
        expressKeyBindings: [], bezelButtonBindings: [], touchRingButtonBinding: .none,
        touchRingSlots: [], touchRingActiveSlotIndex: 0, touchEnabled: false,
        touchSensitivity: 0, tapToClick: false, twoFingerScroll: false,
        reverseScrollDirection: false, twoFingerScrollMomentum: false,
        touchAreaX: 0, touchAreaY: 0, touchAreaWidth: 1, touchAreaHeight: 1
    )

    // Test that the mapper doesn't crash when given valid inputs
    if let _ = mapper.mapToScreen(point, snapshot: snapshot, deviceProductID: 123) {
        expect(true, "mapToScreen successfully mapped a point")
    } else {
        expect(false, "mapToScreen returned nil for a valid active area point")
    }
}

@MainActor
private func testMapToScreenPortrait() {
    var mapper = DisplayMapper()
    let point = TabletPoint(
        x: 1000, y: 0, maxX: 1000, maxY: 1000,
        pressure: 0, maxPressure: 1023, tiltX: 0, tiltY: 0,
        penButton1: false, penButton2: false, eraser: false,
        inProximity: true, hoverDistance: 0
    ) // Top right in raw

    let snapshot = InjectionSnapshot(
        tabletOrientation: .portrait,
        activeAreaX: 0.0,
        activeAreaY: 0.0,
        activeAreaWidth: 1.0,
        activeAreaHeight: 1.0,
        proportionalMapping: false,
        targetDisplayIndex: 1, // Assumes main display in test environment
        toggleDisplayIDs: [],
        calibrationEntries: [],
        parallaxOffsetX: 0,
        parallaxOffsetY: 0,
        invertRotation: false,
        relativeCursorMovement: false,
        tipUpAssistDelay: 0,
        dragThreshold: 0,
        doubleClickDistance: 0,
        doubleClickInterval: 0,
        activeTool: InjectionSnapshot.Tool(
            pressureLUT: [], smoothingStrength: 0, pressureSmoothingStrength: 0,
            panScrollSpeed: 0, panScrollMomentum: false,
            tipBinding: .none, eraserBinding: .none, penButton1Binding: .none,
            penButton2Binding: .none, penButton3Binding: .none,
            penButton4Binding: .none, penButton5Binding: .none,
            useRotationAsTilt: false, rotationTiltOffsetDegrees: 0,
            rotationTiltMagnitude: 0
        ),
        expressKeyBindings: [], bezelButtonBindings: [], touchRingButtonBinding: .none,
        touchRingSlots: [], touchRingActiveSlotIndex: 0, touchEnabled: false,
        touchSensitivity: 0, tapToClick: false, twoFingerScroll: false,
        reverseScrollDirection: false, twoFingerScrollMomentum: false,
        touchAreaX: 0, touchAreaY: 0, touchAreaWidth: 1, touchAreaHeight: 1
    )

    // In portrait, Top Right raw goes to Top Left screen
    if let result = mapper.mapToScreen(point, snapshot: snapshot, deviceProductID: 123) {
        expectClose(result.y, 0.0, 2.0, "Portrait Top Right raw maps to Y=0")
    } else {
        expect(false, "mapToScreen returned nil")
    }
}

@MainActor
private func testResolveRelativePoint() {
    var mapper = DisplayMapper()
    let startPoint = TabletPoint(
        x: 500, y: 500, maxX: 1000, maxY: 1000,
        pressure: 0, maxPressure: 1023, tiltX: 0, tiltY: 0,
        penButton1: false, penButton2: false, eraser: false,
        inProximity: true, hoverDistance: 0
    )

    let snapshot = InjectionSnapshot(
        tabletOrientation: .landscape,
        activeAreaX: 0.0,
        activeAreaY: 0.0,
        activeAreaWidth: 1.0,
        activeAreaHeight: 1.0,
        proportionalMapping: false,
        targetDisplayIndex: 1, // Assumes main display in test environment
        toggleDisplayIDs: [],
        calibrationEntries: [],
        parallaxOffsetX: 0,
        parallaxOffsetY: 0,
        invertRotation: false,
        relativeCursorMovement: true,
        tipUpAssistDelay: 0,
        dragThreshold: 0,
        doubleClickDistance: 0,
        doubleClickInterval: 0,
        activeTool: InjectionSnapshot.Tool(
            pressureLUT: [], smoothingStrength: 0, pressureSmoothingStrength: 0,
            panScrollSpeed: 0, panScrollMomentum: false,
            tipBinding: .none, eraserBinding: .none, penButton1Binding: .none,
            penButton2Binding: .none, penButton3Binding: .none,
            penButton4Binding: .none, penButton5Binding: .none,
            useRotationAsTilt: false, rotationTiltOffsetDegrees: 0,
            rotationTiltMagnitude: 0
        ),
        expressKeyBindings: [], bezelButtonBindings: [], touchRingButtonBinding: .none,
        touchRingSlots: [], touchRingActiveSlotIndex: 0, touchEnabled: false,
        touchSensitivity: 0, tapToClick: false, twoFingerScroll: false,
        reverseScrollDirection: false, twoFingerScrollMomentum: false,
        touchAreaX: 0, touchAreaY: 0, touchAreaWidth: 1, touchAreaHeight: 1
    )

    let currentCursor = CGPoint(x: 960.0, y: 540.0)

    // We can call recomputeVirtualScreenBounds directly on the MainActor
    // without the deadlocking DispatchQueue.main.sync call
    mapper.recomputeVirtualScreenBounds()

    // First call anchors the point
    let result1 = mapper.resolveRelativePoint(startPoint, snapshot: snapshot, currentCursorPosition: currentCursor, deviceProductID: 123)
    expectClose(result1.x, 960.0, 0.1, "First point returns current position")
    expectClose(result1.y, 540.0, 0.1, "First point returns current position")

    // Move pen by 10% on X
    let endPoint = TabletPoint(
        x: 600, y: 500, maxX: 1000, maxY: 1000,
        pressure: 0, maxPressure: 1023, tiltX: 0, tiltY: 0,
        penButton1: false, penButton2: false, eraser: false,
        inProximity: true, hoverDistance: 0
    )
    let result2 = mapper.resolveRelativePoint(endPoint, snapshot: snapshot, currentCursorPosition: currentCursor, deviceProductID: 123)

    expect(result2.x > 960.0, "X moved right")
    expectClose(result2.y, 540.0, 0.1, "Y did not move")
}

@main
enum DisplayMapperTestRunner {
    @MainActor static func main() {
        testMapToScreenDefault()
        testMapToScreenPortrait()
        testResolveRelativePoint()

        if failures == 0 {
            print("ok — \(checks) checks passed")
            exit(0)
        } else {
            FileHandle.standardError.write(Data("\(failures) of \(checks) checks failed\n".utf8))
            exit(1)
        }
    }
}
