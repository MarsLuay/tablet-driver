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

private func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: @autoclosure () -> String,
                                       file: StaticString = #file, line: UInt = #line) {
    expect(a == b, "\(message()) — got \(a), expected \(b)", file: file, line: line)
}

// MARK: - Tests

private func testInitialization() {
    // Normal init
    let key1 = DeviceInstanceKey(productID: 0x0357, instance: "ABC")
    expectEqual(key1.productID, 0x0357, "productID matches")
    expectEqual(key1.instance, "ABC", "instance matches")

    // Init from IOKit
    let key2 = DeviceInstanceKey(productID: 0x0357, usbSerial: "12345", locationID: 0x1420)
    expectEqual(key2.instance, "12345", "usbSerial used when present")

    let key3 = DeviceInstanceKey(productID: 0x0357, usbSerial: "", locationID: 0x1420)
    expectEqual(key3.instance, "loc-00001420", "locationID used when serial empty")

    let key4 = DeviceInstanceKey(productID: 0x0357, usbSerial: nil, locationID: 0x1420)
    expectEqual(key4.instance, "loc-00001420", "locationID used when serial nil")

    let key5 = DeviceInstanceKey(productID: 0x0357, usbSerial: nil, locationID: 0)
    expectEqual(key5.instance, "", "empty instance when neither serial nor locationID present")

    // Placeholder serial
    let key6 = DeviceInstanceKey(productID: 0x0357, usbSerial: "000000000000", locationID: 0x1420)
    expectEqual(key6.instance, "loc-00001420", "locationID used when serial is placeholder")
}

private func testStringValue() {
    let key1 = DeviceInstanceKey(productID: 0x0357, instance: "ABC")
    expectEqual(key1.stringValue, "0x357#ABC", "stringValue formats correctly with instance")

    let key2 = DeviceInstanceKey(productID: 0x0357, instance: "")
    expectEqual(key2.stringValue, "0x357", "stringValue formats correctly without instance")

    // Parse back
    let parsed1 = DeviceInstanceKey(stringValue: "0x357#ABC")
    expectEqual(parsed1, key1, "parse back with instance")

    let parsed2 = DeviceInstanceKey(stringValue: "0x357")
    expectEqual(parsed2, key2, "parse back without instance")

    let parsedFail1 = DeviceInstanceKey(stringValue: "357#ABC")
    expect(parsedFail1 == nil, "parse fails without 0x prefix")

    let parsedFail2 = DeviceInstanceKey(stringValue: "0xXYZ#ABC")
    expect(parsedFail2 == nil, "parse fails with non-hex PID")
}

private func testEquatableAndHashable() {
    let keyA = DeviceInstanceKey(productID: 0x0357, instance: "ABC")
    let keyB = DeviceInstanceKey(productID: 0x0357, instance: "ABC")
    let keyC = DeviceInstanceKey(productID: 0x0357, instance: "DEF")
    let keyD = DeviceInstanceKey(productID: 0x0358, instance: "ABC")

    expectEqual(keyA, keyB, "keys with same PID and instance are equal")
    expect(keyA != keyC, "keys with different instance are not equal")
    expect(keyA != keyD, "keys with different PID are not equal")

    expectEqual(keyA.hashValue, keyB.hashValue, "equal keys have equal hash values")
    expect(keyA.hashValue != keyC.hashValue, "different keys have different hash values")

    var set = Set<DeviceInstanceKey>()
    set.insert(keyA)
    expect(set.contains(keyB), "Set contains keyB")
    expect(!set.contains(keyC), "Set does not contain keyC")
}

private func testCodable() {
    let key = DeviceInstanceKey(productID: 0x0357, instance: "ABC")

    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(key) else {
        expect(false, "encoding failed")
        return
    }

    let decoder = JSONDecoder()
    guard let decoded = try? decoder.decode(DeviceInstanceKey.self, from: data) else {
        expect(false, "decoding failed")
        return
    }

    expectEqual(decoded, key, "decoded key matches original")

    let keyEmpty = DeviceInstanceKey(productID: 0x0357, instance: "")
    guard let dataEmpty = try? encoder.encode(keyEmpty),
          let decodedEmpty = try? decoder.decode(DeviceInstanceKey.self, from: dataEmpty) else {
        expect(false, "encoding/decoding failed for empty instance")
        return
    }
    expectEqual(decodedEmpty, keyEmpty, "decoded key with empty instance matches original")
}

// MARK: - Runner

@main
enum DeviceInstanceKeyTestRunner {
    static func main() {
        testInitialization()
        testStringValue()
        testEquatableAndHashable()
        testCodable()

        if failures == 0 {
            print("ok — \(checks) checks passed")
            exit(0)
        } else {
            FileHandle.standardError.write(Data("\(failures) of \(checks) checks failed\n".utf8))
            exit(1)
        }
    }
}
