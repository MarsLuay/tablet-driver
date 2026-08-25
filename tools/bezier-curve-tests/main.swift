// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// MARK: - Tiny assertion harness

private var failures = 0
private var checks = 0

private func expect(
    _ condition: Bool, _ message: @autoclosure () -> String,
    file: StaticString = #file, line: UInt = #line
) {
    checks += 1
    if !condition {
        failures += 1
        FileHandle.standardError.write(Data("FAIL (\(file):\(line)): \(message())\n".utf8))
    }
}

private func expectNearlyEqual(
    _ actual: Double, _ expected: Double, tolerance: Double = 1e-5, _ message: @autoclosure () -> String,
    file: StaticString = #file, line: UInt = #line
) {
    checks += 1
    if abs(actual - expected) > tolerance {
        failures += 1
        FileHandle.standardError.write(Data("FAIL (\(file):\(line)): \(message()) (expected: \(expected), got: \(actual))\n".utf8))
    }
}

// MARK: - Initialization and Equality Tests

do {
    let curve1 = BezierCurve(p1: CGPoint(x: 0.2, y: 0.3), p2: CGPoint(x: 0.8, y: 0.7))
    let curve2 = BezierCurve(p1: CGPoint(x: 0.2, y: 0.3), p2: CGPoint(x: 0.8, y: 0.7))
    let curve3 = BezierCurve(p1: CGPoint(x: 0.1, y: 0.3), p2: CGPoint(x: 0.8, y: 0.7))

    expect(curve1 == curve2, "Identical curves are equal")
    expect(curve1 != curve3, "Different curves are not equal")

    expect(curve1.p1 == CGPoint(x: 0.2, y: 0.3), "p1 is correctly initialized")
    expect(curve1.p2 == CGPoint(x: 0.8, y: 0.7), "p2 is correctly initialized")
}

// MARK: - Encoding and Decoding Tests

do {
    let original = BezierCurve(p1: CGPoint(x: 0.1, y: 0.9), p2: CGPoint(x: 0.9, y: 0.1))

    let encoder = JSONEncoder()
    let encoded = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(BezierCurve.self, from: encoded)

    expect(original == decoded, "BezierCurve round-trips correctly through JSON")
} catch {
    expect(false, "Failed to encode/decode BezierCurve: \(error)")
}

// MARK: - Evaluation Tests

do {
    // Linear curve (p1: (0.25, 0.25), p2: (0.75, 0.75))
    // Linear mapping should output ~input
    let linear = BezierCurve.linear
    expectNearlyEqual(linear.evaluate(0.0), 0.0, "Linear curve at 0.0")
    expectNearlyEqual(linear.evaluate(0.25), 0.25, "Linear curve at 0.25")
    expectNearlyEqual(linear.evaluate(0.5), 0.5, "Linear curve at 0.5")
    expectNearlyEqual(linear.evaluate(0.75), 0.75, "Linear curve at 0.75")
    expectNearlyEqual(linear.evaluate(1.0), 1.0, "Linear curve at 1.0")

    // Clamping test
    expectNearlyEqual(linear.evaluate(-0.5), 0.0, "Input below 0 is clamped to 0")
    expectNearlyEqual(linear.evaluate(1.5), 1.0, "Input above 1 is clamped to 1")

    // Soft curve (p1: (0.05, 0.5), p2: (0.5, 1.0))
    // Steeper early on
    let soft = BezierCurve.soft
    expectNearlyEqual(soft.evaluate(0.0), 0.0, "Soft curve at 0.0")
    expect(soft.evaluate(0.5) > 0.5, "Soft curve bows upward at 0.5")
    expectNearlyEqual(soft.evaluate(1.0), 1.0, "Soft curve at 1.0")

    // Firm curve (p1: (0.5, 0.0), p2: (0.95, 0.5))
    // Shallower early on
    let firm = BezierCurve.firm
    expectNearlyEqual(firm.evaluate(0.0), 0.0, "Firm curve at 0.0")
    expect(firm.evaluate(0.5) < 0.5, "Firm curve bows downward at 0.5")
    expectNearlyEqual(firm.evaluate(1.0), 1.0, "Firm curve at 1.0")
}

// MARK: - Lookup Table Tests

do {
    let curve = BezierCurve.linear
    let table = curve.buildLookupTable()

    expect(table.count == 256, "Lookup table has exactly 256 entries")

    if table.count == 256 {
        expectNearlyEqual(table[0], 0.0, "First table entry is 0.0")
        expectNearlyEqual(table[127], 127.0/255.0, "Middle table entry is ~0.5")
        expectNearlyEqual(table[255], 1.0, "Last table entry is 1.0")
    }
}

// MARK: - Summary

if failures == 0 {
    print("BezierCurveTests: \(checks) checks passed")
    exit(0)
} else {
    print("BezierCurveTests: \(failures)/\(checks) checks FAILED")
    exit(1)
}
