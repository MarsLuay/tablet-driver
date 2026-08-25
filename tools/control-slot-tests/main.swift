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

print("Running ControlSlot tests...")

// MARK: - Defaults Test
do {
    let defaults = ControlSlot.defaults
    expect(defaults.count == 4, "Defaults should have exactly 4 slots")
    expect(defaults[0].action == .scroll, "Default slot 0 action should be scroll")
    expect(defaults[1].action == .off, "Default slot 1 action should be off")
    expect(defaults[2].action == .off, "Default slot 2 action should be off")
    expect(defaults[3].action == .off, "Default slot 3 action should be off")
    expect(defaults[0].label.contains("Scroll"), "Default slot 0 label contains Scroll")
}

// MARK: - Equality Test
do {
    let id = UUID()
    let led1 = ControlSlot.LEDColor(r: 255, g: 128, b: 0, a: 255)

    let slot1 = ControlSlot(id: id, label: "Zoom", action: .scroll, cwBinding: .none, ccwBinding: .none, speed: 1.5, ledColor: led1)
    let slot2 = ControlSlot(id: id, label: "Zoom", action: .scroll, cwBinding: .none, ccwBinding: .none, speed: 1.5, ledColor: led1)

    expect(slot1 == slot2, "Identical slots should be equal")

    let slot3 = ControlSlot(id: UUID(), label: "Zoom", action: .scroll, cwBinding: .none, ccwBinding: .none, speed: 1.5, ledColor: led1)
    expect(slot1 != slot3, "Slots with different IDs should not be equal")

    var slot4 = slot1
    slot4.speed = 2.0
    expect(slot1 != slot4, "Slots with different speed should not be equal")

    var slot5 = slot1
    slot5.ledColor = ControlSlot.LEDColor(r: 255, g: 128, b: 0, a: 128)
    expect(slot1 != slot5, "Slots with different LED color brightness should not be equal")
}

// MARK: - JSON Decoding/Encoding Test
do {
    let id = UUID()
    let led = ControlSlot.LEDColor(r: 255, g: 128, b: 0, a: 100)
    let originalSlot = ControlSlot(
        id: id,
        label: "Brush Size",
        action: .keyPress,
        cwBinding: ButtonBinding(kind: .leftClick),
        ccwBinding: ButtonBinding(kind: .rightClick),
        speed: 2.5,
        ledColor: led
    )

    let encoded = try JSONEncoder().encode(originalSlot)
    let decoded = try JSONDecoder().decode(ControlSlot.self, from: encoded)

    expect(decoded == originalSlot, "Decoded slot should match original exactly")
    expect(decoded.id == id, "Decoded ID matches")
    expect(decoded.label == "Brush Size", "Decoded label matches")
    expect(decoded.action == .keyPress, "Decoded action matches")
    expect(decoded.speed == 2.5, "Decoded speed matches")
    expect(decoded.ledColor?.r == 255, "Decoded LED r matches")
    expect(decoded.ledColor?.a == 100, "Decoded LED a matches")
}

// MARK: - Legacy LEDColor Decoding Test
do {
    // Colors saved before the brightness ("a") field existed.
    let legacyJSON = #"{"r":255,"g":0,"b":0}"#
    let color = try JSONDecoder().decode(ControlSlot.LEDColor.self, from: Data(legacyJSON.utf8))
    expect(color.a == 255, "LEDColor defaults missing brightness to full strength")
}

// MARK: - Action Display Label Test
do {
    expect(!ControlSlot.Action.scroll.displayLabel.isEmpty, "Scroll action has a display label")
    expect(!ControlSlot.Action.keyPress.displayLabel.isEmpty, "KeyPress action has a display label")
    expect(!ControlSlot.Action.off.displayLabel.isEmpty, "Off action has a display label")
    expect(!ControlSlot.Action.skip.displayLabel.isEmpty, "Skip action has a display label")
}

// MARK: - Summary
if failures == 0 {
    print("ControlSlotTests: \(checks) checks passed")
    exit(0)
} else {
    print("ControlSlotTests: \(failures)/\(checks) checks FAILED")
    exit(1)
}
