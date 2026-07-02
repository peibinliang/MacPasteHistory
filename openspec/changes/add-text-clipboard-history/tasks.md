## 1. Clipboard Monitoring

- [x] 1.1 Implement `NSPasteboard.changeCount` polling.
  - 实现描述：建立定时轮询服务，保存上一次 `changeCount`，发现变化后触发读取流程。
  - 前置条件：应用基础生命周期和日志模块已可用。
  - 验收条件：复制文本时能检测到变化；未变化时不重复触发；轮询可启动和停止。
- [x] 1.2 Read plain text content from the pasteboard.
  - 实现描述：从 `NSPasteboard` 中读取纯文本类型内容，并忽略空字符串或不支持类型。
  - 前置条件：轮询服务能触发读取流程。
  - 验收条件：复制普通文本后能得到完整字符串；复制非文本内容不会产生文本记录。
- [x] 1.3 Add text hashing for deduplication.
  - 实现描述：对规范化后的文本计算稳定 hash，用作去重和数据库查询键。
  - 前置条件：文本读取流程已返回字符串内容。
  - 验收条件：相同文本产生相同 hash，不同文本产生不同 hash 的概率满足本地去重需求。
- [x] 1.4 Add guardrails so internally restored content does not create unwanted duplicates.
  - 实现描述：标记应用自身写入剪贴板的恢复操作，避免恢复动作被监听器误认为新的用户复制。
  - 前置条件：监听服务和后续恢复写入路径已具备可共享状态。
  - 验收条件：点击恢复后不会新增重复记录；用户之后复制新文本仍能正常记录。

## 2. Persistence

- [x] 2.1 Create the `clipboard_history` table for text records.
  - 实现描述：通过迁移层创建包含文本内容、类型、hash、时间、来源和收藏字段的历史表。
  - 前置条件：SQLite 初始化和迁移层已完成。
  - 验收条件：首次启动自动建表；重复执行迁移安全；表结构支持文档中的文本字段。
- [x] 2.2 Save copied text to SQLite.
  - 实现描述：实现 repository 方法，将通过过滤的文本内容写入 `clipboard_history`。
  - 前置条件：历史表已存在，文本读取和 hash 已可用。
  - 验收条件：复制文本后数据库新增记录，字段值与复制内容一致。
- [x] 2.3 Store copy time and content hash.
  - 实现描述：保存复制时间和 `content_hash`，并确保后续排序和去重可使用这些字段。
  - 前置条件：文本保存方法已建立。
  - 验收条件：每条文本记录包含有效时间戳和 hash；列表可按时间倒序读取。
- [x] 2.4 Store text length metadata.
  - 实现描述：计算文本字符数并保存到数据库或可查询模型字段。
  - 前置条件：文本保存流程已能写入扩展元数据。
  - 验收条件：短文本和长文本的长度显示或调试查询结果正确。
- [x] 2.5 Add optional source app metadata where available.
  - 实现描述：在可获取当前前台应用时保存应用名称和 bundle id，无法获取时允许为空。
  - 前置条件：已有或可接入前台应用检测 helper；保存模型支持来源字段。
  - 验收条件：从常见应用复制时尽量保存来源；获取失败不影响文本记录入库。

## 3. History UI

- [x] 3.1 Implement the text history list UI.
  - 实现描述：创建历史列表 view 和 view model，从 repository 读取文本记录并按时间倒序展示。
  - 前置条件：文本记录已可保存和查询。
  - 验收条件：复制文本后列表出现对应记录；重开窗口后仍能加载历史。
- [x] 3.2 Show text previews and copy time.
  - 实现描述：在列表行展示文本前几行或截断预览，并显示复制时间。
  - 前置条件：历史列表 UI 已能展示记录模型。
  - 验收条件：长文本不会撑坏列表；时间信息可读且与记录时间一致。
- [x] 3.3 Load persisted history after app restart.
  - 实现描述：应用启动或窗口打开时从 SQLite 重新加载历史，而不是依赖内存状态。
  - 前置条件：repository 查询方法和列表绑定已完成。
  - 验收条件：复制文本后退出并重启应用，历史列表仍显示之前记录。
- [x] 3.4 Implement keyword search.
  - 实现描述：添加搜索输入和查询逻辑，按关键词过滤文本历史。
  - 前置条件：历史列表和 repository 查询路径已存在。
  - 验收条件：输入关键词后只显示匹配记录；清空关键词恢复完整列表。

## 4. Restore And Manage

- [x] 4.1 Restore a selected text item to the system clipboard.
  - 实现描述：点击或选择文本记录后，将其纯文本内容写入 `NSPasteboard`。
  - 前置条件：列表选择动作和剪贴板写入 helper 已可用。
  - 验收条件：恢复后用户可在其他应用中粘贴该文本；恢复动作不破坏历史。
- [x] 4.2 Delete a single text history item.
  - 实现描述：为列表记录提供删除操作，并从 SQLite 删除对应历史行。
  - 前置条件：列表记录有稳定 id，repository 支持按 id 删除。
  - 验收条件：删除后记录从 UI 和数据库消失，重启后不会回来。
- [x] 4.3 Clear text history.
  - 实现描述：提供清空文本历史操作，只删除文本类型记录并刷新列表。
  - 前置条件：repository 支持按类型批量删除，UI 有清空入口。
  - 验收条件：确认清空后文本记录为空；后续新复制文本仍可继续保存。
- [ ] 4.4 Verify copy, dedupe, search, restore, delete, clear, and restart persistence.
  - 实现描述：执行阶段 2 端到端验收，覆盖文本历史核心闭环。
  - 前置条件：本阶段所有文本监听、存储、UI 和管理任务已完成。
  - 验收条件：文档阶段 2 的验收标准全部通过，并记录未完成的 P1 元数据项。
