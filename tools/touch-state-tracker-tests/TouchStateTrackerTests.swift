// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 MockTab Authors
// SPDX-License-Identifier: GPL-3.0-or-later

// TouchStateTrackerTests.swift — Standalone checks for touch gesture intent.
//
// The app has no XCTest target, so these run as a small executable compiled
// against the real TouchStateTracker.swift. Run via
// tools/touch-state-tracker-tests/run.sh. Exits non-zero on the first failure.

import CoreGraphics
import Foundation
import TabletKit

private var failures = 0
private var checks = 0

private func expect(
    _ condition: Bool,
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    line: UInt = #line
) {
    checks += 1
    guard !condition else { return }
    failures += 1
    FileHandle.standardError.write(Data("FAIL (\(file):\(line)): \(message())\n".utf8))
}

private func expectEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    line: UInt = #line
) {
    expect(actual == expected, "\(message()) — got \(actual), expected \(expected)", file: file, line: line)
}

private func contacts(distance: Double) -> [(id: Int, screen: CGPoint)] {
    [(id: 1, screen: CGPoint(x: -distance / 2, y: 0)),
     (id: 2, screen: CGPoint(x: distance / 2, y: 0))]
}

private func process(
    _ tracker: inout TouchStateTracker,
    _ contacts: [(id: Int, screen: CGPoint)],
    tapToClick: Bool = false,
    pinchZoom: Bool = true,
    at time: CFAbsoluteTime
) -> TouchStateTracker.Intent {
    tracker.process(
        contacts: contacts,
        tapToClick: tapToClick,
        twoFingerScroll: true,
        reverseScrollDirection: false,
        sensitivity: 1,
        pinchZoom: pinchZoom,
        now: time
    )
}

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

    var intent = process(
        &tracker,
        [(id: 1, screen: CGPoint(x: 100, y: 100))],
        tapToClick: true,
        pinchZoom: false,
        at: 0.0
    )
    expectEqual(intent, .none, "initial contact should return none (pending state)")
    expectEqual(tracker.mode, .pending, "tracker should be in pending state")

    intent = process(
        &tracker,
        [(id: 1, screen: CGPoint(x: 150, y: 150))],
        tapToClick: true,
        pinchZoom: false,
        at: TouchStateTracker.onsetDelay + 0.1
    )
    expectEqual(intent, .none, "onset commit discards pending-window motion instead of jumping")
    expectEqual(tracker.mode, .pointer, "tracker should be in pointer state")

    intent = process(
        &tracker,
        [(id: 1, screen: CGPoint(x: 180, y: 190))],
        tapToClick: true,
        pinchZoom: false,
        at: TouchStateTracker.onsetDelay + 0.2
    )
    expectEqual(intent, .pointerMove(dx: 30, dy: 40), "should return pointerMove intent")
    expectEqual(tracker.mode, .pointer, "tracker should stay in pointer state")

    intent = process(
        &tracker,
        [],
        tapToClick: true,
        pinchZoom: false,
        at: TouchStateTracker.onsetDelay + 0.3
    )
    expectEqual(intent, .none, "release after drag should return none")
    expectEqual(tracker.mode, .idle, "tracker should be in idle state")
}

private func testProcessTapClick() {
    var tracker = TouchStateTracker()

    var intent = process(
        &tracker,
        [(id: 1, screen: CGPoint(x: 100, y: 100))],
        tapToClick: true,
        pinchZoom: false,
        at: 0.0
    )
    expectEqual(intent, .none, "initial contact should return none")

    intent = process(
        &tracker,
        [],
        tapToClick: true,
        pinchZoom: false,
        at: 0.1
    )
    expectEqual(intent, .tapClick, "quick release without moving should return tapClick")
}

private func testProcessScroll() {
    var tracker = TouchStateTracker()

    _ = process(
        &tracker,
        [(id: 1, screen: CGPoint(x: 100, y: 100))],
        tapToClick: true,
        pinchZoom: false,
        at: 0.0
    )

    var intent = process(
        &tracker,
        [
            (id: 1, screen: CGPoint(x: 100, y: 100)),
            (id: 2, screen: CGPoint(x: 120, y: 100)),
        ],
        tapToClick: true,
        pinchZoom: false,
        at: 0.05
    )
    expectEqual(intent, .scrollDelta(dx: 0, dy: 0, phase: .began), "second contact should start scroll (.began)")

    intent = process(
        &tracker,
        [
            (id: 1, screen: CGPoint(x: 100, y: 120)),
            (id: 2, screen: CGPoint(x: 120, y: 120)),
        ],
        tapToClick: true,
        pinchZoom: false,
        at: 0.1
    )
    expectEqual(intent, .scrollDelta(dx: 0, dy: 20, phase: .changed), "moving contacts should return scroll (.changed)")

    intent = process(
        &tracker,
        [],
        tapToClick: true,
        pinchZoom: false,
        at: 0.15
    )
    expectEqual(intent, .scrollDelta(dx: 0, dy: 0, phase: .ended), "releasing all contacts should return scroll (.ended)")
}

/// The full magnify envelope: silent commit (no Began until pinch wins),
/// then Changed frames carrying the exact relative growth of inter-finger
/// distance since the previous frame — spreading positive, closing negative
/// — then an Ended bracket on lift.
private func testPinchMagnifyEnvelope() {
    var tracker = TouchStateTracker()
    _ = process(&tracker, [(id: 1, screen: .zero)], at: 0)
    expectEqual(process(&tracker, contacts(distance: 20), at: 0.01), .none,
                "two-finger pinch waits for a decisive motion")
    expectEqual(process(&tracker, contacts(distance: 30), at: 0.02),
                .zoomMagnify(magnification: 0, phase: .began),
                "distance-dominant motion commits to pinch and opens the envelope")
    expectEqual(process(&tracker, contacts(distance: 45), at: 0.03),
                .zoomMagnify(magnification: 15.0 / 30.0, phase: .changed),
                "spreading fingers emits the exact relative growth since last frame")
    expectEqual(process(&tracker, contacts(distance: 30), at: 0.04),
                .zoomMagnify(magnification: -15.0 / 45.0, phase: .changed),
                "closing fingers emits negative relative growth")
    expectEqual(process(&tracker, [], at: 0.05),
                .zoomMagnify(magnification: 0, phase: .ended),
                "lifting fingers closes the magnify envelope")
}

private func testPreCommitLiftHasNoScrollEnd() {
    var tracker = TouchStateTracker()
    _ = process(&tracker, [(id: 1, screen: .zero)], at: 0)
    _ = process(&tracker, contacts(distance: 20), at: 0.01)
    expectEqual(process(&tracker, [], at: 0.02), .none,
                "a pinch that never commits must not emit a scroll end")
}

/// A finger lifting mid-gesture collapses the centroid onto the surviving
/// contact — roughly half the finger separation from the two-finger anchor.
/// That must not read as translation and commit a pan.
private func testSingleContactFrameDoesNotCommitPan() {
    var tracker = TouchStateTracker()
    _ = process(&tracker, [(id: 1, screen: .zero)], at: 0)
    _ = process(&tracker, contacts(distance: 40), at: 0.01)
    expectEqual(process(&tracker, [(id: 2, screen: CGPoint(x: 20, y: 0))], at: 0.02),
                .none,
                "a 1-contact frame while undecided must not commit a phantom pan")
}

private func rawContact(
    id: Int, major: Int?, minor: Int? = nil
) -> (id: Int, major: Int?, minor: Int?) {
    (id: id, major: major, minor: minor)
}

/// PTH-660 and PTH-860 share the same IntuosV2 touch report layout — the
/// registry's own touchMaxX/Y for PTH-660 are estimated from PTH-860's
/// confirmed values — so both PIDs go through the calibrated palm filter.
private func testPalmRejectionOnCalibratedFamily() {
    for productID in [0x0357, 0x0358] {
        var rejector = TouchPalmRejector()

        let initial = rejector.filter(
            contacts: [rawContact(id: 1, major: 6, minor: 7), rawContact(id: 2, major: 2, minor: 3)],
            productID: productID)
        expectEqual(initial.acceptedIDs, Set([2]),
                    "a palm must be dropped while a simultaneous finger remains usable")
        expectEqual(initial.newlyRejectedIDs, [1],
                    "the live palm-sized contact must be classified as a palm")

        let stillRejected = rejector.filter(
            contacts: [rawContact(id: 1, major: 4, minor: 4), rawContact(id: 2, major: 2, minor: 3)],
            productID: productID)
        expectEqual(stillRejected.acceptedIDs, Set([2]),
                    "hysteresis must keep a palm rejected between thresholds")

        let accepted = rejector.filter(
            contacts: [rawContact(id: 1, major: 3, minor: 3)], productID: productID)
        expectEqual(accepted.acceptedIDs, Set([1]),
                    "a contact below the lower threshold can return as a finger")
        expectEqual(accepted.newlyAcceptedIDs, [1],
                    "the hysteresis release must be observable for logging")
    }
}

private func testPalmFilteringIsFamilySpecific() {
    var rejector = TouchPalmRejector()
    let result = rejector.filter(
        contacts: [rawContact(id: 1, major: 41)], productID: 0x0317)
    expectEqual(result.acceptedIDs, Set([1]),
                "un-calibrated tablet families must keep their contacts unchanged")
}

@main
enum TouchStateTrackerTestRunner {
    static func main() {
        testScreenPoint()
        testProcessPointerMove()
        testProcessTapClick()
        testProcessScroll()
        testPinchMagnifyEnvelope()
        testPreCommitLiftHasNoScrollEnd()
        testSingleContactFrameDoesNotCommitPan()
        testPalmRejectionOnCalibratedFamily()
        testPalmFilteringIsFamilySpecific()

        if failures == 0 {
            print("ok — \(checks) checks passed")
            exit(0)
        }
        FileHandle.standardError.write(Data("\(failures) of \(checks) checks failed\n".utf8))
        exit(1)
    }
}
