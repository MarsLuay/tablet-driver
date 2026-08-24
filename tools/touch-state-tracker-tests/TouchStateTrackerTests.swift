// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreGraphics
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

private func testScreenPoint() {
    let contact = TouchContact(id: 1, x: 50, y: 50, contactArea: nil)
    let displayBounds = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    let p = TouchStateTracker.screenPoint(
        for: contact,
        maxX: 100, maxY: 100,
        areaX: 0.0, areaY: 0.0,
        areaWidth: 1.0, areaHeight: 1.0,
        displayBounds: displayBounds
    )

    expectEqual(p, CGPoint(x: 500, y: 500), "screenPoint projects correctly to center")

    let outOfBoundsContact = TouchContact(id: 2, x: 200, y: 50, contactArea: nil)
    let p2 = TouchStateTracker.screenPoint(
        for: outOfBoundsContact,
        maxX: 100, maxY: 100,
        areaX: 0.0, areaY: 0.0,
        areaWidth: 1.0, areaHeight: 1.0,
        displayBounds: displayBounds
    )
    expectEqual(p2, nil, "screenPoint returns nil for out of bounds contact")
}

private func testProcessPointerMove() {
    var tracker = TouchStateTracker()

    // First contact (pending state, onset delay)
    var intent = tracker.process(
        contacts: [(id: 1, screen: CGPoint(x: 100, y: 100))],
        tapToClick: true,
        twoFingerScroll: true,
        reverseScrollDirection: false,
        sensitivity: 1.0,
        now: 0.0
    )
    expectEqual(intent, .none, "initial contact should return none (pending state)")
    expectEqual(tracker.mode, .pending, "tracker should be in pending state")

    // Move after onset delay
    intent = tracker.process(
        contacts: [(id: 1, screen: CGPoint(x: 150, y: 150))],
        tapToClick: true,
        twoFingerScroll: true,
        reverseScrollDirection: false,
        sensitivity: 1.0,
        now: TouchStateTracker.onsetDelay + 0.1
    )
    expectEqual(intent, .pointerMove(dx: 50, dy: 50), "should return pointerMove intent")
    expectEqual(tracker.mode, .pointer, "tracker should be in pointer state")

    // Release
    intent = tracker.process(
        contacts: [],
        tapToClick: true,
        twoFingerScroll: true,
        reverseScrollDirection: false,
        sensitivity: 1.0,
        now: TouchStateTracker.onsetDelay + 0.2
    )
    // moved 50 points, which is > tapMaxDistance (8.0). So it shouldn't be a tapClick.
    expectEqual(intent, .none, "release after drag should return none")
    expectEqual(tracker.mode, .idle, "tracker should be in idle state")
}

private func testProcessTapClick() {
    var tracker = TouchStateTracker()

    var intent = tracker.process(
        contacts: [(id: 1, screen: CGPoint(x: 100, y: 100))],
        tapToClick: true,
        twoFingerScroll: true,
        reverseScrollDirection: false,
        sensitivity: 1.0,
        now: 0.0
    )
    expectEqual(intent, .none, "initial contact should return none")

    intent = tracker.process(
        contacts: [],
        tapToClick: true,
        twoFingerScroll: true,
        reverseScrollDirection: false,
        sensitivity: 1.0,
        now: 0.1
    )
    expectEqual(intent, .tapClick, "quick release without moving should return tapClick")
}

private func testProcessScroll() {
    var tracker = TouchStateTracker()

    // First contact
    _ = tracker.process(
        contacts: [(id: 1, screen: CGPoint(x: 100, y: 100))],
        tapToClick: true,
        twoFingerScroll: true,
        reverseScrollDirection: false,
        sensitivity: 1.0,
        now: 0.0
    )

    // Second contact lands immediately (escalate to scroll)
    var intent = tracker.process(
        contacts: [
            (id: 1, screen: CGPoint(x: 100, y: 100)),
            (id: 2, screen: CGPoint(x: 120, y: 100))
        ],
        tapToClick: true,
        twoFingerScroll: true,
        reverseScrollDirection: false,
        sensitivity: 1.0,
        now: 0.05
    )
    expectEqual(intent, .scrollDelta(dx: 0, dy: 0, phase: .began), "second contact should start scroll (.began)")

    // Move both contacts
    intent = tracker.process(
        contacts: [
            (id: 1, screen: CGPoint(x: 100, y: 120)),
            (id: 2, screen: CGPoint(x: 120, y: 120))
        ],
        tapToClick: true,
        twoFingerScroll: true,
        reverseScrollDirection: false,
        sensitivity: 1.0,
        now: 0.1
    )
    expectEqual(intent, .scrollDelta(dx: 0, dy: 20, phase: .changed), "moving contacts should return scroll (.changed)")

    // Release
    intent = tracker.process(
        contacts: [],
        tapToClick: true,
        twoFingerScroll: true,
        reverseScrollDirection: false,
        sensitivity: 1.0,
        now: 0.15
    )
    expectEqual(intent, .scrollDelta(dx: 0, dy: 0, phase: .ended), "releasing all contacts should return scroll (.ended)")
}

@main
enum TouchStateTrackerTestRunner {
    static func main() {
        testScreenPoint()
        testProcessPointerMove()
        testProcessTapClick()
        testProcessScroll()

        if failures == 0 {
            print("ok — \(checks) checks passed")
            exit(0)
        } else {
            FileHandle.standardError.write(Data("\(failures) of \(checks) checks failed\n".utf8))
            exit(1)
        }
    }
}
