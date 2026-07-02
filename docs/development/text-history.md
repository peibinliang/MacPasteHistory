# Text Clipboard History

## Background

Text history is the first user-facing clipboard workflow. It records accepted plain text locally so users can recover older copied content after the system clipboard changes.

## Goals

- Detect `NSPasteboard.general.changeCount` changes at the configured polling interval.
- Read plain text only, skip empty or whitespace-only content, and sanitize control characters.
- Store text records in SQLite through `ClipboardHistoryRepository`.
- Deduplicate text by normalized SHA-256 content hash.
- Display, search, restore, delete, and clear text history in the main panel.

## Flow

1. `AppDelegate` initializes Application Support directories, opens SQLite, runs migrations, and starts `ClipboardMonitor`.
2. `ClipboardMonitor` compares the current pasteboard `changeCount` with the last processed value.
3. Internal restore changes are skipped through `ClipboardRestorationState`.
4. `ClipboardReader` reads sanitized plain text.
5. `ClipboardHistoryRepository` saves or updates the text record.
6. `ClipboardHistoryViewModel` reloads the list after save, search, delete, or clear.

## Modules

| Module | Responsibility |
| --- | --- |
| `ClipboardMonitor` | Polls pasteboard changes and coordinates text capture. |
| `ClipboardReader` | Reads sanitized plain text from a pasteboard. |
| `ClipboardWriter` | Restores selected text to the system clipboard. |
| `ClipboardHistoryRepository` | Performs SQLite CRUD with bound parameters. |
| `ClipboardHistoryViewModel` | Manages main panel history state and user actions. |
| `MainPanelView` | Displays search, text previews, time, restore, delete, and clear actions. |

## Data

Text records are stored in `clipboard_history` with `content_type = text`, `text_content`, `content_hash`, `text_length`, optional source app fields, timestamps, and favorite/sensitive flags.

Duplicate text does not create a second row. The existing row is moved to the top by updating `created_at` and `updated_at`.

## Privacy And Security

Clipboard content remains local in `~/Library/Application Support/MacPasteHistory/clipboard.db`. Logs record only text length and operational status, never full clipboard content. Sensitive filtering and blocked-app behavior are planned in the privacy change.

## Testing

Automated tests cover:

- text hash normalization and uniqueness
- plain text reading and whitespace skipping
- monitor change detection, no-change skipping, source metadata, and restore skipping
- SQLite save, dedupe, search, delete, and text length metadata
- clipboard restore guard state

Manual verification still needs to cover visible menu bar behavior, copying from real apps, restart persistence, and using restore from the main panel.
