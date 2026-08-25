// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

// MARK: - Dummy Mocks for Dependencies
// To compile CaptureModels.swift in a standalone file, we need to mock
// types it depends on from other files or modules, like HIDDescriptorReader.Parsed.
enum HIDDescriptorReader {
    struct Parsed: Codable {
        let rawHex: String?
        let rawLength: Int
    }
}


// MARK: - Tiny assertion harness

private var failures = 0
private var checks = 0

private func expect(_ condition: Bool, _ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition {
        print("❌ \(file):\(line) - \(message())")
        failures += 1
    }
}

// MARK: - Tests

func testCaptureInitReport() {
    print("Testing CaptureInitReport...")
    let report1 = CaptureInitReport(reportID: 2, value: 2, succeeded: true, ioReturn: nil)
    expect(report1.id == "2-2-ok", "Expected id to be '2-2-ok'")
    expect(report1.reportIDHex == "0x02", "Expected reportIDHex to be '0x02'")
    expect(report1.valueHex == "0x02", "Expected valueHex to be '0x02'")

    let report2 = CaptureInitReport(reportID: 15, value: 255, succeeded: false, ioReturn: "e00002bc")
    expect(report2.id == "15-255-e00002bc", "Expected id to be '15-255-e00002bc'")
    expect(report2.reportIDHex == "0x0F", "Expected reportIDHex to be '0x0F'")
    expect(report2.valueHex == "0xFF", "Expected valueHex to be '0xFF'")
}

func testCaptureDeviceInfo() {
    print("Testing CaptureDeviceInfo...")
    let device1 = CaptureDeviceInfo(vendorID: 0x056a, productID: 0x0357, name: "Wacom Intuos Pro M", locationID: nil)
    expect(device1.vendorIDHex == "0x056A", "Expected vendorIDHex to be '0x056A', got \(device1.vendorIDHex)")
    expect(device1.productIDHex == "0x0357", "Expected productIDHex to be '0x0357', got \(device1.productIDHex)")

    let device2 = CaptureDeviceInfo(vendorID: 1, productID: 10, name: "Test", locationID: "test-loc")
    expect(device2.vendorIDHex == "0x0001", "Expected vendorIDHex to be '0x0001', got \(device2.vendorIDHex)")
    expect(device2.productIDHex == "0x000A", "Expected productIDHex to be '0x000A', got \(device2.productIDHex)")
}

func runTests() {
    print("Running CaptureModelsTests...")
    testCaptureInitReport()
    testCaptureDeviceInfo()

    print("\n\(checks) checks run.")
    if failures > 0 {
        print("❌ \(failures) failures.")
        exit(1)
    } else {
        print("✅ All checks passed.")
    }
}

runTests()
