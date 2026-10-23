# Design

## 背景与现状锚点

- 阅读设置 47 键：`lib/foundation/reader_preferences.dart`（`all` 列表 :252-300）；typed 偏好 `Preference<T>`。
- 模式求值：`lib/foundation/reader_settings.dart:13-55`（`autoReaderMode` 真→按 ComicLayout 从 `pagedReaderMode`/`longStripReaderMode` 选；假→`readerMode`；漫画层 `readerModeOverride` 最高优先）。
- 作用域：`ReaderPreferenceStore`（`lib/foundation/reader_preference_store.dart`）`readRaw/writeRaw/writeComicModeOverride`；`active` 语义见 appdata.dart:803-817。设置页作用域选择器 `lib/features/settings/reader.dart:22,126-256`（三分段；漫画段需 comicId）。
- 快捷面板：`lib/features/reader/quick_settings_panel.dart`（枚举 `ReaderQuickSetting` :17-24，清单 :27-34，固定 comic 作用域 :60-65）。
- 模式切换现有通道：面板下拉写 `writeComicModeOverride`（:110-113）；设置页漫画分支 `setComicReaderModeOverride`（reader_mode.dart:331）。
- CRUD 先例：`searchShortcuts`（appdata.dart:631，List<Map> + identity 去重 + updateSettings 原子写，管理器 `lib/features/search/search_shortcut_manager.dart:6-49`）。

## D1 数据模型

```dart
// appdata.json 顶层键 'readerModePresets'
[
  {
    "id": "<uuid 或时间戳字符串>",
    "name": "日漫双页",
    "values": { "<preferenceKey>": <value>, ... }
  }
]
```

- 管理器 `ReaderPresetStore`（`lib/foundation/reader_presets.dart`）：`list / createFromCurrent(name) / rename(id,name) / updateFromCurrent(id) / delete(id) / apply(id, scope)`，全部经 `appdata.updateSettings` 原子写；list 结果保持存储顺序（用户排序 = 创建顺序，本期不提供排序）。
- `values` 只含 D2 键集合的键；快照时记录这些键在当前**生效层**的值（经 `ReaderPreferenceStore` 按应用时上下文读）。
- 名称校验：trim 后非空、≤30 字符、同库不重名（大小写不敏感）；违反则拒绝并返回已有名称提示（.tl）。
- 删除方案不回写任何已应用的设置。

## D2 方案键集合（固定）

模式：`readerMode`、`autoReaderMode`、`pagedReaderMode`、`longStripReaderMode`
布局：`readerScreenPicNumberForPortrait`、`readerScreenPicNumberForLandscape`、`showSingleImageOnFirstPage`、`limitImageWidth`、`readerSideMargin`、`splitDualPage`、`splitDualPageInvert`、`enablePageAnimation`
手势：`enableTapToTurnPages`、`reverseTapToTurnPages`、`enableDoubleTapToZoom`、`longPressAction`、`longPressZoomPosition`、`quickCollectImage`、`enableTurnPageByVolumeKey`

共 19 键。**不含**：亮度、缩略图、E-Ink、自动阅读 7 键、预加载、评论/页码/状态栏——这些是跨漫画类型的全局体验项。应用时逐键写入；方案中缺失的键不动当前值。

## D3 应用语义（与作用域正交）

- `apply(id, scope)`：逐键 `ReaderPreferenceStore.writeRaw(key, value, scope)`；模式键特判——**与现有模式切换通道完全一致**：comic 层写 `writeComicModeOverride`，global/device 层写对应模式键（含 `autoReaderMode`，走既有 resolve 语义）。
- scope 由调用方决定：设置页 = 选择器当前层（`ReaderSettingsScope`）；阅读器面板 = comic 层。
- 应用后效果经既有 `ReaderSettingsRequest.apply` / `readerSettingEffects` 派发（settings_effects.dart:46-95），不新增效果通道。
- 快照（createFromCurrent / updateFromCurrent）同理：逐键读当前生效层值；模式键快照的是**求值后的生效模式**（resolve 结果），快照同时写入 `autoReaderMode=false` + 求值模式到 `readerMode`——保证方案应用后模式确定、不被全局 auto 再次改写。

## D4 设置页入口

- `lib/features/settings/reader.dart`「阅读模式」组之后新增「阅读模式方案」组：
  - 「当前方案」SelectSetting 风格下拉：显示「无」+ 各方案名；选择 = apply 到当前作用域选择器层；切换作用域选择器不改变下拉显示（下拉只反映「上次应用的方案名」供参考，无绑定关系）。
  - 「管理方案…」CallbackSetting → push 方案管理页（`context.to` 先例同 About→Debug）。
- 管理页：方案列表（名称 + 应用按钮 + 每项操作：重命名（对话框）、更新为当前值（带确认文案）、删除（带确认））+ 顶部「新建方案」（输入名称，从当前设置快照）。
- 若 `_SettingsEditingScope` 就地编辑框架与「应用/管理即时生效」冲突，执行者 MUST 停工上报（与 keyboard-shortcuts 4.1 同一判例）。

## D5 快捷设置面板

- `ReaderQuickSetting` 枚举 + `readerQuickSettings` 清单新增 `preset` 项（置于 mode 之后）：下拉「方案：无 / 各方案名」，选择即 `apply(id, comic)`；面板其余项不变。
- 面板固定 comic 作用域语义不变；方案项与全量页共用同一 `ReaderPresetStore`，无第二数据源（quick-settings spec 原则 ② 保持一致）。
- quick-settings spec delta 增补 Requirement（见 specs/reader/quick-settings/spec.md）。

## D6 框架容纳检查

- 无新视觉语言：复用设置组件（SelectSetting/CallbackSetting/对话框）与面板既有模式项样式；token 走既有。
- 语言规范：全部新文案 .tl，zh_CN/zh_TW 同步；名称由用户输入，不做翻译。
- 反模式检查：无深色块/无第二导航/无装饰图标。

## 风险

- 最大风险 = 模式键在 comic 层走 `readerModeOverride` 特判，快照/应用的键映射若与现有切换通道不一致会产生「方案应用了但模式没变」。缓解：D3 强制复用 `writeComicModeOverride`/既有 writeRaw 路径，验收含逐层 GUI 对照。
- 重名/空名的 UX 与 searchShortcuts 去重先例保持一致。
