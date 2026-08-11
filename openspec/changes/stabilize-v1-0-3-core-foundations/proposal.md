## Why

V1.0.2 已具备完整的剪贴板工作流，但同一次捕获重复读取来源应用、敏感内容正则误判、数据库与图片文件漂移，以及分散的粘贴职责会直接削弱隐私和数据可靠性。V1.0.3 必须先收口这些 V1.0.x 架构债务，才能安全进入 V1.1 的高频内容管理能力。

## What Changes

- 将每次 pasteboard 变化建模为单一捕获上下文，只读取一次来源应用，并让隐私判断、历史记录和 capture event 共享同一来源快照。
- 用结构化、可解释且完全本地运行的 Sensitive Detector V2 替换宽泛的布尔正则判断，降低 Git SHA、MD5、UUID、Trace ID 和普通长字符串误判。
- 新增保守的存储校验能力，识别缺失原图、孤立文件、缺失缩略图、损坏图片和临时文件，不确定时不删除用户数据。
- 让搜索 ViewModel 显式取消旧任务，并保证旧查询永远不能覆盖最新输入或清空已有结果。
- 新增统一 PasteCoordinator，集中处理 clipboard restore、Automatic Paste、Accessibility、目标应用激活、fallback、使用统计和用户反馈。
- 在不改变现有 UI、快捷键和搜索行为的前提下拆分过大的 History ViewModel 职责。
- 通过并发与一致性测试评估 SQLite WAL、busy timeout、checkpoint 和事务边界；只有证据证明安全收益时才启用 WAL。
- 将版本元数据推进到 V1.0.3，补齐三语言、开发文档、用户文档与 CHANGELOG；Tag 和正式 Release 仅在全部门禁通过后由对应步骤执行。

## Capabilities

### New Capabilities

- `clipboard-capture-consistency`: 一次剪贴板变化只捕获一次来源信息，并在隐私判断、持久化和 capture event 中保持一致。
- `sensitive-content-detection-v2`: 提供结构化、可解释、低误判且完全本地的敏感内容检测。
- `storage-reconciliation`: 保守地识别并修复数据库记录、原图、缩略图和临时文件之间的不一致。
- `paste-coordination`: 统一所有历史、动作输出和未来复用入口的复制、自动粘贴、fallback 与使用统计语义。

### Modified Capabilities

- `add-text-clipboard-history`: 搜索输入变化必须取消旧任务，且只有最新查询可以提交 UI 结果。
- `optimize-data-cleanup-and-performance`: SQLite 并发模式、busy timeout、checkpoint 与事务边界必须通过可重复测试验证后再调整。

## Impact

- 主要影响 `ClipboardMonitor`、隐私检测服务、图片存储/数据库仓库、搜索 ViewModel、clipboard/paste 服务、数据库连接和应用启动依赖装配。
- 需要新增针对来源竞态、敏感正反样本、存储漂移、搜索取消、粘贴 fallback/统计和数据库并发的单元与集成测试。
- 可能新增数据库 migration 或启动期维护步骤；任何数据库变化必须保持旧库可升级且不得修改已发布 migration。
- 不新增远程服务或第三方依赖，不上传剪贴板内容，不改变用户已有 Automatic Paste 默认值。
- 需要同步 README、User Guide、架构/数据库/隐私文档、开发日志、CHANGELOG 和三语言资源。
