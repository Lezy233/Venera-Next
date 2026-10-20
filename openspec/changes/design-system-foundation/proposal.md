# Proposal

## Why

项目已决定与原上游脱钩独立发展（见 openspec/config.yaml context），UI/UX 统一成为长期需求。当前状态：Material 3 + 动态取色贯穿全 App，PC 外壳（顶栏/侧栏/窗口框架）是 fork 后新加的深色 tech-editor 风格半成品，两者尚未形成一份成文的设计契约。没有这份契约，每个执行 agent 都会各自发挥，统一性无从保证，未来功能扩展（新页面/新组件）也没有落地依据。2026-10-20 审计（doc/ui-audit-2026-10-20.md）的 P2 项（断点散落、弹窗不就地、装饰不统一）都是缺少这份契约的症状。

## What Changes

- 确定并记录设计方向：**现代极简（modern-minimal）**——内容区与壳层统一为浅色极简语言，动态取色从"全界面染色"降级为"唯一强调色来源"；阅读器本体作为沉浸深色例外（2026-10-20 由 owner 确认，见 design.md D1）
- 产出 `design-spec.md`（项目根目录）：token（颜色/字体/圆角/间距/阴影/动效）、断点、容器策略、图标系统、语言规范、各 surface（settings/dashboard/list-detail/reader）的 do/don't
- 落地第一批基础设施：统一断点常量与用法、浅色壳层重皮（顶栏/窗口框架从深色 VSCode 式改为浅色极简）、间距尺度约定
- **BREAKING（对内）**：`lib/foundation/consts.dart` 的断点常量被新的统一断点系统取代，所有 `changePoint/changePoint2/720/900` 散落用法迁移

## Capabilities

### New Capabilities

- `design-system/tokens`: 设计 token 与断点系统——项目唯一的视觉/布局常量来源，所有界面取值必须来自 token
- `design-system/desktop-shell`: 桌面外壳规范——窗口框架、顶栏、命令中心、侧栏的布局/密度/交互规则，浅色极简语言在壳层的唯一定义来源
- `design-system/spec-doc`: 设计契约文档的维护规则——design-spec.md 的更新时机与约束，保证契约为活文档

### Modified Capabilities

（无）

## Impact

- 新增：`design-spec.md`、设计 token 定义文件（位置见 design.md）、断点系统
- 修改：`lib/foundation/consts.dart`（断点）、`lib/components/navigation_bar.dart`、`lib/app_shell/desktop_top_bar.dart`、`lib/components/window_frame.dart`（迁至 token）、`settings_page.dart`（720 阈值）
- 无数据迁移；对用户可见变化为断点行为统一后个别界面在窄窗口下布局切换位置变化
