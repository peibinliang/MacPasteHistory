## ADDED Requirements

### Requirement: User can filter history by time range
The system SHALL provide a history time-range filter that composes with existing search, content-type, and favorites filters.

#### Scenario: Select time range
- **WHEN** the user selects a time range filter
- **THEN** the history list MUST show only items whose creation time falls within that selected range

#### Scenario: Clear time range
- **WHEN** the user clears the time range filter
- **THEN** time range MUST no longer restrict the visible history list

### Requirement: User can filter history by source application
The system SHALL provide a source-application filter using stored source app metadata and bundle IDs when available.

#### Scenario: Select source application
- **WHEN** the user selects a source application filter
- **THEN** the history list MUST show only items captured from that source application or bundle ID

#### Scenario: Unknown source handling
- **WHEN** history items have no source application metadata
- **THEN** the UI MUST either include an "Unknown source" filter option or keep those items visible only under "All sources"

#### Scenario: Source filter updates after deletion
- **WHEN** history items are deleted or cleared
- **THEN** the available source filter options MUST update without leaving a selected filter in an invalid crashing state

### Requirement: Filters are query-backed and performant
The system MUST apply time and source filters through structured query state or repository filtering, avoiding unbounded UI-only filtering for large history sets.

#### Scenario: Compose filters
- **WHEN** search text, content type, favorites, time range, and source filters are combined
- **THEN** the resulting list MUST satisfy all active filter criteria consistently

#### Scenario: Filter performance
- **WHEN** the history database contains a large number of records
- **THEN** applying or clearing filters MUST keep the UI responsive enough for normal use
