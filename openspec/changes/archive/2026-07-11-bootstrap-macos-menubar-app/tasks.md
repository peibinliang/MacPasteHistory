## 1. Project Foundation

- [x] 1.1 Create the macOS SwiftUI project and ensure it runs.
  - 实现描述：创建 macOS SwiftUI App target，整理基础目录结构，并确保 Debug 构建可以启动到应用生命周期入口。
  - 前置条件：已确认项目名称、Bundle Identifier、最低 macOS 版本和首版只做菜单栏工具的产品定位。
  - 验收条件：从 Xcode 或命令行启动应用不崩溃，应用进程可见，基础 SwiftUI 入口代码可编译。
- [x] 1.2 Configure app name, bundle metadata, and app icon assets.
  - 实现描述：配置 `Info.plist`、Bundle Display Name、版本号、权限占位和 `Assets.xcassets` 中的 AppIcon。
  - 前置条件：SwiftUI target 已创建，应用名称和图标素材或临时占位图已准备。
  - 验收条件：构建产物显示正确应用名称，Dock/App Switcher 或系统信息中元数据正确，缺失图标警告已消除。
- [x] 1.3 Add the application lifecycle entry point needed for menu bar integration.
  - 实现描述：在 SwiftUI `App` 入口中接入 AppKit lifecycle 所需的 delegate 或 coordinator，用于持有菜单栏和窗口控制对象。
  - 前置条件：项目可启动，已确定使用 SwiftUI + AppKit 混合方式管理 macOS 专属能力。
  - 验收条件：生命周期对象在应用运行期间保持存活，后续菜单栏对象可从该入口初始化且不会提前释放。

## 2. Menu Bar And Windows

- [x] 2.1 Implement a retained `NSStatusItem` menu bar icon.
  - 实现描述：创建 `NSStatusItem`，配置图标、菜单或点击处理，并通过长生命周期对象强引用保存。
  - 前置条件：AppKit lifecycle 入口已可用，图标资源或系统符号已确定。
  - 验收条件：应用运行后 macOS 菜单栏显示图标，图标不会在运行期间消失，点击事件可被捕获。
- [x] 2.2 Open the main history panel from the menu bar item.
  - 实现描述：实现菜单栏点击后创建、显示并激活主历史窗口或面板的窗口控制逻辑。
  - 前置条件：`NSStatusItem` 点击处理已工作，主面板 SwiftUI view 可创建。
  - 验收条件：点击菜单栏图标后主窗口出现，再次点击不会创建失控的重复窗口，窗口可被关闭和重新打开。
- [x] 2.3 Add an entry point that opens the settings window.
  - 实现描述：在菜单栏菜单或主窗口中增加设置入口，并实现设置窗口的创建、显示和重新聚焦。
  - 前置条件：设置页基础 view 已可创建，窗口管理 helper 已存在或可复用主窗口逻辑。
  - 验收条件：用户可以打开设置窗口，关闭后可再次打开，多次点击只聚焦或复用合理窗口实例。
- [x] 2.4 Add quit behavior from the menu bar app flow.
  - 实现描述：在菜单栏菜单中提供退出命令，调用 macOS 应用终止流程并释放运行状态。
  - 前置条件：菜单栏菜单结构或命令入口已存在。
  - 验收条件：用户点击退出后应用进程结束，菜单栏图标消失，重新启动不受影响。

## 3. Local Storage

- [x] 3.1 Create the Application Support data directory on startup.
  - 实现描述：解析应用专属 Application Support 路径，启动时创建数据库、图片等后续数据的根目录。
  - 前置条件：Bundle Identifier 已配置，应用有本地文件系统访问能力。
  - 验收条件：首次启动后目录存在；重复启动不会报错；目录创建失败时有日志记录。
- [x] 3.2 Integrate SQLite and verify the database can be created.
  - 实现描述：接入 SQLite 访问层，打开或创建本地数据库文件，并提供基础连接管理。
  - 前置条件：Application Support 目录可用，已选择 SQLite 库或系统接口方案。
  - 验收条件：启动时数据库文件可创建和打开；失败时不静默吞错；可执行简单建表或查询语句。
- [x] 3.3 Add a migration or initialization layer for database setup.
  - 实现描述：封装数据库 schema 初始化和版本迁移入口，为后续 `clipboard_history` 等表创建提供统一路径。
  - 前置条件：SQLite 连接管理已可用，已确定迁移版本记录方式。
  - 验收条件：首次启动执行初始化；重复启动不会重复破坏已有数据；迁移错误可被日志定位。

## 4. Shared Utilities

- [x] 4.1 Add a lightweight logging module.
  - 实现描述：封装统一日志 API，至少支持 debug、info、warning、error 级别和模块标识。
  - 前置条件：项目基础模块目录已建立。
  - 验收条件：关键启动、存储、窗口路径能输出可读日志；Release 构建不会泄露敏感内容。
- [x] 4.2 Add a `UserDefaults` configuration helper.
  - 实现描述：封装基础配置读写，提供类型安全 key、默认值和后续设置页可复用的访问方法。
  - 前置条件：已列出首批需要持久化的基础配置项，例如启动时自动记录。
  - 验收条件：配置写入后可立即读取，重启后仍保留，缺失配置返回明确默认值。
- [x] 4.3 Verify app launch, menu icon display, window opening, data directory creation, and database initialization.
  - 实现描述：执行阶段 1 端到端自测，覆盖启动、菜单栏、主窗口、设置窗口、目录和数据库。
  - 前置条件：本阶段所有实现任务已完成。
  - 验收条件：验收清单全部通过，并记录任何已知限制或后续阶段依赖。
