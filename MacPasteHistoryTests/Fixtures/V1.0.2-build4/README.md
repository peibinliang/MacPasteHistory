# V1.0.2 Build 4 Database Fixture

`v1-0-2-build4-clipboard.db` is an application-created, deterministic and desensitized upgrade fixture.

Provenance:

- Source tag: `V1.0.2`
- Source commit: `de646492a156d320fe45bf317128b1487e5e6d93`
- Bundle version/build: `1.0.2 (4)`
- Built architecture: `x86_64 arm64`
- Built executable SHA-256: `9880de69def6571dcd94d5a3a93db13b48949727d32be052a0e04143aed0cd8d`
- Fixture SHA-256: `f4bb3d0d099068e455d6caa935365474278350e4311931701120b94a8581c55a`
- SQLite migrations: V1, V2, V3 and V4
- SQLite journal mode: DELETE

Creation process:

1. Build the immutable `V1.0.2` tag as a Release application.
2. Launch that exact application with an isolated Application Support directory inside its sandbox container.
3. Copy a synthetic text sample from an untitled editor document so the V1.0.2 clipboard monitor creates the database, history row and capture event.
4. Stop the application before touching the database.
5. Replace all payload/source values and SQLite-codec timestamps with fixed synthetic values. Add one deterministic derived row, its capture event, and one deterministic token-usage row to exercise the existing V1.0.2 build 4 schema, then run `VACUUM`, `PRAGMA integrity_check` and `PRAGMA foreign_key_check`.

The database file and its original source history/capture row were created by the V1.0.2 build 4 application. The additional derived and token-usage rows were inserted deterministically after the application stopped; they are not represented as UI-generated evidence.

The fixture contains no user clipboard payload, OCR text, file paths, credentials or real application identity. Tests must copy it to a temporary location before opening it.
