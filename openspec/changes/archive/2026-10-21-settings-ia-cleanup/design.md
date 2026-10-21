# Design

## Context

- 三个 WebDAV 配置现状：`app.dart` 的 `_WebdavSetting`（数据同步，URL/user/pass + 排除字段 + 同步计划）、`webdav_settings.dart` 的 `BackupWebdavSetting`（CBZ 存档备份）、`WebDavComicLibrarySetting`（在线漫画库，带 `WebDavLibraryScope`）。三者各自读写 `appdata.settings` 中不同的 key，UI 上是 App → Data 下三个平级 `CallbackSetting` 入口 + 三个独立弹窗。
- 阅读设置现状：`ReaderSettings`（`reader.dart`）通过 `comicId`/`comicSource` 参数区分单部漫画模式，页顶有 `_scopeTile`（单部漫画开关）和"Enable device specific settings"开关，每项设置再各自传 `useDeviceSettings`；同一组件被阅读器内面板（`settings_panel.dart`）以 comicId 复用。
- 设置导航现状：`settings_page.dart` 的 `categories` 数组硬编码 9 个分类，双栏阈值 720；`explore_settings.dart` 含 `Initial Page`（`DiscoveryPreferences.initialPage`）与 `Reverse default chapter order`（`AppPreferences.reverseChapterOrder`）。

## Goals / Non-Goals

**Goals:**

- WebDAV 连接信息单点存储，三用途共享；旧配置自动迁移
- 阅读设置作用域改为显式选择器，页面级切换而非条目级混排
- 设置分类归属调整，主导航从 9 项减至 7 项（Explore / Reading / Appearance / Local Favorites / APP / Network / About）

**Non-Goals:**

- 不改 WebDAV 同步/备份/在线阅读的后端行为与数据格式
- 不改阅读设置的数据模型（作用域 key 结构保持不变）
- 本次不做审计中的 P1-6（阅读器内搜索改为真章节过滤）与 P2 项
- 不动已在 quick wins 中落地的三项（双栏默认着陆、阅读页分组、搜索框提示语）

## Decisions

### D1: 共享连接存储在 appdata.settings 的新 key 下，用途设置保持独立

- 新增共享连接 key（如 `webdav.connection`，结构 `{url, user, pass}`），由三个用途共同读取；各用途的排他性配置（同步排除字段、同步计划、备份路径、漫画库目录）保持各自 key 不变。
- 备选：让三个用途共享 `BackupConfig` 已有存储——被拒绝，因为数据同步的字段（excludedFields/mode/interval）与备份不同构，共享会引入耦合。
- 迁移：应用启动时（`App.init()` 阶段）检测三个旧连接 key；若共享 key 为空而数据同步的连接非空，复制之；若备份/漫画库连接与数据同步不一致，以数据同步为准，并置一个"待确认"标记，首次进入远程存储页时提示。

### D2: UI 收敛为一个"远程存储"入口 + 用途子页

- App → Data 下用一个 `CallbackSetting`（标题"远程存储 / Remote Storage"）进入新页面：顶部为连接表单（复用 `WebDavConnectionFields`）+ 测试连接按钮；下方三个用途分组（复用现有 `SettingPartTitle`），各含启用开关、现有配置入口、一句话用途说明和连接状态副标题。
- 备选：保留三个平级入口、仅共享底层连接——实现更省，但入口语义仍然三分，用户心智模型问题未解决，故否。

### D3: 作用域选择器用页面级 SegmentedButton，而非条目级标记

- `ReaderSettings` 顶部改为 `SegmentedButton<String>`（默认 / 此设备 / 此漫画；"此漫画"仅在传入 comicId 时可用）。选中后整页以对应 scope 重新构建；现有 `SettingsSaveState`/`saveSetting` 机制保留，只是 scope 从"每条目传参"变为"页面级单值"。
- 阅读器内面板继续复用同一组件（默认选中"此漫画"），删除面板专用的 `_scopeTile` 混排。
- 备选：在现有平铺结构上只加彩色徽标标记作用域——改动最小但三类作用域仍在同一平面，违背 spec，否。

### D4: 导航调整直接改硬编码数组与条目位置

- `Initial Page`、`Reverse default chapter order` 从 `explore_settings.dart` 迁入 `app.dart`（APP 分类）。
- `ReadingStatsPage` 从 `settings_page.dart` 分类移除；在 `history_page.dart`（或统计页自身入口区）提供入口。
- Debug 从分类数组移除，在 `about.dart` 增加"高级"组（含 Debug、Logs 入口）。
- `initialPage` 参数与双栏逻辑不变（quick win 已处理默认着陆）。

## Risks / Trade-offs

- [迁移时三份旧连接不一致，静默取一可能丢用户配置] → 迁移不删除旧 key；不一致时弹一次性确认对话框，用户可选择保留哪份。
- [作用域选择器与 `SettingsSaveState` 的 `isCurrent` 判断耦合] → 切换作用域视为离开页面：触发 `leaveSettings` 语义（保存中禁用切换），与现有 proxy 弹窗的 `protectSettings` 一致。
- [主导航移除两项后，老用户找不到统计/Debug] → 统计入口移到历史页顶部工具区（同页面原有筛选控件一排）；Debug 在 About 页"高级"组并附说明。
- [WebDAV 共享连接后，停用某用途的连接行为变化] → 用途启停只控制该用途功能，不触碰共享连接；断开连接需用户显式清除。

## Migration Plan

1. 落地 D1 存储 + 迁移逻辑（含不一致确认），保持旧 UI 可用
2. 落地 D2 新 UI 入口，旧三个入口隐藏但代码保留一个版本周期
3. 落地 D3、D4（无数据迁移，纯 UI）
4. 验证：flutter analyze + 手动走查三用途配置/重置流程
5. 回滚：UI 改动均可独立 revert；数据迁移不回滚（新 key 为增量，旧 key 保留）

## Open Questions

- 远程存储页的连接表单是否复用 `_WebdavSetting` 的同步计划字段区，还是同步计划留在"数据同步"用途分组内？（倾向后者，实现时确认）
- 统计页入口放历史页顶部还是"我的"页？（不影响 spec，实现时与现有页面结构对齐）
