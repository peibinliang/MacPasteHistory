# 粘易 Privacy Policy

Last updated: 2026-08-12

粘易 is designed as a local-first macOS clipboard history tool. This policy describes what the app records, where data is stored, and what controls are available.

## Data The App Processes

The app may process clipboard text, supported clipboard images, image file URLs copied from Finder, source application names, source bundle identifiers, timestamps, favorites, and local metadata such as image size, dimensions, paths, and content hashes.

## Local Storage

Clipboard history is stored locally under the user's Application Support directory:

```text
~/Library/Application Support/MacPasteHistory/
```

The internal storage directory retains the legacy `MacPasteHistory` name so an app update preserves existing clipboard history.

Text and metadata are stored in SQLite. Image originals and thumbnails are stored as local files. Clipboard capture, structured search, deterministic content actions, JWT parsing, and manual OCR are processed locally. OCR runs only after a user explicitly selects it for one image; the app does not automatically scan historical images. JWT parsing is a format inspection aid and never verifies a signature or trust claim.

## Optional AI Polishing

AI Polishing is an explicit, user-initiated network feature. Before its first request, the app discloses that the currently selected text will be sent over HTTPS to DeepSeek and may be subject to DeepSeek's terms and charges. Declining sends nothing and does not affect local clipboard features. The app never invokes AI during clipboard monitoring and does not send images or bulk history.

The DeepSeek API key is stored in macOS Keychain and is not saved in UserDefaults or SQLite. For successful responses, SQLite may store only provider, model, request identifier, and provider-reported token counts. It does not store the request text, fixed polishing instruction, response text, or API key in the usage table. Users can remove the credential separately in AI Settings. Clear All Data removes local token-usage records but does not silently remove the Keychain credential.

The current release does not encrypt the local SQLite database or app-managed image files. Local database encryption is planned as a future P2 capability and should not be treated as available until a dedicated encrypted-storage release is implemented and verified.

## Sensitive Content

The app enables sensitive-text filtering by default. Detection runs entirely on the Mac and recognizes high-confidence contextual credentials and secrets, checksum-valid payment-card candidates, and 18-character Mainland China identity candidates whose date and check digit are valid. Git SHA values, MD5 hashes, UUIDs, trace identifiers, and unlabelled long strings are not blocked solely because of their shape or length. When filtering is enabled, only a high-confidence result is skipped instead of being persisted; lower-confidence or unmatched content remains eligible for recording. This filter is best-effort and does not guarantee that every sensitive value is detected.

Users may disable the filter under **Settings → Privacy → Filter sensitive content**. The first disable request requires confirmation that matching sensitive text may then be saved to the local, unencrypted SQLite history database. Cancelling keeps filtering enabled. Re-enabling the same switch takes effect immediately and does not remove sensitive records that were already saved; those records can be deleted individually or through the clear-data controls.

## App Blocking And Pause Controls

The capture pipeline supports paused recording and blocked application checks. For each observed pasteboard change, the app resolves the current foreground application once and reuses that immutable snapshot for the blocked-app decision, history metadata, and capture event. Switching to another foreground app after processing begins does not replace that snapshot. macOS pasteboard data does not identify which process performed the copy, so switching apps before the polling loop observes the change can cause the later foreground app to be used; blocked-app filtering is best-effort and is not an absolute security boundary. When recording is paused or the captured source app is blocked, matching clipboard changes are skipped.

## User Controls

Users can disable text recording, disable image recording, delete individual records, clear text history, or clear all local data. Clear-all removes database history records and app-managed image files. Standard macOS backups or external copies outside the app's control may retain older data.

## System Permissions

Automatic Paste is off by default. The app does not ask for Accessibility access on launch. When a user enables Automatic Paste, settings explains the permission and links to the correct macOS pane. Without permission—or while the setting is off—the app still restores content to the clipboard and asks the user to press `Command-V` manually. Target-app activation, paste dispatch and usage accounting are coordinated locally; failed or cancelled dispatch does not transmit clipboard content and does not retry in the background. Permission state is checked locally and is never transmitted.

## Logs

Operational logs should record statuses, lengths, counts, errors, and source identifiers only. Clipboard content itself should not be logged. Sensitive detection results use only a category, confidence, and fixed reason code; matched values are not included in those diagnostics.

## Software Updates And Network Requests

The app uses Sparkle for software updates. When automatic checks are enabled, or when the user selects **Settings → About & Updates → Check for Updates…**, Sparkle requests the fixed GitHub Pages appcast and may request GitHub-hosted release notes and an update package. These requests are for update metadata and artifacts only. The app does not include clipboard history, images, content hashes, settings, or clipboard payloads in update requests.

Users can change the automatic-check preference under **About & Updates** and can still request a manual check. A formally published update is verified before installation; failed or cancelled checks do not upload local history.

## Third Parties

The app does not use third-party analytics, advertising SDKs, cloud sync, or remote clipboard storage. GitHub hosts update metadata and artifacts, Sparkle performs the update workflow described above, and DeepSeek is contacted only for an explicit AI Polishing request.

## Contact And Review

Before public release, review this policy against the final signed build, sandbox configuration, App Store metadata, screenshots, and any future networking or sync changes.
