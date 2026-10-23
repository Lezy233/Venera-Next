# Proposal

## Why

BACKLOG F4（批次 A）：不同漫画类型（条漫/页漫/日漫双页）需要整套阅读配置切换，但现状阅读设置是 47 个独立键（`lib/foundation/reader_preferences.dart`），用户只能逐项调整，或靠「自动模式 + 布局检测」被动匹配。快捷键体系（keyboard-shortcuts）已落地，为整套切换补最后一块：命名方案的保存与应用。

## What Changes

- 新增**阅读模式方案**（mode presets）：命名的「键→值」包，覆盖约 20 个模式/布局/手势键（design D2 清单）；存储于 `appdata.json` 顶层 `readerModePresets`
- 方案 CRUD：从当前生效设置**快照新建**、重命名、**更新为当前值**（重新快照）、删除；名称非空、同作用域内不重名（重名拒绝并提示）
- **应用方案**：把方案内键值写入当前作用域——设置页内 = 作用域选择器当前所选层；阅读器内 = 此漫画层。方案与三层作用域机制**正交**：方案本身不携带作用域，应用目标由应用时的上下文决定
- 入口一：设置 → 阅读分类新增「阅读模式方案」组（当前方案应用 + 管理页）
- 入口二：阅读器快捷设置面板新增「方案」下拉（选择即应用到此漫画），修改 quick-settings spec
- 无数据迁移；预设键集合固定，未来新增阅读键不追溯进既有方案

## Capabilities

### New Capabilities

- `reader/mode-presets`: 阅读模式方案的命名、快照、应用与生命周期管理（与三层作用域机制正交）

### Modified Capabilities

- `reader/quick-settings`: 面板默认集新增「方案」切换项

## Impact

- 代码：新增 `lib/foundation/reader_presets.dart`（管理器）；修改 `lib/features/settings/reader.dart`（新增方案组）、新增方案管理页、`lib/features/reader/quick_settings_panel.dart`（方案下拉）；复用 `ReaderPreferenceStore` 写路径（含 comic 层 `readerModeOverride` 特判）
- 数据：`appdata.json` 新增顶层键 `readerModePresets`（List of {id, name, values}）；pubspec.yaml/lock 不动
- 翻译：`assets/translation.json` 新词条（方案管理、重名提示等），zh_CN/zh_TW 同步
- 契约依赖：settings/reader-scope-model（作用域选择器语义）、reader/quick-settings（面板默认集）；均只引用不修改（quick-settings 以 delta 增补）

## Out of Scope

- 方案的导入/导出/分享
- 方案与「自动模式/布局检测」的联动（检测不自动选方案）
- 收藏/详情页级方案入口（保留阅读器 + 设置两处）
- 亮度、缩略图、E-Ink、自动阅读、预加载等全局体验键不进方案键集合（design D2）
- 快捷键绑定方案切换（注册表预留命令扩展，本期不接）
