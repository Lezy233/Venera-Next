# F10 v2 阶段交付（D4未决，非全部完成）

历史阶段记录：owner随后已裁定各作者栏独立排序，当前契约为v2.1四件套/tasks3.x。下文D4未决与folder order写回证据仅对应当时v2，完整原件在history/v2-stage/delivery.md；本次新语义交付另写delivery-v2.1.md。

2026-11-06正式回传architect独立复核：2.1–2.5、2.8完成；2.6无冲突部分已实现和验证，但D4等待owner，2.6与2.7保持未勾选。本次收尾仅核对既有证据、更新本文/tasks/SHA，不重跑已满足测试、不改实现。未提交、归档或push。以下过程记录保留，最终命令、计数及GUI/构建/清理以文末阶段交付为准。

本轮HEAD为5977b8523b516893f70fb5fe660bef72cc524611，工作区v2工件四份与/tmp/f10-v2-artifacts.sha256核对全OK。v1授权脏改完整保留，开局跟踪补丁/tmp/f10-v2-executor-before.patch SHA256 55fa79e52312c26fee3fcb2083cf4e67e3d289c6e2c5bfea044d9ba058e7167f；未跟踪快照/tmp/f10-v2-untracked-before.tar SHA256 b3362b77a17c0ed60ffba2b8531d7c7823c4b6fc8d0bab036f5dce63d35efd48，逐文件清单/tmp/f10-v2-untracked-before.sha256，状态/tmp/f10-v2-executor-status.txt。不清空、不stash、不还原、不提交。

## 2.1 真实红灯

实际命令（环境统一为http(s)_proxy=http://127.0.0.1:7897、LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib、RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu）：

`fvm flutter test --no-pub test/features/favorites/author_shelf_ui_test.dart --reporter expanded > /tmp/f10-v2-red.log 2>&1`

1失败、0skip。生产LocalFavoritesPage文件夹Shelf，真实菜单坐标(1200.5,24)→(1143,203.5)，正确完成菜单和入队保存后断言共同作品在Alpha/Beta各显示一次：期望2 ComicTile、实际1。真实mainNavigator observer收到首页+菜单2次push，业务页面0；受控A/B来源请求均0。此前测试初始化、finder与settle失败已修正，不作为产品红灯。v1绿灯不复用。

待验证原因：平铺列表不能表达跨栏实例；v1首作者/独立rank不符合完整作者投影；三态组件及文件夹状态缺失。D4冲突分支等待architect工件更新，其余继续。

## 实现过程记录（历史轮次，最终结果见文末）

- 2.2已完成：新增author_shelf_model.dart及author_shelf.dart，用完整folder display_order投影全部作者，独立unknown与跨栏UI/hero身份；业务选择仍(id,type)。系列页v1入口撤回，与HEAD零diff；全部收藏不提供新模式。
- `/tmp/f10-v2-projection.log`：模型+原始生产入口8通过/0失败/0skip。
- `/tmp/f10-v2-interaction.log`：三态存储/真实三态按钮/左右Shift+PointerScrollEvent/父页邻栏隔离/clamp/松键纵滚/绑定源单次普通搜索，13通过/0失败/0skip。
- `/tmp/f10-v2-search-protection.log`：命令`fvm flutter test --no-pub test/features/favorites/author_shelf_model_test.dart test/features/favorites/author_shelf_storage_test.dart test/features/favorites/author_shelf_ui_test.dart test/features/favorites/creator_platform_names_test.dart test/features/favorites/creator_platform_names_view_test.dart test/features/search/search_target_memory_test.dart --reporter expanded`，55通过/0失败/0skip。面板生成后修改A当前默认值为other，点击实际使用other；同名B来源请求0，A请求1且SearchResultPage真实mainNavigator业务路由1，F8 memory不变。
- `/tmp/f10-v2-selection.log`：`fvm flutter test --no-pub test/features/favorites/author_shelf_ui_test.dart --reporter expanded`，1通过/0失败/0skip，补入右键Select后跨栏另一实例取消，计数1且业务路由0。
- 中间analyze曾55（原50+新增4条缺括号和1条unused import），随后定点修复；最终50的具体集合见文末。测试开发中初始化/finder/fake timer、带List的record身份比较、被appbar遮挡坐标、错误调用WidgetTester.ensureVisible(alignment:)均已修正，均不冒充产品红灯。实际SDK需Scrollable.ensureVisible(context, alignment:)；最终无missed tap告警。
- 无冲突子序列写回已加入，重叠检测走明确AuthorShelfPolicyPending临时边界，不代表采用任何D4最终规则；当前任务状态以本文开头与tasks为准。

后续进度以tasks当前记录为准：2.3/2.4已完成。`/tmp/f10-v2-states-final.log`16通过/0失败/0skip含8格390/1280浅深1/1.6长名布局、原库状态/全DB复制换目录、真实按钮SQLite失败保旧态/Retry、双Shift/正负clamp/原生横滚/松键纵滚；`/tmp/f10-v2-drag-lifecycle.log`24通过/0失败/0skip，命令`fvm flutter test --no-pub test/features/favorites/author_shelf_drag_test.dart --reporter expanded`，涵盖两布局长按/Escape/跨栏/拖动中CRUD与alias/销毁/真实中途SQLite失败回滚重试/上下来回替代及首项禁用/短击详情直读各实际路由1。短击目的类型通过实际push的AppPageRoute.builder确认，随后立即pop，不冒称装载了真实漫画后端。

滚轮probe唯一产品外根因已定位为harness缓存旧ScrollPosition：现有SmoothScrollProvider改变physics导致SDK替换position。`/tmp/f10-v2-wheel-probe-receivers.log`证明事件到达局部、两个Scrollable和父Smooth回调，`/tmp/f10-v2-parent-control.log`无shelf父层对照通过，`/tmp/f10-v2-wheel-live-position.log`证明replaced=true、旧pixels0、当前纵向pixels100。保留同事件序列/卡片内坐标和严格松键恢复断言，改为原ScrollableState当前position后通过；无共享scroll实现改动，已去除临时render listener包裹与额外等待。

v1未验收独立编辑页author_order_editor.dart及对应author_manual_order_ui_test.dart已由新shelf实现/模型/存储/布局/真实页面/长按矩阵替换；原件完整保留于开局/tmp/f10-v2-untracked-before.tar（逐文件SHA在对应清单）。原v1数据兼容与存储测试保留，不删改已验收测试。D4仍未裁定，2.6/最终交付不宣称完成。

2.5已完成：`fvm flutter test --no-pub test/features/favorites/author_shelf_ui_test.dart test/features/favorites/creator_platform_names_test.dart test/features/favorites/creator_platform_names_view_test.dart test/features/search/search_target_memory_test.dart --reporter expanded`，/tmp/f10-v2-search-final.log为43通过/0失败/0skip。完全复用F7生产Store/View/_search；面板展开零请求、同源多名/同名不同key、点击当下defaultOption变更、一次A路由/请求与B零请求/F8不改、卸载来源点击再验证及unknown空态均通过真实坐标和mainNavigator observer验证。

原库排序新增10项首跑8通过2失败，根因是测试错误预期原始SqliteException/AuthorShelfPolicyPending，现有_commitFavoriteTransaction包装为PersistenceFailure；核对实际cause与notCommitted后修正断言，未改事务产品实现或放松回滚/重试断言。结果见/tmp/f10-v2-order.log；D4临时pending边界仍不是最终冲突策略。

完整回归首跑/tmp/f10-v2-regression.log为785通过/13失败/0skip，除原2基线之外11项真实回归全部保留并定点修复：旧schema无shelf状态表的rename/delete应跳过不存在的新表；新适配器只在有效shelf模式读取完整成员，普通/已销毁文件夹沿既有缓存快照，防止改名删除后读旧表。未改旧测试；/tmp/f10-v2-regression-fix.log为184通过/2已知基线失败/0skip。最终完整复跑另记regression-final，首跑不冒称通过。

Architect GUI复核发现箭头左置违反既定栏头右侧契约：新增生产布局坐标断言，/tmp/f10-v2-arrow-red.log为0通过/1失败（右边界应390实际48）；移至栏头最右、作者名独立且保留本数，/tmp/f10-v2-arrow-green.log为40通过/0失败/0skip（8格布局+7状态+生产页+24拖动）。此前GUI PID62257和71089旧图均非最终图。

补齐键盘替代排序与Escape后短击/焦点断言时，初跑24通过2失败发现产品焦点回退：previousFocus为FocusScope时requestFocus会重新选择scope历史中的dragFocus。核对实际SDK后onDragEnd先unfocus(previouslyFocusedChild)移除拖动焦点，再恢复旧节点。/tmp/f10-v2-keyboard-final.log最终26通过/0失败/0skip，原mainNavigator计数不放宽。此前失败具体Expected页面FocusScope、Actual拖动FocusNode已记录，不把它归入基线。

GUI方案：X11实际宿主1080×760，fixture实际窗口1280×700；使用/tmp/f10_v2_gui.dart内整帧RepaintBoundary.toImage(pixelRatio:1)输出真实1280×700，逐张核对尺寸和view_image；宿主裁切截图不作为完整帧。helper/tmp/f10_v2_x11.py仅:1、title匹配F10 v2 fixture PID与/proc验证、实际鼠标坐标不得越过1080×760，按键/鼠标确保release。仅/tmp业务库、隔离XDG；正常main/runner未改。

## 2026-11-06阶段交付：最终命令与结果

HEAD仍为5977b8523b516893f70fb5fe660bef72cc524611；2026-11-06重新读取AGENTS/ROADMAP/v2四件套与本文，当前dirty全部保留。收尾前`sha256sum -c /tmp/f10-v2-final.sha256`全部OK，证明实现、测试和planner工件仍为上轮验证版本；本次只补文档，之后更新同一最终清单。开局三份契约proposal/design/spec仍匹配派工SHA；tasks是执行者按要求更新项，不能再拿其开局SHA要求零变化。

最终完整相关回归实际命令（环境沿前述proxy/native/Rust配置，全部--no-pub）：

```sh
f10_favorite_tests=($(rg --files test/features/favorites | rg '_test.dart$' | rg -v 'folder_order_ownership_test.dart$'))
fvm flutter test --no-pub "${f10_favorite_tests[@]}" \
  test/features/comic_widgets test/features/search \
  test/components/context_menu_test.dart \
  test/foundation/directory_replacement_test.dart \
  test/foundation/file_replacement_test.dart \
  test/foundation/directory_selection_test.dart --reporter expanded \
  > /tmp/f10-v2-regression-final.log 2>&1
```

结果：**800通过、2失败、0skip**，正常结束exit 1。唯一失败为folder_creation_presentation_test.dart中的`removed sidebar rejects a late Create Folder publication`与`removed sidebar rejects a late Sort publication`。两项HEAD失败依据保留在history/v1/delivery.md及review.md，本轮未修改、删弱或排除它们。`folder_order_ownership_test.dart`为已记录静态编译基线，明确未运行；它不是skip数，不借此排除其他新失败。范围包含完整收藏/系列/CRUD/身份/原排序、F7/F8、全部comic_widgets及B4的收藏命中/展示/拖动/搜索/context_menu保护文件；未把历史174直接作为本轮通过数。

最终新测试分项为model 7、storage 7、layout 8、order 10、production UI 1、drag 28，均通过且0skip（合计61，包含D4临时检测边界测试，不表示最终冲突政策验收）。最后新增两布局拖动期间真实文件夹改名，`fvm flutter test --no-pub test/features/favorites/author_shelf_drag_test.dart --reporter expanded > /tmp/f10-v2-drag-final.log 2>&1`为28通过；随后已纳入上述800完整回归。原库排序`author_shelf_order_test.dart`的/tmp/f10-v2-order.log为10通过。相关43项单源搜索保护、40项箭头/三态/布局/交互矩阵及各轮红绿日志见前文；最终源包含箭头右置、焦点恢复及两处真实回归修复。

F9/B3保护实际命令：

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
  test/features/reader/settings_effects_test.dart --reporter expanded \
  > /tmp/f10-v2-f9-b3-protection.log 2>&1
```

结果：**326通过、0失败、0skip**，未改原断言。

`fvm flutter analyze --no-pub > /tmp/f10-v2-analyze-final.log 2>&1`：**raw=unique=50=tool/code_audit38+其余12**，exit 1为基线问题。/tmp/f10-v2-validation.json保留完整50条具体诊断（含路径、位置、规则、消息）；与本轮已达50的progress.log逐条比较added=[]、removed=[]，诊断所在文件相对HEAD全部零diff。没有修无关基线。`python3 /tmp/f10_v2_verify.py`校验上述集合、全部保护及翻译并生成/tmp/f10-v2-final.sha256；这只是证据核对，不是重新执行测试/analyze。

## 最终GUI、真实重启与正常构建清理

最终harness为/tmp/f10_v2_gui.dart，helper为/tmp/f10_v2_x11.py；早期PID62257/71089图片不作最终证据。生产源码最终GUI为PID75523，真实重启PID80160，窗口均逐次核对标题`F10 v2 fixture PID <pid>`及/proc后才操作。harness使用生产LocalFavoritesPage/棚组件/F7 Store与View/真实mainNavigator observer，正常main/runner未为fixture修改；来源为无网络受控本地适配器，不声称真实平台内容命中。

```sh
fvm flutter build linux --debug --no-pub --target /tmp/f10_v2_gui.dart \
  > /tmp/f10-v2-gui-build.log 2>&1
env DISPLAY=:1 GDK_BACKEND=x11 \
  XDG_CONFIG_HOME=/tmp/f10-v2-xdg/config \
  XDG_DATA_HOME=/tmp/f10-v2-xdg/data \
  XDG_CACHE_HOME=/tmp/f10-v2-xdg/cache \
  build/linux/x64/debug/bundle/venera-next > /tmp/f10-v2-gui-run.log 2>&1
# 同命令真实重启，输出/tmp/f10-v2-gui-restart.log。
```

业务库仅/tmp/f10-v2-gui-data，cache仅/tmp/f10-v2-gui-cache。宿主1080×760；完整帧由实际1280×700或390×700的RepaintBoundary输出，PNG IHDR尺寸与capture日志再次核对。截图全部/tmp，所有下列图片已在动作release并稳定后逐张view_image，不是1080宿主裁切图。

| 场景 | 最终截图（均为/tmp/f10-v2-frame-前缀） |
|---|---|
| normal真实长按后1280浅色1 | 75523-1.png |
| 390浅色1折叠/左Shift横移 | 75523-2.png、75523-3.png |
| collapsed真实长按、双栏等高 | 75523-4.png |
| 松Shift恢复父纵滚、邻栏不动 | 75523-5.png |
| 1280深色1 / 深色1.6 | 75523-6.png、75523-7.png |
| 390深色1.6 / 深色1 | 75523-8.png、75523-9.png |
| 390浅色1.6 / 1280浅色1.6长名 | 75523-10.png、75523-11.png |
| expanded底部平台树/仅A普通搜索页 | 75523-12.png、75523-13.png |
| 重启前B collapsed / A expanded | 75523-14.png、75523-15.png |
| 新PID A expanded / B collapsed / A展开面板重现 | 80160-1.png、80160-2.png、80160-3.png |

原始动作与计数：normal及collapsed均在1280窗口实际坐标(600,165)长按拖到(180,165)，release后核对卡片和磁盘顺序。最终A顺序为Alpha2/Beta1/Alpha1/Beta2，Beta及B文件夹顺序不变。390右侧箭头(370,121)切态、作者名(180,121)独立切expanded；栏头零主路由。真实左右Shift滚轮命中卡片(180,200)，横移与clamp验证；松键后同坐标普通滚轮父纵53、Alpha横106、Beta横0。原始状态/顺序/controller坐标在/tmp/f10-v2-gui-75523.jsonl。

展开截图12前业务路由0、请求0；面板同源两名及A/B同名不同key、失效源保留disabled可见。F7快捷键仅在/tmp fixture改A当前默认为other，随后实际点击A的Bound name(180,326)，observer仅新增AppPageRoute一次（总业务page含首页为2）；只有`f10-a,text=Bound name,page=1,options=[other]`请求1次，B为0。截图13为生产SearchResultPage及受控结果。F8不写回与作者转换/聚合零扩散另由生产UI及既有F7/F8回归保护，不以旧configure回调0代替真实导航证据。

真实停止75523后重启80160；startup记录A/Alpha expanded、A/Beta collapsed、B/Alpha collapsed、B/Beta normal，顺序仍Alpha2/Beta1/Alpha1/Beta2。新PID真实切B/回A并滚到expanded面板，截图80160-1/2/3与/tmp/f10-v2-gui-80160.jsonl核对一致，新进程仅首页路由、0搜索请求。SQLite只读查询favorite_author_shelf_states亦为A Alpha expanded、A Beta collapsed、B Alpha collapsed，B Beta缺键按normal，未用manager重开冒充PID重启。

精确停止自己fixture的命令分别为`kill -TERM 62257`、`kill -TERM 71089`、`kill -TERM 75523`、`kill -TERM 80160`，未停止他人进程。最后恢复正常入口：

```sh
fvm flutter build linux --debug --no-pub > /tmp/f10-v2-main-build.log 2>&1
```

构建成功。bundle/data/flutter_assets/kernel_blob.bin SHA256为`e35ca53f484736fc246222ff479b8b325c370205645bd26ea29d3b2b75a3c8e7`，包含`package:venera_next/main.dart`，无`file:///tmp/f10_v2_gui.dart`及`F10 v2 fixture PID`。独立`ps -eo pid,comm,args`最终相关进程记录/tmp/f10-v2-final-processes.txt为无venera-next/dart/flutter_tester匹配；独立helper info显示fixtures=[]，2026-11-06收尾只读复查仍为空。architect随后启动的独立测试/analyze进程属于复核，不是fixture残留，本轮未停止它们。

## 保护、SHA与未决边界

`/tmp/f10-v2-validation.json`及`/tmp/f10-v2-final.sha256`列出全部当前改动/未跟踪文件最终SHA，包含本文与tasks；`sha256sum -c /tmp/f10-v2-final.sha256`供复核。planner的AGENTS/BACKLOG/ROADMAP及proposal/design/spec相对开局授权快照零新增diff；history/v1、根目录旧delivery/review、favorite_order.dart与旧存储测试逐文件SHA不变，五份Fake相对开局无新增改动。main/runner、pubspec.yaml/lock、design-spec、openspec/specs/**、共享comic_widgets及系列页相对HEAD零diff。CreatorPlatformNamesStore/View沿用既有实现；无依赖/lock变化。

新文案全部.tl；相对开局仅zh_CN/zh_TW各新增同一6词条，其他语言与既有词条零丢失/改值。`git diff --check`通过；`openspec validate --changes favorite-author-manual-order`为1通过0失败。当前源码/测试清单在最终SHA中，v1未验收独立编辑器/UI测试替换与原件快照依据见前文；未清理他人工作或修改已验收测试断言。

D4仍等待owner，当前冲突检测仅通过AuthorShelfPolicyPending阻止未裁定分支被误用，并未决定最终拒绝或共享联动策略。2.6不勾完，2.7因D7多作者冲突矩阵未满足保持未勾；2.8当前源码GUI/真实重启/正常构建/清理及阶段交付证据已满足并勾选。待architect更新D4后再实现对应政策和必要验证，不能把本阶段结果当F10全部完成或owner验收。此刻正式交付architect独立复核，未提交/归档/push，未启动其他change。
