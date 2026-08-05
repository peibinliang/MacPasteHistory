# Database Schema

`clipboard.db` is local SQLite storage. Migration V3 extends `clipboard_history` with searchable/classification metadata, capture and usage counters, OCR data, and derived-record lineage.

| Group | Columns |
|---|---|
| Search/classification | `searchable_text`, `detected_type`, `user_override_type`, confidence, version and timestamp |
| Capture/usage | first/last capture, capture count, reuse/paste counts and timestamps |
| OCR | status, text, update timestamp and stable error code |
| Derived | origin ID, action ID/summary, source preview/hash and derived timestamp |

`derived_from_history_id` is a self-reference with `ON DELETE SET NULL`; its action summary remains after the origin is deleted. Capture events are separate rows that can be aggregated for display. The content hash deduplicates normalized values but is not encryption; the SQLite database and app-managed image files remain unencrypted at application level.
