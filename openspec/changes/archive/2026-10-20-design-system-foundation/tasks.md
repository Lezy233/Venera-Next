# Tasks

## 1. 方向确认与文档

- [x] 1.1 设计方向已锁定：现代极简（浅色内容区 + 浅色壳，阅读器跟随主题不设例外；owner 2026-10-20 确认并修订）；执行 agent 按 design.md D1 执行
- [x] 1.2 按 design.md D3 结构编写 `design-spec.md` 初版（方向与意象/Token/断点/容器/图标/语言/Surface 规则/例外清单）

## 2. Token 与断点系统

- [x] 2.1 新建 `lib/design_system/tokens.dart`：间距尺度（4px 基底）、圆角、动效时长、阴影、容器色角色（引用 colorScheme）
- [x] 2.2 新建 `lib/design_system/breakpoints.dart`：compact <720 / medium <1200 / expanded ≥1200 三档常量与判断辅助
- [x] 2.3 `consts.dart` 的 `changePoint/changePoint2` 标记 `@Deprecated` 并转发到新断点
- [x] 2.4 迁移散落阈值：`settings_page.dart` 的 720、`desktop_top_bar.dart` 的 900 改引新常量

## 3. 壳层规范落地（浅色极简重皮）

- [x] 3.1 顶栏侧栏开关：非可用页面改为禁用态 + tooltip 说明（替代 `SizedBox.shrink` 消失）
- [x] 3.2 设置分类选中态移除尾随 `arrow_right` 图标（桌面端）
- [x] 3.3 `window_frame.dart` 与 `desktop_top_bar.dart` 着色逻辑重写为浅色极简（token 取色，移除深色 VSCode 式硬编码；窗口控件/win32 原生按钮色随主题）
- [x] 3.4 命令中心搜索框样式对齐浅色规范（填充色/描边/提示色引自 token）
- [x] 3.5 核对标题栏与顶栏的视觉参数（高度/间距）并登记到 design-spec.md 的壳层章节

## 4. 例外清单与验证

- [x] 4.1 扫描全 lib 的明显散落硬编码（宽高/字号字面量），能迁移的迁移，不能迁移的登记例外清单
- [x] 4.2 `flutter analyze` 无新增告警
- [x] 4.3 三档宽度（600/1000/1400）手动走查：导航形态、设置双栏、命令中心可见性与 design-spec.md 一致

## 5. 验收缺陷修复（owner 走查 2026-10-20 发现）

- [x] 5.1 缺陷：从「收藏」切到「主页」或「发现」时，顶栏侧栏开关保持可用态（亮色、可点击、点击无反应）；切到「分类」则正常变灰。预期：所有非收藏上下文（其他标签页、以及从收藏 push 上去的详情页等）均应为禁用态 + tooltip。状态流：`favoritesActive` 仅由 `favorites_page.dart`（didChangeDependencies/dispose）维护，顶栏 `desktop_top_bar.dart` 读取；疑似 `_NaviMainView` 的 `AnimatedSwitcher`（navigation_bar.dart:753）出栈子树生命周期导致 `dispose` 未触发或状态被重新置真——需运行时验证（已排除假设：`AutomaticKeepAliveClientMixin`，分类/发现均有该 mixin 但表现不同）
- [x] 5.2 回归验证：收藏→主页/发现/分类三个方向的切换，侧栏开关均立即变灰且 tooltip 正确；收藏页内及其 push 的详情页上行为符合 spec（详情页属非收藏上下文，应为禁用态）
- [x] 5.3 `flutter analyze` 无新增告警
