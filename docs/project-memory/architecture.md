# Architecture

- `MockTab/App/MockTabApp.swift` is the macOS app entry point. The `MockTab` Xcode target consumes local `TabletKit/` as a Swift package submodule.
- Live input path: `IOHIDManager` on dedicated `HIDThread` callbacks, device wrapper routing, `TabletReportDecoder.decode`, `TabletManager`, `DeviceContext`/`InputInjector`, then `CGEventPost` to WindowServer.
- `TabletKit` contains pure decoder logic, registries, value types, and smoothing helpers. App-specific HID transport, device management, injection, mapping, settings, and UI stay in MockTab.
- HID callbacks and hot-path work stay on `HIDThread`. AppKit, SwiftUI, settings, and IOKit feature-report writes stay on the main thread. Settings cross the boundary through immutable injection snapshots.
- Decoder tests live under `TabletKit/Tests/TabletKitTests/` and run with `cd TabletKit && swift test`.

Evidence: `README.md`, `Architecture.md`, `MockTab/App/MockTabApp.swift`, `MockTab.xcodeproj/project.pbxproj`.
