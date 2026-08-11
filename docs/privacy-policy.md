# 粘易 Privacy Policy

Last updated: 2026-08-11

粘易 is designed as a local-first macOS clipboard history tool. This policy describes what the app records, where data is stored, and what controls are available.

## Data The App Processes

The app may process clipboard text, supported clipboard images, image file URLs copied from Finder, source application names, source bundle identifiers, timestamps, favorites, and local metadata such as image size, dimensions, paths, and content hashes.

## Local Storage

Clipboard history is stored locally under the user's Application Support directory:

```text
~/Library/Application Support/MacPasteHistory/
```

The internal storage directory retains the legacy `MacPasteHistory` name so an app update preserves existing clipboard history.

Text and metadata are stored in SQLite. Image originals and thumbnails are stored as local files. The app does not intentionally upload clipboard history, images, hashes, or settings to a cloud service. Structured search, content actions, JWT parsing and manual OCR are also processed locally. OCR runs only after a user explicitly selects it for one image; the app does not automatically scan historical images. JWT parsing is a format inspection aid and never verifies a signature or trust claim.

The current release does not encrypt the local SQLite database or app-managed image files. Local database encryption is planned as a future P2 capability and should not be treated as available until a dedicated encrypted-storage release is implemented and verified.

## Sensitive Content

The app enables sensitive-text filtering by default for common patterns such as passwords, API tokens, authorization headers, long token-like strings, bank-card-like numbers, and ID-like numbers. When filtering is enabled and a pattern is detected, matching text is skipped instead of being persisted. This filter is best-effort and does not guarantee that every sensitive value is detected.

Users may disable the filter under **Settings → Privacy → Filter sensitive content**. The first disable request requires confirmation that matching sensitive text may then be saved to the local, unencrypted SQLite history database. Cancelling keeps filtering enabled. Re-enabling the same switch takes effect immediately and does not remove sensitive records that were already saved; those records can be deleted individually or through the clear-data controls.

## App Blocking And Pause Controls

The capture pipeline supports paused recording and blocked application checks. When recording is paused or the foreground app is blocked, matching clipboard changes are skipped. Users should verify blocked-app behavior in their own environment before relying on it for high-risk workflows.

## User Controls

Users can disable text recording, disable image recording, delete individual records, clear text history, or clear all local data. Clear-all removes database history records and app-managed image files. Standard macOS backups or external copies outside the app's control may retain older data.

## System Permissions

Direct paste uses macOS Accessibility permission to send `Command + V` to the application that was active before opening history. 粘易 checks this permission locally and does not transmit the result. When permission is missing, the app shows guidance on first launch and again before a blocked direct-paste attempt; users can open the macOS Accessibility settings pane from the reminder. Clipboard history remains unchanged until permission is available and the paste action is retried.

## Logs

Operational logs should record statuses, lengths, counts, errors, and source identifiers only. Clipboard content itself should not be logged.

## Software Updates And Network Requests

The app uses Sparkle for software updates. When automatic checks are enabled, or when the user selects **Settings → About & Updates → Check for Updates…**, Sparkle requests the fixed GitHub Pages appcast and may request GitHub-hosted release notes and an update package. These requests are for update metadata and artifacts only. The app does not include clipboard history, images, content hashes, settings, or clipboard payloads in update requests.

Users can change the automatic-check preference under **About & Updates** and can still request a manual check. A formally published update is verified before installation; failed or cancelled checks do not upload local history.

## Third Parties

The app does not use third-party analytics, advertising SDKs, cloud sync, or remote clipboard storage. GitHub hosts update metadata and artifacts, and Sparkle performs the update workflow described above.

## Contact And Review

Before public release, review this policy against the final signed build, sandbox configuration, App Store metadata, screenshots, and any future networking or sync changes.
