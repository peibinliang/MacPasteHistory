## 1. Privacy Onboarding

- [x] 1.1 Add first-launch privacy notice state.
  - 实现描述：增加首次启动隐私提示状态字段，用于判断是否需要展示本地记录说明。
  - 前置条件：设置持久化能力已存在，已确定隐私提示文案范围。
  - 验收条件：新安装或清空设置时状态为未确认；确认后状态可保存。
- [x] 1.2 Show the privacy notice on first launch.
  - 实现描述：应用首次启动时弹出隐私说明，说明记录文本/图片、仅本地保存和可暂停/清空。
  - 前置条件：首次启动状态可读取，主窗口或启动流程可展示弹窗。
  - 验收条件：首次启动必定展示提示；用户确认后才能进入常规使用流程或关闭提示。
- [x] 1.3 Persist acknowledgement so the notice is not repeated unnecessarily.
  - 实现描述：用户确认隐私提示后保存确认状态，并在后续启动中跳过弹窗。
  - 前置条件：隐私提示 UI 已实现，设置服务可写入确认状态。
  - 验收条件：确认后重启不再重复展示；重置配置后可再次展示。
- [x] 1.4 Draft the privacy policy document.
  - 实现描述：编写隐私政策草稿，覆盖本地存储、记录范围、敏感过滤、黑名单、清空数据和无云同步。
  - 前置条件：首版隐私能力边界已由需求文档确认。
  - 验收条件：仓库中存在可审阅的隐私政策文档，内容与应用实际行为一致。

## 2. Sensitive Filtering

- [x] 2.1 Implement sensitive text keyword rules.
  - 实现描述：实现敏感关键词匹配，包括 password、token、Authorization、api_key、secret、验证码等文档列出的规则。
  - 前置条件：文本捕获保存前有可插入过滤逻辑的位置。
  - 验收条件：包含规则关键词的文本默认被识别为敏感内容。
- [x] 2.2 Add pattern checks for tokens, verification codes, identity numbers, and bank-card-like values.
  - 实现描述：添加正则或结构化规则识别常见 token、验证码、身份证号和银行卡号样式。
  - 前置条件：敏感过滤服务已可组合多条规则。
  - 验收条件：典型样例可被命中；明显普通文本不会大量误报。
- [x] 2.3 Skip persistence when sensitive content is detected.
  - 实现描述：在文本写入数据库前调用敏感过滤服务，命中时跳过保存并记录非敏感日志。
  - 前置条件：敏感规则已实现，文本保存流程可中止。
  - 验收条件：复制疑似密码或 token 后数据库不新增记录，日志不泄露原始敏感内容。
- [x] 2.4 Add a sensitive filtering setting.
  - 实现描述：在设置中添加敏感内容过滤开关，默认开启，允许用户关闭。
  - 前置条件：设置页和设置服务已可扩展。
  - 验收条件：默认开启；关闭后过滤服务不阻止保存；重启后开关状态保持。

## 3. Pause And Blocked Apps

- [x] 3.1 Implement pause recording state.
  - 实现描述：增加全局暂停状态，捕获文本或图片前统一检查该状态。
  - 前置条件：剪贴板捕获入口可访问共享设置或运行状态。
  - 验收条件：暂停开启后复制文本和图片都不进入历史；关闭后恢复记录。
- [x] 3.2 Add pause entry point in the app UI.
  - 实现描述：在菜单栏或主面板中添加一键暂停/恢复入口，并显示当前状态。
  - 前置条件：暂停状态已实现，菜单栏或主面板操作区可修改。
  - 验收条件：用户可快速切换暂停状态，UI 状态与实际捕获行为一致。
- [x] 3.3 Create blocked app storage.
  - 实现描述：创建 `blocked_apps` 表或等价存储，保存应用名称、bundle id、启用状态和创建时间。
  - 前置条件：数据库迁移层已可添加新表。
  - 验收条件：可新增、查询、启用/停用黑名单应用；重启后数据仍存在。
- [x] 3.4 Add blocked app configuration UI.
  - 实现描述：提供黑名单配置界面，支持查看、添加、删除或启用/停用应用条目。
  - 前置条件：blocked app repository 已存在，设置页可增加隐私分区。
  - 验收条件：用户能管理黑名单；UI 变更会持久化到存储。
- [x] 3.5 Detect the current foreground app and bundle id.
  - 实现描述：使用 macOS API 获取当前前台应用名称和 bundle id，用于来源记录和黑名单判断。
  - 前置条件：应用具备调用 NSWorkspace 等前台应用检测 API 的代码路径。
  - 验收条件：从常见应用复制时能识别合理的应用名称和 bundle id；获取失败时有安全降级。
- [x] 3.6 Skip saving clipboard content from enabled blocked apps.
  - 实现描述：保存前比较当前来源应用与启用的黑名单条目，命中则跳过持久化。
  - 前置条件：前台应用检测和黑名单存储已完成。
  - 验收条件：黑名单应用中复制内容不会保存；非黑名单应用仍正常记录。

## 4. Cleanup And Verification

- [x] 4.1 Add automatic cleanup for expired history.
  - 实现描述：根据历史保留天数清理过期记录，删除关联图片文件，并避免清理收藏内容。
  - 前置条件：保留天数设置、history repository 和图片存储服务可用。
  - 验收条件：过期非收藏记录被清理；未过期和收藏记录保留；关联文件同步处理。
- [x] 4.2 Verify first-launch notice, sensitive skip, pause skip, blocked-app skip, and clear-data availability.
  - 实现描述：执行阶段 7 端到端验收，覆盖隐私提示、敏感过滤、暂停、黑名单和清空入口。
  - 前置条件：本阶段所有隐私、安全和清理任务已完成。
  - 验收条件：文档阶段 7 的验收标准全部通过。
