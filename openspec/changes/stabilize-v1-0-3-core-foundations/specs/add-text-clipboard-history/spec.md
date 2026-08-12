## MODIFIED Requirements

### Requirement: Text History Browsing And Search
The system SHALL display saved text history, immediately filter currently loaded items, cancel superseded asynchronous searches, and commit database-ranked results only for the latest user input.

#### Scenario: Search text history
- **WHEN** the user enters a keyword and the latest search completes
- **THEN** matching text history records are shown

#### Scenario: A newer query supersedes an older query
- **WHEN** an older asynchronous search completes after the user has entered a newer query
- **THEN** the older result is ignored and cannot replace the newer query state

#### Scenario: Search is pending
- **WHEN** a database search is waiting for debounce or results
- **THEN** the current results remain visible and the input stays responsive

#### Scenario: Search fails
- **WHEN** the latest database search fails
- **THEN** the current usable results remain available and a non-sensitive error state is reported
