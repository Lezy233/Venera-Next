# Spec Delta

## Purpose

键盘快捷键体系的统一登记与求值能力：动作注册表是全部键盘绑定的唯一事实来源；默认键位兼容现状；用户可自定义、清除、重置；同上下文冲突被拒绝；文本输入聚焦时全局键不触发；设置页与 macOS 菜单一致展示。

## ADDED Requirements

### Requirement: 注册表唯一事实来源

全部全局与阅读器键盘绑定 MUST 通过动作注册表登记与求值（动作 id / 标题 / 默认键位 / 上下文 / 执行体）。`desktopShortcuts` 一类硬编码绑定表 MUST NOT 继续作为生效路径存在。

#### Scenario: 全局键经注册表生效

- **WHEN** 应用启动后用户在桌面壳按 Ctrl/Cmd+B
- **THEN** 触发左栏切换，且该绑定来自注册表 global 条目（desktopShortcuts 硬编码已移除）

#### Scenario: 阅读器键经注册表生效

- **WHEN** 用户在阅读器内按方向键、F12、Space
- **THEN** 行为与迁移前一致，且绑定解析自注册表 reader 条目

### Requirement: 默认键位兼容

迁移 MUST NOT 改变既有默认行为：4 个全局键（Ctrl/Cmd+, 设置；Ctrl/Cmd+F 搜索；Ctrl/Cmd+B 左栏；Ctrl/Cmd+Alt+B 右栏）、阅读器方向键（含 continuous 的 vertical/reverse 方向语义与 gallery 的按键连发）、F12 全屏，逐键可见行为与迁移前一致。

#### Scenario: 冻结约束保持

- **WHEN** 迁移完成后的应用中，chrome-lifecycle spec 所冻结的 4 个全局快捷键被触发（含阅读器内 Ctrl/Cmd+F 分流到章节搜索）
- **THEN** 触发行为与冻结描述一致

### Requirement: 用户覆盖持久化

用户改键 MUST 即时生效并持久化到 `appdata.json` 顶层 `shortcutOverrides`；重启后 MUST 保留；MUST 支持单条重置默认、单条清除（无键位）、全部重置。缺省（无该键）视为全部默认。

#### Scenario: 改键并重启

- **WHEN** 用户将「打开设置」改为 Ctrl+Shift+P，重启应用
- **THEN** 新键生效且 Ctrl+, 不再触发打开设置

#### Scenario: 重置

- **WHEN** 用户对某动作执行重置默认（或全部重置）
- **THEN** 该动作（或全部动作）恢复 design D2 默认键位并即时生效

### Requirement: 冲突检测

同一上下文内两个动作 MUST NOT 绑定同一组合键。捕获新键时若与同上下文其他动作的生效键冲突，MUST 拒绝保存并显示占用动作标题；不同上下文（global 与 reader）之间的相同组合键不算冲突。

#### Scenario: 同上下文冲突

- **WHEN** 用户尝试将某动作改为已被同上下文另一动作占用的组合键
- **THEN** 保存被拒绝，界面显示占用动作名称，原键位保持不变

#### Scenario: 跨上下文不算冲突

- **WHEN** 用户将某 reader 动作绑定为与某 global 动作相同的组合键
- **THEN** 保存被允许（阅读器接管键盘时屏蔽 global 键）

### Requirement: 文本输入守卫

当文本输入控件（EditableText/TextField）聚焦时，global 上下文注册键 MUST NOT 触发；reader 上下文保留既有阅读器焦点守卫。Esc 的局部行为（全局 pop、阅读器退出守卫、右键菜单）不受影响。

#### Scenario: 搜索框聚焦

- **WHEN** 命令中心搜索框聚焦且用户按下 Ctrl+B
- **THEN** 不触发左栏切换（现状会冒泡触发，本 change 修复之）

### Requirement: 设置页编辑

设置 APP 分类 MUST 提供「快捷键」页：按上下文分组列出全部可定制动作与生效键位；点击捕获新键（Esc 取消）；支持清除与重置；全部用户可见文案走 .tl 且 zh_CN/zh_TW 齐备。

#### Scenario: 捕获改键

- **WHEN** 用户点击「打开设置」行并按下 Ctrl+Shift+P
- **THEN** 新键即时生效、键位文本更新，且「打开设置」行不再显示 Ctrl+,

#### Scenario: 冲突提示

- **WHEN** 捕获到与「切换左栏」冲突的组合键
- **THEN** 界面显示「已被『切换左栏』使用」类文案（.tl），键位未变更

### Requirement: macOS 菜单 accelerator 一致

macOS 平台菜单项的 accelerator MUST 与注册表当前生效键位一致；被用户清除键位的菜单项 MUST NOT 显示 accelerator。

#### Scenario: 菜单显示当前键位

- **WHEN** 用户在 macOS 菜单查看 File/View 等菜单
- **THEN** 设有键位的菜单项显示与注册表一致的 accelerator，改键后重建反映新键
