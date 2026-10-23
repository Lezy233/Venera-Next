# Proposal

## Why

BACKLOG F3（批次 A）：Venera-Next 是 PC 优先效率工具，键盘可全程操作是愿景核心，但现状键盘能力薄弱——全局仅 4 个硬编码快捷键（`desktop_chrome.dart:222-230` 的 desktopShortcuts），阅读器键位散落在视图内部不可自定义，无动作登记机制、无用户改键能力、无冲突检测。owner 明确诉求自定义键位。F3 同时是 F1（页面多开）的前置：动作注册表的多栈上下文设计需要先定型。

## What Changes

- 新增**动作注册表**（action registry）：动作 id / 标题（.tl）/ 默认键位 / 上下文（global/reader）/ 执行体统一登记，成为全部键盘绑定的唯一事实来源；删除 `desktopShortcuts` 硬编码，main.dart 顶层快捷键改为从注册表动态构建
- 现有键位**原样迁移**（默认行为零变化）：4 个全局键、阅读器方向键（视图语义保留在视图层）、F12 全屏；少量高价值新增默认键（主页面切换 Ctrl/Cmd+1..4、阅读器 Space/PageUp/PageDown 翻页）
- **用户自定义键位**：覆盖持久化到 `appdata.json`（顶层 `shortcutOverrides`），改键即时生效、重启保留；支持单条重置与全部重置
- **冲突检测**：同一上下文内两个动作不得绑定同一组合键；编辑时冲突拒绝保存并显示占用动作名
- **文本输入守卫**：文本输入控件聚焦时全局注册键不触发（修复现状 Ctrl+字母在输入框聚焦时冒泡触发的问题）
- 设置 APP 分类新增「快捷键」页：分组展示、捕获式改键、清除/重置
- macOS 菜单项 accelerator 与注册表当前生效键位一致

## Capabilities

### New Capabilities

- `shell/shortcuts`: 键盘快捷键体系——动作注册表、默认键位、用户覆盖、冲突检测、设置页编辑与菜单标注的统一登记与求值

### Modified Capabilities

- `settings/navigation`: 新增「快捷键」设置分类，归属 APP 分类（App 级行为偏好）

## Impact

- 代码：`lib/app_shell/desktop_chrome.dart`（desktopShortcuts 移除）、`lib/main.dart`（顶层绑定动态化）、`lib/features/reader/`（键位接入注册表，视图方向语义保留）、`lib/features/settings/`（新增快捷键页）、新增注册表模块（建议 `lib/foundation/shortcuts/` 或 `lib/app_shell/shortcuts/`，由执行者按代码结构定）
- 数据：`appdata.json` 新增顶层键 `shortcutOverrides`（无默认值变更，缺省视为空表）；pubspec.yaml / pubspec.lock 不动
- 翻译：`assets/translation.json` 新增词条（动作标题、设置页文案、冲突提示），zh_CN 与 zh_TW 同步补齐
- 契约：`openspec/specs/shell/chrome-lifecycle/spec.md` 冻结了「全局快捷键注册内容与触发行为不变」——本 change 保持该约束（迁移后 4 全局键行为不变）

## Out of Scope

- Esc 键改键/注册（保留现有局部行为：全局 pop、阅读器退出守卫、右键菜单；登记为已知边界）
- 手势系统（独立输入通道）、移动端专属键位
- Windows/Linux 内联菜单的键位文字标注（仅 macOS 菜单 accelerator）
- F1 多栈的页面级上下文（design.md 仅做兼容性设计，不实现）
- 命令中心键位语义（Ctrl/Cmd+F 现有行为不变，见 command-center spec）
