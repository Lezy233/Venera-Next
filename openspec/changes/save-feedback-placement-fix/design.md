# Design

## Context

- `_SettingsSaveFeedback`（`lib/components/settings_save_state.dart`）以 `Stack` + `Positioned.fill` + `Align(topCenter)` 浮动保存反馈，位于页面 Stack 的最顶部。
- 桌面壳（`lib/app_shell/desktop_chrome.dart`）顶栏覆盖在内容区之上（或页面区域向上延伸至顶栏之下），`topCenter` 对齐点落入顶栏遮挡带，提示只显示下半。设置页与就地编辑右栏均受影响。
- 窄屏/移动端无顶栏遮挡带问题，但同一组件代码共用，修复需同时保证两端。

## Goals / Non-Goals

**Goals:** 三态反馈（保存中/成功/失败）在桌面与移动、单栏与双栏下均完整可见；改动最小，不动壳层结构。

**Non-Goals:** 不改提示样式/文案；不改顶栏；不引入全局 Overlay。

## Decisions

### D1: 首选「下移进入内容安全区」，而非上移贴顶栏下沿

- 诊断先行：executor 先用 GUI/VM 测定遮挡带几何（顶栏高度与 Stack 顶部的关系），再定偏移方案。
- 候选方案（按优先级）：① 反馈垂直位置改为顶栏安全区之下（如 `topCenter` + 顶部 padding 为壳层高度，或改用 `bottomCenter` 浮于内容底部）；② 若遮挡源于兄弟绘制顺序而非几何，调整 Stack 内层级。首选对组件自包含、不依赖壳层内部知识的方案；需要读壳层常量时经现有 design-system 断点/壳层规范取数，不硬编码魔数。

### D2: 回归断言

- 新增 widget 测试：在带模拟顶栏遮挡带的宿主中，断言反馈 Widget 的绘制区域不与遮挡带相交（比较 RenderObject 的 paint bounds 与遮挡带矩形）。

## Risks / Trade-offs

- [底部悬浮可能被页面底部控件（如键盘/工具栏）遮挡] → 诊断时核对各接入页底部结构；若底部更不安全，则回顶部安全区偏移方案。
- [与 reader-quick-settings-panel 验收并行] → 本修复独立于该 change 的代码路径（组件层），可单独提交、单独验收。

## Migration Plan

1. 诊断遮挡带几何（GUI/VM 测定）
2. 按 D1 实施最小定位修复
3. 新增 D2 回归测试 + analyze
4. GUI 走查：设置 → 阅读切换作用域、快捷设置 → 全部设置切换作用域，提示完整可见
