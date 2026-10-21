# Design

## Context

现状分流在 `DesktopChromeController`：阅读器注册 `DesktopReaderActions`（`openChapters`），收藏页注册 `_favoritesSearchQuery`；`focusSearch` 在阅读器内直接打开章节列表，`submitSearch` 提交时再分流。章节列表 UI 在 `lib/features/reader/chapters.dart`。

## Goals / Non-Goals

**Goals:** 三上下文行为/提示语一一对应；章节过滤为"输入即过滤"；快捷键与点击等价。

**Non-Goals:** 不做全局模糊搜索（跨源聚合）；不动全局搜索页本身；不引入搜索历史。

## Decisions

### D1: 章节过滤走"过滤回调注册"模式，与收藏页同构

- `DesktopReaderActions` 增加 `ValueChanged<String>? filterChapters`；阅读器挂载时注册，将过滤词路由到章节列表的过滤逻辑（章节列表组件需支持按标题过滤，若现有 `chapters.dart` 无过滤能力则补一个内部过滤状态，不改数据源）。
- `focusSearch` 改为：阅读器内 → 打开章节列表**并聚焦命令中心**（现状打开后焦点行为不变），过滤词实时下发；提交（回车）→ 跳转首个匹配。
- 备选：回车仍只打开章节列表——提示语承诺了"搜索"，行为必须兑现，否。

### D2: 空态与匹配逻辑

- 章节过滤大小写不敏感，匹配章节标题；空结果在章节列表区显示空态文案。
- 收藏页空输入恢复完整列表（现状 `updateSearchQuery` 已支持，核对即可）。

## Risks / Trade-offs

- [章节列表组件改造范围不确定] → 任务 1.1 先做侦察，过滤实现若牵涉滚动定位（scrollable_positioned_list）则缩小范围到"过滤+跳转首匹配"，不做高亮
- [过滤性能（超长章节列表）] → 过滤在内存中按标题匹配，千级章节无压力；如实测卡顿再节流

## Migration Plan

1. 侦察 `chapters.dart` 现有结构与过滤能力
2. 实现过滤回调链路（controller → reader → chapters）
3. 空态提示 + 快捷键对齐核对
4. 验证 spec 场景 + flutter analyze
5. 回滚：链路为增量注册式，可整体 revert
