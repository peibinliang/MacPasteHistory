## ADDED Requirements

### Requirement: Automatic Cleanup
The system SHALL clean expired records and enforce configured record and storage limits.

#### Scenario: Startup cleanup
- **WHEN** the app starts and expired history exists
- **THEN** expired non-protected records are removed.

### Requirement: Bounded Image Storage
The system SHALL remove image files when configured storage limits are exceeded.

#### Scenario: Image storage cap exceeded
- **WHEN** image storage exceeds the configured cap
- **THEN** old eligible image records and files are removed until storage is within the limit.

### Requirement: Indexed Queries
The system SHALL maintain indexes for common history queries.

#### Scenario: Search and list records
- **WHEN** the app lists or searches history records
- **THEN** indexed columns support efficient query execution.

### Requirement: Paginated Loading
The system SHALL load history records in pages for large datasets.

#### Scenario: Load many records
- **WHEN** history contains many text or image records
- **THEN** the UI loads records incrementally without freezing.

### Requirement: Long-Running Efficiency
The system SHALL keep CPU and memory usage low during long-running monitoring.

#### Scenario: App runs for hours
- **WHEN** the app runs continuously
- **THEN** monitoring remains stable without unbounded memory growth or excessive CPU use.
