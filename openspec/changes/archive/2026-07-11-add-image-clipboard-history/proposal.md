## Why

The first version must preserve copied images as well as text because screenshots and browser images are common clipboard contents that users can accidentally overwrite. This phase adds local image capture, thumbnails, metadata, restore, cleanup, and settings integration.

## What Changes

- Detect PNG and TIFF image data in the pasteboard.
- Convert TIFF to PNG for consistent storage.
- Save original image files under a local images directory.
- Generate thumbnails for history list previews.
- Persist image metadata including width, height, size, paths, and hash.
- Display image history rows.
- Restore selected images back to the system clipboard.
- Delete local image files when deleting records.
- Add image dedupe and max-size handling.
- Respect the image recording setting.

## Capabilities

### New Capabilities
- `add-image-clipboard-history`: Image clipboard capture, file storage, thumbnail generation, metadata persistence, list display, restore, dedupe, cleanup, and image recording controls.

### Modified Capabilities

## Impact

- Affects pasteboard reading and writing, image conversion, filesystem storage, thumbnail generation, SQLite metadata, history UI, settings checks, and deletion cleanup.
