// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

// HIDCaptureTests.swift — Standalone checks for HIDCapture recording
// and formatting logic.
//
// The app has no XCTest target, so these run as a small executable
// compiled against the real HIDCapture.swift.

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

private func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: @autoclosure () -> String,
                                       file: StaticString = #file, line: UInt = #line) {
    expect(a == b, "\(message()) — got \(a), expected \(b)", file: file, line: line)
}

// MARK: - Tests

private func testHIDCaptureEarlyReturns() {
    let capture = HIDCapture.shared
    capture.clear()

    // 1. Stopped capture early return
    capture.stop()
    expectEqual(capture.isCapturing, false, "Capture should be stopped")

    let bytes: [UInt8] = [0x01, 0x02, 0x03]
    bytes.withUnsafeBufferPointer { buffer in
        guard let pointer = buffer.baseAddress else { return }
        capture.record(tag: "Test", report: pointer, length: bytes.count)
    }

    expectEqual(capture.reportCount, 0, "Should ignore reports when stopped")

    // 2. Length <= 0 early return
    capture.start()
    expectEqual(capture.isCapturing, true, "Capture should be started")

    capture.record(tag: "Test", report: UnsafePointer<UInt8>(bitPattern: 0x1000)!, length: 0)
    capture.record(tag: "Test", report: UnsafePointer<UInt8>(bitPattern: 0x1000)!, length: -1)

    expectEqual(capture.reportCount, 0, "Should ignore reports with length <= 0")
}

private func testHIDCaptureFormatting() {
    let capture = HIDCapture.shared
    capture.start()
    capture.clear() // restart counts

    let report1: [UInt8] = [0x05, 0xAB, 0xCD] // ID=05, len=3
    report1.withUnsafeBufferPointer { buffer in
        guard let pointer = buffer.baseAddress else { return }
        capture.record(tag: "ShortTag", report: pointer, length: report1.count)
    }

    let report2: [UInt8] = [0x1A, 0x00, 0xFF, 0x42] // ID=1A, len=4
    report2.withUnsafeBufferPointer { buffer in
        guard let pointer = buffer.baseAddress else { return }
        capture.record(tag: "ThisTagIsWayTooLongAndShouldBeTruncated", report: pointer, length: report2.count)
    }

    expectEqual(capture.reportCount, 2, "Should have 2 reports recorded")

    // Save to temp file and read back
    guard let savedURL = capture.save() else {
        expect(false, "Save should succeed and return URL")
        return
    }

    defer {
        try? FileManager.default.removeItem(at: savedURL)
    }

    guard let contents = try? String(contentsOf: savedURL, encoding: .utf8) else {
        expect(false, "Failed to read saved file")
        return
    }

    let lines = contents.components(separatedBy: .newlines)

    // Header check
    expect(lines[0].contains("MockTab HID Capture"), "Should have header")
    expect(lines[2].contains("Reports : 2"), "Should indicate 2 reports")

    // Skip down to actual report lines. (Header is around 5 lines)
    // Looking for the specific formatted lines.

    // We expect: [00:00.000] ShortTag             ID=05 len=3     05 AB CD
    // And:       [00:00.000] ThisTagIsWayTooLongA ID=1A len=4     1A 00 FF 42

    var foundReport1 = false
    var foundReport2 = false

    for line in lines {
        if line.contains("ShortTag") {
            foundReport1 = true
            expect(line.contains("ShortTag            "), "Tag should be padded to 20 chars")
            expect(line.contains("ID=05"), "ID should be formatted as hex 05")
            expect(line.contains("len=3   "), "Length should be formatted")
            expect(line.hasSuffix("05 AB CD"), "Hex dump should be correctly spaced and formatted")
        }
        if line.contains("ThisTagIsWayTooLongA") {
            foundReport2 = true
            expect(!line.contains("ThisTagIsWayTooLongAnd"), "Tag should be truncated to 20 chars")
            expect(line.contains("ID=1A"), "ID should be formatted as hex 1A")
            expect(line.contains("len=4   "), "Length should be formatted")
            expect(line.hasSuffix("1A 00 FF 42"), "Hex dump should be correctly spaced and formatted")
        }
    }

    expect(foundReport1, "Should have found the first report in saved file")
    expect(foundReport2, "Should have found the second report in saved file")
}

// MARK: - Runner

testHIDCaptureEarlyReturns()
testHIDCaptureFormatting()

if failures > 0 {
    print("FAILED: \(failures) of \(checks) checks failed.")
    exit(1)
} else {
    print("PASSED: \(checks) checks passed.")
    exit(0)
}
