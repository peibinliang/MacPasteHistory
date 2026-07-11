## Context

MacPasteHistory currently hardcodes all user-facing strings in English across SwiftUI views, AppKit menu items, window titles, alert messages, error messages, and relative-time labels. The app targets macOS 14+ with XcodeGen-managed project configuration. SwiftUI view initializers (`Text`, `Label`, `Button`, `Section`, `TextField`) accept `LocalizedStringKey` directly, but AppKit code (`NSMenuItem`, `NSWindow.title`) requires explicit `NSLocalizedString` calls. The project uses `Info.plist` with `GENERATE_INFOPLIST_FILE: NO`.

## Goals / Non-Goals

**Goals:**
- Provide full UI localization for English, Simplified Chinese, and Traditional Chinese.
- Let users override the system language from Settings; default to following the system locale.
- Localize Info.plist usage descriptions and display name.
- Keep the implementation idiomatic to Apple's standard localization toolchain.

**Non-Goals:**
- Right-to-left language support (not needed for the three target languages).
- Dynamic language switching without restart (macOS limitation; a restart is acceptable).
- Localization of clipboard content itself (only app UI is localized).
- Adding more languages beyond the initial three in this change.

## Decisions

- **Use `Localizable.strings` in `.lproj` directories** (not `.xcstrings` string catalogs). Traditional `.strings` + `.lproj` has the broadest XcodeGen compatibility and is well understood. One file per language: `en.lproj/Localizable.strings`, `zh-Hans.lproj/Localizable.strings`, `zh-Hant.lproj/Localizable.strings`.
- **Leverage SwiftUI's automatic `LocalizedStringKey` conformance.** String literals passed to `Text("...")`, `Label("...")`, `Button("...")`, `Section("...")`, `TextField("...")` are automatically treated as localized keys — no code change needed beyond ensuring the key exists in the catalog. This minimizes the diff in view files.
- **Use explicit `NSLocalizedString` for AppKit strings.** `NSMenuItem(title:)` and `NSWindow.title` take `String`, so they need `NSLocalizedString(key, comment:)` calls.
- **Language override via `AppleLanguages` UserDefaults key.** When the user selects a specific language, set `UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")`. When "follow system" is selected, remove the override. The change takes effect on next launch. A restart prompt is shown after the user changes the language.
- **Persist language preference in `UserDefaults`** via a new `LanguageManager` service. This service reads/writes the preference, applies the `AppleLanguages` override, and exposes the list of supported languages.
- **Use `InfoPlist.strings` files** in each `.lproj` directory to localize `NSPasteboardAccessUsageDescription`, `NSAccessibilityUsageDescription`, and `CFBundleDisplayName`.
- **Localize `HistoryDisplayFormatter`** relative-time labels (`Today`, `Yesterday`) using `NSLocalizedString`. Switch date formatters from fixed `en_US_POSIX` locale to the current locale for date/time formatting, while keeping `en_US_POSIX` only for fixed-format parsing if needed.
- **Use format strings for interpolated text.** For SwiftUI views, `LocalizedStringKey` interpolation handles parameters automatically (e.g., `Text("Keep history for \(days) days")`). For non-SwiftUI code, use `String(format: NSLocalizedString(key, comment:), args)`.
- **Register `knownRegions` in `project.yml`** as `["en", "zh-Hans", "zh-Hant"]` so XcodeGen includes the `.lproj` directories in the build.
- **Set `CFBundleDevelopmentRegion` to `en`** and `CFBundleLocalizations` to `["en", "zh-Hans", "zh-Hant"]` in Info.plist.

## Risks / Trade-offs

- [Language change requires restart] → Show a clear prompt informing the user to restart the app for the language change to take effect.
- [Missing translation keys cause English fallback] → English is the development region and serves as the fallback; verify all keys exist in all three catalogs during testing.
- [XcodeGen may not auto-discover `.lproj` directories] → Explicitly list resource paths in `project.yml` or verify that `knownRegions` registration includes them.
- [String interpolation differences between SwiftUI and AppKit] → Use `LocalizedStringKey` for SwiftUI and `String(format:)` for AppKit; document the pattern in code comments.
- [Date format locale change may break existing tests] → Update `HistoryDisplayFormatterTests` to account for locale-aware formatting.
