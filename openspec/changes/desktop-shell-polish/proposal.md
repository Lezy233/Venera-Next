# Proposal

## Why

审计 P2：设置页在宽屏双栏模式下，`PopupWindowSetting`（代理、DNS、关键词屏蔽、WebDAV 各配置）仍用居中弹窗覆盖在双栏之上，与双栏设置的"就地编辑"心智不符（参考现代极简设置页的就地展开形态）。统一 UI/UX 要求设置编辑在宽屏下就地发生。

## What Changes

- 双栏模式下，`PopupWindowSetting` 的构建结果改在右栏内容区就地渲染（带返回/关闭 affordance），不再弹居中弹窗
- 窄屏（单栏）保持现有弹窗行为不变
- 就地编辑的保存状态条（`settingsSaveStatus`）在右栏可见

## Capabilities

### New Capabilities

- `settings/inplace-editing`: 设置的就地编辑能力——宽屏双栏下设置子页在右栏就地展开，窄屏回退弹窗

### Modified Capabilities

（无）

## Impact

- 代码：`lib/features/settings/setting_components.dart`（`PopupWindowSetting`）、`lib/features/settings/settings_page.dart`（右栏导航栈增加子页路由能力）
- 依赖：建议在 design-system-foundation 之后实施（断点来源与壳层规范就位）
