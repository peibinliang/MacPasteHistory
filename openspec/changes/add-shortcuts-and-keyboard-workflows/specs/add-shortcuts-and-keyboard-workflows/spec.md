## ADDED Requirements

### Requirement: Global Shortcut Activation
The system SHALL open the history panel from a global keyboard shortcut.

#### Scenario: Press default shortcut
- **WHEN** the user presses Command + Shift + V
- **THEN** the history panel opens.

### Requirement: Shortcut Conflict Handling
The system SHALL detect shortcut registration failures and inform the user without crashing.

#### Scenario: Shortcut conflict
- **WHEN** the configured shortcut cannot be registered
- **THEN** the system shows a conflict state and remains usable.

### Requirement: Keyboard Navigation
The system SHALL support keyboard navigation within the history panel.

#### Scenario: Navigate records
- **WHEN** the user presses up or down arrow keys
- **THEN** the selected history record changes.

### Requirement: Keyboard Restore And Close
The system SHALL restore the selected item with Enter and close the panel with Escape.

#### Scenario: Restore selected record
- **WHEN** the user presses Enter with a history record selected
- **THEN** the selected record is restored to the clipboard and feedback is shown.

#### Scenario: Close panel
- **WHEN** the user presses Escape
- **THEN** the history panel closes.
