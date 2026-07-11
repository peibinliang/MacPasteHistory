## 1. List Presentation

- [x] 1.1 Improve history list row styling.
  - 实现描述：优化行间距、字体层级、类型标识和操作区域，让文本和图片记录都易扫描。
  - 前置条件：基础历史列表已存在并能渲染记录。
  - 验收条件：列表在浅色和深色模式下清晰可读，行操作不遮挡内容。
- [x] 1.2 Add bounded multi-line text previews.
  - 实现描述：限制文本预览行数和高度，对超长内容使用截断或渐隐处理。
  - 前置条件：历史行组件能访问文本内容。
  - 验收条件：长文本不会撑爆窗口；短文本完整显示在预览范围内。
- [x] 1.3 Add user-friendly time display for today, yesterday, and exact times.
  - 实现描述：封装时间格式化，按今天、昨天和更早日期展示相对或具体时间。
  - 前置条件：历史记录包含创建时间字段。
  - 验收条件：不同日期记录显示符合规则；系统时区下结果正确。
- [x] 1.4 Ensure long text does not distort the list layout.
  - 实现描述：为行高、文本容器和操作按钮设置稳定约束，避免动态内容导致布局跳动。
  - 前置条件：多行预览和行样式已实现。
  - 验收条件：超长单词、多行文本和大量记录下列表仍能正常滚动。

## 2. Details

- [x] 2.1 Implement a history detail view or dialog.
  - 实现描述：创建详情弹窗或独立面板，用于展示记录完整内容和操作按钮。
  - 前置条件：历史列表记录有稳定选择或点击事件。
  - 验收条件：点击记录可打开详情；关闭详情后列表状态保持正常。
- [x] 2.2 Show full text content in the detail view.
  - 实现描述：在详情中展示完整文本，支持滚动和复制/恢复入口。
  - 前置条件：详情视图已能接收文本记录模型。
  - 验收条件：长文本可完整查看且不会截断；滚动行为正常。
- [x] 2.3 Show available metadata such as time, type, source, and size.
  - 实现描述：在详情中展示创建时间、内容类型、来源应用、文本长度或图片大小等已有字段。
  - 前置条件：记录模型和数据库查询返回对应元数据。
  - 验收条件：有值字段正确显示；缺失字段以空状态或隐藏方式处理。
- [x] 2.4 Keep restore and delete actions available from detail where appropriate.
  - 实现描述：在详情页复用列表的恢复和删除逻辑，删除后关闭详情并刷新列表。
  - 前置条件：恢复和删除服务已存在。
  - 验收条件：从详情恢复和删除的结果与从列表操作一致。

## 3. Favorites And Filters

- [x] 3.1 Add favorite behavior for history records.
  - 实现描述：为记录添加收藏操作，更新 `is_favorite` 状态并刷新 UI。
  - 前置条件：历史表包含收藏字段，列表行有操作入口。
  - 验收条件：收藏后图标或状态立即变化，重启后收藏状态仍保留。
- [x] 3.2 Add unfavorite behavior.
  - 实现描述：为已收藏记录提供取消收藏操作，并持久化状态变更。
  - 前置条件：收藏行为已实现。
  - 验收条件：取消收藏后记录不再出现在收藏过滤结果中，重启后状态正确。
- [x] 3.3 Add a favorites-only list or filter.
  - 实现描述：添加收藏列表或筛选开关，只查询并展示 `is_favorite` 记录。
  - 前置条件：收藏和取消收藏状态可查询。
  - 验收条件：开启收藏视图后只显示收藏记录；关闭后恢复普通历史。
- [x] 3.4 Add content type filtering for text and image records.
  - 实现描述：添加文本、图片等类型筛选，并将筛选条件传给查询或 view model。
  - 前置条件：历史记录包含 `content_type` 字段。
  - 验收条件：选择文本只显示文本，选择图片只显示图片，全部模式恢复完整列表。

## 4. Loading Behavior

- [x] 4.1 Add lazy loading or pagination for history queries.
  - 实现描述：将历史查询改为分页或懒加载，滚动接近底部时加载更多。
  - 前置条件：repository 支持 limit/offset 或游标参数。
  - 验收条件：大量记录不会一次性全部加载；滚动到底部能继续加载下一页。
- [x] 4.2 Verify scrolling remains smooth with many records.
  - 实现描述：用足量文本和图片记录进行滚动体验验证，定位明显卡顿点。
  - 前置条件：分页或懒加载已实现，测试数据可准备。
  - 验收条件：滚动无明显冻结；内存不会因列表浏览持续异常增长。
- [x] 4.3 Verify favorites, filters, detail viewing, and long previews.
  - 实现描述：执行阶段 3 功能验收，覆盖收藏、筛选、详情和长文本布局。
  - 前置条件：本阶段所有 UI 和查询增强任务已完成。
  - 验收条件：文档阶段 3 的验收标准全部通过。
