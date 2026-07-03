## 1. Release Configuration

- [ ] 1.1 Configure App Sandbox.
  - 实现描述：在 Xcode entitlements 中启用 App Sandbox，并配置剪贴板、文件访问等首版所需能力。
  - 前置条件：核心功能已实现到可回归测试状态，目标分发方式已明确。
  - 验收条件：启用 Sandbox 后应用可构建，启动、记录、恢复和本地存储仍可工作。
  - 当前进展：`project.yml` 已通过 `CODE_SIGN_ENTITLEMENTS` 绑定 `MacPasteHistory/MacPasteHistory.entitlements`，Release 产物已确认包含 `com.apple.security.app-sandbox = true`；`scripts/release-smoke-test.sh` 已验证沙盒 Release 包可启动、捕获模拟文本/图片到本地数据库、退出、重启后历史仍保留；仍需完成人工恢复和 UI 回归后才能关闭。
- [ ] 1.2 Configure signing certificate settings.
  - 实现描述：配置开发或分发签名团队、证书、profile 和 bundle identifier。
  - 前置条件：Apple Developer 账号和证书资源已准备，项目 Bundle ID 已确定。
  - 验收条件：本机可完成签名构建；签名错误已清除或有明确处理记录。
  - 当前进展：新增 `scripts/release-environment-report.sh` 可生成本机签名与发布环境诊断；当前报告显示 `security find-identity -p codesigning -v` 为 `0 valid identities found`，Release 包仍为 `Signature=adhoc`、`TeamIdentifier=not set`，分发签名需安装 Apple Development、Apple Distribution 或 Developer ID Application 证书后才能关闭。
- [x] 1.3 Configure Release build settings.
  - 实现描述：检查 Release 配置、优化选项、版本号、构建号和资源包含情况。
  - 前置条件：Debug 构建功能已通过主要验收。
  - 验收条件：Release 配置可成功编译，产物包含必要资源且无调试专用依赖。
  - 当前进展：Release 配置已设置 `SWIFT_OPTIMIZATION_LEVEL = -O`、`SWIFT_COMPILATION_MODE = wholemodule`、`COPY_PHASE_STRIP = YES`、`STRIP_STYLE = non-global`、`DEPLOYMENT_POSTPROCESSING = YES`、`ENABLE_DEBUG_DYLIB_SUPPORT = NO`，并通过 `xcodebuild -configuration Release build` 验证。
- [ ] 1.4 Produce a Release build and verify it launches.
  - 实现描述：生成 Release 应用包并在本机独立启动验证。
  - 前置条件：Sandbox、签名和 Release 设置已配置。
  - 验收条件：Release 包可启动、显示菜单栏图标、打开窗口并执行基本复制历史流程。
  - 当前进展：`scripts/release-smoke-test.sh` 已验证 Release app 临时安装副本可启动、捕获模拟文本/图片、写入沙盒数据库、正常退出并在重启后保留历史；`scripts/preview-release-app.sh`、`scripts/package-release-qa-build.sh` 和 `scripts/release-smoke-test.sh` 已接入 `scripts/validate-xcode-file-references.sh`，构建前会重生成工程并校验 Swift 引用可解析到真实文件，避免陈旧 Xcode 引用导致 Release 构建入口失败；菜单栏图标、窗口打开和恢复流程仍需人工 UI 验证。

## 2. Compatibility Testing

- [ ] 2.1 Test on Intel Mac where available.
  - 实现描述：在 Intel Mac 或等价测试环境运行 Release 包，执行核心功能回归。
  - 前置条件：可访问 Intel 测试设备；Release 包已生成。
  - 验收条件：启动、菜单栏、文本/图片记录、恢复和退出行为通过；无法测试时记录原因。
  - 当前进展：`scripts/release-environment-report.sh` 已确认当前机器为 `arm64` Apple Silicon；新增 `scripts/package-release-qa-build.sh` 可生成带 manifest 和 SHA-256 的 Release QA zip，新增 `scripts/verify-release-qa-package.sh` 可在目标机器校验 zip、架构、签名和 Sandbox entitlement，便于传到 Intel Mac 或等价 CI/虚拟化环境补充证据；本机仍无法提供 Intel 实机通过结果。
- [ ] 2.2 Test on Apple Silicon Mac where available.
  - 实现描述：在 Apple Silicon Mac 运行 Release 包，执行核心功能回归。
  - 前置条件：可访问 Apple Silicon 测试设备；Release 包已生成。
  - 验收条件：启动、菜单栏、文本/图片记录、恢复和退出行为通过；架构相关问题已记录。
  - 当前进展：当前机器为 Apple Silicon（arm64，Apple M5，macOS 26.5.1），Release 冒烟测试已验证临时安装副本启动、文本/图片记录、退出、重启后历史保留和启动清理；菜单栏、恢复和完整人工回归仍待验证。
- [ ] 2.3 Test supported macOS versions.
  - 实现描述：在目标支持的 macOS 版本上验证安装、启动和核心功能。
  - 前置条件：已确定最低和主要支持 macOS 版本，测试设备或虚拟环境可用。
  - 验收条件：每个已测版本结果有记录；不兼容版本有明确最低版本说明。
  - 当前进展：本机发布环境报告记录当前可测系统为 macOS `26.5.1 (25F80)`；新增 QA zip 打包和校验脚本可为其他 macOS 设备提供一致测试包与包完整性/配置证据；macOS 14.0+ 目标范围仍需额外设备或虚拟环境实际覆盖。
- [ ] 2.4 Verify install, startup, quit, and restart behavior.
  - 实现描述：验证应用首次安装、普通启动、退出、重启后历史加载和设置恢复。
  - 前置条件：Release 包可运行，已有测试数据或可现场生成。
  - 验收条件：安装/启动/退出/重启无异常，历史和设置符合预期。
  - 当前进展：`scripts/release-smoke-test.sh` 已将 Release 包复制到临时安装目录启动，验证捕获后的历史在退出并重启后仍可查询；Launch at login 已接入 `SMAppService.mainApp.register()` / `unregister()`，并通过 `LoginItemServiceTests` 和 `SettingsViewModelTests` 验证注册、失败回滚和设置状态同步；设置窗口、开机启动注销/登录后的真实行为和真实安装路径仍需人工验证。

## 3. Functional QA

- [ ] 3.1 Test text and image copy from Chrome.
  - 实现描述：在 Chrome 中复制文本和图片，验证历史记录、预览和恢复。
  - 前置条件：Chrome 已安装，Release 应用运行中。
  - 验收条件：文本和支持的图片复制场景按预期记录；不支持场景有说明。
  - 当前进展：发布环境报告已确认 `/Applications/Google Chrome.app` 存在；新增 `scripts/generate-manual-qa-fixtures.swift` 可生成无隐私浏览器文本和图片样本用于 Chrome 复制测试；实际复制/预览/恢复仍需人工 QA。
- [ ] 3.2 Test text and image copy from Safari.
  - 实现描述：在 Safari 中复制文本和图片，验证历史记录、预览和恢复。
  - 前置条件：Safari 可用，Release 应用运行中。
  - 验收条件：文本和支持的图片复制场景按预期记录；不支持场景有说明。
  - 当前进展：发布环境报告已确认 `/Applications/Safari.app` 存在；新增无隐私浏览器文本、标准图片和大尺寸图片样本用于 Safari 复制测试；实际复制/预览/恢复仍需人工 QA。
- [ ] 3.3 Test text copy from VS Code.
  - 实现描述：在 VS Code 中复制代码和普通文本，验证文本历史、搜索和恢复。
  - 前置条件：VS Code 已安装或可用，Release 应用运行中。
  - 验收条件：复制代码可记录和搜索，恢复后格式按纯文本策略保持内容一致。
  - 当前进展：发布环境报告已确认 `/Applications/Visual Studio Code.app` 存在；新增合成 Swift 代码样本用于 VS Code 复制、搜索和恢复测试；实际代码复制、搜索和恢复仍需人工 QA。
- [ ] 3.4 Test common chat app copy flows such as WeChat and DingTalk.
  - 实现描述：在微信、钉钉等聊天应用中测试文本和可支持图片的复制/恢复。
  - 前置条件：测试账号和应用环境可用，隐私黑名单设置已确认。
  - 验收条件：非黑名单场景按预期记录；黑名单场景按预期跳过；结果有记录。
  - 当前进展：发布环境报告已确认 `/Applications/WeChat.app` 和 `/Applications/DingTalk.app` 存在；新增无隐私聊天复制样本用于测试账号/测试群复制流程；测试账号、真实会话复制和黑名单场景仍需人工 QA。
- [ ] 3.5 Test large text copy.
  - 实现描述：复制大段文本，观察捕获、存储、列表预览、详情、搜索和恢复表现。
  - 前置条件：大文本测试样本已准备，性能优化已完成。
  - 验收条件：应用不崩溃，UI 不明显卡死，超大内容按限制策略处理。
  - 当前进展：`scripts/release-smoke-test.sh` 已在 Release 包中验证 92,699 字符模拟文本可捕获并持久化；新增 `04-large-text-sample.txt` 作为人工大文本复制、列表预览、详情、搜索、恢复和 UI 卡顿观察样本；人工 UI 结果仍待验证。
- [ ] 3.6 Test large image copy.
  - 实现描述：复制大尺寸或大文件图片，验证大小限制、缩略图、存储和恢复策略。
  - 前置条件：大图片测试样本已准备，图片大小限制设置可用。
  - 验收条件：未超限图片正常处理；超限图片被跳过且无残留文件。
  - 当前进展：`scripts/release-smoke-test.sh` 已在 Release 包中验证 1024x768 模拟 PNG 可捕获，且原图、缩略图路径和尺寸元数据已持久化；新增超限图片验证会临时降低 `config.maxImageSizeInBytes`，复制独立 PNG，并确认不会新增图片数据库记录、原图文件或缩略图文件；新增标准 PNG 和 2400x1600 大尺寸 PNG 人工复制样本；图片恢复到真实目标应用仍待人工验证。
- [ ] 3.7 Test data cleanup behavior in Release build.
  - 实现描述：在 Release 环境验证过期清理、数量限制、空间限制和清空全部数据。
  - 前置条件：清理功能已实现，测试数据可控。
  - 验收条件：数据库和图片文件清理结果正确，Release 下行为与 Debug 一致。
  - 当前进展：新增 `DataCleanupServiceTests` 回归测试，覆盖过期图片文件清理、文本数量限制、图片数量限制、收藏图片计入总数限制、图片存储空间上限清理；新增 `ClipboardDataClearServiceTests` 验证清空全部数据会删除数据库记录、原图和缩略图；修复过期图片清理只删数据库不删文件的问题，并修复收藏项未计入数量上限导致总记录数超限的问题。`scripts/release-smoke-test.sh` 现在使用临时隔离 App Support 目录运行 Release 包，不写入真实历史数据库；脚本已验证 Release 启动时会清理过期图片数据库记录/原图/缩略图，会按文本数量限制、图片数量限制和图片存储空间上限清理，并保留收藏项。清空全部数据仍需 Release UI 手动触发补验。

## 4. Release Materials

- [x] 4.1 Write user usage documentation.
  - 实现描述：编写用户使用说明，覆盖启动、菜单栏、搜索、恢复、删除、清空、暂停、设置和黑名单。
  - 前置条件：首版功能范围已冻结。
  - 验收条件：文档能指导新用户完成主要工作流，内容与实际 UI 一致。
- [x] 4.2 Write privacy policy.
  - 实现描述：完善隐私政策，说明记录范围、本地存储、敏感过滤、黑名单、清空数据和无云同步。
  - 前置条件：隐私功能和数据处理方式已实现并确认。
  - 验收条件：隐私政策可用于发布审查，且不承诺应用未实现的能力。
- [x] 4.3 Prepare App Store screenshots.
  - 实现描述：准备展示菜单栏、历史列表、搜索、图片预览、设置和隐私控制的截图素材。
  - 前置条件：Release UI 已基本稳定，测试数据可构造。
  - 验收条件：截图清晰、无敏感真实数据、覆盖首版核心价值。
  - 当前进展：新增 `scripts/generate-release-screenshots.swift`，可使用合成示例数据生成 `docs/release/screenshots/01-history-overview.png`、`02-image-history.png`、`03-settings-controls.png`、`04-local-privacy.png`；已用 `file`、`sips` 和人工预览抽查确认 PNG 清晰、无真实隐私数据，并覆盖历史列表/搜索过滤、图片详情、设置控制、隐私和清理控制。
- [ ] 4.4 Verify final release checklist is complete.
  - 实现描述：汇总构建、兼容性、功能 QA、文档、隐私政策和截图检查结果。
  - 前置条件：本阶段所有发布配置、测试和材料任务已完成。
  - 验收条件：文档阶段 9 的验收标准全部通过，未完成项有明确记录和处理决定。
  - 当前进展：新增 `docs/release/manual-qa-record.md` 作为人工发布 QA 证据模板，用于记录真实设备、真实应用复制/恢复、菜单栏、Clear All Data、Launch at login 和隐私场景的 tester/date/build/evidence；新增 `scripts/release-qa-baseline.sh` 可生成当前构建、机器、Xcode、签名、Sandbox 和常见应用安装情况的 Markdown 基线，便于填入人工记录；新增 `scripts/package-release-qa-build.sh` 可生成跨机器 QA zip、SHA-256 和 manifest；新增 `scripts/verify-release-qa-package.sh` 可校验 QA 包完整性、架构、签名和 Sandbox entitlement；新增 `scripts/generate-manual-qa-fixtures.swift` 可生成无隐私人工功能 QA 样本；新增 `scripts/start-manual-release-qa-session.sh` 可一次性生成时间戳 QA 会话目录，汇总 QA 包、校验报告、基线、样本和记录模板，减少人工证据准备遗漏；新增 `scripts/validate-manual-qa-record.sh` 可在人工记录填写后检查必需章节、TBD/Not run 占位符、最终发布决定和签名/Team ID 明显缺口；最终验收仍需这些记录实际填写、校验通过并人工复核后才能关闭。
