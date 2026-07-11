## ADDED Requirements

### Requirement: Dock icon visibility applies at runtime
The system SHALL apply the persisted Dock icon visibility setting to the running macOS application activation policy.

#### Scenario: Enable Dock icon
- **WHEN** the user turns on "Show Dock icon"
- **THEN** the app MUST attempt to switch to a Dock-visible activation policy and persist the setting

#### Scenario: Disable Dock icon
- **WHEN** the user turns off "Show Dock icon"
- **THEN** the app MUST attempt to switch to a menu-bar/accessory activation policy and persist the setting

#### Scenario: Runtime application cannot complete
- **WHEN** macOS cannot apply the activation-policy change immediately
- **THEN** the app MUST keep the saved preference and show a clear restart-required message

### Requirement: App preferences load on launch
The system MUST apply persisted app-level preferences during startup before the user opens the settings window.

#### Scenario: Launch with hidden Dock icon preference
- **WHEN** the app launches with Dock icon visibility disabled
- **THEN** the app MUST run as a menu-bar/accessory application without requiring the user to reopen settings

#### Scenario: Launch with visible Dock icon preference
- **WHEN** the app launches with Dock icon visibility enabled
- **THEN** the app MUST use a Dock-visible activation policy as early as practical in the app lifecycle

### Requirement: Runtime preference behavior is tested
The system MUST include tests or manual QA evidence for persisted and runtime app-preference behavior.

#### Scenario: Preference verification
- **WHEN** QA verifies Dock icon visibility
- **THEN** the evidence MUST include setting persistence, launch behavior, and runtime toggle behavior
