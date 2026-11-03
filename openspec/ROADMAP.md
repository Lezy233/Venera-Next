# Venera-Next UI/UX 改造路线图

> 分工：codex「architect」（规划，pane w4:p1）→ codex「executor」（执行/debug，pane w4:p2）→ owner（人工验收 → archive）
> 规则见 `openspec/config.yaml` 的 context 与 operations。已完成的 quick wins 见 `doc/ui-audit-2026-10-20.md`。
> 设计方向（2026-10-20 锁定，同日修订）：现代极简——浅色内容区 + 浅色壳，动态取色为唯一强调色来源；阅读器跟随主题不设例外；深色内容区主题为二期。详见 design-system-foundation。

## 执行顺序（依赖关系）

功能愿望与新功能规划见 `openspec/BACKLOG.md`（愿景 + 候选清单 + 批次建议）。

2026-11-01 owner反馈的依赖/验收条件见BACKLOG「Owner反馈TODO」。当前F6/F7、B3/B4均已验收归档；owner已安排F8 → F9，其他候选未开启。

2026-11-02 owner实际搜索未得到结果，已批准废止B2详情跨平台入口及原F7专用作者聚合链路。`search-profiles-author` 最终设计：F6搜索方案保留，F7改为收藏右栏单选创作者的平台名称树，可维护同源多名称并点击普通单源搜索。2026-11-03实现与自动化独立复核完成：113项测试全通过、0skip，analyze50=38+12零新增；F6/F7 GUI证据已重留并独立抽查通过，正常生产构建已恢复，owner于2026-11-03验收通过，已归档（实现commit c5429bb）。B3/B4已于2026-11-03由owner安排，四件套已建并校验，顺序执行；F8–F11尚未启动。

| # | Change | 内容 | 前置依赖 |
|---|--------|------|----------|
| 1 | **design-system-foundation** | 设计方向确认 + design-spec.md + token/断点系统 + 壳层规范 | 无（最先做；方向任务 1.1 需 owner 确认） |
| 2 | **settings-ia-cleanup** ✅已归档 | WebDAV 三合一（P0）/ 阅读设置作用域选择器（P1）/ 分类调整（P1） | 与 #1 可并行；断点迁移受 #1 影响处需对齐 |
| 3 | **desktop-shell-polish** ✅已归档 | 宽屏设置就地编辑（P2） | #1（断点）、#2（WebDAV 入口对齐） |
| 4 | **desktop-search-context** ✅已归档 | 命令中心三上下文行为统一（P1-6） | #1（命令中心可见性规则） |
| 5 | **reader-quick-settings-panel** ✅已归档 | 阅读内精简设置面板（P0-1 遗留） | #2 的作用域选择器（降级路径见 design.md D3） |
| 6 | **keyboard-shortcuts**（BACKLOG F3，批次 A）✅已归档 | 动作注册表 + 多键位自定义 + 冲突检测 + 独立主分类 + 平台默认键（2026-10-23 归档，commit b735663） | 无强依赖（注册表为 F1 多栈预留扩展，见 design D8） |
| 7 | **reader-mode-presets**（BACKLOG F4，批次 A）✅已归档 | 阅读模式方案 CRUD：命名快照/应用/管理 + 面板方案切换（2026-10-23 归档，commit 1c8fbc3） | settings-ia-cleanup 作用域选择器（已归档）；quick-settings 面板 |
| 8 | **favorite-series**（BACKLOG F5，批次 C）✅已归档 | 跨来源手动系列 + 收藏文件夹右键操作 + 顶部多选入口 + Escape 退出 + 批量加入系列（2026-10-25 归档，commit ce5be2a） | settings-ia-cleanup（已归档） |
| 9 | **search-profiles-author**（BACKLOG F6+F7，批次 C）✅已归档 | 搜索方案CRUD/来源排序及选项 + 收藏单选创作者平台名称树/手动维护/普通单源搜索（2026-11-03 owner验收，实现commit c5429bb，替代旧B2） | 既有搜索及收藏作者alias基础；F8前置已满足 |
| 10 | **reader-preset-state-recovery**（B3）✅已归档 | 持续编辑共享19键、跟随默认保持绑定并动态继承；285+174测试0skip、analyze50零新增，GUI/重启/正常构建通过 | 2026-11-03 owner验收通过，实现526c311；归档review.md含证据 |
| 11 | **comic-card-hit-target-fix**（B4）✅已归档 | 标题首行/封面命中、窄brief紧凑徽章；owner验收通过，实现6f65f7f，174测试/50基线及GUI通过 | 无B3技术依赖；2026-11-03单独归档，B3返工保留 |
| 12 | **search-target-memory**（F8）已派工 | 记忆聚合/单源及所选方案身份，失效可见回退、可靠保存 | F6/F7、B3/B4均已验收归档 |
| 13 | **reader-preset-ordering**（F9）工件已建，排队 | 拖动和上/下移，跨入口一致顺序、身份/绑定不变 | B3已完成；等F8验收后另会话派工 |

下一排期（owner已授权）：**F8搜索目标记忆 → F9阅读方案手动排序**，按change逐个执行、复核和验收。B3/B4均已归档；B5、F11、F10及F1 → F2保留候选，统一视觉美化后置。

## 已完成（quick wins，不在 changes 中）

- 设置页双栏默认着陆（settings_page.dart）
- Reading 页 7 组分组标题（reader.dart）
- 搜索框上下文提示语（desktop_top_bar.dart）

## 验收后归档

每个 change 由 owner 验收后运行 `openspec archive <name>`，delta spec 合并进 `openspec/specs/`。
归档前执行 agent 必须完成：flutter analyze 基线50项零新增、tasks.md 全部勾选、新增词条已补 zh_CN/zh_TW。

2026-11-03 owner人工验收：B4通过，未发归档推送指令；B3不通过，要求选中的方案成为持续编辑目标。planner已修订B3四件套，保留19键范围并明确同ID共享、None退出保留效果、旧引用迁移及失败恢复；交executor执行3.x/4.x后再次独立复核。B4实现与工件作为保护基线，不混入返工。

2026-11-03 owner明确「先归档推送B4，B3继续完成」：B4实现6f65f7f，归档2026-11-03-comic-card-hit-target-fix；B3保持活动change，未提交返工实现、未归档，待剩余窄回归/GUI与跟随默认语义完成后另行验收。

2026-11-03 owner裁定B3跟随默认：保持方案绑定并保存共享继承行为，按各目标上层模式策略动态求值；planner补充D2.4/spec/tasks3.5。既有窄35测试、已定GUI/真实重启及正常构建完成，待继承分支实现后最终回归及独立复核。

2026-11-03 owner最终验收B3通过并授权归档推送；实现526c311，归档2026-11-03-reader-preset-state-recovery。历史未完成记录以上述最终状态为准；接续F8 → F9。
