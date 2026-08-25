// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

// InputInjectorTests.swift — Standalone checks for click resolution
// and other deterministic functions within InputInjector.
//
// The app has no XCTest target, so these run as a small executable
// compiled against the real InputInjector.swift.

import Foundation
import CoreGraphics

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

private func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: @autoclosure () -> String,
                                       file: StaticString = #file, line: UInt = #line) {
    expect(a == b, "\(message()) — got \(a), expected \(b)", file: file, line: line)
}

// MARK: - Tests

private func testEdgePinning() {
    let bounds = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    // Test exact center
    let center = CGPoint(x: 500, y: 500)
    expectEqual(InputInjector.pinNearScreenEdges(center, in: bounds), center, "Center should not be pinned")

    // Test near left edge (within 2.0 points)
    let nearLeft = CGPoint(x: 1.0, y: 500)
    let expectedLeft = CGPoint(x: 0.1196, y: 500) // edgePinInset
    expectEqual(InputInjector.pinNearScreenEdges(nearLeft, in: bounds), expectedLeft, "Near left edge should be pinned")

    // Test outside left edge (negative)
    let outsideLeft = CGPoint(x: -1.0, y: 500)
    expectEqual(InputInjector.pinNearScreenEdges(outsideLeft, in: bounds), expectedLeft, "Outside left edge should be pinned to inset")

    // Test near right edge
    let nearRight = CGPoint(x: 999.0, y: 500)
    let expectedRight = CGPoint(x: 999.8804, y: 500) // bounds.maxX - edgePinInset
    expectEqual(InputInjector.pinNearScreenEdges(nearRight, in: bounds), expectedRight, "Near right edge should be pinned")

    // Test near top edge (minY)
    let nearTop = CGPoint(x: 500, y: 1.0)
    let expectedTop = CGPoint(x: 500, y: 0.1196)
    expectEqual(InputInjector.pinNearScreenEdges(nearTop, in: bounds), expectedTop, "Near top edge should be pinned")

    // Test near bottom edge (maxY)
    let nearBottom = CGPoint(x: 500, y: 999.0)
    let expectedBottom = CGPoint(x: 500, y: 999.8804)
    expectEqual(InputInjector.pinNearScreenEdges(nearBottom, in: bounds), expectedBottom, "Near bottom edge should be pinned")
}

// A simple mock struct for InjectionSnapshot that will be linked
// from InjectionSnapshot.swift, but we don't instantiate InputInjector
// because it has dependencies (TabletKit, etc.) we can't compile.
// We only test static methods like edge pinning which are deterministic.

// MARK: - Runner

testEdgePinning()

if failures > 0 {
    print("FAILED: \(failures) of \(checks) checks failed.")
    exit(1)
} else {
    print("PASSED: \(checks) checks passed.")
    exit(0)
}
