// MockTab — native macOS driver for supported drawing tablets
// SPDX-FileCopyrightText: 2026 Jay Petronis (Cyzor)
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import AppKit

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

// MARK: - Preset Tests

do {
    let noneBinding = ButtonBinding.none
    expect(noneBinding.kind == .none, "none preset kind is .none")
    expect(noneBinding.displayLabel == "None", "none preset display label is None")
    expect(noneBinding.mouseButton == nil, "none preset mouse button is nil")

    let leftClick = ButtonBinding.leftClick
    expect(leftClick.kind == .leftClick, "leftClick preset kind is .leftClick")
    expect(leftClick.displayLabel == "Left Click", "leftClick preset display label is Left Click")
    expect(leftClick.mouseButton == .left, "leftClick preset mouse button is .left")

    let scrollDrag = ButtonBinding.scrollDrag
    expect(scrollDrag.kind == .scrollDrag, "scrollDrag preset kind is .scrollDrag")
    expect(scrollDrag.displayLabel == "Pan View", "scrollDrag preset display label is Pan View")
    expect(scrollDrag.mouseButton == nil, "scrollDrag preset mouse button is nil")
}

// MARK: - Mouse Button Mappings

do {
    expect(ButtonBinding.rightClick.mouseButton == .right, "rightClick maps to .right")
    expect(ButtonBinding.middleClick.mouseButton == .center, "middleClick maps to .center")
    expect(ButtonBinding(kind: .middleClickWithTip).mouseButton == .center, "middleClickWithTip maps to .center")
    expect(ButtonBinding.doubleClick.mouseButton == nil, "doubleClick is not a single mouse button")
}

// MARK: - Modifier Only Init

do {
    let shiftOnly = ButtonBinding(modifierOnly: .shift)
    expect(shiftOnly.kind == .keyCombo, "modifierOnly creates a keyCombo")
    expect(shiftOnly.keyLabel == "", "modifierOnly has empty keyLabel")
    expect(shiftOnly.keyCode == 56, "modifierOnly with shift maps to keyCode 56")

    let cmdOnly = ButtonBinding(modifierOnly: .command)
    expect(cmdOnly.keyCode == 55, "modifierOnly with command maps to keyCode 55")

    let optionOnly = ButtonBinding(modifierOnly: .option)
    expect(optionOnly.keyCode == 58, "modifierOnly with option maps to keyCode 58")

    let controlOnly = ButtonBinding(modifierOnly: .control)
    expect(controlOnly.keyCode == 59, "modifierOnly with control maps to keyCode 59")
}

// MARK: - Display Label

do {
    let displayToggle = ButtonBinding(kind: .displayToggle)
    expect(displayToggle.displayLabel == "Toggle Display", "displayToggle displayLabel")

    let ringMode1 = ButtonBinding(kind: .ringSelectSlot, keyCode: 0)
    expect(ringMode1.displayLabel == "Ring: Mode 1", "ringSelectSlot 0 displayLabel")

    let ringMode4 = ButtonBinding(kind: .ringSelectSlot, keyCode: 3)
    expect(ringMode4.displayLabel == "Ring: Mode 4", "ringSelectSlot 3 displayLabel")

    // For keyCombo, we manually mock what an NSEvent or UCKeyTranslate would produce.
    // Cmd+C
    var cgFlags = CGEventFlags()
    cgFlags.insert(.maskCommand)
    let cmdC = ButtonBinding(kind: .keyCombo, keyCode: 8, modifierFlags: cgFlags.rawValue, keyLabel: "C")
    expect(cmdC.displayLabel == "⌘C", "Cmd+C display label")

    // Shift+Option+T
    var cgFlags2 = CGEventFlags()
    cgFlags2.insert(.maskShift)
    cgFlags2.insert(.maskAlternate)
    let shiftOptionT = ButtonBinding(kind: .keyCombo, keyCode: 17, modifierFlags: cgFlags2.rawValue, keyLabel: "T")
    expect(shiftOptionT.displayLabel == "⌥⇧T", "Shift+Option+T display label")
}

// MARK: - From Display Label (Parsing)

do {
    let noneParsed = ButtonBinding.fromDisplayLabel("None")
    expect(noneParsed == .none, "fromDisplayLabel('None') parses correctly")

    let eraserParsed = ButtonBinding.fromDisplayLabel("Eraser")
    expect(eraserParsed == .eraser, "fromDisplayLabel('Eraser') parses correctly")

    let legacyScrollDrag = ButtonBinding.fromDisplayLabel("Scroll Drag")
    expect(legacyScrollDrag == .scrollDrag, "fromDisplayLabel('Scroll Drag') parses to scrollDrag")

    let panView = ButtonBinding.fromDisplayLabel("Pan View")
    expect(panView == .scrollDrag, "fromDisplayLabel('Pan View') parses to scrollDrag")

    let ringMode2 = ButtonBinding.fromDisplayLabel("Ring: Mode 2")
    expect(ringMode2.kind == .ringSelectSlot, "parses ring mode kind")
    expect(ringMode2.keyCode == 1, "parses ring mode slot index")

    let cmdSpace = ButtonBinding.fromDisplayLabel("⌘Space")
    expect(cmdSpace.kind == .keyCombo, "⌘Space is keyCombo")
    expect(cmdSpace.keyCode == 49, "⌘Space keyCode is 49 (Space)")
    expect(CGEventFlags(rawValue: cmdSpace.modifierFlags).contains(.maskCommand), "⌘Space has command flag")

    let complexCombo = ButtonBinding.fromDisplayLabel("⌃⌥⇧⌘Space")
    expect(complexCombo.kind == .keyCombo, "Complex combo is keyCombo")
    let complexFlags = CGEventFlags(rawValue: complexCombo.modifierFlags)
    expect(complexFlags.contains(.maskControl), "has control")
    expect(complexFlags.contains(.maskAlternate), "has option")
    expect(complexFlags.contains(.maskShift), "has shift")
    expect(complexFlags.contains(.maskCommand), "has command")
    expect(complexCombo.keyCode == 49, "keyCode is space")
}

// MARK: - Equality

do {
    let b1 = ButtonBinding(kind: .leftClick)
    let b2 = ButtonBinding(kind: .leftClick)
    let b3 = ButtonBinding(kind: .rightClick)
    expect(b1 == b2, "Equal bindings are equal")
    expect(b1 != b3, "Different bindings are not equal")

    let b4 = ButtonBinding(kind: .keyCombo, keyCode: 55, modifierFlags: 1048576, keyLabel: "C")
    let b5 = ButtonBinding(kind: .keyCombo, keyCode: 55, modifierFlags: 1048576, keyLabel: "C")
    let b6 = ButtonBinding(kind: .keyCombo, keyCode: 55, modifierFlags: 131072, keyLabel: "C")
    expect(b4 == b5, "Equal key combos are equal")
    expect(b4 != b6, "Key combos with different flags are not equal")
}

// MARK: - JSON Encoding/Decoding

do {
    let original = ButtonBinding(kind: .keyCombo, keyCode: 49, modifierFlags: CGEventFlags.maskCommand.rawValue, keyLabel: "Space")
    let encodedString = original.encoded

    guard let decoded = ButtonBinding.decode(encodedString) else {
        expect(false, "Failed to decode valid JSON string")
        return
    }
    expect(decoded == original, "Round-tripped binding equals original")
}

// MARK: - Summary

if failures == 0 {
    print("ButtonBindingTests: \(checks) checks passed")
    exit(0)
} else {
    print("ButtonBindingTests: \(failures)/\(checks) checks FAILED")
    exit(1)
}
