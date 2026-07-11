## Context

Clipboard history can accumulate quickly, especially with images. Performance and cleanup should be explicit so the app remains lightweight during long-running use.

## Goals / Non-Goals

**Goals:**
- Enforce retention, count, and storage limits.
- Add database indexes for common queries.
- Page history results and optimize thumbnail loading.
- Tune polling frequency to reduce CPU use.
- Verify long-running stability.

**Non-Goals:**
- Cloud archival, export, OCR indexing, and database encryption are out of scope.

## Decisions

- Run cleanup on startup and through a cleanup service that can be reused later for scheduled cleanup.
- Preserve favorite records during automatic cleanup unless the user explicitly clears all data.
- Add indexes matching common access patterns: created time, content type, hash, and favorite.
- Use paginated repository methods so UI does not fetch all records at once.
- Cache or precompute thumbnails so scrolling image-heavy lists does not decode originals repeatedly.

## Risks / Trade-offs

- Cleanup can delete data users expected to keep -> make limits configurable and preserve favorites by default.
- Indexes improve reads but add write overhead -> keep indexes limited to documented query paths.
- Polling interval changes affect responsiveness -> test CPU use and perceived delay with a balanced default.
