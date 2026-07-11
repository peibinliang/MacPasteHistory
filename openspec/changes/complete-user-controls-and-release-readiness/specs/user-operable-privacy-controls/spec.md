## ADDED Requirements

### Requirement: User can pause and resume recording
The system SHALL provide a visible user control to pause and resume clipboard recording, and the capture pipeline MUST honor the persisted pause state for both text and image clipboard content.

#### Scenario: Pause recording from UI
- **WHEN** the user enables pause recording from the app UI
- **THEN** subsequent text and image clipboard changes MUST NOT be persisted to history

#### Scenario: Resume recording from UI
- **WHEN** the user disables pause recording from the app UI
- **THEN** subsequent supported clipboard changes MUST be eligible for normal persistence

#### Scenario: Pause state survives restart
- **WHEN** the app restarts after the user enabled pause recording
- **THEN** the UI MUST show recording as paused and the capture pipeline MUST continue skipping persistence

### Requirement: User can manage blocked applications
The system SHALL provide a visible blocked-application management UI that lets users view, add, enable or disable, and remove blocked applications by bundle ID with a human-readable app name when available.

#### Scenario: Add blocked application
- **WHEN** the user adds an application to the blocked-app list
- **THEN** the app MUST persist the bundle ID and display the application in the blocked-app UI

#### Scenario: Capture from blocked application
- **WHEN** clipboard content is copied from an enabled blocked application
- **THEN** the system MUST skip saving that content without logging the clipboard payload

#### Scenario: Disabled blocked application entry
- **WHEN** a blocked application entry is disabled
- **THEN** clipboard content from that application MUST be eligible for normal capture

#### Scenario: Remove blocked application
- **WHEN** the user removes an application from the blocked-app list
- **THEN** clipboard content from that application MUST no longer be skipped because of that removed entry

### Requirement: Privacy controls are verifiable
The system MUST include automated or documented QA coverage proving pause recording and blocked-app controls affect the actual capture chain, not only the UI state.

#### Scenario: Capture-chain verification
- **WHEN** release or regression verification runs privacy-control checks
- **THEN** the evidence MUST show both UI/persistence state and capture-skip behavior for pause and blocked apps
