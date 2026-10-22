# Proposal

## Why

BACKLOG B1（2026-10-21 诊断附带发现）：应用每次启动都在日志中报框架错误 `setState() or markNeedsBuild() called during build`——`main_page.dart:74` 的 `didChangeDependencies` 中同步调用 `_bindChrome` → `desktop_chrome.dart:109` 的 `bindGlobalActions` 通知上层 `InheritedNotifier` → 在构建期内触发 `DesktopChromeScope` markNeedsBuild。属于 Flutter 框架错误级日志，虽被框架宽容处理（父级正在构建），但每次启动必现，会掩盖其他真正的构建期问题，也不排除在更复杂的重建时序下引发实际异常。

## What Changes

- 动作绑定/侧栏同步通知移出构建期：延迟到帧后回调（addPostFrameCallback）执行，或改为不触发构建期的注册方式
- 稳定回调引用（避免每次 build 产生新闭包导致重复解绑/绑定）

## Capabilities

### New Capabilities

- `shell/chrome-lifecycle`: 桌面壳控制器的生命周期协调能力——动作绑定与通知不在构建期执行，壳层状态变化不触发框架错误

### Modified Capabilities

（无）

## Impact

- 代码：`lib/app_shell/main_page.dart`（`_bindChrome` 调用时机）、`lib/app_shell/desktop_chrome.dart`（`bindGlobalActions` 的通知方式/回调稳定性）
- 数据：无；翻译：无新词条

## Out of Scope

- 壳层其他行为/视觉调整
- 全局 setState-during-build 大排查（仅修本已知路径，其他路径若发现新问题另立 change）
