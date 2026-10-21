# settings/inplace-editing Specification

## Purpose
设置的就地编辑能力：宽屏双栏下设置子页（代理、DNS、关键词屏蔽等）在右栏内容区就地展开，窄屏回退弹窗，编辑行为与所在布局一致。

## Requirements

### Requirement: 宽屏就地编辑

窗口处于双栏模式时，点击 `PopupWindowSetting` 类入口 MUST 在右栏内容区就地展开编辑界面，MUST NOT 弹居中弹窗覆盖。

#### Scenario: 宽屏编辑代理

- **WHEN** 用户在双栏设置页点击"代理"
- **THEN** 代理表单在右栏展开，带返回按钮回到分类列表视图

#### Scenario: 窄屏回退

- **WHEN** 窗口处于单栏模式
- **THEN** 行为与现状一致（弹窗），不引入就地展开

### Requirement: 状态与保存反馈

就地展开的编辑界面 MUST 显示与弹窗版相同的保存状态与校验反馈。

#### Scenario: 校验失败

- **WHEN** 代理端口输入非法
- **THEN** 右栏内联显示校验错误，与弹窗版文案一致
