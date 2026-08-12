# Overall Architecture

粘易 is a local-first macOS menu-bar clipboard history app. The app process owns all writes; asynchronous search uses a separate read-only SQLite connection so typing does not contend with clipboard capture.

```mermaid
flowchart LR
    PB[NSPasteboard] --> MON[ClipboardMonitor]
    MON --> REP[ClipboardHistoryRepository]
    REP --> DB[(SQLite + image files)]
    DB --> SEARCH[Read-only SearchCandidateProvider]
    DB --> RECON[Read-only Storage Reconciliation]
    SEARCH --> VM[ClipboardHistoryViewModel]
    VM --> PANEL[History panel]
    PANEL --> ACTION[Content action session]
    ACTION --> REP
    ACTION -->|explicit AI polishing / translation| AI[DeepSeek HTTPS]
    AI --> TOKEN[(Token usage only)]
    ACTION --> KEY[Owner-only local AI credential file]
    PANEL --> OCR[Manual Vision OCR]
    OCR --> REP
```

## Module boundaries

| Module | Responsibility |
|---|---|
| `App` | App lifecycle, status item and fullscreen-safe `HistoryPanelWindow`. |
| `Clipboard` | Pasteboard observation, capture filtering, writes and restoration suppression. |
| `Database` | Schema migration, transactional writes, local history metadata and capture events. |
| `Search` | Parse structured input, merge controls, issue read-only candidate queries and rank results. |
| `ContentActions` | Classification, deterministic local transforms, session history and syntax tokens. |
| `Services` | Automatic-paste policy, local AI credential boundary, and explicit DeepSeek text-processing client. |
| `OCR` | Explicit user-triggered Vision request for one managed image at a time. |
| `Services` | Shared application services, including the testable Sparkle update boundary. |
| `ViewModels` / `Views` | Main-actor state and SwiftUI/AppKit presentation. |

## Data and concurrency

`DatabaseInitializer` opens the writer connection. `SearchCandidateProvider` is an actor that opens, uses and closes a read-only connection per request. SQLite remains in default `DELETE` journal mode with a 1,000 ms busy timeout and `BEGIN IMMEDIATE` write transactions; WAL was tested with the same correctness matrix but rejected for V1.0.3 because its sidecars remained after the tested shutdown lifecycle. After synchronous retention cleanup, startup dispatches storage reconciliation to a utility queue with its own read-only SQLite connection, so history opening and clipboard monitoring do not wait for image decoding. Reconciliation inventories canonical `images`, `thumbnails`, and `temporary` roots, reports drift using counts, retains ordinary orphaned or uncertain files, and mutates only a safely referenced missing thumbnail or an unreferenced `mph-image-*.tmp` file older than 24 hours. Clipboard capture, search, deterministic actions, OCR, and reconciliation remain local. The sole network path is an explicitly selected AI polishing or translation action: after first-use disclosure, the current action text is sent over HTTPS to DeepSeek. The API key is stored in an owner-only plaintext file under Application Support instead of the default Keychain runtime path, trading weaker at-rest protection for no Keychain access after relaunch. SQLite stores provider/model/token counts only, never prompts, source text, responses, or credentials.

Automatic paste is controlled by a persisted default-off preference and live Accessibility trust. `PasteCoordinator` is the single MainActor orchestration boundary for history items and content-action output: it writes the clipboard, evaluates the shared policy, prepares the panel for dispatch, activates the captured target app, waits for focus transfer, sends `Command-V`, and records exactly one paste or reuse outcome. The policy returns clipboard-only, permission-required, or ready; every path writes the clipboard first, while only ready may activate and dispatch. Cancellation and target/command failure keep a typed clipboard-available fallback instead of retrying or double-counting.

## Search, action and OCR lifecycle

`ClipboardHistoryViewModel` remains the stable SwiftUI-facing MainActor facade. Focused collaborators own ordinary/ranked pagination (`HistoryListCoordinator`), retained Task plus request ownership (`SearchTaskLifecycle`), and derived-item selection (`HistorySelectionState`) behind narrow injectable protocols. A list reload invalidates the active search before fetching, and the search Task captures the ViewModel weakly so replacing or closing a panel releases the old facade and cancels its work. Views continue to call the facade and do not access SQLite or paste accounting directly.

```mermaid
sequenceDiagram
    participant U as User
    participant S as SearchCoordinator
    participant R as Read-only SQLite
    participant A as ActionSession
    participant W as Writer SQLite
    U->>S: structured query
    S->>R: candidates + filters
    R-->>S: history items
    U->>A: execute local transform
    A-->>U: editable output
    U->>W: copy, paste, save derived, or save OCR
```

`ActionSession` retains only the active transformation branch. Copy increments reuse count; a successfully dispatched direct paste increments paste count; save-derived does not increment source usage. OCR is never an automatic historical scan: a user selects one image, edits the recognition, and explicitly saves it. Saving preserves image storage type but enables OCR text search and type-aware actions.

`ClipboardHistoryViewModel` owns exactly one search `Task`. Every new input cancels the superseded task and advances a request ID; immediate results remain visible while the full candidate query is pending, and only the latest request may update results, errors, or loading state. `SearchCoordinator` keeps its separate generation check around debounce and read-only candidate retrieval. Explicit Task cancellation avoids wasted work, while generation and request ownership prevent late results from dependencies that do not promptly honor cancellation.

## Software update subsystem

The application links Sparkle at the exact package version `2.9.2`. `AppDelegate` owns one lazy `UpdateService` backed by one `SparkleUpdateDriver` and injects that same service into both Settings entry points. This keeps Sparkle's updater controller alive for the application lifecycle and prevents duplicate update sessions.

```mermaid
flowchart LR
    AD[AppDelegate] --> US[UpdateService]
    SV[SettingsView] --> US
    US --> UD[UpdateDriving]
    SD[SparkleUpdateDriver] --> UD
    SD --> SPU[SPUStandardUpdaterController]
    SPU --> UI[Sparkle standard update UI]
```

`UpdateDriving` is the test boundary. It publishes `canCheckForUpdates`, `automaticallyChecksForUpdates`, and `UpdateStatus`; `SparkleUpdateDriver` supplies the preference streams from Sparkle's KVO-compliant updater properties and the status stream from `SPUUpdaterDelegate` events. `UpdateService` mirrors these values as `@Published` main-actor state, exposes whether a manual check can start, and reports checking, up-to-date, update-available, and failure outcomes. User preference writes travel through `setAutomaticallyChecksForUpdates(_:)` to Sparkle, while driver-originated changes only update service state. This one-way subscription prevents feedback loops and keeps the About toggle synchronized when Sparkle's authorization UI changes the preference.

The app owns only the About controls and a concise status summary. `SPUStandardUpdaterController` remains responsible for the complete update-check progress, release notes, download, authorization, installation, cancellation, and relaunch UI. Because the app normally runs as an `LSUIElement`, `SparkleUpdateDriver` also implements Sparkle's gentle scheduled-reminder capability: it temporarily promotes an accessory app to a regular Dock application, badges the Dock icon for scheduled updates, clears the badge when the update receives attention, and restores accessory mode after the update session unless the user enabled the Dock icon preference.

`AppVersionProviding` is the test boundary for the About version label. `AppVersionInfo` is its Bundle-backed implementation, while `SettingsView` accepts any provider so tests and previews do not depend on hard-coded release values.

The current branch configures and statically validates the fixed HTTPS feed, public EdDSA key, and sandboxed Sparkle XPC services. Private signing material remains outside the repository. A genuine signed/notarized release archive and end-to-end V1.0.0 → V1.0.1 upgrade remain release evidence gates rather than responsibilities of the observable updater boundary.
