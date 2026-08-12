## Purpose

持续校验 SQLite 图片历史与应用管理文件之间的一致性，并以保守、可恢复的策略处理异常退出或磁盘故障留下的漂移。

## ADDED Requirements

### Requirement: Storage Drift Is Classified Before Repair
The system SHALL identify records with missing originals, orphaned managed files, missing thumbnails, corrupted images, and stale temporary files without treating uncertain files as safe to delete.

#### Scenario: Database record references a missing original
- **WHEN** reconciliation finds an image history record whose original file is absent
- **THEN** the record is retained, the issue is reported, and image presentation exposes an unavailable state instead of crashing or presenting a healthy preview

#### Scenario: Managed file has no database record
- **WHEN** reconciliation finds a file in an app-managed image directory with no matching history record
- **THEN** the file is classified as orphaned, retained automatically, and included in the non-sensitive reconciliation summary

#### Scenario: Referenced image is corrupted
- **WHEN** a referenced original image cannot be decoded
- **THEN** the database record and original file are retained, the item is reported as unavailable, and no automatic destructive repair is attempted

### Requirement: Missing Thumbnails Can Be Rebuilt
The system SHALL regenerate a missing thumbnail when the corresponding original image is present, readable, and still referenced by a valid history record.

#### Scenario: Original exists but thumbnail is missing
- **WHEN** reconciliation can safely read a valid original image whose thumbnail is absent
- **THEN** a replacement thumbnail is generated and the record remains usable

### Requirement: Reconciliation Is Conservative And Idempotent
The system SHALL prefer retaining uncertain user data, SHALL restrict mutations to app-managed storage, and SHALL produce the same healthy state when run repeatedly.

#### Scenario: File ownership is uncertain
- **WHEN** a candidate file cannot be proven to belong to MacPasteHistory managed storage
- **THEN** reconciliation leaves the file untouched and reports the unresolved condition

#### Scenario: Run reconciliation twice
- **WHEN** reconciliation completes successfully and runs again without intervening storage changes
- **THEN** the second run performs no additional destructive mutation

#### Scenario: Stale app temporary file
- **WHEN** a file is inside the canonical app-managed temporary directory, matches the app-owned temporary naming contract, is unreferenced, and is older than the documented 24-hour safety window
- **THEN** reconciliation may remove that temporary file and records only non-sensitive summary metadata

#### Scenario: Temporary file is recent or provenance is incomplete
- **WHEN** a temporary candidate is no older than 24 hours or any ownership condition cannot be proven
- **THEN** reconciliation retains the file and reports no destructive repair

### Requirement: Reconciliation Failures Preserve App Availability
The system SHALL isolate per-item reconciliation failures and provide non-sensitive summary diagnostics without preventing the app from opening history.

#### Scenario: One image is unreadable
- **WHEN** one managed image cannot be decoded during reconciliation
- **THEN** other items are still checked and the failure summary does not contain clipboard content
