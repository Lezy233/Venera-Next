# Tasks

> 硬规则：design-spec.md、openspec/specs/**、pubspec.yaml/lock 禁改；pubspec.lock 不得重新生成；analyze 基线 50 项不得新增；截图只留 `/tmp`；工作区必须干净；architect 批准前不得提交。

## 1. 搜索方案基础

- [ ] 1.1 定义 search profile 模型、JSON 编解码、名称校验和 appdata 持久化迁移。
- [ ] 1.2 实现方案 CRUD、默认选择、来源卸载/未知来源清理和现有设置兼容。
- [ ] 1.3 为聚合搜索和结果分页传递 profile 的逐源有效 options。

## 2. 作者跨源搜索

- [ ] 2.1 定义来源作者查询能力与转换接口，补齐能力声明及 unsupported 结果模型。
- [ ] 2.2 从标准作者 tag/详情作者入口创建 AuthorSearchIntent，并按方案来源执行聚合作者搜索。
- [ ] 2.3 在结果页展示来源跳过/失败状态，不改变现有单源 tag 跳转和快捷方式。

## 3. 设置与验证

- [ ] 3.1 在 Explore 设置和聚合搜索页加入方案管理/选择 UI，遵循 design-spec。
- [ ] 3.2 新增 `.tl` 文案并补 `zh_CN`/`zh_TW`。
- [ ] 3.3 添加模型、持久化、分页、source schema 变化、作者转换和 unsupported 状态测试。
- [ ] 3.4 运行相关测试与 `fvm flutter analyze --no-pub`，确认基线 50 项无新增。
- [ ] 3.5 用 `DISPLAY=:1` 隔离数据目录走查方案切换和作者入口；截图仅存 `/tmp`。
