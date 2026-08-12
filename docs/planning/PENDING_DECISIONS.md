# 待决策问题

本清单记录不宜由开发智能体擅自决定、但暂不阻塞安全实现的问题。状态为 `待决策` 的条目由产品负责人后续统一确认。

| ID | 状态 | 版本 | 问题 | 当前处理方式 | 影响 |
| --- | --- | --- | --- | --- | --- |
| PD-001 | 待决策 | V1.0.x | V1.0.2 是否在仅 ad-hoc 签名、未 Apple 公证的情况下视为正式发布完成？ | 视为功能基线已发布；Developer ID、公证和正式分发仍由独立 Release Task 处理。 | 不阻塞 V1.0.3 功能开发，但阻塞正式分发结论。 |
| PD-002 | 待决策 | 全版本 | Tag 是否从下一版本起统一使用小写 `v`？当前存在 `v1.0.0`、`v1.0.1` 与 `V1.0.2` 混用。 | 不修改历史 Tag；V1.0.3 完成前不创建新 Tag。 | 影响版本命名一致性和自动化脚本。 |
| PD-003 | 待决策 | V1.0.x | 旧 OpenSpec 中依赖证书、Intel 机器或真实升级链路的未完成 QA 项应补齐、豁免还是迁移到独立 Release Task？ | 保留原勾选状态和证据，不虚假完成；新版本需求单独跟踪。 | 影响旧变更归档，不阻塞本地代码迭代。 |
| PD-004 | 待决策 | V1.1 | V1.1 采用一个总 OpenSpec change，还是按 Slots、Tags/Collections、App Rules、FTS5 拆分多个 change？ | V1.0.3 完成前不提前实现；建议同一 release 分支内按能力拆成可独立审查的 change。 | 影响 V1.1 排期、migration 次数和 Review 粒度。 |
| PD-005 | 待决策 | V1.0.3 | 是否接受“来源应用为轮询观察时的前台 App”这一 macOS 限制？如果用户复制后在下一次 0.5 秒轮询前切换 App，pasteboard 不提供真实复制来源；项目规则禁止用键盘监听推断复制。 | 当前只保证 capture pipeline 开始后来源快照不漂移；文档明确为 best-effort，不宣称可防住轮询前切换。 | 若不接受，需要批准并另行设计更强来源信号及其 Accessibility/隐私成本；当前 blocked-app 功能不能作为绝对安全边界。 |
| PD-006 | 已解决 | V1.0.3 | 谁提供一份由已发布 V1.0.2 build 4 应用实际创建、已脱敏且可提交仓库的 SQLite 数据库 fixture？ | 2026-08-12 解锁后，从不可变标签 `V1.0.2`（commit `de64649`）构建并校验 Universal `1.0.2 (4)` App；主二进制 SHA-256 为 `9880de69def6571dcd94d5a3a93db13b48949727d32be052a0e04143aed0cd8d`。该 App 在隔离目录创建数据库、历史与 capture event 后停机脱敏；仓库 fixture SHA-256 为 `f4bb3d0d099068e455d6caa935365474278350e4311931701120b94a8581c55a`。测试锁定 checksum，并验证 integrity、foreign key、DELETE journal、V1–V4 migration、脱敏来源、capture event 与 AI usage；独立 reviewer 复核无 finding。 | Task 8.1 与真实旧库升级门禁已完成；不影响仍独立开放的 GUI smoke（PD-007）和正式分发门禁。 |
| PD-007 | 已决策 | V1.0.3 | 谁补验 `SystemUIServer` 菜单栏状态项与真实全局快捷键，或是否批准这两项 GUI 证据豁免？ | 2026-08-12 已在隔离 App Support 与独立 QA UserDefaults suite 中验证 Release 文本/图片列表、快速搜索、文本与图片恢复、内容动作与另存、Finder 真实图片捕获、Blocked Apps 及快速切换竞态、Automatic Paste 缺少 Accessibility 时的手动粘贴回退、三页设置读取、偏好隔离、多次重启持久化及 Clear All Data。Computer Use 对 `SystemUIServer` 的两次只读访问均超时，且其按键 API 明确不能触发全局快捷键，因此两项没有伪造通过。产品负责人随后明确要求创建 `v1.0.3` tag、DMG、更新包和 GitHub Release，视为批准本版本仅对这两项 GUI 证据豁免；不改变相应功能的自动测试结果或已知自动化边界。 | V1.0.3 非发布代码门禁可继续合并；后续版本仍应在可用人工环境补回真实状态项与全局快捷键 smoke，不将本次豁免泛化。 |
| PD-008 | 已解决 | V1.0.3 | AI 润色成功后，设置页 token 汇总可能持续显示为 0，是否修复后再发布？ | 2026-08-12 产品负责人确认先修复再发布。成功新增 usage 或成功清空 token usage 后发布本地变更通知，已存在的设置 ViewModel 在主线程刷新汇总；失败删除不发布误导事件。持久化按实际发起请求的配置模型归属，避免 provider 模型别名使“当前模型”为 0。所有新增回归场景均先 RED 后 GREEN。 | V1.0.3 可继续完整 QA、重新打包和发布；历史 usage 不迁移、不重写。 |
| PD-009 | 已决策 | V1.0.4 | 由谁提供并维护同一 Apple Developer Team 的 Developer ID Application 证书/私钥、Team ID 与 notarization 凭据？ | 2026-08-12 产品负责人明确决定 V1.0.4 暂不配置 Developer ID，批准以 ad-hoc 签名继续合并和发布。凭据未来只进入操作者钥匙串或 CI secret store，不提交仓库。 | 本次豁免只适用于 V1.0.4：每次更新后可能仍需重新授予辅助功能权限，且包未经过 Apple 公证。身份校验工具继续保留，后续取得 Developer ID 后必须恢复正式门禁。 |
| PD-010 | 已决策 | V1.0.5 | API Key 是否改为非钥匙串存储，以及自动粘贴是否绕过辅助功能？ | 产品负责人要求不再将 API Key 存入钥匙串。V1.0.5 改为 Application Support 下 `0600` 权限的本地明文文件；不自动读取、迁移或删除旧钥匙串项。macOS 没有对任意第三方应用通用且免授权的粘贴注入公开 API，因此保留无权限时恢复剪贴板并手动 `Command-V`，拒绝以 Apple Events、私有 API 或应用特化方案冒充等价绕过。 | 重启不再访问钥匙串，但 API Key 的静态保护弱于钥匙串；通用自动粘贴仍需辅助功能权限。 |
