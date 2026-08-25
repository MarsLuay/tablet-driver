// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import IOKit.hid
import OSLog

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

private class MockDevice {}

private func testSeverityEnum() {
    let required = HIDSetReportSeverity.required
    let bestEffort = HIDSetReportSeverity.bestEffort
    expect(required != bestEffort, "Severity cases should be distinct")
}

private func testHidSetReportRuntime() {
    let mockObj = MockDevice()
    let dummyDevice = unsafeBitCast(Unmanaged.passRetained(mockObj).toOpaque(), to: IOHIDDevice.self)

    let log = Logger(subsystem: "com.cyzor.mocktab.tests", category: "hid_helpers_tests")
    var bytes: [UInt8] = [0x01, 0x02]

    // Mock setter that always returns an error.
    let mockSetter: (IOHIDDevice, IOHIDReportType, CFIndex, UnsafePointer<UInt8>, CFIndex) -> IOReturn = { _, _, _, _, _ in
        return kIOReturnUnsupported
    }

    let ret1 = hidSetReport(
        dummyDevice,
        type: kIOHIDReportTypeFeature,
        reportID: 0x01,
        bytes: &bytes,
        tag: "TestRequired",
        severity: .required,
        log: log,
        setter: mockSetter
    )
    expect(ret1 == kIOReturnUnsupported, "hidSetReport should return the mocked error code")

    let ret2 = hidSetReport(
        dummyDevice,
        type: kIOHIDReportTypeFeature,
        reportID: 0x01,
        bytes: &bytes,
        tag: "TestBestEffort",
        severity: .bestEffort,
        log: log,
        setter: mockSetter
    )
    expect(ret2 == kIOReturnUnsupported, "hidSetReport should return the mocked error code")
}

private func runAll() {
    testSeverityEnum()
    testHidSetReportRuntime()

    if failures > 0 {
        print("\n❌ \(failures) of \(checks) checks failed.")
        exit(1)
    } else {
        print("✅ All \(checks) checks passed.")
    }
}

runAll()
