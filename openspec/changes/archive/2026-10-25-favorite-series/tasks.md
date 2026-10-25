# Tasks

> 硬规则：design-spec.md、openspec/specs/**、pubspec.yaml/lock 禁改；pubspec.lock 不得重新生成；analyze 基线 50 项不得新增；截图只留 `/tmp`；工作区必须干净；architect 批准前不得提交。

## 1. 数据层

- [x] 1.1 设计并实现固定系列表、旧库 schema 升级和回滚安全路径。备注：initializeMetadata 在事务中创建固定表，旧库自动升级，事务异常回滚。
- [x] 1.2 扩展 FavoritesRepository：系列 CRUD、排序、成员查询与事务变更。备注：已加入 CRUD、排序、成员幂等写入/删除、跨来源读取和计数。
- [x] 1.3 扩展 FavoritesManager：通知、缓存刷新、孤儿成员清理及旧导入兼容。备注：系列变更统一通知，删除收藏/文件夹时清理孤儿成员，旧收藏导入继续复用现有路径。

## 2. 收藏 UI

- [x] 2.1 侧栏与选择状态增加系列入口，保持文件夹选择兼容。备注：侧栏系列分组与独立选择状态已接入，文件夹选择路径保留。
- [x] 2.2 实现系列内容视图，保留跨来源成员，不复用 All 去重结果。备注：LocalFavoriteSeriesPage 直接按 (id,type) 成员读取，跨来源同名身份不合并。
- [x] 2.3 实现系列管理和加入/移出系列操作，遵循 design-spec token/断点。备注：侧栏支持创建/重命名/删除/排序，系列页支持加入和移除。
- [x] 2.4 新增 `.tl` 文案并补 `zh_CN`/`zh_TW`。备注：系列入口、管理、成员操作及空态文案已加入双语 translation.json，代码均使用 .tl。
- [x] 2.5 补齐本地文件夹 secondary-click 操作菜单，覆盖重命名、排序/导出和删除等可发现的文件夹操作。备注：FavoritesFolderSidebar 行接入 secondary-click context menu，提供 Rename/Reorder/Export/Delete Folder，并保留左键选择。
- [x] 2.6 在内容页顶部「更多」加入显式多选入口；多选状态用 `Escape` 清空并退出，且不触发窗口级返回。备注：本地内容页（含 All）顶部更多菜单加入 Select comics；Focus 键盘守卫消费活动多选状态的 Escape，清空并退出，保留关闭按钮。
- [x] 2.7 在多选操作菜单加入批量「加入系列」流程，包含无系列提示、数量反馈和双语文案。备注：多选菜单加入 Add to series，支持选择/创建系列、过滤仍有效身份、一次性写入并反馈数量，文案已补 zh_CN/zh_TW。

## 3. 验证

- [x] 3.1 添加 repository/manager/schema/UI 状态测试，覆盖幂等、回滚、孤儿清理和旧库兼容。备注：favorite_series_test.dart 5 项通过，覆盖 schema、Repository、Manager 通知/CRUD、幂等、回滚、跨来源和孤儿清理；系列页面已完成编译级 UI 状态接入。
- [x] 3.2 运行相关测试与 `fvm flutter analyze --no-pub`，确认基线 50 项无新增。备注：系列+Repository+Manager 回归 91 项全绿；analyze 50 项，保持 38 tool/code_audit + 12 lib/test 基线。
- [ ] 3.3 用 `DISPLAY=:1` 隔离数据目录走查桌面/compact 系列入口；截图仅存 `/tmp`。备注：本轮以 `GDK_BACKEND=x11` + 隔离 XDG 目录启动，窗口可见并通过 `xwininfo` 定位；桌面启动截图 `/tmp/favorite-series-gui-20261025e/desktop.png`。但当前会话无窗口管理器客户端列表，XTest 鼠标/键盘事件无法驱动导航，无法完成收藏系列入口、创建/选择/空态及 compact 交互；保持未勾选。日志 `/tmp/favorite-series-gui-20261025e.log`。
- [ ] 3.4 添加并运行多选入口、Escape 退出、批量加入系列和文件夹右键菜单的行为测试；复跑相关回归与 analyze，截图仍只存 `/tmp`。备注：已保留稳定的 Manager 批量加入/幂等测试与 Escape 守卫单元测试，相关 favorites 回归 93 项全绿、analyze 50；真实 widget secondary-click/菜单导航 harness 不稳定已删除，GUI 仍无可交互证据，故不勾选。
