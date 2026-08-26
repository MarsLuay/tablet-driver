# Decisions

- Keep decoder work in the `TabletKit` submodule; keep MockTab-specific transport, routing, event injection, settings, and UI glue in the app repository.
- Use a dedicated HID thread for report handling and immutable settings snapshots for handoff from the main thread to the input hot path.
- Treat model identity and device-instance identity separately: model-level registries use product IDs; per-device contexts and settings use the composite instance key while preserving the legacy settings prefix for the first unit.
- Keep the app GPL-3.0-or-later and TabletKit MPL-2.0 as separate license boundaries.

Evidence: `README.md`, `Architecture.md`.
