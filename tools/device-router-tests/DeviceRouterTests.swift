// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

#if canImport(IOKit)
import IOKit.hid
#else
// Define a dummy pointer type for Linux compilation of tests
typealias IOHIDDevice = OpaquePointer
#endif

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

@MainActor
private let noopCallbacks = DeviceRouter.Callbacks(
    onTablet: { _ in },
    onAux: { _ in },
    onToolEnter: { _ in },
    onMouseButton: { _ in },
    onBattery: { _, _ in },
    onHardwareSerial: { _ in },
    onWheel: { _, _ in },
    onTouch: { _ in },
    onPairedPID: { _ in }
)

@MainActor
private func testCintiqV1DeferralWithOverride() {
    #if canImport(IOKit)
    // To safely get an IOHIDDevice reference for testing without bridging crashes,
    // we use IOHIDDeviceCreate to instantiate a valid opaque CF object natively.
    // IOHIDDeviceCreate expects an allocator and an io_service_t (UInt32).
    let allocator = kCFAllocatorDefault
    let dummyDevice = IOHIDDeviceCreate(allocator, 0)
    #else
    let dummyDevice = OpaquePointer(bitPattern: 1)!
    #endif

    // We use overrideSpec to bypass WacomDeviceRegistry and IOKit queries
    let cintiqSpec = WacomDeviceSpec(
        productID: 0x00F4, name: "Cintiq 24HD", parser: .cintiqV1,
        maxX: 1000, maxY: 1000, maxPressure: 1024, seizeUSB: true
    )

    // Testing the CintiqV1 interface 0xFF00 deferral logic
    // overrideSpec is natively supported by DeviceRouter.route
    let routed = DeviceRouter.route(
        device: dummyDevice, productID: 0x00F4, usagePage: 0xFF00, isBLE: false,
        contexts: [:], callbacks: noopCallbacks, overrideSpec: cintiqSpec
    )

    if case .deferred = routed {
        expect(true, "CintiqV1 0xFF00 interface is deferred")
    } else {
        expect(false, "Expected .deferred, got string representation instead")
    }
}

@MainActor
private func testCintiqV1SeizureWithOverride() {
    #if canImport(IOKit)
    let allocator = kCFAllocatorDefault
    let dummyDevice = IOHIDDeviceCreate(allocator, 0)
    #else
    let dummyDevice = OpaquePointer(bitPattern: 1)!
    #endif

    let cintiqSpec = WacomDeviceSpec(
        productID: 0x00F4, name: "Cintiq 24HD", parser: .cintiqV1,
        maxX: 1000, maxY: 1000, maxPressure: 1024, seizeUSB: true
    )

    // Testing the CintiqV1 interface 0x01 seizure logic
    let routed = DeviceRouter.route(
        device: dummyDevice, productID: 0x00F4, usagePage: 0x01, isBLE: false,
        contexts: [:], callbacks: noopCallbacks, overrideSpec: cintiqSpec
    )

    if case .driver(_, let seized) = routed {
        expect(seized, "CintiqV1 0x01 interface is seized")
    } else {
        expect(false, "Expected .driver, got something else")
    }
}

// MARK: - Runner

@main
@MainActor
enum DeviceRouterTestRunner {
    static func main() {
        testCintiqV1DeferralWithOverride()
        testCintiqV1SeizureWithOverride()

        if failures > 0 {
            FileHandle.standardError.write(Data("\nFAILED: \(failures) of \(checks) checks failed.\n".utf8))
            exit(1)
        } else {
            print("\nOK: \(checks) checks passed.")
            exit(0)
        }
    }
}
