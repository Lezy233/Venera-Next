# Proposal

## Why

Venera-Next 的设置在移动端继承期形成了混乱的信息架构：三套互相独立的 WebDAV 配置让用户重复填写连接信息且无法建立正确心智模型；阅读设置的全局/设备/单部漫画三层作用域并列暴露，用户改错作用域后无法评估改动影响；App 级行为偏好（启动页、章节排序）错放在"浏览"分类，统计页和 Debug 控制台占据了主导航格子。2026-10-20 的 UI 审计（见 `doc/ui-audit-2026-10-20.md`）将以上列为 P0/P1。三个 quick wins（双栏默认着陆、阅读页分组标题、搜索框上下文提示语）已先行落地，本 change 覆盖剩余的高优先级项。

## What Changes

- 将 App → Data 下三个独立 WebDAV 配置入口（Data Sync / Comic Archive Backup / WebDAV Comic Library）合并为单一"远程存储"配置：一份连接配置 + 各用途开关/说明，并在每个用途入口显示当前连接状态
- 阅读设置页引入明确的作用域选择器（默认 / 此设备 / 此漫画），整页内容随所选作用域切换；单部漫画设置面板中的跨层级提示文案改为具体动作描述
- 设置分类调整："Initial Page"与"Reverse default chapter order"迁入 APP 分类；"Reading statistics"移出设置主导航（改由历史/统计页入口承载）；Debug 从主导航折叠进 About → 高级

## Capabilities

### New Capabilities

- `settings/webdav-storage`: 统一的远程存储（WebDAV）连接配置能力——一份连接信息被数据同步、漫画存档备份、WebDAV 漫画库三个用途共享，各用途可独立启停，UI 上显示连接配置状态
- `settings/reader-scope-model`: 阅读设置的作用域选择能力——用户在阅读设置页通过显式选择器切换"默认 / 此设备 / 此漫画"作用域，页面内容随作用域整体切换，避免逐条目的作用域混排
- `settings/navigation`: 设置区的信息架构组织能力——分类归属与用户心智模型一致，非设置内容（统计页、调试工具）不占主导航格子

### Modified Capabilities

（无——项目尚无既有 spec）

## Impact

- 代码：`lib/features/settings/app.dart`（WebDAV 三个入口与 `_WebdavSetting`）、`lib/features/settings/webdav_settings.dart`、`lib/features/settings/reader.dart`（作用域选择器）、`lib/features/settings/settings_page.dart`（分类与导航）、`lib/features/settings/explore_settings.dart`（迁出 App 级偏好）、`lib/features/history/reading_stats_page.dart`（入口迁移）、`lib/features/settings/debug.dart`（入口折叠）
- 数据：WebDAV 连接配置存储模型需要迁移/兼容逻辑（三处旧配置 → 一份共享配置 + 用途开关）；阅读设置作用域数据模型不变，仅交互改变
- 翻译：`assets/translation.json` 需新增约 15–20 个词条
- 依赖：无新依赖
