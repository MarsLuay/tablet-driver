# Known failures

- On the documented macOS 27 Golden Gate beta, pen clicks on visible content in a background window may not activate that window reliably. Click its title bar first.
- Support is intentionally incomplete for Huion, XP-Pen, newer Wacom product cycles not listed in the hardware support documentation, Windows, Linux, and iPad.
- A companion Quick Keys puck cannot be deterministically paired when multiple identical pen tablets are present; model-level pairing chooses the first pen-bearing unit.

Evidence: `README.md`, `Architecture.md`.
