// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

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

private func testRecordBasic() {
    let capture = HIDCapture.shared
    capture.clear()
    capture.start()

    let reportBytes: [UInt8] = [0x01, 0xAB, 0xCD]
    capture.record(tag: "TestDevice", report: reportBytes, length: reportBytes.count)

    expect(capture.reportCount == 1, "Report count should be 1")

    capture.stop()
}

private func testRecordDisabled() {
    let capture = HIDCapture.shared
    capture.clear()
    capture.stop()

    expect(capture.isCapturing == false, "Capture should be disabled")
    let countBefore = capture.reportCount

    let reportBytes: [UInt8] = [0x02, 0x11]
    capture.record(tag: "TestDevice", report: reportBytes, length: reportBytes.count)

    expect(capture.reportCount == countBefore, "Report count should not increase when stopped")
}

private func testRecordZeroLength() {
    let capture = HIDCapture.shared
    capture.clear()
    capture.start()

    let countBefore = capture.reportCount

    let reportBytes: [UInt8] = []
    capture.record(tag: "TestDevice", report: reportBytes, length: 0)

    expect(capture.reportCount == countBefore, "Report count should not increase for 0 length")

    capture.stop()
}

private func testClear() {
    let capture = HIDCapture.shared
    capture.clear()
    capture.start()

    let reportBytes: [UInt8] = [0x01, 0xAB, 0xCD]
    capture.record(tag: "TestDevice", report: reportBytes, length: reportBytes.count)

    expect(capture.reportCount == 1, "Report count should be 1")

    capture.clear()
    expect(capture.reportCount == 0, "Report count should be 0 after clear")

    capture.stop()
}

private func runAll() {
    testRecordBasic()
    testRecordDisabled()
    testRecordZeroLength()
    testClear()

    if failures > 0 {
        print("\n❌ \(failures) of \(checks) checks failed.")
        exit(1)
    } else {
        print("✅ All \(checks) checks passed.")
    }
}

runAll()
