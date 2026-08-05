# 粘易增强搜索与开发者内容动作 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按任务逐项实施。每次只执行第一个未完成任务，完成门禁、提交代码并停止，禁止跨任务批量修改。

**Goal:** 在不破坏粘易现有“打开即搜、回车即贴”体验的前提下，完成结构化增强搜索、混合排序、内容类型识别、开发者内容动作、可编辑动作串联、衍生记录、复制来源事件和手动 OCR。

**Architecture:** 保留 `ClipboardHistoryRepository` 作为主记录与事务写入边界；新增独立 `Search`、`ContentActions`、`OCR` 能力域。搜索使用“已加载记录内存初筛 + 150ms 防抖 + 独立只读 SQLite 连接候选查询 + Swift 混合排序”；内容动作使用稳定 Action ID、注册表和会话步骤栈；OCR 使用 Vision 本地识别并由用户确认后写入数据库。

**Tech Stack:** Swift 6.0、SwiftUI、AppKit、SQLite3、Vision、XCTest、XcodeGen；最低 macOS 14.0；不引入第三方依赖和网络能力。

**Product Source:** `docs/superpowers/specs/2026-08-05-enhanced-search-and-content-actions-prd.md`

## Global Constraints

- 开发前必须阅读 `AI_CODING_RULES.md`、PRD、架构文档、用户指南和变更记录。
- 所有剪贴板正文、JWT、OCR 原文、URL 查询参数和动作结果不得写入日志。
- 不增加云同步、账号、网络请求、SQLite FTS、JWT 签名验证、脚本插件或工作流持久化。
- 新增用户文案必须同时补充 `en`、`zh-Hans`、`zh-Hant`。
- 新增文件由 `project.yml` 的目录式 sources 自动收录；每次新增/移动源文件后必须重新运行 `xcodegen generate`。
- 数据库迁移必须事务化、幂等，并从当前 migration version 2 无损升级。
- 原始历史记录永不被内容动作覆盖。
- 测试先行；每个任务必须先观察定向测试失败，再完成最小实现。
- 一个任务对应一个可审查提交；任务门禁未通过不得进入下一任务。
- 每次提交前必须确认 `git diff --check` 无错误且没有无关文件变化。

---

## 1. Codex LOOP 执行协议

本计划中的每个任务都重复执行一次 **LOOP：Locate → Outline → Operate → Prove**。

### L — Locate：锁定目标与上下文

Codex 在修改前必须输出一段 `LOOP Brief`，包含：

```text
Task: 当前任务编号与名称
Goal: 本次只交付什么
Dependencies: 已完成的前置任务/提交
Read: 本次已阅读的文件
Touch: 计划创建和修改的文件
Do not touch: 本次明确不修改的模块
```

随后执行：

```bash
git status --short
git log -1 --oneline
```

工作区不干净时，不得覆盖用户已有修改；先识别已有变更与本任务是否相关。

### O — Outline：先确认接口与测试

编码前输出：

```text
Interfaces produced:
Interfaces consumed:
Failing tests to add:
Acceptance commands:
Expected commit:
```

如果当前代码与计划假设不一致，Codex 必须停止修改并报告具体文件、符号和差异，不得自行扩大产品范围。

### O — Operate：红灯、最小实现、绿灯

执行顺序固定：

1. 添加任务要求的测试。
2. 运行定向测试并确认失败原因是缺少目标能力，而不是测试写错。
3. 编写最小实现。
4. 重复运行定向测试直至通过。
5. 只重构本任务直接触及的重复或超长逻辑。

### P — Prove：验证、文档、审查、提交

每个任务结束必须执行：

```bash
git diff --check
git status --short
```

然后按任务给出的命令运行验证，并输出：

```text
Tests run:
Build result:
Files changed:
Behavior delivered:
Known limitations preserved:
Commit SHA:
Next unlocked task:
```

完成提交后停止，等待下一轮 LOOP。

### 失败回路

任一验证失败时：

```text
保留失败输出
→ 返回 Locate，重新定位失败路径
→ 只修复导致门禁失败的最小范围
→ 重新执行 Operate 与 Prove
```

禁止通过删除测试、放宽断言、跳过 Release 检查或吞掉错误来结束回路。

---

## 2. 首次执行前基线

Codex 第一次执行本计划时先创建隔离分支或 worktree：

```bash
git switch -c feature/enhanced-search-content-actions
```

如果当前环境已经位于专用 worktree，则在该 worktree 创建同名或等价 feature 分支，不要修改主工作区。

运行基线：

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  test
```

预期：当前基线全部通过；README 记录的基线为 120 项测试。若实际测试数已变化，以命令真实输出为准并记录，但不得在基线失败时开始功能开发。

---

## 3. 任务依赖图

```text
Task 1 Database foundation
  └─> Task 2 Domain model and row mapping
        ├─> Task 3 Capture events and aggregation
        │     └─> Task 4 Repository feature APIs
        │            ├─> Task 6 Search engine
        │            ├─> Task 9 Content classification persistence
        │            ├─> Task 12 Action use/derived persistence
        │            └─> Task 14 OCR persistence
        ├─> Task 5 Search parser and suggestions
        │     └─> Task 6 Search engine
        └─> Task 9 Content classifier

Task 7 Main panel component extraction ─> Task 8 Search UI integration
Task 6 Search engine ────────────────> Task 8 Search UI integration
Task 9 Content classifier ──────────> Task 10 Action framework
Task 10 Action framework ───────────> Task 11 Advanced actions/highlighting
Task 4 + Task 10 + Task 11 ─────────> Task 12 Action session/derived behavior
Task 7 + Task 8 + Task 12 ──────────> Task 13 Command palette/right panel
Task 4 + Task 9 + Task 13 ──────────> Task 14 Manual OCR
All prior tasks ────────────────────> Task 15 Localization/docs/release gate
```

可并行范围：

- Task 7 可在 Task 1–6 期间由独立 agent 执行，但合并前必须保证 UI 行为不变。
- Task 5 可在 Task 3 开发期间执行，但依赖 Task 2 中的 `DetectedContentType`。
- 除上述两项外，按依赖图顺序执行。

---

## 4. 文件级目标结构

### 新增生产文件

```text
MacPasteHistory/Database/DatabaseOpenMode.swift
MacPasteHistory/Models/DetectedContentType.swift
MacPasteHistory/Models/ContentDetectionResult.swift
MacPasteHistory/Models/OCRStatus.swift
MacPasteHistory/Models/ClipboardCaptureEvent.swift
MacPasteHistory/Models/ClipboardCaptureEventSummary.swift
MacPasteHistory/Models/DerivedClipboardRecordRequest.swift
MacPasteHistory/Search/ParsedSearchQuery.swift
MacPasteHistory/Search/SearchQueryParser.swift
MacPasteHistory/Search/SearchSuggestionProvider.swift
MacPasteHistory/Search/SearchFilterMerger.swift
MacPasteHistory/Search/SearchCandidateSQLBuilder.swift
MacPasteHistory/Search/SearchCandidateProvider.swift
MacPasteHistory/Search/SearchRankingWeights.swift
MacPasteHistory/Search/SearchRanker.swift
MacPasteHistory/Search/SearchCoordinator.swift
MacPasteHistory/Search/SearchTextMatcher.swift
MacPasteHistory/ContentActions/ContentClassifier.swift
MacPasteHistory/ContentActions/ContentClassificationService.swift
MacPasteHistory/ContentActions/ContentAction.swift
MacPasteHistory/ContentActions/ContentActionRegistry.swift
MacPasteHistory/ContentActions/ContentActionExecutor.swift
MacPasteHistory/ContentActions/ContentActionResult.swift
MacPasteHistory/ContentActions/ActionSession.swift
MacPasteHistory/ContentActions/ActionSessionStep.swift
MacPasteHistory/ContentActions/DerivedSourcePreviewBuilder.swift
MacPasteHistory/ContentActions/Actions/JSONContentActions.swift
MacPasteHistory/ContentActions/Actions/URLContentActions.swift
MacPasteHistory/ContentActions/Actions/Base64ContentActions.swift
MacPasteHistory/ContentActions/Actions/JWTContentAction.swift
MacPasteHistory/ContentActions/Actions/TimestampContentAction.swift
MacPasteHistory/ContentActions/Actions/TextContentActions.swift
MacPasteHistory/ContentActions/Actions/SQLContentAction.swift
MacPasteHistory/ContentActions/Actions/ShellContentAction.swift
MacPasteHistory/ContentActions/Highlighting/ContentSyntaxHighlighter.swift
MacPasteHistory/OCR/OCRService.swift
MacPasteHistory/OCR/OCRResult.swift
MacPasteHistory/Services/CaptureEventAggregationService.swift
MacPasteHistory/Services/CaptureEventAggregationPreferences.swift
MacPasteHistory/ViewModels/ContentActionPanelViewModel.swift
MacPasteHistory/ViewModels/OCRViewModel.swift
MacPasteHistory/Views/Search/SearchBarView.swift
MacPasteHistory/Views/Search/SearchTokenView.swift
MacPasteHistory/Views/Search/SearchSuggestionView.swift
MacPasteHistory/Views/Search/KeywordHighlightedText.swift
MacPasteHistory/Views/History/HistoryTimelineView.swift
MacPasteHistory/Views/History/HistoryRowView.swift
MacPasteHistory/Views/History/HistoryDetailView.swift
MacPasteHistory/Views/Actions/ContentActionCommandPalette.swift
MacPasteHistory/Views/Actions/ContentActionPreviewView.swift
MacPasteHistory/Views/Actions/SyntaxHighlightedTextView.swift
MacPasteHistory/Views/OCR/OCRResultView.swift
```

### 主要修改文件

```text
MacPasteHistory/App/AppDelegate.swift
MacPasteHistory/App/HistoryPanelWindow.swift
MacPasteHistory/Clipboard/ClipboardMonitor.swift
MacPasteHistory/Database/DatabaseConnection.swift
MacPasteHistory/Database/MigrationManager.swift
MacPasteHistory/Database/ClipboardHistoryRepository.swift
MacPasteHistory/Models/ClipboardHistoryItem.swift
MacPasteHistory/Models/HistoryQuery.swift
MacPasteHistory/Services/DataCleanupService.swift
MacPasteHistory/Services/PasteCommandService.swift
MacPasteHistory/Utils/HistoryDisplayFormatter.swift
MacPasteHistory/ViewModels/ClipboardHistoryViewModel.swift
MacPasteHistory/Views/MainPanelView.swift
MacPasteHistory/Resources/en.lproj/Localizable.strings
MacPasteHistory/Resources/zh-Hans.lproj/Localizable.strings
MacPasteHistory/Resources/zh-Hant.lproj/Localizable.strings
docs/architecture/overall-architecture.md
docs/user-guide.md
docs/privacy-policy.md
docs/changelog/CHANGELOG.md
docs/release/manual-qa-record.md
docs/release/RELEASE_PREP_GUIDE.md
scripts/generate-manual-qa-fixtures.swift
scripts/verify-manual-qa-fixtures.sh
scripts/release-smoke-test.sh
```

---

# Task 1: Database Connection Safety and Migration V3

**Dependencies:** Baseline only.

**Files:**

- Create: `MacPasteHistory/Database/DatabaseOpenMode.swift`
- Modify: `MacPasteHistory/Database/DatabaseConnection.swift`
- Modify: `MacPasteHistory/Database/MigrationManager.swift`
- Create: `MacPasteHistoryTests/TestSupport/TemporaryDatabase.swift`
- Create: `MacPasteHistoryTests/DatabaseConnectionTests.swift`
- Create: `MacPasteHistoryTests/MigrationManagerV3Tests.swift`

**Interfaces:**

- Consumes: existing `DatabaseError`, migration versions 1 and 2.
- Produces:

```swift
enum DatabaseOpenMode {
    case readWriteCreate
    case readOnly

    var flags: Int32 { get }
}

final class DatabaseConnection {
    let databaseURL: URL

    init(databaseURL: URL, mode: DatabaseOpenMode = .readWriteCreate) throws
    func inTransaction<T>(_ operation: () throws -> T) throws -> T
    func foreignKeysAreEnabled() throws -> Bool
}
```

### LOOP steps

- [ ] **Step 1: Add database connection failure tests**

Create tests that verify the writer connection enables foreign keys and a read-only connection can query an initialized database:

```swift
func testInit_shouldEnableForeignKeys() throws {
    let temporary = try TemporaryDatabase()
    defer { temporary.remove() }

    XCTAssertTrue(try temporary.connection.foreignKeysAreEnabled())
}

func testReadOnlyConnection_shouldReadExistingDatabase() throws {
    let temporary = try TemporaryDatabase()
    defer { temporary.remove() }
    try MigrationManager(database: temporary.connection).migrate()

    let readOnly = try DatabaseConnection(databaseURL: temporary.url, mode: .readOnly)
    defer { try? readOnly.close() }

    let statement = try readOnly.prepare("SELECT COUNT(*) FROM schema_migrations;")
    defer { sqlite3_finalize(statement) }
    XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
}
```

Run and confirm failure:

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/DatabaseConnectionTests test
```

Expected: compile failure because `DatabaseOpenMode` and `foreignKeysAreEnabled()` do not exist.

- [ ] **Step 2: Implement connection modes and connection pragmas**

Use `sqlite3_open_v2` with `SQLITE_OPEN_FULLMUTEX`:

```swift
enum DatabaseOpenMode {
    case readWriteCreate
    case readOnly

    var flags: Int32 {
        switch self {
        case .readWriteCreate:
            return SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        case .readOnly:
            return SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        }
    }
}
```

After open succeeds:

```swift
sqlite3_busy_timeout(database, 1_000)
handle = database
try execute("PRAGMA foreign_keys = ON;")
```

`inTransaction` must commit only after the closure succeeds and roll back on every thrown error:

```swift
func inTransaction<T>(_ operation: () throws -> T) throws -> T {
    try execute("BEGIN IMMEDIATE TRANSACTION;")
    do {
        let value = try operation()
        try execute("COMMIT;")
        return value
    } catch {
        try? execute("ROLLBACK;")
        throw error
    }
}
```

- [ ] **Step 3: Add migration V3 schema tests**

The tests must build an actual version-2 database, run the current migrator, and assert:

```text
schema_migrations contains versions 1, 2, 3
clipboard_history contains every new column
clipboard_capture_events exists
clipboard_capture_event_summaries exists
foreign key for derived_from_history_id uses ON DELETE SET NULL
capture event foreign keys use ON DELETE CASCADE
running migrate() twice does not add another version row or fail
```

Use `PRAGMA table_info`, `PRAGMA foreign_key_list` and `sqlite_master`; do not inspect private migration constants.

- [ ] **Step 4: Implement migration version 3**

Add exactly one versioned migration named `enhanced_search_content_actions`.

Main-table additions:

```sql
ALTER TABLE clipboard_history ADD COLUMN searchable_text TEXT;
ALTER TABLE clipboard_history ADD COLUMN detected_type TEXT;
ALTER TABLE clipboard_history ADD COLUMN user_override_type TEXT;
ALTER TABLE clipboard_history ADD COLUMN detection_confidence REAL;
ALTER TABLE clipboard_history ADD COLUMN detection_version INTEGER;
ALTER TABLE clipboard_history ADD COLUMN detected_at DATETIME;
ALTER TABLE clipboard_history ADD COLUMN first_captured_at DATETIME;
ALTER TABLE clipboard_history ADD COLUMN last_captured_at DATETIME;
ALTER TABLE clipboard_history ADD COLUMN capture_count INTEGER NOT NULL DEFAULT 1;
ALTER TABLE clipboard_history ADD COLUMN reuse_copy_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE clipboard_history ADD COLUMN paste_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE clipboard_history ADD COLUMN last_reuse_copied_at DATETIME;
ALTER TABLE clipboard_history ADD COLUMN last_pasted_at DATETIME;
ALTER TABLE clipboard_history ADD COLUMN ocr_status TEXT NOT NULL DEFAULT 'notStarted';
ALTER TABLE clipboard_history ADD COLUMN ocr_text TEXT;
ALTER TABLE clipboard_history ADD COLUMN ocr_updated_at DATETIME;
ALTER TABLE clipboard_history ADD COLUMN ocr_error_code TEXT;
ALTER TABLE clipboard_history ADD COLUMN derived_from_history_id INTEGER REFERENCES clipboard_history(id) ON DELETE SET NULL;
ALTER TABLE clipboard_history ADD COLUMN derived_action_id TEXT;
ALTER TABLE clipboard_history ADD COLUMN derived_action_summary TEXT;
ALTER TABLE clipboard_history ADD COLUMN derived_at DATETIME;
ALTER TABLE clipboard_history ADD COLUMN derived_source_preview TEXT;
ALTER TABLE clipboard_history ADD COLUMN derived_source_hash TEXT;
```

Backfill:

```sql
UPDATE clipboard_history
SET searchable_text = COALESCE(text_content, ''),
    first_captured_at = created_at,
    last_captured_at = created_at
WHERE first_captured_at IS NULL OR last_captured_at IS NULL OR searchable_text IS NULL;
```

Create event tables. The summary table must include a non-null `source_key` so unknown/null sources can be deterministically upserted:

```sql
CREATE TABLE clipboard_capture_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    history_id INTEGER NOT NULL,
    source_app TEXT,
    source_bundle_id TEXT,
    captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(history_id) REFERENCES clipboard_history(id) ON DELETE CASCADE
);

CREATE TABLE clipboard_capture_event_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    history_id INTEGER NOT NULL,
    source_key TEXT NOT NULL,
    source_app TEXT,
    source_bundle_id TEXT,
    capture_count INTEGER NOT NULL DEFAULT 0,
    first_captured_at DATETIME NOT NULL,
    last_captured_at DATETIME NOT NULL,
    UNIQUE(history_id, source_key),
    FOREIGN KEY(history_id) REFERENCES clipboard_history(id) ON DELETE CASCADE
);
```

Add the indexes specified by the PRD, including `last_captured_at`, effective type fields, `last_pasted_at`, and event time indexes.

- [ ] **Step 5: Run Task 1 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/DatabaseConnectionTests \
  -only-testing:MacPasteHistoryTests/MigrationManagerV3Tests test
```

Expected: all Task 1 tests pass.

- [ ] **Step 6: Commit Task 1**

```bash
git add MacPasteHistory/Database MacPasteHistoryTests/DatabaseConnectionTests.swift \
  MacPasteHistoryTests/MigrationManagerV3Tests.swift MacPasteHistoryTests/TestSupport/TemporaryDatabase.swift
git commit -m "feat: add enhanced history database foundation"
```

**Gate:** migration version 3 is transactional and idempotent; foreign keys report enabled; read-only connection works; no repository behavior changes yet.

---

# Task 2: Expanded Domain Models and Repository Row Mapping

**Dependencies:** Task 1.

**Files:**

- Create: `MacPasteHistory/Models/DetectedContentType.swift`
- Create: `MacPasteHistory/Models/ContentDetectionResult.swift`
- Create: `MacPasteHistory/Models/OCRStatus.swift`
- Create: `MacPasteHistory/Models/ClipboardCaptureEvent.swift`
- Create: `MacPasteHistory/Models/ClipboardCaptureEventSummary.swift`
- Create: `MacPasteHistory/Models/DerivedClipboardRecordRequest.swift`
- Modify: `MacPasteHistory/Models/ClipboardHistoryItem.swift`
- Modify: `MacPasteHistory/Database/ClipboardHistoryRepository.swift`
- Modify: `MacPasteHistory/Utils/HistoryDisplayFormatter.swift`
- Modify: `MacPasteHistoryTests/ClipboardHistoryRepositoryTests.swift`
- Modify: `MacPasteHistoryTests/HistoryDisplayFormatterTests.swift`
- Create: `MacPasteHistoryTests/ClipboardHistoryItemTests.swift`

**Interfaces produced:**

```swift
enum DetectedContentType: String, CaseIterable, Codable {
    case plainText
    case image
    case json
    case url
    case base64
    case jwt
    case timestamp
    case sql
    case shell
}

struct ContentDetectionResult: Equatable {
    let type: DetectedContentType
    let confidence: Double
    let version: Int
    let detectedAt: Date
}

enum OCRStatus: String, Codable {
    case notStarted
    case recognizing
    case recognized
    case failed
}
```

Extend `ClipboardHistoryItem` with all V3 fields and these computed properties:

```swift
var effectiveDetectedType: DetectedContentType {
    userOverrideType ?? detectedType ?? (contentType == .image ? .image : .plainText)
}

var displayDate: Date {
    lastCapturedAt ?? createdAt
}

var isDerived: Bool {
    derivedActionID != nil
}
```

### LOOP steps

- [ ] **Step 1: Add model behavior tests**

Test exact priority and fallback:

```swift
func testEffectiveDetectedType_shouldPreferUserOverride() {
    let item = makeHistoryItem(detectedType: .json, userOverrideType: .plainText)
    XCTAssertEqual(item.effectiveDetectedType, .plainText)
}

func testDisplayDate_shouldPreferLastCapturedAt() {
    let created = Date(timeIntervalSince1970: 100)
    let captured = Date(timeIntervalSince1970: 200)
    let item = makeHistoryItem(createdAt: created, lastCapturedAt: captured)
    XCTAssertEqual(item.displayDate, captured)
}
```

- [ ] **Step 2: Add repository mapping tests**

Save a text record, update every new column using SQL, reload it through the repository and assert all values map correctly. Include nullable dates, `Double` confidence, OCR fields and derived fields.

Run:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/ClipboardHistoryItemTests \
  -only-testing:MacPasteHistoryTests/ClipboardHistoryRepositoryTests test
```

Expected: compile or assertion failure because the model and SELECT mapping do not include V3 fields.

- [ ] **Step 3: Implement models and stable initializers**

Provide an explicit `ClipboardHistoryItem` initializer. New arguments must have defaults so existing tests and call sites remain source-compatible. Clamp `detectionConfidence` to `0...1` when constructing `ContentDetectionResult`; invalid database values are decoded as nil rather than crashing.

- [ ] **Step 4: Expand repository SELECT mapping**

Update `selectHistorySQL` once and keep the index mapping centralized. Add helper decoders:

```swift
private func nullableDoubleValue(_ statement: OpaquePointer?, index: Int32) -> Double?
private func nullableDateValue(_ statement: OpaquePointer?, index: Int32) throws -> Date?
private func detectedType(from value: String?) -> DetectedContentType?
private func ocrStatus(from value: String?) -> OCRStatus
```

Do not duplicate SELECT column lists in individual methods.

- [ ] **Step 5: Change timeline metadata to `displayDate`**

In `HistoryTimelineOrganizer` and recent source generation, replace `item.createdAt` with `item.displayDate`. In list/detail display formatting use `displayDate` for “recent copy” context; retain `createdAt` in detailed metadata as the first-seen date when both are displayed later.

- [ ] **Step 6: Run Task 2 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/ClipboardHistoryItemTests \
  -only-testing:MacPasteHistoryTests/ClipboardHistoryRepositoryTests \
  -only-testing:MacPasteHistoryTests/HistoryDisplayFormatterTests test
```

- [ ] **Step 7: Commit Task 2**

```bash
git add MacPasteHistory/Models MacPasteHistory/Database/ClipboardHistoryRepository.swift \
  MacPasteHistory/Utils/HistoryDisplayFormatter.swift MacPasteHistoryTests
git commit -m "feat: map enhanced clipboard history metadata"
```

**Gate:** existing save/fetch/delete/favorite behavior remains green; V3 fields round-trip; timeline groups by `lastCapturedAt` fallback.

---

# Task 3: Capture Events and 30-Day Aggregation

**Dependencies:** Task 2.

**Files:**

- Create: `MacPasteHistory/Services/CaptureEventAggregationService.swift`
- Create: `MacPasteHistory/Services/CaptureEventAggregationPreferences.swift`
- Create: `MacPasteHistory/Utils/CaptureSourceIdentity.swift`
- Modify: `MacPasteHistory/Database/ClipboardHistoryRepository.swift`
- Modify: `MacPasteHistory/Services/DataCleanupService.swift`
- Modify: `MacPasteHistory/App/AppDelegate.swift`
- Modify: `MacPasteHistoryTests/ClipboardHistoryRepositoryTests.swift`
- Create: `MacPasteHistoryTests/CaptureEventAggregationServiceTests.swift`
- Modify: `MacPasteHistoryTests/DataCleanupServiceTests.swift`

**Interfaces produced:**

```swift
struct CaptureSourceIdentity {
    let key: String
    let appName: String?
    let bundleID: String?

    init(appName: String?, bundleID: String?)
}

protocol CaptureEventAggregationPreferencesProviding {
    var lastAggregationDate: Date? { get set }
}

struct CaptureEventAggregationService {
    func aggregateIfNeeded(now: Date = Date()) throws
}
```

Repository additions:

```swift
func fetchCaptureEvents(historyID: Int64, since date: Date) throws -> [ClipboardCaptureEvent]
func fetchCaptureSummaries(historyID: Int64) throws -> [ClipboardCaptureEventSummary]
func aggregateCaptureEvents(before cutoff: Date) throws
```

### LOOP steps

- [ ] **Step 1: Define source identity tests**

Required keys:

```text
bundleID exists       → bundle:<lowercased bundleID>
no bundle, app exists → app:<trimmed lowercased app name>
no source             → unknown
```

This key is database identity only and must never be displayed to users.

- [ ] **Step 2: Add atomic capture tests**

Tests must prove:

```text
new text creates one main record and one event
same text returns same main record
same text increments capture_count
same text updates last_captured_at and latest source
same text does not change created_at or first_captured_at
new and duplicate image captures also create events
failure inserting an event rolls back the corresponding main-record update
```

For the rollback test, add a temporary trigger that aborts inserts into `clipboard_capture_events`, call `saveText`, and assert no partial main-record change remains.

- [ ] **Step 3: Implement atomic save/capture behavior**

Wrap insert/update plus event insert in `database.inTransaction`. Change duplicate updates from:

```sql
created_at = CURRENT_TIMESTAMP
```

to:

```sql
last_captured_at = CURRENT_TIMESTAMP,
capture_count = capture_count + 1,
source_app = ?,
source_bundle_id = ?,
updated_at = CURRENT_TIMESTAMP
```

New records must initialize `searchable_text`, `first_captured_at`, `last_captured_at`, `capture_count = 1`, then insert the first event.

- [ ] **Step 4: Add aggregation tests**

Create events at 31 days and 5 days before a fixed `now`. Assert:

```text
only older events are aggregated
summary count, first time and last time are correct
same source upserts into one summary row
recent events remain
running aggregation twice does not double-count
triggered failure rolls back summary updates and event deletion
same calendar day causes aggregateIfNeeded to skip the repository call
```

- [ ] **Step 5: Implement aggregation SQL**

Within one transaction:

1. Group old events by `history_id` and normalized source identity.
2. Upsert `capture_count` by addition.
3. Use the minimum first time and maximum last time.
4. Delete only events with `captured_at < cutoff` after the upsert succeeds.

`aggregateIfNeeded` calculates `cutoff = now - 30 days`, records the successful day in preferences, and does not mark success when repository aggregation throws.

- [ ] **Step 6: Integrate startup cleanup**

Inject `CaptureEventAggregationService` into `DataCleanupService`. Run aggregation as an independent cleanup step so failure does not prevent expiry/count/storage cleanup. `AppDelegate` must construct it using the existing repository and `UserDefaults.standard` preferences.

- [ ] **Step 7: Run Task 3 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/ClipboardHistoryRepositoryTests \
  -only-testing:MacPasteHistoryTests/CaptureEventAggregationServiceTests \
  -only-testing:MacPasteHistoryTests/DataCleanupServiceTests test
```

- [ ] **Step 8: Commit Task 3**

```bash
git add MacPasteHistory/Database/ClipboardHistoryRepository.swift \
  MacPasteHistory/Services MacPasteHistory/Utils/CaptureSourceIdentity.swift \
  MacPasteHistory/App/AppDelegate.swift MacPasteHistoryTests
git commit -m "feat: retain clipboard capture source history"
```

**Gate:** one canonical record per hash; capture updates and event writes are atomic; 30-day aggregation is idempotent and transactional.

---

# Task 4: Repository APIs for Usage, Type Overrides, OCR and Derived Records

**Dependencies:** Task 3.

**Files:**

- Modify: `MacPasteHistory/Models/DerivedClipboardRecordRequest.swift`
- Create: `MacPasteHistory/ContentActions/DerivedSourcePreviewBuilder.swift`
- Modify: `MacPasteHistory/Database/ClipboardHistoryRepository.swift`
- Create: `MacPasteHistoryTests/ClipboardHistoryFeatureRepositoryTests.swift`
- Create: `MacPasteHistoryTests/DerivedSourcePreviewBuilderTests.swift`

**Interfaces produced:**

```swift
struct DerivedClipboardRecordRequest {
    let text: String
    let sourceHistoryID: Int64
    let actionID: String
    let actionSummary: String
    let sourcePreview: String
    let sourceHash: String
    let detection: ContentDetectionResult
}

func recordReuseCopy(historyID: Int64, at date: Date) throws
func recordPaste(historyID: Int64, at date: Date) throws
func updateDetectedType(id: Int64, result: ContentDetectionResult) throws
func updateUserOverrideType(id: Int64, type: DetectedContentType?) throws
func saveOCRResult(id: Int64, text: String, detection: ContentDetectionResult) throws
func markOCRFailure(id: Int64, errorCode: String, at date: Date) throws
func saveDerivedText(_ request: DerivedClipboardRecordRequest) throws -> ClipboardHistoryItem
```

### LOOP steps

- [ ] **Step 1: Add usage-stat tests**

Assert copy and paste counts/timestamps update independently. Updating usage must not change capture count, source app, `createdAt` or `lastCapturedAt`.

- [ ] **Step 2: Add type and OCR persistence tests**

Assert:

```text
updateDetectedType stores type/confidence/version/time
updateUserOverrideType stores a manual type
passing nil clears the override
saveOCRResult stores text/status/time, clears error, updates searchable_text
markOCRFailure preserves previous ocr_text and stores a stable error code
```

For an image, `saveOCRResult` must not change `content_type` from image.

- [ ] **Step 3: Define derived-source preview behavior**

Implement deterministic privacy-aware previews:

```text
sensitive record                  → "Sensitive content"
image record                      → "Image"
JWT                               → "JWT • <first 8 hash chars>"
URL                               → scheme + host + path, query/fragment removed
other text                        → whitespace collapsed, max 120 characters
empty text                        → "Empty text"
```

The stable stored values are English identifiers, not localized UI strings; UI localizes display labels later.

- [ ] **Step 4: Add derived-record tests**

Assert:

```text
new output creates a text record with source/action metadata
multi-step summary is stored verbatim
new derived record starts with zero reuse/paste counts
existing hash is reused and no duplicate row is created
existing canonical record provenance is not overwritten when a derived output matches it
deleting source sets derived_from_history_id to NULL while preserving summary/hash/preview
```

- [ ] **Step 5: Implement repository methods with bound parameters**

All values, including error code, action ID and summary, must use SQLite bindings. Do not interpolate user-controlled strings into SQL.

`saveDerivedText` must reuse the same content normalization/hash service as `saveText`. When an existing hash is found:

1. Record a new capture event with source app `AppBrand.displayName` and the app bundle ID.
2. Update capture time/count using the duplicate path.
3. Return the existing record.
4. Do not overwrite any existing derived metadata.

- [ ] **Step 6: Run Task 4 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/ClipboardHistoryFeatureRepositoryTests \
  -only-testing:MacPasteHistoryTests/DerivedSourcePreviewBuilderTests test
```

- [ ] **Step 7: Commit Task 4**

```bash
git add MacPasteHistory/Database/ClipboardHistoryRepository.swift \
  MacPasteHistory/Models/DerivedClipboardRecordRequest.swift \
  MacPasteHistory/ContentActions/DerivedSourcePreviewBuilder.swift MacPasteHistoryTests
git commit -m "feat: persist clipboard usage and derived metadata"
```

**Gate:** all future search/action/OCR layers can use repository methods without issuing SQL from ViewModels.

---

# Task 5: Structured Search Parser, Tokens and Suggestions

**Dependencies:** Task 2.

**Files:**

- Create: `MacPasteHistory/Search/ParsedSearchQuery.swift`
- Create: `MacPasteHistory/Search/SearchQueryParser.swift`
- Create: `MacPasteHistory/Search/SearchSuggestionProvider.swift`
- Create: `MacPasteHistory/Search/SearchFilterMerger.swift`
- Create: `MacPasteHistoryTests/SearchQueryParserTests.swift`
- Create: `MacPasteHistoryTests/SearchSuggestionProviderTests.swift`
- Create: `MacPasteHistoryTests/SearchFilterMergerTests.swift`

**Interfaces produced:**

```swift
struct ParsedSearchQuery: Equatable {
    let rawInput: String
    let terms: [String]
    let app: String?
    let type: DetectedContentType?
    let favorite: Bool?
    let before: Date?
    let after: Date?
    let tokens: [SearchToken]
    let issues: [SearchParseIssue]
}

enum SearchTokenKind: Equatable {
    case app(String)
    case type(DetectedContentType)
    case favorite(Bool)
    case before(Date)
    case after(Date)
    case invalid(prefix: String, value: String)
}

struct SearchQueryParser {
    init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init)
    func parse(_ input: String) -> ParsedSearchQuery
}
```

### LOOP steps

- [ ] **Step 1: Add tokenizer/parser tests**

Required cases:

```swift
XCTAssertEqual(parser.parse("docker compose").terms, ["docker", "compose"])
XCTAssertEqual(parser.parse("app:\"Visual Studio Code\" json").app, "Visual Studio Code")
XCTAssertEqual(parser.parse("type:jwt").type, .jwt)
XCTAssertEqual(parser.parse("type:text").type, .plainText)
XCTAssertEqual(parser.parse("fav:false").favorite, false)
```

Also test:

```text
before:7d and after:30d against a fixed now
YYYY-MM-DD in the current calendar/timezone
unknown repo:foo remains a normal term
known invalid fav:yes produces an invalid token and issue
repeated app/type/fav/before/after uses the final valid value
unterminated quote becomes a normal term plus a nonfatal issue
```

- [ ] **Step 2: Implement a single-pass tokenizer**

The parser must preserve the raw input and support escaped quote/backslash inside quoted values. It must not use a regular expression that loses character ranges required by removable token UI.

Each `SearchToken` stores its original `Range<String.Index>` so removing a token can edit only that range.

- [ ] **Step 3: Add suggestion tests**

Given known sources `[Terminal, Visual Studio Code]`, assert:

```text
"a" or "ap" suggests app:
"type:" suggests all supported type values
"app:v" filters to Visual Studio Code
"fav:" suggests true and false
"before:" suggests 1d, 7d, 30d and YYYY-MM-DD help
accepted suggestion returns replacement text and cursor offset
```

- [ ] **Step 4: Implement SearchSuggestionProvider**

Suggestions are pure values; the provider must not own UI focus. Sort source suggestions by case-insensitive title. Limit visible suggestions to 10.

- [ ] **Step 5: Define filter precedence with tests**

`SearchFilterMerger` combines syntax with existing ribbon/filter state:

```text
syntax app overrides selectedSourceOption
syntax type overrides selectedContentType
syntax fav overrides favorites toggle
before/after override selected TimeRange
for dimensions absent from syntax, existing controls remain active
```

This avoids contradictory hidden filters while preserving the existing UI.

- [ ] **Step 6: Run Task 5 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/SearchQueryParserTests \
  -only-testing:MacPasteHistoryTests/SearchSuggestionProviderTests \
  -only-testing:MacPasteHistoryTests/SearchFilterMergerTests test
```

- [ ] **Step 7: Commit Task 5**

```bash
git add MacPasteHistory/Search MacPasteHistoryTests/SearchQueryParserTests.swift \
  MacPasteHistoryTests/SearchSuggestionProviderTests.swift \
  MacPasteHistoryTests/SearchFilterMergerTests.swift
git commit -m "feat: parse structured clipboard searches"
```

**Gate:** parser is deterministic, nonfatal on bad syntax, and independent of SwiftUI/SQLite.

---

# Task 6: Search Candidate Query, Ranking and Request Coordination

**Dependencies:** Tasks 4 and 5.

**Files:**

- Create: `MacPasteHistory/Search/SearchCandidateSQLBuilder.swift`
- Create: `MacPasteHistory/Search/SearchCandidateProvider.swift`
- Create: `MacPasteHistory/Search/SearchRankingWeights.swift`
- Create: `MacPasteHistory/Search/SearchTextMatcher.swift`
- Create: `MacPasteHistory/Search/SearchRanker.swift`
- Create: `MacPasteHistory/Search/SearchCoordinator.swift`
- Modify: `MacPasteHistory/Database/ClipboardHistoryRepository.swift`
- Create: `MacPasteHistoryTests/SearchCandidateSQLBuilderTests.swift`
- Create: `MacPasteHistoryTests/SearchCandidateProviderTests.swift`
- Create: `MacPasteHistoryTests/SearchRankerTests.swift`
- Create: `MacPasteHistoryTests/SearchCoordinatorTests.swift`
- Create: `MacPasteHistoryTests/SearchPerformanceTests.swift`

**Interfaces produced:**

```swift
struct SearchCandidateRequest {
    let parsedQuery: ParsedSearchQuery
    let storageContentType: ClipboardContentType?
    let sourceFilter: HistoryQuery.SourceFilter
    let timeRange: HistoryQuery.TimeRange
    let favoritesOnly: Bool
    let limit: Int
}

actor SearchCandidateProvider {
    init(databaseURL: URL)
    func candidates(for request: SearchCandidateRequest) throws -> [ClipboardHistoryItem]
}

struct RankedSearchResult: Identifiable, Equatable {
    let item: ClipboardHistoryItem
    let score: Double
    let matchedTerms: [String]
    var id: Int64 { item.id }
}

actor SearchCoordinator {
    func immediateResults(input: String, loadedItems: [ClipboardHistoryItem], filters: SearchUIFilters) -> SearchResponse
    func search(input: String, loadedItems: [ClipboardHistoryItem], filters: SearchUIFilters) async -> SearchResponse
    func cancelCurrentSearch()
}
```

### LOOP steps

- [ ] **Step 1: Add SQL builder tests**

Verify generated SQL and bound values for every structured filter. The builder must:

- use `COALESCE(user_override_type, detected_type, CASE WHEN content_type = 'image' THEN 'image' ELSE 'plainText' END)` for effective type;
- use `last_captured_at` for before/after/time-range filters;
- apply app filter to both source name and bundle ID, case-insensitive;
- include a keyword match bucket in `ORDER BY` so exact/substr matches are considered before recency;
- never interpolate search text into SQL;
- end with `LIMIT ?` capped at 500.

- [ ] **Step 2: Implement candidate fetching on an isolated read connection**

`SearchCandidateProvider` opens a `.readOnly` `DatabaseConnection` inside its actor for each full query, closes it in `defer`, and constructs a repository over that connection. It must never share the app writer connection across detached tasks.

Add to repository:

```swift
func fetchSearchCandidates(request: SearchCandidateRequest) throws -> [ClipboardHistoryItem]
```

- [ ] **Step 3: Add matcher and ranker tests**

Required precedence:

```text
exact > prefix > complete word > substring > fuzzy
```

The fuzzy path must compare against bounded tokens, not the entire large text:

```text
inspect at most first 4096 normalized characters
extract at most 256 tokens
only compare tokens whose length is within ±50% of the term length
normalized Levenshtein similarity below 0.60 yields no fuzzy match
```

Test that an unmatched record cannot enter results solely through favorite or usage scores.

- [ ] **Step 4: Implement centralized ranking weights**

Use these defaults:

```swift
struct SearchRankingWeights {
    let exact = 1_000.0
    let prefix = 700.0
    let wholeWord = 500.0
    let substring = 300.0
    let fuzzyMaximum = 250.0
    let captureRecencyMaximum = 200.0
    let pasteRecencyMaximum = 120.0
    let pasteCountMaximum = 80.0
    let reuseCopyCountMaximum = 40.0
    let favorite = 30.0
    let sourceMaximum = 80.0
    let allTermsBonus = 40.0
}
```

Recency formula:

```swift
maximum * pow(0.5, age / halfLife)
```

Use 7-day capture half-life and 14-day paste half-life. Count score uses bounded logarithmic growth:

```swift
minimum(maximum, log2(Double(count) + 1) / log2(65) * maximum)
```

- [ ] **Step 5: Add coordinator race/cancellation tests**

Use a fake provider with controlled continuations. Start search `j`, then `json`; resume `json` first and `j` last. Assert only `json` is marked current. Test explicit cancellation and 150ms debounce using an injected sleeper/clock abstraction rather than real wall-clock sleeps.

- [ ] **Step 6: Implement coordinator**

The actor owns a monotonically increasing generation. Every new search or cancellation increments it. After debounce and candidate query, compare the captured generation before returning a current response. A stale response must be returned with `isCurrent = false` and ignored by the ViewModel.

`immediateResults` parses and ranks only loaded items without awaiting SQLite.

- [ ] **Step 7: Add performance tests**

Generate 500 in-memory items and assert ranker work using `measure`. Add a database performance test with 500 synthetic rows. Do not fail on a single noisy sample; use XCTest metrics and document the target:

```text
in-memory initial filter target < 16ms
read query plus rank target < 100ms on the development Mac
```

Performance tests may be excluded from the fastest per-edit command, but must run in the Task 6 gate.

- [ ] **Step 8: Run Task 6 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/SearchCandidateSQLBuilderTests \
  -only-testing:MacPasteHistoryTests/SearchCandidateProviderTests \
  -only-testing:MacPasteHistoryTests/SearchRankerTests \
  -only-testing:MacPasteHistoryTests/SearchCoordinatorTests \
  -only-testing:MacPasteHistoryTests/SearchPerformanceTests test
```

- [ ] **Step 9: Commit Task 6**

```bash
git add MacPasteHistory/Search MacPasteHistory/Database/ClipboardHistoryRepository.swift \
  MacPasteHistoryTests/SearchCandidateSQLBuilderTests.swift \
  MacPasteHistoryTests/SearchCandidateProviderTests.swift \
  MacPasteHistoryTests/SearchRankerTests.swift \
  MacPasteHistoryTests/SearchCoordinatorTests.swift \
  MacPasteHistoryTests/SearchPerformanceTests.swift
git commit -m "feat: rank clipboard search results"
```

**Gate:** search core is UI-independent, cancellation-safe, uses a read-only connection and meets measured targets on 500 records.

---

# Task 7: Extract Main Panel Components Without Behavior Changes

**Dependencies:** Baseline. Can run in parallel, but merge before Task 8.

**Files:**

- Modify: `MacPasteHistory/Views/MainPanelView.swift`
- Create: `MacPasteHistory/Views/History/HistoryTimelineView.swift`
- Create: `MacPasteHistory/Views/History/HistoryRowView.swift`
- Create: `MacPasteHistory/Views/History/HistoryDetailView.swift`
- Create: `MacPasteHistory/Views/History/HistoryImagePreview.swift`
- Modify: `MacPasteHistoryTests/HistoryPanelInteractionTests.swift` if present
- Create: `MacPasteHistoryTests/HistoryRowPresentationTests.swift`

**Interfaces produced:**

```swift
struct HistoryTimelineView: View
struct HistoryRowView: View
struct HistoryDetailView: View
struct HistoryImagePreview: View
```

### LOOP steps

- [ ] **Step 1: Capture current presentation behavior in tests**

Extract pure presentation helpers from the private row view and test:

```text
text/image preview label
source metadata formatting
image size label
favorite accessibility title
selected-row hint
```

- [ ] **Step 2: Move private views to focused files**

Move code without changing strings, gestures, keyboard behavior, colors or layout. `MainPanelView` retains panel-level state and orchestration only.

- [ ] **Step 3: Verify no behavior drift**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/HistoryRowPresentationTests \
  -only-testing:MacPasteHistoryTests/HistoryPanelInteractionTests test
```

If `HistoryPanelInteractionTests` does not exist, use the existing panel/window test class discovered with:

```bash
rg -n "HistoryPanel|MainPanel|direct paste|keyboard" MacPasteHistoryTests
```

Record the exact discovered class in the LOOP report; do not create a duplicate test class for existing behavior.

- [ ] **Step 4: Commit Task 7**

```bash
git add MacPasteHistory/Views/MainPanelView.swift MacPasteHistory/Views/History MacPasteHistoryTests
git commit -m "refactor: split clipboard history panel components"
```

**Gate:** generated app builds and existing direct paste, details, favorite, delete, key navigation and sheet behavior remain unchanged.

---

# Task 8: Search ViewModel and UI Integration

**Dependencies:** Tasks 6 and 7.

**Files:**

- Create: `MacPasteHistory/Views/Search/SearchBarView.swift`
- Create: `MacPasteHistory/Views/Search/SearchTokenView.swift`
- Create: `MacPasteHistory/Views/Search/SearchSuggestionView.swift`
- Create: `MacPasteHistory/Views/Search/KeywordHighlightedText.swift`
- Modify: `MacPasteHistory/ViewModels/ClipboardHistoryViewModel.swift`
- Modify: `MacPasteHistory/Views/MainPanelView.swift`
- Modify: `MacPasteHistory/Views/History/HistoryTimelineView.swift`
- Modify: `MacPasteHistory/Views/History/HistoryRowView.swift`
- Modify: `MacPasteHistory/App/AppDelegate.swift`
- Modify: `MacPasteHistoryTests/ClipboardHistoryViewModelTests.swift`
- Create: `MacPasteHistoryTests/SearchViewModelTests.swift`
- Create: `MacPasteHistoryTests/KeywordHighlightTests.swift`

**ViewModel outputs:**

```swift
@Published private(set) var parsedSearchQuery: ParsedSearchQuery
@Published private(set) var searchTokens: [SearchToken]
@Published private(set) var searchSuggestions: [SearchSuggestion]
@Published private(set) var isSearchLoading: Bool
@Published private(set) var highlightedTerms: [String]

func updateSearchText(_ text: String)
func acceptSuggestion(_ suggestion: SearchSuggestion)
func removeSearchToken(_ token: SearchToken)
func refreshSearch()
```

### LOOP steps

- [ ] **Step 1: Add ViewModel immediate/full search tests**

Use a fake `SearchCoordinating` protocol implementation. Assert:

```text
updateSearchText publishes immediate in-memory results synchronously
full response replaces immediate results only when isCurrent is true
stale response is ignored
selected item ID remains when present in new results
missing selected item falls back to first result
loadMore reveals the next page from the ranked candidate pool
search errors preserve previous items and expose a light error message
```

- [ ] **Step 2: Refactor pagination for ranked candidates**

Store up to 500 ranked candidates in a private array. `items` exposes `prefix(visibleCount)`. `loadMoreIfNeeded` increases visible count by `pageSize`; it must not issue a second database query for the same search generation.

Empty search still goes through the search coordinator and sorts by `lastCapturedAt`, preserving timeline behavior.

- [ ] **Step 3: Inject SearchCoordinator in AppDelegate**

Construct it with `applicationSupportService.databaseURL`. Do not pass the writer database connection. Inject it into each new `ClipboardHistoryViewModel`.

- [ ] **Step 4: Implement SearchBarView and suggestions**

Keep the raw text in a normal `TextField`. Render parsed tokens below or adjacent to the field without replacing raw input. Required keyboard behavior:

```text
Up/Down selects suggestion
Enter accepts selected suggestion when suggestion list is visible
Esc closes suggestions before closing the panel
```

Accepting a suggestion replaces only the active token range and places the cursor after the replacement.

- [ ] **Step 5: Implement token removal**

Removing a token deletes its original range from `searchText`, normalizes adjacent spaces, and triggers `updateSearchText`. Invalid known-prefix tokens use warning styling and an accessibility description.

- [ ] **Step 6: Implement keyword highlighting**

`KeywordHighlightedText` receives plain text plus `highlightedTerms` and returns an `AttributedString`. It must match case-insensitively, prefer longer overlapping terms, and cap work to the displayed preview text. Copy/paste continues to use the original item text.

- [ ] **Step 7: Wire filters through SearchFilterMerger**

Replace direct `loadHistory()` calls from source ribbon, type/time filter and favorite toggle with `refreshSearch()`. Same-dimension search syntax takes precedence as defined in Task 5.

- [ ] **Step 8: Run Task 8 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/ClipboardHistoryViewModelTests \
  -only-testing:MacPasteHistoryTests/SearchViewModelTests \
  -only-testing:MacPasteHistoryTests/KeywordHighlightTests test
```

Manual preview:

```bash
scripts/preview-release-app.sh --seed-preview-data
```

Verify ordinary search, `app:`, `type:`, `fav:`, `before:`, token removal, suggestions, key navigation and no blank flicker.

- [ ] **Step 9: Commit Task 8**

```bash
git add MacPasteHistory/App/AppDelegate.swift MacPasteHistory/ViewModels/ClipboardHistoryViewModel.swift \
  MacPasteHistory/Views/Search MacPasteHistory/Views/MainPanelView.swift \
  MacPasteHistory/Views/History MacPasteHistoryTests
git commit -m "feat: integrate responsive structured search"
```

**Gate:** current basic search remains simple; structured syntax and suggestions are optional; old query results cannot overwrite newer text.

---

# Task 9: Content Classifier, Layered Detection and Manual Override

**Dependencies:** Tasks 2 and 4.

**Files:**

- Create: `MacPasteHistory/ContentActions/ContentClassifier.swift`
- Create: `MacPasteHistory/ContentActions/ContentClassificationService.swift`
- Modify: `MacPasteHistory/Clipboard/ClipboardMonitor.swift`
- Modify: `MacPasteHistory/Database/ClipboardHistoryRepository.swift`
- Modify: `MacPasteHistory/Views/History/HistoryRowView.swift`
- Modify: `MacPasteHistory/ViewModels/ClipboardHistoryViewModel.swift`
- Create: `MacPasteHistoryTests/ContentClassifierTests.swift`
- Create: `MacPasteHistoryTests/ContentClassificationServiceTests.swift`
- Modify: `MacPasteHistoryTests/ClipboardMonitorTests.swift`

**Interfaces produced:**

```swift
struct ContentClassifier {
    static let currentVersion = 1
    func classifyFast(_ input: String, at date: Date = Date()) -> ContentDetectionResult
    func classifyComplete(_ input: String, at date: Date = Date()) -> ContentDetectionResult
}

actor ContentClassificationService {
    func classifyIfNeeded(item: ClipboardHistoryItem) async
    func effectiveType(for item: ClipboardHistoryItem) async -> DetectedContentType
}
```

### LOOP steps

- [ ] **Step 1: Add deterministic classifier tests**

Include exact fixtures for:

```text
JWT with valid JSON header/payload → jwt
three invalid dot segments → not jwt
JSON object/array → json
JSON scalar → plainText
https/file/ssh/git URL → url
bare example.com → plainText
valid 10-digit and 13-digit timestamp in 2000...2100 → timestamp
out-of-range digits → plainText
standard and URL-safe printable Base64 → base64
short/common English that happens to fit alphabet → plainText
SELECT ... FROM and UPDATE ... SET → sql in complete classifier
single word SELECT → plainText
command with flags/pipe/redirection/env variable → shell in complete classifier
single normal sentence → plainText
JWT wins before Base64
```

- [ ] **Step 2: Implement fast classifier**

Order is fixed:

```text
JWT → JSON → URL → Timestamp → Base64 → Plain Text
```

Use Foundation parsers first; regular expressions only for bounded structural checks. Base64 must require at least 8 characters, valid alphabet/padding, UTF-8 output and at least 85% printable characters.

- [ ] **Step 3: Implement complete classifier**

Call fast classification first. Only plain text continues to SQL and Shell multi-feature scoring. A score below the defined threshold remains `.plainText`. Keep scoring constants private and named.

- [ ] **Step 4: Integrate fast classification into capture**

Inject `ContentClassifier` into `ClipboardMonitor`. `saveText` receives the fast detection and stores it on insert. Duplicate capture may refresh automatic detection only when no manual override exists and stored `detectionVersion` is older than current.

Clipboard polling must not await complete classification.

- [ ] **Step 5: Implement idle/command fallback classification**

`ContentClassificationService` performs complete classification in an actor and calls repository update. It must skip records with `userOverrideType != nil` and current-version complete results.

Opening future command palette calls `effectiveType(for:)`, which performs the complete fallback if needed.

- [ ] **Step 6: Add manual override ViewModel API**

```swift
func setUserOverrideType(_ type: DetectedContentType?, for item: ClipboardHistoryItem)
```

After save, refresh the item/search so icon, `type:` results and recommendations use the override immediately.

- [ ] **Step 7: Add lightweight type icons**

Display icons only for JSON, JWT, URL, Base64, Timestamp, SQL and Shell. Plain text has no icon; image keeps its image preview. Clicking the icon will be wired to the command palette in Task 13. Add help/accessibility labels now.

- [ ] **Step 8: Run Task 9 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/ContentClassifierTests \
  -only-testing:MacPasteHistoryTests/ContentClassificationServiceTests \
  -only-testing:MacPasteHistoryTests/ClipboardMonitorTests test
```

- [ ] **Step 9: Commit Task 9**

```bash
git add MacPasteHistory/ContentActions/ContentClassifier.swift \
  MacPasteHistory/ContentActions/ContentClassificationService.swift \
  MacPasteHistory/Clipboard/ClipboardMonitor.swift MacPasteHistory/Database/ClipboardHistoryRepository.swift \
  MacPasteHistory/ViewModels/ClipboardHistoryViewModel.swift MacPasteHistory/Views/History/HistoryRowView.swift \
  MacPasteHistoryTests
git commit -m "feat: classify developer clipboard content"
```

**Gate:** fast capture remains nonblocking; complete classification is isolated; manual overrides are persistent and never overwritten.

---

# Task 10: Content Action Protocol, Registry and Core Actions

**Dependencies:** Task 9.

**Files:**

- Create: `MacPasteHistory/ContentActions/ContentAction.swift`
- Create: `MacPasteHistory/ContentActions/ContentActionResult.swift`
- Create: `MacPasteHistory/ContentActions/ContentActionRegistry.swift`
- Create: `MacPasteHistory/ContentActions/ContentActionExecutor.swift`
- Create: `MacPasteHistory/ContentActions/Actions/JSONContentActions.swift`
- Create: `MacPasteHistory/ContentActions/Actions/URLContentActions.swift`
- Create: `MacPasteHistory/ContentActions/Actions/Base64ContentActions.swift`
- Create: `MacPasteHistory/ContentActions/Actions/TextContentActions.swift`
- Create: `MacPasteHistoryTests/ContentActionRegistryTests.swift`
- Create: `MacPasteHistoryTests/JSONContentActionsTests.swift`
- Create: `MacPasteHistoryTests/URLContentActionsTests.swift`
- Create: `MacPasteHistoryTests/Base64ContentActionsTests.swift`
- Create: `MacPasteHistoryTests/TextContentActionsTests.swift`

**Interfaces produced:**

```swift
struct ContentActionID: RawRepresentable, Hashable, Codable {
    let rawValue: String
}

enum ContentSyntax: Equatable {
    case plainText
    case json
    case sql
    case jwt
}

struct ContentActionCopyVariant: Identifiable, Equatable {
    let id: String
    let titleKey: String
    let value: String
}

struct ContentActionResult: Equatable {
    let output: String
    let syntax: ContentSyntax
    let notices: [ContentActionNotice]
    let copyVariants: [ContentActionCopyVariant]
}

protocol ContentAction {
    var id: ContentActionID { get }
    var titleKey: String { get }
    var category: ContentActionCategory { get }
    var supportedTypes: Set<DetectedContentType> { get }
    func validate(input: String) -> ActionValidationResult
    func execute(input: String) throws -> ContentActionResult
}
```

Stable IDs:

```text
json.format
json.minify
json.validate
json.escape
json.unescape
url.encode-query-value
url.decode
url.extract-host
url.parse-query
base64.encode
base64.decode
base64.decode-url-safe
base64.validate
text.trim
text.remove-empty-lines
text.deduplicate-lines
text.single-line
text.uppercase
text.lowercase
text.markdown-code-block
```

### LOOP steps

- [ ] **Step 1: Add registry tests**

Assert stable ID uniqueness, lookup by ID, recommended actions by type, case-insensitive action-title search, and deterministic category/title ordering.

- [ ] **Step 2: Implement action validation/error model**

Use typed errors:

```swift
enum ContentActionError: Error, Equatable {
    case invalidInput(messageKey: String)
    case unsupportedInput(messageKey: String)
    case parseFailed(messageKey: String)
    case decodeFailed(messageKey: String)
    case nonUTF8Result(messageKey: String)
    case outOfRange(messageKey: String)
    case emptyResult(messageKey: String)
}
```

Action errors store localization keys, not prelocalized text.

- [ ] **Step 3: Implement and test JSON actions**

Exact output rules:

```text
format: JSONSerialization prettyPrinted + sortedKeys, 4-space output normalization
minify: no optional whitespace
validate: output a localized-result key through notice and preserve normalized JSON in output
escape: JSON string escaping without surrounding quotes
unescape: accepts with/without surrounding quotes and returns decoded string
```

Tests include nested objects, arrays, Chinese, emoji, invalid JSON and illegal escapes.

- [ ] **Step 4: Implement and test URL actions**

`encode-query-value` uses an allowed character set appropriate for one query parameter value. `parse-query` sorts by key while preserving repeated-key relative order and emits one `key = value` line per pair. `extract-host` rejects hostless input.

- [ ] **Step 5: Implement and test Base64 actions**

Normalize URL-safe alphabet and restore missing valid padding before decode. Reject non-UTF-8 and low-printability outputs. Validation returns a clear result without producing an empty output.

- [ ] **Step 6: Implement and test text actions**

Required exact semantics:

```text
trim: trim leading/trailing whitespace/newlines only
remove-empty-lines: remove lines whose trimmed form is empty; preserve other line text
deduplicate-lines: preserve first occurrence and original line text
single-line: collapse every whitespace run to one ASCII space
uppercase/lowercase: use current locale-independent Unicode transforms
markdown-code-block: three backticks + newline + input + newline + three backticks
```

- [ ] **Step 7: Run Task 10 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/ContentActionRegistryTests \
  -only-testing:MacPasteHistoryTests/JSONContentActionsTests \
  -only-testing:MacPasteHistoryTests/URLContentActionsTests \
  -only-testing:MacPasteHistoryTests/Base64ContentActionsTests \
  -only-testing:MacPasteHistoryTests/TextContentActionsTests test
```

- [ ] **Step 8: Commit Task 10**

```bash
git add MacPasteHistory/ContentActions MacPasteHistoryTests/*ContentAction*Tests.swift \
  MacPasteHistoryTests/JSONContentActionsTests.swift MacPasteHistoryTests/URLContentActionsTests.swift \
  MacPasteHistoryTests/Base64ContentActionsTests.swift MacPasteHistoryTests/TextContentActionsTests.swift
git commit -m "feat: add local clipboard content actions"
```

**Gate:** actions are pure, offline, independently tested and registered by stable IDs.

---

# Task 11: JWT, Timestamp, SQL, Shell and Syntax Highlighting

**Dependencies:** Task 10.

**Files:**

- Create: `MacPasteHistory/ContentActions/Actions/JWTContentAction.swift`
- Create: `MacPasteHistory/ContentActions/Actions/TimestampContentAction.swift`
- Create: `MacPasteHistory/ContentActions/Actions/SQLContentAction.swift`
- Create: `MacPasteHistory/ContentActions/Actions/ShellContentAction.swift`
- Create: `MacPasteHistory/ContentActions/Highlighting/ContentSyntaxHighlighter.swift`
- Modify: `MacPasteHistory/ContentActions/ContentActionRegistry.swift`
- Create: `MacPasteHistoryTests/JWTContentActionTests.swift`
- Create: `MacPasteHistoryTests/TimestampContentActionTests.swift`
- Create: `MacPasteHistoryTests/SQLContentActionTests.swift`
- Create: `MacPasteHistoryTests/ShellContentActionTests.swift`
- Create: `MacPasteHistoryTests/ContentSyntaxHighlighterTests.swift`

**Stable IDs:**

```text
jwt.inspect
timestamp.convert
sql.single-line
shell.quote-argument
```

### LOOP steps

- [ ] **Step 1: Implement JWT fixtures and tests**

Use deterministic unsigned sample segments; do not use a real secret. Assert:

```text
exactly three segments required
header/payload decode as Base64URL JSON objects
alg/typ/iss/sub/aud are extracted when present
iat/exp/nbf numeric dates become local, UTC and ISO 8601 values
expired, not expired and no-exp states are distinct
output always contains the signature-not-verified notice
copy variants include header JSON, payload JSON and full summary
signature is never verified
```

`JWTContentAction` receives `now` and timezone/calendar providers for deterministic tests.

- [ ] **Step 2: Implement timestamp conversion tests**

Test 10-digit seconds, 13-digit milliseconds, ISO 8601, `yyyy-MM-dd HH:mm:ss`, invalid input and out-of-range dates. Output copy variants:

```text
local
autc
iso8601
seconds
milliseconds
```

Use ID `utc` rather than `autc` in code; the above list describes five variants and the implementation must name it `utc`.

- [ ] **Step 3: Implement SQL single-line tokenizer**

Use a small state machine with states:

```swift
normal
singleQuotedString
doubleQuotedIdentifier
backtickIdentifier
lineComment
blockComment
```

Collapse whitespace only in `normal`; preserve all characters inside strings and comments. Tests must cover escaped quotes and comment boundaries.

- [ ] **Step 4: Implement Shell single-argument quoting**

Exact transformation:

```swift
"abc"       -> "'abc'"
"a b"       -> "'a b'"
"it's"      -> "'it'\\''s'"
""          -> "''"
```

The action only returns text and contains no process execution API.

- [ ] **Step 5: Implement lightweight syntax highlighter**

`ContentSyntaxHighlighter` returns an `AttributedString` and semantic token ranges. Support:

```text
JSON: key, string, number, boolean, null
JWT: JSON rules plus special semantic marking for iat/exp/nbf keys
SQL: keyword, string, number, line comment, block comment
```

The highlighter must not hardcode display colors. `SyntaxHighlightedTextView` chooses system semantic styles later.

- [ ] **Step 6: Register advanced actions**

Recommended mappings:

```text
jwt       → jwt.inspect
 timestamp → timestamp.convert
sql       → sql.single-line
shell     → shell.quote-argument
```

Other actions remain searchable in the full command palette.

- [ ] **Step 7: Run Task 11 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/JWTContentActionTests \
  -only-testing:MacPasteHistoryTests/TimestampContentActionTests \
  -only-testing:MacPasteHistoryTests/SQLContentActionTests \
  -only-testing:MacPasteHistoryTests/ShellContentActionTests \
  -only-testing:MacPasteHistoryTests/ContentSyntaxHighlighterTests test
```

- [ ] **Step 8: Commit Task 11**

```bash
git add MacPasteHistory/ContentActions MacPasteHistoryTests/JWTContentActionTests.swift \
  MacPasteHistoryTests/TimestampContentActionTests.swift MacPasteHistoryTests/SQLContentActionTests.swift \
  MacPasteHistoryTests/ShellContentActionTests.swift MacPasteHistoryTests/ContentSyntaxHighlighterTests.swift
git commit -m "feat: add advanced developer transformations"
```

**Gate:** JWT is inspection-only; date results are deterministic; SQL/Shell actions never execute input; highlighting is presentation-only.

---

# Task 12: Action Session, Usage Attribution and Derived Record Save

**Dependencies:** Tasks 4, 10 and 11.

**Files:**

- Create: `MacPasteHistory/ContentActions/ActionSessionStep.swift`
- Create: `MacPasteHistory/ContentActions/ActionSession.swift`
- Create: `MacPasteHistory/ViewModels/ContentActionPanelViewModel.swift`
- Modify: `MacPasteHistory/Services/PasteCommandService.swift`
- Modify: `MacPasteHistory/ViewModels/ClipboardHistoryViewModel.swift`
- Create: `MacPasteHistoryTests/ActionSessionTests.swift`
- Create: `MacPasteHistoryTests/ContentActionPanelViewModelTests.swift`
- Modify: `MacPasteHistoryTests/ClipboardHistoryViewModelTests.swift`
- Modify: existing PasteCommandService tests discovered by `rg -n "PasteCommandService|PasteCommandSending" MacPasteHistoryTests`

**Interfaces produced:**

```swift
struct ActionSessionStep: Identifiable, Equatable {
    let id: UUID
    let actionID: ContentActionID
    let actionTitleKey: String
    let input: String
    let originalResult: ContentActionResult
    var editedOutput: String
    let error: ContentActionError?
}

struct ActionSession: Equatable {
    let sourceItem: ClipboardHistoryItem
    private(set) var steps: [ActionSessionStep]
    private(set) var currentIndex: Int?

    mutating func append(action: any ContentAction, result: ContentActionResult, input: String)
    mutating func updateEditedOutput(_ text: String)
    mutating func restoreCurrentOutput()
    mutating func moveBack()
    mutating func clear()
    var currentOutput: String { get }
    var actionSummary: String { get }
}
```

### LOOP steps

- [ ] **Step 1: Add ActionSession tests**

Assert:

```text
first action uses original item content
next action uses current edited output
editing marks current step as edited
restore resets only current step output
moveBack restores previous step
adding after moveBack removes the abandoned future branch
summary joins localized-independent action title keys in order
clear destroys every step
```

- [ ] **Step 2: Define panel ViewModel states**

```swift
enum ContentActionPanelState: Equatable {
    case closed
    case choosing
    case executing(ContentActionID)
    case previewing
    case failed(ContentActionError)
}
```

`ContentActionPanelViewModel` owns command search, recommended/all actions, selected action, `ActionSession`, copy variants, notices and edited text.

- [ ] **Step 3: Refactor paste command result**

Change:

```swift
protocol PasteCommandSending {
    func sendCommandVPaste()
}
```

to:

```swift
protocol PasteCommandSending {
    func sendCommandVPaste() -> Bool
}

final class PasteCommandService {
    func sendPasteCommand() -> Bool
}
```

Return true only when accessibility is already granted and both key events are created and posted. This is “dispatch success”, not proof that the target application consumed the paste.

- [ ] **Step 4: Implement usage attribution paths**

Rules:

```text
copy original/result succeeds → recordReuseCopy(source history ID)
direct paste writes clipboard, dispatch succeeds → recordPaste(source history ID)
clipboard write succeeds, dispatch fails → recordReuseCopy only and show manual-paste message
save derived record → no reuse/paste increment on source
preview/transform/edit → no usage increment
```

For a derived source item, usage is attributed to that selected item, not recursively to its ancestor.

- [ ] **Step 5: Implement save-derived flow**

Build `DerivedClipboardRecordRequest` from:

```text
current edited output
selected source item ID/hash
last action stable ID
full action summary
DerivedSourcePreviewBuilder result
fresh fast content detection
```

After save, refresh search and select the returned canonical item. If the hash already existed, show a message that the existing record was reused.

- [ ] **Step 6: Add ViewModel tests for copy/paste/save**

Use fake writer, fake paste sender and repository test database. Verify success and failure statistics exactly, including the manual-paste fallback.

- [ ] **Step 7: Run Task 12 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/ActionSessionTests \
  -only-testing:MacPasteHistoryTests/ContentActionPanelViewModelTests \
  -only-testing:MacPasteHistoryTests/ClipboardHistoryViewModelTests test
```

Also run the exact discovered PasteCommandService test class.

- [ ] **Step 8: Commit Task 12**

```bash
git add MacPasteHistory/ContentActions/ActionSession.swift \
  MacPasteHistory/ContentActions/ActionSessionStep.swift \
  MacPasteHistory/ViewModels/ContentActionPanelViewModel.swift \
  MacPasteHistory/ViewModels/ClipboardHistoryViewModel.swift \
  MacPasteHistory/Services/PasteCommandService.swift MacPasteHistoryTests
git commit -m "feat: manage editable clipboard action sessions"
```

**Gate:** action chains are session-only; edited output is the value copied/pasted/saved; usage counters reflect the successful path.

---

# Task 13: Command Palette, Right Preview Panel and Progressive UI

**Dependencies:** Tasks 7, 8 and 12.

**Files:**

- Create: `MacPasteHistory/Views/Actions/ContentActionCommandPalette.swift`
- Create: `MacPasteHistory/Views/Actions/ContentActionPreviewView.swift`
- Create: `MacPasteHistory/Views/Actions/SyntaxHighlightedTextView.swift`
- Modify: `MacPasteHistory/Views/MainPanelView.swift`
- Modify: `MacPasteHistory/Views/History/HistoryRowView.swift`
- Modify: `MacPasteHistory/Views/History/HistoryDetailView.swift`
- Modify: `MacPasteHistory/App/HistoryPanelWindow.swift`
- Modify: `MacPasteHistory/App/AppDelegate.swift`
- Create: `MacPasteHistoryTests/ContentActionPanelLayoutTests.swift`
- Create: `MacPasteHistoryTests/ContentActionKeyboardPolicyTests.swift`
- Modify: existing panel interaction tests.

### LOOP steps

- [ ] **Step 1: Add panel sizing policy tests**

Create pure policy methods:

```swift
static let defaultSize = NSSize(width: 880, height: 620)
static let expandedPreferredWidth: CGFloat = 1_240
static let minimumScreenSideInset: CGFloat = 24

static func layoutMode(availableWidth: CGFloat) -> HistoryPanelLayoutMode
static func panelSize(for mode: HistoryPanelLayoutMode, screenVisibleFrame: NSRect) -> NSSize
```

Assert expanded mode only when the screen can preserve both 24pt side insets; otherwise use overlay mode at existing width.

- [ ] **Step 2: Implement command palette entry points**

Entry points share the same `ContentActionPanelViewModel`:

```text
Command + K on selected record opens full palette
row More menu shows recommended actions plus “All Actions…”
type icon opens recommended palette
```

The right-click/menu list must not duplicate action execution logic.

- [ ] **Step 3: Implement palette keyboard behavior**

```text
Up/Down moves action selection
Enter executes selected action
Esc closes palette first
typing filters localized action titles
```

When palette closes, focus returns to the previous list/result editor target.

- [ ] **Step 4: Implement right preview panel**

Expanded mode layout:

```text
left: existing search, ribbon, timeline, footer
right: action title/type/notices, original/result tabs, editable result, steps, fixed actions
```

Overlay mode replaces the history content region but preserves the panel header and an explicit Back button.

Use system split/layout primitives; do not create a separate titled window or sheet.

- [ ] **Step 5: Implement editable result and highlighter**

Use a plain text editing control for the authoritative output. When syntax highlighting is enabled, ensure edits remain possible and the copied value is the plain string. If a single SwiftUI control cannot reliably combine editing and attributed display on macOS 14, use an `NSViewRepresentable` wrapping `NSTextView`, with the string as the single source of truth.

Only JSON, JWT and SQL request highlighted attributes; all other output uses monospaced plain text.

- [ ] **Step 6: Implement footer actions and shortcuts**

Buttons:

```text
Copy Result
Paste Result
Save as New Record
```

Shortcuts:

```text
Command + C copies result when result editor/panel is active
Command + Enter pastes result
Esc closes palette → preview → panel in that order
```

The existing Enter-on-list direct-paste behavior remains unchanged when no action UI is open.

- [ ] **Step 7: Add origin and type indicators**

Derived rows display a lightweight icon with `derivedActionSummary` help text. Deleted origins display “Source record deleted” in detail. Developer type icons use the Task 9 policy. No full labels are added to ordinary rows.

- [ ] **Step 8: Wire type override control into details/preview**

Provide a compact type picker with “Automatic” plus supported types. Changing it calls the ViewModel repository API and refreshes recommendations/search.

- [ ] **Step 9: Run Task 13 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/ContentActionPanelLayoutTests \
  -only-testing:MacPasteHistoryTests/ContentActionKeyboardPolicyTests test
```

Then:

```bash
scripts/preview-release-app.sh --seed-preview-data
```

Manual gate matrix:

```text
wide screen expands panel and retains list
narrow screen uses overlay mode
Command+K, menu and type icon open the same actions
JSON result can be edited/restored/copied/pasted/saved
Base64 decode → JSON format can move back and branch
Esc closes in the required order
full-screen invocation still opens in the current Space
outside click still dismisses when no modal layer is active
```

- [ ] **Step 10: Commit Task 13**

```bash
git add MacPasteHistory/Views/Actions MacPasteHistory/Views/MainPanelView.swift \
  MacPasteHistory/Views/History MacPasteHistory/App/HistoryPanelWindow.swift \
  MacPasteHistory/App/AppDelegate.swift MacPasteHistoryTests
git commit -m "feat: add progressive clipboard action panel"
```

**Gate:** ordinary users can ignore all advanced UI; existing direct paste remains one action; action preview does not break fullscreen/nonactivating panel behavior.

---

# Task 14: Manual Local OCR and Search/Action Integration

**Dependencies:** Tasks 4, 9 and 13.

**Files:**

- Create: `MacPasteHistory/OCR/OCRResult.swift`
- Create: `MacPasteHistory/OCR/OCRService.swift`
- Create: `MacPasteHistory/ViewModels/OCRViewModel.swift`
- Create: `MacPasteHistory/Views/OCR/OCRResultView.swift`
- Modify: `MacPasteHistory/Views/History/HistoryDetailView.swift`
- Modify: `MacPasteHistory/Views/Actions/ContentActionPreviewView.swift`
- Modify: `MacPasteHistory/ViewModels/ClipboardHistoryViewModel.swift`
- Modify: `MacPasteHistory/App/AppDelegate.swift`
- Create: `MacPasteHistoryTests/OCRServiceTests.swift`
- Create: `MacPasteHistoryTests/OCRViewModelTests.swift`
- Modify: `MacPasteHistoryTests/SearchCandidateProviderTests.swift`

**Interfaces produced:**

```swift
struct OCRResult: Equatable {
    let text: String
    let observationsCount: Int
    let languages: [String]
}

protocol OCRServicing {
    func recognizeText(in imageURL: URL) async throws -> OCRResult
}

final class OCRService: OCRServicing

@MainActor
final class OCRViewModel: ObservableObject {
    @Published private(set) var state: OCRViewState
    @Published var editableText: String
    func recognize(item: ClipboardHistoryItem) async
    func save(item: ClipboardHistoryItem) async
    func cancel()
    func retry(item: ClipboardHistoryItem) async
}
```

### LOOP steps

- [ ] **Step 1: Add OCR service abstraction tests**

Separate Vision request execution behind an injectable protocol so unit tests can provide recognized observations without depending on OCR accuracy. Test ordering observations top-to-bottom, left-to-right and joining lines with newline.

- [ ] **Step 2: Implement Vision service**

Use:

```swift
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
```

Read the image from the app-managed file URL, execute off the main actor, and map failures to stable codes:

```text
imageMissing
imageDecodeFailed
visionFailed
noTextFound
```

- [ ] **Step 3: Add OCR ViewModel tests**

Use fake service/repository. Assert:

```text
recognize transitions idle → recognizing → editing
recognized text is editable before save
cancel does not change repository
save persists edited text, marks recognized and refreshes search
failure preserves prior stored OCR text and allows retry
repeated click while recognizing does nothing
```

- [ ] **Step 4: Implement OCR UI**

Only image details show “Recognize Text”. During recognition show progress and disable repeat. After recognition show editable text plus Save/Cancel. Saved OCR text can open the same action palette, with classifier recommendations based on OCR content.

- [ ] **Step 5: Integrate search**

After save, `searchable_text` contains OCR text. Add an integration test that saves OCR text to an image and finds it by keyword while `type:image` still includes the record.

Search row presentation keeps the thumbnail and displays an OCR text excerpt when the search term matched OCR.

- [ ] **Step 6: Integrate type behavior**

The image record’s storage type remains image. Its `effectiveDetectedType` for list filtering remains image unless the user is operating on OCR text; action recommendations use the OCR detection result stored in `detected_type`. To avoid ambiguity in search:

```text
type:image filters storage content type image
type:json/sql/etc. can also match an image whose OCR detected type is that value
```

Implement this rule in `SearchFilterMerger`/candidate SQL tests.

- [ ] **Step 7: Run Task 14 verification**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:MacPasteHistoryTests/OCRServiceTests \
  -only-testing:MacPasteHistoryTests/OCRViewModelTests \
  -only-testing:MacPasteHistoryTests/SearchCandidateProviderTests test
```

Manual test with a synthetic screenshot containing English, simplified Chinese and traditional Chinese. Confirm no network activity and no automatic historical scan.

- [ ] **Step 8: Commit Task 14**

```bash
git add MacPasteHistory/OCR MacPasteHistory/ViewModels/OCRViewModel.swift \
  MacPasteHistory/Views/OCR MacPasteHistory/Views/History/HistoryDetailView.swift \
  MacPasteHistory/Views/Actions/ContentActionPreviewView.swift \
  MacPasteHistory/ViewModels/ClipboardHistoryViewModel.swift MacPasteHistory/App/AppDelegate.swift \
  MacPasteHistory/Search MacPasteHistoryTests
git commit -m "feat: add manual local image text recognition"
```

**Gate:** OCR is user-triggered, editable, local and cancellable; save is explicit; image identity and search/action behavior are correct.

---

# Task 15: Localization, Accessibility, Documentation, Release QA and Final Gate

**Dependencies:** Tasks 1–14.

**Files:**

- Modify: `MacPasteHistory/Resources/en.lproj/Localizable.strings`
- Modify: `MacPasteHistory/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `MacPasteHistory/Resources/zh-Hant.lproj/Localizable.strings`
- Modify: all new/changed SwiftUI views requiring accessibility metadata
- Modify: `docs/architecture/overall-architecture.md`
- Create: `docs/architecture/database-schema.md`
- Modify: `docs/user-guide.md`
- Modify: `docs/privacy-policy.md`
- Modify: `docs/changelog/CHANGELOG.md`
- Modify: `docs/release/manual-qa-record.md`
- Modify: `docs/release/RELEASE_PREP_GUIDE.md`
- Modify: `scripts/generate-manual-qa-fixtures.swift`
- Modify: `scripts/verify-manual-qa-fixtures.sh`
- Modify: `scripts/release-smoke-test.sh`
- Create: `MacPasteHistoryTests/LocalizationCoverageTests.swift`
- Create: `MacPasteHistoryTests/AccessibilityPresentationTests.swift`
- Create: `MacPasteHistoryTests/EndToEndFeatureFlowTests.swift`

### LOOP steps

- [ ] **Step 1: Inventory localization keys**

Add a test that loads all three `.strings` files and asserts identical key sets for new feature keys. Include:

```text
search prefixes/suggestions/errors
type names and Automatic
action names/categories/errors
copy/paste/save buttons and edited/restored states
JWT signature warning and expiry states
timestamp result labels
OCR states/errors/buttons
derived origin/deleted-source labels
manual paste fallback
```

- [ ] **Step 2: Complete accessibility semantics**

Tests/pure presentation policies must verify labels exist for:

```text
type icon
derived icon
search token and invalid token removal
action list selection
result edited status
JWT expired/not-expired and signature warning
OCR recognizing/failed/recognized
copy variants
```

Use labels/hints/values; color is never the only state cue.

- [ ] **Step 3: Add end-to-end integration tests**

Build one temporary database and exercise:

```text
capture Base64 JSON
search through structured syntax
execute Base64 decode then JSON format
edit output
save derived record
copy derived output and record reuse count
delete source and confirm derived relation is null but summary remains
save OCR text to image and find it by keyword
```

Use fakes for paste command and OCR; no AppKit UI automation is required in this test.

- [ ] **Step 4: Update architecture/database docs**

Document module boundaries, writer/read-only SQLite connections, V3 columns, foreign keys, event aggregation, search pipeline, action session lifecycle and OCR flow. Include Mermaid diagrams where they improve clarity.

- [ ] **Step 5: Update user/privacy/changelog docs**

User guide must include examples:

```text
app:terminal type:shell docker
fav:true
before:7d
Base64 decode → JSON format
JWT warning
manual OCR
```

Privacy policy states all new processing is local, OCR is manual, local database/image files remain unencrypted at app level, and JWT parsing is not trust verification.

- [ ] **Step 6: Extend QA fixtures and validators**

Generate synthetic fixtures for:

```text
valid/invalid JSON
standard and URL-safe Base64
expired and unexpired unsigned JWT samples
10/13 digit timestamps
SQL with quoted whitespace
Shell argument with single quote
OCR screenshot with English/简体/繁體 text
structured search source labels
```

Validator checks markers, expected dimensions and absence of real secrets/user data.

- [ ] **Step 7: Extend release smoke test**

At minimum automate database-level validation for:

```text
migration V3 columns/tables
repeat capture count/event
structured candidate query
usage counters
derived record SET NULL behavior
OCR searchable_text persistence
```

Do not attempt to automate Vision recognition or CGEvent paste consumption in the shell smoke test; retain those in manual QA.

- [ ] **Step 8: Run complete unit test suite**

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  test
```

Expected: zero failures.

- [ ] **Step 9: Run static privacy and release checks**

```bash
scripts/scan-privacy-log-safety.sh
scripts/verify-privacy-usage-descriptions.sh
scripts/verify-release-entitlements.sh
scripts/verify-supported-macos-targets.sh
scripts/verify-release-version-build.sh
scripts/verify-manual-qa-fixtures.sh
```

Expected: zero blockers; no log statement contains clipboard/OCR/JWT/action output variables.

- [ ] **Step 10: Run Release build, smoke and install preflight**

```bash
scripts/release-smoke-test.sh
scripts/release-install-preflight.sh
```

Expected: both pass using isolated app support data.

- [ ] **Step 11: Run preview/manual QA**

```bash
scripts/preview-release-app.sh --seed-preview-data
scripts/start-manual-release-qa-session.sh
```

Fill the generated session’s manual record for:

```text
ordinary and structured search
search suggestions/tokens/highlight
wide and narrow action panel
all content action categories
JWT warning and expiry
editable action chain
copy/direct paste/save statistics
manual OCR and OCR search
capture event detail/summary
derived source deletion
full-screen invocation and accessibility fallback
```

- [ ] **Step 12: Generate final readiness report**

Internal QA without a distribution identity may use `--allow-adhoc`, but the final distribution gate may not:

```bash
scripts/release-readiness-report.sh \
  --manual-record build/manual-release-qa-session/<timestamp>-<commit>/manual-qa-record.md \
  --qa-session build/manual-release-qa-session/<timestamp>-<commit> \
  --output build/release-readiness-report.md \
  --json-output build/release-readiness-report.json \
  --strict-final
```

Expected final status: no blockers and no warnings under `--strict-final`. If signing is the only unavailable external prerequisite, record it explicitly and do not claim formal distribution readiness.

- [ ] **Step 13: Perform final diff self-review**

Run:

```bash
git diff --check
git status --short
rg -n "print\(|TODO|FIXME|try\?|catch \{\s*\}" MacPasteHistory MacPasteHistoryTests
```

Review every match. Existing intentional `try?` must be justified by existing behavior; new core search/action/OCR/database paths must not swallow errors.

- [ ] **Step 14: Commit Task 15**

```bash
git add MacPasteHistory/Resources MacPasteHistory/Views MacPasteHistoryTests \
  docs scripts
git commit -m "docs: complete enhanced search and actions release gate"
```

**Gate:** full test suite, smoke test, install preflight, privacy scans, localization coverage, manual QA and readiness report are complete; docs match implementation.

---

## 5. Final Integration Review

After Task 15, Codex performs one final review-only LOOP. No feature additions are allowed.

### Spec coverage matrix

Codex must report each PRD requirement group and the implementing task/commit:

```text
SEARCH-001...007
CLASSIFY-001...006
ACTION-001...TIMESTAMP/TEXT/SHELL/SQL
PREVIEW-001...006
USAGE-001
DERIVED-001...003
OCR-001...005
EVENT-001
privacy/accessibility/performance/testing/DoD
```

Any uncovered item reopens the task that owns it; do not create an unplanned catch-all implementation commit.

### Type/signature consistency check

Verify these names remain consistent across production and tests:

```text
DetectedContentType
ContentDetectionResult
ParsedSearchQuery
SearchCandidateRequest
RankedSearchResult
ContentActionID
ContentActionResult
ActionSession
DerivedClipboardRecordRequest
OCRResult
OCRStatus
```

### Final build commands

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -configuration Debug -destination 'platform=macOS,arch=arm64' build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -configuration Release -destination 'generic/platform=macOS' build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' test
```

### Completion report template

```text
Feature branch:
Task commits:
Full test result:
Debug build result:
Release build result:
Smoke test result:
Install preflight result:
Privacy scan result:
Manual QA session:
Readiness report:
PRD coverage gaps: none / exact list
Distribution signing limitation: none / exact limitation
```

Only after this report is complete may the branch proceed to code review and merge.

---

## 6. Codex 启动提示词

将下面内容直接交给 Codex：

```text
你正在开发 GitHub 仓库 peibinliang/MacPasteHistory。

先阅读：
1. AI_CODING_RULES.md
2. docs/superpowers/specs/2026-08-05-enhanced-search-and-content-actions-prd.md
3. docs/superpowers/plans/2026-08-05-enhanced-search-and-content-actions-implementation-plan.md
4. 当前任务列出的相关代码和测试。

严格按 Implementation Plan 的 LOOP 协议工作：Locate → Outline → Operate → Prove。
本轮只执行计划中第一个未完成任务，不得提前实现后续任务。
先输出 LOOP Brief 和接口/测试计划，再写失败测试；确认红灯后实现最小代码。
完成任务要求的定向测试、git diff --check、自审和提交后，输出门禁报告并停止。
不得加入 PRD 范围外功能，不得把剪贴板正文、JWT、OCR 或动作输出写入日志，不得通过删除测试或跳过检查结束任务。
```
