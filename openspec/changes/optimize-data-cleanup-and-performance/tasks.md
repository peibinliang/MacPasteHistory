## 1. Cleanup Rules

- [ ] 1.1 Clean expired records on startup.
  - 实现描述：应用启动时读取保留天数配置，删除超过期限的非收藏历史记录。
  - 前置条件：保留天数设置和清理服务已存在，历史记录有创建时间。
  - 验收条件：启动后过期记录被移除，未过期记录保留，清理结果有日志。
- [ ] 1.2 Remove oldest records when text count limits are exceeded.
  - 实现描述：按文本最大记录数保留最新文本记录，超出部分按时间从旧到新清理。
  - 前置条件：文本记录类型可查询，文本数量限制配置可读取。
  - 验收条件：超过限制后文本记录数量回到阈值内，最新记录保留。
- [ ] 1.3 Remove oldest records when image count limits are exceeded.
  - 实现描述：按图片最大记录数保留最新图片记录，删除超出部分及其本地文件。
  - 前置条件：图片记录类型和文件路径可查询，图片数量限制配置可读取。
  - 验收条件：超过限制后图片记录数量回到阈值内，删除记录的文件同步移除。
- [ ] 1.4 Preserve favorite records during automatic cleanup.
  - 实现描述：自动清理时跳过收藏记录，除非用户执行明确的清空全部数据。
  - 前置条件：历史记录有 `is_favorite` 字段，清理查询可过滤收藏状态。
  - 验收条件：收藏记录不会被过期、数量或空间自动清理删除。
- [ ] 1.5 Remove image files when storage limits are exceeded.
  - 实现描述：计算图片存储目录占用，超过总空间上限时按策略删除旧图片记录和文件。
  - 前置条件：总存储上限配置、图片目录大小计算和图片删除服务可用。
  - 验收条件：清理后目录大小不超过配置上限或已无可清理记录，数据库和文件状态一致。

## 2. Database And Queries

- [ ] 2.1 Add index for `created_at`.
  - 实现描述：通过迁移为历史表 `created_at` 字段添加索引，用于倒序列表和清理查询。
  - 前置条件：历史表已存在，迁移层支持新增索引。
  - 验收条件：索引存在；按时间排序查询可正常执行。
- [ ] 2.2 Add index for `content_type`.
  - 实现描述：为 `content_type` 字段添加索引，用于文本/图片筛选和按类型清理。
  - 前置条件：历史表包含 `content_type` 字段。
  - 验收条件：索引存在；按内容类型过滤查询结果正确。
- [ ] 2.3 Add index for `content_hash`.
  - 实现描述：为 `content_hash` 字段添加索引，用于文本和图片去重查询。
  - 前置条件：历史表包含 `content_hash` 字段。
  - 验收条件：索引存在；按 hash 查重查询结果正确。
- [ ] 2.4 Add index for `is_favorite`.
  - 实现描述：为 `is_favorite` 字段添加索引，用于收藏列表和清理跳过逻辑。
  - 前置条件：历史表包含 `is_favorite` 字段。
  - 验收条件：索引存在；收藏筛选查询结果正确。
- [ ] 2.5 Update repository queries to use pagination.
  - 实现描述：将历史列表、搜索和筛选查询改为 limit/offset 或游标分页。
  - 前置条件：repository 查询入口集中，UI 能请求更多数据。
  - 验收条件：分页参数生效；第一页和后续页无重复或漏数据。

## 3. UI And Image Performance

- [ ] 3.1 Add paginated list loading.
  - 实现描述：在 UI 层接入分页查询，滚动接近底部时加载下一页并追加到列表。
  - 前置条件：repository 已支持分页查询。
  - 验收条件：首次只加载有限记录；滚动加载更多时 UI 不冻结。
- [ ] 3.2 Optimize thumbnail cache usage.
  - 实现描述：避免反复解码原图，优先加载缩略图并缓存近期使用的缩略图对象。
  - 前置条件：图片记录已有缩略图路径，列表可区分图片行。
  - 验收条件：图片列表滚动时不会频繁读取原图；缩略图缺失时有降级处理。
- [ ] 3.3 Verify 1000 text records search without noticeable lag.
  - 实现描述：准备至少 1000 条文本记录，测试搜索输入、结果刷新和列表滚动体验。
  - 前置条件：搜索、索引和分页已实现，可生成或导入测试数据。
  - 验收条件：搜索不会明显卡顿或冻结，结果正确，CPU 使用保持可接受。
- [ ] 3.4 Verify 100 image records list smoothly.
  - 实现描述：准备至少 100 条图片记录，测试缩略图加载、滚动和内存占用。
  - 前置条件：图片存储、缩略图和分页列表已完成。
  - 验收条件：图片列表滚动流畅，内存不会随反复滚动持续异常增长。

## 4. Runtime Stability

- [ ] 4.1 Tune clipboard polling frequency.
  - 实现描述：将剪贴板轮询频率调整到兼顾实时性和 CPU 占用的默认值，例如 0.5 秒。
  - 前置条件：剪贴板监听器支持配置或常量化轮询间隔。
  - 验收条件：复制后能及时记录；空闲时 CPU 占用低且稳定。
- [ ] 4.2 Check long-running CPU usage.
  - 实现描述：让应用持续运行并记录空闲和频繁复制场景下的 CPU 表现。
  - 前置条件：核心监听、UI 和清理功能已集成。
  - 验收条件：长期空闲运行无持续高 CPU；异常热点有记录或修复。
- [ ] 4.3 Check for memory leaks.
  - 实现描述：使用 Instruments 或手动监测检查窗口开关、列表滚动、图片加载和复制恢复中的内存增长。
  - 前置条件：主要功能已可运行，能执行重复操作测试。
  - 验收条件：重复操作后内存能趋于稳定；发现的明显泄漏已修复或记录。
- [ ] 4.4 Verify data and image files do not grow without bounds.
  - 实现描述：组合测试保留天数、数量限制、空间上限和图片删除，确认长期数据有边界。
  - 前置条件：清理规则和设置项全部接入。
  - 验收条件：文档阶段 8 的验收标准全部通过。
