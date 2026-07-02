# Database Schema

## Current State

The app initializes a SQLite database file at:

```text
~/Library/Application Support/MacPasteHistory/clipboard.db
```

No application tables are created yet. The current phase only verifies that SQLite can open or create the database file.

## Planned Tables

The planned schema is defined in the product requirements and OpenSpec changes:

- `clipboard_history`
- `blocked_apps`
- `app_settings`

Future table creation must be implemented through a migration layer and documented here with field definitions, indexes, and compatibility notes.
