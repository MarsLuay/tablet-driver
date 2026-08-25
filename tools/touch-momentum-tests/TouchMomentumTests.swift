// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import TabletKit

private var failures = 0
private var checks = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    guard condition() else {
        failures += 1
        FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
        return
    }
}

private func contacts(y: Double) -> [(id: Int, screen: CGPoint)] {
    [(id: 1, screen: CGPoint(x: -10, y: y)),
     (id: 2, screen: CGPoint(x: 10, y: y))]
}

private func process(
    _ tracker: inout TouchStateTracker, _ contacts: [(id: Int, screen: CGPoint)],
    reverse: Bool = false, at time: CFAbsoluteTime
) -> TouchStateTracker.Intent {
    tracker.process(
        contacts: contacts,
        tapToClick: false,
        twoFingerScroll: true,
        reverseScrollDirection: reverse,
        sensitivity: 1,
        now: time)
}

private func startScroll(_ tracker: inout TouchStateTracker, reverse: Bool = false) {
    _ = process(&tracker, contacts(y: 0), reverse: reverse, at: 0)
    let began = process(&tracker, contacts(y: 0), reverse: reverse, at: 0.01)
    if case .scrollDelta(let dx, let dy, let phase) = began {
        expect(dx == 0 && dy == 0 && phase == .began, "two-finger touch begins a scroll")
    } else {
        expect(false, "two-finger touch emits a began phase")
    }
}

private func releaseVelocity(reverse: Bool = false, stationaryFrame: Bool = false) -> CGVector? {
    var tracker = TouchStateTracker()
    startScroll(&tracker, reverse: reverse)
    let changed = process(&tracker, contacts(y: 10), reverse: reverse, at: 0.02)
    if case .scrollDelta(_, let dy, let phase) = changed {
        expect(phase == .changed, "touch motion emits a changed phase")
        expect(reverse ? dy < 0 : dy > 0, "touch delta follows the configured direction")
    } else {
        expect(false, "touch motion emits a scroll delta")
    }
    if stationaryFrame {
        _ = process(&tracker, contacts(y: 10), reverse: reverse, at: 0.03)
    }
    let ended = process(
        &tracker, [], reverse: reverse, at: stationaryFrame ? 0.10 : 0.03)
    if case .scrollDelta(let dx, let dy, let phase) = ended {
        expect(dx == 0 && dy == 0 && phase == .ended, "last finger lift closes the scroll phase")
        return tracker.releaseVelocity
    }
    expect(false, "last finger lift emits a scroll end phase")
    return nil
}

private func testReleaseVelocity() {
    let velocity = releaseVelocity()
    expect((velocity?.dy ?? 0) > 0, "forward touch flick has positive release velocity")
    expect((velocity?.dy ?? 0) > 400, "a 10 pt / 10 ms flick retains a responsive seed velocity")
}

private func testReverseVelocity() {
    let velocity = releaseVelocity(reverse: true)
    expect((velocity?.dy ?? 0) < 0, "reversed touch flick reverses momentum direction")
}

private func testDeliberateBrakeSuppressesVelocity() {
    let moving = abs(releaseVelocity()?.dy ?? 0)
    let stationary = abs(releaseVelocity(stationaryFrame: true)?.dy ?? 0)
    expect(stationary < moving, "a deliberate pause before lift suppresses momentum")
}

@main
enum TouchMomentumTestRunner {
    static func main() {
        testReleaseVelocity()
        testReverseVelocity()
        testDeliberateBrakeSuppressesVelocity()
        if failures == 0 {
            print("ok — \(checks) checks passed")
            exit(0)
        }
        FileHandle.standardError.write(Data("\(failures) of \(checks) checks failed\n".utf8))
        exit(1)
    }
}
