# Proposal

## Why

owner 验收时发现（2026-10-21）：在「设置 → 阅读」切换作用域、以及「快捷设置 → 全部设置 → 切换作用域」时，页面顶部弹出一个只显示下半的方框（推测为「已保存」成功气泡），被桌面壳顶栏遮住。作用域切换会触发保存（settings-ia-cleanup 的既定语义），因此该提示在最高频路径上必然出现。

根因：`save-bar-layout-fix` 的 `_SettingsSaveFeedback` 以 `Align(topCenter)` 浮动在页面 Stack 顶部，位于桌面壳顶栏（desktop chrome）的覆盖/裁剪范围内，提示仅下半可见。这是 save-bar-layout-fix 覆盖层方案的放置位置回归——该 change 验收时的 GUI 走查页面（收藏/阅读设置）未覆盖「顶栏遮挡」这一几何关系。

## What Changes

- 保存反馈覆盖层的垂直位置移入安全可视区：不被顶栏遮挡、完整呈现三态反馈
- 修复后所有接入 `withSettingsSaveFeedback` 的页面（含设置页与右栏就地编辑页）一并生效

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `components/save-feedback`: 增加「完整可见」约束——保存反馈 MUST NOT 被壳层（顶栏等）遮挡或裁剪

## Impact

- 代码：`lib/components/settings_save_state.dart`（`_SettingsSaveFeedback` 的定位，预计极小改动）
- 数据：无；翻译：无新词条

## Out of Scope

- 保存反馈的样式重设计（只动位置，不动视觉）
- 顶栏（desktop chrome）本身的布局结构
