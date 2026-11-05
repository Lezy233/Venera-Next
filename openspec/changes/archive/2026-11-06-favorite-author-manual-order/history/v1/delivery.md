# F10 executor 最终交付

基准 HEAD：`5977b8523b516893f70fb5fe660bef72cc524611`。开局工作区干净；保护树/SHA 为 `/tmp/f10-protected-head-tree.txt`、`/tmp/f10-protected-head.sha`。tasks 1.1–1.5 全部完成。未提交、归档或 push，未启动其他 change。Architect 已独立复核并写 review、更新待 owner 验收状态；executor 交付停止。

## 实现与范围

本地收藏 All、各文件夹、各系列新增 Author → manual order。沿用既有标签优先、首位有效作者及人工 alias；作者外序稳定升序、缺作者最后。类型化 scope 独立保存模式、生命周期 token 和完整 `(comic_id,comic_type)` rank，与旧 display_order 隔离。新增成员组末追加，改名迁移、删除重建重置、系列成员变化按归属清理。

编辑器先选择作者组，再编辑该视图的完整成员；支持真实拖动、上下移、Tab+Enter/Space、同身份焦点、首尾禁用。筛选隐藏成员仍参与完整组编辑，返回保持过滤。跨组移动由编辑范围限制并明确说明，不修改作者/作者外序。writer 捕获原目录、连接 generation、scope token、移动与相邻复合身份，入队后按最新成员/作者验证，仅事务更新当前组 rank。真实 SQLite 失败回滚、无 Saved、可 Retry；销毁/替换不伪成功或写新库。协调限定成员/作用域事务，普通已读/更新不扫描全库 rank。不调用远端排序 API。

Executor 改动清单：

- 新增 `lib/features/favorites/favorite_order.dart`、`author_order_editor.dart`。
- 局部修改同目录 `favorite_filters.dart`、`favorites_manager.dart`、`favorites_repository.dart`、`local_favorites_page.dart`、`local_favorite_series_page.dart`。
- `assets/translation.json` 简繁各新增7条，旧词条全部保持。
- 新增 `test/features/favorites/author_manual_order_storage_test.dart`、`author_manual_order_ui_test.dart`。
- 五份旧 Fake manager 测试仅增加 import 与 `orderScopeMode => null`：`comic_reorder_ownership_test.dart`、`favorite_confirmation_ownership_test.dart`、`favorite_metadata_ownership_test.dart`、`favorite_transfer_ownership_test.dart`、`folder_rename_ownership_test.dart`。原文案、行为、布局、ownership断言未删弱。
- 本 change 的 tasks/delivery。

proposal/design/delta spec、正式 specs、design-spec、main/runner、pubspec/lock及F8/F9/B3/B4等无关实现未由executor修改。未加依赖、重生成lock或修无关基线。冻结后 Architect 新增 `review.md`、更新 `AGENTS.md`、`openspec/BACKLOG.md`、`openspec/ROADMAP.md` 的4份改动属于 planner 授权文档，已保留，不是executor越界；未重跑旧允许清单或还原它们。

## 红灯、根因与修复

独立 HEAD 快照 `/tmp/f10-red-head` 由 `git archive HEAD` 重建，不曾清理主工作区。最终红灯命令（在该目录运行）：

```sh
LD_LIBRARY_PATH=/home/_Le/Code/Projects/Venera-Next/build/linux/x64/debug/bundle/lib \
  fvm flutter test --no-pub test/features/favorites/author_manual_order_ui_test.dart
```

`/tmp/f10-red-actual-route.log`：0通过/2项预期失败/0skip。真实收藏 Manual 菜单缺新模式，系列缺 Sort。失败前核对具体作品坐标、`(same,0)/(same,31)/(beta,0)`，接通真实 mainNavigator 的 route observer，详情/直读计数0。旧 configure 回调0不作为 LocalFavorites 主动作的独立证明。

实现中新增回归抓住并修复：

1. rank DELETE 覆盖 db.updatedRows，作品已删却漏回执/通知：立即捕获作品DELETE结果；有rank/无rank两分支及原post-commit observer、待阅读计数断言均通过。
2. 未改排序也await新SQLite，改变过滤保存入队顺序：仅模式变化才写scope，整个保存保持原数据访问归属；原页面销毁/布局7项通过。
3. 真拖动中改名令主视图读旧scope：失效scope返回空成员；变更取消拖动并反馈，落位仍验证原身份。
4. 作者下拉自身弹层令canPresent禁用回调：真实Beta选择红灯 `/tmp/f10-group-selection-probe.log` 为0通过/1失败；仅本地组选择改按原route active与原库归属，排序写入仍严格验证；三个UI场景现均真实切Beta、单项两端禁用。

脚手架初始化、单次位移未完成拖动识别、fake-async等待、Tags文字不可点击及Row导入歧义均已纠正，不当作能力通过证据。真实手势未替换为回调；最终Tags测试点击实际Expand IconButton和FilterChip，并断言未选中→选中。

## 完整命令与计数

环境统一，所有Flutter test/analyze/build均 `--no-pub`：

```sh
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
export LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib
```

完整相关回归：

```sh
f10_favorite_tests=($(rg --files test/features/favorites | rg '_test.dart$' | rg -v 'folder_order_ownership_test.dart$'))
fvm flutter test --no-pub "${f10_favorite_tests[@]}" \
  test/features/comic_widgets test/features/search \
  test/components/context_menu_test.dart \
  test/foundation/directory_replacement_test.dart \
  test/foundation/file_replacement_test.dart \
  test/foundation/directory_selection_test.dart --reporter expanded
```

最终 `/tmp/f10-regression-group-final.log`：**759通过/2项HEAD既有失败/0skip**，正常结束。前轮 `/tmp/f10-regression-final.log`同为759/2/0；`/tmp/f10-favorites-regression-fixed.log`为扩展用例前752/2/0。原失败日志 `/tmp/f10-favorites-regression.log` 保留（520/228后挂起，已停止），不当作通过证据。

唯一剩余失败均在 `folder_creation_presentation_test.dart`：

- `removed sidebar rejects a late Create Folder publication`
- `removed sidebar rejects a late Sort publication`

独立HEAD对照（工作目录 `/tmp/f10-red-head`）：

```sh
fvm flutter test --no-pub \
  test/features/favorites/favorites_manager_test.dart \
  test/features/favorites/favorites_settings_persistence_test.dart \
  test/features/favorites/read_later_test.dart \
  test/features/favorites/folder_creation_presentation_test.dart \
  test/features/favorites/favorites_view_persistence_test.dart --reporter expanded
```

`/tmp/f10-head-baseline-failures.log`：103通过/上述同名2失败/0skip。未将其他本change失败排除。`folder_order_ownership_test.dart` 因原编译错误未纳入完整命令，仍属原analyze50基线；未修改或skip其断言。

核心及最终实际路由增强：

```sh
fvm flutter test --no-pub \
  test/features/favorites/author_manual_order_ui_test.dart \
  test/features/favorites/author_manual_order_storage_test.dart \
  test/features/favorites/favorites_view_persistence_test.dart
fvm flutter test --no-pub test/features/favorites/author_manual_order_ui_test.dart
```

第一条 `/tmp/f10-core-group-fixed.log`：**42通过/0失败/0skip**（20 F10 UI + 15存储 + 原7保存）。第二条 `/tmp/f10-ui-route-count.log`：**20通过/0失败/0skip**，接通真实mainNavigator，观察实际ComicPage/ReaderWithLoading/ComicReadingPage路由。最终以真实route计数为准；旧configure回调0不独立证明LocalFavorites。Observer仅增强测试和/tmp宿主，format/analyze已复核并更新冻结SHA，未改生产实现。Architect独立 `/tmp/f10-architect-core.log`71通过/0失败/0skip（Architect报告）。

F9/B3保护：

```sh
fvm flutter test --no-pub \
  test/foundation/reader_preset_ordering_test.dart \
  test/features/settings/reader_preset_ordering_test.dart \
  test/foundation/reader_presets_test.dart \
  test/foundation/reader_preset_binding_test.dart \
  test/foundation/reader_preset_inheritance_test.dart \
  test/foundation/reader_preset_recovery_test.dart \
  test/foundation/appdata_admission_test.dart test/foundation/appdata_test.dart \
  test/features/settings/reader_presets_test.dart \
  test/features/settings/reader_settings_persistence_test.dart \
  test/features/settings/reader_side_margin_test.dart \
  test/features/reader/quick_settings_panel_test.dart \
  test/components/settings_save_feedback_test.dart \
  test/components/settings_save_host_test.dart \
  test/foundation/reader_settings_snapshot_test.dart \
  test/foundation/reader_preference_store_test.dart \
  test/foundation/reader_mode_settings_test.dart \
  test/foundation/reader_gesture_settings_test.dart \
  test/features/reader/automatic_reader_mode_test.dart \
  test/features/reader/layout_detection_test.dart \
  test/features/reader/settings_effects_test.dart --reporter expanded
```

`/tmp/f10-f9-b3-protection.log`：**326通过/0失败/0skip**，原断言保持。

## D6矩阵

| 场景 | 最终证据 |
|---|---|
| 生产缺失能力红灯 | red-actual-route日志，真实控件、完整身份/坐标、实际route0 |
| 作者归组 | 存储15项：标签优先/首位/alias/空白大小写/缺作者/同id不同type；UI真实Alpha→Beta |
| scope/模式保持 | typed scopes；compact选择→Confirm→重开、旧模式往返、旧异步结果不污染新folder/series；GUI两新模式不同序及新PID |
| 输入/副作用 | 真pointer拖动、上下移、Tab+Enter/Space、同身份焦点、首尾禁用、组内限制；真实mainNavigator route0 |
| 筛选/CRUD | 真FilterChip隐藏(same,31)，完整组仍可编辑；返回保留过滤与隐藏顺序；新增组末、删除重加、改名/重建、series成员/alias |
| 并发/失败/生命周期 | 拖动按下期间真实新增/删除/改名/作者/alias写入；排队变更；SQLite触发器中途拒写/回滚/Retry；强制销毁；真实新目录新库拒旧操作；整库备份恢复 |
| 回归/UI | 完整收藏/F7/B4/F8、F9/B3保护；390与实际1280浅深1.6长名无新增溢出 |

## Analyze、保护与冻结

`fvm flutter analyze --no-pub`，最终 `/tmp/f10-analyze-freeze.log`：**raw=unique=50=tool/code_audit38+其余12**。与 `/tmp/f9-architect-analyze.log` 逐条具体集合added=[]、removed=[]。前一版analyze-final实际59项，新增8条大括号/1条context已仅在本change修正；未把59误称50。

`/tmp/f10_verify.cjs`、`/tmp/f10-validation-freeze.json`：冻结时HEAD不变、executor允许清单外forbidden=[]、旧翻译lostTranslations=[]、简繁各新增7项、git diff --check通过，含源码/测试SHA。Observer测试增强后已format/analyze并更新报告；此后只有executor tasks/delivery及前述planner授权4份文档变化。未因旧清单还原planner改动。脚本沙箱spawn只读git遇EPERM后按流程授权重跑成功，无绕过权限。

## 最终GUI证据索引

临时宿主 `/tmp/f10_gui.dart` 使用生产收藏/系列/编辑器，ensureInitialized/show；正常main/runner未为fixture修改。业务库 `/tmp/f10-gui-data`、cache `/tmp/f10-gui-cache`；隔离XDG `/tmp/f10-xdg/{config,data,cache}`。已读核对helper `/tmp/f10_x11.py`仅匹配F10标题、DISPLAY=:1及/tmp/f10图片；按键间flush等待，鼠标release后稳定，逐图view_image。

```sh
RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu \
  fvm flutter build linux --debug --no-pub --target /tmp/f10_gui.dart
env DISPLAY=:1 GDK_BACKEND=x11 \
  XDG_CONFIG_HOME=/tmp/f10-xdg/config XDG_DATA_HOME=/tmp/f10-xdg/data \
  XDG_CACHE_HOME=/tmp/f10-xdg/cache build/linux/x64/debug/bundle/venera-next
```

生产版本构建 `/tmp/f10-gui-final-build2.log`，仅/tmp宿主增强observer的构建 `/tmp/f10-gui-observer-build.log`。生产源码期间未改。

| 场景 | 有效证据 |
|---|---|
| 真拖动复合身份 | `/tmp/f10-final2-a-drag.png`，PID871803 |
| 真选择Beta/单项首尾禁用 | `/tmp/f10-final2-beta.png`，自身弹层问题修复后 |
| Alpha按钮/键盘三项序 | `/tmp/f10-final2-alpha-button-down.png`=0/31/3；`/tmp/f10-final2-alpha-keyboard-enter.png`=31/0/3；`/tmp/f10-final2-alpha-keyboard-space.png`=0/31/3，逐图及audit对照 |
| 实际route observer下Alpha动作 | `/tmp/f10-final3-a-route-keyboard.png`、`/tmp/f10-final3-a-main.png`，PID882305，按钮/Tab+Enter后31/0/3 |
| 同名series也选新模式存不同序 | `/tmp/f10-final3-series-mode-menu.png`、`/tmp/f10-final3-series-editor.png`、`/tmp/f10-final3-series-main.png`，PID882305，series为3/31/0 |
| B/All保持 | `/tmp/f10-final3-b-unchanged.png`、`/tmp/f10-final3-all-unchanged.png` |
| 390浅深1.6长名 | `/tmp/f10-final2-compact-dark16-alpha.png`、`/tmp/f10-final2-compact-light16-alpha.png` |
| 1280×740浅深1.6完整实际帧 | `/tmp/f10-frame-871803-0.png`、`/tmp/f10-frame-871803-1.png`；RepaintBoundary输出并核对PNG尺寸。1080宿主裁切locator图不冒充完整1280 |
| 两份新模式真实重启 | PID882305退出→887436；`/tmp/f10-final-restart-a.png`、`/tmp/f10-final-restart-series.png`。A=authorManual、31/0/3；同名series=authorManual、3/31/0；B/All不变 |

`/tmp/f10-gui-audit.jsonl`、解析脚本 `/tmp/f10_gui_evidence.cjs`、`/tmp/f10-gui-validation-final.json`：PID882305/887436共13个actualRouteObserver事件，实际主动作0；两新模式不同序、身份/作者/标签及完整重启状态一致，B/All不变，failures=[]。PID871803旧configure计数不独立证明LocalFavorites。`/tmp/f10-final2-a-keyboard.png`实际仍Beta，明确作废；早期PID504809/859637及旧final-*图不计最终证据。

日志 `/tmp/f10-gui-final-run2.log`、`/tmp/f10-gui-final-run3.log`、`/tmp/f10-gui-final-restart.log`无Flutter exception/overflow，仅宿主Mesa/GTK初始化警告。仅证明受控数据排序语义，不宣称网络平台验证。截图全部/tmp，未入库。

## main恢复、清理与交接

```sh
RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu \
  fvm flutter build linux --debug --no-pub
```

`/tmp/f10-main-build.log`正常main构建成功。最终fixture PID887436已关闭。Architect独立确认kernel仅含package:venera_next/main.dart、无f10_gui；宿主ps无venera-next/f10，X11仅原qq与Chromium clipboard小窗。没有fixture运行进程遗留，不重复清理历史PID。

Architect已完成独立复核并新增review、维护待owner验收状态。按最后指令仅完成tasks1.5/delivery后停止，未扩验证、提交、归档或push。
