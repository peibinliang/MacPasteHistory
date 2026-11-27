# Image Clipboard History

## Background

Image history records screenshots and copied image data alongside text history. Image binaries are stored as local files; SQLite stores paths and metadata so the database stays small.

## Flow

1. `ClipboardMonitor` detects a pasteboard change and skips internal restore changes.
2. `ClipboardReader` snapshots PNG, JPEG, TIFF, or Finder-style image file URLs on the main run loop and decodes/normalizes accepted image data to PNG via thread-safe `ImageIO` (`CGImageSource` / `CGImageDestination`).
3. `ImageStorageService` enforces the per-image size limit, creates `images/` and `thumbnails/`, writes the original PNG, and encodes a bounded thumbnail via `ImageIO` on the monitor's background capture queue.
4. `ClipboardHistoryRepository` persists image paths, dimensions, file size, format, hash, source app, and timestamps.
5. `MainPanelView` and `HistoryImagePreview` render row thumbnails and detail previews through `PreviewImageCache`, downsampling to target display dimensions and evicting cached entries when records are deleted or cleared.
6. `ClipboardHistoryViewModel` restores image records by reading the stored PNG and writing it back to `NSPasteboard`.
7. Deleting an image record removes both the database row and local original/thumbnail files.

## Storage

Image files live under:

```text
~/Library/Application Support/MacPasteHistory/images/
~/Library/Application Support/MacPasteHistory/thumbnails/
```

File names use the normalized PNG content hash, for example `<sha256>.png`. Duplicate images reuse the same history record by hash instead of creating repeated rows.

## Finder File Copies

Finder image copies are read from pasteboard file URLs. Supported file extensions are `png`, `jpg`, `jpeg`, `tif`, `tiff`, and `heic`; readable images are copied into app-managed storage as PNG data. Non-image file URLs are ignored and do not create history records.

## Controls

Image capture reads `RecordingSettingsProviding.shouldRecordImage`. The default provider maps to `DefaultSettings.shouldRecordImage`; later settings persistence can replace this provider without changing the capture pipeline.

## Testing

Automated tests cover PNG/TIFF reading, TIFF-to-PNG conversion, Finder image file URL reading, non-image file URL skipping, image size limits, original and thumbnail file creation, image metadata persistence, hash deduplication, image capture gating, image restore, and image file cleanup on delete.

Manual verification is still needed for browser-specific copied image representations and full running-app screenshot/browser restore workflows.
