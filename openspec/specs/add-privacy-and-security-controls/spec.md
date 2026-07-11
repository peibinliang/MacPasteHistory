# add-privacy-and-security-controls Specification

## Purpose
TBD - created by archiving change add-privacy-and-security-controls. Update Purpose after archive.
## Requirements
### Requirement: First Launch Privacy Notice
The system SHALL show a first-launch privacy notice explaining that clipboard history is stored locally.

#### Scenario: First launch
- **WHEN** the user opens the app for the first time
- **THEN** the privacy notice is shown before regular use.

### Requirement: Sensitive Content Filtering
The system SHALL detect sensitive text and prevent it from being saved by default.

#### Scenario: Copy token
- **WHEN** copied text matches sensitive token, password, verification code, ID, or bank-card rules
- **THEN** the content is not saved to history.

### Requirement: Pause Recording
The system SHALL allow users to temporarily pause clipboard recording.

#### Scenario: Pause enabled
- **WHEN** recording is paused
- **THEN** copied text and images are not saved to history.

### Requirement: Blocked Apps
The system SHALL allow users to configure blocked apps and skip clipboard saves from those apps.

#### Scenario: Copy from blocked app
- **WHEN** the foreground source app is enabled in the blocked-app list
- **THEN** copied content from that app is not saved.

### Requirement: Privacy Documentation And Cleanup
The system SHALL include privacy documentation and cleanup behavior for expired history.

#### Scenario: Cleanup old data
- **WHEN** history exceeds the configured retention period
- **THEN** expired non-protected records are removed by cleanup logic.

