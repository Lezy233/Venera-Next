# F9 阅读模式方案手动排序

## Why

方案库目前按创建顺序展示，用户无法调整常用顺序。B3 持续绑定及继承行为已验收归档；owner 指定 F8 → F9。

## What Changes

- 管理页提供拖动手柄及上移/下移操作，支持键盘和单次点击替代拖动。
- 持久化方案库顺序，管理页、设置选择器、阅读器面板使用同一顺序，重进重启保持。
- 排序只移动身份，不修改名称、19键、modeBehavior、三层绑定及实际阅读效果；可靠失败恢复与并发CRUD保留。

## Scope and Impact

入口 lib/features/settings/reader_presets.dart、lib/foundation/reader_presets.dart、lib/features/reader/quick_settings_panel.dart。复用既有 readerModePresets 有序列表；保持 B3 正式契约，遵循 design-spec.md §1–6，不增加依赖或美化。F8 验收后才派活，本工件只规划，不与F8并行改实现。
