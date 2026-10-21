# Design

## Context

- 保存状态条现状：`SettingsSaveState`（`lib/components/settings_save_state.dart`）在 `_pending` 非空时渲染一条 42px 高的状态条（指示器 18px + 上下 padding 各 12px，见 :283），保存结束清空 `_pending`（:180）后消失。各页面自行决定插入位置：收藏页在 Column 的 Expanded 前（`favorites_page.dart:117`）、阅读模式在设置项列表前（`reader_mode.dart:253`）、阅读设置在 CustomScrollView 中作为 Sliver（`reader.dart:354`）。
- 诊断已动态验证：重新选择同一文件夹、开关写回原值均可复现，两页稳定测得下移 42px 后回弹；页面实例与 ScrollController 均未重建，排除滚动重置假说；chrome 布局标志不变，排除 shell 假说。
- 保存语义（`saveSetting`、admission、`protectSettings`/`leaveSettings`、失败重试）已被多个测试覆盖，必须原样保留。

## Goals / Non-Goals

**Goals:**

- 保存进行中/成功/失败期间，正文布局坐标零变化（消除下移-回弹）
- 三个接入点统一改造，不留第二种插入式用法
- 保存反馈仍清晰可见（不能因为改覆盖层而弱化可感知性）

**Non-Goals:**

- 不修 chrome 构建期 setState 缺陷（独立问题，入 BACKLOG）
- 不重设计状态条样式（沿用现有视觉，仅迁移呈现位置）
- 不改保存语义与任何数据读写路径

## Decisions

### D1: 覆盖层采用 Stack 顶层浮动条，不走 OverlayEntry

- `SettingsSaveState` 增加覆盖层渲染模式：页面根用 `Stack` 包裹，状态条以 `Align(topCenter)` 浮动在内容区顶部，参与绘制不参与布局约束——正文 Widget 树结构不变，坐标天然稳定。
- 备选：用 `OverlayEntry` 挂到全局 Overlay——层级隔离更彻底，但定位依赖上下文坐标换算，三个接入点的改造面更大，且与现有「状态条属于页面」的心智不一致，否。
- 备选：为状态条保留恒定 42px 占位——无位移但永久吃掉 42px 内容高度，违背现代极简的留白原则，否。

### D2: 保留现有插入式 API 一个版本周期

- 三个接入点切换为覆盖层模式后，旧的插入式构造路径保留但标记为弃用（内部注释说明），避免外部调用点（若有遗漏）直接编译失败。本仓库全库检索确认无第四处接入点（诊断已核）。
- 若全库确认只有三处接入，可直接移除旧路径，不保留兼容（倾向后者，实现时确认）。

### D3: 回归测试以坐标断言为核心

- 新测试阻塞 `saveSetting` 内部的保存 Future（以测试钩子或可控的 fake store），在保存进行中断言正文关键 Widget 的坐标与保存前一致，保存完成后仍一致。
- 现有持久化测试（`reader_settings_persistence_test.dart` 等）不覆盖视觉条件，不可依赖。

## Risks / Trade-offs

- [覆盖层状态条遮挡正文顶部内容] → 状态条出现时正文顶部 42px 区域被浮动条覆盖；现有插入式方案同样让正文顶部变化，遮挡是可接受的等价代价，且保存态通常瞬时（<1s）。
- [三处接入改造遗漏] → 实现时全库 grep `SettingsSaveState` 使用点清单作为 tasks 核对项；坐标回归测试覆盖收藏与阅读两条路径。
- [移动端显示异常] → 覆盖层在窄屏同样浮动于顶部，不依赖断点；实现后用 widget 测试覆盖窄宽断言。

## Migration Plan

1. `SettingsSaveState` 增加覆盖层渲染模式（D1），旧路径保留（D2）
2. 收藏页接入；跑收藏相关测试
3. 阅读模式 + 阅读设置外层接入；跑阅读设置相关测试
4. 新增坐标回归测试（D3）
5. 验证：`flutter analyze` 无新增 + 全量相关测试 + 手动走查两页保存路径
6. 回滚：三步接入相互独立，可单独 revert；核心组件改动单测兜底

## Open Questions

- 覆盖层状态条是否需要半透明底色以区分于正文？（倾向需要，实现时对照 design-spec.md 的分隔线/层级约定确认）
