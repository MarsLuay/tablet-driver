// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

// TabletSettingsTests.swift — Standalone checks for TabletSettings composite
// structs (Profile, AppOverride, AppProfileBinding).
//
// Covers:
//   1. Round-trip: a struct decoded from JSON containing an unrecognized
//      field (simulating a newer app version's format) must re-emit that
//      field unchanged when re-encoded by this build.
//   2. Decode-failure detection: JSONDecoder throws (rather than silently
//      degrading) when a required field is missing.
//   3. Equality and initialization logic.
//
// The app has no XCTest target (by design — see the project's test
// conventions), so this runs as a small executable compiled against the
// real source files (or dynamically extracted definitions, due to
// AppKit/TabletKit dependencies in TabletSettings).
// Run via tools/tablet-settings-tests/run.sh. Exits non-zero on failure.

import Foundation

// MARK: - Tiny assertion harness
private var failures = 0
private var checks = 0

private func expect(_ condition: Bool, _ message: @autoclosure () -> String, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition {
        failures += 1
        FileHandle.standardError.write(Data("FAIL (\(file):\(line)): \(message())\n".utf8))
    }
}

// MARK: - AppOverride round-trip

do {
    let futureJSON = """
        {"bundleID":"com.example.app","appName":"Example","overriddenKeys":["activeAreaY"],"newSetting":42}
        """
    let data = Data(futureJSON.utf8)
    let override = try JSONDecoder().decode(TabletSettings.AppOverride.self, from: data)
    expect(override.bundleID == "com.example.app", "AppOverride decodes known fields")

    let reEncoded = try JSONEncoder().encode(override)
    let roundTripped = try JSONSerialization.jsonObject(with: reEncoded) as? [String: Any]
    expect(
        (roundTripped?["newSetting"] as? Int) == 42,
        "AppOverride preserves unknown field 'newSetting' on re-encode")
} catch {
    expect(false, "AppOverride round-trip failed: \(error)")
}

// MARK: - AppOverride Decode-failure detection

do {
    let malformedJSON = """
        {"appName":"Example"}
        """
    let malformedData = Data(malformedJSON.utf8)
    do {
        _ = try JSONDecoder().decode(TabletSettings.AppOverride.self, from: malformedData)
        expect(false, "AppOverride should throw on missing required fields")
    } catch {
        expect(true, "AppOverride throws when required fields are missing")
    }
}

// MARK: - Profile round-trip

do {
    let futureJSON = """
        {"id":"00000000-0000-0000-0000-000000000000","name":"My Profile","overriddenKeys":["activeAreaX"],"newFeature":true}
        """
    let data = Data(futureJSON.utf8)
    let profile = try JSONDecoder().decode(TabletSettings.Profile.self, from: data)
    expect(profile.name == "My Profile", "Profile decodes known fields")

    let reEncoded = try JSONEncoder().encode(profile)
    let roundTripped = try JSONSerialization.jsonObject(with: reEncoded) as? [String: Any]
    expect(
        (roundTripped?["newFeature"] as? Bool) == true,
        "Profile preserves unknown field 'newFeature' on re-encode")
} catch {
    expect(false, "Profile round-trip failed: \(error)")
}

// MARK: - Profile Decode-failure detection

do {
    let malformedJSON = """
        {"id":"00000000-0000-0000-0000-000000000000"}
        """
    let malformedData = Data(malformedJSON.utf8)
    do {
        _ = try JSONDecoder().decode(TabletSettings.Profile.self, from: malformedData)
        expect(false, "Profile should throw on missing required fields")
    } catch {
        expect(true, "Profile throws when required fields are missing")
    }
}

// MARK: - Profile Equality

do {
    let p1 = TabletSettings.Profile(name: "Test")
    var p2 = p1
    expect(p1 == p2, "Identical profiles are equal")
    p2.name = "Different"
    expect(p1 != p2, "Different names mean not equal")
}

// MARK: - AppOverride Equality

do {
    let o1 = TabletSettings.AppOverride(bundleID: "com.test", appName: "TestApp")
    var o2 = o1
    expect(o1 == o2, "Identical overrides are equal")
    o2.appName = "DifferentApp"
    expect(o1 != o2, "Different appNames mean not equal")
}

// MARK: - AppProfileBinding Decoding

do {
    let json = """
        {"bundleID":"com.test","appName":"TestApp","profileID":"00000000-0000-0000-0000-000000000000"}
        """
    let data = Data(json.utf8)
    let binding = try JSONDecoder().decode(TabletSettings.AppProfileBinding.self, from: data)
    expect(binding.bundleID == "com.test", "AppProfileBinding decodes bundleID")
    expect(binding.id == "com.test", "AppProfileBinding id matches bundleID")
} catch {
    expect(false, "AppProfileBinding decoding failed: \(error)")
}

// MARK: - AppProfileBinding Decode-failure detection

do {
    let malformedJSON = """
        {"appName":"TestApp"}
        """
    let malformedData = Data(malformedJSON.utf8)
    do {
        _ = try JSONDecoder().decode(TabletSettings.AppProfileBinding.self, from: malformedData)
        expect(false, "AppProfileBinding should throw on missing required fields")
    } catch {
        expect(true, "AppProfileBinding throws when required fields are missing")
    }
}

// MARK: - Summary
if failures == 0 {
    print("TabletSettingsTests: \(checks) checks passed")
    exit(0)
} else {
    print("TabletSettingsTests: \(failures)/\(checks) checks FAILED")
    exit(1)
}
