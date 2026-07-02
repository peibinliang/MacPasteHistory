## Context

The first text list is functional but not enough for regular use. Long copied text must stay readable, users need to inspect full content, favorite useful items, and browse larger datasets without UI stalls.

## Goals / Non-Goals

**Goals:**
- Improve row layout and previews.
- Add full-detail viewing.
- Add favorite, unfavorite, and favorites-only browsing.
- Add basic content type filtering.
- Add relative time display and lazy loading.

**Non-Goals:**
- Image capture, advanced date/source filters, OCR search, tags, and cloud sync remain out of scope.

## Decisions

- Keep list rows compact with bounded multi-line previews so long text cannot expand the panel uncontrollably.
- Store favorites using the existing history record model via `is_favorite`.
- Implement filters as repository/query inputs rather than only in-memory UI filtering so later pagination remains efficient.
- Use lazy list loading or paginated repository access before the dataset grows large.

## Risks / Trade-offs

- Detail views can duplicate row actions -> keep restore, delete, and favorite behavior consistent across list and detail surfaces.
- Favorites must survive cleanup decisions -> later cleanup logic must preserve favorite records unless explicitly cleared.
- Lazy loading can complicate search and filters -> define a single query path that combines filter, search, and pagination parameters.
