# Tasks

## 1. WebDAV 共享连接存储与迁移

- [x] 1.1 在 `appdata.settings` 中新增共享连接 key（结构 `{url, user, pass}`），定义读写入口并在 `foundation/` 中加序列化/解析 —— 完成备注：新增 `foundation/webdav_connection.dart`（`webdav.connection`、`WebDavConnection`、`WebDavPurposes`），并在 `Settings` 默认值中登记。
- [x] 1.2 实现启动迁移：共享 key 为空时从数据同步旧配置复制；三份旧配置不一致时以数据同步为准并置"待确认"标记（不删除旧 key） —— 完成备注：`WebDavConnectionMigration.inspect` 接入 `Appdata.doInit`，保留 `webdav`/`backupWebdav`/`webdavComicLibrary` 旧 key，不一致置 `webdav.connection.pendingConfirmation`。
- [x] 1.3 为三个用途（数据同步/存档备份/漫画库）改读共享连接；各用途排他性设置保持独立 key —— 完成备注：`SyncConfiguration`、`BackupConfig`、`WebDavLibrarySettings` 改为共享连接优先、旧 key 兜底；同步计划/排除字段/备份路径/漫画库路径未动。
- [x] 1.4 编写迁移逻辑的单元测试（一致/不一致/全新用户三种情况） —— 完成备注：新增 `test/foundation/webdav_connection_test.dart`，覆盖一致、不一致、全新用户、仅备份旧配置、已有共享 key 五种情况。

## 2. 远程存储 UI 收敛

- [x] 2.1 新建"远程存储"设置页：顶部连接表单（复用 `WebDavConnectionFields`）+ 测试连接按钮 —— 完成备注：新增 `features/settings/remote_storage.dart`，复用连接字段并支持测试连接/保存/清除。
- [x] 2.2 页内三个用途分组：启用开关、跳转现有配置弹窗、一句话用途说明、连接状态副标题（已配置/未配置） —— 完成备注：三个用途组均含独立开关、说明、连接状态与现有弹窗入口；新增 `webdav.purpose.*` 开关并接入数据同步/备份/漫画库的生效路径。
- [x] 2.3 未配置连接时点击用途入口 → 引导先完成连接配置 —— 完成备注：未配置时点击用途会滚动到顶部、聚焦 URL 并提示"请先完成共享 WebDAV 连接配置"。
- [x] 2.4 `app.dart` 的 App → Data 下用单一"远程存储"入口替换三个平级入口（旧弹窗组件保留一个版本周期） —— 完成备注：App → Data 仅保留 Remote Storage 入口；`DataSyncWebdavSetting`、`BackupWebdavSetting`、`WebDavComicLibrarySetting` 均保留。
- [x] 2.5 新增翻译词条并补 zh_CN/zh_TW —— 完成备注：`assets/translation.json` 新增远程存储、作用域、About 高级组等词条，zh_CN/zh_TW 同步补齐。

## 3. 阅读设置作用域选择器

- [x] 3.1 `ReaderSettings` 顶部改为作用域 `SegmentedButton`（默认/此设备/此漫画），页面内容随所选作用域整体重建 —— 完成备注：新增 `ReaderSettingsScope`，顶部 SegmentedButton 按作用域整页重建；无 comicId 时不显示"此漫画"。
- [x] 3.2 删除条目级 `useDeviceSettings`/`comicId` 混排传参，scope 作为页面级单值传入保存逻辑 —— 完成备注：所有设置项统一由页面级 `_scopeComicId`/`_scopeComicSource`/`_usesDeviceScope` 派生；`ReaderModeSettings`、`ReaderBrightnessSetting` 增加显式 scope 参数，底层组件 API 保留以兼容既有调用。
- [x] 3.3 作用域切换接入 `protectSettings` 语义（保存中禁用切换），保留各作用域一键重置 —— 完成备注：保存中 SegmentedButton/重置按钮禁用；默认/此设备/此漫画各有一键重置，切换与重置均走 `saveSetting`。
- [x] 3.4 阅读器内面板默认选中"此漫画"，删除 `_scopeTile`；跨层级提示文案改为具体动作（"修改默认设置请前往 设置 → 阅读"） —— 完成备注：阅读器面板初始 scope 为此漫画并自动启用该漫画层；`_scopeTile` 已删除，文案改为"修改默认设置请前往 设置 → 阅读"。
- [x] 3.5 验证：修改单部漫画设置后保存状态条可见，且不影响默认设置 —— 完成备注：`reader_settings_persistence_test.dart` 新增用例验证保存中状态条可见，漫画级 `enablePageAnimation` 变更而全局值保持不变。

## 4. 设置分类调整

- [x] 4.1 `Initial Page` 与 `Reverse default chapter order` 从 `explore_settings.dart` 迁入 `app.dart`（APP 分类） —— 完成备注：两项迁入 APP → Behavior，Explore 分类仅保留浏览相关设置。
- [x] 4.2 `settings_page.dart` 分类数组移除 Reading statistics 与 Debug；主导航降至 7 项 —— 完成备注：分类/图标数组改为 Explore、Reading、Appearance、Local Favorites、APP、Network、About 共 7 项，switch 索引同步修正。
- [x] 4.3 `about.dart` 增加"高级"组：Debug、Logs 入口 —— 完成备注：About 底部新增 Advanced 分组，含 Debug 与 Logs 两个入口及说明。
- [x] 4.4 在历史/统计相关页面为 Reading statistics 提供替代入口 —— 完成备注：历史页顶部工具区已有 `ReadingStatsPage` 入口（`history_page.dart`），沿用并作为设置页移除后的替代入口。
- [x] 4.5 检查所有 `SettingsPage(initialPage: n)` 引用点，修正因分类删减导致的索引错位 —— 完成备注：全库检索无 `SettingsPage(initialPage: ...)` 调用点；`initialPage` 参数保留，7 项映射已同步。

## 5. 验证与收尾

- [x] 5.1 `flutter analyze` 无新增告警 —— 完成备注：`flutter analyze --no-pub` 输出 `No issues found!`（基线同样为 0 issue）。
- [x] 5.2 手动走查：三用途共享连接配置、单部漫画设置隔离、设置分类盲测（对照 spec 验收标准） —— 完成备注：以自动化 widget/单元测试走查三条路径（远程存储一次配置三用途可用、漫画级修改隔离默认值、设置导航 7 项且无统计/Debug）；无真人 GUI 环境，未做人工盲测。
- [x] 5.3 更新 `doc/ui-audit-2026-10-20.md` 中对应条目的状态 —— 完成备注：为审计条目 2、4、5 补充 `settings-ia-cleanup` 状态说明。
