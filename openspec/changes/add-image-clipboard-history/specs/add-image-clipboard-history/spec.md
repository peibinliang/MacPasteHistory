## ADDED Requirements

### Requirement: Image Clipboard Capture
The system SHALL detect and read PNG and TIFF image data from the macOS pasteboard.

#### Scenario: Copy screenshot
- **WHEN** the user copies a macOS screenshot image
- **THEN** the system records an image history item.

### Requirement: Image File Storage
The system SHALL store original images and thumbnails as local files and persist metadata in SQLite.

#### Scenario: Save image
- **WHEN** an accepted image is captured
- **THEN** the original image, thumbnail, file paths, dimensions, size, and format metadata are saved.

### Requirement: Image History Display
The system SHALL show image history records with thumbnails in the history list.

#### Scenario: View image history
- **WHEN** an image record exists
- **THEN** the history list displays a thumbnail preview for that image.

### Requirement: Image Restore
The system SHALL restore selected image history records to the system clipboard.

#### Scenario: Restore image
- **WHEN** the user selects an image history item for restore
- **THEN** the image is written to the system clipboard.

### Requirement: Image Cleanup And Controls
The system SHALL delete image files with their records and honor image recording controls.

#### Scenario: Delete image record
- **WHEN** the user deletes an image history item
- **THEN** the database record, original image file, and thumbnail file are removed.

#### Scenario: Disable image recording
- **WHEN** image recording is disabled
- **THEN** copied images are not saved to history.
