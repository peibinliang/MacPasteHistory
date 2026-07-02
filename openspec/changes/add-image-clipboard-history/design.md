## Context

Image history requires different storage from text. Original images and thumbnails should live as files, while SQLite stores metadata and paths. The first version must support screenshots and common copied image formats.

## Goals / Non-Goals

**Goals:**
- Read PNG and TIFF pasteboard image data.
- Normalize stored images to PNG where needed.
- Store image files and thumbnails locally.
- Persist image metadata and display image rows.
- Restore selected images to the system clipboard.
- Remove local files when records are deleted.
- Respect image recording and size settings.

**Non-Goals:**
- OCR search, cloud sync, advanced image editing, and automatic paste are out of scope.

## Decisions

- Store image binaries on disk rather than in SQLite so the database remains small and queryable.
- Store file paths, thumbnail paths, dimensions, file size, and hash in `clipboard_history`.
- Generate thumbnails at capture time so list rendering does not repeatedly decode large images.
- Convert TIFF to PNG for consistent persistence and restore behavior.
- Delete image and thumbnail files in the same record deletion flow to avoid orphaned data.

## Risks / Trade-offs

- Large images can consume disk quickly -> enforce per-image limits and leave aggregate cleanup for the performance phase.
- File deletion can fail independently of database deletion -> log failures and keep cleanup idempotent.
- Pasteboard image representations vary by source app -> support PNG and TIFF first, then add Finder file-copy handling as P1.
