# settings/navigation Specification

## Purpose
设置区的信息架构组织能力：分类归属与用户心智模型一致，非设置内容不占主导航格子，降低查找设置时的认知负荷。

## Requirements

### Requirement: 分类归属一致

App 级行为偏好 MUST 归入 APP 分类；分类内的条目归属 MUST 与用户的心智模型一致（用户找"启动时打开哪个页面"应去 APP 分类，而不是浏览分类）。**例外（owner 2026-10-22 裁决）**：「快捷键」MUST 为独立主分类，不归入 APP 分类——键位体系是 PC 效率核心功能，入口需要直接可达。

#### Scenario: 查找启动页设置

- **WHEN** 用户想在设置中修改"启动时打开的页面"
- **THEN** 该设置项 MUST 位于 APP 分类下

#### Scenario: 查找键位设置

- **WHEN** 用户想在设置中修改快捷键
- **THEN** 「快捷键」MUST 作为独立分类直接出现在设置主分类列表中

#### Scenario: 浏览分类内容

- **WHEN** 用户打开"浏览"分类
- **THEN** 其中 MUST NOT 出现与浏览行为无关的 App 级设置（如章节排序、初始页面）

### Requirement: 非设置内容不占主导航

统计页面 MUST NOT 作为设置分类占据主导航格子；Debug 工具 MUST NOT 对普通用户直接可见。

#### Scenario: 普通用户视角

- **WHEN** 普通用户打开设置
- **THEN** 主导航 MUST NOT 出现 Debug 分类；阅读统计 MUST NOT 出现在设置分类列表中

#### Scenario: 访问调试工具

- **WHEN** 用户需要访问 Debug 工具
- **THEN** MUST 通过 About 分类下的"高级"入口（或等价显式入口）到达
