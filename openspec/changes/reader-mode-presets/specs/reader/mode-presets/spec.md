# Spec Delta

## Purpose

阅读模式方案能力：把模式/布局/手势的一组阅读设置保存为命名方案，支持快照新建、重命名、更新、删除与应用；方案与三层作用域机制正交（应用目标由应用时上下文决定）。

## ADDED Requirements

### Requirement: 方案数据模型

方案 MUST 存储为 `appdata.json` 顶层 `readerModePresets`（List of {id, name, values}）；`values` MUST 只包含 design D2 键集合（18 个模式/布局/手势键）的键值对；MUST NOT 包含亮度、缩略图、E-Ink、自动阅读、预加载等非组合键。

#### Scenario: 快照新建

- **WHEN** 用户在方案管理页输入名称「日漫双页」并确认新建
- **THEN** 存储中新增一条记录，values 为当前生效层 D2 键集合的快照；模式键快照为求值后的生效模式且 `autoReaderMode=false`

### Requirement: 方案 CRUD 与名称校验

管理器 MUST 支持：从当前设置快照新建、重命名、更新为当前值（重新快照）、删除（删除不回写任何已应用的设置）。名称 trim 后非空、≤30 字符、同库不重名（大小写不敏感）；违反 MUST 拒绝并给出已有名称提示。

#### Scenario: 重名拒绝

- **WHEN** 用户把某方案重命名为已存在的「日漫双页」
- **THEN** 操作被拒绝，界面提示名称已被使用，原名保持不变

### Requirement: 应用方案

`apply` MUST 逐键把方案值写入调用方指定的作用域：设置页内 = 作用域选择器当前层；阅读器内 = 此漫画层。模式键 MUST 复用既有模式切换通道（comic 层写 `readerModeOverride`，其他层写对应模式键，含 `autoReaderMode` 走既有 resolve 语义）。方案中缺失的键 MUST NOT 改动当前值。

#### Scenario: 应用到漫画层

- **WHEN** 用户在阅读器快捷设置面板选择方案「条漫」
- **THEN** 方案内 18 键写入此漫画作用域，模式键经 `readerModeOverride` 生效；方案外的设置（如亮度）不变

#### Scenario: 应用到全局层

- **WHEN** 用户在设置页（作用域选择器为「默认」）应用同一方案
- **THEN** 方案值写入 global 顶层键，模式键含 `autoReaderMode=false` 与确定模式，apply 后不随布局检测改写

### Requirement: 设置页入口

设置「阅读」分类 MUST 提供「阅读模式方案」组：当前方案下拉（应用到当前作用域层）+ 管理页入口；管理页 MUST 提供列表与新建/重命名/更新/删除操作。

#### Scenario: 入口可达

- **WHEN** 用户打开 设置 → 阅读
- **THEN** 在「阅读模式」组之后看到「阅读模式方案」组，可进入管理页完成全部 CRUD

### Requirement: 面板方案切换

阅读器快捷设置面板 MUST 提供「方案」下拉项（位于阅读模式项之后），选择即应用到此漫画作用域；面板其余项与作用域标识语义不变。

#### Scenario: 面板切换

- **WHEN** 用户在阅读中打开快捷设置面板并选择方案「页漫」
- **THEN** 当前漫画的设置立即按方案变更，面板显示作用域标识不变（此漫画）
