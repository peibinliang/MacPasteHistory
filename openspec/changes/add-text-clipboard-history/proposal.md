## Why

Text history is the core value of the clipboard history app: users need copied text to remain available after later copy operations overwrite the system clipboard. This phase delivers automatic text capture, search, restore, delete, clear, and persistence.

## What Changes

- Monitor `NSPasteboard` changes by polling `changeCount`.
- Read plain text clipboard contents.
- Hash text content for deduplication.
- Create and use a `clipboard_history` table for text records.
- Save copied text with timestamp, content hash, and optional metadata.
- Display text history in reverse chronological order.
- Search text history by keyword.
- Restore selected text back to the system clipboard.
- Delete individual text records and clear text history.

## Capabilities

### New Capabilities
- `add-text-clipboard-history`: Text clipboard monitoring, deduplication, persistence, listing, searching, restore, delete, and clear behavior.

### Modified Capabilities

## Impact

- Affects clipboard monitoring services, pasteboard reading and writing, SQLite schema/repository code, history list UI, search state, and deletion flows.
