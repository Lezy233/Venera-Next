# Design

## Context

`PopupWindowSetting`（`setting_components.dart`）当前固定走 `showPopUpWidget`（覆盖层弹窗）。双栏右栏已有内嵌 `Navigator`（quick win 加了 `ValueKey`），具备子页能力。`SettingsSaveState`/`protectSettings` 机制在弹窗与页面均可工作（`_ProxySettingView` 已示范）。

## Goals / Non-Goals

**Goals:** 双栏就地、单栏弹窗；编辑组件零改动复用（同一 builder）。

**Non-Goals:** 不重写任何编辑表单；不动 `showPopUpWidget` 本身（窄屏仍用）。

## Decisions

### D1: 按断点分流，组件本体不改

- `PopupWindowSetting` 增加布局感知：读取统一断点（design-system-foundation 的 `breakpoints.dart`），双栏时向最近的设置页上下文发送"就地展开"请求（经 `SettingsPage` 提供的静态/Inherited 回调推入右栏 Navigator），单栏时保持 `showPopUpWidget`。
- 备选：为每个子页写双份容器——明显违反 DRY，否。

### D2: 就地容器复用 `PopUpWidgetScaffold` 的标题/返回结构

- 右栏就地页套用与弹窗相同的 scaffold（标题 + 返回），保证视觉与交互一致；`onBack` 即右栏 pop。

## Risks / Trade-offs

- [右栏 Navigator 栈与分类切换的交互（切分类时子页是否保留）] → 现状切分类重建 Navigator（ValueKey），就地子页随分类切换销毁，可接受；若验收时认为应保留，再加分类级栈
- [部分弹窗组件依赖覆盖层上下文（如 PopupIndicatorWidget）] → 任务 1.1 侦察 `_ProxySettingView`/`_DNSOverrides` 的覆盖层依赖，发现硬依赖则该入口暂缓就地化并记录例外

## Migration Plan

1. 侦察覆盖层依赖（任务 1.1）
2. 实现断点分流 + 右栏就地容器
3. 逐入口启用（代理 → DNS → 关键词屏蔽 → WebDAV 相关）
4. 验证 spec 场景 + flutter analyze
5. 回滚：分流开关集中在 `PopupWindowSetting`，可整体 revert
