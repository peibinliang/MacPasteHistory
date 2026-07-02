## 1. Release Configuration

- [ ] 1.1 Configure App Sandbox.
  - 实现描述：在 Xcode entitlements 中启用 App Sandbox，并配置剪贴板、文件访问等首版所需能力。
  - 前置条件：核心功能已实现到可回归测试状态，目标分发方式已明确。
  - 验收条件：启用 Sandbox 后应用可构建，启动、记录、恢复和本地存储仍可工作。
  - 当前进展：`project.yml` 已通过 `CODE_SIGN_ENTITLEMENTS` 绑定 `MacPasteHistory/MacPasteHistory.entitlements`，Release 产物已确认包含 `com.apple.security.app-sandbox = true`；仍需完成真实启动、记录、恢复和本地存储回归后才能关闭。
- [ ] 1.2 Configure signing certificate settings.
  - 实现描述：配置开发或分发签名团队、证书、profile 和 bundle identifier。
  - 前置条件：Apple Developer 账号和证书资源已准备，项目 Bundle ID 已确定。
  - 验收条件：本机可完成签名构建；签名错误已清除或有明确处理记录。
- [x] 1.3 Configure Release build settings.
  - 实现描述：检查 Release 配置、优化选项、版本号、构建号和资源包含情况。
  - 前置条件：Debug 构建功能已通过主要验收。
  - 验收条件：Release 配置可成功编译，产物包含必要资源且无调试专用依赖。
  - 当前进展：Release 配置已设置 `SWIFT_OPTIMIZATION_LEVEL = -O`、`SWIFT_COMPILATION_MODE = wholemodule`、`COPY_PHASE_STRIP = YES`、`STRIP_STYLE = non-global`、`DEPLOYMENT_POSTPROCESSING = YES`、`ENABLE_DEBUG_DYLIB_SUPPORT = NO`，并通过 `xcodebuild -configuration Release build` 验证。
- [ ] 1.4 Produce a Release build and verify it launches.
  - 实现描述：生成 Release 应用包并在本机独立启动验证。
  - 前置条件：Sandbox、签名和 Release 设置已配置。
  - 验收条件：Release 包可启动、显示菜单栏图标、打开窗口并执行基本复制历史流程。

## 2. Compatibility Testing

- [ ] 2.1 Test on Intel Mac where available.
  - 实现描述：在 Intel Mac 或等价测试环境运行 Release 包，执行核心功能回归。
  - 前置条件：可访问 Intel 测试设备；Release 包已生成。
  - 验收条件：启动、菜单栏、文本/图片记录、恢复和退出行为通过；无法测试时记录原因。
- [ ] 2.2 Test on Apple Silicon Mac where available.
  - 实现描述：在 Apple Silicon Mac 运行 Release 包，执行核心功能回归。
  - 前置条件：可访问 Apple Silicon 测试设备；Release 包已生成。
  - 验收条件：启动、菜单栏、文本/图片记录、恢复和退出行为通过；架构相关问题已记录。
- [ ] 2.3 Test supported macOS versions.
  - 实现描述：在目标支持的 macOS 版本上验证安装、启动和核心功能。
  - 前置条件：已确定最低和主要支持 macOS 版本，测试设备或虚拟环境可用。
  - 验收条件：每个已测版本结果有记录；不兼容版本有明确最低版本说明。
- [ ] 2.4 Verify install, startup, quit, and restart behavior.
  - 实现描述：验证应用首次安装、普通启动、退出、重启后历史加载和设置恢复。
  - 前置条件：Release 包可运行，已有测试数据或可现场生成。
  - 验收条件：安装/启动/退出/重启无异常，历史和设置符合预期。

## 3. Functional QA

- [ ] 3.1 Test text and image copy from Chrome.
  - 实现描述：在 Chrome 中复制文本和图片，验证历史记录、预览和恢复。
  - 前置条件：Chrome 已安装，Release 应用运行中。
  - 验收条件：文本和支持的图片复制场景按预期记录；不支持场景有说明。
- [ ] 3.2 Test text and image copy from Safari.
  - 实现描述：在 Safari 中复制文本和图片，验证历史记录、预览和恢复。
  - 前置条件：Safari 可用，Release 应用运行中。
  - 验收条件：文本和支持的图片复制场景按预期记录；不支持场景有说明。
- [ ] 3.3 Test text copy from VS Code.
  - 实现描述：在 VS Code 中复制代码和普通文本，验证文本历史、搜索和恢复。
  - 前置条件：VS Code 已安装或可用，Release 应用运行中。
  - 验收条件：复制代码可记录和搜索，恢复后格式按纯文本策略保持内容一致。
- [ ] 3.4 Test common chat app copy flows such as WeChat and DingTalk.
  - 实现描述：在微信、钉钉等聊天应用中测试文本和可支持图片的复制/恢复。
  - 前置条件：测试账号和应用环境可用，隐私黑名单设置已确认。
  - 验收条件：非黑名单场景按预期记录；黑名单场景按预期跳过；结果有记录。
- [ ] 3.5 Test large text copy.
  - 实现描述：复制大段文本，观察捕获、存储、列表预览、详情、搜索和恢复表现。
  - 前置条件：大文本测试样本已准备，性能优化已完成。
  - 验收条件：应用不崩溃，UI 不明显卡死，超大内容按限制策略处理。
- [ ] 3.6 Test large image copy.
  - 实现描述：复制大尺寸或大文件图片，验证大小限制、缩略图、存储和恢复策略。
  - 前置条件：大图片测试样本已准备，图片大小限制设置可用。
  - 验收条件：未超限图片正常处理；超限图片被跳过且无残留文件。
- [ ] 3.7 Test data cleanup behavior in Release build.
  - 实现描述：在 Release 环境验证过期清理、数量限制、空间限制和清空全部数据。
  - 前置条件：清理功能已实现，测试数据可控。
  - 验收条件：数据库和图片文件清理结果正确，Release 下行为与 Debug 一致。

## 4. Release Materials

- [x] 4.1 Write user usage documentation.
  - 实现描述：编写用户使用说明，覆盖启动、菜单栏、搜索、恢复、删除、清空、暂停、设置和黑名单。
  - 前置条件：首版功能范围已冻结。
  - 验收条件：文档能指导新用户完成主要工作流，内容与实际 UI 一致。
- [x] 4.2 Write privacy policy.
  - 实现描述：完善隐私政策，说明记录范围、本地存储、敏感过滤、黑名单、清空数据和无云同步。
  - 前置条件：隐私功能和数据处理方式已实现并确认。
  - 验收条件：隐私政策可用于发布审查，且不承诺应用未实现的能力。
- [ ] 4.3 Prepare App Store screenshots.
  - 实现描述：准备展示菜单栏、历史列表、搜索、图片预览、设置和隐私控制的截图素材。
  - 前置条件：Release UI 已基本稳定，测试数据可构造。
  - 验收条件：截图清晰、无敏感真实数据、覆盖首版核心价值。
- [ ] 4.4 Verify final release checklist is complete.
  - 实现描述：汇总构建、兼容性、功能 QA、文档、隐私政策和截图检查结果。
  - 前置条件：本阶段所有发布配置、测试和材料任务已完成。
  - 验收条件：文档阶段 9 的验收标准全部通过，未完成项有明确记录和处理决定。
