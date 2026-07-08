## Why

All UI strings are currently hardcoded in English, including menu items, window titles, settings labels, alert messages, and relative time formatters. Users who prefer Simplified Chinese or Traditional Chinese cannot use the app in their native language. Adding multi-language support improves accessibility and broadens the app's reach.

## What Changes

- Extract all hardcoded user-facing strings into `Localizable.strings` catalogs for English (`en`), Simplified Chinese (`zh-Hans`), and Traditional Chinese (`zh-Hant`).
- Add a language preference in Settings that lets users override the system language; default to following the system locale.
- Localize all SwiftUI view strings, AppKit menu items, window titles, alert messages, error messages, and the relative-time formatter (`Today`, `Yesterday`).
- Localize Info.plist usage descriptions (`NSPasteboardAccessUsageDescription`, `NSAccessibilityUsageDescription`) and `CFBundleDisplayName`.
- Configure `CFBundleLocalizations` and `CFBundleDevelopmentRegion` in Info.plist, and register `knownRegions` in `project.yml` for XcodeGen.
- Add a `LanguageManager` service to persist the selected language and apply it at launch.

## Capabilities

### New Capabilities
- `app-localization`: Localized string catalogs, language preference management, and UI string extraction for three supported languages (English, Simplified Chinese, Traditional Chinese).

### Modified Capabilities

## Impact

- **Views**: `MainPanelView.swift` and `SettingsView.swift` — replace all hardcoded `Text`/`Label`/`Button`/`Section`/`TextField`/`alert` strings with `LocalizedStringKey` or `NSLocalizedString` calls.
- **App**: `AppDelegate.swift` — localize status menu items and window titles.
- **ViewModels**: `ClipboardHistoryViewModel.swift` and `SettingsViewModel.swift` — localize error messages.
- **Utils**: `HistoryDisplayFormatter.swift` — localize `Today`/`Yesterday` relative time labels.
- **Resources**: `Info.plist` — add `CFBundleLocalizations`, `CFBundleDevelopmentRegion`, and localized usage descriptions; create `.lproj` directories with `Localizable.strings`.
- **Build config**: `project.yml` — add `knownRegions` configuration.
- **Services**: New `LanguageManager` service for language preference persistence and application.
