# Design

## Context

`settings_panel.dart` 现以 `ReaderSettingsPanel` 包装全量 `ReaderSettings`（comicId 传入）。settings-ia-cleanup 的 D3 将引入页面级作用域选择器。quick wins 已为全量页做了 7 组分组标题。

## Goals / Non-Goals

**Goals:** 阅读内面板 ≤8 项；与全量页零数据分叉；实施时与作用域选择器机制对齐。

**Non-Goals:** 不改阅读器手势/工具栏；不动全量设置页结构。

## Decisions

### D1: 精简面板为独立组件，复用偏好层而非 UI 层

- 新建 `lib/features/reader/quick_settings_panel.dart`，面板项直接用 `ReaderPreferenceStore`（comic scope）读写，UI 不复用 `ReaderSettings` 的 sliver 结构；与全量页共享的是 `foundation/reader_preferences.dart` 的偏好定义。
- 备选：给 `ReaderSettings` 加 `compact` 模式参数——组件 889 行已超载，再加模式分支会更难维护，否。

### D2: 面板项集合可配置，默认集写死在 spec 层

- 面板项列表实现为常量数组，未来增删只改一处；默认集以本 change spec 的"高频项"清单为准。

### D3: 实施顺序

- 在 settings-ia-cleanup 的作用域选择器（D3）落地后实施，直接消费其 scope 机制；若 owner 要求提前，则以现有 `_scopeTile` 机制临时对齐并在任务中记录技术债。

## Risks / Trade-offs

- [面板项取舍争议（"我常用的不在里面"）] → "全部设置"入口一键可达；后续按反馈调整常量数组
- [与作用域选择器的时序耦合] → tasks 中设前置检查任务；机制未就绪则按 D3 降级路径执行

## Migration Plan

1. 前置检查：作用域选择器是否已落地（reader-scope-model）
2. 实现精简面板组件并替换 `settings_panel.dart` 的全量复用
3. 验证 spec 三个场景 + flutter analyze
4. 回滚：独立组件，可整体 revert
