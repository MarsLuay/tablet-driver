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

// MARK: - Factory Helpers

func makeBaseSnapshot(name: String = "TestProfile") -> TabletSnapshot {
    return TabletSnapshot(
        name: name,
        deviceModel: "Wacom Intuos Pro M",
        tabletAreaX: 0.1,
        tabletAreaY: 0.2,
        tabletAreaWidth: 0.8,
        tabletAreaHeight: 0.7,
        proportionalMapping: true,
        targetDisplayIndex: 1,
        pressureCurve: BezierCurve(p1: CGPoint(x: 0.1, y: 0.1), p2: CGPoint(x: 0.9, y: 0.9)),
        smoothingStrength: 0.5,
        penButton1: ButtonBinding(kind: .leftClick),
        penButton2: ButtonBinding(kind: .rightClick),
        tipBinding: ButtonBinding(kind: .leftClick),
        eraserBinding: ButtonBinding(kind: .eraser),
        touchRingMode: "scroll",
        touchRingButtonBinding: ButtonBinding(kind: .none),
        toolSettingsPerSerial: nil
    )
}

func makeToolSnapshot(serial: String = "deadbeef") -> ToolSnapshot {
    return ToolSnapshot(
        serial: serial,
        pressureCurve: BezierCurve(p1: CGPoint(x: 0.2, y: 0.2), p2: CGPoint(x: 0.8, y: 0.8)),
        smoothingStrength: 0.2,
        penButton1: ButtonBinding(kind: .rightClick),
        penButton2: ButtonBinding(kind: .middleClick)
    )
}

// MARK: - TabletSnapshot Round-Trip (No ToolSettings)

do {
    let snapshot = makeBaseSnapshot()

    let encoded = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(TabletSnapshot.self, from: encoded)

    expect(snapshot == decoded, "TabletSnapshot without tool settings round-trips exactly")
    expect(decoded.name == "TestProfile", "Decoded name matches")
    expect(decoded.tabletAreaX == 0.1, "Decoded area matches")
    expect(decoded.toolSettingsPerSerial == nil, "toolSettingsPerSerial is nil")
} catch {
    expect(false, "Failed to encode/decode TabletSnapshot: \(error)")
}

// MARK: - TabletSnapshot Round-Trip (With ToolSettings)

do {
    var snapshot = makeBaseSnapshot(name: "WithTools")
    snapshot.toolSettingsPerSerial = [
        "abcd": makeToolSnapshot(serial: "abcd"),
        "1234": makeToolSnapshot(serial: "1234")
    ]

    let encoded = try JSONEncoder().encode(snapshot)
    let decoded = try JSONDecoder().decode(TabletSnapshot.self, from: encoded)

    expect(snapshot == decoded, "TabletSnapshot with tool settings round-trips exactly")
    expect(decoded.toolSettingsPerSerial?.count == 2, "Decoded toolSettingsPerSerial has 2 elements")
    expect(decoded.toolSettingsPerSerial?["abcd"]?.serial == "abcd", "Decoded tool snapshot serial matches")
} catch {
    expect(false, "Failed to encode/decode TabletSnapshot with tools: \(error)")
}

// MARK: - ToolSnapshot Round-Trip

do {
    let toolSnapshot = makeToolSnapshot()

    let encoded = try JSONEncoder().encode(toolSnapshot)
    let decoded = try JSONDecoder().decode(ToolSnapshot.self, from: encoded)

    expect(toolSnapshot == decoded, "ToolSnapshot round-trips exactly")
    expect(decoded.serial == "deadbeef", "Decoded serial matches")
    expect(decoded.smoothingStrength == 0.2, "Decoded smoothing strength matches")
} catch {
    expect(false, "Failed to encode/decode ToolSnapshot: \(error)")
}

// MARK: - Equality Checks

do {
    let s1 = makeBaseSnapshot()
    var s2 = makeBaseSnapshot()

    expect(s1 == s2, "Identical base snapshots are equal")

    s2.name = "DifferentName"
    expect(s1 != s2, "Different names are not equal")

    s2 = makeBaseSnapshot()
    s2.toolSettingsPerSerial = ["a": makeToolSnapshot()]
    expect(s1 != s2, "Different toolSettingsPerSerial are not equal")

    let t1 = makeToolSnapshot()
    var t2 = makeToolSnapshot()
    expect(t1 == t2, "Identical tool snapshots are equal")

    t2.serial = "different"
    expect(t1 != t2, "Different tool serials are not equal")
}

// MARK: - Missing Required Fields (Error Detection)

do {
    // Missing 'name' field
    let malformedJSON = """
    {
        "deviceModel": "Wacom",
        "tabletAreaX": 0.0,
        "tabletAreaY": 0.0,
        "tabletAreaWidth": 1.0,
        "tabletAreaHeight": 1.0,
        "proportionalMapping": true,
        "targetDisplayIndex": 0,
        "pressureCurve": {"p1": [0,0], "p2": [1,1]},
        "smoothingStrength": 0.0,
        "penButton1": {"kind": "none"},
        "penButton2": {"kind": "none"},
        "tipBinding": {"kind": "none"},
        "eraserBinding": {"kind": "none"},
        "touchRingMode": "off",
        "touchRingButtonBinding": {"kind": "none"}
    }
    """

    let malformedData = Data(malformedJSON.utf8)
    do {
        _ = try JSONDecoder().decode(TabletSnapshot.self, from: malformedData)
        expect(false, "TabletSnapshot should throw on missing required fields")
    } catch {
        expect(true, "TabletSnapshot throws when required fields are missing")
    }
}

// MARK: - Summary

if failures == 0 {
    print("ProfileSerializationTests: \(checks) checks passed")
    exit(0)
} else {
    print("ProfileSerializationTests: \(failures)/\(checks) checks FAILED")
    exit(1)
}
