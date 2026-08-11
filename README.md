# 粘易

[简体中文](README.md) | [English](README_EN.md)

粘易是一款本地优先的 macOS 剪贴板历史工具。它常驻菜单栏，以轻量浮层呈现文本与图片历史；可选择手动粘贴、按需自动粘贴，也可主动调用 DeepSeek 润色文本。

> 以下界面来自当前 Release 构建，内容均为合成示例数据，不包含真实剪贴板记录。

## 界面预览

### 时间线式复制历史

![粘易时间线式复制历史界面](docs/release/screenshots/01-history-overview.png)

### 图片详情

![粘易图片历史详情界面](docs/release/screenshots/02-image-history.png)

### 设置与隐私控制

<table>
  <tr>
    <td width="50%"><img src="docs/release/screenshots/03-settings-controls.png" alt="粘易通用设置界面"></td>
    <td width="50%"><img src="docs/release/screenshots/04-local-privacy.png" alt="粘易隐私设置界面"></td>
  </tr>
</table>

## 已实现功能

### 文本与图片历史

- 自动记录文本以及 PNG、TIFF、JPEG 等常见图片内容
- 支持从 Finder 复制本地图片文件，并生成本地缩略图用于预览
- 通过内容哈希合并重复记录，保留最近复制时间与来源应用
- V1.0.3 在单次轮询管线内固定来源与捕获时间，并以亚秒精度排列快速重复捕获
- 历史、图片和非密钥设置保存在当前 Mac；只有用户主动选择 AI 润色的文本会发送给 DeepSeek

### 时间线、搜索与筛选

- 按“刚刚 / 今天 / 更早”组织历史，并展示最近来源应用快捷筛选栏
- 支持文本内容搜索、文本/图片类型筛选、时间范围筛选和仅看收藏
- 支持 `app:`、`type:`、`fav:`、`before:`、`after:` 结构化搜索，以及搜索建议和可移除条件标签
- 结合内容相关度、模糊匹配、复制时间、使用次数、收藏和来源应用进行混合排序
- 支持长文本详情、图片预览、分页加载、收藏和单条删除

### 本地内容动作与 OCR

- 自动识别纯文本、图片、JSON、URL、Base64、JWT、时间戳、SQL、Shell 和 OCR 文本，并提供适合当前类型的操作
- 可通过 `Command + K`、类型图标或更多操作菜单打开动作面板
- 支持 JSON 格式化与校验、URL 编解码、Base64 编解码、JWT 字段查看、时间戳转换、SQL 格式化、Shell 参数转义和常用文本处理
- 动作可连续执行，结果可编辑，并可复制、直接粘贴或另存为新的派生历史记录；原记录不会被覆盖
- 图片文字识别由用户主动触发，使用 macOS Vision 在本机完成；校对并保存后，识别文字可参与搜索和内容动作
- JWT 动作仅解析可见字段与过期状态，不验证签名或内容可信度

### 快速恢复与粘贴

- 使用全局快捷键打开历史，默认为 `Command + Shift + V`，可在设置中修改
- 历史浮层可显示在全屏应用上方，无需切换到普通窗口
- 自动粘贴默认关闭；单击记录或按 `Enter` 会先恢复内容，关闭时提示使用 `Command-V` 手动粘贴
- 用户开启自动粘贴且授予辅助功能权限后，才会返回原应用并发送 `Command-V`
- 支持仅恢复到剪贴板，以及从详情或更多操作菜单收藏、粘贴和删除
- 首次启动不会请求辅助功能权限；仅在开启自动粘贴后提供授权入口

### AI 文本润色

- 文本动作中提供显式触发的 AI 润色，默认模型为 `deepseek-v4-flash`，可在设置中修改
- 首次发送前说明文本将交由 DeepSeek 远程处理；拒绝不会影响任何本地剪贴板功能
- API Key 存储于 macOS 钥匙串，结果可继续编辑、复制、保存或粘贴
- 展示并本地汇总服务商报告的输入、输出和总 Token；用量表不保存原文或响应正文

### 隐私与安全控制

- 可分别启用或停用文本、图片历史记录，也可以随时暂停全部记录
- 可一键屏蔽当前前台应用，或通过应用名称与 Bundle ID 管理黑名单
- 敏感内容过滤默认开启，会跳过常见密码、令牌、身份信息和银行卡等文本模式
- V1.0.3 使用结构化类别、置信度与安全原因码减少开发者 ID、哈希和普通长文本误判
- 可在“设置 → 隐私”中关闭过滤；首次关闭前会提示敏感文本可能写入本机未加密的 SQLite 历史数据库。需要恢复保护时，在同一位置重新开启即可立即生效
- 应用不会在日志中记录完整的剪贴板内容

### 关于与更新

- “设置 → 关于与更新”显示当前应用名称、版本和构建号
- Sparkle 可按设置自动检查更新，也可通过“检查更新…”按钮手动检查；正式签名更新发布后，由 Sparkle 验证、安装并重新启动应用
- 更新检查会访问 GitHub Pages 上的固定 appcast 和 GitHub Releases 上的更新资源；不会上传剪贴板历史、图片、内容哈希或设置

### 存储与个性化设置

- 支持设置历史保留天数、文本/图片数量上限、单张图片大小上限和总存储上限
- 启动时自动清理过期或超限数据，并同步移除对应的本地图片文件
- 启动后异步检查数据库与图片存储一致性，只自动重建可证明安全的缩略图并清理超过 24 小时的应用临时文件
- 支持清空文本历史或一次性清除全部本地历史与图片文件
- 支持登录时启动、显示或隐藏 Dock 图标
- 支持跟随系统、浅色和深色外观，切换后立即生效
- 支持简体中文、繁体中文和英文界面

## 产品规划

粘易后续将从“剪贴板历史工具”逐步演进为“本地优先的 macOS 内容工作台”，围绕内容捕获、搜索、整理、转换、复用、工作流与隐私能力持续增强。

| 版本 | 定位 | 重点能力 |
| --- | --- | --- |
| V1.0.x | 核心稳定 | 捕获一致性、敏感检测 V2、存储一致性、搜索生命周期、粘贴架构与数据库治理 |
| V1.1 | 高频内容管理 | 快捷槽位、Tags、智能集合、应用规则、FTS5 搜索 |
| V1.2 | Developer Clipboard | Snippet、模板变量、YAML/XML/IP/CIDR/Cron/cURL 动作、Paste Queue |
| V1.3 | Workflow Automation | Workflow、动作链保存、执行引擎、快捷键、导入导出 |
| V1.4 | AI & Privacy Platform | 多 AI Provider、OpenAI Compatible、Ollama、AI Actions、Privacy Vault、Temporary History、Backup/Restore |

每个版本里程碑完成后创建独立 Git Tag；正式 Release、签名、公证、Sparkle 包与 GitHub Release 留给后续独立发布任务执行。

完整功能说明、版本边界、验收标准与 Codex 长期开发约束请参见：[V1.0 → V1.4 产品规划](docs/roadmap/V1.0-V1.4-PRODUCT_ROADMAP.md)。

## 系统要求

- macOS 14.0 或更高版本
- Xcode 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- 自动粘贴需要在“系统设置 → 隐私与安全性 → 辅助功能”中授权粘易

## 本地构建

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  build
```

## 运行测试

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' \
  test
```

## 隐私说明

剪贴板历史、图片和设置默认仅存储在本机。更新检查会请求 GitHub 托管的 appcast、发布说明和更新包，但不会包含剪贴板历史。AI 润色是明确触发的远程功能，会在首次使用前提示，并仅发送当前所选文本给 DeepSeek。当前版本不会加密本地历史数据库或应用管理的图片文件；关闭敏感内容过滤可能把密码或令牌等文本保存到该数据库。如需设备级保护，请启用 macOS 账户安全措施和 FileVault。详细说明参见[隐私政策](docs/privacy-policy.md)和[用户指南](docs/user-guide.md)。

## 项目文档

- [开发文档索引](docs/README.md)
- [用户指南](docs/user-guide.md)
- [产品规划 V1.0 → V1.4](docs/roadmap/V1.0-V1.4-PRODUCT_ROADMAP.md)
- [整体架构](docs/architecture/overall-architecture.md)
- [数据库设计](docs/database/schema.md)
- [变更记录](docs/changelog/CHANGELOG.md)
- [Release 准备指南](docs/release/RELEASE_PREP_GUIDE.md)
