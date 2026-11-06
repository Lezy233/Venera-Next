# F11 executor 交付与architect收尾

开局HEAD `31b38e07d8c0df1ed9b424aaa67c0cc081176408`，工作区干净；先读AGENTS，再ROADMAP、change四件套、design-spec及指定UI/诊断技能。无提交、归档或push，不启动其他change。tasks1.1–1.5已完成；executor在GUI收尾时触发用量限制，architect随后仅完成独立GUI验收、正常构建恢复和清理，没有改动实现或测试。最终以本文末尾收尾记录和review.md为准，前文阶段/剩余项保留历史语境。

## 改动及根因

- `favorites_page.dart` 页面拥有三组导航偏好，常驻侧栏及窄窗选择器共享同一ValueNotifier；复用SettingsSaveState保存、失败Retry、离页/窗口等待。选择器也显示现有保存失败反馈。
- `sidebar_sections.dart`：`implicitData['favoritesSidebarSections']`为`{local:bool,series:bool,network:bool}`，默认true，坏整体/坏单项独立回退；事务合并未知字段，完整最终意图快照串行保存，不覆盖其他implicitData。
- `side_bar.dart`：标题主体与管理动作独立命中；组级焦点、键盘、expanded/selected语义；当前摘要按有效系列id/来源key/本地身份判断。仅移除该组导航子项，内容key及业务实现未变。
- 文案全部复用已有`.tl`：Local/Series/Network/All/Expand/Collapse/Settings，无新翻译key，未修改translation.json。

## 红绿和基线

所有Flutter命令均`--no-pub`，固定环境：
```sh
env https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897 LD_LIBRARY_PATH=/home/_Le/Code/Projects/Venera-Next/build/linux/x64/debug/bundle/lib fvm flutter test --no-pub test/features/favorites/sidebar_sections_test.dart --reporter expanded
```

- 真实坐标红灯：`/tmp/f11-red.log`，0通过1失败，点击生产Local文字中心后A仍存在；非fixture初始化错误。
- 首个真实坐标绿灯：`/tmp/f11-green-first2.log`，1通过0失败0skip。
- 最终独立新增：上列命令重定向`/tmp/f11-sections-final.log`，26通过0失败0skip。覆盖三组、文本/箭头、键盘/焦点、菜单与设置、当前All/同名系列/网络、真实内容实例/两项选择/筛选/滚动/Escape、网络计数、真实磁盘doInit重载、失败Retry、离页窗口等待、窄窗关闭及八格UI矩阵。
- 相关HEAD基线：`/tmp/f11-baseline-test.log`，favorites_view_persistence、favorites_settings_persistence、favorite_series、folder_creation_presentation四文件：45通过2失败0skip；失败严格为folder_creation两项`removed sidebar rejects a late Create Folder publication` / `removed sidebar rejects a late Sort publication`。
- 受影响14文件首轮：`/tmp/f11-regression.log`，139通过1失败0skip，其中114项原相关回归通过；唯一失败为新增窄窗精确动画时序，已在独立26项最终运行修正验证。没有把首轮冒称最终全绿。architect独立冻结源码14文件集合`/tmp/f11-architect-regression.log`最终140通过0失败0skip（26新增+114原相关），已由architect回报读核；源码未变，不重复该集合。
- 初期新增测试编译差异（SemanticsFlags/Tristate、MenuButton导入、Tooltip nullable）均单列为测试构建错误，未冒称行为红灯。已用四文件静态检查集中清除，`/tmp/f11-changed-analyze-final.log`零问题。

## 窄窗失败诊断证据

具体失败是Retry保存屏障挂起时，Close后`findsNothing`仍找到原选择器。探针`/tmp/f11-close-probe5.log`记录：同一路由`isCurrent=false,isActive=false,animation=0,status=reverse,overlay=[true,true]`；真实异步让出无效。本地SDK`packages/flutter/lib/src/animation/animation_controller.dart:993`：`_InterpolationSimulation.isDone(time) => time > duration`；`widgets/routes.dart`只在dismissed状态finalize。因此恰好结束时值为0但status仍reverse，不是存储保留已退出overlay，也不是产品关闭失败。

最终测试使用route真实reverseTransitionDuration，断言route非active、选择器不可命中，再推进1微秒越过SDK严格边界并清理帧，仍严格断言最终移除且保存尚挂起；release后等待保存并断言磁盘最终local=false、无Retry、无异常。单例`/tmp/f11-close-green.log`1通过；完整最终26通过。已删除全部诊断探针，无生产契约/断言语义取舍。

## analyze / 保护

- 固定env + `fvm flutter analyze --no-pub`：`/tmp/f11-baseline-analyze.log`与`/tmp/f11-final-analyze.log`均raw/unique50=38tool+12其余，具体集合added=[] removed=[]，`/tmp/f11-analyze-comparison.json`保存完整双方集合；architect独立同结果`/tmp/f11-architect-analyze-comparison.json`。
- `git diff --exit-code HEAD -- design-spec.md openspec/specs pubspec.yaml pubspec.lock openspec/changes/archive openspec/changes/favorites-sidebar-section-collapse/proposal.md openspec/changes/favorites-sidebar-section-collapse/design.md openspec/changes/favorites-sidebar-section-collapse/specs`退出0。原B4/F10/B5业务实现无diff。
- `git diff --check`、`sha256sum -c /tmp/f11-source.sha256`四项、`openspec validate --changes favorites-sidebar-section-collapse`（1 passed,0 failed）均通过。
- B4/F10原相关包含在architect最终140集合内；另运行`test/features/reader/page_layout_test.dart test/features/reader/layout_detection_test.dart test/features/reader/comic_layout_test.dart`，日志`/tmp/f11-b5-protection.log`42通过0失败0skip。这是三文件阅读布局保护，**不是B5 gallery像素17项**，未冒称重跑该像素集。
- 指定基线复验`folder_creation_presentation_test.dart folder_order_ownership_test.dart`：`/tmp/f11-known-baselines.log`原始20通过4失败0skip，其中2项既有folder_creation业务失败、1项folder_order_ownership:146 nullable onReorder编译失败、1项由并行编译器退出派生的folder_creation loading错误；该文件后续20业务通过和2业务失败仍完整执行。没有将4项冒称4个业务失败，也不吞新失败，不改旧断言。开局该业务文件在基线45通过2失败集合中已确认两项失败。

## 冻结源码 SHA256

```
39436767bb25522c684ebc534b9f080e6e67f5014a56e9157bb4189795f7b312  lib/features/favorites/favorites_page.dart
90ee1dc1004fa3d91afb5a7ea340c5af2290c5061945cb8a4df4087f907837ec  lib/features/favorites/side_bar.dart
1b29976e1fdc002937602b67bf57258f974864647afce56b42751af831460b8b  lib/features/favorites/sidebar_sections.dart
9044c8782b4a9ad3a83771d362233fefd2c1548a286dbb0ff46ceade7e64270d  test/features/favorites/sidebar_sections_test.dart
```

## GUI阶段证据与剩余项

- harness仅`/tmp/f11_gui.dart`，SHA `b85099cf20d21e5fd7de2db157a90ec1296d734e7b3312d65883e299dfdf1c08`；生产FavoritesPage、真实侧栏、windowManager.ensureInitialized/show，未修改main/runner。
- 已全文读核批准helper `/tmp/f11_x11.py` SHA `677ca58d55e9ea4a8d0ae05ef804499cb804cb72721ddcb79dd011b6a7eb944e`；限定本轮title/PID/proc exe/fixture标志，坐标窗口+宿主预检，键白名单，finally释放。脚本若修改先重报SHA并获读核。
- GUI构建：固定env另加`RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu fvm flutter build linux --debug --no-pub --target /tmp/f11_gui.dart`，`/tmp/f11-gui-build.log`成功。
- 启动：`env DISPLAY=:1 GDK_BACKEND=x11 F11_FIXTURE=1 XDG_CONFIG_HOME=/tmp/f11-gui/xdg-config XDG_DATA_HOME=/tmp/f11-gui/xdg-data XDG_CACHE_HOME=/tmp/f11-gui/xdg-cache build/linux/x64/debug/bundle/venera-next`，业务/cache也显式为/tmp/f11-gui/business与cache；日志`/tmp/f11-gui-run.log`。
- helper命令形态`env DISPLAY=:1 python3 /tmp/f11_x11.py <info|click x y|key 白名单键|resize 1280 800或390 800|capture 名称>`。输入后分步稳定、F12完整RepaintBoundary截帧并逐图读核。
- 宿主X11真实1080×760，窗口实际1280×800及390×800已确认。`frame-*.png`为完整RepaintBoundary，`x11-*.png`受宿主裁切，不冒称完整X11。
- 已读核frame0浅色展开、frame1浅色当前组折叠摘要/内容保持、frame2深色当前组折叠、frame3深色390内容、frame5深色窄窗共享折叠摘要、frame6窄窗展开不关闭、frame7真实本地菜单独立命中且不改变当前内容。截图全部仅/tmp。
- 剩余：GUI两项真实多选保持与Escape/主题、大文字与键盘焦点、真实进程关闭重启从文件恢复；正常main构建恢复、停止自身fixture并ps/X11清理；完整保护/OpenSpec/analyze集合与1.4/1.5最终备注。

## Architect最终收尾（已完成）

旧/tmp临时脚本、日志、截图已被清理，不能再以旧路径作为现存证据。源码四项SHA与前轮冻结值全部一致；architect复用此前已全文核对、kernel内仍含file:///tmp/f11_gui.dart与固定标题的既有GUI二进制重留证据，没有改生产main/runner。重建的独立验收helper为/tmp/f11_x11.py，SHA `374c761603d6eebb505f3dc747b2aa770d39871da31a05b5566ae92c29ff3148`，固定标题/PID/exe/环境标志、命令白名单、窗口及宿主坐标检查、按键和鼠标finally释放；只操作自身进程。

新GUI进程PID106449，真实1280×800与390×800，宿主仍1080×760；两种尺寸均通过xwininfo核对。每次真实输入后等稳定再截帧、逐张view_image。`/tmp/f11-gui/review-before-restart/frame-*.png`为完整RepaintBoundary导出，非完整X11宿主截图：

- frame1：长按真实首张漫画，选择1项；frame2：真实第二张点击后选择2项。
- frame3：点击本地标题收起后仍选择2项，首两卡选中态、内容及当前文件夹摘要保持。
- frame4：深色同样保持两项；frame5：Escape退出多选、原文件夹和折叠保持。Escape后主动作恢复由本轮已通过的B4 favorite_hit_target相关测试现有真实坐标/route次数断言保护，未冒称GUI点击真实书籍详情。
- frame7：390窄窗选择器保持同一折叠状态与摘要。`/tmp/f11-gui/x11-narrow-menu.png`是实际X11窗口图，显示新建文件夹/排序菜单，收起状态与选择器保持；其底部受宿主高度限制，未冒称完整宿主。截图键会影响菜单状态，因此此菜单使用无输入的外部截图，未把仅hover的frame6当菜单打开证据。
- frame9/10：实际Tab聚焦组头，Right展开、Left收起；焦点细线可见，子项显隐正确。
- frame11/12：深色1.6文字内容及繁体窄窗选择器，无overflow，摘要和独立菜单可用；减少动画由harness显式启用。
- frame13：本地/系列均收起、网络展开。真实已保存文件/tmp/f11-review-before-restart.json为local=false/series=false/network=true。

确认磁盘稳定后，仅核对并终止自身PID106449，再以同一隔离业务/cache/XDG目录重启得到PID112612。`/tmp/f11-gui/frame-0.png`为新进程启动完整帧：本地/系列收起、网络展开，当前内容保持；重启前后implicitData文件cmp退出0。此验证是稳定落盘后的进程终止/重启，不冒称有未完成保存时的GUI优雅退出；未完成保存的窗口等待由自动化覆盖。

GUI无真实已安装网络来源，未进行真实平台请求/账号操作；网络身份与请求次数由生产组件受控来源自动化覆盖。未验证owner实际收藏库，封面使用受控空路径占位；这不替代分组交互的真实命中证据。

随后核对并停自身PID112612。`fvm flutter build linux --debug --no-pub`无target正常main构建成功，日志/tmp/f11-review-main-build.log；最终kernel包含package:venera_next/main.dart且无f11_gui.dart，SHA `296ad3d097a443e52db171ab67b4b8eac80d877bd7b8a2d5c3f0fd1d284b6f47`。ps两PID均无输出，X11只余原qq/Chromium clipboard窗口，未动其他程序。

因旧临时日志清理，architect同冻结SHA重新保留14文件相关回归：/tmp/f11-review-regression.log，140通过0失败0skip（含26新增，不累加）。完整analyze /tmp/f11-review-analyze.log仍raw/unique50=38+12；前轮独立具体集合added=[] removed=[]已确认，冻结后未改源码。新完整诊断持久化于reviewed-analyze.json，四源码SHA于reviewed-files.json。protected零diff、diffcheck和OpenSpec复核通过，最终等待owner人工验收，未提交、归档或push。
