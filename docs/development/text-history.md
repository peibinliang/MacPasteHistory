# Text Clipboard History

## Background

Text history is the first user-facing clipboard workflow. It records accepted plain text locally so users can recover older copied content after the system clipboard changes.

## Goals

- Detect `NSPasteboard.general.changeCount` changes at the configured polling interval.
- Read plain text only, skip empty or whitespace-only content, and sanitize control characters.
- Store text records in SQLite through `ClipboardHistoryRepository`.
- Deduplicate text by normalized SHA-256 content hash.
- Display, search, restore, double-click paste, delete, and clear text history in the main panel.

## Flow

1. `AppDelegate` initializes Application Support directories, opens SQLite, runs migrations, and starts `ClipboardMonitor`.
2. `ClipboardMonitor` compares the current pasteboard `changeCount` with the last processed value.
3. Internal restore changes are skipped through `ClipboardRestorationState`.
4. The monitor captures one immutable source-application and timestamp context for the pasteboard change.
5. Pause and blocked-app privacy checks use that captured context before content is read.
6. `ClipboardReader` reads sanitized plain text and sensitive filtering decides whether it may be persisted.
7. `ClipboardHistoryRepository` saves or updates the text record and capture event with the same source context.
8. `ClipboardHistoryViewModel` reloads the list after save, search, delete, or clear.

## Modules

| Module | Responsibility |
| --- | --- |
| `ClipboardMonitor` | Polls pasteboard changes and coordinates text capture. |
| `ClipboardCaptureContext` | Holds one immutable source application and capture time for a pasteboard change. |
| `ClipboardReader` | Reads sanitized plain text from a pasteboard. |
| `ClipboardWriter` | Restores selected text to the system clipboard. |
| `PasteCommandService` | Sends Command+V after a successful double-click restore. |
| `ClipboardHistoryRepository` | Performs SQLite CRUD with bound parameters. |
| `ClipboardHistoryViewModel` | Manages main panel history state and user actions. |
| `MainPanelView` | Displays search, text previews, time, restore, delete, and clear actions. |

## Data

Text records are stored in `clipboard_history` with `content_type = text`, `text_content`, `content_hash`, `text_length`, optional source app fields, timestamps, and favorite/sensitive flags.

Duplicate text does not create a second row. The existing row keeps its original creation time, increments `capture_count`, updates `last_captured_at`, and receives a capture event. The history row and its event use the same source metadata and capture timestamp from the monitor context.

## Privacy And Security

Clipboard content remains local in `~/Library/Application Support/MacPasteHistory/clipboard.db`. Logs record only text length and operational status, never full clipboard content. Pause, blocked-app and sensitive-content checks run before persistence. A foreground-app change after capture begins cannot replace the source snapshot used by the blocked-app decision or saved metadata.

macOS pasteboard data does not identify the process that placed content on the pasteboard. The source snapshot is therefore the foreground app observed when the 0.5-second polling loop detects the change. If the user switches apps before that observation, source attribution and blocked-app filtering are best-effort rather than an absolute security boundary; the project does not use keyboard interception to infer copy events.

## Testing

Automated tests cover:

- text hash normalization and uniqueness
- plain text reading and whitespace skipping
- monitor change detection, no-change skipping, single source-provider resolution, foreground-app race handling, unknown source metadata, and restore skipping
- SQLite save, dedupe, capture-event source/time consistency, search, delete, and text length metadata
- clipboard restore guard state
- restore success/failure reporting and paste command dispatch

Manual verification still needs to cover visible menu bar behavior, copying from real apps, restart persistence, using restore from the main panel, and double-click paste after Accessibility permission is granted.
