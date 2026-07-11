## ADDED Requirements

### Requirement: App Launch
The system SHALL launch as a macOS SwiftUI application with configured name, icon, and basic app metadata.

#### Scenario: Launch app
- **WHEN** the user starts the app
- **THEN** the app launches without crashing and presents its configured identity.

### Requirement: Menu Bar Entry
The system SHALL show a persistent menu bar item for opening the app.

#### Scenario: Show menu bar icon
- **WHEN** the app is running
- **THEN** a menu bar icon is visible in the macOS menu bar.

### Requirement: Main And Settings Windows
The system SHALL provide entry points for opening the main history panel and settings window.

#### Scenario: Open windows
- **WHEN** the user clicks the menu bar item or settings entry
- **THEN** the corresponding app window opens.

### Requirement: Local Storage Foundation
The system SHALL create an Application Support data directory and initialize a SQLite database.

#### Scenario: Initialize storage
- **WHEN** the app starts for the first time
- **THEN** the data directory exists and the SQLite database can be opened.

### Requirement: Shared Utilities
The system SHALL provide logging and basic persisted settings utilities for later features.

#### Scenario: Persist setting
- **WHEN** a basic setting is saved
- **THEN** the setting can be read again after app restart.
