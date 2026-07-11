## Context

The app records clipboard data locally, so users must be able to configure recording behavior and data retention. Settings need to be reliable because they directly affect privacy, storage, and startup behavior.

## Goals / Non-Goals

**Goals:**
- Provide a usable settings page.
- Persist all settings across restarts.
- Control text and image recording.
- Configure retention and storage limits.
- Clear all local data from the app.

**Non-Goals:**
- Sensitive content rules, blocked apps, and privacy notice are handled in the privacy change.

## Decisions

- Store small settings values in `UserDefaults` or the `app_settings` table through a single settings service.
- Apply text/image recording toggles at the clipboard monitoring boundary so disabled content is never saved.
- Route clear-all through repositories and file storage services so database rows and image files are removed together.
- Keep Dock icon and launch-at-login settings behind platform-specific services to isolate macOS APIs.

## Risks / Trade-offs

- Clear-all is destructive -> require explicit user confirmation before deleting local data.
- Settings may not apply until restart if services cache values -> publish setting updates or reload them where monitors run.
- Launch-at-login and Dock icon behavior can differ by macOS version -> encapsulate platform calls and verify manually.
