## Purpose

Give users control over whether the app synthesizes a paste command, while deferring macOS Accessibility authorization until the user explicitly opts in.

## ADDED Requirements

### Requirement: Automatic Paste Is Opt-In
The system SHALL keep Automatic Paste disabled by default for new and existing installations that have not explicitly saved this preference.

#### Scenario: First launch with no saved preference
- **WHEN** the app starts without a saved Automatic Paste preference
- **THEN** Automatic Paste is disabled and the app does not request, prompt for, or open settings for Accessibility access.

#### Scenario: Launch while automatic paste is disabled
- **WHEN** the app starts with Automatic Paste disabled
- **THEN** clipboard monitoring, history browsing, and clipboard restore remain available without an Accessibility reminder.

### Requirement: Authorization Is Deferred Until Enablement
The system SHALL begin the Accessibility authorization guidance only after the user turns on Automatic Paste.

#### Scenario: Enable without Accessibility access
- **WHEN** the user enables Automatic Paste and the app is not trusted for Accessibility
- **THEN** the preference remains enabled pending authorization and the app explains why access is needed with an action to open the relevant System Settings pane.

#### Scenario: Enable with existing Accessibility access
- **WHEN** the user enables Automatic Paste and the app is already trusted for Accessibility
- **THEN** the setting becomes ready without showing unnecessary authorization guidance.

#### Scenario: Disable automatic paste
- **WHEN** the user disables Automatic Paste
- **THEN** the app immediately stops dispatching synthetic paste commands and does not require the user to revoke the system permission.

### Requirement: Paste Behavior Respects The Setting
The system SHALL always restore selected content to the clipboard and SHALL dispatch a synthetic paste command only when Automatic Paste is enabled and Accessibility access is currently available.

#### Scenario: Use a history item while automatic paste is disabled
- **WHEN** the user activates a history item with Automatic Paste disabled
- **THEN** the content is restored to the clipboard, no synthetic keyboard event is sent, and the app communicates that the user can paste manually.

#### Scenario: Paste an action output while automatic paste is enabled
- **WHEN** the user chooses Paste for an action output while Automatic Paste is enabled and Accessibility access is available
- **THEN** the output is written to the clipboard and the app sends the paste command to the previously active application.

#### Scenario: Permission is missing or revoked
- **WHEN** an automatic paste is attempted while the setting is enabled but Accessibility access is unavailable
- **THEN** the content remains restored to the clipboard, no paste command is sent, and the app shows authorization guidance plus a manual-paste fallback.

### Requirement: Paste Accounting Reflects Actual Dispatch
The system SHALL count a successful paste only after the paste command is dispatched, while clipboard-only fallback SHALL be counted as a copy or restore rather than a paste.

#### Scenario: Automatic paste falls back to manual paste
- **WHEN** content is restored but the paste command is not dispatched because the setting is off or permission is unavailable
- **THEN** paste usage is not incremented and the clipboard restore remains successful.
