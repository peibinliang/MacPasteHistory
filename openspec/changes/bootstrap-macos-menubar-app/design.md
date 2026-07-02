## Context

This project starts as a Mac menu bar clipboard history utility. The first phase must produce a stable app shell that can launch, stay resident in the menu bar, open a main panel, open settings, and prepare local storage.

## Goals / Non-Goals

**Goals:**
- Build a runnable SwiftUI macOS app with menu bar presence.
- Provide main and settings window entry points.
- Create the Application Support directory and initialize SQLite.
- Add minimal logging and settings helpers for later phases.

**Non-Goals:**
- Clipboard monitoring, history capture, image processing, privacy filtering, shortcuts, and release packaging are handled by later changes.

## Decisions

- Use SwiftUI for app views while using AppKit where required for `NSStatusItem` and macOS-specific window behavior. This keeps the UI modern while preserving menu bar control.
- Store app data under Application Support instead of Documents or temporary folders so history data persists without being user-facing by default.
- Initialize SQLite through a database manager and migration layer so later phases can add tables and indexes predictably.
- Keep `UserDefaults` for lightweight preferences only; clipboard history and larger data belong in SQLite and the app data directory.

## Risks / Trade-offs

- `NSStatusItem` lifecycle bugs could make the menu item disappear -> keep the status item strongly retained for the lifetime of the app.
- SQLite setup can fail because of filesystem permissions or path issues -> surface initialization errors in logs and avoid crashing without diagnostics.
- Window management can become inconsistent across SwiftUI and AppKit -> centralize window opening behavior behind small app-level helpers.
