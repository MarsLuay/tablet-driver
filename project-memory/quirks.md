# Quirks

- Build the decoder suite from the `TabletKit/` submodule with `swift test`; root-level app logic has separate standalone checks where documented.
- A fresh clone needs the `TabletKit` submodule initialized. App commits pin the exact package commit they build against.
- Accessibility and Input Monitoring permissions are required for event injection and raw HID access. Permission changes may require removing and re-adding MockTab in System Settings.
- `showInDock` is read before launch finishes and controls regular-versus-accessory activation policy.
- Xencelabs Quick Keys pairing is model-level because the wire protocol does not identify its owner; with multiple identical pen tablets, the first pen-bearing unit is selected.

Evidence: `README.md`, `Contributing.md`, `Architecture.md`, `MockTab/App/MockTabApp.swift`, `MockTab/Info.plist`.
