# Tasks

> 硬规则：design-spec.md、openspec/specs/**、pubspec.yaml/lock 禁改；pubspec.lock 不得重新生成；analyze 基线 50 项不得新增；截图只留 `/tmp`；工作区必须干净；architect 批准前不得提交。

## 1. 数据层

- [ ] 1.1 设计并实现固定系列表、旧库 schema 升级和回滚安全路径。
- [ ] 1.2 扩展 FavoritesRepository：系列 CRUD、排序、成员查询与事务变更。
- [ ] 1.3 扩展 FavoritesManager：通知、缓存刷新、孤儿成员清理及旧导入兼容。

## 2. 收藏 UI

- [ ] 2.1 侧栏与选择状态增加系列入口，保持文件夹选择兼容。
- [ ] 2.2 实现系列内容视图，保留跨来源成员，不复用 All 去重结果。
- [ ] 2.3 实现系列管理和加入/移出系列操作，遵循 design-spec token/断点。
- [ ] 2.4 新增 `.tl` 文案并补 `zh_CN`/`zh_TW`。

## 3. 验证

- [ ] 3.1 添加 repository/manager/schema/UI 状态测试，覆盖幂等、回滚、孤儿清理和旧库兼容。
- [ ] 3.2 运行相关测试与 `fvm flutter analyze --no-pub`，确认基线 50 项无新增。
- [ ] 3.3 用 `DISPLAY=:1` 隔离数据目录走查桌面/compact 系列入口；截图仅存 `/tmp`。
