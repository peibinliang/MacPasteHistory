# 粘易增强搜索与开发者内容动作 PRD

> 状态：已确认，可进入实施计划阶段  
> 版本：1.0  
> 日期：2026-08-05  
> 目标平台：macOS 14.0 及以上  
> 目标用户：以开发者为主，同时保持普通办公用户零学习成本  
> 产品原则：默认极简，能力渐进展开；本地优先，不建设自有云同步

---

## 0. Codex 开发前置要求

本文件是本轮功能开发的唯一产品范围基线。Codex 在开始修改代码前必须完成以下动作：

1. 阅读仓库根目录 `AI_CODING_RULES.md`。
2. 阅读 `docs/architecture/overall-architecture.md`、`docs/user-guide.md`、`docs/changelog/CHANGELOG.md`。
3. 阅读现有的 `HistoryQuery`、`ClipboardHistoryRepository`、`ClipboardHistoryViewModel`、`MainPanelView`、`MigrationManager`、`ClipboardMonitor` 和 `ClipboardWriter`。
4. 先输出详细实施计划，再开始编码；不得一次性跨越所有模块直接提交完整实现。
5. 使用测试驱动方式开发：先添加失败测试，再实现最小代码，再运行相关测试和完整测试。
6. 每个阶段必须形成可独立验证的提交，禁止把数据库、搜索、内容动作、OCR 和 UI 全部塞入一个提交。
7. 只实现本 PRD 明确列出的能力，不得自行加入云同步、脚本插件、AI 改写、JWT 签名验证或其他未确认能力。
8. 核心代码变更必须同步更新架构、数据库、用户指南和变更记录文档。
9. 所有新增用户文案必须支持简体中文、繁体中文和英文。
10. 不得在日志中写入完整剪贴板正文、JWT、OCR 原文或转换结果。

---

## 1. 产品背景

粘易当前已经具备文本和图片剪贴板历史、本地 SQLite 持久化、搜索、来源应用筛选、收藏、时间线分组、全局快捷键、键盘导航、直接粘贴、敏感内容过滤和存储清理等基础能力。

当前搜索仍以简单子串匹配和时间倒序为主。开发者在大量代码、命令、JSON、URL、报错信息和临时文本中寻找历史内容时，存在以下问题：

- 只记得部分字符时难以快速找到记录。
- 无法通过结构化语法组合来源、类型、时间和收藏条件。
- 常用但稍早的内容容易被新记录淹没。
- 找到 JSON、JWT、Base64、时间戳等内容后，还需要切换到其他工具处理。
- 截图中的报错、代码和配置无法进入文本搜索。
- 同一内容重复复制时，主列表虽然保持干净，但缺少来源和重复使用上下文。

本轮迭代目标是在不破坏“打开即搜、回车即贴”的核心体验下，把粘易升级为面向开发者的渐进式剪贴板效率工具。

---

## 2. 产品目标

### 2.1 核心目标

1. 用户输入普通关键词后，能够获得比单纯时间倒序更准确的混合排序结果。
2. 用户可以通过 `app:`、`type:`、`fav:`、`before:`、`after:` 组合筛选历史记录。
3. 用户找到内容后，可以通过右键菜单或 `Command + K` 执行本地开发者内容动作。
4. 内容动作结果必须先预览，可编辑后再复制、直接粘贴或保存为新记录。
5. 图片文字识别必须由用户主动触发，OCR 结果保存在本机并进入搜索。
6. 重复内容保持单条主记录，同时保留最近来源事件和长期聚合统计。
7. 所有功能保持本地运行，不依赖账号、网络、云服务或第三方 API。

### 2.2 成功标准

- 常规数据量下，内存初筛耗时小于 16ms。
- 数据库候选查询与混合排序常规耗时小于 100ms。
- 搜索输入停止 150ms 后触发完整查询。
- 搜索请求不会出现旧请求覆盖新请求的竞态。
- 文本匹配分始终是排序主因，旧记录不会只因高使用次数长期霸榜。
- 所有内容动作均不修改原记录。
- 未复制、未粘贴、未保存的动作会话在关闭详情后完全丢弃。
- JWT 页面始终明确提示“内容已解析，但签名未验证”。
- OCR 不自动扫描历史图片，不上传图片。
- 完整单元测试和 Release 验证全部通过。

---

## 3. 非目标

首版明确不包含：

- 自建账号、云同步或跨设备数据库同步。
- iPhone 或 iPad 独立客户端。
- 自动后台 OCR 全部图片。
- SQLite FTS 全文索引。
- AI 内容分类、摘要、改写或翻译。
- JWT 签名验证、JWT 生成、Secret 或公钥存储。
- 固定代码片段、变量模板和片段分组。
- 多条记录连续粘贴或粘贴队列。
- 用户自定义脚本、插件市场或工作流保存。
- 动作链完整持久化、参数持久化或中间结果持久化。
- Shell 命令执行、SQL 执行或网络请求。

未来跨设备能力优先探索 Apple 通用剪贴板等系统能力，不在本轮开发范围内。

---

## 4. 用户画像与典型场景

### 4.1 主用户

日常使用 VS Code、Xcode、JetBrains IDE、Terminal、iTerm2、浏览器、数据库客户端和即时通讯工具的开发者。

### 4.2 兼容用户

需要搜索文本、图片、链接和重复办公内容的普通用户。普通用户无需理解搜索语法和内容类型，仍可按现有方式使用。

### 4.3 典型场景

1. 开发者记得命令中包含 `docker`，输入关键词即可在 Terminal 和 IDE 复制记录中定位。
2. 输入 `app:terminal type:shell docker`，只查看 Terminal 来源的 Shell 内容。
3. 找到压缩 JSON 后执行“JSON 格式化”，编辑结果并直接粘贴回 IDE。
4. 对 Base64 字符串先执行解码，再对结果执行 JSON 格式化。
5. 对 JWT 查看 Header、Payload、过期状态，但不验证签名。
6. 将 10 位或 13 位时间戳转换为本地时间、UTC 和 ISO 8601。
7. 对错误截图手动执行 OCR，修正文字后保存并通过关键词搜索。
8. 查看一条重复复制命令最近来自哪些应用，以及 30 天以前的来源汇总。

---

## 5. 总体设计原则

1. **默认极简**：主入口仍是现有历史浮层和搜索框。
2. **渐进增强**：结构化语法、类型图标、右键动作和 `Command + K` 不打扰基础使用。
3. **原始数据安全**：所有转换均生成临时结果，不覆盖原记录。
4. **本地优先**：搜索、分类、转换、OCR 全部在本机执行。
5. **模块隔离**：搜索、内容动作、OCR 各自拥有独立边界，ViewModel 只协调状态。
6. **可测试**：解析、评分、分类、转换、事件聚合均应为无 UI 依赖的可测试单元。
7. **可扩展但不过度设计**：首版使用注册式动作架构，但不实现插件系统。

---

## 6. 总体架构

建议在现有项目中新增以下能力域：

```text
MacPasteHistory/
├── Search/
│   ├── SearchQueryParser.swift
│   ├── SearchSuggestionProvider.swift
│   ├── SearchCandidateProvider.swift
│   ├── SearchRanker.swift
│   ├── SearchCoordinator.swift
│   └── SearchRankingWeights.swift
├── ContentActions/
│   ├── ContentClassifier.swift
│   ├── ContentAction.swift
│   ├── ContentActionRegistry.swift
│   ├── ContentActionExecutor.swift
│   ├── ActionSession.swift
│   ├── ActionSessionStep.swift
│   └── Actions/
│       ├── JSONActions.swift
│       ├── URLActions.swift
│       ├── Base64Actions.swift
│       ├── JWTActions.swift
│       ├── TimestampActions.swift
│       ├── TextActions.swift
│       ├── SQLActions.swift
│       └── ShellActions.swift
├── OCR/
│   ├── OCRService.swift
│   ├── OCRResult.swift
│   └── OCRStatus.swift
├── Models/
│   ├── DetectedContentType.swift
│   ├── ParsedSearchQuery.swift
│   ├── SearchResult.swift
│   ├── ClipboardCaptureEvent.swift
│   └── ClipboardCaptureEventSummary.swift
├── ViewModels/
│   ├── ClipboardHistoryViewModel.swift
│   ├── ContentActionPanelViewModel.swift
│   └── OCRViewModel.swift
└── Views/
    ├── MainPanelView.swift
    ├── SearchTokenView.swift
    ├── SearchSuggestionView.swift
    ├── ContentActionPanelView.swift
    ├── ContentActionPreviewView.swift
    ├── SyntaxHighlightedTextView.swift
    └── OCRResultView.swift
```

允许 Codex 根据现有实际目录做最小范围调整，但不得把所有逻辑继续堆入 `ClipboardHistoryViewModel` 或 `MainPanelView`。

### 6.1 搜索数据流

```text
搜索框输入
→ SearchQueryParser 解析普通关键词和结构化条件
→ 已加载结果在内存中立即初筛
→ 150ms 防抖
→ Repository 查询数据库候选
→ SearchRanker 计算混合得分
→ SearchCoordinator 丢弃过期请求
→ 刷新列表并尽量保持当前选中项
```

### 6.2 内容动作数据流

```text
选中历史记录
→ 读取有效内容类型
→ ContentActionRegistry 返回推荐动作
→ 用户选择动作
→ ContentActionExecutor 校验并执行
→ ActionSession 保存本次会话步骤
→ 右侧详情面板显示可编辑结果
→ 复制 / 直接粘贴 / 保存为新记录
```

### 6.3 OCR 数据流

```text
用户在图片详情点击“识别文字”
→ OCRService 使用 Vision 本地识别
→ 用户查看并修正文本
→ 用户确认保存
→ 更新 ocr_text 和 searchable_text
→ 触发内容类型识别
→ OCR 文本进入搜索与内容动作流程
```

---

## 7. 功能需求一：增强搜索

### 7.1 普通搜索

编号：`SEARCH-001`

- 用户直接输入文字时，系统应搜索 `searchable_text`。
- 文本记录的 `searchable_text` 至少包含原始文本。
- 图片记录完成 OCR 后，`searchable_text` 至少包含 OCR 文本。
- 候选查询可同时参考来源应用名和 Bundle ID，但来源字段命中权重低于正文命中。
- 搜索不区分英文大小写。
- 首版不要求中文分词，中文按照子串匹配处理。
- 空搜索保持现有时间线逻辑，按最近捕获时间倒序。

### 7.2 搜索语法

编号：`SEARCH-002`

首版支持以下结构化条件：

| 语法 | 说明 | 示例 |
| --- | --- | --- |
| `app:` | 来源应用名称或 Bundle ID | `app:terminal` |
| `type:` | 内容类型 | `type:json` |
| `fav:` | 收藏状态 | `fav:true` |
| `before:` | 早于某日期或相对天数 | `before:7d` |
| `after:` | 晚于某日期或相对天数 | `after:2026-08-01` |

支持的 `type:` 值：

```text
text, image, json, url, base64, jwt, timestamp, sql, shell
```

规则：

- 普通关键词可与结构化条件任意组合。
- 带空格的值使用双引号，例如 `app:"Visual Studio Code"`。
- 同类条件重复输入时，最后一个有效条件生效，前面的条件在解析结果中被替换。
- `fav:` 只接受 `true` 和 `false`，不接受其他值。
- `before:`、`after:` 接受 `Nd` 相对天数或 `YYYY-MM-DD`。
- 未知前缀，例如 `repo:foo`，按普通关键词处理，不显示错误。
- 已知前缀但值无效时，显示可移除的错误标签；完整查询不得崩溃。
- 搜索框必须保留原始输入文本，标签仅作为辅助呈现，不得造成光标跳动。

### 7.3 搜索补全

编号：`SEARCH-003`

- 输入 `a`、`ap`、`app:` 时提供 `app:` 提示。
- 输入 `type:` 后展示支持类型。
- 输入 `app:` 后根据已有来源应用提供候选。
- 输入 `fav:` 后只展示 `true`、`false`。
- 输入 `before:`、`after:` 后展示 `1d`、`7d`、`30d` 和日期格式说明。
- 上下方向键选择提示，`Enter` 接受提示，`Esc` 关闭提示。
- 提示列表不得抢占历史列表的全局键盘焦点。

### 7.4 分层响应

编号：`SEARCH-004`

- 每次输入先对当前已加载记录做内存初筛。
- 完整数据库搜索使用 150ms 防抖。
- 每次完整搜索生成递增请求 ID，或取消上一个异步任务。
- 只有最新请求允许更新 UI。
- 查询开始时保留旧结果，不得出现空白闪烁。
- 数据库结果返回后平滑替换内存初筛结果。
- 搜索条件没有实质变化时，不重复查询。

### 7.5 混合排序

编号：`SEARCH-005`

排序必须保证文本相关度高于使用行为。建议首版使用以下可集中配置的权重：

```text
完全匹配                    1000
前缀匹配                     700
完整词匹配                   500
子串匹配                     300
模糊匹配                   0...250
最近捕获时间               0...200
最近直接粘贴               0...120
直接粘贴次数               0...80
从粘易复制次数             0...40
收藏加分                      30
来源应用命中               0...80
```

计算要求：

- `SearchRankingWeights` 统一保存常量，禁止散落 magic number。
- 时间衰减以 `last_captured_at` 为主，建议 7 天半衰期。
- 最近粘贴时间建议 14 天半衰期。
- 次数加分使用对数增长，例如 `log2(count + 1)`，并受上限约束。
- 普通关键词有多个时，各关键词分别评分后求和，并给予“全部关键词均命中”额外小幅加分。
- 收藏和次数不能让无关键词匹配的记录进入关键词搜索结果。
- 空搜索不使用文本相关度，按 `last_captured_at` 倒序，收藏不置顶。

### 7.6 关键词高亮

编号：`SEARCH-006`

- 只高亮普通关键词，不高亮 `app:`、`type:` 等结构化值。
- 长文本只处理当前预览范围。
- 高亮仅影响展示，不修改字符串内容。
- 图片 OCR 预览可以高亮 OCR 文本中的普通关键词。

### 7.7 选择状态

编号：`SEARCH-007`

- 数据库完整结果替换内存结果时，如果原选中记录仍存在，应保持选中。
- 原选中记录不存在时，选择第一条结果。
- 用户正在使用动作面板或结果面板时，搜索结果刷新不得关闭当前动作会话。

---

## 8. 功能需求二：内容类型识别

### 8.1 支持类型

编号：`CLASSIFY-001`

```swift
enum DetectedContentType: String, CaseIterable {
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
```

识别优先级：

```text
JWT → JSON → URL → Timestamp → Base64 → SQL → Shell → Plain Text
```

图片主类型始终为 `image`；完成 OCR 后，应额外对 OCR 文本进行识别，并作为图片可用动作类型。

### 8.2 分层识别时机

编号：`CLASSIFY-002`

- 捕获时立即执行低成本识别：JWT、JSON、URL、明显时间戳、标准 Base64。
- SQL、Shell 使用多特征评分，可在应用空闲时补充执行。
- 用户打开动作面板时，如果识别未完成，立即执行一次完整识别。
- 识别失败或置信度低时使用 `plainText`。
- 后台识别不得阻塞剪贴板捕获和主线程 UI。

### 8.3 识别规则

编号：`CLASSIFY-003`

#### JWT

- 必须恰好由三个 `.` 分隔段组成。
- Header 和 Payload 必须可按 Base64URL 解码。
- Header 和 Payload 解码后必须是合法 JSON 对象。
- 不验证 Signature。

#### JSON

- 去除首尾空白后，可被 `JSONSerialization` 解析。
- 首版只将顶层对象或数组标记为 JSON，避免普通数字或字符串被误识别。

#### URL

- 必须可被 `URLComponents` 解析。
- 首版自动识别 `http`、`https`、`file`、`ssh`、`git` 协议。
- 无协议普通域名不自动识别为 URL，但用户仍可手动指定。

#### Timestamp

- 只自动识别纯数字 10 位秒级或 13 位毫秒级时间戳。
- 转换后的日期必须位于 2000-01-01 至 2100-01-01 之间。
- 不满足范围时按普通文本处理。

#### Base64

- 最小长度 8 个字符。
- 支持标准 Base64 和 URL-safe Base64。
- 字符集、长度和填充必须合法。
- 解码结果必须是有效 UTF-8，且可打印字符占比不低于 85%。
- JWT 必须先于 Base64 判断。

#### SQL

- 使用特征评分，不允许仅凭单个关键字判断。
- 至少满足“语句起始关键字 + 第二个 SQL 结构关键字”，例如 `SELECT + FROM`、`UPDATE + SET`、`INSERT + INTO`。
- 忽略字符串字面量内的关键字。

#### Shell

- 需要同时具备命令形态和 Shell 特征，例如参数、管道、重定向、环境变量或命令连接符。
- 单个普通单词不得自动识别为 Shell。

### 8.4 用户修正

编号：`CLASSIFY-004`

- 保存 `detected_type` 和 `user_override_type`。
- 实际类型优先级为 `user_override_type > detected_type`。
- 用户可以改为任意支持类型或“自动识别”。
- 用户选择“自动识别”时清空 `user_override_type` 并重新执行当前版本规则。
- 后台识别和规则升级不得覆盖人工类型。

### 8.5 识别元数据

编号：`CLASSIFY-005`

每次自动识别保存：

```text
detected_type
detection_confidence
detection_version
detected_at
```

- `detection_confidence` 范围为 `0.0...1.0`。
- `detection_version` 首版固定为 `1`。
- 后续规则升级时，只重新识别旧版本且没有人工覆盖的记录。

### 8.6 类型图标

编号：`CLASSIFY-006`

- 主列表只对 JSON、JWT、URL、Base64、Timestamp、SQL、Shell 显示轻量图标。
- 普通文本不显示类型图标。
- 图片沿用现有图片标识。
- 悬停图标显示类型名称。
- 点击图标打开推荐动作。
- 图标必须提供无障碍标签，不能只依赖颜色区分。

---

## 9. 功能需求三：内容动作系统

### 9.1 动作协议

编号：`ACTION-001`

统一接口建议如下：

```swift
protocol ContentAction {
    var id: String { get }
    var title: String { get }
    var supportedTypes: Set<DetectedContentType> { get }
    var category: ContentActionCategory { get }

    func validate(input: String) -> ActionValidationResult
    func execute(input: String) throws -> ContentActionResult
}
```

约束：

- `id` 必须稳定，不随本地化文案变化。
- 动作显示名必须通过本地化资源获取。
- Action 不得直接访问 UI、数据库或剪贴板。
- Action 不得发起网络请求。
- 每个 Action 必须有独立单元测试。

### 9.2 动作入口

编号：`ACTION-002`

采用双入口：

1. 右键菜单或“更多”菜单：显示当前类型的推荐动作。
2. 选中记录后按 `Command + K`：打开完整动作面板。

完整动作面板要求：

- 支持输入动作名称搜索。
- 推荐动作位于顶部。
- 其他动作按分类展示。
- 不适用动作可以隐藏；如果选择显示全部动作，则不适用动作显示禁用原因。
- 上下方向键选择，`Enter` 执行，`Esc` 关闭。

### 9.3 JSON 动作

编号：`ACTION-JSON`

必须提供：

- JSON 格式化：4 空格缩进，保持 Unicode 字符，不转义斜杠。
- JSON 压缩：移除不必要空白。
- JSON 校验：不生成衍生文本时，也要返回明确的合法/非法结果；非法时包含解析错误描述。
- JSON 字符串转义：输出可嵌入 JSON 字符串值的转义内容，不额外包裹引号。
- JSON 字符串反转义：接受带或不带外层双引号的字符串；非法转义返回错误。

### 9.4 URL 动作

编号：`ACTION-URL`

必须提供：

- URL 编码：按查询参数值语义进行百分号编码。
- URL 解码：解码百分号转义，非法输入返回错误。
- 提取域名：输出 `host`；无 host 时返回不适用错误。
- 解析查询参数：输出稳定排序的可读文本，每行格式为 `key = value`；重复 key 保留多行。

### 9.5 Base64 动作

编号：`ACTION-BASE64`

必须提供：

- 文本编码为标准 Base64。
- 标准 Base64 解码为 UTF-8 文本。
- URL-safe Base64 解码为 UTF-8 文本。
- Base64 合法性校验。
- 解码时自动处理缺失的合法 padding。
- 解码失败、非 UTF-8 或结果包含大量不可打印字符时返回明确错误，不生成空字符串。

### 9.6 JWT 动作

编号：`ACTION-JWT`

首版只解析，不验证签名。

必须提供：

- 解析 Header。
- 解析 Payload。
- JSON 格式化展示。
- 展示 `alg`、`typ`、`iss`、`sub`、`aud`。
- 将 `iat`、`exp`、`nbf` 自动转换为本地时间、UTC 和 ISO 8601。
- 根据当前时间显示“未过期”“已过期”或“无 exp 字段”。
- 一键复制 Header JSON、Payload JSON 或完整解析摘要。
- 页面固定显示：“内容已解析，但签名未验证，不能据此判断 Token 可信。”
- 禁止提供 Secret、公钥输入框、签名验证和 JWT 生成。

### 9.7 时间戳动作

编号：`ACTION-TIMESTAMP`

必须提供：

- 10 位秒级时间戳转日期。
- 13 位毫秒级时间戳转日期。
- 自动判断秒或毫秒。
- 日期文本转 Unix 秒级和毫秒级时间戳。
- 日期解析支持 ISO 8601 和 `yyyy-MM-dd HH:mm:ss`。
- 结果同时展示本地时区、UTC、ISO 8601、秒级和毫秒级值。
- 提供单独复制每种结果的操作。
- 输入不合法时说明接受的格式。

### 9.8 普通文本动作

编号：`ACTION-TEXT`

必须提供：

- 去除首尾空白。
- 删除空行。
- 按行去重，保留第一次出现的顺序。
- 合并为单行：连续空白折叠为单个空格。
- 转大写。
- 转小写。
- 包裹为 Markdown 代码块：首版使用不带语言名称的三反引号代码块。

### 9.9 Shell 动作

编号：`ACTION-SHELL`

必须提供 Shell 参数安全转义：

- 将输入视为单个 Shell 参数。
- 使用单引号包裹。
- 内部单引号使用标准 `'\''` 形式处理。
- 只输出转义文本，绝不执行命令。

### 9.10 SQL 动作

编号：`ACTION-SQL`

必须提供 SQL 合并为单行：

- 折叠字符串字面量和注释之外的多余空白。
- 不得修改单引号、双引号或反引号中的内容。
- 不得把 `--` 或 `/* */` 注释内容拼入字符串字面量。
- 首版不做 SQL 格式化、美化或方言解析。

---

## 10. 功能需求四：动作结果预览与串联

### 10.1 右侧详情面板

编号：`PREVIEW-001`

- 默认历史浮层保持现有宽度和布局。
- 选择动作后，在右侧打开详情面板，左侧历史列表继续可见。
- 推荐展开总宽度约 1240pt，但必须根据当前屏幕可用区域动态限制。
- 窗口左右至少保留 24pt 安全边距。
- 可用宽度不足时，右侧面板退化为当前浮层内覆盖页。
- 不得创建独立普通窗口，不得破坏全屏 Space 上方展示能力。

### 10.2 面板内容

编号：`PREVIEW-002`

右侧面板包含：

- 动作名称。
- 当前有效内容类型。
- 必要风险提示。
- “原始内容”和“处理结果”切换。
- 可编辑结果区域。
- 当前动作步骤摘要。
- 固定底部操作：复制结果、直接粘贴、保存为新记录。

### 10.3 可编辑结果

编号：`PREVIEW-003`

- 转换成功后结果默认可编辑。
- 用户修改后显示“已编辑”状态。
- 提供“恢复转换结果”，恢复当前步骤最初输出。
- 复制、直接粘贴、保存新记录都使用当前编辑文本。
- 关闭面板时未使用的编辑结果直接丢弃，不提示保存。
- 转换失败时结果区域为只读错误状态。

### 10.4 语法高亮

编号：`PREVIEW-004`

首版只对以下内容提供基础高亮：

- JSON：键、字符串、数字、布尔、`null`。
- JWT：Header、Payload 复用 JSON 高亮，并突出 `iat`、`exp`、`nbf`。
- SQL：关键字、字符串、数字和注释。

要求：

- 高亮只作用于展示层。
- 剪贴板输出必须是纯文本。
- 不引入重量级第三方代码编辑器。
- 普通文本、URL、Base64、Shell 首版使用等宽纯文本。

### 10.5 键盘交互

编号：`PREVIEW-005`

- `Command + K`：打开动作面板。
- `Command + C`：详情面板激活时复制当前结果；普通列表激活时保持系统默认或复制当前记录。
- `Command + Enter`：直接粘贴当前结果。
- `Esc`：先关闭动作选择层，再关闭结果详情，再关闭整个历史浮层。
- 方向键在列表和动作面板之间切换时，焦点必须可预测。

### 10.6 动作串联

编号：`PREVIEW-006`

- 用户可基于当前编辑结果再次打开动作面板。
- 下一动作输入使用当前编辑结果。
- `ActionSession` 保存本次会话步骤栈。
- 每一步保存动作 ID、动作名称、输入、初始输出、当前编辑输出和错误状态。
- 用户可返回上一步。
- 返回上一步后执行新动作时，删除原分支后续步骤。
- 关闭详情面板后完整步骤栈销毁。
- 首版不持久化步骤栈。

---

## 11. 功能需求五：复制、粘贴与衍生记录

### 11.1 使用统计

编号：`USAGE-001`

区分以下概念：

- `capture_count`：内容被系统剪贴板监控捕获的次数。
- `reuse_copy_count`：用户从粘易复制原内容或动作结果的次数。
- `paste_count`：用户从粘易直接粘贴原内容或动作结果的次数。

行为规则：

- 点击“复制结果”增加原始记录的 `reuse_copy_count`。
- 从列表复制原记录增加该记录的 `reuse_copy_count`。
- 直接粘贴原记录或动作结果增加原始记录的 `paste_count`。
- “保存为新记录”不增加原记录使用次数。
- 仅查看、OCR、识别类型或执行转换不计使用次数。
- 新衍生记录的使用统计从 0 开始。

### 11.2 保存为新记录

编号：`DERIVED-001`

- 保存动作结果时创建独立主记录。
- 新记录重新计算内容哈希和自动类型。
- 如果结果与已有主记录哈希相同，复用现有主记录并新增捕获事件，不创建重复主记录。
- 新记录拥有独立收藏、使用次数和搜索排序。

保存以下衍生信息：

```text
derived_from_history_id
derived_action_id
derived_action_summary
derived_at
derived_source_preview
derived_source_hash
```

规则：

- `derived_from_history_id` 指向最初原始记录。
- 多步骤时 `derived_action_id` 保存最后一个动作 ID。
- `derived_action_summary` 保存简短链路，例如 `Base64 解码 → JSON 格式化`。
- `derived_source_preview` 保存不超过 120 个字符的脱敏摘要。
- `derived_source_hash` 保存原记录内容哈希。
- 不保存中间步骤、参数或动作版本。

### 11.3 删除关系

编号：`DERIVED-002`

- 删除原记录时，衍生记录必须保留。
- `derived_from_history_id` 使用 `ON DELETE SET NULL`。
- 衍生动作摘要、生成时间、来源摘要和来源哈希继续保留。
- 详情显示“来源记录已删除”。
- 删除衍生记录不影响原记录。

### 11.4 衍生标识

编号：`DERIVED-003`

- 主列表对衍生记录显示轻量图标，不显示长标签。
- 悬停显示 `derived_action_summary`。
- 点击图标打开衍生详情。
- 图标必须提供无障碍文本。

---

## 12. 功能需求六：手动 OCR

### 12.1 OCR 入口

编号：`OCR-001`

- 仅图片详情显示“识别文字”。
- 不自动识别新图片或历史图片。
- 正在识别时禁用重复点击。
- OCR 失败时允许重试。

### 12.2 OCR 实现

编号：`OCR-002`

- 使用 Apple Vision `VNRecognizeTextRequest`。
- 使用 `.accurate` 模式。
- 开启语言纠正。
- 优先支持简体中文、繁体中文和英文。
- 在后台任务执行，主线程只更新状态。
- 不写入临时网络目录，不上传图片。

### 12.3 OCR 状态

编号：`OCR-003`

```swift
enum OCRStatus: String {
    case notStarted
    case recognizing
    case recognized
    case failed
}
```

数据库保存：

```text
ocr_status
ocr_text
ocr_updated_at
ocr_error_code
```

- 不保存完整底层错误堆栈。
- `ocr_error_code` 只保存可枚举的错误类型。

### 12.4 OCR 结果编辑与保存

编号：`OCR-004`

- 识别结果先进入可编辑区域。
- 用户确认保存后才写入 `ocr_text`。
- 用户取消时不修改数据库。
- 保存后更新 `searchable_text`。
- 保存后执行内容类型识别。
- OCR 文本可继续执行 JSON、URL、Base64、JWT、Timestamp、SQL、Shell 和普通文本动作。

### 12.5 OCR 搜索

编号：`OCR-005`

- OCR 保存后立即可被普通关键词搜索。
- `type:image` 仍能找到该记录。
- OCR 推断出的开发者类型只用于动作推荐，不把图片主记录改成文本记录。
- 搜索结果可显示 OCR 文本摘要，但仍保留图片缩略图。

---

## 13. 数据模型与数据库迁移

### 13.1 现有主表迁移

为 `clipboard_history` 新增：

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

ALTER TABLE clipboard_history ADD COLUMN derived_from_history_id INTEGER;
ALTER TABLE clipboard_history ADD COLUMN derived_action_id TEXT;
ALTER TABLE clipboard_history ADD COLUMN derived_action_summary TEXT;
ALTER TABLE clipboard_history ADD COLUMN derived_at DATETIME;
ALTER TABLE clipboard_history ADD COLUMN derived_source_preview TEXT;
ALTER TABLE clipboard_history ADD COLUMN derived_source_hash TEXT;
```

迁移初始化规则：

- `searchable_text = COALESCE(text_content, '')`。
- `first_captured_at = created_at`。
- `last_captured_at = created_at`。
- 现有记录 `capture_count = 1`。
- 现有图片 `ocr_status = 'notStarted'`。
- 现有重复记录的真实首次时间无法恢复，接受以当前 `created_at` 作为迁移基线。
- 迁移必须使用现有版本化事务机制。

迁移后修改重复内容更新逻辑：

- 不再更新 `created_at`。
- 更新 `last_captured_at`。
- `capture_count += 1`。
- 更新最近来源 `source_app`、`source_bundle_id`。
- 新增一条捕获事件。

### 13.2 捕获事件表

```sql
CREATE TABLE clipboard_capture_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    history_id INTEGER NOT NULL,
    source_app TEXT,
    source_bundle_id TEXT,
    captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(history_id) REFERENCES clipboard_history(id) ON DELETE CASCADE
);
```

索引：

```sql
CREATE INDEX idx_capture_events_history_time
ON clipboard_capture_events(history_id, captured_at DESC);

CREATE INDEX idx_capture_events_captured_at
ON clipboard_capture_events(captured_at);
```

### 13.3 捕获事件聚合表

```sql
CREATE TABLE clipboard_capture_event_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    history_id INTEGER NOT NULL,
    source_app TEXT,
    source_bundle_id TEXT,
    capture_count INTEGER NOT NULL DEFAULT 0,
    first_captured_at DATETIME NOT NULL,
    last_captured_at DATETIME NOT NULL,
    UNIQUE(history_id, source_bundle_id, source_app),
    FOREIGN KEY(history_id) REFERENCES clipboard_history(id) ON DELETE CASCADE
);
```

### 13.4 事件保留策略

编号：`EVENT-001`

- 最近 30 天保留明细事件。
- 30 天以前按 `history_id + source_bundle_id + source_app` 聚合。
- 聚合使用单一事务：查询 → upsert summary → 删除已聚合明细。
- 聚合成功提交前不得删除明细。
- 应用启动清理阶段执行一次；同一天内不重复执行。
- 事件表不计入现有文本和图片记录数量上限。
- 删除主记录时，事件和聚合数据级联删除。

### 13.5 外键

- 数据库连接必须执行 `PRAGMA foreign_keys = ON;`。
- 新增测试验证 `CASCADE` 和 `SET NULL` 行为。
- 如果现有连接未启用外键，必须在连接初始化处统一启用，不得在单个 Repository 临时设置。

### 13.6 新增索引

建议新增：

```sql
CREATE INDEX idx_clipboard_last_captured_at
ON clipboard_history(last_captured_at DESC);

CREATE INDEX idx_clipboard_detected_type
ON clipboard_history(detected_type);

CREATE INDEX idx_clipboard_user_override_type
ON clipboard_history(user_override_type);

CREATE INDEX idx_clipboard_last_pasted_at
ON clipboard_history(last_pasted_at DESC);
```

首版不创建 FTS 虚拟表。

---

## 14. Repository 与服务接口要求

Codex 可在实施计划中细化签名，但至少应提供以下职责明确的方法：

### 14.1 ClipboardHistoryRepository

```swift
func fetchSearchCandidates(query: ParsedSearchQuery, limit: Int) throws -> [ClipboardHistoryItem]
func recordCapture(historyID: Int64, sourceApp: String?, sourceBundleID: String?) throws
func recordReuseCopy(historyID: Int64, at date: Date) throws
func recordPaste(historyID: Int64, at date: Date) throws
func updateDetectedType(id: Int64, result: ContentDetectionResult) throws
func updateUserOverrideType(id: Int64, type: DetectedContentType?) throws
func saveOCRResult(id: Int64, text: String, detectedType: ContentDetectionResult) throws
func saveDerivedText(_ request: DerivedClipboardRecordRequest) throws -> ClipboardHistoryItem
func fetchCaptureEvents(historyID: Int64, since date: Date) throws -> [ClipboardCaptureEvent]
func fetchCaptureSummaries(historyID: Int64) throws -> [ClipboardCaptureEventSummary]
```

### 14.2 SearchCoordinator

```swift
func search(input: String, loadedItems: [ClipboardHistoryItem]) async -> SearchResponse
func cancelCurrentSearch()
```

### 14.3 ContentClassifier

```swift
func classifyFast(_ input: String) -> ContentDetectionResult
func classifyComplete(_ input: String) -> ContentDetectionResult
```

### 14.4 ContentActionRegistry

```swift
func recommendedActions(for type: DetectedContentType) -> [any ContentAction]
func allActions(matching keyword: String?) -> [any ContentAction]
func action(id: String) -> (any ContentAction)?
```

### 14.5 OCRService

```swift
func recognizeText(in imageURL: URL) async throws -> OCRResult
```

---

## 15. 错误处理与用户反馈

### 15.1 搜索错误

- 单个无效结构化条件显示错误标签，不阻止其他有效条件和关键词搜索。
- 数据库查询失败时保留当前结果，并显示轻量错误提示。
- 搜索错误不得关闭历史浮层。

### 15.2 动作错误

统一错误类型至少包括：

```text
invalidInput
unsupportedInput
parseFailed
decodeFailed
nonUTF8Result
outOfRange
emptyResult
```

- 错误信息必须说明失败原因和可接受格式。
- 转换失败不得清空原始内容和上一步结果。
- 不得使用空 `catch` 或 `try?` 吞掉核心错误。

### 15.3 OCR 错误

- 图片不存在、图片不可解码、Vision 失败、未识别到文字必须区分。
- 用户可重试。
- OCR 失败不得修改现有 `ocr_text`。

### 15.4 自动粘贴错误

- 沿用现有辅助功能权限提醒。
- 处理结果写入剪贴板成功但自动粘贴失败时，提示“结果已复制，可手动粘贴”。
- 使用统计只有在对应复制写入或粘贴命令确认成功后更新。

---

## 16. 隐私与安全要求

1. 所有数据仍保存在本机 Application Support 目录。
2. OCR、JWT、JSON、Base64、URL、SQL 和 Shell 处理全部离线。
3. 不新增网络权限和外部 API。
4. 日志禁止记录完整正文、OCR 文本、JWT、URL 查询参数或动作输出。
5. 日志只允许记录记录 ID、内容类型、字符数、动作 ID、耗时和错误代码。
6. JWT 页面必须明确未验证签名。
7. Shell 动作只做字符串转义，禁止执行。
8. SQL 动作只处理文本，禁止连接数据库。
9. OCR 编辑结果保存前必须由用户确认。
10. 敏感记录仍服从现有敏感内容和应用黑名单策略。

---

## 17. 本地化与无障碍

### 17.1 本地化

所有新增内容必须提供：

- 简体中文。
- 繁体中文。
- 英文。

包括：搜索提示、类型名、动作名、错误提示、JWT 风险说明、OCR 状态、衍生说明和快捷键描述。

### 17.2 无障碍

- 类型图标、衍生图标、动作按钮必须提供 Accessibility Label。
- 颜色不能作为唯一状态表达。
- 动作面板和结果面板必须支持完整键盘操作。
- VoiceOver 应能读出当前动作、结果是否已编辑、JWT 是否过期和 OCR 状态。
- 搜索高亮不能破坏正文可读性。

---

## 18. 性能要求

1. 内存初筛目标小于 16ms。
2. 500 条数据库候选查询与排序目标小于 100ms。
3. 完整搜索候选上限首版为 500，最终展示继续使用现有分页策略。
4. 搜索超过 300ms 时显示轻量加载状态。
5. 类型快速识别单条目标小于 5ms。
6. SQL、Shell 完整识别不得在主线程批量执行。
7. OCR 在后台执行，不阻塞滚动和搜索。
8. 语法高亮只处理当前可见或当前编辑文本，不对完整历史批量生成富文本。
9. 事件聚合必须使用事务和批量 SQL，避免逐条 UI 线程操作。

---

## 19. 测试要求

### 19.1 搜索测试

至少覆盖：

- 普通关键词解析。
- 带引号的 `app:`。
- 各结构化条件合法和非法输入。
- 未知前缀按普通关键词处理。
- 重复条件最后值生效。
- 请求取消和旧请求不覆盖新请求。
- 完全匹配、前缀、子串、模糊匹配排序。
- 时间衰减、粘贴次数、复制次数和收藏加分上限。
- 无正文匹配记录不能因使用次数进入结果。
- 关键词高亮只处理普通关键词。

### 19.2 分类测试

至少覆盖：

- JWT 优先于 Base64。
- JSON 对象、数组和非法 JSON。
- 支持协议 URL 和无协议域名。
- 10 位、13 位时间戳及范围外数字。
- 标准 Base64、URL-safe Base64、非 UTF-8 数据和普通英文误判。
- SQL 多特征识别。
- Shell 多特征识别。
- 人工覆盖不被后台识别覆盖。
- detection version 升级行为。

### 19.3 内容动作测试

每个动作至少覆盖：

- 正常输入。
- 空输入。
- 非法输入。
- Unicode。
- 长文本。
- 输出不为空。
- 错误类型正确。

额外覆盖：

- JSON 转义/反转义往返。
- Base64 标准和 URL-safe 解码。
- JWT 三段结构、字段解析和过期状态。
- 时间戳秒/毫秒自动判断。
- SQL 字符串字面量不被错误折叠。
- Shell 单引号转义。

### 19.4 数据库测试

至少覆盖：

- 迁移从当前版本成功升级。
- 迁移重复执行幂等。
- 现有记录字段回填。
- 重复内容不再更新 `created_at`。
- 重复内容更新 `last_captured_at` 和 `capture_count`。
- 捕获事件写入。
- 30 天以前事件聚合和删除。
- 聚合失败事务回滚。
- 删除主记录级联删除事件。
- 删除原记录时衍生记录 `derived_from_history_id` 置空。
- OCR 保存更新 `searchable_text`。
- 使用统计分别更新。

### 19.5 ViewModel 和 UI 状态测试

至少覆盖：

- 内存初筛到数据库结果替换。
- 选中项保持。
- 动作面板打开、搜索、执行和关闭。
- 可编辑结果、已编辑状态和恢复结果。
- 多步骤动作栈、返回上一步和分支删除。
- `Esc` 分层关闭。
- OCR 识别、编辑、保存、取消和失败重试。
- 自动粘贴失败后的复制成功提示。

### 19.6 完整验证

每个任务完成后运行相关定向测试；最终必须运行：

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  test
```

并执行现有 Release readiness、smoke test 和手工 QA 检查。

---

## 20. 核心验收场景

### AC-01 普通搜索

给定历史中存在 `docker compose up -d`，当用户输入 `docker`，则该记录进入结果，关键词高亮，且完全或前缀命中优先于只包含模糊字符的结果。

### AC-02 结构化搜索

给定 Terminal 和 VS Code 都存在包含 `docker` 的记录，当用户输入 `app:terminal type:shell docker`，则只显示 Terminal 来源且有效类型为 Shell 的匹配记录。

### AC-03 搜索竞态

当用户快速从 `j` 输入到 `json`，即使 `j` 的数据库请求最后返回，也不得覆盖 `json` 的结果。

### AC-04 JSON 动作

给定压缩 JSON，用户执行 JSON 格式化后，应在右侧看到可编辑格式化结果；修改后点击直接粘贴，粘贴内容必须是修改后的纯文本，原记录不变。

### AC-05 动作串联

给定 Base64 编码的 JSON，用户执行 Base64 解码，再执行 JSON 格式化，步骤摘要显示 `Base64 解码 → JSON 格式化`，保存后新记录保留该摘要并关联最初原记录。

### AC-06 JWT

给定结构合法但签名未知的 JWT，系统显示 Header、Payload 和过期状态，同时始终显示“签名未验证”提示，不提供密钥输入和验证操作。

### AC-07 时间戳

给定 `1754380800000`，系统自动识别为毫秒级时间戳，并展示本地时间、UTC、ISO 8601、秒级和毫秒级结果。

### AC-08 类型修正

给定一串被误判为 Base64 的普通文本，用户将类型改为普通文本后，列表图标、`type:` 搜索和推荐动作立即使用人工类型，后台识别不得覆盖。

### AC-09 手动 OCR

给定一张报错截图，用户主动识别并修正文字后保存；输入截图中的错误关键词可以找到该图片，结果仍显示图片缩略图。

### AC-10 重复复制事件

同一命令分别从 Terminal、VS Code 和 iTerm2 复制，主列表保持一条记录，`capture_count` 增加，详情显示最近 30 天来源明细。

### AC-11 事件聚合

存在 30 天以前的捕获事件，清理任务执行后，明细被汇总到 summary 表且不重复累计；事务失败时原明细仍存在。

### AC-12 删除原记录

原记录存在衍生记录，删除原记录后衍生记录仍存在，来源外键置空，详情显示动作摘要和“来源记录已删除”。

### AC-13 自动粘贴失败

处理结果成功写入系统剪贴板但辅助功能权限阻止自动粘贴时，系统提示结果已复制，可手动粘贴，并只增加复制统计，不增加成功粘贴统计。

---

## 21. 推荐实施阶段

本节只定义依赖顺序，具体任务拆分由后续 Implementation Plan 给出。

1. 数据库迁移、事件表、外键和 Repository 基础能力。
2. 搜索查询模型、语法解析、候选查询和混合排序。
3. 内容分类模型、快速识别、完整识别和人工覆盖。
4. 内容动作协议、Registry 和各类纯函数动作。
5. 动作面板、右侧结果面板、编辑状态和动作会话栈。
6. 使用统计、衍生记录和来源详情。
7. 手动 OCR、OCR 编辑保存和搜索接入。
8. 本地化、无障碍、性能验证、文档和 Release QA。

每个阶段必须在前一阶段测试通过后再进入下一阶段。

---

## 22. 文档交付要求

开发完成时必须同步更新：

- `docs/architecture/overall-architecture.md`
- 数据库设计文档；如果不存在则新增 `docs/architecture/database-schema.md`
- `docs/user-guide.md`
- `docs/privacy-policy.md`
- `docs/changelog/CHANGELOG.md`
- Release 手工 QA 模板与检查脚本中涉及的新功能项

文档必须说明：

- 搜索语法。
- 内容动作和快捷键。
- JWT 不验证签名。
- OCR 为手动本地识别。
- 使用统计和复制来源历史的含义。
- 衍生记录行为。
- 数据仍仅保存在本机。

---

## 23. Definition of Done

只有同时满足以下条件，功能才视为完成：

- 本 PRD 中所有首版需求已实现。
- 所有新增逻辑具备单元测试。
- 数据库迁移可从当前生产结构无损升级。
- 完整测试套件通过。
- Release readiness 和 smoke test 通过。
- 手工验证搜索、动作串联、JWT、时间戳、OCR、直接粘贴和删除关系。
- 未新增网络依赖和云端数据传输。
- 日志中没有完整剪贴板内容。
- 简体中文、繁体中文和英文文案完整。
- VoiceOver 和完整键盘路径可用。
- 架构、数据库、用户、隐私和变更文档已同步。
- 不存在 `TODO`、临时代码、空实现、被吞掉的错误或无说明的 magic number。

---

## 24. 已冻结决策

以下决策已经确认，实施过程中不得自行更改：

- 产品采用默认极简、能力渐进展开的定位。
- 主用户为开发者，同时兼容普通用户。
- 首阶段优先增强搜索和内容处理。
- 搜索采用普通模糊搜索与结构化语法结合。
- 排序采用相关度、时间和轻量行为加分的混合策略。
- 图片使用手动 OCR，不自动识别全部图片。
- 内容处理结果先预览，再复制、粘贴或保存。
- 首版包含 Base64、JWT 解析和时间戳转换。
- JWT 仅解析，不验证签名。
- 内容动作同时提供右键菜单和 `Command + K`。
- 结果使用右侧详情面板，小屏退化为覆盖页。
- 首版只为 JSON、JWT 和 SQL 提供语法高亮。
- 分开统计从粘易复制和直接粘贴。
- 重复内容使用主记录加捕获事件模型。
- 最近 30 天保留事件明细，更早记录聚合。
- 衍生记录只保存轻量来源关联和动作摘要。
- 删除原记录时保留衍生记录并解除关联。
- 主列表使用轻量衍生图标和开发者类型图标。
- 用户可以持久化修正内容类型。
- 类型识别使用快速识别、空闲补充和动作面板兜底。
- 搜索使用内存初筛加 150ms 防抖数据库查询。
- 搜索只高亮普通关键词。
- 动作结果允许编辑。
- 首版支持本次会话内动作串联。
- 多步骤保存简短动作摘要，不持久化完整工作流。
