# Proposal

## Why

审计 P0-1 的修复项之一：阅读器内的设置面板目前整页复用 `ReaderSettings`（30+ 项带分组的全量设置，见 settings-ia-cleanup 与已落地的分组），阅读时调整亮度/模式要在完整设置页里翻找，违背"阅读场景快速调整"的目标。同时 settings-ia-cleanup 中的作用域选择器（reader-scope-model）会重构 `ReaderSettings` 的入口结构，本 change 与之衔接：作用域选择器管"全局/设备/漫画"结构，本 change 管"阅读内只留高频项"。

## What Changes

- 阅读器内设置面板改为精简面板：仅保留阅读模式、亮度、翻页方向/缩放、背景色等 6–8 个高频项
- 全量设置保留"全部设置"入口跳转设置 → 阅读（作用域自动为"此漫画"）
- 精简面板 items 与 `reader.dart` 分组后的 Reading 页共用同一偏好读写逻辑，无双份数据源

## Capabilities

### New Capabilities

- `reader/quick-settings`: 阅读器内快速设置面板——阅读场景下的高频设置极简集合，其余设置一键跳转到全量页

### Modified Capabilities

（无——reader-scope-model 的能力定义在 settings-ia-cleanup 中）

## Impact

- 代码：`lib/features/reader/settings_panel.dart`、`lib/features/settings/reader.dart`（抽出可复用的小组组件）
- 依赖：建议在 settings-ia-cleanup 的作用域选择器之后实施（面板默认"此漫画"作用域沿用其机制）
