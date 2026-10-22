# Venera-Next UI/UX 改造路线图

> 分工：Kimi（规划）→ dsh / deepseek-v4.1f（执行/debug）→ owner（人工验收 → archive）
> 规则见 `openspec/config.yaml` 的 context 与 operations。已完成的 quick wins 见 `doc/ui-audit-2026-10-20.md`。
> 设计方向（2026-10-20 锁定，同日修订）：现代极简——浅色内容区 + 浅色壳，动态取色为唯一强调色来源；阅读器跟随主题不设例外；深色内容区主题为二期。详见 design-system-foundation。

## 执行顺序（依赖关系）

功能愿望与新功能规划见 `openspec/BACKLOG.md`（愿景 + 候选清单 + 批次建议）。

| # | Change | 内容 | 前置依赖 |
|---|--------|------|----------|
| 1 | **design-system-foundation** | 设计方向确认 + design-spec.md + token/断点系统 + 壳层规范 | 无（最先做；方向任务 1.1 需 owner 确认） |
| 2 | **settings-ia-cleanup** ✅已归档 | WebDAV 三合一（P0）/ 阅读设置作用域选择器（P1）/ 分类调整（P1） | 与 #1 可并行；断点迁移受 #1 影响处需对齐 |
| 3 | **desktop-shell-polish** ✅已归档 | 宽屏设置就地编辑（P2） | #1（断点）、#2（WebDAV 入口对齐） |
| 4 | **desktop-search-context** ✅已归档 | 命令中心三上下文行为统一（P1-6） | #1（命令中心可见性规则） |
| 5 | **reader-quick-settings-panel** ✅已归档 | 阅读内精简设置面板（P0-1 遗留） | #2 的作用域选择器（降级路径见 design.md D3） |
| 6 | **keyboard-shortcuts**（BACKLOG F3，批次 A） | 动作注册表 + 用户自定义键位 + 冲突检测 + 快捷键设置页 | 无强依赖（注册表为 F1 多栈预留扩展，见 design D8） |

## 已完成（quick wins，不在 changes 中）

- 设置页双栏默认着陆（settings_page.dart）
- Reading 页 7 组分组标题（reader.dart）
- 搜索框上下文提示语（desktop_top_bar.dart）

## 验收后归档

每个 change 由 owner 验收后运行 `openspec archive <name>`，delta spec 合并进 `openspec/specs/`。
归档前执行 agent 必须完成：flutter analyze 干净、tasks.md 全部勾选、新增词条已补 zh_CN/zh_TW。
