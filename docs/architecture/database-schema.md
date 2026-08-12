# Database Schema

`clipboard.db` is local SQLite storage. Migration V3 extends `clipboard_history` with searchable/classification metadata, capture and usage counters, OCR data, and derived-record lineage. Migration V4 adds `ai_token_usage` for provider-reported accounting metadata.

| Group | Columns |
|---|---|
| Search/classification | `searchable_text`, `detected_type`, `user_override_type`, confidence, version and timestamp |
| Capture/usage | first/last capture, capture count, reuse/paste counts and timestamps |
| OCR | status, text, update timestamp and stable error code |
| Derived | origin ID, action ID/summary, source preview/hash and derived timestamp |

`derived_from_history_id` is a self-reference with `ON DELETE SET NULL`; its action summary remains after the origin is deleted. Capture events are separate rows that can be aggregated for display. The content hash deduplicates normalized values but is not encryption; the SQLite database and app-managed image files remain unencrypted at application level.

`ai_token_usage` stores a unique provider request ID, provider/model identifiers, non-negative input/output/total token counts, optional cached-input tokens, and insertion time. Model/time indexes support settings summaries. It deliberately has no history reference and stores no prompt, source text, response text, or API key. Clear All Data deletes these rows; the separately managed local AI credential file requires explicit removal.

## Image storage reconciliation

Image rows retain absolute original and thumbnail paths for compatibility. Startup reconciliation treats those database values as untrusted: both paths must resolve inside their canonical managed roots before any repair is planned. Missing and corrupted originals, ordinary orphan files, symlinks, and paths with uncertain ownership are retained and summarized. A valid referenced original may regenerate only its missing managed thumbnail. The dedicated `temporary` directory uses the `mph-image-*.tmp` ownership contract; only unreferenced regular files older than 24 hours may be deleted. Reconciliation does not change schema or migration history.

V1.0.3 retains SQLite's default `DELETE` journal mode with a 1,000 ms busy timeout and `BEGIN IMMEDIATE` write ownership. A deterministic matrix proved committed-snapshot search reads during an open capture write, bounded competing-writer failure, rollback, reopen, and clean sidecar shutdown. The same WAL experiment passed data-correctness and busy bounds but retained `-wal` and `-shm` sidecars after the tested close/reopen lifecycle, so WAL and checkpoint policy were not enabled. Existing V1–V4 migrations remain immutable. New application-written timestamps use fixed-width fractional seconds while the reader accepts both fractional and legacy second-only values.
