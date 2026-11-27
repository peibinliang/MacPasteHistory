# 粘易崩溃与严重卡顿修复记录（v1.0.5 Hotfix）

> 日期：2026-11-27 | 基线版本：`v1.0.5 (Build 7)` | 分支：`hotfix/v1.0.6`

## 1. 问题现象

本机安装的 `/Applications/粘易.app`（`com.peibin.MacPasteHistory`，版本 `1.0.5 (7)`）在长期常驻运行后反复出现两类问题：

1. **偶发闪退与设置动作失效**：
   - 在历史搜索栏快速编辑/清空搜索词或点击移除结构化搜索标签（如 `type:json`、`app:...`）时偶发 `String.Index` 越界陷阱闪退。
   - 在设置页切换语言并点击“立即重启”时，应用退出但未重新拉起（表现如点击后直接闪退消失）。
   - 在历史浮窗弹出删除确认框或详情弹窗时，父级非激活 `NSPanel` 可能因 `resignKey()` 被提前 `orderOut` 关闭。
   - 主面板空态点击“打开设置”无响应。
2. **严重卡顿、HID 无响应与内存暴涨**：
   - 系统诊断报告（`粘易_2026-11-26-092326.cpu_resource.diag` 与 `spindump`）记录进程处于 `Unresponsive`，152 秒内消耗 90 秒 CPU，`slow hid response` 达 `30.8s`，内存从 `328 MB` 暴涨至 `1,093 MB`（峰值 `1,265.59 MB`）。
   - 本机容器库因应用连续运行 18 天未重启而未执行仅在启动阶段运行的 `DataCleanupService`，文本记录累积至 `1,525` 条（单条最大 `217,622` 字符）、图片累积至 `287` 张（`124 MB`）。

## 2. 影响范围

- 影响版本：`v1.0.0` – `v1.0.5 (Build 7)`。
- 影响模块：搜索栏与结构化查询词元、剪贴板后台轮询与分类/敏感检测、历史时间线列表与图片预览、主面板与设置窗口生命周期、语言切换重启逻辑、本地清理调度。

## 3. 根因分析

1. **`String.Index` 跨字符串切片越界崩溃**：
   - `SearchToken` 仅保存解析时的 `Range<String.Index>`。当 SwiftUI `TextField` 双向绑定先一步缩短或清空 `searchText`，而 `searchTokens` 仍持有上一轮解析范围时，`SearchBarView` 中的 `String(text[token.range])` 与 `ClipboardHistoryViewModel.removeSearchToken(_:)` 直接使用旧索引切片新字符串触发 fatal trap。
2. **历史浮窗每次呼出全量重建根视图与同步主线程查库**：
   - `AppDelegate.openMainPanel()` 每次快捷键/状态栏呼出都会新建 `ClipboardHistoryViewModel`、`ContentActionPanelViewModel`、`PasteCoordinator` 并重写 `NSHostingView.rootView`，且同步在主线程拉取历史记录与全表 `GROUP BY` 来源列表；即使面板隐藏，后台每次复制仍触发主线程重载数据库。
3. **非惰性列表、分页风暴与无缓存原图解码导致内存暴涨**：
   - `HistoryTimelineView` 使用非惰性 `VStack` 一次性实例化全部行；分页判断 `index == section.items.count - 1` 未限制最后一个时间分组，导致“最近 / 今天”分组末尾出现时连续触发分页拉取。
   - `HistoryImagePreview` 在列表和详情中每次重绘都调用无缓存的 `NSImage(contentsOfFile:)`，全尺寸解码大图导致内存飙升至 `1.26 GB`。
   - `MainPanelView.body` 每次状态刷新都会在主线程重算时间线分组、来源去重、`NSWorkspace` 应用图标、`L10n` `.lproj` Bundle 查找及多实例 `DateFormatter`；`HistoryDisplayFormatter.preview(for:)` 对 `217 KB` 单行长文本执行全量拷贝扫描。
4. **超长文本灾难性正则回溯与主线程重度采集**：
   - `ContentClassifier` 中 `shellFlagRegex`（`\S+\s+--?\w+`）未锚定词首且未使用占有量词，遇到 `217 KB` 无空格单行文本会产生 $O(N^2)$（百亿级步数）ICU 正则回溯，直接锁死主线程数十秒；`shellEnvCommandRegex` 中的 `=.*\s+\S+` 同样存在回溯放大。
   - `ClipboardMonitor` 每 `0.5s` 在主线程同步执行图片解码/PNG 重编码、`NSImage.lockFocus()` 缩略图绘制、SHA-256、敏感检测、内容分类与 SQLite 事务写入。
5. **长期不退出运行缺少运行期定期清理**：
   - 菜单栏常驻应用 `LSUIElement` 数周不退出时，`performStartupCleanup()` 从不再次运行，超限文本与图片无法淘汰。
6. **App Sandbox 下 `/bin/sh` 重启受限**：
   - `AppRelauncher` 仅通过 `/bin/sh -c "sleep 0.5; /usr/bin/open -n ..."` 重启，在沙箱环境下子进程受阻导致旧进程 `terminate` 后新实例未能拉起。

## 4. 修复方案

1. **搜索词元安全切片与移除**：
   - 在 `SearchToken` 中缓存解析时的 `rawText` 并提供带边界与 `unicodeScalars` 校验的 `displayTitle(in:)`；`SearchBarView` 与 `removeSearchToken(_:)` 在文本不同步时安全重解析或回退，消除 `String.Index` 崩溃。
   - 移除 `HistorySourceOption.title` 中唯一的生产代码强制解包 `appName!`。
2. **面板失焦保护、沙箱安全重启与空态设置入口**：
   - `HistoryPanelWindow.resignKey()` 增加 `NSApp.modalWindow` 与 `childWindows` 判断，并在 `orderOut` 时通过 `onDidOrderOut` 通知 ViewModel 进入隐藏态。
   - `AppRelauncher.relaunchAndTerminate` 优先通过 `NSWorkspace.shared.openApplication`（`createsNewApplicationInstance = true`）启动新实例后再退出旧实例，失败时回退原脚本方案。
   - 补齐 `MainPanelView` 的 `openSettingsAction` 回调。
3. **复用单实例 ViewModel、惰性时间线与下采样图片缓存**：
   - `AppDelegate` 复用单实例 `ClipboardHistoryViewModel`、`ContentActionPanelViewModel`、`SettingsViewModel` 与 `DynamicPasteTarget`；面板隐藏时暂停后台通知驱动的 UI 查库，并在关闭面板时自动裁剪回首页大小（`50` 条）。
   - 新增 `DatabaseHistoryListSnapshotLoader` 使用只读 SQLite 连接异步加载列表快照。
   - `HistoryTimelineView` 切换为 `LazyVStack`，通过 `shouldTriggerLoadMore` 严格限制仅在最后一个分组最后一行触发分页，且 `.onHover` 仅在选中项变化时写入状态。
   - 新增 `PreviewImageCache`（基于 `ImageIO` 按显示尺寸下采样 + `NSCache` 容量上限控制 + 应用图标缓存），并在删除/清空/重建缩略图时主动驱逐缓存。
   - 新增 `LocalizationBundleCache`、`SharedHistoryDisplayFormatter`（对超长文本限制前 `1,024` 字符常数级预览截断）以及 `ContentActionPanelViewModel` 推荐动作字典预计算，移除 `MainPanelView` 中未使用的 `Legacy*` 视图代码。
4. **消除正则灾难性回溯、后台采集队列与运行期定期清理**：
   - 将 `ContentClassifier` 与 `SensitiveContentDetector` 正则改为静态预编译，使用锚定边界与占有量词（如 `(?:^|\s)\S++\s++--?\w+`、`(?m)(?:^|\s)[A-Za-z_][A-Za-z0-9_]*+=\S*+\s++\S+`），并对分类检查窗口做 `65,536` 字节上限裁剪，使 `220 KB` 单行文本分类耗时从分钟级降至毫秒级。
   - `ClipboardReader` 与 `ImageStorageService` 全面切换至线程安全的 `ImageIO`（`CGImageSource` / `CGImageDestination`），移除非线程安全的 `NSImage.lockFocus()`。
   - `ClipboardMonitor` 定时器路径仅在主线程读取 `changeCount`、隐私状态与原始剪贴板快照，将图片转码、缩略图生成、Hash、敏感检测、内容分类与 SQLite 写入派发至串行 `.utility` 队列 `captureQueue`，保留 `pollOnce()` 同步语义兼容既有调用方。
   - `DatabaseConnection` 引入 `NSRecursiveLock`（`synchronized`）保护连接级句柄与语句生命周期，保持默认 `DELETE` 日志模式与 `1,000 ms` `busy_timeout` 不变。
   - 新增 `PeriodicCleanupController`，每累计 `50` 次成功捕获或间隔满 `30` 分钟在后台自动执行一次 `DataCleanupService` 清理。

## 5. 新增内部默认参数说明

以下内部运行期参数集中定义于 `DefaultSettings`，无需用户配置，立即生效：

| 参数名称 | 常量名 | 类型 | 默认值 | 生效范围 | 说明 |
|---|---|---|---|---|---|
| 运行期定期清理时间间隔 | `periodicCleanupInterval` | `TimeInterval` | `1800`（30 分钟） | `ClipboardMonitor` | 距上次清理达到该时长且发生新捕获时后台执行清理 |
| 运行期定期清理捕获阈值 | `periodicCleanupCaptureThreshold` | `Int` | `50` | `ClipboardMonitor` | 累计捕获达到该次数时后台执行清理 |
| 分类检查最大字节数 | `classificationMaxInspectionCharacters` | `Int` | `65536` | `ContentClassifier` | 限制超大文本分类扫描前缀范围 |
| 预览图片缓存条数上限 | `previewImageCacheCountLimit` | `Int` | `200` | `PreviewImageCache` | 控制内存缓存解码图片数量 |
| 预览图片缓存字节上限 | `previewImageCacheByteLimit` | `Int` | `33554432`（32 MB） | `PreviewImageCache` | 控制内存缓存估算像素占用上限 |
| 来源应用图标缓存上限 | `appIconCacheCountLimit` | `Int` | `64` | `PreviewImageCache` | 缓存 `NSWorkspace` 应用图标避免重复查询 |

## 6. 涉及文件

- `MacPasteHistory/App/AppDelegate.swift`
- `MacPasteHistory/App/HistoryPanelWindow.swift`
- `MacPasteHistory/Clipboard/ClipboardCaptureContext.swift`
- `MacPasteHistory/Clipboard/ClipboardMonitor.swift`
- `MacPasteHistory/Clipboard/ClipboardReader.swift`
- `MacPasteHistory/Clipboard/TextHashService.swift`
- `MacPasteHistory/ContentActions/ContentClassifier.swift`
- `MacPasteHistory/Database/AITokenUsageRepository.swift`
- `MacPasteHistory/Database/ClipboardHistoryRepository.swift`
- `MacPasteHistory/Database/DatabaseConnection.swift`
- `MacPasteHistory/Models/ClipboardContentType.swift`
- `MacPasteHistory/Models/ClipboardHistoryItem.swift`
- `MacPasteHistory/Models/ClipboardImageCandidate.swift`
- `MacPasteHistory/Models/ClipboardImageFormat.swift`
- `MacPasteHistory/Models/DetectedContentType.swift`
- `MacPasteHistory/Models/HistoryQuery.swift`
- `MacPasteHistory/Models/OCRStatus.swift`
- `MacPasteHistory/Models/StoredClipboardImage.swift`
- `MacPasteHistory/Search/ParsedSearchQuery.swift`
- `MacPasteHistory/Search/SearchQueryParser.swift`
- `MacPasteHistory/Services/AppRelauncher.swift`
- `MacPasteHistory/Services/DataCleanupService.swift`
- `MacPasteHistory/Services/ImageStorageService.swift`
- `MacPasteHistory/Services/L10n.swift`
- `MacPasteHistory/Services/PasteCoordinator.swift`
- `MacPasteHistory/Services/PreviewImageCache.swift`（新增）
- `MacPasteHistory/Services/PrivacyService.swift`
- `MacPasteHistory/Services/SensitiveContentDetector.swift`
- `MacPasteHistory/Services/SourceApplicationProvider.swift`
- `MacPasteHistory/Services/UserDefaultsConfig.swift`
- `MacPasteHistory/Utils/DefaultSettings.swift`
- `MacPasteHistory/Utils/HistoryDisplayFormatter.swift`
- `MacPasteHistory/Utils/Logger.swift`
- `MacPasteHistory/ViewModels/ClipboardHistoryViewModel.swift`
- `MacPasteHistory/ViewModels/ContentActionPanelViewModel.swift`
- `MacPasteHistory/ViewModels/HistoryViewModelCollaborators.swift`
- `MacPasteHistory/Views/History/HistoryImagePreview.swift`
- `MacPasteHistory/Views/History/HistoryRowView.swift`
- `MacPasteHistory/Views/History/HistoryTimelineView.swift`
- `MacPasteHistory/Views/MainPanelView.swift`
- `MacPasteHistory/Views/Search/SearchBarView.swift`
- `MacPasteHistory/Views/SettingsView.swift`

## 7. 回归测试

- `SearchViewModelTests`：验证 `searchText` 缩短或清空后 `SearchToken.displayTitle(in:)` 与 `removeSearchToken(_:)` 不触发 `String.Index` 陷阱。
- `ClipboardHistoryViewModelTests`：验证面板隐藏时抑制后台重载、关闭时裁剪回首页条数、重新显示时补齐最新记录，以及 `HistoryTimelineView.shouldTriggerLoadMore` 仅对末组末行返回 `true`。
- `ContentClassifierTests` & `SensitiveContentDetectorTests`：验证 `50 KB` 与 `220 KB` 无空格赋值/标识符单行文本在 `< 0.25s` / `< 0.5s` 内完成且无正则灾难性回溯。
- `ClipboardMonitorTests`：验证定时器异步采集队列落库与达到捕获阈值时触发定期清理回调。
- `AppRelauncherTests`：验证 `NSWorkspace` 重启成功直接退出旧实例、失败时自动回退 `/bin/sh` 启动命令。
- 全量回归：`MacPasteHistoryTests` 共 `412` 个测试全部通过（`0` 失败），静态隐私日志安全扫描与包配置校验全部 `PASS`。

## 8. 风险说明与数据修复

- **无需数据库迁移**：未修改 SQLite 表结构或迁移版本（保持 V1–V4 与默认 `DELETE` 日志模式）。
- **存量超限数据自动收敛**：无需手工执行 SQL 修复；新版本启动及后续运行期定期清理会按用户现有保留策略（默认文本 `1,000` 条、图片 `100` 张、总容量 `250 MB`、保留 `30` 天，收藏记录永久保留）自动清理超限历史记录与对应图片文件。
- **权限与隐私影响**：未新增任何系统权限或网络请求；剪贴板内容继续仅保存在本机沙箱目录，日志不打印任何剪贴板原文。
