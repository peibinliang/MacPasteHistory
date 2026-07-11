## ADDED Requirements

### Requirement: User can configure the global shortcut
The system SHALL allow the user to change the global shortcut used to open or focus the history panel.

#### Scenario: Save valid shortcut
- **WHEN** the user records a valid shortcut combination
- **THEN** the app MUST persist it, register it globally, and display the new shortcut in settings

#### Scenario: Restart with custom shortcut
- **WHEN** the app restarts after a custom shortcut was saved
- **THEN** the app MUST register the saved shortcut instead of the default Command + Shift + V

#### Scenario: Reset shortcut
- **WHEN** the user chooses reset-to-default
- **THEN** the app MUST restore Command + Shift + V and re-register that shortcut

### Requirement: Invalid shortcuts are rejected safely
The system MUST reject shortcut combinations that are empty, modifier-only, unsupported, or reserved for app/system behavior.

#### Scenario: Reject invalid shortcut
- **WHEN** the user attempts to save an invalid shortcut
- **THEN** the app MUST keep the last valid shortcut active and show a clear validation message

### Requirement: Shortcut registration conflicts are visible
The system MUST surface shortcut registration conflicts without crashing or losing the previous usable configuration.

#### Scenario: Conflict during registration
- **WHEN** the requested shortcut cannot be registered because another app or system service owns it
- **THEN** the app MUST show a conflict message and keep either the last registered shortcut or a clearly reported unregistered state

#### Scenario: Conflict resolved
- **WHEN** the user selects a shortcut that can be registered
- **THEN** the conflict message MUST disappear and the new shortcut MUST open or focus the history panel

### Requirement: Shortcut behavior is covered by tests
The system MUST include automated tests for shortcut persistence, validation, registration attempts, conflict state, and reset behavior.

#### Scenario: Shortcut regression test
- **WHEN** the shortcut test suite runs
- **THEN** it MUST verify the default shortcut, a custom shortcut, invalid input handling, and conflict reporting
