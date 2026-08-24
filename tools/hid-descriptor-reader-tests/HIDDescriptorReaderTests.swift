// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

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

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: @autoclosure () -> String = "",
                                       file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if actual != expected {
        failures += 1
        let msg = message()
        let prefix = msg.isEmpty ? "" : "\(msg) - "
        FileHandle.standardError.write(Data("FAIL (\(file):\(line)): \(prefix)Expected '\(expected)', got '\(actual)'\n".utf8))
    }
}

// MARK: - Field fixture helper

private func field(page: UInt32, usage: UInt32, size: UInt32 = 8, count: UInt32 = 1, logicalMin: Int = 0, logicalMax: Int = 255) -> HIDDescriptorReader.Field {
    HIDDescriptorReader.Field(
        usagePage: page, usage: usage, bitSize: size, reportCount: count,
        logicalMin: logicalMin, logicalMax: logicalMax, physicalMin: 0, physicalMax: 0,
        unit: 0, unitExponent: 0)
}

// MARK: - Tests

private func testSummarizeEmpty() {
    let p = HIDDescriptorReader.Parsed(rawHex: nil, rawLength: 10, reports: [:])
    let summary = HIDDescriptorReader.summarize(p)
    let expected = """
    HID descriptor: 10 bytes
      (no elements exposed)
    """
    expectEqual(summary, expected)
}

private func testSummarizeSingleReport() {
    let reports: [String: HIDDescriptorReader.ReportLayout] = [
        "input:0x01": .init(reportID: 0x01, direction: .input, fields: [
            field(page: 0x01, usage: 0x30, size: 16, count: 1, logicalMin: 0, logicalMax: 10000), // X
            field(page: 0x01, usage: 0x31, size: 16, count: 1, logicalMin: 0, logicalMax: 10000), // Y
            field(page: 0x0D, usage: 0x30, size: 16, count: 1, logicalMin: 0, logicalMax: 8191), // TipPressure
        ])
    ]
    let p = HIDDescriptorReader.Parsed(rawHex: "010203", rawLength: 3, reports: reports)
    let summary = HIDDescriptorReader.summarize(p)

    // Note: total bits = 16 * 1 + 16 * 1 + 16 * 1 = 48 bits
    let expected = """
    HID descriptor: 3 bytes
      input:0x01 (3 field group(s), 48 bits):
        page=0x01 usage=0x30  16 bits  [0…10000]  X
        page=0x01 usage=0x31  16 bits  [0…10000]  Y
        page=0x0D usage=0x30  16 bits  [0…8191]  TipPressure
    """
    expectEqual(summary, expected)
}

private func testSummarizeWithUnknownUsages() {
    let reports: [String: HIDDescriptorReader.ReportLayout] = [
        "feature:0x02": .init(reportID: 0x02, direction: .feature, fields: [
            field(page: 0xFF00, usage: 0x01, size: 8, count: 2, logicalMin: -127, logicalMax: 127) // Unknown vendor usage
        ])
    ]
    let p = HIDDescriptorReader.Parsed(rawHex: "ff", rawLength: 1, reports: reports)
    let summary = HIDDescriptorReader.summarize(p)

    // Total bits = 8 * 2 = 16 bits
    let expected = """
    HID descriptor: 1 bytes
      feature:0x02 (1 field group(s), 16 bits):
        page=0xFF00 usage=0x01  8x2 bits  [-127…127]
    """
    expectEqual(summary, expected)
}

// MARK: - Runner

@main
enum HIDDescriptorReaderTestRunner {
    static func main() {
        testSummarizeEmpty()
        testSummarizeSingleReport()
        testSummarizeWithUnknownUsages()

        if failures == 0 {
            print("ok — \(checks) checks passed")
            exit(0)
        } else {
            FileHandle.standardError.write(Data("\(failures) of \(checks) checks failed\n".utf8))
            exit(1)
        }
    }
}
