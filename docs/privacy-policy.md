# 粘易 Privacy Policy

Last updated: 2026-07-02

粘易 is designed as a local-first macOS clipboard history tool. This policy describes what the app records, where data is stored, and what controls are available.

## Data The App Processes

The app may process clipboard text, supported clipboard images, image file URLs copied from Finder, source application names, source bundle identifiers, timestamps, favorites, and local metadata such as image size, dimensions, paths, and content hashes.

## Local Storage

Clipboard history is stored locally under the user's Application Support directory:

```text
~/Library/Application Support/MacPasteHistory/
```

The internal storage directory retains the legacy `MacPasteHistory` name so an app update preserves existing clipboard history.

Text and metadata are stored in SQLite. Image originals and thumbnails are stored as local files. The app does not intentionally upload clipboard history, images, hashes, or settings to a cloud service.

The current release does not encrypt the local SQLite database or app-managed image files. Local database encryption is planned as a future P2 capability and should not be treated as available until a dedicated encrypted-storage release is implemented and verified.

## Sensitive Content

The app includes sensitive-text filtering for common patterns such as passwords, API tokens, authorization headers, long token-like strings, bank-card-like numbers, and ID-like numbers. When detected, matching text is skipped instead of being persisted. This filter is best-effort and does not guarantee that every sensitive value is detected.

## App Blocking And Pause Controls

The capture pipeline supports paused recording and blocked application checks. When recording is paused or the foreground app is blocked, matching clipboard changes are skipped. Users should verify blocked-app behavior in their own environment before relying on it for high-risk workflows.

## User Controls

Users can disable text recording, disable image recording, delete individual records, clear text history, or clear all local data. Clear-all removes database history records and app-managed image files. Standard macOS backups or external copies outside the app's control may retain older data.

## Logs

Operational logs should record statuses, lengths, counts, errors, and source identifiers only. Clipboard content itself should not be logged.

## Third Parties

The app does not use third-party analytics, advertising SDKs, or cloud sync in the current implementation.

## Contact And Review

Before public release, review this policy against the final signed build, sandbox configuration, App Store metadata, screenshots, and any future networking or sync changes.
