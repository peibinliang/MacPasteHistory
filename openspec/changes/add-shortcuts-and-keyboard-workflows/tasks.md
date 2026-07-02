## 1. Shortcut Registration

- [ ] 1.1 Add a shortcut service.
  - 实现描述：封装全局快捷键注册、注销、回调和错误状态，避免快捷键逻辑散落在 UI 中。
  - 前置条件：应用生命周期对象可持有长期服务，设置服务可提供快捷键配置。
  - 验收条件：服务可启动和停止，注册成功或失败都有明确状态。
- [ ] 1.2 Register Command + Shift + V as the default global shortcut.
  - 实现描述：设置默认快捷键为 Command + Shift + V，并在应用启动时尝试注册。
  - 前置条件：快捷键服务已具备注册能力。
  - 验收条件：未被占用时按下 Command + Shift + V 能触发应用回调。
- [ ] 1.3 Open the history panel from the shortcut.
  - 实现描述：将快捷键回调连接到主历史面板窗口控制逻辑，支持唤起和聚焦。
  - 前置条件：主历史面板打开逻辑已存在，默认快捷键可触发回调。
  - 验收条件：在其他应用前台时按快捷键可打开或聚焦历史面板。
- [ ] 1.4 Detect shortcut registration conflicts.
  - 实现描述：捕获全局快捷键注册失败，记录冲突状态并暴露给设置页或提示组件。
  - 前置条件：快捷键注册 API 返回可判断的失败信息。
  - 验收条件：快捷键被占用时应用不崩溃，并能告知用户需要更换快捷键。

## 2. Shortcut Settings

- [ ] 2.1 Persist the configured shortcut.
  - 实现描述：将当前快捷键组合保存到配置中，并在启动时恢复注册。
  - 前置条件：`UserDefaults` 或设置服务已可保存结构化快捷键。
  - 验收条件：修改快捷键后重启应用仍使用新配置。
- [ ] 2.2 Add shortcut customization support.
  - 实现描述：在设置页提供快捷键录入或选择控件，校验组合键后更新快捷键服务。
  - 前置条件：设置页已存在，快捷键服务支持重新注册。
  - 验收条件：用户可修改快捷键；非法或空快捷键不会破坏已有可用配置。
- [ ] 2.3 Show a clear conflict message when registration fails.
  - 实现描述：在设置页或 toast 中展示快捷键冲突提示，并保留重新设置入口。
  - 前置条件：快捷键服务能暴露冲突状态。
  - 验收条件：冲突发生时用户能看到明确提示；解决冲突后提示消失。

## 3. Keyboard Interaction

- [ ] 3.1 Focus the history list when the panel opens.
  - 实现描述：面板显示后将键盘焦点放到历史列表或搜索/列表组合的默认控件上。
  - 前置条件：历史面板窗口打开逻辑已可执行焦点设置。
  - 验收条件：打开面板后无需鼠标点击即可使用方向键或输入搜索。
- [ ] 3.2 Close the panel with Escape.
  - 实现描述：监听 Escape 键并关闭或隐藏历史面板，同时保持应用继续运行在菜单栏。
  - 前置条件：面板窗口可被程序化关闭或隐藏。
  - 验收条件：按 Escape 后面板消失，菜单栏图标仍存在，再次唤起正常。
- [ ] 3.3 Move selection with up and down arrow keys.
  - 实现描述：为历史列表维护选中项，响应上下键移动并自动滚动到可见区域。
  - 前置条件：列表数据源和选中状态绑定已存在。
  - 验收条件：上下键能稳定切换记录；到达首尾时行为可预测且不崩溃。
- [ ] 3.4 Restore the selected item with Enter.
  - 实现描述：按 Enter 时调用当前选中记录的文本或图片恢复逻辑。
  - 前置条件：列表选中状态和文本/图片恢复服务已可用。
  - 验收条件：选中文本或图片后按 Enter 能写入剪贴板；无选中项时不会异常。

## 4. Feedback And Verification

- [ ] 4.1 Show a copy success toast after restore.
  - 实现描述：恢复成功后展示短暂 toast，例如“已复制到剪贴板”，失败时展示可理解错误。
  - 前置条件：恢复服务能返回成功或失败结果，UI 有 toast 承载位置。
  - 验收条件：恢复成功有反馈，反馈不会遮挡主要操作并会自动消失。
- [ ] 4.2 Verify shortcut opening, keyboard selection, Enter restore, Escape close, and conflict handling.
  - 实现描述：执行阶段 5 端到端验收，覆盖快捷键注册、键盘交互、恢复反馈和冲突场景。
  - 前置条件：本阶段所有快捷键和键盘任务已完成。
  - 验收条件：文档阶段 5 的验收标准全部通过。
