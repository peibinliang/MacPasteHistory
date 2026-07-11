# app-localization Specification

## Purpose
TBD - created by archiving change add-multi-language-support. Update Purpose after archive.
## Requirements
### Requirement: Localized UI Strings
The system SHALL provide localized string catalogs for English (`en`), Simplified Chinese (`zh-Hans`), and Traditional Chinese (`zh-Hant`) covering all user-facing strings including view labels, menu items, window titles, button text, alert messages, error messages, and toast notifications.

#### Scenario: Display UI in English
- **WHEN** the app language is English
- **THEN** all UI strings appear in English.

#### Scenario: Display UI in Simplified Chinese
- **WHEN** the app language is set to Simplified Chinese
- **THEN** all UI strings appear in Simplified Chinese.

#### Scenario: Display UI in Traditional Chinese
- **WHEN** the app language is set to Traditional Chinese
- **THEN** all UI strings appear in Traditional Chinese.

#### Scenario: Fallback to English for missing key
- **WHEN** a translation key is missing in the selected language catalog
- **THEN** the system displays the English fallback string.

### Requirement: Language Preference
The system SHALL allow users to select their preferred language from Settings, with options for English, Simplified Chinese, Traditional Chinese, and "Follow System" (default).

#### Scenario: Follow system language
- **WHEN** the language preference is set to "Follow System"
- **THEN** the app uses the macOS system language, falling back to English if the system language is not supported.

#### Scenario: Override to a specific language
- **WHEN** the user selects a specific language in Settings
- **THEN** the app stores the preference and applies the `AppleLanguages` override for the next launch.

#### Scenario: Language preference persists across restarts
- **WHEN** the user restarts the app after selecting a language
- **THEN** the previously selected language remains in effect.

### Requirement: Language Change Restart Prompt
The system SHALL inform the user that a restart is required for the language change to take effect.

#### Scenario: User changes language
- **WHEN** the user selects a different language in Settings
- **THEN** the system displays a prompt advising the user to restart the app.

### Requirement: Info.plist Localization
The system SHALL localize the Info.plist usage descriptions (`NSPasteboardAccessUsageDescription`, `NSAccessibilityUsageDescription`) and the display name (`CFBundleDisplayName`) for all three supported languages.

#### Scenario: Localized usage description
- **WHEN** macOS requests pasteboard access permission in Simplified Chinese
- **THEN** the permission dialog displays the usage description in Simplified Chinese.

#### Scenario: Localized display name
- **WHEN** the app runs in Traditional Chinese
- **THEN** the app display name appears in Traditional Chinese.

### Requirement: Localized Date And Time Formatting
The system SHALL localize relative time labels (`Today`, `Yesterday`) and use locale-appropriate date/time formats in the history display.

#### Scenario: Display relative time in Chinese
- **WHEN** a clipboard item was copied today and the app language is Simplified Chinese
- **THEN** the timestamp label shows the Chinese equivalent of "Today" followed by the time.

#### Scenario: Display relative time in English
- **WHEN** a clipboard item was copied yesterday and the app language is English
- **THEN** the timestamp label shows "Yesterday" followed by the time.

### Requirement: Build Configuration For Localization
The system SHALL register `en`, `zh-Hans`, and `zh-Hant` as known localizations in the Xcode project and declare them in `CFBundleLocalizations` in Info.plist.

#### Scenario: XcodeGen generates project with localizations
- **WHEN** `xcodegen generate` is run
- **THEN** the generated project includes `knownRegions` for `en`, `zh-Hans`, and `zh-Hant`.

