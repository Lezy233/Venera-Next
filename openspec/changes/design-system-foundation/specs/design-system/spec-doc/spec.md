# Spec Delta

## Purpose

设计契约文档的维护规则：design-spec.md 是全项目设计的唯一契约，其更新时机与约束保证契约为活文档而非一次性产出。

## ADDED Requirements

### Requirement: 契约为唯一依据

任何 UI 相关 change 的 proposal/design MUST 引用 design-spec.md 的相关章节；与契约冲突的实现 MUST 先更新契约再实现。

#### Scenario: 新 surface

- **WHEN** 规划一个之前没有设计规则的新界面类型
- **THEN** 先为 design-spec.md 增补该 surface 的规则章节，再进入实现任务

### Requirement: 例外登记

代码中偏离契约的个案 MUST 同步登记到 design-spec.md 的例外清单（位置、原因、登记日期）。

#### Scenario: 审查例外

- **WHEN** 维护者在代码中发现偏离
- **THEN** 例外清单中能找到对应条目，否则视为违规
