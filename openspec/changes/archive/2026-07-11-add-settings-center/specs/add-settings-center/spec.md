## ADDED Requirements

### Requirement: Settings Persistence
The system SHALL persist settings changes and apply them after app restart.

#### Scenario: Restart after setting change
- **WHEN** the user changes a setting and restarts the app
- **THEN** the setting remains in effect.

### Requirement: Recording Toggles
The system SHALL allow users to enable or disable text and image recording.

#### Scenario: Disable text recording
- **WHEN** text recording is disabled
- **THEN** copied text is not saved to history.

#### Scenario: Disable image recording
- **WHEN** image recording is disabled
- **THEN** copied images are not saved to history.

### Requirement: App Behavior Settings
The system SHALL allow users to configure startup behavior and Dock icon visibility.

#### Scenario: Configure startup
- **WHEN** the user changes the startup setting
- **THEN** the app applies the configured launch behavior.

### Requirement: Retention And Storage Limits
The system SHALL allow users to configure history retention, record limits, image size limits, and total storage limits.

#### Scenario: Save retention settings
- **WHEN** the user updates retention or storage limit values
- **THEN** the values are saved for cleanup and capture logic.

### Requirement: Clear All Data
The system SHALL allow users to clear all local history data.

#### Scenario: Clear data
- **WHEN** the user confirms clear-all
- **THEN** database history and local image files are removed.
