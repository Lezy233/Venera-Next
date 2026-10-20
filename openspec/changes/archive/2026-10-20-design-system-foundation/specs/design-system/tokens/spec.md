# Spec Delta

## Purpose

设计 token 与断点系统：项目唯一的视觉与布局常量来源，所有界面的颜色、字体、圆角、间距、阴影、动效与响应式断点取值必须来自本系统，杜绝散落硬编码。

## ADDED Requirements

### Requirement: 单一 token 来源

所有界面代码 MUST 从设计 token 系统读取颜色、字体、圆角、间距、阴影与动效时长，MUST NOT 引入新的散落硬编码值；个别确有理由的偏离 MUST 在代码注释中说明并记入 design-spec.md 的例外清单。

#### Scenario: 新增页面

- **WHEN** 任何执行 agent 新增一个页面或组件
- **THEN** 其中的间距、圆角、字号取值全部来自 token 常量，flutter analyze 无新增告警

#### Scenario: 审查例外

- **WHEN** 维护者审查 diff 时发现未走 token 的字面量
- **THEN** 能在一处文档（design-spec.md 例外清单）查到该偏离是否已被记录

### Requirement: 统一断点系统

响应式布局切换 MUST 只使用断点系统定义的常量（紧凑 / 中等 / 展开三档），MUST NOT 出现 720、900 等散落的自定义阈值。

#### Scenario: 设置页与导航栏一致

- **WHEN** 窗口宽度变化触发布局切换
- **THEN** 设置双栏、导航栏形态、命令中心可见性在相同宽度处切换

### Requirement: 间距尺度

界面间距 MUST 使用 4px 基底的间距尺度（4/8/12/16/24/32），off-scale 值必须有记录的理由。

#### Scenario: 审查新 UI

- **WHEN** 审查任何新界面
- **THEN** 所有 padding/margin/gap 均为尺度上的值或例外清单成员
