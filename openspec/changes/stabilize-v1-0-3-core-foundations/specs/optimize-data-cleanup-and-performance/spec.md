## ADDED Requirements

### Requirement: Evidence-Based SQLite Concurrency Mode
The system SHALL verify concurrent clipboard writes and search reads, busy handling, transaction boundaries, and checkpoint behavior before changing the released SQLite journal mode.

#### Scenario: Concurrent capture and search
- **WHEN** a clipboard write and read-only search overlap under the selected database configuration
- **THEN** both operations complete with consistent data or a bounded, recoverable busy outcome

#### Scenario: WAL does not pass the evidence gate
- **WHEN** WAL evaluation reveals migration, consistency, checkpoint, or recovery regressions
- **THEN** the released configuration retains the safer existing journal mode

#### Scenario: WAL passes the evidence gate
- **WHEN** repeatable tests demonstrate that WAL improves concurrency without data loss or upgrade regressions
- **THEN** WAL may be enabled with explicit busy timeout, checkpoint, and transaction behavior documented

### Requirement: Existing Databases Remain Upgrade Safe
The system SHALL open existing V1.0.2 databases without destructive reset when applying any accepted SQLite configuration change.

#### Scenario: Open an existing database
- **WHEN** V1.0.3 starts with a valid V1.0.2 database
- **THEN** existing history remains readable and new captures can be committed after configuration is applied
