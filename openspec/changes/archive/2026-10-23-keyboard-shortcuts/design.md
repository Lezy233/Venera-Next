# Design

## 背景与现状锚点

- 全局 4 键硬编码：`lib/app_shell/desktop_chrome.dart:222-230`（desktopShortcuts + primaryShortcut，macOS 用 meta、其余用 control），挂载于 `lib/main.dart:436-449` 的 `CallbackShortcuts`，依赖 `autofocus` Focus；内层 Esc→pop。
- 阅读器键盘：`lib/features/reader/reader_page.dart:1904-1932`（KeyboardListener + `focusNode.hasPrimaryFocus` 守卫）；方向键处理在视图内——gallery（`gallery_view.dart:580-619`，KeyRepeatEvent + Timer 连发）、continuous（`continuous_view.dart:1310-1354`，按 vertical/reverse 决定方向语义，25% 视口滚动）；F12 全屏在 reader_page onKeyEvent；Home/End 在 progress_bar（`progress_bar.dart:172-180`）。
- 翻页动作入口已存在：`reader_page.dart:764-785`（`toNextPage/toPrevPage/toChapter/toNextChapter/toPrevChapter`）。
- 动作分发现状：`DesktopChromeController.bindGlobalActions`（desktop_chrome.dart:98-114）+ reader 动作的 `setReaderActions`（scaffold.dart:160-180），无统一登记。
- 存储：`lib/foundation/appdata.dart` `Settings._data`（Map）→ `appdata.json`；先例 `'searchShortcuts'`（appdata.dart:631）顶层键。
- 设置页：`lib/features/settings/settings_page.dart` 硬编码 categories/icons/switch 三处 + 页面 widget；复用组件在 `setting_components.dart`。
- 已冻结约束：`openspec/specs/shell/chrome-lifecycle/spec.md`——全局快捷键注册内容与触发行为不变；`openspec/specs/shell/command-center/spec.md`——Ctrl/Cmd+F 聚焦行为与点击一致。

## D1 注册表模型

新建注册表模块（执行者按代码结构选择位置，如 `lib/foundation/shortcuts/`）：

```dart
enum ShortcutContext { global, reader } // F1 预留扩展，见 D8

class ShortcutAction {
  final String id;                 // 稳定字符串，如 'app.openSettings'
  final String titleKey;           // .tl 词条（英文 key）
  final ShortcutContext context;
  final List<ShortcutActivator> defaultBindings;
  final ShortcutRunner runner;     // 执行体，签名携带 KeyEvent（保留连发语义）
}
```

- 默认表为静态常量表；**生效键位 = 默认表 ⊕ 用户覆盖**（覆盖可改键、可清除）。
- 注册表是键盘绑定的唯一事实来源：main.dart 顶层 `Shortcuts/CallbackShortcuts` 由注册表 global 条目动态构建；阅读器按键处理先查注册表 reader 条目再落默认。桌面壳 desktopShortcuts 硬编码删除。
- runner 不持有 widget 状态：global runner 调 `DesktopChromeController` 现有动作（openSettingsAction 等，其阅读器分流语义保持不变）；reader runner 调阅读器现有方法（视图方向语义见 D2）。

## D2 默认键位表（迁移 + 增量）

格式：`动作 id` | 上下文 | 默认键（win/linux；macOS 前缀 Ctrl→Cmd）| 来源。

**global：**

| 动作 | 默认键 | 来源 |
|---|---|---|
| app.openSettings | Ctrl+, | 迁移 |
| app.openSearch | Ctrl+F | 迁移（阅读器内分流到章节搜索的语义不变） |
| app.toggleLeftSidebar | Ctrl+B | 迁移 |
| app.toggleRightSidebar | **win/linux：Ctrl+Shift+B**；macOS：Cmd+Alt+B | 迁移+改默认（owner 2026-10-22：win/linux 默认由 Ctrl+Alt+B 改为 Ctrl+Shift+B，macOS 不变；平台相关默认值在注册表按平台求值） |
| app.goHome | Ctrl+1 | 新增（chrome.navigateTo） |
| app.goFavorites | Ctrl+2 | 新增 |
| app.goExplore | Ctrl+3 | 新增 |
| app.goCategories | Ctrl+4 | 新增 |

**reader：**

| 动作 | 默认键 | 来源 |
|---|---|---|
| reader.moveLeft / moveRight / moveUp / moveDown | 对应方向键 | 迁移；runner 委托视图现有 handler，**方向语义与连发逻辑保留在视图层**（continuous 的 vertical/reverse、gallery 的 Timer 连发不得改动） |
| reader.toggleFullscreen | F12 | 迁移 |
| reader.nextPage | Space, PageDown | 新增；**分模式**：gallery 调 `toNextPage`（±1 页）；continuous 复用视图滚动机制**前进一视口高**（不是 toNextPage 的跳下一图片条目；到底无操作，不自动切章） |
| reader.prevPage | PageUp | 新增；**分模式**：gallery 调 `toPrevPage`；continuous 反向滚动一视口高（到顶无操作） |

边界（不注册、行为不变，proposal 已登记）：Esc（全局 pop、阅读器退出守卫 exit_guard、右键菜单各自局部处理）；阅读器 progress_bar 的 Home/End 保留在局部（注册它们会与全局导航未来扩展纠缠，本期不登记）。

## D3 覆盖存储与求值

- 存储：`settings['shortcutOverrides']`：`Map<String, List<String>>`，actionId → 组合键编码列表（如 `["ctrl+shift+b"]`、`["space","pagedown"]`）。空列表/absent 语义：**键不存在 = 用默认表；存在且为空列表 = 用户显式解绑（无键位）**（owner 2026-10-22：支持同一动作绑定多个快捷键）。编码规则在注册表模块内提供序列化/反序列化与展示格式化各一份（展示格式见 D6）。
- 求值：读取时合并默认表；写入走 `appdata.updateSettings`（既有批量+通知）。缺省（键不存在）= 全部默认。
- 生命周期：改键/清除/重置即时写入并即时生效（无需显式保存按钮）；应用重启后保留。
- 数据迁移：无（新顶层键，旧版本无此数据）。

## D4 冲突检测

- 冲突域 = 同一 `ShortcutContext` 内。global 与 reader 的相同组合键互不算冲突（阅读器接管键盘时本就屏蔽全局键）。
- 检测时机：设置页捕获新键时即时检测；启动/加载时若持久化数据自身冲突（如版本变更），后加载者失效并回退无键位（不弹窗）。
- 冲突反馈：拒绝保存，显示占用动作标题（.tl 词条）；用户可先去清除占用方。
- 例外：同一动作自身的多默认键（如 reader.nextPage 的 Space+PageDown）不算冲突。

## D5 文本输入守卫

- 当 `FocusManager.instance.primaryFocus` 位于 EditableText（含 TextField）内时，global 上下文注册键 MUST NOT 触发。实现建议：注册表驱动的顶层 ShortcutManager/守卫 widget 统一检查，替代各点散判。
- reader 上下文保留现有 `focusNode.hasPrimaryFocus` 守卫并接入同一检查逻辑。
- Esc 的局部行为不受本守卫影响（现状保持）。

## D6 设置页「快捷键」

- 归属（owner 2026-10-22 验收反馈裁决，**取代此前的 APP 分类内入口方案**）：「快捷键」为**独立主分类**，在 categories/icons/switch 三处登记 + 新页面文件 + settings.dart export；撤销 `app.dart` 的 CallbackSetting 入口。理由：键位体系是 PC 效率核心功能，入口需要直接可达；settings/navigation delta 已同步修订（分类归属一致新增快捷键例外）。
- 页面结构：两个分组（全局 / 阅读器，`SettingPartTitle`），行 = 动作标题 + 生效键位（**多键位时逐个显示，可单独删除**；owner 2026-10-22）+「添加键位」入口；macOS 显示符号（⌃⌥⌘⇧ 风格，由执行者定），win/linux 显示 "Ctrl+Shift+B" 文本。
- 交互：点击「添加键位」/某键位进入捕获态（提示「按下新的快捷键…」），按下组合键即保存（即时生效）；Esc 取消捕获；每行提供清除全部键位与重置默认；页面级「全部重置」。
- 冲突：捕获到冲突键时行内/提示条显示「已被『占用动作名』使用」类文案（.tl），不保存。
- 与 settings-ia-cleanup 的 `_SettingsEditingScope` 就地编辑框架的关系：快捷键改动即时生效，不纳入显式保存栏；如框架强约束冲突，执行者 MUST 停工上报（契约冲突流程）。

## D7 macOS 菜单 accelerator

- `lib/app_shell/desktop_menus.dart` 的 `PlatformMenuItem` 增加 `shortcut:`，值 = 注册表当前生效键位（用户改键后重建菜单即可反映；绑定缺省/被清除的项不显示 accelerator）。
- Windows/Linux 内联菜单本期不加键位文字（Out of Scope）。

## D8 F1 多栈兼容性（仅设计，不实现）

- `ShortcutContext` 为枚举，F1 可追加页面级值（如 `page`）而不要求改造条目结构。
- 冲突域从「上下文」扩展为「(上下文, 栈)」是数据层面的扩展：`shortcutOverrides` 编码可升级为 `"ctx:combo"` 或嵌套 map；本期编码保持扁平，升级路径在注释中说明。
- runner 不持有页面状态（D1），多栈下由路由层解析目标栈，符合现有 chrome 动作分流模式。

## 框架容纳检查

- token/断点/surface：设置页复用现有设置双栏框架与 token；无新视觉语言。design-spec.md 无需新增例外。
- 语言规范：全部新文案走 .tl，zh_CN/zh_TW 同步（proposal Impact 已列）。
- 反模式检查：无深色块、无新造窗口框架、无装饰性图标。

## 风险与回退

- 最大风险 = 阅读器方向键迁移改变默认行为。缓解：D2 要求 runner 仅委托现有视图 handler，方向语义/连发零改动；验证任务含逐键 GUI/单元对照。
- 全局键行为被 chrome-lifecycle spec 冻结：迁移后触发链可变为注册表，但 4 键的可见行为（含阅读器分流）必须逐项验收。
