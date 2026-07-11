## 1. Image Detection

- [x] 1.1 Detect PNG data in the pasteboard.
  - 实现描述：扩展剪贴板读取器，识别 `NSPasteboard` 中的 PNG 类型数据并转换为内部图片候选对象。
  - 前置条件：剪贴板监听服务已能检测变化，图片记录开关默认策略已确定。
  - 验收条件：复制 PNG 图片后读取器能返回图片数据；复制纯文本不会误判为图片。
- [x] 1.2 Detect TIFF data in the pasteboard.
  - 实现描述：支持 macOS 截图等常见 TIFF pasteboard 表示，读取 TIFF 数据并传入图片处理流程。
  - 前置条件：图片读取器接口已支持多格式分支。
  - 验收条件：使用 macOS 截图复制到剪贴板后能识别为图片候选。
- [x] 1.3 Convert TIFF images to PNG for storage.
  - 实现描述：将 TIFF 数据解码后重新编码为 PNG，统一后续文件存储和恢复路径。
  - 前置条件：TIFF 读取已可获得有效图片数据，图片编码工具已确定。
  - 验收条件：TIFF 来源图片保存为 PNG 文件，图片尺寸和可视内容保持正确。
- [x] 1.4 Support browser-copied images where available.
  - 实现描述：验证并兼容 Chrome、Safari 等浏览器复制图片时提供的 pasteboard 类型。
  - 前置条件：PNG/TIFF 读取分支已实现，已有手动测试浏览器环境。
  - 验收条件：从主流浏览器复制图片后，能记录可预览的图片历史项；不支持的表示有日志说明。
- [x] 1.5 Add support for Finder image file copies.
  - 实现描述：识别 Finder 复制图片文件时的文件 URL，读取受支持图片并复制到应用存储目录。
  - 前置条件：本地图片存储服务已准备，已明确支持的文件扩展名。
  - 验收条件：在 Finder 复制 PNG/JPEG 等图片文件后可生成图片历史；非图片文件不会被保存。

## 2. Image Storage

- [x] 2.1 Create the local images directory.
  - 实现描述：在 Application Support 下创建 images 和 thumbnails 目录，并封装路径生成逻辑。
  - 前置条件：Application Support 根目录已存在。
  - 验收条件：首次保存图片前目录自动创建；重复创建安全；路径不暴露到临时目录。
- [x] 2.2 Save original image files to disk.
  - 实现描述：将捕获或转换后的图片原文件写入 images 目录，文件名使用稳定唯一 id 或 hash。
  - 前置条件：图片数据已可读取，images 目录可用。
  - 验收条件：复制图片后磁盘上存在对应原图文件，文件可打开且内容正确。
- [x] 2.3 Generate thumbnail files.
  - 实现描述：为图片生成尺寸受控的缩略图并写入 thumbnails 目录，用于列表预览。
  - 前置条件：原图文件已保存，图片解码和缩放工具可用。
  - 验收条件：每条图片记录有可读取缩略图；大图缩略图尺寸受控且不明显变形。
- [x] 2.4 Persist image paths and metadata in SQLite.
  - 实现描述：在 `clipboard_history` 中保存图片类型、原图路径、缩略图路径、大小、宽高、格式和时间。
  - 前置条件：历史表支持图片字段或迁移已准备，图片文件保存成功。
  - 验收条件：图片记录可从数据库查询到完整路径和元数据；重启后仍可显示。
- [x] 2.5 Add image hash deduplication.
  - 实现描述：基于规范化图片数据或文件内容计算 hash，避免重复保存相同图片。
  - 前置条件：图片保存前可访问最终图片数据，数据库支持按 hash 查询。
  - 验收条件：连续复制相同图片不会新增重复记录；不同图片能分别保存。
- [x] 2.6 Enforce per-image size limits.
  - 实现描述：在保存前检查图片数据大小或文件大小，超过配置限制时跳过保存并记录原因。
  - 前置条件：图片大小可计算，设置服务提供默认大小限制。
  - 验收条件：超限图片不落库也不残留文件；未超限图片正常保存。

## 3. Image UI And Restore

- [x] 3.1 Display image records in the history list.
  - 实现描述：扩展历史列表数据模型和行组件，使图片记录与文本记录按时间统一展示。
  - 前置条件：图片元数据已可从数据库查询，历史列表支持内容类型。
  - 验收条件：复制图片后列表出现图片记录；文本和图片排序一致。
- [x] 3.2 Show thumbnail previews.
  - 实现描述：在图片行加载并显示缩略图，处理缩略图缺失或读取失败的占位状态。
  - 前置条件：缩略图文件已生成，图片行组件已存在。
  - 验收条件：图片行显示缩略图；缺失文件不会导致崩溃。
- [x] 3.3 Open full image detail where appropriate.
  - 实现描述：在详情视图中展示原图预览和图片元数据，支持滚动或适配窗口大小。
  - 前置条件：历史详情视图已存在或可创建，原图路径可读取。
  - 验收条件：点击图片记录可查看大图；大图显示不超出窗口可用区域。
- [x] 3.4 Restore selected images to the system clipboard.
  - 实现描述：读取本地图片文件并写入 `NSPasteboard` 的图片类型，使其他应用可粘贴。
  - 前置条件：原图文件存在，剪贴板写入 helper 支持图片。
  - 验收条件：恢复图片后可粘贴到支持图片的聊天或办公应用；恢复失败有用户反馈或日志。

## 4. Cleanup And Settings

- [x] 4.1 Delete original and thumbnail files when image records are deleted.
  - 实现描述：扩展删除流程，在删除数据库记录时同步删除原图和缩略图文件。
  - 前置条件：图片记录包含可解析文件路径，删除 repository 已存在。
  - 验收条件：删除图片历史后数据库记录消失，原图和缩略图文件不再残留。
- [x] 4.2 Add or wire the image recording switch.
  - 实现描述：将设置中的图片记录开关接入图片捕获入口，关闭时直接跳过图片保存。
  - 前置条件：设置服务或默认配置可读取图片记录开关。
  - 验收条件：关闭图片记录后复制图片不新增历史；重新开启后恢复记录能力。
- [x] 4.3 Verify screenshot, browser image, restore, delete cleanup, and disabled image recording behavior.
  - 实现描述：执行阶段 4 端到端验收，覆盖主要图片来源、恢复、删除和开关行为。
  - 前置条件：本阶段图片检测、存储、UI、恢复、清理和设置任务已完成。
  - 验收条件：文档阶段 4 的验收标准全部通过，并记录 Finder 图片文件复制等 P1 场景结果。
