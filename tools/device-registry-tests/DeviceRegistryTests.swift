// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

// DeviceRegistryTests.swift — Standalone checks for DeviceRegistry logic.
//
// The app has no XCTest target, so these run as a small executable compiled
// against the real DeviceRegistry.swift, seeded into a scratch UserDefaults suite.
// Run via tools/device-registry-tests/run.sh. Exits non-zero on the first failure.

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

private func expectNotNil<T>(_ a: T?, _ message: @autoclosure () -> String,
                             file: StaticString = #file, line: UInt = #line) -> T? {
    expect(a != nil, "\(message()) — expected non-nil", file: file, line: line)
    return a
}

// MARK: - Stubs

// These types are required for compilation outside of MockTab.
struct ToolIdentity {
    var serial: UInt32
    var toolCode: UInt16
    var isEraser: Bool
    var isMouse: Bool
}

struct TabletManager {
    static func deviceName(forProductID: Int, vendorID: Int, productString: String?) -> String {
        return "StubDevice"
    }
}

struct WacomDeviceRegistry {
    struct Spec { var family: String }
    static func spec(for productID: Int) -> Spec? {
        return Spec(family: "universal")
    }
}

struct WacomToolCatalog {
    struct Capabilities { var isSupported: Bool }
    static func name(forToolCode: UInt16) -> String { return "StubPen" }
    static func capabilities(forToolCode: UInt16, family: String) -> Capabilities {
        return Capabilities(isSupported: true)
    }
}

// MARK: - Tests

@MainActor
private func testRenameTablet() {
    let registry = DeviceRegistry.shared
    registry.knownTablets.removeAll()

    let key = DeviceInstanceKey(productID: 0x0357, instance: "test1")
    registry.recordTablet(instanceKey: key, usbSerial: "serial1")

    let id = registry.knownTablets[0].id
    expectEqual(registry.knownTablets[0].nickname, "StubDevice", "Initial nickname")

    registry.renameTablet(id: id, to: "My Intuos Pro")
    expectEqual(registry.knownTablets[0].nickname, "My Intuos Pro", "Renamed nickname")
}

@MainActor
private func testRenameTool() {
    let registry = DeviceRegistry.shared
    registry.knownTablets.removeAll()

    let key = DeviceInstanceKey(productID: 0x0357, instance: "test1")
    registry.recordTablet(instanceKey: key, usbSerial: "serial1")

    let identity = ToolIdentity(serial: 1234, toolCode: 0x0842, isEraser: false, isMouse: false)
    let toolID = registry.recordTool(identity: identity, forDevice: key)

    expectEqual(registry.knownTools[0].nickname, "StubPen", "Initial tool nickname")

    registry.renameTool(id: toolID, to: "My Favorite Pen", forDevice: key.stringValue)
    expectEqual(registry.knownTools[0].nickname, "My Favorite Pen", "Renamed tool nickname")
    expectEqual(registry.allKnownTools[0].nickname, "My Favorite Pen", "Renamed tool nickname everywhere")
}

@MainActor
private func testRenameToolEverywhere() {
    let registry = DeviceRegistry.shared
    registry.knownTablets.removeAll()

    let key1 = DeviceInstanceKey(productID: 0x0357, instance: "test1")
    registry.recordTablet(instanceKey: key1, usbSerial: "serial1")

    let identity = ToolIdentity(serial: 1234, toolCode: 0x0842, isEraser: false, isMouse: false)
    let toolID = registry.recordTool(identity: identity, forDevice: key1)

    registry.renameToolEverywhere(id: toolID, to: "Global Pen")

    registry.loadTools(for: key1)
    expectEqual(registry.knownTools[0].nickname, "Global Pen", "Globally renamed tool nickname")
    expectEqual(registry.allKnownTools[0].nickname, "Global Pen", "Globally renamed tool nickname everywhere")
}

@MainActor
private func testForgetAndRestoreTool() {
    let registry = DeviceRegistry.shared
    registry.knownTablets.removeAll()

    let key = DeviceInstanceKey(productID: 0x0357, instance: "test1")
    registry.recordTablet(instanceKey: key, usbSerial: "serial1")

    let identity = ToolIdentity(serial: 5678, toolCode: 0x0842, isEraser: false, isMouse: false)
    let toolID = registry.recordTool(identity: identity, forDevice: key)

    expectEqual(registry.knownTools.count, 1, "Tool recorded")

    let snapshot = registry.forgetTool(id: toolID, forDevice: key.stringValue)
    expectNotNil(snapshot, "Forget tool returns snapshot")
    expectEqual(registry.knownTools.count, 0, "Tool forgotten")

    if let snapshot = snapshot {
        registry.restoreTool(snapshot)
        expectEqual(registry.knownTools.count, 1, "Tool restored")
    }
}

@MainActor
private func testForgetAndRestoreToolEverywhere() {
    let registry = DeviceRegistry.shared
    registry.knownTablets.removeAll()

    let key1 = DeviceInstanceKey(productID: 0x0357, instance: "test1")
    registry.recordTablet(instanceKey: key1, usbSerial: "serial1")

    let identity = ToolIdentity(serial: 5678, toolCode: 0x0842, isEraser: false, isMouse: false)
    let toolID = registry.recordTool(identity: identity, forDevice: key1)

    let snapshot = registry.forgetToolEverywhere(id: toolID)
    expectNotNil(snapshot, "Forget tool everywhere returns snapshot")

    registry.loadTools(for: key1)
    expectEqual(registry.knownTools.count, 0, "Tool forgotten globally")

    if let snapshot = snapshot {
        registry.restoreTool(snapshot)
        registry.loadTools(for: key1)
        expectEqual(registry.knownTools.count, 1, "Tool restored globally")
    }
}

@MainActor
private func testRemoveAndRestoreTablet() {
    let registry = DeviceRegistry.shared
    registry.knownTablets.removeAll()

    let key = DeviceInstanceKey(productID: 0x0357, instance: "testremove")
    registry.recordTablet(instanceKey: key, usbSerial: "serialremove")

    expectEqual(registry.knownTablets.count, 1, "Tablet recorded")
    let tabletID = registry.knownTablets[0].id

    let snapshot = registry.removeTablet(id: tabletID)
    expectNotNil(snapshot, "Remove tablet returns snapshot")
    expectEqual(registry.knownTablets.count, 0, "Tablet removed")

    if let snapshot = snapshot {
        registry.restoreTablet(snapshot)
        expectEqual(registry.knownTablets.count, 1, "Tablet restored")
    }
}

@MainActor
private func testRecordHardwareSerial() {
    let registry = DeviceRegistry.shared

    let canonicalPID = 0x5202
    let serial: UInt32 = 0x12345678

    registry.recordHardwareSerial(serial, forDevice: canonicalPID)

    let resolvedPID = registry.canonicalProductID(forHardwareSerial: serial)
    expectEqual(resolvedPID, canonicalPID, "Hardware serial resolves to canonical PID")

    let unknownPID = registry.canonicalProductID(forHardwareSerial: 0x87654321)
    expectEqual(unknownPID, nil, "Unknown hardware serial resolves to nil")

    registry.recordHardwareSerial(0, forDevice: 0x1234)
    let ignoredPID = registry.canonicalProductID(forHardwareSerial: 0)
    expectEqual(ignoredPID, nil, "Hardware serial 0 resolves to nil")
}

@MainActor
private func testRecordTabletBackfills() {
    let registry = DeviceRegistry.shared
    registry.knownTablets.removeAll()

    let key = DeviceInstanceKey(productID: 0x0357, instance: "testbackfill")

    registry.recordTablet(instanceKey: key, usbSerial: nil, vendorID: 0x056A)
    expectEqual(registry.knownTablets.count, 1, "Tablet recorded")
    expectEqual(registry.knownTablets[0].usbSerial, nil, "Initial serial is nil")
    expectEqual(registry.knownTablets[0].vendorID, 0x056A, "Initial vendor is 0x056A")

    registry.recordTablet(instanceKey: key, usbSerial: "newserial", vendorID: 0x28BD)
    expectEqual(registry.knownTablets.count, 1, "No duplicate tablet recorded")
    expectEqual(registry.knownTablets[0].usbSerial, "newserial", "Serial was backfilled")
    expectEqual(registry.knownTablets[0].vendorID, 0x28BD, "VendorID was updated")
}

@MainActor
private func testRecordToolIntuosV1() {
    let registry = DeviceRegistry.shared
    registry.knownTablets.removeAll()
    registry.knownTools.removeAll()

    let key = DeviceInstanceKey(productID: 0x00B5, instance: "")
    registry.recordTablet(instanceKey: key, usbSerial: nil)

    let identity1 = ToolIdentity(serial: 0, toolCode: 0, isEraser: false, isMouse: false)
    let toolID1 = registry.recordTool(identity: identity1, forDevice: key)

    expectEqual(toolID1, "stylus", "Generic stylus gets ID stylus")
    expectEqual(registry.knownTools.count, 1, "One generic stylus recorded")

    let toolID2 = registry.recordTool(identity: identity1, forDevice: key)
    expectEqual(toolID2, "stylus-1", "Second generic stylus gets counter suffix")
    expectEqual(registry.knownTools.count, 2, "Two generic styluses recorded")

    let realIdentity = ToolIdentity(serial: 1234, toolCode: 0x0822, isEraser: false, isMouse: false)
    registry.recordTool(identity: realIdentity, forDevice: key)

    expectEqual(registry.knownTools.count, 2, "Generic stylus removed, real tool added")
    expectEqual(registry.knownTools.contains(where: { $0.id == "stylus" }), false, "stylus was removed")
    expectEqual(registry.knownTools.contains(where: { $0.id == "stylus-1" }), true, "stylus-1 remains")
    expectEqual(registry.knownTools.contains(where: { $0.id == "0x000004D2" }), true, "real tool added")
}

// MARK: - Main

@MainActor
private func runAll() {
    testRecordHardwareSerial()
    testRecordTabletBackfills()
    testRecordToolIntuosV1()
    testRenameTablet()
    testRenameTool()
    testRenameToolEverywhere()
    testForgetAndRestoreTool()
    testForgetAndRestoreToolEverywhere()
    testRemoveAndRestoreTablet()

    if failures > 0 {
        print("\n❌ \(failures) of \(checks) checks failed.")
        exit(1)
    } else {
        print("✅ All \(checks) checks passed.")
    }
}

runAll()
