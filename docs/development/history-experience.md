# History Experience

## Background

This phase improves browsing and inspecting saved clipboard history after text capture is available. It does not add image capture; image is only exposed as a filter value because the schema already supports content types.

## User Flow

1. `ClipboardHistoryViewModel` loads the first page through `ClipboardHistoryRepository`.
2. Search text, favorites-only state, and content type filter are converted into a single `HistoryQuery`.
3. `MainPanelView` renders a compact row with metadata, bounded preview text, and row actions.
4. Selecting a row opens `HistoryDetailView` with full text and available metadata.
5. Scrolling to the last loaded row calls `loadMoreIfNeeded(currentItem:)` to request the next page.

## Overlay Presentation

The history surface is hosted in `HistoryPanelWindow`, a nonactivating `NSPanel` positioned at the top center of the screen containing the pointer. The panel uses a translucent rounded background and behaves like a temporary system overlay instead of a document window.

- `.canJoinAllSpaces` and `.fullScreenAuxiliary` allow it to appear over the current fullscreen Space.
- `.nonactivatingPanel` avoids activating the app as a normal window and prevents an unwanted Space switch.
- `.popUpMenu` keeps the panel above the fullscreen application while it is visible.
- Escape, double-click paste, clicking outside the panel, or selecting a paste target closes the overlay.
- The settings surface remains a standard titled window because it is a persistent editing workflow rather than a quick overlay.

## Modules

| Module | Responsibility |
| --- | --- |
| `HistoryQuery` | Carries keyword, favorite, content type, limit, and offset query inputs. |
| `HistoryDisplayFormatter` | Formats bounded previews and today/yesterday/exact timestamps. |
| `ClipboardHistoryRepository` | Applies search, favorite, type, and pagination filters with bound SQL parameters. |
| `ClipboardHistoryViewModel` | Owns filter state, favorite updates, refreshes, and incremental loading. |
| `MainPanelView` | Presents filters, rows, actions, and the detail sheet. |
| `HistoryPanelWindow` | Configures fullscreen-safe overlay behavior, active-screen positioning, and automatic dismissal. |

## Behavior

- Long text previews are limited to three lines and a bounded character count.
- Today and yesterday records show a short friendly label; older records show an exact date and time.
- Favorite and unfavorite update `is_favorite` through the repository and refresh the current query.
- Favorites-only and content type filters are executed at query time so pagination stays consistent.
- Detail view shows full text, type, created time, text length, source app, and bundle id when available.
- Restore, delete, and favorite actions are available from both row and detail surfaces.

## Testing

Automated tests cover preview truncation, date display, repository favorite persistence, content type filtering, pagination, ViewModel filter/loading behavior, overlay window flags, window level, and top-center positioning.

Manual verification is still needed for visual smoothness with a large real dataset, final row/detail interaction polish, and invocation over native and third-party fullscreen applications.
