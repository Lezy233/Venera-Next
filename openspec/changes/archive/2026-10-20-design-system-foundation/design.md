# Design

## Context

见 proposal.md。现状要点：M3 动态取色在 `main.dart` 的 `getTheme`（FlexTones.vividBackground）；断点散落在 `consts.dart`（600/1300）、`settings_page.dart`（720）、`desktop_top_bar.dart`（900）；壳层组件在 `app_shell/` 与 `components/navigation_bar.dart`、`window_frame.dart`；项目无 design-spec.md，token 无成文定义。

## Goals / Non-Goals

**Goals:**

- 一份可执行的 design-spec.md + 一套代码级 token/断点常量
- 执行 agent 新增 UI 时有章可循，review 有客观依据

**Non-Goals:**

- 内容区各页面（发现/收藏/详情等）的全面视觉迁移不在本次——由后续 change 依据 design-spec.md 逐步进行；本次仅做壳层浅色重皮
- 不引入设计工具链（Figma 等）依赖
- 深色内容区主题（二期变体）不做，仅在设计契约中预留规则
- 不决定移动端专属视觉（移动端跟随 token，暂不单独设计）

## Decisions

### D1: 设计方向 = 现代极简（owner 已于 2026-10-20 确认）

- 内容区与壳层统一为**浅色现代极简**（Linear/Vercel/Notion 气质）：浅中性底、排版主导、层级靠字重与留白、锐利网格、克制强调色。动态取色保留但降级为"唯一强调色来源"（按钮/选中态/进度）。
- **阅读器不设主题例外**：阅读器 chrome 跟随应用当前主题，与全 App 一致（2026-10-20 owner 修订，取消原沉浸深色例外）。
- 深色内容区主题作为二期变体（先浅色打磨到位；阅读器深色不受影响）。
- 壳层已有的效率型功能模式（命令中心、快捷键、双栏设置、就地编辑）全部保留，仅视觉从深色 VSCode 式改为浅色极简。
- 备选（已否）：Material 3 + tech-editor 深色壳混合——owner 判断漫画阅读软件与 VSCode 组件调性不搭；全量 tech-cyberpunk——与极简目标冲突。
- 成本提示：壳层深色着色逻辑重写（`window_frame`/`desktop_top_bar`）落在本 change 任务组 3，内容区各页面视觉迁移由后续 change 依据 design-spec.md 逐步进行。

### D2: token 落位 = `lib/design_system/` 新目录

- 新建 `lib/design_system/tokens.dart`（颜色角色引用 colorScheme、间距尺度、圆角、动效时长、阴影）与 `lib/design_system/breakpoints.dart`（紧凑 <720 / 中等 720–1199 / 展开 ≥1200，即 compact/medium/expanded 三档，数值取 M3 窗口类断点）。
- 备选：塞进 `foundation/consts.dart`——该文件是历史杂物间，新建目录建立边界，便于未来扩展（design_system 下可加 component 规范类）。
- 迁移：`consts.dart` 的 `changePoint/changePoint2` 标记 deprecated 并转发到新断点；`settings_page.dart` 的 720、`desktop_top_bar.dart` 的 900 改为引用新常量。

### D3: design-spec.md 结构

- 章节：方向与意象 / Token 表（与 `tokens.dart` 一一对应）/ 断点 / 容器策略 / 图标系统 / 语言规范 / Surface 规则（settings、list-detail、reader、shell）/ 例外清单。
- 与 oiloil-ui-ux-guide 技能的 design-spec 模板对齐，后续设计走查以它为基准。

## Risks / Trade-offs

- [三档断点与旧两档切换点不完全重合，个别界面布局切换位置移动] → 在 design-spec.md 中明确记录新旧对照；迁移时逐个核对调用点
- [design-spec.md 与代码漂移] → spec-doc 能力要求例外登记与"先更新契约再实现"；每次 UI change 的 archive 步骤核对契约
- [执行 agent 绕过 token 继续硬编码] → tasks 中安排一次性扫描（找散落的 SizedBox 宽高/字面量），review 清单加入 token 检查项

## Migration Plan

1. 建 `lib/design_system/`（tokens + breakpoints）+ design-spec.md 初版
2. 迁移 consts.dart 与两个散落阈值，标记 deprecated
3. 壳层小修：侧栏开关禁用态、移除设置分类尾随箭头
4. `flutter analyze` + 三档宽度手动走查（600/1000/1400）
5. 回滚：均为增量改动，可整体 revert

## Open Questions

- 展开断点取 1200 还是沿用 1300（旧 changePoint2）？倾向 1200 对齐 M3，迁移时验证设置双栏在 1000–1300 区间的观感后定稿
