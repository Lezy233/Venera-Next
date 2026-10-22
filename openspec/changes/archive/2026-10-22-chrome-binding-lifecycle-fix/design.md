# Design

## Context

- 错误链（启动日志实证）：`_MainPageState.didChangeDependencies`（main_page.dart:74）→ `_bindChrome`（:79）→ `DesktopChromeController.bindGlobalActions`（desktop_chrome.dart:109）→ `notifyListeners`（ChangeNotifier）→ `_InheritedNotifierElement._handleUpdate` 对 `DesktopChromeScope` 调 `markNeedsBuild`，此时框架正处于 build 阶段（`Builder` 构建中），触发错误日志。
- `didChangeDependencies` 可能随依赖变化多次调用；若回调引用不稳定（每次 build 新建闭包），还会产生重复绑定/解绑抖动。

## Goals / Non-Goals

**Goals:** 启动日志不再出现该错误；绑定语义不变（全局动作在阅读器/页面上下文正确注册）；回调引用稳定。

**Non-Goals:** 不改全局动作集内容；不改 InheritedNotifier 传递机制本身。

## Decisions

### D1: 绑定移入帧后回调，而非改通知机制

- `didChangeDependencies` 中的 `_bindChrome` 改为通过 `addPostFrameCallback` 延迟到首帧后执行（并做 mounted 守卫）；`bindGlobalActions` 内部通知保持同步（帧外调用时无构建期问题）。
- 备选：把 InheritedNotifier 换成显式 setState 传播——改动面大且波及所有消费方，否。
- 备选：仅在首次 didChangeDependencies 绑定——解决重复但不解决构建期触发，否。

### D2: 回调引用稳定化

- 绑定入口（`_bindChrome` 传入的回调）以 State 字段持有的稳定闭包/method tear-off 提供，不在 build 内联新建。

## Risks / Trade-offs

- [帧后绑定使首帧动作注册晚一帧] → 首帧内用户不可能触发全局动作（键盘事件晚于首帧渲染），无实际影响；executor 在诊断中实证。
- [addPostFrameCallback 在 didChangeDependencies 多次调用时排队多个回调] → mounted/已绑定守卫去重。

## Migration Plan

1. 复现并记录修复前启动日志错误
2. 按 D1/D2 实施
3. 新增回归测试（帧序断言）
4. GUI 走查：启动日志无该错误、全局动作（章节/搜索等快捷键）仍工作
