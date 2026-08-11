# 粘易

[简体中文](README.md) | [English](README_EN.md)

粘易 is a local-first clipboard history app for macOS. It lives in the menu bar and presents text and image history in a lightweight overlay that stays out of your way. Select an item to return to the previous app and paste it immediately.

> The screenshots below come from the current Release build and use synthetic sample data. They do not contain real clipboard records.

## Screenshots

### Timeline-based clipboard history

![粘易 timeline-based clipboard history](docs/release/screenshots/01-history-overview.png)

### Image details

![粘易 image history details](docs/release/screenshots/02-image-history.png)

### Settings and privacy controls

<table>
  <tr>
    <td width="50%"><img src="docs/release/screenshots/03-settings-controls.png" alt="粘易 general settings"></td>
    <td width="50%"><img src="docs/release/screenshots/04-local-privacy.png" alt="粘易 privacy settings"></td>
  </tr>
</table>

## Implemented Features

### Text and image history

- Automatically records text and common image formats, including PNG, TIFF, and JPEG
- Captures supported local image files copied from Finder and creates local thumbnails for previews
- Deduplicates content by hash while retaining the latest copy time and source application
- Stores history, images, and preferences locally on the current Mac by default

### Timeline, search, and filters

- Organizes history into **Just Now**, **Today**, and **Earlier**, with quick filters for recently used source apps
- Supports text search, text/image filters, time-range filters, and a favorites-only view
- Supports structured `app:`, `type:`, `fav:`, `before:`, and `after:` queries, with suggestions and removable filter tokens
- Ranks results using text relevance, fuzzy matching, recency, usage, favorites, and source application signals
- Includes long-text details, image previews, pagination, favorites, and per-item deletion

### Local content actions and OCR

- Classifies plain text, images, JSON, URLs, Base64, JWTs, timestamps, SQL, shell content, and OCR text, then presents actions suited to the current type
- Opens the action panel with `Command + K`, the type icon, or the More Actions menu
- Supports JSON formatting and validation, URL encoding and decoding, Base64 encoding and decoding, JWT field inspection, timestamp conversion, SQL formatting, shell argument quoting, and common text transformations
- Chains actions with editable results that can be copied, pasted directly, or saved as new derived history without overwriting the original record
- Runs image text recognition only when requested, using macOS Vision on the device; corrected and saved OCR text becomes searchable and available to content actions
- Decodes visible JWT fields and expiration state without verifying the signature or establishing trust

### Fast restore and paste

- Opens history with a customizable global shortcut; the default is `Command + Shift + V`
- Displays the history overlay above full-screen apps without switching to a standard window
- Restores and pastes an item into the previous app with one click, or with the arrow keys followed by `Enter`
- Supports clipboard-only restore plus favorite, paste, and delete actions from details or the More Actions menu
- Guides the user to grant Accessibility permission on first launch or when macOS blocks automatic paste

### Privacy and security controls

- Enables text and image recording independently, with an option to pause all recording
- Blocks the current foreground app in one click, or manages blocked apps by name and bundle identifier
- Enables sensitive-content filtering by default, skipping common password, token, identity, and payment-card patterns
- Allows filtering to be disabled under **Settings → Privacy**; the first disable request warns that sensitive text may be written to the local unencrypted SQLite history database. Re-enable the same switch at any time for immediate protection
- Never writes complete clipboard contents to application logs

### About and updates

- Shows the running app name, version, and build under **Settings → About & Updates**
- Uses Sparkle for automatic checks and the **Check for Updates…** button for manual checks; after a formally signed update is published, Sparkle verifies, installs, and relaunches the app
- Contacts a fixed GitHub Pages appcast and GitHub Releases update resources during update checks; clipboard history, images, content hashes, and preferences are never uploaded

### Storage and personalization

- Configures retention days, text/image count limits, per-image size limits, and a total storage cap
- Cleans up expired or excess records on startup and removes their local image files
- Clears text history separately or deletes all local history and image files at once
- Supports launch at login and showing or hiding the Dock icon
- Supports Follow System, Light, and Dark appearances with immediate updates
- Provides Simplified Chinese, Traditional Chinese, and English interfaces

## Requirements

- macOS 14.0 or later
- Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Automatic paste requires granting 粘易 access under **System Settings → Privacy & Security → Accessibility**

## Build Locally

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  build
```

## Run Tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  test
```

## Privacy

Clipboard history, images, and preferences stay on the device by default and are not uploaded to the cloud. Update checks request GitHub-hosted appcast, release-note, and update-package resources, but those requests do not contain clipboard history. The current release does not encrypt its local history database or app-managed image files; disabling sensitive-content filtering may store password- or token-like text in that database. Enable macOS account security and FileVault if you require device-level protection. See the [Privacy Policy](docs/privacy-policy.md) and [User Guide](docs/user-guide.md) for details.

## Documentation

- [Documentation Index](docs/README.md)
- [User Guide](docs/user-guide.md)
- [Architecture](docs/architecture/overall-architecture.md)
- [Database Schema](docs/database/schema.md)
- [Changelog](docs/changelog/CHANGELOG.md)
- [Release Preparation Guide](docs/release/RELEASE_PREP_GUIDE.md)
