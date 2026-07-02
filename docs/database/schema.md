# Database Schema

## Current State

The app initializes a SQLite database file at:

```text
~/Library/Application Support/MacPasteHistory/clipboard.db
```

The database is migrated on startup by `MigrationManager`.

## Tables

### `schema_migrations`

Tracks applied database migrations.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `version` | INTEGER | Yes | None | Migration version primary key. |
| `name` | TEXT | Yes | None | Migration name. |
| `applied_at` | DATETIME | Yes | `CURRENT_TIMESTAMP` | Apply time. |

### `clipboard_history`

Stores local clipboard history records. The current implementation writes text records only.

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `id` | INTEGER | Yes | Auto increment | Primary key. |
| `content_type` | TEXT | Yes | None | Active values: `text`, `image`. |
| `text_content` | TEXT | No | `NULL` | Plain text clipboard content. |
| `file_path` | TEXT | No | `NULL` | Stored image file path for image history. |
| `thumbnail_path` | TEXT | No | `NULL` | Stored thumbnail file path for image history. |
| `source_app` | TEXT | No | `NULL` | Frontmost app name when available. |
| `source_bundle_id` | TEXT | No | `NULL` | Frontmost app bundle id when available. |
| `content_hash` | TEXT | Yes | None | SHA-256 hash for deduplication. |
| `text_length` | INTEGER | Yes | `0` | Sanitized text character count. |
| `file_size` | INTEGER | No | `NULL` | Stored image file size in bytes. |
| `image_width` | INTEGER | No | `NULL` | Stored image pixel width. |
| `image_height` | INTEGER | No | `NULL` | Stored image pixel height. |
| `image_format` | TEXT | No | `NULL` | Normalized stored image format, currently `png`. |
| `is_favorite` | INTEGER | Yes | `0` | Favorite flag used by favorites-only filtering. |
| `is_sensitive` | INTEGER | Yes | `0` | Sensitive flag for later privacy controls. |
| `created_at` | DATETIME | Yes | `CURRENT_TIMESTAMP` | Copy time and list sort key. |
| `updated_at` | DATETIME | Yes | `CURRENT_TIMESTAMP` | Last update time. |

## Indexes

| Index | Fields | Purpose |
| --- | --- | --- |
| `idx_clipboard_hash` | `content_hash` | Unique deduplication lookup. |
| `idx_clipboard_created_at` | `created_at` | Reverse chronological history list. |
| `idx_clipboard_content_type` | `content_type` | Type-specific queries and clear actions. |
| `idx_clipboard_favorite` | `is_favorite` | Favorites-only filtering. |
| `idx_clipboard_text_content` | `text_content` | Keyword search support. |

## Planned Tables

Later OpenSpec changes will add or activate:

- `blocked_apps`
- `app_settings`
