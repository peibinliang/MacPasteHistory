## 1. Build Configuration And Resource Setup

- [x] 1.1 Add `knownRegions` to `project.yml`.
  - 实现描述：在 `project.yml` 的 `options` 下添加 `knownRegions: [en, zh-Hans, zh-Hant]`，确保 XcodeGen 生成的项目包含本地化区域。
  - 前置条件：`project.yml` 已存在且使用 XcodeGen 管理项目。
  - 验收条件：运行 `xcodegen generate` 后，`project.pbxproj` 中包含三个 `knownRegions` 条目。
- [x] 1.2 Update Info.plist with localization metadata.
  - 实现描述：在 `Info.plist` 中添加 `CFBundleDevelopmentRegion` 设为 `en`，添加 `CFBundleLocalizations` 数组包含 `en`、`zh-Hans`、`zh-Hant`。
  - 前置条件：`Info.plist` 已存在且 `GENERATE_INFOPLIST_FILE` 为 `NO`。
  - 验收条件：构建后的 app bundle 中 Info.plist 包含正确的开发区域和支持语言列表。
- [x] 1.3 Create `.lproj` directories and `Localizable.strings` files.
  - 实现描述：在 `MacPasteHistory/Resources/` 下创建 `en.lproj/`、`zh-Hans.lproj/`、`zh-Hant.lproj/` 目录，每个目录中创建空的 `Localizable.strings` 文件。
  - 前置条件：`project.yml` 已配置 `knownRegions`。
  - 验收条件：三个 `.lproj` 目录存在，各自包含 `Localizable.strings` 文件，且被 Xcode 项目引用。
- [x] 1.4 Create `InfoPlist.strings` files for each language.
  - 实现描述：在每个 `.lproj` 目录中创建 `InfoPlist.strings`，包含 `NSPasteboardAccessUsageDescription`、`NSAccessibilityUsageDescription` 和 `CFBundleDisplayName` 的本地化文案。
  - 前置条件：`.lproj` 目录已创建。
  - 验收条件：三个语言的 `InfoPlist.strings` 文件存在且包含三个键的翻译。
- [x] 1.5 Regenerate Xcode project and verify build.
  - 实现描述：运行 `xcodegen generate` 重新生成项目，然后执行构建确认无错误。
  - 前置条件：所有资源文件和配置已就绪。
  - 验收条件：`xcodegen generate` 成功，`xcodebuild build` 成功。

## 2. LanguageManager Service

- [x] 2.1 Create `LanguageManager` service.
  - 实现描述：在 `MacPasteHistory/Services/` 下创建 `LanguageManager.swift`，定义支持的语言枚举（`system`、`en`、`zhHans`、`zhHant`），提供读取/写入语言偏好到 `UserDefaults` 的方法，以及应用 `AppleLanguages` 覆盖的逻辑。
  - 前置条件：无。
  - 验收条件：`LanguageManager` 能读取当前语言偏好，写入后 `AppleLanguages` 被正确设置或清除。
- [x] 2.2 Add `LanguageManager` to `UserDefaultsConfig`.
  - 实现描述：在 `UserDefaultsConfig` 中添加语言偏好键和默认值（`system`），使设置可持久化。
  - 前置条件：`UserDefaultsConfig` 已存在。
  - 验收条件：语言偏好键可读写，默认值为跟随系统。
- [x] 2.3 Add unit tests for `LanguageManager`.
  - 实现描述：编写 `LanguageManagerTests.swift`，测试读取默认值、设置特定语言后 `AppleLanguages` 被覆盖、设置为系统后 `AppleLanguages` 被清除。
  - 前置条件：`LanguageManager` 已实现。
  - 验收条件：所有测试通过，覆盖三种语言和系统默认场景。

## 3. Localizable.strings Catalogs

- [x] 3.1 Populate English `Localizable.strings`.
  - 实现描述：将所有 UI 字符串以英文填入 `en.lproj/Localizable.strings`，包括 MainPanelView、SettingsView、AppDelegate、ViewModel 错误消息、HistoryDisplayFormatter 的所有用户可见字符串。对含参数的字符串使用 `%lld`、`%@` 等格式占位符。
  - 前置条件：已完成字符串收集和键名规划。
  - 验收条件：文件包含所有 UI 字符串键值对，无遗漏。
- [x] 3.2 Populate Simplified Chinese `Localizable.strings`.
  - 实现描述：将所有键翻译为简体中文填入 `zh-Hans.lproj/Localizable.strings`。
  - 前置条件：英文 `Localizable.strings` 已完成。
  - 验收条件：所有键与英文版本一一对应，翻译准确自然。
- [x] 3.3 Populate Traditional Chinese `Localizable.strings`.
  - 实现描述：将所有键翻译为繁体中文填入 `zh-Hant.lproj/Localizable.strings`。
  - 前置条件：英文 `Localizable.strings` 已完成。
  - 验收条件：所有键与英文版本一一对应，翻译准确自然。
- [x] 3.4 Verify no missing keys across catalogs.
  - 实现描述：对比三个 `Localizable.strings` 文件，确认键集合完全一致，无遗漏或多余。
  - 前置条件：三个文件均已填写。
  - 验收条件：三个文件的键集合完全相同。

## 4. SwiftUI View Localization

- [x] 4.1 Localize `MainPanelView.swift`.
  - 实现描述：确认 `MainPanelView.swift` 中所有 `Text`、`Label`、`Button`、`TextField`、`ContentUnavailableView` 的字符串字面量与 `Localizable.strings` 键匹配。SwiftUI 自动使用 `LocalizedStringKey`，通常无需改代码，但需确认插值字符串（如 `"Keep history for \(days) days"`）的键格式正确。将动态字符串（如 toast message、filter title）改用 `LocalizedStringKey` 或 `NSLocalizedString`。
  - 前置条件：`Localizable.strings` 已填充对应键。
  - 验收条件：切换语言后 MainPanelView 所有文案正确显示对应语言。
- [x] 4.2 Localize `SettingsView.swift`.
  - 实现描述：确认 `SettingsView.swift` 中所有 `Section`、`Toggle`、`Stepper`、`Picker`、`Button`、`alert` 的字符串与 `Localizable.strings` 键匹配。含插值的 Stepper 文案需确认本地化键格式。
  - 前置条件：`Localizable.strings` 已填充对应键。
  - 验收条件：切换语言后 SettingsView 所有文案正确显示对应语言。
- [x] 4.3 Add language preference section to `SettingsView`.
  - 实现描述：在 `SettingsView` 中新增一个 Language Section，包含一个 Picker 让用户选择语言（Follow System / English / 简体中文 / 繁體中文），绑定到 `SettingsViewModel` 的新属性。选择后触发重启提示。
  - 前置条件：`LanguageManager` 已实现，`SettingsViewModel` 已添加语言属性。
  - 验收条件：用户可在设置中选择语言，选择后弹出重启提示。
- [x] 4.4 Add restart prompt alert.
  - 实现描述：在 `SettingsView` 中添加一个 alert，当用户更改语言后显示提示信息告知需重启生效，提供"立即重启"和"稍后"按钮。
  - 前置条件：语言 Picker 已添加。
  - 验收条件：更改语言后弹出提示；点击"立即重启"时应用退出并重新启动。

## 5. AppKit And ViewModel Localization

- [x] 5.1 Localize `AppDelegate.swift` menu items and window titles.
  - 实现描述：将 `NSMenuItem(title:)` 中的 "Open History"、"Settings"、"Quit" 改为 `NSLocalizedString` 调用。将窗口标题 "Clipboard History"、"Settings" 也改为 `NSLocalizedString`。
  - 前置条件：`Localizable.strings` 已填充对应键。
  - 验收条件：切换语言后菜单项和窗口标题正确显示对应语言。
- [x] 5.2 Localize `ClipboardHistoryViewModel` error messages.
  - 实现描述：将 ViewModel 中所有 `errorMessage` 赋值的硬编码字符串改为 `NSLocalizedString` 调用。
  - 前置条件：`Localizable.strings` 已填充对应键。
  - 验收条件：触发错误时错误消息以当前语言显示。
- [x] 5.3 Localize `SettingsViewModel` error messages.
  - 实现描述：将 `SettingsViewModel` 中的 `launchAtStartupErrorMessage` 硬编码字符串改为 `NSLocalizedString` 调用。
  - 前置条件：`Localizable.strings` 已填充对应键。
  - 验收条件：登录项设置失败时错误消息以当前语言显示。
- [x] 5.4 Add language preference to `SettingsViewModel`.
  - 实现描述：在 `SettingsViewModel` 中添加 `selectedLanguage` 属性，绑定到 `LanguageManager`，提供 `updateLanguage(_:)` 方法，在更改时触发重启标志。
  - 前置条件：`LanguageManager` 已实现。
  - 验收条件：`SettingsViewModel` 能读写语言偏好并通知 UI 显示重启提示。

## 6. Date And Time Formatter Localization

- [x] 6.1 Localize `HistoryDisplayFormatter` relative time labels.
  - 实现描述：将 `displayTime(for:)` 方法中的 "Today" 和 "Yesterday" 改为 `NSLocalizedString` 调用。
  - 前置条件：`Localizable.strings` 已填充 "Today" 和 "Yesterday" 键。
  - 验收条件：切换语言后，今天和昨天的相对时间标签以当前语言显示。
- [x] 6.2 Switch date formatters to locale-aware formatting.
  - 实现描述：将 `timeFormatter` 和 `dateTimeFormatter` 的 `locale` 从固定 `en_US_POSIX` 改为 `Locale.current`，使日期时间格式遵循当前语言区域习惯。保留 `en_US_POSIX` 仅用于需要固定解析格式的场景。
  - 前置条件：`HistoryDisplayFormatter` 已存在。
  - 验收条件：中文环境下日期时间格式符合中文习惯（如 24 小时制、年月日顺序）。
- [x] 6.3 Update `HistoryDisplayFormatterTests`.
  - 实现描述：更新现有测试以适配本地化后的 `Today`/`Yesterday` 标签和 locale-aware 日期格式。如有必要，在测试中固定 locale 以保证断言稳定。
  - 前置条件：`HistoryDisplayFormatter` 已完成本地化修改。
  - 验收条件：所有 `HistoryDisplayFormatterTests` 测试通过。

## 7. Integration And Verification

- [x] 7.1 Wire `LanguageManager` into app launch.
  - 实现描述：在 `AppDelegate.applicationDidFinishLaunching` 中调用 `LanguageManager` 应用已保存的语言偏好（设置 `AppleLanguages`）。
  - 前置条件：`LanguageManager` 已实现。
  - 验收条件：应用启动时读取并应用已保存的语言偏好。
- [x] 7.2 Run full build and test suite.
  - 实现描述：执行 `xcodegen generate`、`xcodebuild build`、`xcodebuild test`，确认全部通过。
  - 前置条件：所有代码修改已完成。
  - 验收条件：构建成功，所有测试通过。
- [x] 7.3 Manual language switching verification.
  - 实现描述：手动验证在设置中切换到英文、简体中文、繁体中文后，重启应用后所有界面文案、菜单项、窗口标题、错误提示、相对时间标签均正确显示对应语言。
  - 前置条件：应用已构建成功。
  - 验收条件：三种语言下 UI 全部正确显示，无遗漏英文或乱码。
- [x] 7.4 Verify Info.plist localized usage descriptions.
  - 实现描述：在不同语言环境下触发剪贴板权限和辅助功能权限请求，确认系统弹窗中的使用说明以当前语言显示。
  - 前置条件：`InfoPlist.strings` 已配置。
  - 验收条件：权限弹窗文案以当前语言显示。
