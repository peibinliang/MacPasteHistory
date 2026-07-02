# AI_CODING_RULES.md

# Mac 剪贴板历史工具智能体开发代码规范

## 1. 文档目的

本规范用于约束智能体在本项目中的代码生成、修改、重构、调试、测试、文档沉淀和提交行为。

目标是避免智能体在开发过程中生成短期可用但长期难以维护的代码，确保项目具备良好的：

* 可读性
* 可维护性
* 可扩展性
* 稳定性
* 安全性
* 可测试性
* 文档完整性
* 团队协作一致性

智能体在开发本项目时，必须优先遵守本规范。

---

## 2. 适用范围

本规范适用于本项目所有代码、文档和配置，包括但不限于：

* Swift / SwiftUI / AppKit 代码
* macOS 菜单栏应用代码
* 剪贴板监听逻辑
* 文本历史记录逻辑
* 图片历史记录逻辑
* 本地数据库访问代码
* 本地图片与缩略图存储代码
* 设置配置代码
* 隐私与安全过滤代码
* 应用黑名单逻辑
* 自动清理逻辑
* 快捷键逻辑
* 单元测试代码
* 构建脚本
* 数据库迁移脚本
* 开发文档
* 上架文档
* 发布说明

---

# 3. 智能体开发总原则

## 3.1 先理解，再修改

智能体在修改代码前，必须先理解已有项目结构和相关上下文。

禁止行为：

```text
未阅读上下文就直接重写文件
未确认已有工具类就新建重复工具类
未理解调用链就修改核心逻辑
未查看现有命名风格就引入新风格
未确认已有数据结构就新增重复模型
```

正确行为：

```text
先阅读相关模块
先确认已有模型、服务、工具类
尽量复用已有结构
只修改与任务相关的最小范围
```

---

## 3.2 最小改动原则

每次开发任务只允许修改与需求直接相关的代码。

禁止行为：

```text
顺手重构无关模块
顺手修改 UI 风格
顺手调整命名
顺手升级依赖
顺手修改配置
顺手调整目录结构
```

除非任务明确要求，否则不得扩大修改范围。

---

## 3.3 不得臆造需求

智能体不得自行添加用户未要求的功能。

禁止行为：

```text
用户只要求文本历史，智能体擅自增加云同步
用户只要求删除记录，智能体擅自修改数据库结构
用户只要求修 Bug，智能体擅自重构 UI
用户只要求图片记录，智能体擅自接入 OCR
```

允许行为：

```text
发现风险时，在回复中提出建议
必要时增加最小防御性代码
不改变产品行为的前提下优化可读性
```

---

## 3.4 可读性优先

代码应优先让人容易理解，而不是追求炫技。

禁止行为：

```text
过度使用复杂泛型
过度封装
过度链式调用
使用晦涩缩写
把多个逻辑压缩到一行
```

正确行为：

```text
命名清晰
逻辑分层
函数短小
职责单一
关键逻辑有注释
异常处理明确
```

---

## 3.5 不允许生成临时代码

禁止出现以下无责任交付：

```text
TODO: later
FIXME: temp
先这样写
临时兼容一下
magic number
debug print 未清理
无意义 catch
空实现函数
伪代码冒充可运行代码
```

确实需要保留 TODO 时，必须说明原因和后续处理方式。

示例：

```swift
// TODO: 支持图片 OCR 搜索。
// 原因：当前版本仅支持图片缩略图展示，OCR 依赖后续模块接入。
// 跟进：v2.0 实现 OCRIndexService。
```

---

## 3.6 代码与文档同步原则

本项目要求代码和文档同步沉淀。

任何核心功能如果只有代码实现，没有对应开发文档、设计说明或变更记录，视为交付不完整。

智能体不得只写代码不写文档。

---

# 4. 项目架构规范

## 4.1 推荐目录结构

项目应保持清晰分层，推荐结构如下：

```text
MacPasteHistory/
├── App/
│   ├── MacPasteHistoryApp.swift
│   └── AppDelegate.swift
├── Clipboard/
│   ├── ClipboardMonitor.swift
│   ├── ClipboardReader.swift
│   ├── ClipboardWriter.swift
│   └── ClipboardContentDetector.swift
├── Database/
│   ├── DatabaseManager.swift
│   ├── ClipboardHistoryRepository.swift
│   └── MigrationManager.swift
├── Models/
│   ├── ClipboardHistoryItem.swift
│   ├── ClipboardContentType.swift
│   └── AppSettings.swift
├── Views/
│   ├── MainPanelView.swift
│   ├── HistoryListView.swift
│   ├── HistoryRowView.swift
│   ├── HistoryDetailView.swift
│   └── SettingsView.swift
├── ViewModels/
│   ├── ClipboardHistoryViewModel.swift
│   └── SettingsViewModel.swift
├── Services/
│   ├── ImageStorageService.swift
│   ├── ThumbnailService.swift
│   ├── SensitiveContentService.swift
│   ├── BlockedAppService.swift
│   ├── CleanupService.swift
│   └── ShortcutService.swift
├── Utils/
│   ├── HashUtil.swift
│   ├── FileUtil.swift
│   ├── DateUtil.swift
│   └── Logger.swift
├── Resources/
│   ├── Assets.xcassets
│   └── Localizable.strings
└── docs/
    ├── feature-list.md
    ├── architecture.md
    ├── database.md
    ├── privacy-and-security.md
    ├── development-log.md
    └── changelog.md
```

---

## 4.2 分层职责

### App 层

负责：

* 应用启动
* 菜单栏入口
* 生命周期管理
* 全局依赖初始化

不得包含：

* 业务逻辑
* 数据库 SQL
* 图片处理逻辑
* 剪贴板解析逻辑

---

### Clipboard 层

负责：

* 监听剪贴板变化
* 读取剪贴板内容
* 判断内容类型
* 将内容写回剪贴板

不得包含：

* UI 展示逻辑
* 数据库细节
* 设置页面逻辑
* 图片文件持久化细节

---

### Database 层

负责：

* 数据库初始化
* 表结构迁移
* CRUD 操作
* 查询封装
* 索引维护

不得包含：

* UI 逻辑
* 剪贴板监听逻辑
* 图片压缩处理逻辑

---

### Services 层

负责：

* 图片存储
* 缩略图生成
* 敏感内容识别
* 黑名单判断
* 自动清理
* 快捷键注册
* 文件管理

服务类必须职责单一，不得变成万能 Service。

---

### ViewModels 层

负责：

* UI 状态管理
* 调用 Service / Repository
* 处理用户交互
* 错误状态管理
* 加载状态管理

不得直接：

* 拼接 SQL
* 操作文件系统底层细节
* 直接访问 NSPasteboard
* 执行耗时图片处理

---

### Views 层

负责：

* UI 展示
* 用户交互入口
* 状态绑定

不得包含：

* 数据库访问
* 文件保存
* 剪贴板读取
* 大量业务判断
* 敏感内容识别逻辑

---

# 5. 命名规范

## 5.1 通用命名原则

命名必须清晰表达含义。

推荐：

```swift
ClipboardHistoryItem
ImageStorageService
SensitiveContentDetector
BlockedAppRepository
saveClipboardText()
generateThumbnail()
deleteExpiredHistory()
```

禁止：

```swift
DataManager
CommonUtil
Tool
Helper
handle()
doSomething()
processData()
tempData
newData
```

除非职责非常明确，否则不要使用：

```text
Manager
Helper
Util
Common
Base
Temp
New
Old
```

---

## 5.2 类型命名

类型使用大驼峰命名。

```swift
struct ClipboardHistoryItem
final class ClipboardMonitor
enum ClipboardContentType
protocol ClipboardWritable
```

---

## 5.3 变量和函数命名

变量、函数使用小驼峰命名。

```swift
let contentHash: String
let createdAt: Date
func saveClipboardItem()
func deleteHistoryItem()
func generateThumbnail()
```

---

## 5.4 布尔变量命名

布尔变量必须表达明确的是 / 否含义。

推荐：

```swift
let isFavorite: Bool
let isSensitive: Bool
let shouldRecordImage: Bool
let canDeleteHistory: Bool
```

禁止：

```swift
let favorite: Bool
let sensitive: Bool
let record: Bool
let flag: Bool
```

---

## 5.5 枚举命名

枚举 case 使用小驼峰。

```swift
enum ClipboardContentType {
    case text
    case image
    case file
    case link
    case code
}
```

---

# 6. Swift 编码规范

## 6.1 基础格式

要求：

* 使用 4 个空格缩进
* 每行尽量不超过 120 个字符
* 一个文件只定义一个主要类型
* 文件名必须与主要类型名一致
* 删除无用 import
* 删除无用代码
* 删除无用注释
* 不提交格式混乱的代码

---

## 6.2 访问控制

必须显式控制访问范围。

优先级：

```text
private > fileprivate > internal > public
```

示例：

```swift
final class ClipboardMonitor {
    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }
}
```

能用 `private` 就不要使用默认访问级别。

---

## 6.3 禁止强制解包

禁止使用：

```swift
value!
try!
as!
```

除非在测试代码中，并且能保证一定存在。

错误示例：

```swift
let image = NSImage(data: data)!
```

正确示例：

```swift
guard let image = NSImage(data: data) else {
    throw ImageStorageError.invalidImageData
}
```

---

## 6.4 禁止隐式崩溃

禁止为了省事写出可能崩溃的代码。

禁止：

```swift
array[0]
dictionary["key"]!
Int(text)!
```

正确：

```swift
guard let firstItem = array.first else {
    return
}

guard let value = dictionary["key"] else {
    return
}

guard let number = Int(text) else {
    return
}
```

---

## 6.5 函数长度限制

单个函数建议不超过 50 行。

超过 50 行时，应考虑拆分为：

* 参数校验函数
* 数据转换函数
* 存储函数
* UI 状态更新函数
* 错误处理函数

---

## 6.6 类型长度限制

单个类型建议不超过 300 行。

超过时应考虑拆分职责。

例如：

```text
ClipboardMonitor 只负责监听
ClipboardReader 只负责读取
ClipboardWriter 只负责写回
ClipboardContentDetector 只负责类型识别
```

---

## 6.7 避免重复代码

禁止复制粘贴相似逻辑。

发现重复逻辑时，应抽取为：

* private 方法
* Service
* Repository
* Extension
* Utility

但不得过度抽象。

---

## 6.8 错误处理规范

必须明确处理错误，不得吞掉异常。

禁止：

```swift
do {
    try saveImage(data)
} catch {
}
```

正确：

```swift
do {
    try saveImage(data)
} catch {
    logger.error("保存图片失败: \(error.localizedDescription)")
    throw error
}
```

UI 层需要给用户明确反馈。

---

## 6.9 日志规范

日志必须有意义。

推荐：

```swift
logger.info("剪贴板文本已保存，字符数: \(content.count)")
logger.warning("检测到敏感内容，已跳过保存")
logger.error("图片缩略图生成失败: \(error.localizedDescription)")
```

禁止：

```swift
print("111")
print("test")
print(error)
print(clipboardContent)
```

Release 版本不得保留无意义调试输出。

---

# 7. 剪贴板模块规范

## 7.1 监听方式

剪贴板监听应基于 `NSPasteboard.general.changeCount` 变化判断。

要求：

* 不监听键盘事件来判断复制
* 不记录未变化内容
* 不重复处理同一次 changeCount
* 监听频率默认不低于 0.3 秒，不高于 1 秒
* 用户暂停记录时必须停止保存
* 用户关闭文本或图片记录时必须跳过对应类型

---

## 7.2 内容读取顺序

推荐读取顺序：

```text
1. 判断是否暂停记录
2. 判断当前来源应用是否在黑名单
3. 判断 pasteboard.changeCount 是否变化
4. 识别剪贴板内容类型
5. 判断对应内容类型是否启用记录
6. 执行敏感内容过滤
7. 计算内容 Hash
8. 执行去重判断
9. 保存内容
10. 更新 UI
```

---

## 7.3 文本处理

文本保存前必须执行：

* 去除非法控制字符
* 判断是否为空
* 判断是否超过最大长度
* 计算 Hash
* 敏感内容检测
* 去重判断

空文本不得保存。

---

## 7.4 图片处理

图片保存前必须执行：

* 判断图片格式
* 判断图片大小
* 判断是否超过单张大小上限
* 转换为统一格式
* 计算 Hash
* 保存原图
* 生成缩略图
* 保存元数据

图片不得直接存入 SQLite。

---

## 7.5 恢复剪贴板

恢复历史内容时：

* 先清空剪贴板
* 再写入目标内容
* 写入成功后提示用户
* 不得将恢复操作再次记录为新历史

必须避免循环记录。

推荐做法：

```text
设置 isRestoringFromHistory = true
写入剪贴板
下一次监听到 changeCount 时跳过
恢复 isRestoringFromHistory = false
```

---

# 8. 数据库规范

## 8.1 数据库访问原则

所有数据库访问必须通过 Repository。

禁止 UI 层直接操作数据库。

禁止：

```swift
HistoryListView 直接执行 SQL
SettingsView 直接操作 SQLite
ClipboardMonitor 直接拼 SQL
```

正确调用链：

```text
View → ViewModel → Repository → DatabaseManager
ClipboardMonitor → Service → Repository → DatabaseManager
```

---

## 8.2 SQL 规范

要求：

* 禁止字符串拼接 SQL 参数
* 必须使用参数绑定
* 表名、字段名统一小写加下划线
* 必须为常用查询字段添加索引
* 数据库迁移必须可追踪

---

## 8.3 核心表结构

### clipboard_history

```sql
CREATE TABLE clipboard_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_type TEXT NOT NULL,
    text_content TEXT,
    file_path TEXT,
    thumbnail_path TEXT,
    source_app TEXT,
    source_bundle_id TEXT,
    content_hash TEXT NOT NULL,
    file_size INTEGER,
    image_width INTEGER,
    image_height INTEGER,
    is_favorite INTEGER DEFAULT 0,
    is_sensitive INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### blocked_apps

```sql
CREATE TABLE blocked_apps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_name TEXT NOT NULL,
    bundle_id TEXT,
    enabled INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### app_settings

```sql
CREATE TABLE app_settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 8.4 建议索引

```sql
CREATE INDEX idx_clipboard_created_at 
ON clipboard_history(created_at);

CREATE INDEX idx_clipboard_content_type 
ON clipboard_history(content_type);

CREATE INDEX idx_clipboard_hash 
ON clipboard_history(content_hash);

CREATE INDEX idx_clipboard_favorite 
ON clipboard_history(is_favorite);
```

---

## 8.5 数据迁移规范

数据库结构变化时必须新增 migration。

禁止直接修改旧表结构而不写迁移。

迁移命名：

```text
001_create_clipboard_history.sql
002_add_blocked_apps.sql
003_add_image_metadata.sql
```

每个迁移脚本必须具备：

* 明确编号
* 明确目的
* 可重复追踪
* 与数据库文档一致

---

# 9. 文件存储规范

## 9.1 存储目录

所有用户数据必须存储在 App 专属目录中。

推荐：

```text
~/Library/Application Support/MacPasteHistory/
├── clipboard.db
├── images/
├── thumbnails/
├── logs/
└── config/
```

禁止将数据随意写入：

```text
Desktop
Downloads
Documents
项目源码目录
临时目录且不清理
```

---

## 9.2 图片文件命名

图片文件名不得使用原始名称。

推荐格式：

```text
yyyyMMdd_HHmmss_hash.png
```

示例：

```text
20260702_153012_a8f3c21d.png
```

---

## 9.3 删除规范

删除图片历史时，必须同时删除：

* 数据库记录
* 原图文件
* 缩略图文件

删除失败必须记录日志。

---

# 10. 隐私与安全规范

## 10.1 本地优先原则

剪贴板内容默认只允许保存在本机。

未经明确需求，禁止：

```text
上传剪贴板内容
接入云同步
接入第三方分析 SDK 采集剪贴板内容
将历史内容写入远程日志
将图片上传服务器
```

---

## 10.2 敏感内容过滤

必须内置敏感内容识别规则。

包括但不限于：

```text
password
passwd
token
access_token
refresh_token
Authorization
Bearer
api_key
secret
private_key
sk-
验证码
动态码
身份证号
银行卡号
```

命中敏感规则时，默认不得保存。

---

## 10.3 应用黑名单

必须支持应用黑名单。

默认建议加入：

```text
1Password
Bitwarden
KeePass
钥匙串访问
银行类 App
支付类 App
```

来自黑名单应用的剪贴板内容不得保存。

---

## 10.4 日志安全

日志中不得出现：

```text
完整剪贴板内容
完整图片路径中的隐私信息
密码
Token
API Key
验证码
身份证号
银行卡号
```

日志只允许记录摘要信息。

示例：

```swift
logger.info("文本历史保存成功，字符数: \(content.count)")
logger.warning("检测到敏感内容，已跳过保存")
```

---

## 10.5 用户控制权

必须提供：

* 暂停记录
* 清空全部历史
* 删除单条历史
* 关闭文本记录
* 关闭图片记录
* 应用黑名单配置
* 敏感内容过滤开关

用户必须可以随时清理自己的本地数据。

---

# 11. UI 开发规范

## 11.1 SwiftUI View 规范

View 只负责展示，不处理复杂业务逻辑。

禁止在 View 中：

```text
直接读写数据库
直接访问 NSPasteboard
直接处理图片压缩
直接拼接复杂业务判断
```

View 中允许：

```text
展示状态
触发 ViewModel 方法
简单格式化显示
```

---

## 11.2 ViewModel 规范

ViewModel 负责：

* 页面状态
* 用户操作响应
* 调用 Service / Repository
* 错误提示状态
* 加载状态

ViewModel 不得直接写复杂底层代码。

---

## 11.3 UI 状态规范

所有异步加载必须有明确状态。

```swift
enum LoadingState {
    case idle
    case loading
    case success
    case failed(String)
}
```

不得让页面在异常时无反馈。

---

## 11.4 用户反馈规范

以下操作必须有反馈：

* 复制成功
* 删除成功
* 清空成功
* 保存失败
* 权限不足
* 图片过大未保存
* 敏感内容已跳过
* 已暂停记录

---

# 12. 配置规范

## 12.1 禁止硬编码

禁止在业务代码中硬编码以下内容：

```text
监听间隔
最大保存数量
最大图片大小
历史保留天数
文件目录名称
敏感关键词
默认快捷键
UI 展示文案
错误提示文案
```

错误示例：

```swift
let maxImageSize = 20 * 1024 * 1024
```

正确示例：

```swift
let maxImageSize = appSettings.maxImageSize
```

---

## 12.2 默认配置集中管理

默认配置必须统一放在配置文件或配置类型中。

示例：

```swift
struct DefaultSettings {
    static let clipboardPollingInterval: TimeInterval = 0.5
    static let maxTextHistoryCount: Int = 1000
    static let maxImageHistoryCount: Int = 100
    static let maxImageSizeInBytes: Int = 20 * 1024 * 1024
    static let historyRetentionDays: Int = 30
}
```

业务代码不得散落默认值。

---

## 12.3 配置项必须有文档

新增配置项时，必须同步更新配置文档。

配置文档必须包含：

* 配置名称
* 配置 key
* 配置类型
* 默认值
* 可选值
* 生效范围
* 是否支持用户修改
* 是否需要重启生效

---

# 13. 并发与性能规范

## 13.1 主线程规范

主线程只处理 UI。

禁止在主线程执行：

```text
大图片压缩
数据库批量查询
文件批量删除
Hash 计算
缩略图生成
大文本搜索
```

这些操作应放到后台队列或异步任务中执行。

---

## 13.2 图片加载规范

列表中必须加载缩略图，不得直接加载原图。

错误：

```text
历史列表直接加载 5MB 原图
```

正确：

```text
历史列表加载 thumbnail
详情页再加载原图
```

---

## 13.3 搜索性能规范

搜索必须考虑大量数据场景。

要求：

* 搜索字段加索引
* 输入搜索做 debounce
* 列表分页或懒加载
* 不在 UI 渲染中做数据库查询

---

## 13.4 剪贴板监听性能

剪贴板监听不得造成明显 CPU 占用。

要求：

* 默认监听间隔建议为 0.5 秒
* 支持暂停监听
* 应避免重复解析同一 changeCount
* 图片处理放入后台任务
* 大图片需要限制大小

---

# 14. 测试规范

## 14.1 必须测试的核心逻辑

以下模块必须具备测试或明确验证方式：

* 文本 Hash 去重
* 敏感内容识别
* 应用黑名单判断
* 图片大小限制
* 图片文件删除
* 数据库 CRUD
* 自动清理规则
* 剪贴板恢复跳过重复记录
* 设置项保存与读取
* 历史搜索

---

## 14.2 测试命名

测试方法命名应表达清楚场景和预期。

推荐：

```swift
func testSaveText_whenContentIsDuplicated_shouldUpdateExistingItem()
func testDetectSensitiveContent_whenTextContainsBearerToken_shouldReturnTrue()
func testDeleteImageHistory_shouldRemoveDatabaseRecordAndImageFiles()
```

禁止：

```swift
func test1()
func testSave()
func testData()
```

---

## 14.3 测试数据规范

测试数据不得使用真实隐私数据。

禁止：

```text
真实手机号
真实身份证号
真实银行卡号
真实 Token
真实 API Key
真实聊天截图
```

必须使用模拟数据。

---

## 14.4 回归测试要求

修复重要 Bug 后，必须补充回归测试点。

至少说明：

* 问题如何复现
* 修复后如何验证
* 是否影响已有功能
* 是否涉及历史数据兼容

---

# 15. 注释规范

## 15.1 什么情况需要注释

需要注释：

* 复杂业务规则
* 系统权限处理
* 剪贴板特殊行为
* 数据库迁移原因
* 敏感内容过滤规则
* 图片格式转换原因
* 防止循环记录的逻辑

不需要注释：

* 显而易见的代码
* 重复函数名含义
* 无意义模板注释

错误示例：

```swift
// 删除
deleteItem()
```

正确示例：

```swift
// 恢复历史内容会触发 pasteboard.changeCount 变化，
// 这里需要跳过下一次监听，避免将恢复操作再次保存为新历史。
isRestoringFromHistory = true
```

---

# 16. 开发文档沉淀规范

## 16.1 基本原则

智能体在开发过程中，凡是涉及功能设计、核心逻辑、架构调整、数据库变更、权限处理、异常处理、上线配置等内容，必须同步沉淀开发文档。

开发文档不是可选项，而是代码交付的一部分。

任何功能如果只有代码实现，没有对应的开发说明、设计说明或变更记录，视为交付不完整。

---

## 16.2 必须沉淀文档的场景

以下场景必须新增或更新开发文档：

```text
1. 新增核心功能
2. 修改核心业务流程
3. 新增或修改数据库表结构
4. 新增或修改本地文件存储规则
5. 新增或修改系统权限申请
6. 新增或修改剪贴板监听逻辑
7. 新增或修改图片处理逻辑
8. 新增或修改敏感内容过滤规则
9. 新增或修改应用黑名单逻辑
10. 新增或修改自动清理策略
11. 新增或修改快捷键逻辑
12. 新增或修改配置项
13. 新增或修改错误处理策略
14. 新增第三方依赖
15. 修改项目架构或目录结构
16. 修复重要 Bug
17. 调整打包、签名、上架或发布流程
```

禁止只改代码不更新文档。

---

## 16.3 开发文档目录规范

项目根目录必须维护 `docs` 目录。

推荐完整结构：

```text
docs/
├── README.md
├── product/
│   ├── feature-list.md
│   ├── roadmap.md
│   └── release-plan.md
├── architecture/
│   ├── overall-architecture.md
│   ├── module-design.md
│   └── data-flow.md
├── development/
│   ├── clipboard-monitor.md
│   ├── text-history.md
│   ├── image-history.md
│   ├── storage-design.md
│   ├── privacy-and-security.md
│   ├── settings-design.md
│   └── shortcut-design.md
├── database/
│   ├── schema.md
│   └── migration-history.md
├── testing/
│   ├── test-plan.md
│   └── test-cases.md
├── release/
│   ├── build-and-sign.md
│   ├── app-store-release.md
│   └── notarization.md
└── changelog/
    └── CHANGELOG.md
```

项目规模较小时，可以先保留最小结构：

```text
docs/
├── feature-list.md
├── architecture.md
├── database.md
├── privacy-and-security.md
├── development-log.md
└── changelog.md
```

---

## 16.4 功能开发文档要求

每新增一个核心功能，必须补充对应开发文档。

文档至少包含：

```text
1. 功能背景
2. 功能目标
3. 使用场景
4. 交互流程
5. 技术方案
6. 涉及模块
7. 数据结构
8. 异常处理
9. 隐私与安全影响
10. 测试点
11. 后续扩展点
```

推荐模板：

```markdown
# 功能名称

## 1. 功能背景

说明为什么需要该功能。

## 2. 功能目标

说明该功能要解决什么问题。

## 3. 使用场景

说明用户在什么情况下会使用该功能。

## 4. 交互流程

描述用户操作流程和系统处理流程。

## 5. 技术方案

说明主要实现方式、核心类、关键逻辑。

## 6. 涉及模块

列出涉及的文件、类、服务、数据库表。

## 7. 数据结构

说明新增或使用的数据模型、字段含义。

## 8. 异常处理

说明失败场景和处理策略。

## 9. 隐私与安全影响

说明是否涉及剪贴板内容、图片、路径、权限、敏感信息。

## 10. 测试点

列出必须验证的测试场景。

## 11. 后续扩展点

说明未来可能扩展的方向。
```

---

## 16.5 架构变更文档要求

任何架构调整必须更新架构文档。

包括但不限于：

```text
1. 新增模块
2. 拆分模块
3. 合并模块
4. 修改调用链
5. 修改数据流
6. 修改目录结构
7. 引入新的设计模式
8. 引入新的依赖
```

架构文档必须说明：

```text
1. 为什么调整
2. 调整前的问题
3. 调整后的结构
4. 涉及哪些模块
5. 对已有功能的影响
6. 是否需要迁移
7. 是否存在兼容性风险
```

禁止只重构代码而不更新架构说明。

---

## 16.6 数据库文档要求

新增或修改数据库表结构时，必须同步更新数据库文档。

必须包含：

```text
1. 表名
2. 表用途
3. 字段说明
4. 字段类型
5. 是否允许为空
6. 默认值
7. 索引说明
8. 迁移脚本
9. 兼容性说明
```

示例：

```markdown
# clipboard_history 表

## 表用途

用于存储剪贴板历史记录，包括文本、图片、文件等类型。

## 字段说明

| 字段 | 类型 | 是否必填 | 默认值 | 说明 |
|---|---|---|---|---|
| id | INTEGER | 是 | 自增 | 主键 |
| content_type | TEXT | 是 | 无 | 内容类型 |
| text_content | TEXT | 否 | NULL | 文本内容 |
| file_path | TEXT | 否 | NULL | 图片或文件路径 |
| content_hash | TEXT | 是 | 无 | 内容 Hash |
| created_at | DATETIME | 是 | CURRENT_TIMESTAMP | 创建时间 |

## 索引说明

| 索引名 | 字段 | 说明 |
|---|---|---|
| idx_clipboard_created_at | created_at | 用于按时间倒序查询 |
| idx_clipboard_hash | content_hash | 用于内容去重 |

## 迁移记录

- 001_create_clipboard_history.sql：创建剪贴板历史表
```

---

## 16.7 配置项文档要求

新增配置项时，必须更新配置文档。

配置文档必须包含：

```text
1. 配置名称
2. 配置 key
3. 配置类型
4. 默认值
5. 可选值
6. 生效范围
7. 是否支持用户修改
8. 是否需要重启生效
```

示例：

```markdown
| 配置名称 | Key | 类型 | 默认值 | 说明 |
|---|---|---|---|---|
| 是否记录文本 | record_text_enabled | Boolean | true | 控制是否保存文本剪贴板历史 |
| 是否记录图片 | record_image_enabled | Boolean | false | 控制是否保存图片剪贴板历史 |
| 文本最大保存数量 | max_text_history_count | Int | 1000 | 超出后自动清理旧记录 |
| 图片最大保存数量 | max_image_history_count | Int | 100 | 超出后自动清理旧图片 |
```

---

## 16.8 隐私与安全文档要求

凡是涉及用户数据、剪贴板内容、图片、文件路径、系统权限的功能，必须更新隐私与安全文档。

必须说明：

```text
1. 采集了什么数据
2. 数据存储在哪里
3. 是否上传服务器
4. 是否记录日志
5. 是否支持用户删除
6. 是否支持暂停记录
7. 是否涉及敏感内容过滤
8. 是否涉及应用黑名单
9. 是否涉及系统权限
10. 是否影响 App Store 审核
```

剪贴板相关功能必须明确说明：

```text
剪贴板内容默认仅保存在用户本机。
不得上传剪贴板内容。
不得将剪贴板内容写入远程日志。
不得在日志中打印完整剪贴板内容。
用户必须可以暂停记录和清空数据。
```

---

## 16.9 Bug 修复文档要求

修复重要 Bug 时，必须在开发文档或变更记录中说明。

内容至少包括：

```text
1. Bug 现象
2. 影响范围
3. 根因分析
4. 修复方案
5. 涉及文件
6. 回归测试点
7. 是否需要数据修复
```

推荐模板：

```markdown
# Bug 修复记录

## 问题现象

描述用户遇到的问题。

## 影响范围

说明影响哪些功能和版本。

## 根因分析

说明导致问题的具体原因。

## 修复方案

说明如何修复。

## 涉及文件

列出修改的主要文件。

## 回归测试

列出验证方式。

## 风险说明

说明是否存在兼容性或数据风险。
```

---

## 16.10 开发日志要求

项目必须维护开发日志。

推荐文件：

```text
docs/development-log.md
```

每次完成一个功能、修复一个重要 Bug、调整一个核心模块后，都需要追加记录。

格式：

```markdown
## 2026-07-02

### 新增

- 完成文本剪贴板监听能力。
- 新增 ClipboardMonitor，用于基于 NSPasteboard.changeCount 监听剪贴板变化。
- 新增 ClipboardHistoryRepository，用于保存文本历史。

### 修改

- 调整 clipboard_history 表结构，增加 content_hash 字段用于去重。

### 修复

- 修复恢复历史内容时被重复记录的问题。

### 风险

- 当前仅支持纯文本，暂不支持富文本格式。
```

---

## 16.11 Changelog 要求

项目必须维护面向版本发布的变更记录。

推荐文件：

```text
docs/changelog/CHANGELOG.md
```

格式：

```markdown
# CHANGELOG

## v1.0.0

### Added

- 新增文本剪贴板历史记录。
- 新增图片剪贴板历史记录。
- 新增历史搜索能力。
- 新增点击恢复到剪贴板能力。

### Changed

- 优化历史列表展示样式。

### Fixed

- 修复恢复历史内容时重复保存的问题。

### Security

- 新增敏感内容过滤规则。
- 新增应用黑名单能力。
```

---

## 16.12 智能体开发后的文档输出要求

智能体每次完成开发任务后，必须在最终回复中说明文档变更情况。

必须包含：

```text
1. 是否新增或更新开发文档
2. 更新了哪些文档
3. 文档记录了哪些内容
4. 是否还有待补充文档
```

输出示例：

```text
本次已同步更新开发文档：

1. docs/development/text-history.md
   - 补充文本剪贴板监听流程
   - 补充文本去重策略
   - 补充异常处理说明

2. docs/database/schema.md
   - 新增 clipboard_history 表说明
   - 新增 content_hash 字段说明

3. docs/development-log.md
   - 记录本次文本历史功能开发内容

暂无待补充文档。
```

如果没有更新文档，必须说明原因。

禁止在完成核心功能后只回复“代码已完成”，但不说明文档沉淀情况。

---

## 16.13 文档与代码一致性要求

文档必须与代码保持一致。

禁止出现：

```text
1. 文档写了功能已支持，但代码未实现
2. 代码已修改，但文档仍是旧逻辑
3. 数据库字段已变更，但文档未更新
4. 配置默认值已变化，但文档未同步
5. 权限申请已变化，但隐私文档未同步
```

如果发现文档与代码不一致，应优先修正文档或代码，不能继续扩大开发。

---

## 16.14 文档质量要求

开发文档必须清晰、准确、可维护。

禁止：

```text
1. 只写标题，没有内容
2. 只写“已完成”，没有实现说明
3. 大量复制代码，不解释逻辑
4. 文档内容与代码不一致
5. 文档过度口语化
6. 文档没有时间、版本或变更记录
```

推荐：

```text
1. 用清晰的小标题组织内容
2. 用表格描述字段和配置
3. 用流程或步骤描述复杂逻辑
4. 用简短代码片段说明关键实现
5. 明确说明异常场景
6. 明确说明测试方式
```

---

## 16.15 文档优先级

文档优先级如下：

```text
P0：必须随代码同步更新
P1：应在当前迭代内补充
P2：可在版本发布前补充
```

P0 文档包括：

```text
1. 架构说明
2. 数据库结构
3. 核心功能设计
4. 隐私与安全说明
5. 开发日志
6. 重要 Bug 修复记录
```

P1 文档包括：

```text
1. 测试用例
2. 配置说明
3. 发布说明
4. 使用说明
```

P2 文档包括：

```text
1. 高级功能扩展说明
2. 性能优化记录
3. 技术调研记录
```

---

# 17. Git 提交规范

## 17.1 Commit Message 格式

推荐格式：

```text
<type>: <summary>
```

type 可选：

```text
feat      新功能
fix       修复问题
refactor  重构
perf      性能优化
test      测试
docs      文档
style     格式调整
chore     构建或工具调整
```

示例：

```text
feat: add clipboard text history monitor
fix: prevent restored clipboard item from being saved again
refactor: split image storage logic into ImageStorageService
docs: add AI coding rules
```

---

## 17.2 提交粒度

一次提交只做一类事情。

禁止：

```text
一个提交同时修改 UI、数据库、图片逻辑、快捷键和文档
```

正确：

```text
一个提交实现文本监听
一个提交实现文本保存
一个提交实现图片缩略图
一个提交修复重复保存问题
一个提交补充开发文档
```

---

## 17.3 文档提交要求

涉及核心功能开发时，代码提交必须包含对应文档变更。

推荐提交组合：

```text
feat: add image clipboard history
docs: add image history development design
test: add image history validation cases
```

或在同一个功能提交中包含对应文档修改。

---

# 18. 智能体输出规范

## 18.1 修改代码前

智能体应先明确：

```text
要修改哪个模块
为什么修改
会影响哪些功能
是否需要新增文件
是否需要修改数据库结构
是否需要更新开发文档
是否需要测试
```

---

## 18.2 修改代码时

智能体必须：

```text
保持现有项目结构
遵守命名规范
避免重复代码
避免大范围重写
补充必要错误处理
补充必要测试
同步更新开发文档
删除无用代码
保证代码可编译
```

---

## 18.3 修改代码后

智能体必须说明：

```text
修改了哪些文件
完成了哪些功能
修复了哪些问题
是否有兼容性影响
是否需要数据库迁移
是否需要用户授权
如何验证
更新了哪些开发文档
是否还有待补充文档
```

---

# 19. 禁止行为清单

智能体禁止执行以下行为：

```text
1. 未理解代码结构就大面积重写
2. 新增重复 Service、Repository、Model
3. 在 View 中写数据库逻辑
4. 在 View 中写剪贴板监听逻辑
5. 直接把图片二进制存入 SQLite
6. 使用强制解包 value!
7. 空 catch 吞掉错误
8. 生成无意义 TODO
9. 硬编码配置值
10. 打印敏感剪贴板内容
11. 默认上传用户剪贴板内容
12. 未经要求加入云同步
13. 未经要求加入第三方 SDK
14. 删除用户数据但不做确认
15. 修改无关文件
16. 引入不必要依赖
17. 生成无法编译的伪代码
18. 只实现 happy path，不处理异常
19. 修改数据库结构但不写迁移
20. 删除图片记录但不删除本地图片文件
21. 新增核心功能但不更新开发文档
22. 修复重要 Bug 但不记录根因
23. 文档写了已支持但代码未实现
24. 代码已变更但文档仍是旧逻辑
25. 只回复“代码已完成”但不说明验证方式和文档变更
```

---

# 20. 代码审查检查清单

每次智能体完成代码后，应按以下清单自检：

```text
功能是否满足需求？
是否只修改了必要范围？
是否存在强制解包？
是否存在空 catch？
是否存在硬编码？
是否存在重复代码？
是否存在无用 import？
是否存在无用文件？
是否存在敏感日志？
是否处理异常场景？
是否考虑数据为空的情况？
是否考虑权限不足的情况？
是否考虑大文本和大图片？
是否需要数据库迁移？
是否需要补充测试？
是否会影响已有功能？
是否同步更新开发文档？
是否更新 development-log？
是否存在文档与代码不一致？
```

---

# 21. 项目首版质量标准

首版代码必须达到以下标准：

```text
1. 项目结构清晰
2. 模块职责明确
3. 核心功能可测试
4. 无明显重复代码
5. 无强制解包
6. 无敏感日志
7. 无无意义 TODO
8. 无散落硬编码
9. 数据库存储稳定
10. 图片文件可清理
11. 剪贴板恢复不会循环记录
12. 大量历史数据下不卡顿
13. 用户可暂停记录
14. 用户可清空数据
15. 隐私逻辑默认安全
16. 核心功能有开发文档
17. 数据库结构有文档
18. 隐私与安全逻辑有文档
19. 重要 Bug 有修复记录
20. 每次核心开发有 development-log
```

---

# 22. 推荐智能体执行提示词

后续让智能体开发本项目时，可以附加以下提示词：

```text
请严格遵守项目根目录中的 AI_CODING_RULES.md。

开发前请先阅读相关模块代码，不要直接重写无关文件。

本次任务只允许修改与需求直接相关的代码，禁止扩大范围。

代码必须符合以下要求：

1. 不使用强制解包
2. 不吞掉异常
3. 不硬编码配置
4. 不打印敏感内容
5. 不在 View 中写业务逻辑
6. 不重复创建已有工具类
7. 不引入不必要依赖
8. 不修改无关 UI 风格
9. 新增数据库字段必须提供迁移
10. 新增核心逻辑必须补充测试或说明验证方式
11. 新增或修改核心功能必须同步更新开发文档
12. 每次开发完成后必须追加 docs/development-log.md

本次开发完成后，请说明：

1. 修改了哪些文件
2. 实现了什么功能
3. 如何验证
4. 是否存在风险
5. 是否需要后续处理
6. 更新了哪些开发文档
7. 是否还有待补充文档

禁止只提交代码不更新文档。
```

---

# 23. 结语

本规范不是为了限制开发速度，而是为了避免智能体生成短期可用、长期难维护的代码。

本项目的核心原则是：

```text
小步修改
职责清晰
本地优先
隐私安全
可读可测
文档同步
长期可维护
```

智能体在任何开发任务中，都必须同时关注：

```text
代码是否能运行
结构是否清晰
逻辑是否安全
异常是否处理
文档是否沉淀
后续是否好维护
```
