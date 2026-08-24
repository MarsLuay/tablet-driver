// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import CoreGraphics

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

private func expectNear(_ a: Double, _ b: Double, epsilon: Double = 0.0001, _ message: @autoclosure () -> String,
                                       file: StaticString = #file, line: UInt = #line) {
    expect(abs(a - b) <= epsilon, "\(message()) — got \(a), expected \(b)", file: file, line: line)
}

// MARK: - Tests

private func testEngageDisengage() {
    var tracker = PanScrollTracker()
    expectEqual(tracker.isActive, false, "initially inactive")

    let intentBegan = tracker.engage(reverse: false)
    expectEqual(tracker.isActive, true, "active after engage")
    expectEqual(intentBegan, .scroll(dx: 0, dy: 0, phase: .began), "engage emits began")

    let intentEnded = tracker.disengage()
    expectEqual(tracker.isActive, false, "inactive after disengage")
    expectEqual(intentEnded, .scroll(dx: 0, dy: 0, phase: .ended), "disengage emits ended")

    let intentNone = tracker.disengage()
    expectEqual(intentNone, .none, "disengage is idempotent")
}

private func testProcessContinuous() {
    var tracker = PanScrollTracker()
    _ = tracker.engage(reverse: false)

    let intentFirst = tracker.process(screen: CGPoint(x: 10, y: 10), dt: 0.008)
    expectEqual(intentFirst, .none, "first frame sets anchor, emits none")

    // Disable smoothing logic so our delta is 1:1 mapped for these basic tests
    // Actually PanSmoother uses speed-adaptive dampening, but moving enough should break through and give us some scroll.
    // Instead of fighting smoothing, let's just make it do zero smoothing by making strength 0 manually, but it's hardcoded to 0.3.
    // So we'll expect *some* intent back.
    let intentSecond = tracker.process(screen: CGPoint(x: 20, y: 30), dt: 0.008)
    if case .scroll(let dx, let dy, let phase) = intentSecond {
        expect(dx > 0, "dx should be positive")
        expect(dy > 0, "dy should be positive")
        expectEqual(phase, .changed, "phase should be changed")
    } else {
        expect(false, "expected scroll intent")
    }
}

private func testAxisLock() {
    var tracker = PanScrollTracker()
    _ = tracker.engage(reverse: false)

    _ = tracker.process(screen: CGPoint(x: 10, y: 10), dt: 0.008)

    // Move mostly horizontally to trigger horizontal lock
    // Needs >= 26 points of travel and 2:1 ratio
    var totalX = 0.0
    var intent: PanScrollTracker.Intent = .none
    for i in 1...30 {
        intent = tracker.process(screen: CGPoint(x: 10 + Double(i), y: 10), dt: 0.008)
    }

    // Once locked horizontal, a vertical motion shouldn't produce dy
    intent = tracker.process(screen: CGPoint(x: 40, y: 50), dt: 0.008)
    if case .scroll(let dx, let dy, _) = intent {
        expect(dy == 0, "dy should be 0 due to horizontal lock")
    } else {
        expect(false, "expected scroll intent")
    }
}

private func testSuspend() {
    var tracker = PanScrollTracker()
    _ = tracker.engage(reverse: false)

    _ = tracker.process(screen: CGPoint(x: 10, y: 10), dt: 0.008)
    tracker.suspend()
    expectEqual(tracker.isActive, true, "still active after suspend")

    let intentResume = tracker.process(screen: CGPoint(x: 100, y: 100), dt: 0.008)
    expectEqual(intentResume, .none, "first frame after suspend emits none, sets new anchor")
}

private func testFractionalAccumulation() {
    var tracker = PanScrollTracker()
    _ = tracker.engage(reverse: false)

    _ = tracker.process(screen: CGPoint(x: 0, y: 0), dt: 0.008)

    // Move by small amounts
    var intents: [PanScrollTracker.Intent] = []
    for i in 1...100 {
        intents.append(tracker.process(screen: CGPoint(x: Double(i) * 0.5, y: 0), dt: 0.008))
    }

    let changedIntents = intents.filter { $0 != .none }
    expect(changedIntents.count > 0, "should have some scroll events after accumulation")
}

private func testVelocity() {
    var tracker = PanScrollTracker()
    _ = tracker.engage(reverse: false)
    _ = tracker.process(screen: CGPoint(x: 0, y: 0), dt: 0.01)
    _ = tracker.process(screen: CGPoint(x: 100, y: 0), dt: 0.01) // 10000 pt/s raw speed
    _ = tracker.disengage()
    expect(tracker.releaseVelocity.dx > 0, "should have some positive release velocity")
    expectEqual(tracker.releaseVelocity.dy, 0, "dy velocity should be 0")
}

// MARK: - Runner

@main
enum PanScrollTrackerTestRunner {
    static func main() {
        testEngageDisengage()
        testProcessContinuous()
        testAxisLock()
        testSuspend()
        testFractionalAccumulation()
        testVelocity()

        if failures == 0 {
            print("ok — \(checks) checks passed")
            exit(0)
        } else {
            FileHandle.standardError.write(Data("\(failures) of \(checks) checks failed\n".utf8))
            exit(1)
        }
    }
}
