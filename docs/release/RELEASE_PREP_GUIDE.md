# MacPasteHistory 发布准备操作指引

> **版本**: v0.1.0 | **目标**: Apple Silicon / Intel macOS 14.0+ | **最后更新**: 2026-07-02

本手册覆盖从代码冻结到 App Store 提交之前的全部发布准备步骤，按阶段顺序执行。每个阶段末尾有验收检查清单（✅ 全部打勾才能进入下一阶段）。

---

## 目录

- [阶段 1: 发布配置](#阶段-1-发布配置) — 沙盒、签名、Release 构建
- [阶段 2: 兼容性测试](#阶段-2-兼容性测试) — Intel / Apple Silicon / macOS 版本
- [阶段 3: 功能 QA](#阶段-3-功能-qa) — 常用应用复制 / 大内容 / 数据清理
- [阶段 4: 发布材料](#阶段-4-发布材料) — 用户文档 / 隐私政策 / App Store 截图
- [阶段 5: 最终验收](#阶段-5-最终验收) — 清单汇总

---

## 阶段 1: 发布配置

### 1.1 启用 App Sandbox

**目标**: 在 entitlements 中启用沙盒并声明应用所需的能力。

**当前项目状态**: `project.yml` 已通过 `CODE_SIGN_ENTITLEMENTS = MacPasteHistory/MacPasteHistory.entitlements` 绑定沙盒权限文件。`xcodebuild -configuration Release build` 已生成可本机运行的 Release 包，`codesign -d --entitlements :-` 已确认产物包含 `com.apple.security.app-sandbox = true`。

#### 操作步骤

1. 如需通过 Xcode UI 复核，在 Xcode 中选中项目 → `MacPasteHistory` target → **Signing & Capabilities**。

2. 点击 **+ Capability**，添加 **App Sandbox**。

3. 在 `.entitlements` 文件中确认以下权限已开启：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- 剪贴板读写（必须） -->
    <key>com.apple.security.device.usb</key>
    <false/>
    <key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
    <array>
        <string>com.apple.coreaudio</string>
    </array>

    <!-- 网络：首版无需网络访问，保持关闭 -->
    <key>com.apple.security.network.client</key>
    <false/>
    <key>com.apple.security.network.server</key>
    <false/>

    <!-- 文件访问：Application Support 目录由系统自动沙盒化 -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <false/>
</dict>
</plist>
```

4. **注意**: 沙盒环境下 `NSPasteboard.general` 仍然可用（系统自动授权），但需确认：
   - `NSWorkspace.shared.frontmostApplication` 需要 **辅助功能权限**（在 Info.plist 中已声明 `NSAccessibilityUsageDescription`）。
   - 首次启动时系统会弹出辅助功能授权弹窗，引导用户到 **系统设置 → 隐私与安全性 → 辅助功能** 中添加应用。
   - 使用 `scripts/verify-privacy-usage-descriptions.sh` 校验 `NSPasteboardAccessUsageDescription` 和 `NSAccessibilityUsageDescription` 存在且不是占位文案。

5. 构建验证：

```bash
xcodebuild -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  build
```

本机可重复验证：

```bash
scripts/release-smoke-test.sh
```

该脚本会构建 Release 包、复制到临时安装目录、确认沙盒 entitlement、启动应用、写入模拟文本/大文本/模拟 PNG/大尺寸 PNG 到剪贴板，并查询本地数据库确认捕获成功；脚本还会重启 Release 包验证历史保留，插入过期图片记录验证数据库记录/原图/缩略图会一起清理，并在备份真实应用数据后验证 Release 启动时的文本数量限制、图片数量限制、收藏保护和图片存储上限清理。详细说明见 `docs/release/local-release-smoke-test.md`。

发布环境可重复诊断：

```bash
scripts/release-environment-report.sh
```

当前快照见 `docs/release/local-release-environment.md`。

人工 QA 证据记录模板：

```bash
docs/release/manual-qa-record.md
```

生成当前构建与机器环境基线：

```bash
scripts/release-qa-baseline.sh --build
```

该脚本输出 Markdown 证据片段，包含 git commit、Release app 路径、版本号、签名状态、Sandbox entitlement、Xcode 授权状态、当前 macOS/架构和常见测试应用安装情况。它不会替代人工验收；菜单栏、窗口、真实复制/恢复、Clear All Data、Launch at login、Intel Mac 和多 macOS 版本仍需在 `docs/release/manual-qa-record.md` 中记录实际结果。

生成可交给其他 Mac 做兼容性测试的 QA 分发包：

```bash
scripts/package-release-qa-build.sh
```

输出位于 `build/release-qa/`，包含 `.app` 副本、`.zip`、`.sha256` 和 manifest。将 zip 交给 Intel Mac 或其他 macOS 测试设备时，同时把 manifest 中的版本、commit、签名、架构和 SHA-256 填入 `docs/release/manual-qa-record.md`。

收到 QA zip 后，可先在目标机器校验包完整性、架构、签名和 Sandbox entitlement：

```bash
scripts/verify-release-qa-package.sh build/release-qa/MacPasteHistory-*.zip
```

如需一次性准备人工 QA 会话目录，推荐使用：

```bash
scripts/start-manual-release-qa-session.sh
```

该脚本会在 `build/manual-release-qa-session/<timestamp>-<commit>/` 下生成 Release QA 包、包校验报告、当前机器/构建基线、无隐私功能测试样本和 `manual-qa-record.md` 副本。脚本只负责准备证据输入，不会替代菜单栏、恢复、Clear All Data、Launch at login、Intel Mac 或多 macOS 版本的人工结果。

会话内的 `manual-qa-record.md` 会通过 `scripts/prefill-manual-qa-record.sh` 自动预填构建、包校验、签名、当前机器和样本路径等客观字段；所有人工场景仍保持 `Not run`，必须由测试人员实际执行后填写。

#### ⚠️ 已知风险

| 风险 | 缓解措施 |
|------|---------|
| 沙盒限制 `frontmostApplication` | 已在 Info.plist 声明 `NSAccessibilityUsageDescription`；沙盒内仍可读取，但首次需用户授权辅助功能 |
| `NSPasteboard` 沙盒限制 | 应用沙盒下剪贴板读写无需额外 entitlement，系统自动授权 |
| 快捷键注册 | 全局快捷键依赖辅助功能权限，沙盒不影响 HotKey API |

#### ✅ 验收清单

- [x] 项目已绑定 `MacPasteHistory/MacPasteHistory.entitlements`
- [x] Release 构建成功，无本机签名错误
- [x] Release 产物包含 `com.apple.security.app-sandbox = true`
- [x] 本机 Release 冒烟测试通过
- [ ] 沙盒下应用可正常启动、读取剪贴板、保存记录
- [ ] 辅助功能权限请求正常弹出

---

### 1.2 配置签名证书

**目标**: 设置正确的 Team、证书和 Provisioning Profile。

#### 前置条件

- Apple Developer Program 会员（$99/年）
- 本机已安装开发证书或分发证书

**当前机器状态（2026-07-02）**:

- `xcode-select -p` 已指向 `/Applications/Xcode.app/Contents/Developer`。
- `xcodebuild -checkFirstLaunchStatus` 和 `xcodebuild -license check` 已通过。
- `security find-identity -p codesigning -v` 显示 `0 valid identities found`。
- 当前 Release 包签名为 `Signature=adhoc`、`TeamIdentifier=not set`，只能用于本机运行验证，不能用于 Developer ID 分发或 App Store 上传。
- `scripts/release-environment-report.sh` 会生成签名身份、Xcode 状态、设备架构和常见测试应用安装情况报告。

查看已有签名身份：

```bash
security find-identity -p codesigning -v
```

#### 操作步骤

1. 在 Xcode 中选中项目 → **Signing & Capabilities** → **Team**，选择你的开发者账号。

2. **Development 签名**（本地测试）：
   - **Signing Certificate**: `Apple Development: Your Name (XXXXXXXXXX)`
   - **Provisioning Profile**: Xcode Managed（自动生成）

3. **Distribution 签名**（App Store 提交）：
   - **Signing Certificate**: `Apple Distribution: Your Name (XXXXXXXXXX)`
   - **Provisioning Profile**: App Store Profile

4. Bundle Identifier: `com.peibin.MacPasteHistory`（已与当前项目一致，无需修改）

5. 验证签名配置：

```bash
 codesign -dvv /path/to/MacPasteHistory.app 2>&1 | head -10
```

#### ⚠️ 注意事项

- 如果你打算 **仅在自有渠道分发**（不通过 App Store），需使用 **Developer ID Application** 证书 + Notarization。
- 如果通过 **Mac App Store**，使用 **Apple Distribution** 证书。

#### ✅ 验收清单

- [ ] Team 已选择
- [ ] Bundle Identifier 为 `com.peibin.MacPasteHistory`
- [ ] Debug 使用开发证书，Release 使用分发证书
- [ ] `codesign -dvv` 显示正确的 Team 和签名身份

---

### 1.3 配置 Release 构建设置

**目标**: 确认 Release 配置正确，产物不含调试依赖。

#### 操作步骤

1. 在 Xcode 中选择 **Product → Scheme → Edit Scheme** → **Run** → **Build Configuration** 选 **Release**。

2. 检查以下构建设置（Project → Build Settings → 筛选 "Release"）：

| 设置项 | 推荐值 | 说明 |
|--------|--------|------|
| `SWIFT_OPTIMIZATION_LEVEL` | `-O` | Release 开启优化 |
| `SWIFT_COMPILATION_MODE` | `wholemodule` | 全模块优化 |
| `ENABLE_DEBUG_DYLIB_SUPPORT` | `NO` | 不包含调试 dylib |
| `COPY_PHASE_STRIP` | `YES` | 去除调试符号 |
| `STRIP_STYLE` | `non-global` | 去除非全局符号 |
| `DEPLOYMENT_POSTPROCESSING` | `YES` | 启用后处理 |
| `COMPILE_SOURCES_WITH_NORMAL_ENTITLEMENTS` | `YES` | 使用普通 entitlements |

3. **版本号确认**:
   - `CFBundleShortVersionString`: `0.1.0`
   - `CFBundleVersion`: `1`

4. 在 Info.plist 中确认 `LSUIElement = <true/>`（应用不显示 Dock 图标，纯菜单栏应用）。

#### ✅ 验收清单

- [x] Release 配置构建成功
- [x] `SWIFT_OPTIMIZATION_LEVEL = -O`
- [x] `ENABLE_DEBUG_DYLIB_SUPPORT = NO`
- [x] 版本号为 `0.1.0 (1)`
- [x] `LSUIElement = true`

---

### 1.4 生成 Release 包并验证启动

**目标**: 生成可独立运行的 Release 应用包。

#### 操作步骤

```bash
# Archive
xcodebuild -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath ./build/MacPasteHistory.xcarchive \
  archive

# 导出 Development 包（用于本地测试）
xcodebuild -exportArchive \
  -archivePath ./build/MacPasteHistory.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist ExportOptions.plist
```

ExportOptions.plist 内容：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>  <!-- 或 "app-store" / "developer-id" -->
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

手动启动验证：

```bash
open ./build/export/MacPasteHistory.app
```

当前本机 Release 构建产物也可以直接预览：

```bash
scripts/preview-release-app.sh
```

如需只构建并打印产物路径：

```bash
scripts/preview-release-app.sh --build-only
```

如需使用临时隔离数据目录预览，避免写入真实历史数据库：

```bash
scripts/preview-release-app.sh --isolated-data
```

如需在隔离目录中预置合成历史，打开后直接检查列表、搜索、收藏、图片详情和长文本详情：

```bash
scripts/preview-release-app.sh --seed-preview-data
```

该命令会调用 `scripts/seed-preview-data.sh`，写入 4 条合成文本记录和 2 条合成图片记录到临时 App Support 目录，不会修改真实历史数据库。

确认以下行为：
- 菜单栏出现剪贴板图标
- 点击图标可打开历史窗口
- 复制一段文本 → 历史窗口中出现记录
- 重启应用后历史记录仍保留

`scripts/release-smoke-test.sh` 已自动验证临时安装副本可启动、捕获文本/图片、退出并重启后历史仍保留；`scripts/preview-release-app.sh --seed-preview-data` 可用于后续人工确认菜单栏图标、窗口打开、搜索、详情、恢复和清空流程。

如需在人工 QA 前快速验证安装副本启动、隔离 App Support 初始化和退出行为：

```bash
scripts/release-install-preflight.sh
```

该脚本会构建或复用 Release app，将 `.app` 复制到临时安装目录，从副本启动，确认沙盒容器中的隔离数据库和核心表已创建，然后退出应用。它不替代菜单栏图标、窗口打开、恢复或 Launch at login 的人工验证。

#### ✅ 验收清单

- [ ] Archive 成功
- [ ] Export 成功，.app 包存在
- [ ] 双击 .app 可独立启动
- [ ] 菜单栏图标可见
- [ ] 基本功能（复制、记录、恢复）正常

---

## 阶段 2: 兼容性测试

推荐先生成完整人工 QA 会话目录：

```bash
scripts/start-manual-release-qa-session.sh
```

目录中的 `README.md` 会列出包、校验报告、基线、样本和记录模板路径。后续测试结果应填写到该目录的 `manual-qa-record.md`，确认无误后再同步到仓库内发布记录。

开始跨机器测试前，先生成 QA 分发包：

```bash
scripts/package-release-qa-build.sh
```

在目标机器解压 zip 后运行 `.app`，并把 manifest 与实际测试结果一起记录到 `docs/release/manual-qa-record.md`。当前没有有效分发证书时，zip 内应用仍可能是 ad-hoc 签名，只能作为本地/内部 QA 包，不可作为正式分发物。

运行人工测试前先校验 QA 包：

```bash
scripts/verify-release-qa-package.sh /path/to/MacPasteHistory-*.zip
```

生成人工功能 QA 的无隐私测试样本：

```bash
scripts/generate-manual-qa-fixtures.swift
```

默认输出到 `build/manual-qa-fixtures/`，包含浏览器文本、VS Code 代码、聊天应用文本、大文本、标准图片和大尺寸图片。使用这些样本执行 3.1-3.6 的复制、搜索、预览和恢复验证，并把真实结果记录到 `docs/release/manual-qa-record.md`。

### 2.1 Apple Silicon Mac 测试

**当前开发环境**: macOS 26.5.1 (Apple Silicon)

#### 测试项

| 测试项 | 验证内容 | 状态 |
|--------|---------|------|
| 启动 | 应用启动无崩溃，菜单栏图标可见 | ⬜ |
| 文本记录 | 复制中文/英文/混合文本，列表中显示预览 | ⬜ |
| 图片记录 | 截图 (⌘⇧⌘4) 后图片记录出现在列表 | ⬜ |
| 搜索 | 输入关键词，列表实时过滤 | ⬜ |
| 恢复 | 点击恢复按钮或按 Enter，可粘贴到其他应用 | ⬜ |
| 删除 | 删除单条记录，UI 和数据库同步更新 | ⬜ |
| 清空 | 清空文本历史，列表清空 | ⬜ |
| 收藏 | 标记收藏，仅显示收藏筛选正常 | ⬜ |
| 文件清理 | 旧记录超出 1000 条时自动清理 | ⬜ |
| 设置持久化 | 关闭文本记录后复制文本不入库，重启设置保留 | ⬜ |
| 快捷键 | ⌘⇧V 打开/聚焦历史面板 | ⬜ |
| 退出重启 | 退出后重启，历史和设置均恢复 | ⬜ |

### 2.2 Intel Mac 测试

> **限制**: 如无 Intel Mac，可用 Rosetta 模式模拟 Apple Silicon 上的 Intel 行为（部分测试无法通过 Rosetta 完全模拟）。

**替代方案**: 使用 Hackintosh 或 CI 服务（如 GitHub Actions macOS-13 runner）。

测试项同上，额外关注：
- 无 Apple Silicon 特有的汇编指令
- 文件路径编码兼容性（`com.peibin.MacPasteHistory` 全 ASCII，无兼容性风险）

### 2.3 macOS 版本兼容性测试

目标支持版本: **macOS 14.0 (Sonoma)** 及以上。

| macOS 版本 | 测试方式 | 已知问题 |
|-----------|---------|---------|
| 14.0 Sonoma | 物理机/虚拟机 | 无 |
| 15.0 Sequoia | 物理机/虚拟机 | 无 |
| 16.x (当前开发) | 物理机 | 无 |

**虚拟机测试**:
- 使用 Parallels Desktop / VMware Fusion 安装目标 macOS 版本
- 复制 Release 包到虚拟机中运行
- 重点验证: API 可用性（`onKeyPress` API 需 macOS 13+，但最低部署目标为 14.0，安全）

### 2.4 安装 / 启动 / 退出 / 重启验证

| 步骤 | 操作 | 预期结果 |
|------|------|---------|
| 首次安装 | 将 .app 拖到 Applications 文件夹 | Finder 显示应用图标，无 Gatekeeper 警告（签名后） |
| 首次启动 | 双击启动 | 菜单栏出现图标，可能弹出辅助功能权限请求 |
| 辅助功能授权 | 系统设置中添加应用 | 之后可检测前台应用 bundle ID |
| 复制测试 | 从任意应用复制文本 | 历史列表出现记录 |
| 正常退出 | 菜单栏 Quit | 进程结束，图标消失 |
| 重启 | 重新启动应用 | 历史记录和设置恢复 |
| 开机启动 | 在 Settings 启用 Launch at login，再注销/登录 | 应用通过 macOS Login Items 自动启动；若系统拒绝注册，应用回滚开关并显示错误 |
| 强制退出 | ⌘⌥Esc 强制退出 | 重新启动后数据完整 |

当前代码状态：Launch at login 已接入 `SMAppService.mainApp.register()` / `unregister()`，并由 `LoginItemServiceTests` 与 `SettingsViewModelTests` 覆盖注册、注销和失败回滚。真实登录后自动启动仍需在 Release 包安装路径下人工验证。

#### ✅ 验收清单

- [ ] Apple Silicon Mac 全部测试项通过
- [ ] Intel Mac 已测试（或记录"无可用设备，暂不测试"）
- [ ] macOS 14.0 Sonoma+ 已测试
- [ ] 安装/启动/退出/重启均为预期
- [ ] Launch at login 注销/登录后自动启动行为通过
- [ ] 授权流程用户友好

---

## 阶段 3: 功能 QA

本阶段推荐先生成统一测试样本：

```bash
scripts/generate-manual-qa-fixtures.swift
scripts/verify-manual-qa-fixtures.sh
```

样本位于 `build/manual-qa-fixtures/`，均为合成内容，不包含真实剪贴板数据。执行下面每个场景时，用这些文件作为复制源，并在 `docs/release/manual-qa-record.md` 记录实际结果、目标应用、系统版本和截图/录屏路径。

`scripts/verify-manual-qa-fixtures.sh` 会在临时目录重新生成样本并校验文本标记、大文本体量、PNG 尺寸和 README，可用于确认 QA 输入材料完整；它不替代真实 Chrome、Safari、VS Code、微信、钉钉里的人工复制结果。

如果已经运行 `scripts/start-manual-release-qa-session.sh`，优先使用会话目录中的 `fixtures/` 和 `manual-qa-record.md`，避免多次生成样本后记录路径不一致。

### 3.1 Chrome 中文本/图片复制测试

| # | 测试场景 | 操作 | 预期结果 |
|---|---------|------|---------|
| 1 | 复制网页文本 | 在 Chrome 中选中文本 → ⌘C | 历史列表出现该文本，预览正确 |
| 2 | 复制图片 | 右键网页图片 → "复制图片" → ⌘V 到 Pasteboard | 历史列表出现图片缩略图 |
| 3 | 搜索过滤 | 在应用搜索框输入关键词 | 仅显示匹配的 Chrome 复制记录 |
| 4 | 恢复文本 | 选择记录 → Enter / 点击恢复 | 可在其他应用 ⌘V 粘贴 |
| 5 | 恢复图片 | 选择图片记录 → 恢复 | 可在支持图片的应用中粘贴 |

### 3.2 Safari 中文本/图片复制测试

| # | 测试场景 | 操作 | 预期结果 |
|---|---------|------|---------|
| 1 | 复制网页文本 | ⌘C | 文本记录正常 |
| 2 | 复制图片 | 右键 → 复制图像 | 图片记录正常 |
| 3 | 复制链接 | ⌘C 复制 URL | URL 作为文本记录（包含 http/https 前缀） |

### 3.3 VS Code 中文本复制测试

| # | 测试场景 | 操作 | 预期结果 |
|---|---------|------|---------|
| 1 | 复制代码块 | 选中多行代码 → ⌘C | 历史显示带换行的代码文本 |
| 2 | 搜索代码关键词 | 在应用搜索框输入变量名 | 仅在包含该词的记录中高亮/列出 |
| 3 | 恢复代码 | Enter 恢复 | 粘贴到编辑器时代码内容完整 |

### 3.4 微信 / 钉钉 测试

> **⚠️ 隐私注意**: 测试聊天应用时，可使用不涉及真实用户的测试账号或测试群聊。

| # | 测试场景 | 操作 | 预期结果 |
|---|---------|------|---------|
| 1 | 复制聊天文本 | 选中文本 → ⌘C | 文本记录出现在列表 |
| 2 | 复制图片消息 | 右键图片 → 复制 | 图片记录出现在列表 |
| 3 | **黑名单测试** | 在设置中将微信/钉钉 bundle ID 加入黑名单 | 切换到微信时复制内容不记录 |

如何使用开发者工具获取 bundle ID：

```bash
# 查看任意应用的 bundle ID
osascript -e 'id of app "WeChat"'  # 返回 com.tencent.xin
osascript -e 'id of app "DingTalk"'  # 返回 com.alibaba.DingTalk
```

### 3.5 大文本复制测试

| # | 内容 | 大小 | 验证 |
|---|------|------|------|
| 1 | Lorem Ipsum 100 行 | ~5 KB | 记录正常，预览截断 |
| 2 | 日志文件 10,000 行 | ~500 KB | 记录正常，搜索可用 |
| 3 | 超大文本 100,000 行 | ~5 MB | 记录正常，详情可打开，搜索不卡死 |
| 4 | 单行超长文本（100 万字符） | ~1 MB | 记录正常（无截断），详情可滚动 |

### 3.6 大图片复制测试

| # | 内容 | 大小 | 验证 |
|---|------|------|------|
| 1 | 普通截图 | ~200 KB | 正常记录，缩略图正确 |
| 2 | 高清截图（Retina） | ~2 MB | 正常记录 |
| 3 | 超大图片（5000x5000 PNG） | ~20 MB | 取决于 ImageStorageService 的 maxImageSizeInBytes 设置 |
| 4 | 超过限制的图片 | > 20 MB | 按当前设置跳过，不生成文件，日志中记录 "image exceeds size limit" |

`scripts/release-smoke-test.sh` 已自动验证 1024x768 模拟 PNG 可记录、持久化尺寸和缩略图；同时会临时降低 `config.maxImageSizeInBytes`，复制独立的超限 PNG，并验证不会新增数据库记录、原图文件或缩略图文件。图片恢复到真实目标应用仍需人工 QA。

### 3.7 数据清理功能测试（Release 构建）

| # | 测试项 | 操作 | 预期结果 |
|---|--------|------|---------|
| 1 | 过期清理 | 修改系统时间 +N 天后重启应用 | N 天前的非收藏记录被删除 |
| 2 | 数量限制 | 创建 1000+ 条文本记录 | 保留最新 1000 条，旧记录自动删除 |
| 3 | 图片数量限制 | 创建 100+ 条图片记录 | 保留最新 100 条，文件同步删除 |
| 4 | 存储限制 | 复制大图片总存储超过 20MB | 旧图片记录和文件被驱逐 |
| 5 | 收藏保护 | 标记收藏后再触发清理 | 收藏记录不受任何自动清理影响 |
| 6 | 清空全部数据 | 设置 → Clear All Data 并确认 | 数据库和 image 目录清空 |

`scripts/release-smoke-test.sh` 现在使用临时隔离 App Support 目录运行 Release 包，不写入真实历史数据库；脚本已自动验证过期图片清理、文本数量限制、图片数量限制、收藏保护和图片存储上限清理。`ClipboardDataClearServiceTests` 已验证清空全部数据的核心行为会删除数据库记录、原图和缩略图；用户手动触发的 Clear All Data 仍需在 Settings UI 中人工验证。

#### ✅ 验收清单

- [ ] Chrome 文本和图片复制正常
- [ ] Safari 文本和图片复制正常
- [ ] VS Code 代码复制、搜索、恢复正常
- [ ] 微信/钉钉非黑名单场景正常
- [ ] 黑名单场景按预期跳过（内容不入库）
- [ ] 大文本（5MB）正常处理不崩溃
- [x] 大图超限被正确跳过
- [x] 过期清理、数量限制、存储驱逐全部正确
- [x] 收藏记录不受自动清理
- [x] 清空数据后列表和文件目录均为空（服务级自动测试）

---

## 阶段 4: 发布材料

### 4.1 用户使用说明

发布到 `docs/release/USER_GUIDE.md`。

#### 文档大纲

```markdown
# MacPasteHistory 用户指南

## 简介
MacPasteHistory 是一款 macOS 菜单栏工具，自动记录剪贴板历史。
- 纯本地存储，无任何网络上传
- 支持文本和图片格式
- 完全免费、开源

## 安装
1. 下载 MacPasteHistory.dmg
2. 拖拽到 Applications 文件夹
3. 首次打开授权辅助功能（检测来源应用）

## 系统要求
- macOS 14.0 Sonoma 及以上
- Apple Silicon 或 Intel Mac
- 首次运行需授权辅助功能（检测前台应用）

## 基本使用
### 打开历史面板
- 点击菜单栏图标
- 或按 ⌘⇧V（可自定义快捷键）

### 搜索
- 在搜索框输入关键词，实时过滤
- 支持中英文

### 恢复
- 选中记录按 Enter，或点击恢复按钮
- 首次恢复时系统可能请求剪贴板读取权限

### 删除
- 移除单条：点击行尾删除按钮
- 清空文本：顶部 Clear Text
- 清空全部：设置页面 → Clear All Data

## 键盘快捷键
| 快捷键 | 功能 |
|--------|------|
| ⌘⇧V | 打开历史面板（全局快捷键） |
| ↑ / ↓ | 在记录列表中上下移动 |
| Enter | 恢复当前选中项 |
| Esc | 关闭面板 |

## 设置
| 设置项 | 说明 |
|--------|------|
| 文本记录开关 | 是否记录纯文本复制 |
| 图片记录开关 | 是否记录图片复制 |
| 开机启动 | 系统登录时自动启动 |
| Dock 图标 | 默认隐藏，开启后可显示在 Dock |
| 保留天数 | 历史记录保存天数 |
| 文本最大数量 | 超出后自动删旧 |
| 图片最大数量 | 超出后自动删旧并清理文件 |
| 单张图片限制 | 超过此大小的图片不保存 |
| 总存储上限 | 图片总存储上限 |
| 敏感内容过滤 | 自动跳过疑似密码/密钥的内容 |
| 暂停录制 | 临时暂停剪贴板监听 |
| 黑名单应用 | 跳过指定应用的复制内容 |

## 隐私说明
- 所有数据存储在本地 `~/Library/Application Support/MacPasteHistory/`
- 不上传任何数据到云端
- 可一键清除所有数据
- 完整隐私政策见 [链接]

## 常见问题
- Q: 快捷键不工作？
  A: 请确认在 系统设置 → 隐私与安全性 → 辅助功能 中授权了 MacPasteHistory。
```

### 4.2 隐私政策

发布到 `docs/release/PRIVACY_POLICY.md`。

#### 文档大纲

```markdown
# MacPasteHistory 隐私政策

**更新日期**: 2026-07-02

## 数据收集

MacPasteHistory **不收集任何个人身份信息**。

该应用:
- ❌ 不包含任何分析或追踪代码
- ❌ 不含网络请求（无任何联网功能）
- ❌ 不收集用户行为数据
- ❌ 不与任何第三方共享数据

## 本地存储

应用仅将以下数据存储在本机：

1. **剪贴板历史**: 存储在 `~/Library/Application Support/MacPasteHistory/clipboard.db`
   - 文本内容、复制时间、来源应用名称和 bundle ID
   - 不包含剪贴板文本以外的上下文信息
   - 受 macOS 沙盒保护，仅本应用可访问

2. **图片文件**: 存储在 `~/Library/Application Support/MacPasteHistory/images/` 和 `thumbnails/`
   - 原始图片和缩路图
   - 受 macOS 沙盒保护

3. **应用设置**: 存储在 UserDefaults
   - 录制开关、保留天数、数量上限、黑名单 bundle ID

## 敏感内容过滤

应用内置启发式检测，自动跳过以下类型的内容:
- 包含 "password"、"API key"、"token" 等关键词的文本
- 16-19 位数字（疑似银行卡号）
- 15-18 位数字（疑似身份证号）
- 长度 > 32 的字母数字组合（疑似密钥）

被检测到的敏感内容**不写入数据库或文件**，仅跳过。

## 数据清除

用户可随时通过以下方式删除所有数据:
- 设置 → "Clear All Data" 按钮（有确认弹窗）
- 手动删除 `~/Library/Application Support/MacPasteHistory/` 目录

## 联系方式

如有隐私相关问题，请联系: [你的邮箱]

## 变更通知

本隐私政策更新时，将在应用更新说明中注明。
```

### 4.3 App Store 截图

#### 规格要求

| 设备 | 分辨率 | 用途 |
|------|--------|------|
| 13-inch MacBook (2022+) | 2560 × 1664 | 主截图 |
| 16-inch MacBook (2021+) | 3456 × 2234 | 辅助截图 |

#### 截图内容（已准备 4 张）

1. `docs/release/screenshots/01-history-overview.png` — 历史列表、搜索、过滤、收藏、恢复和删除入口
2. `docs/release/screenshots/02-image-history.png` — 图片缩略图、图片详情、尺寸、格式和来源应用
3. `docs/release/screenshots/03-settings-controls.png` — 录制开关、Launch at login、保留时间和存储限制
4. `docs/release/screenshots/04-local-privacy.png` — 本地存储、暂停记录、敏感内容过滤和清空全部数据

#### 截图制作建议

- 当前仓库提供可重复生成脚本：`scripts/generate-release-screenshots.swift`
- 使用合成示例数据，不包含真实用户内容
- macOS 模板框架使用 [App Store Marketing Guidelines](https://developer.apple.com/app-store/marketing/guidelines/) 的官方模板
- 分辨率: 2x（确保 Retina 清晰）
- 当前输出为 5760 × 3600 PNG，可按最终上架渠道要求裁切或导出目标尺寸
- 使用 `scripts/verify-release-screenshot-assets.sh` 校验 4 张 PNG 均存在、可读取且尺寸为 5760 × 3600

#### App Icon

当前仓库提供可重复生成的 App Icon 脚本：

```bash
scripts/generate-app-icon.swift
scripts/verify-app-icon-assets.sh
scripts/verify-release-screenshot-assets.sh
```

图标位于 `MacPasteHistory/Resources/Assets.xcassets/AppIcon.appiconset/`，覆盖 macOS 所需的 16、32、64、128、256、512、1024 像素 PNG，并由 `project.yml` 中的 `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` 绑定到应用 target。

#### ✅ 验收清单

- [x] 用户指南 `docs/user-guide.md` 完成
- [x] 隐私政策 `docs/privacy-policy.md` 完成
- [x] App Store 截图素材已生成并记录在 `docs/release/screenshots/README.md`
- [x] App Icon asset catalog 已生成并通过尺寸校验

---

## 阶段 5: 最终验收

先生成发布就绪汇总报告：

```bash
scripts/release-readiness-report.sh --output build/release-readiness-report.md
```

如需给 CI 或后续自动化读取阻断项，可同时输出 JSON 摘要：

```bash
scripts/release-readiness-report.sh \
  --output build/release-readiness-report.md \
  --json-output build/release-readiness-report.json \
  --strict-final
```

该报告会汇总 Xcode 文件引用、日志隐私扫描、Info.plist 用途说明、App Icon 素材、截图 PNG 尺寸、人工 QA 样本生成校验、Release 冒烟测试、Release 安装副本预检、Xcode 授权、签名身份、用户文档、隐私政策、人工 QA 记录和 git 工作区状态。默认运行时会构建 Release 包，运行隔离数据的 synthetic smoke test（文本/图片捕获、重启持久化、大文本/大图、超限跳过、启动清理），再复制到临时安装目录、启动副本、验证隔离 SQLite 本地存储初始化并退出应用。正式分发前报告必须无 `Blockers`，且推荐使用 `--strict-final` 将所有 warning 也视为阻断项，避免跳过检查、ad-hoc 签名或未提交工作区进入分发审批。JSON 摘要会包含 `status`、`checks`、`blockers`、`warnings` 和仍需人工证据的列表。如果只是内部 QA、尚未安装分发证书，可临时加入 `--allow-adhoc`，但该模式只会把缺失签名身份降级为警告，不能作为最终分发验收依据。

如果只需要临时检查静态材料，可使用 `--skip-release-smoke` 和 `--skip-install-preflight` 跳过启动类检查；最终发布验收不得跳过：

```bash
scripts/release-readiness-report.sh --skip-release-smoke --skip-install-preflight --output build/release-readiness-report.md
```

最终报告也会运行日志隐私静态扫描：

```bash
scripts/scan-privacy-log-safety.sh
scripts/verify-privacy-usage-descriptions.sh
```

这些扫描会检查 App Swift 源码是否存在直接 console 输出、公开 OSLog 默认隐私级别、明显把剪贴板内容字段传入日志的调用，以及 Info.plist 中剪贴板/辅助功能用途说明是否完整。它们不能替代人工检查运行时日志，但可作为提交前门禁。

人工记录填写完成后，先运行最终记录校验：

```bash
scripts/validate-manual-qa-record.sh docs/release/manual-qa-record.md
```

如果仍处于内部 QA、尚未安装分发证书，可临时使用：

```bash
scripts/validate-manual-qa-record.sh --allow-adhoc docs/release/manual-qa-record.md
```

`--allow-adhoc` 只用于内部 QA，不得作为最终分发签名验收依据。该脚本会检查必需章节，并在对应章节内检查 Release App Workflow 必测行（包括双击历史项直接粘贴）、环境覆盖行、常用应用矩阵行、隐私与安全检查行，同时检查 `TBD`、`Not run`、最终发布决定和签名/Team ID 明显缺口。

### 汇总检查

| # | 检查项 | 阶段 | 状态 |
|---|--------|------|------|
| 1 | App Sandbox 已启用并构建成功 | 1.1 | ⬜ |
| 2 | 签名配置正确 (Development + Distribution) | 1.2 | ⬜ |
| 3 | Release 构建配置无误 | 1.3 | ⬜ |
| 4 | Release 包可独立启动 | 1.4 | ⬜ |
| 5 | Intel Mac 已测试或已记录不可测试 | 2.1 | ⬜ |
| 6 | Apple Silicon 兼容性通过 | 2.2 | ⬜ |
| 7 | macOS 14.0+ 兼容已验证 | 2.3 | ⬜ |
| 8 | 安装/启动/退出/重启均正常 | 2.4 | ⬜ |
| 9 | Chrome/Safari/VS Code 复制场景通过 | 3.1-3.3 | ⬜ |
| 10 | 微信/钉钉含黑名单测试通过 | 3.4 | ⬜ |
| 11 | 大文本 (5MB) 正常处理 | 3.5 | ⬜ |
| 12 | 大图片超限被正确跳过 | 3.6 | ✅ |
| 13 | 数据清理功能全部正确 | 3.7 | ⬜ |
| 14 | 用户指南已完成 | 4.1 | ✅ |
| 15 | 隐私政策已完成 | 4.2 | ✅ |
| 16 | App Store 截图已准备（已规划或完成） | 4.3 | ✅ |
| 17 | 最终 readiness report 默认安装副本预检通过 | 4.4 | ⬜ |
| 18 | 最终 readiness report 默认 Release smoke test 通过 | 4.4 | ⬜ |

### 发布决策

全部检查项通过后，确认以下信息并准备提交：

- **应用名称**: MacPasteHistory
- **Bundle ID**: `com.peibin.MacPasteHistory`
- **版本**: 0.1.0 (1)
- **最低 macOS 版本**: 14.0 Sonoma
- **分发渠道**: ☐ App Store  /  ⚩ 自有网站 + DMG
- **截图规范**: 当前仓库提供 4 张 5760 × 3600 PNG 截图素材；最终上传前按目标渠道裁切或导出目标尺寸

#### ✅ 最终验收清单

- [ ] 本指南中阶段 1 至阶段 4 的所有验收清单全部完成
- [x] `prepare-release-testing-and-store-assets` 的截图素材已准备并在 OpenSpec 中记录
- [ ] 最终产物可独立分发
