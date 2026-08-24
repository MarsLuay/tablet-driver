// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

// CalibrationDataTests.swift — Standalone checks for the CalibrationData models.

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

private func expectClose(_ a: Double, _ b: Double, _ tol: Double = 1e-9,
                         _ message: @autoclosure () -> String,
                         file: StaticString = #file, line: UInt = #line) {
    expect(abs(a - b) <= tol, "\(message()) — got \(a), expected \(b) (±\(tol))",
           file: file, line: line)
}

private func expectEqual<T: Equatable>(_ a: T, _ b: T,
                                       _ message: @autoclosure () -> String,
                                       file: StaticString = #file, line: UInt = #line) {
    expect(a == b, "\(message()) — got \(a), expected \(b)", file: file, line: line)
}

// MARK: - Tests

private func testCalibrationKeyEncodingDecoding() {
    let original = CalibrationKey(orientation: 2, displayUUID: "1234-5678-90")
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    do {
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(CalibrationKey.self, from: data)
        expectEqual(decoded.orientation, original.orientation, "orientation should match")
        expectEqual(decoded.displayUUID, original.displayUUID, "displayUUID should match")
    } catch {
        expect(false, "Encoding/Decoding failed: \(error)")
    }
}

private func testCalibrationKeyLegacyDecoding() {
    let json = """
    {
        "orientation": 1,
        "displayID": 69733250
    }
    """.data(using: .utf8)!

    let decoder = JSONDecoder()
    do {
        let decoded = try decoder.decode(CalibrationKey.self, from: json)
        expectEqual(decoded.orientation, 1, "orientation should match")
        // The displayID 69733250 translates to some vendor, model, serial.
        // As a unit test, we just check that it produces the corresponding UUID string.
        let expectedUUID = CalibrationKey.uuidString(for: 69733250)
        expectEqual(decoded.displayUUID, expectedUUID, "displayUUID should match legacy displayID resolution")
    } catch {
        expect(false, "Legacy Decoding failed: \(error)")
    }
}

private func testCalibrationKeyUUIDString() {
    expectEqual(CalibrationKey.uuidString(for: 0), "", "Invalid display ID should yield empty string")
    // NOTE: In CoreGraphics, invalid vendor is 0xFFFF_FFFF. We can't trivially craft a CGDirectDisplayID
    // that produces exactly that vendor without mocking or specific knowledge of macOS implementation.
    // We rely on the legacy decoding test above for the valid path.
}

private func testCalibrationEntryApplyNone() {
    let entry = CalibrationEntry(
        key: CalibrationKey(orientation: 0, displayUUID: ""),
        samples: [],
        transform: .none,
        calibratedAt: Date(),
        maxResidual: 0
    )
    let p = entry.apply(to: (0.5, 0.6))
    expectEqual(p.0, 0.5, "Identity transform X")
    expectEqual(p.1, 0.6, "Identity transform Y")
}

private func testCalibrationEntryApplyAffine() {
    let entry = CalibrationEntry(
        key: CalibrationKey(orientation: 0, displayUUID: ""),
        samples: [],
        transform: .affine(coefficients: [2.0, 0.0, 0.1, 0.0, 3.0, 0.2]),
        calibratedAt: Date(),
        maxResidual: 0
    )
    let p = entry.apply(to: (0.4, 0.3))
    // X = 2.0 * 0.4 + 0.0 * 0.3 + 0.1 = 0.9
    // Y = 0.0 * 0.4 + 3.0 * 0.3 + 0.2 = 1.1
    expectClose(p.0, 0.9, 1e-9, "Affine transform X")
    expectClose(p.1, 1.1, 1e-9, "Affine transform Y")
}

private func testCalibrationEntryApplyHomography() {
    let entry = CalibrationEntry(
        key: CalibrationKey(orientation: 0, displayUUID: ""),
        samples: [],
        // [h0, h1, h2, h3, h4, h5, h6, h7]
        transform: .homography(coefficients: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0]),
        calibratedAt: Date(),
        maxResidual: 0
    )
    // w = h6*x + h7*y + 1 = 1.0*0.5 + 0 + 1 = 1.5
    // correctedX = (1.0*0.5 + 0 + 0) / 1.5 = 0.5 / 1.5 = 1/3
    // correctedY = (0 + 1.0*0.6 + 0) / 1.5 = 0.6 / 1.5 = 0.4
    let p = entry.apply(to: (0.5, 0.6))
    expectClose(p.0, 1.0 / 3.0, 1e-9, "Homography transform X")
    expectClose(p.1, 0.4, 1e-9, "Homography transform Y")
}

private func testCalibrationEntryApplyHomographyZeroWeight() {
    let entry = CalibrationEntry(
        key: CalibrationKey(orientation: 0, displayUUID: ""),
        samples: [],
        transform: .homography(coefficients: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, -2.0, 0.0]),
        calibratedAt: Date(),
        maxResidual: 0
    )
    // w = -2.0*0.5 + 1.0 = 0.0 (falls below 1e-12 check)
    // should return original point
    let p = entry.apply(to: (0.5, 0.6))
    expectEqual(p.0, 0.5, "Homography zero weight fallback X")
    expectEqual(p.1, 0.6, "Homography zero weight fallback Y")
}

// MARK: - Runner

@main
enum CalibrationDataTestRunner {
    static func main() {
        testCalibrationKeyEncodingDecoding()
        testCalibrationKeyLegacyDecoding()
        testCalibrationKeyUUIDString()
        testCalibrationEntryApplyNone()
        testCalibrationEntryApplyAffine()
        testCalibrationEntryApplyHomography()
        testCalibrationEntryApplyHomographyZeroWeight()

        if failures == 0 {
            print("ok — \(checks) checks passed")
            exit(0)
        } else {
            FileHandle.standardError.write(Data("\(failures) of \(checks) checks failed\n".utf8))
            exit(1)
        }
    }
}
