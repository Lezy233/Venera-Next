# Tasks

## 1. 方向确认与文档

- [ ] 1.1 设计方向已锁定：现代极简（浅色内容区 + 浅色壳 + 阅读器沉浸深色例外，owner 2026-10-20 确认）；执行 agent 无需再确认，按 design.md D1 执行
- [ ] 1.2 按 design.md D3 结构编写 `design-spec.md` 初版（方向与意象/Token/断点/容器/图标/语言/Surface 规则/例外清单）

## 2. Token 与断点系统

- [ ] 2.1 新建 `lib/design_system/tokens.dart`：间距尺度（4px 基底）、圆角、动效时长、阴影、容器色角色（引用 colorScheme）
- [ ] 2.2 新建 `lib/design_system/breakpoints.dart`：compact <720 / medium <1200 / expanded ≥1200 三档常量与判断辅助
- [ ] 2.3 `consts.dart` 的 `changePoint/changePoint2` 标记 `@Deprecated` 并转发到新断点
- [ ] 2.4 迁移散落阈值：`settings_page.dart` 的 720、`desktop_top_bar.dart` 的 900 改引新常量

## 3. 壳层规范落地（浅色极简重皮）

- [ ] 3.1 顶栏侧栏开关：非可用页面改为禁用态 + tooltip 说明（替代 `SizedBox.shrink` 消失）
- [ ] 3.2 设置分类选中态移除尾随 `arrow_right` 图标（桌面端）
- [ ] 3.3 `window_frame.dart` 与 `desktop_top_bar.dart` 着色逻辑重写为浅色极简（token 取色，移除深色 VSCode 式硬编码；窗口控件/win32 原生按钮色随主题）
- [ ] 3.4 命令中心搜索框样式对齐浅色规范（填充色/描边/提示色引自 token）
- [ ] 3.5 核对标题栏与顶栏的视觉参数（高度/间距）并登记到 design-spec.md 的壳层章节

## 4. 例外清单与验证

- [ ] 4.1 扫描全 lib 的明显散落硬编码（宽高/字号字面量），能迁移的迁移，不能迁移的登记例外清单
- [ ] 4.2 `flutter analyze` 无新增告警
- [ ] 4.3 三档宽度（600/1000/1400）手动走查：导航形态、设置双栏、命令中心可见性与 design-spec.md 一致
