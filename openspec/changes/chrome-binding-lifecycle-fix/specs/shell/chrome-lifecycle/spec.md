# Spec Delta

## Purpose

桌面壳控制器的生命周期协调能力：动作绑定与状态通知不在构建期执行，壳层在任何重建时序下都不触发 Flutter 框架错误，且全局动作注册语义不变。

## ADDED Requirements

### Requirement: 构建期无通知

桌面壳的控制器 MUST NOT 在 Widget 构建阶段（build / didChangeDependencies 同步路径）触发任何会导致 markNeedsBuild 的通知；动作绑定 MUST 在帧后回调中完成（带 mounted 与已绑定守卫）。

#### Scenario: 应用启动

- **WHEN** 应用启动完成首帧渲染
- **THEN** 启动日志不出现 setState/markNeedsBuild-during-build 错误，全局动作在首帧后完成注册

#### Scenario: 依赖重建

- **WHEN** 上层依赖变化导致 main page 重建并再次进入 didChangeDependencies
- **THEN** 不产生重复绑定，也不触发构建期错误

### Requirement: 动作语义不变

修复 MUST NOT 改变全局动作的注册内容与触发行为（章节、搜索等快捷键及命令中心动作在阅读器内外均保持现状）。

#### Scenario: 快捷键工作

- **WHEN** 用户在启动后使用全局快捷键（如阅读器内打开章节列表）
- **THEN** 行为与修复前一致
