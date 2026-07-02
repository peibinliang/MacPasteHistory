## Context

After the app shell exists, the first real history workflow is text. The implementation needs to detect clipboard changes, filter duplicate content, persist records locally, and let users find and restore previous text.

## Goals / Non-Goals

**Goals:**
- Poll `NSPasteboard.changeCount` and read plain text changes.
- Store text records in SQLite with hash-based deduplication.
- Show a persisted history list after restart.
- Support keyword search, restore to clipboard, single delete, and clear text history.

**Non-Goals:**
- Rich text preservation, automatic paste into the active app, image history, advanced filters, and privacy filtering are handled by separate changes.

## Decisions

- Use `NSPasteboard.changeCount` polling rather than accessibility-driven capture because the first version should minimize permissions.
- Store text content in SQLite and use `content_hash` for dedupe so duplicate detection is deterministic.
- Treat restore as writing the selected record back to the clipboard; the user performs manual paste with Cmd+V.
- Keep source app capture as optional P1 metadata so P0 text history can work without blocking on foreground app detection.

## Risks / Trade-offs

- Polling too frequently can waste CPU -> start with a conservative interval and leave tuning for the performance phase.
- Large text snippets can slow rendering -> truncate previews in rows and reserve full content for detail views in a later phase.
- Hash-only dedupe can hide repeated intentional copies -> update timestamp or move the existing record to the top when duplicate behavior is implemented.
