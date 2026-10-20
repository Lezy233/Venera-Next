# Venera-Next 设计契约（design-spec）

- 版本：v0.1（2026-10-20）
- 状态：生效中。本文件是 Venera-Next 全部 UI 的唯一设计契约。
- 代码 token：`lib/design_system/tokens.dart`、`lib/design_system/breakpoints.dart`
- 维护规则：任何 UI 相关 change 的 proposal/design MUST 引用本文件对应章节；实现与本文件冲突时 MUST 先更新本文件再实现。代码中确有理由偏离契约的个案 MUST 登记到文末「例外清单」，否则视为违规。

## 1. 方向与意象

**现代极简（modern-minimal）**：浅色中性底、排版主导、层级靠字重与留白、锐利网格、克制的强调色。参考气质：Linear / Vercel / Notion，而不是 VSCode 的深色 tech-editor。

- 内容区与桌面壳层统一为浅色语言；外壳与内容之间只用 1px 分隔线建立层级，不靠深色底、渐变或重阴影。
- 动态取色保留，但只作为**唯一强调色来源**：按钮、选中态、进度、焦点描边。大面积底色保持中性。
- **阅读器不设主题例外**：阅读器 chrome 跟随应用当前主题（浅色/深色），与全 App 一致；「画廊 / 暗室」的反差不作为设计目标。（2026-10-20 owner 修订：取消原沉浸深色例外。）
- 深色内容区主题是二期变体；本契约只约束浅色内容区。用户切换系统深色主题时，shell 通过 colorScheme 语义角色自动适配，不新增硬编码深色。

反模式（不允许）：

- 在浅色壳层里使用纯黑/纯白硬编码、VSCode 式深色色块、彩色渐变。
- 用阴影堆叠替代分隔线；卡片套卡片。
- 每个页面自造窗口级框架、标题栏或第二套导航。
- 用装饰性图标（如选中项尾随箭头）表达状态。

## 2. Token 表

Token 是唯一取值来源。颜色优先使用 `ColorScheme` 语义角色；需要表达「壳层 / 内容 / 强调 / 危险」语义时使用 `AppColorRoles` 别名。禁止 `Color(0xFF...)`、`Colors.black` 等硬编码（阅读器深色场景除外）。

### 2.1 间距（4px 基底）

| Token | 值 | 用途 |
|---|---|---|
| `AppSpacing.xs` | 4 | 图标与文字、紧密元素 |
| `AppSpacing.sm` | 8 | 控件内边距、列表项内间距 |
| `AppSpacing.md` | 12 | 分组内间距、紧凑容器 padding |
| `AppSpacing.lg` | 16 | 页面/区块标准 padding、栏间距 |
| `AppSpacing.xl` | 24 | 区块之间、设置页边距 |
| `AppSpacing.xxl` | 32 | 页面级大区块分隔 |

Off-scale 间距必须有理由并登记例外清单。组件自身的固定尺寸（高度/栏宽）不视为间距，使用 `AppSizes`。

### 2.2 圆角

| Token | 值 | 用途 |
|---|---|---|
| `AppRadius.sm` | 4 | 小标签、密集控件 |
| `AppRadius.md` | 8 | 标准控件、列表选中态、搜索框 |
| `AppRadius.lg` | 12 | 浮层、面板 |
| `AppRadius.pill` | 999 | 胶囊/圆形控件 |

### 2.3 动效

| Token | 值 | 用途 |
|---|---|---|
| `AppMotion.fast` | 160ms | hover、选中态、快速切换 |
| `AppMotion.normal` | 200ms | 常规内容切换 |
| `AppMotion.emphasized` | 250ms | 导航形态切换、较大的布局变化 |
| `AppMotion.slow` | 350ms | 大面积过渡 |
| `AppMotion.tooltipWait` | 600ms | tooltip 延迟 |

### 2.4 阴影

| Token | 用途 |
|---|---|
| `AppShadows.floating(scheme, focused:)` | Linux 虚拟窗口外框等真正浮起的容器；颜色来自 `colorScheme.shadow` |
| 无 | 默认平面。壳层与内容之间用 1px `outlineVariant` 分隔，不用阴影 |

### 2.5 字体

| Token | 值 | 现有入口 |
|---|---|---|
| `AppFontSize.caption` | 10 | `ts.s10` |
| `AppFontSize.bodySmall` | 12 | `ts.s12` |
| `AppFontSize.body` | 14 | `ts.s14` |
| `AppFontSize.bodyLarge` | 16 | `ts.s16` |
| `AppFontSize.title` | 18 | `ts.s18` |
| `AppFontSize.titleLarge` | 20 | `ts.s20` |

字重层级：正文 regular；标题 `FontWeight.bold`（设置页、壳层标题）；辅助信息用 `colorScheme.onSurfaceVariant`，不缩小到 10px 以下。

### 2.6 透明度与颜色角色

| Token | 值 | 用途 |
|---|---|---|
| `AppOpacity.disabled` | 0.38 | 禁用态前景 |
| `AppOpacity.hover` | 0.08 | hover 叠加 |
| `AppOpacity.pressed` | 0.12 | 按下叠加 |
| `AppOpacity.selectedContainer` | 0.36 | 设置分类选中底色 |

| 角色 | 映射 | 用途 |
|---|---|---|
| `shellSurface` | `surface` | 标题栏、顶栏、导航栏底色 |
| `shellSurfaceHover` | `surfaceContainerHigh` | 壳层 hover、命令中心填充 |
| `shellBorder` | `outlineVariant` | 壳层 1px 分隔线 |
| `shellForeground` | `onSurface` | 壳层主文字/图标 |
| `shellForegroundMuted` | `onSurfaceVariant` | 壳层次要文字/图标、未选中态 |
| `disabledForeground` | `onSurface` @ 38% | 禁用态图标/文字 |
| `contentSurface` | `surface` | 内容区底色 |
| `contentSurfaceRaised` | `surfaceContainerLow` | 内容区轻量浮起容器 |
| `contentBorder` | `outlineVariant` | 内容区分隔线 |
| `accent` | `primary` | 强调色：选中、焦点、链接、主按钮 |
| `accentContainer` | `primaryContainer` | 选中底色 |
| `onAccentContainer` | `onPrimaryContainer` | 选中底色上的文字/图标 |
| `danger` | `error` | 危险操作（关闭按钮 hover、删除） |
| `onDanger` | `onError` | 危险底色上的图标 |

### 2.7 壳层组件尺寸

| Token | 值 | 说明 |
|---|---|---|
| `AppSizes.titleBarHeight` | 36 | 自定义标题栏高度 |
| `AppSizes.hairline` | 1 | 分隔线/描边宽度 |
| `AppSizes.windowControlWidth` | 46 | Windows/Linux 单个窗口按钮宽度 |
| `AppSizes.windowControlIconSize` | 10 | 窗口控件图形尺寸 |
| `AppSizes.shellIconSize` | 18 | 标题栏图标 |
| `AppSizes.shellControlSize` | 30 | 标题栏图标按钮点击区域 |
| `AppSizes.shellSearchIconSize` | 16 | 命令中心搜索图标 |
| `AppSizes.macTrafficLightsWidth` | 68 | macOS 标题栏左侧交通灯留白 |
| `AppSizes.windowButtonsWidth` | 138 | 窗口按钮组总宽度 |
| `AppSizes.navTopBarHeight` | 48 | 移动形态顶栏 |
| `AppSizes.navBottomBarHeight` | 58 | 移动形态底栏 |
| `AppSizes.navSideRailWidth` | 48 | 桌面图标侧栏宽度 |
| `AppSizes.navItemSize` | 48 | 导航项点击区域 |
| `AppSizes.navBottomIndicatorWidth` | 64 | 移动底栏选中指示器宽度 |
| `AppSizes.navBottomIndicatorHeight` | 28 | 移动底栏选中指示器高度 |
| `AppSizes.navBottomIndicatorMinWidth` | 32 | 移动底栏未选中指示器宽度 |
| `AppSizes.navIconSize` | 24 | 导航图标 |
| `AppSizes.commandCenterWidth` | 320 | 命令中心搜索框宽度 |
| `AppSizes.commandCenterHeight` | 26 | 命令中心搜索框高度 |
| `AppSizes.settingsSidebarWidth` | 280 | 设置双栏左栏宽度 |
| `AppSizes.settingsCategoryHeight` | 46 | 设置分类行高 |
| `AppSizes.settingsHeaderHeight` | 56 | 设置左栏标题区高度 |
| `AppSizes.settingsSelectedIndicatorWidth` | 2 | 设置分类选中左侧边条宽度 |
| `AppSizes.authIconSize` | 36 | 认证页图标 |

## 3. 断点

三档，采用 Material 3 窗口尺寸类数值：

| 档位 | 条件 | 布局含义 |
|---|---|---|
| compact | `width < 720` | 单栏；移动形态导航（顶栏 + 底栏）；设置单页 |
| medium | `720 ≤ width < 1200` | 图标侧栏 + 内容；设置双栏；命令中心隐藏 |
| expanded | `width ≥ 1200` | 图标侧栏 + 内容；设置双栏；命令中心显示 |

- 统一入口：`Breakpoints.of(context)` / `Breakpoints.isCompact(context)` / `Breakpoints.isMedium(context)` / `Breakpoints.isExpanded(context)`。MUST NOT 在业务代码中出现 `720`、`900`、`1200` 等裸阈值。
- 同一宽度必须触发同一类切换：导航形态、设置双栏、命令中心可见性共享上述断点。
- 新旧对照（迁移记录）：旧侧栏切换 600 → 720；旧展开切换 1300 → 1200；设置双栏 720 → 720（含等号，`720` 起为双栏）；命令中心 900 → 1200（低于 expanded 隐藏）。
- 宽度恰好为 720 时属于 medium；恰好为 1200 时属于 expanded。

## 4. 容器策略

- 壳层：标题栏（36）+ 内容区；桌面宽度 ≥720 时内容左侧固定 48px 图标侧栏，侧栏与内容以 1px `shellBorder` 分隔。侧栏不参与滚动，内容区独立滚动。
- 设置页：medium/expanded 使用 280px 分类栏 + 1px 分隔线 + 自适应内容区；左栏选中项用「底色 + 2px 左侧边条」，禁止尾随箭头等移动端装饰。compact 使用单栏 push 导航。
- 列表/详情：列表与详情并排时，详情为自适应剩余宽度；不做「卡片套卡片」，分组用留白与 1px 分隔线。
- 页面内边距：标准 `AppSpacing.lg`（16）；设置类内容区块之间 `AppSpacing.xl`（24）；列表项密集区可用 `AppSpacing.sm`（8）。
- 浮层/弹窗：宽屏优先就地展开（in-place），窄屏才用居中弹窗；浮层圆角 `AppRadius.lg`，阴影仅在真正浮起时使用。
- 阅读器：全屏、无壳层，跟随应用当前主题（不设深色例外，owner 2026-10-20 修订）；容器策略不适用。

## 5. 图标系统

- 统一使用 Material Icons；未选中用 outline 变体，选中用 filled 变体（`Icons.book` / `Icons.book_outlined` 之外的现有配对按此原则）。
- 尺寸：壳层 18（`shellIconSize`），导航 24（`navIconSize`），行内图标 16–20；MUST NOT 为单个图标单独发明尺寸。
- 图标颜色跟随语义角色：默认 `shellForegroundMuted`，选中 `accent` / `onAccentContainer`，禁用 `disabledForeground`。
- 纯图形窗口控件（最小化/最大化/关闭）继续使用自绘 painter，颜色随 `colorScheme`；不要为浅色主题另存一套位图。
- 例外：标题栏侧栏开关暂时复用 `assets/vscode_layout_sidebar_*.png`（见例外清单 E-01），后续可替换为 Material 图标。

## 6. 语言规范

- 用户可见文案 MUST 通过 `.tl` 读取，源 key 使用英文；新增 key MUST 同时在 `assets/translation.json` 的 `zh_CN` 与 `zh_TW` 中补条目。
- 中文文案使用简体中文书面语；动作按钮用动词（「保存」「重试」），状态用陈述句（「已保存」）；省略号使用 `…`。
- 带参文案使用 `@name` 占位符，例如 `"Image dimensions: @width × @height pixels"`，通过 `tlParams` 渲染。
- 同一概念只用一个词：Search / 搜索；Favorites / 收藏；Chapters / 章节；Reading Settings / 阅读设置。
- 禁止在 widget 中直接写用户可见的中英文字符串（`Debug` 等历史遗留见例外清单）。

## 7. Surface 规则

### 7.1 Shell（桌面外壳）

- 结构：自定义标题栏（36）+ 顶栏（移动 48）/ 图标侧栏（桌面 48）+ 内容区。页面 MUST NOT 自造第二套窗口框架。
- 壳层视觉参数（实现核对于 2026-10-20，均来自 `AppSizes` / `AppSpacing`）：

| 部位 | 参数 | 值 |
|---|---|---|
| 标题栏 | 高度 | 36（`titleBarHeight`） |
| 标题栏 | 左右留白 | Windows/Linux 8；macOS 交通灯区 68 + 12 |
| 标题栏 | 侧栏开关 | 控件 30×30，图标 18，内边距 4 |
| 标题栏 | 窗口按钮 | 单按钮宽 46，图标区 10×10，整组 138 |
| 标题栏 | 菜单文字 | 12px（`AppFontSize.bodySmall`），左右 8 |
| 命令中心 | 尺寸 | 320×26，圆角 8，1px 边框，内边距 4/8 |
| 导航顶栏 | 高度 | 48（`navTopBarHeight`），左右 16，标题 18 bold |
| 导航侧栏 | 宽度 | 48（`navSideRailWidth`），项 48×48，图标 24，上/下留白 16 |
| 导航底栏 | 高度 | 58（`navBottomBarHeight`），指示器 64×28 |

- 标题栏：底色 `shellSurface`，底部 1px `shellBorder`；左侧菜单（Windows/Linux）或 macOS 交通灯留白；中间命令中心；右侧侧栏开关与窗口按钮。
- 命令中心：宽度 320、高度 26，填充 `shellSurfaceHover`，1px `shellBorder`，圆角 `AppRadius.md`，提示色 `shellForegroundMuted`，聚焦描边 `accent`。仅在 expanded（≥1200）显示；提示语随上下文变化（全局搜索 / 搜索收藏 / 搜索章节）。
- 侧栏开关：任何页面都可见；不可用时禁用（`disabledForeground`）并用 tooltip 说明原因，不允许 `SizedBox.shrink` 消失。tooltip 文案：「仅收藏页可用」/「当前页面无可切换的侧栏」。
- 设置分类选中态：底色 + 左侧 2px 边条；桌面端无尾随箭头。
- 壳层动效：hover/选中 160ms，导航形态切换 250ms；不做位移夸张的动画。

### 7.2 Settings（list-detail）

- medium/expanded：左栏 280px 分类列表 + 右栏内容；打开即默认着陆第一个分类，不留半屏空白。
- compact：单栏 push；返回按钮在标题区左侧。
- 分类行高 46；图标 24 + 16 间距 + 文字；选中底色 `accentContainer` @36% + 左边条 `accent`。
- 单页设置项按语义分组，低频项折叠；不在同一平面暴露三层作用域（全局 / 设备 / 单部漫画）。

### 7.3 List-detail（漫画列表与详情）

- 宽屏列表与详情并排，窄屏 push；详情内容自适应剩余宽度。
- 列表项 hover 用 `shellSurfaceHover`；选中态用 `accentContainer`，不加边框动画。
- 分组标题用 18px bold + 24 上下留白；分隔线 1px `contentBorder`。

### 7.4 Reader

- 全屏阅读，不显示自定义标题栏（`WindowFrame.setWindowFrame(false)`）。
- 阅读器 chrome 跟随应用当前主题，不设深色例外；间距/圆角/动效/断点走 token。
- 阅读器内搜索目标是章节列表，命令中心提示语为「搜索章节」；不给阅读器加浅色壳层。

## 8. 例外清单

登记格式：编号 | 位置 | 偏离内容 | 原因 | 登记日期。

| 编号 | 位置 | 偏离内容 | 原因 | 登记日期 |
|---|---|---|---|---|
| E-01 | `lib/app_shell/desktop_top_bar.dart` | 侧栏开关使用 `assets/vscode_layout_sidebar_*.png` 位图而非 Material Icons | 图标表达左右栏方向比现有 Material 图标精确；后续换图标时一并移除 | 2026-10-20 |
| E-02 | `lib/features/**`（内容区，含阅读器） | 扫描到 43 处字号字面量、387 处宽高字面量、54 处硬编码颜色未迁移到 token（宽高集中在 comic_details 80、settings 63、reader 55、comic_source 46） | 本 change 的 Non-Goal 明确内容区视觉迁移由后续 change 依据本契约逐步进行；壳层与新增 UI 已全部走 token。阅读器无配色例外（跟随主题），字号/尺寸仍应在后续迁移 | 2026-10-20 |
| E-03 | `lib/components/**`（`navigation_bar.dart`、`window_frame.dart` 除外） | 扫描到 11 处字号字面量、45 处宽高字面量、14 处硬编码颜色（select/button/code/flyout 等历史共享组件） | 共享组件的取值改动会影响内容区视觉，留给内容区迁移 change 一并处理，避免本 change 夹带无关重绘 | 2026-10-20 |
| E-04 | `lib/components/window_frame.dart`（`kDebugMode` 分支） | 调试按钮文案 `Debug` 未走 `.tl` | 仅 debug 构建可见、不进入发布包；后续随手补齐翻译 key 时移除 | 2026-10-20 |
