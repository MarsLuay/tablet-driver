// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

// TabletOrientationTests.swift — Standalone checks for TabletOrientation enum
//
// The app has no XCTest target (by design — see the project's test conventions),
// so this runs as a small executable compiled against the real TabletOrientation.swift.
// Run via tools/tablet-orientation-tests/run.sh. Exits non-zero on the first failure.

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

// MARK: - Tests

private func testRawValueAndInit() {
    expect(TabletOrientation.landscape.rawValue == 0, "Landscape rawValue should be 0")
    expect(TabletOrientation.portrait.rawValue == 1, "Portrait rawValue should be 1")
    expect(TabletOrientation.landscapeFlipped.rawValue == 2, "Landscape Flipped rawValue should be 2")
    expect(TabletOrientation.portraitFlipped.rawValue == 3, "Portrait Flipped rawValue should be 3")

    expect(TabletOrientation(rawValue: 0) == .landscape, "Init 0 should be Landscape")
    expect(TabletOrientation(rawValue: 1) == .portrait, "Init 1 should be Portrait")
    expect(TabletOrientation(rawValue: 2) == .landscapeFlipped, "Init 2 should be Landscape Flipped")
    expect(TabletOrientation(rawValue: 3) == .portraitFlipped, "Init 3 should be Portrait Flipped")
}

private func testRotationAngle() {
    expect(TabletOrientation.landscape.rotationAngle == 0, "Landscape rotation angle should be 0")
    expect(TabletOrientation.portrait.rotationAngle == 3 * .pi / 2, "Portrait rotation angle should be 3pi/2")
    expect(TabletOrientation.landscapeFlipped.rotationAngle == .pi, "Landscape Flipped rotation angle should be pi")
    expect(TabletOrientation.portraitFlipped.rotationAngle == .pi / 2, "Portrait Flipped rotation angle should be pi/2")
}

private func testSwapsAxes() {
    expect(TabletOrientation.landscape.swapsAxes == false, "Landscape should not swap axes")
    expect(TabletOrientation.portrait.swapsAxes == true, "Portrait should swap axes")
    expect(TabletOrientation.landscapeFlipped.swapsAxes == false, "Landscape Flipped should not swap axes")
    expect(TabletOrientation.portraitFlipped.swapsAxes == true, "Portrait Flipped should swap axes")
}

private func testLabel() {
    // In a pure CLI environment without an explicit bundle, String(localized:) defaults
    // to returning the original string literal (the key). This lets us test the expected labels.
    expect(TabletOrientation.landscape.label == "Landscape", "Landscape label should be Landscape")
    expect(TabletOrientation.portrait.label == "Portrait", "Portrait label should be Portrait")
    expect(TabletOrientation.landscapeFlipped.label == "Landscape Flipped", "Landscape Flipped label should be Landscape Flipped")
    expect(TabletOrientation.portraitFlipped.label == "Portrait Flipped", "Portrait Flipped label should be Portrait Flipped")
}

private func testAllCases() {
    let cases = TabletOrientation.allCases
    expect(cases.count == 4, "Should be exactly 4 cases")
    expect(cases[0] == .landscape, "First case should be landscape")
    expect(cases[1] == .portrait, "Second case should be portrait")
    expect(cases[2] == .landscapeFlipped, "Third case should be landscapeFlipped")
    expect(cases[3] == .portraitFlipped, "Fourth case should be portraitFlipped")
}

// MARK: - Runner

@main
enum TabletOrientationTestRunner {
    static func main() {
        testRawValueAndInit()
        testRotationAngle()
        testSwapsAxes()
        testLabel()
        testAllCases()

        if failures == 0 {
            print("ok — \(checks) checks passed")
            exit(0)
        } else {
            FileHandle.standardError.write(Data("\(failures) of \(checks) checks failed\n".utf8))
            exit(1)
        }
    }
}
