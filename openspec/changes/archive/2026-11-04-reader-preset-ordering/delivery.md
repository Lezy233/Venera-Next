# F9 executor 交付（等待 architect 独立复核）

基准 HEAD `7336ef510e250f3f99840af078ea1a9de96e684d`，开工工作区干净。仅执行 F9；未提交、归档或推送。实现和测试 SHA 冻结于 `/tmp/f9-final-implementation.sha256`，最终 GUI 后逐项 MATCH。

## 实现与授权改动

- `lib/features/settings/reader_presets.dart`：生产管理页使用稳定 ID 的可重排列表、独立手柄、上/下移按钮、首尾禁用及同 ID 焦点；本页保存期间禁用 CRUD/排序。拖动开始捕获显示身份，拖动期间保留显示列表，落位按原 ID 入 writer，避免并发新增/改名导致错移或 Flutter 布局异常。失效目标显示本地化错误；补偿未完成重进仍显示错误并提供恢复重试。
- `lib/foundation/reader_presets.dart`：`move(id, adjacentId, before: …)` 捕获目录，在串行 writer 的最新 raw 列表上只移动原记录；不重新序列化旧对象、不应用方案、无变化不写盘。顺序使用独立恢复 key；失败重试只保存恢复后的有效状态。
- `lib/foundation/settings_recovery.dart`：在既有 keyed-list 字段恢复中补充顺序所有权。仅在存活共有 ID 仍处于本次发布顺序时恢复旧顺序；并发新增保留位置、删除不复活、改名/值保留、后续排序接管保留。原 B3 字段恢复不变。
- `lib/foundation/appdata.dart`：增加默认 `true` 的 `migrateReaderPresets` 选项，仅排序传 `false`，避免无变化排序触发 legacy 绑定迁移并写盘，保护 raw 值/引用。其余调用默认行为不变。
- `assets/translation.json`：仅增加 `Drag to reorder`、`Preset list changed; try again` 的简繁翻译，所有原词条完整保留；复用原 Move up/down。
- 新增 `test/foundation/reader_preset_ordering_test.dart`、`test/features/settings/reader_preset_ordering_test.dart`；原 B3/F8/B4 测试零 diff，没有删除或弱化断言。
- 本 change `tasks.md`、本交付文件。

F9 授权涉及 B3 实现的单独清单为上述四份 Dart 源码；未修改 B3 其他源码或任何已验收工件。`quick_settings_panel.dart` 不需修改：生产面板已经复用同一 selector/list。

## 中断与红绿证据

意外中断后原 `/tmp/f9-start-sha256.txt`、`/tmp/f9-red.log`、旧 GUI helper、architect 旧 analyze 基线等均不再存在，不将它们作为现存证据。保留主工作区全部改动，在 `/tmp/f9-head` 从 HEAD 独立解出临时 checkout，复制已有 `.dart_tool` 配置（本包 rootUri 为相对 `../`，指向该 checkout，未指向工作区源码），全程 `--no-pub`，不改 lock。

从独立 HEAD 重建的 SHA 为 `/tmp/f9-protected-head.sha256`（相对路径）及 `/tmp/f9-head-sha256.txt`。现存两条红灯位于 `/tmp/f9-red-rebuilt.log`：**0 通过、2 失败、0 skip**。

```sh
cd /tmp/f9-head
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
LD_LIBRARY_PATH=/home/_Le/Code/Projects/Venera-Next/build/linux/x64/debug/bundle/lib \
  fvm flutter test --no-pub test/features/settings/f9_red_probe_test.dart --reporter expanded
```

1. 并发删除 B、改名 C、新增 D 后，失败排序补偿期望 `A/C/D`，HEAD 实际仍为 `C/A/D`。
2. 真实 `ReaderPresetManagement` 找不到 `ReorderableListView`，也无独立拖动控件。

修复后的同类断言保留在生产 UI 测试内。额外红灯还锁住了：无变化移动触发自动迁移产生两次文件写入；拖动中列表新增导致 Flutter 布局/语义异常。对应最终回归均通过。测试等待使用有界 writer 轮询；早期无界等待已终止并替换，没有保留运行进程。

## D4 矩阵

| D4 要求 | 最终证据 |
|---|---|
| A/B/C 前后/首尾/无变化/空/单项/坏或已删 ID | foundation 13 项：双向移动、无变化/非法目标真实写入计数为 0、排队删除移动项与目标不复活；新实例与真实文件 reload |
| 对象、19 键、modeBehavior、三层绑定/raw/实际模式不变 | fixed/inherit 两分支逐字段比较全部 raw settings 与完整方案对象；三个明确 B 绑定，逐项比较 19 键实际求值；None 保持 None |
| CRUD 不重排无关项 | 新建末尾、重命名/显式更新原位置、删除仅移除目标；排队新建/改名/共享值编辑/删除后排序保留最新记录 |
| 真实管理页输入 | UI 9 项：鼠标向前和向后拖动、按钮点击、Tab+Enter/Space；onApplied=0；同 ID 焦点；首尾禁用；拖动中并发新增/改名按原身份完成 |
| 宽度/主题/缩放 | 390/1280 × 浅/深 × 1.6 的真实键盘操作；长名称两行及 tooltip，零 overflow；最终 GUI 完整帧另见下表 |
| 各选择器/生产面板同序 | UI 打开实际下拉，global/device/comic 和生产 ReaderQuickSettingsPanel 的 None/方案顺序一致，所选中间 B 与 inherit 保持；真实新 PID 再核对 |
| appdata/syncdata 真实 IO 失败 | 两文件分别由真实 `.tmp` 目录障碍触发 native 写失败，再解除一次性障碍；补偿两文件均恢复旧序并保留并发新增/删除/改名/共享值/无关语言字段；磁盘 reload 验证 |
| 补偿失败/恢复/重进 | 持续目录障碍使首次与补偿都失败；跨 store 排序暂停、绑定仍 B；反复重试失败保持；解除后只保存恢复状态，不重放移动。真实 UI 销毁重进仍有持续错误、CRUD/排序禁用，点击 Retry recovery 后解锁，无 Saved/应用 |
| 顺序接管/目录切换 | 后续排序接管不回滚；排队切目录不写新库；失败中切目录只登记旧归属恢复，旧 owner 不能向新目录重试，返回原目录后恢复旧序 |
| B3 保护 | 原绑定/19键/共享值/None/fixed/inherit/失败恢复/UI断言全部保留；19 文件共 304 项通过；另有 B4/F8 保护集 199 项 |

## 实际自动化命令和计数

以下均在主工作区，环境：

```sh
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
export LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib
```

最终 **231 通过、0 失败、0 skip**（F9 新增 22 + B3 相关 209），日志 `/tmp/f9-final-regression.log`：

```sh
fvm flutter test --no-pub \
  test/foundation/reader_preset_ordering_test.dart \
  test/features/settings/reader_preset_ordering_test.dart \
  test/foundation/reader_presets_test.dart \
  test/foundation/reader_preset_binding_test.dart \
  test/foundation/reader_preset_inheritance_test.dart \
  test/foundation/reader_preset_recovery_test.dart \
  test/foundation/appdata_admission_test.dart \
  test/foundation/appdata_test.dart \
  test/features/settings/reader_presets_test.dart \
  test/features/settings/reader_settings_persistence_test.dart \
  test/features/settings/reader_side_margin_test.dart \
  test/features/reader/quick_settings_panel_test.dart \
  test/components/settings_save_feedback_test.dart \
  test/components/settings_save_host_test.dart --reporter expanded
```

补齐实际模式/作用域/手势直接依赖 **95 通过、0 失败、0 skip**，日志 `/tmp/f9-b3-effective-settings.log`；因此本次 B3 相关合计 **304 项/19 文件**。B3 历史精确命令仅记录于已丢失的 /tmp 文件，不将本次范围伪称为历史 285 项完全相同命令。

```sh
fvm flutter test --no-pub \
  test/foundation/reader_settings_snapshot_test.dart \
  test/foundation/reader_preference_store_test.dart \
  test/foundation/reader_mode_settings_test.dart \
  test/foundation/reader_gesture_settings_test.dart \
  test/features/reader/automatic_reader_mode_test.dart \
  test/features/reader/layout_detection_test.dart \
  test/features/reader/settings_effects_test.dart --reporter expanded
```

B4/F8 保护 **199 通过、0 失败、0 skip**，日志 `/tmp/f9-b4-f8-protection.log`（原 B4 范围加当前 F8 测试）：

```sh
fvm flutter test --no-pub \
  test/features/comic_widgets \
  test/features/favorites/favorite_hit_target_test.dart \
  test/features/favorites/favorites_display_test.dart \
  test/features/favorites/favorites_reorder_test.dart \
  test/features/search \
  test/components/context_menu_test.dart --reporter expanded
```

故障用例的红色 IO 日志是预期异常断言，最终测试统计无失败。原测试全部保持原文。

## Analyze 与保护

`fvm flutter analyze --no-pub`：`/tmp/f9-analyze-final.log`，raw **50**、unique **50** = tool/code_audit **38** + 其余 **12**。从独立 HEAD checkout 同命令重建 `/tmp/f9-head-analyze.log`，逐条完整问题集合相同，added=[]、removed=[]。具体 50 项问题保留在这两份日志中，不将预存 folder_order_ownership_test 编译错误等清零。

曾出现 53 项的中间检查新增：管理页旧 onReorder deprecation、settings_recovery 多余 cast、测试多余 import；仅修这三项，使用 onReorderItem 并按 Flutter 已修正后的目标索引转为相邻 ID。

`python3 /tmp/f9_validate.py` 输出 `/tmp/f9-validation-summary.json`：保护允许清单之外零变化；旧翻译零删除/修改；最终 GUI 事件仅顺序改变、三层 B、19 键完整、inherit、实际 waterfall、无应用回调。HEAD 中所有跟踪文件均有重建 SHA；main/runner、pubspec/lock、design-spec、F9 四件套、正式 specs、F8/B4 实现及全部已验收工件零 diff。翻译文件的 F8 词条保持原文，仅增加 F9 两组词条。

`git diff --check` 通过。未添加依赖、未生成 lock、未修无关基线。

## 最终源码 GUI 与真实重启

临时宿主 `/tmp/f9_gui.dart`，`windowManager.ensureInitialized/show`，有界生产管理页/selector/quick panel，不改 main/runner。DISPLAY=:1、GDK_BACKEND=x11、XDG config/data/cache 分别为 `/tmp/f9-xdg/{config,data,cache}`，业务库 `/tmp/f9-gui-data`、缓存 `/tmp/f9-gui-cache`。已读核对重建 helper `/tmp/f9_x11.py`；每次操作校验 WM_NAME，只有 F9 窗口才执行，松开后等待稳定。

启动命令：

```sh
DISPLAY=:1 GDK_BACKEND=x11 \
  XDG_CONFIG_HOME=/tmp/f9-xdg/config \
  XDG_DATA_HOME=/tmp/f9-xdg/data \
  XDG_CACHE_HOME=/tmp/f9-xdg/cache \
  LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib \
  build/linux/x64/debug/bundle/venera-next
```

最终源码 PID **104621 → 106532**（TERM 停旧进程后重新启动，同库从真实磁盘加载）。对应 `/tmp/f9-gui-final-run1.log`、`/tmp/f9-gui-final-run2.log`。审计 `/tmp/f9-gui-audit.jsonl` 按 PID/页面记录完整 settings。最终两进程的 11 个审计事件逐字段比较：仅顺序有变，三层绑定均 B、B 的 19 键/name/modeBehavior=inherit 和所有 raw settings 不变，实际 waterfall；无 onApplied/面板应用。

下列均已逐张 view_image，截图只在 /tmp，不入库：

| 最终证据 | 实际结果 | 文件 |
|---|---|---|
| PID104621 鼠标拖动 B | A/C/B → B/A/C | `/tmp/f9-final-drag.png` |
| 同 ID B 下移按钮 | B/A/C → A/B/C | `/tmp/f9-final-click.png` |
| Tab 到 C 上移，Enter | 焦点可见，A/B/C → A/C/B | `/tmp/f9-final-focus.png`、`/tmp/f9-final-keyboard.png` |
| compact 深/浅 1.6 | 390×720，A/C/B、B长名称换行、边界禁用、无溢出 | `/tmp/f9-final-compact-dark-scale.png`、`/tmp/f9-final-compact-light-scale.png` |
| expanded 浅/深 1.6 | 完整 1280×720 实际渲染帧，A/C/B | `/tmp/f9-frame-104621-0.png`、`/tmp/f9-frame-104621-1.png` |
| PID106532 重启管理页 | A/C/B、当前 B、actual waterfall | `/tmp/f9-final-restart-manage.png` |
| 新 PID 全局/设备/漫画下拉 | None/A/C/B，B 高亮，页面身份由审计 page:1/2/3 佐证 | `/tmp/f9-final-restart-global-menu.png`、`/tmp/f9-final-restart-device-menu.png`、`/tmp/f9-final-restart-comic-menu.png` |
| 新 PID 生产快捷面板 | 当前 B、Follow default、实际 Waterfall | `/tmp/f9-final-panel-light.png`、`/tmp/f9-final-panel-dark.png` |
| 新 PID 面板实际方案菜单 | None/A/C/B，B 高亮 | `/tmp/f9-final-panel-menu.png` |

X11 宿主实际只有 **1080×760**；expanded 不采用裁切的 X11 图，而用宿主 RepaintBoundary 在 release 后 800ms/endOfFrame 导出完整实际帧；实际窗口1280×720见 `/tmp/f9-final-expanded-window.txt`。无拼接/重绘。

前期 PID93813 的 compact 深色 GUI 还实际完成 Tab+Enter 上移 B、Tab+Space 下移 B，截图 `/tmp/f9-keyboard-up-focus.png`、`/tmp/f9-keyboard-enter.png`、`/tmp/f9-keyboard-down-focus.png`、`/tmp/f9-keyboard-space.png`。最终源码同操作在四种宽度/主题的 UI 回归中再次验证。

证据排除：前期 PID97911 曾因取证坐标误点模式菜单，改变了隔离 fixture；该次面板菜单图不作为通过证据。保留审计，TERM 后确认 `.bak` 与误点前 page:4 完整 settings 完全相同，恢复该隔离快照，再用最终源码 PID104621/106532 全部重拍。最终两个 PID 的验证摘要不含误点事件，也无数据手动修改。

## 构建、清理与复核入口

最终 GUI 构建：`/tmp/f9-gui-final-build.log`。GUI 完成后恢复正常入口：

```sh
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu \
  fvm flutter build linux --debug --no-pub -t lib/main.dart
```

正常构建成功，日志 `/tmp/f9-main-build.log`。`/tmp/f9-cleanup.log`：ps 无 venera-next；X11 仅保留原有 qq/Chromium clipboard 小窗口，无 F9 fixture；生产 bundle kernel 含 `package:venera_next/main.dart`、无 `f9_gui.dart`；7份实现/测试/翻译 SHA 全 MATCH。未停止原有 X11 服务；曾因沙箱看不到宿主显示而尝试的 Xvfb :1 启动失败，没有新增显示服务或待清理进程。

tasks 1.1–1.5 均已完成。本次最终三组测试命令合计 **525 通过、0失败、0skip**（F9 22 + B3相关304 + B4/F8保护199）；所有最终取证和正常构建后源码 SHA 未变。

建议 architect 先复跑上述 231/95/199 与 analyze 集合比较，检查保护 SHA、tasks、diff，再抽查 final-drag、final-compact-dark-scale、两张1280完整帧、PID106532管理页及面板菜单/继承截图。等待独立复核批准；不自行提交或归档推送。
