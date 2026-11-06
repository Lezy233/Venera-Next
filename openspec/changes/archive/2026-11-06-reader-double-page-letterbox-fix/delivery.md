# B5 executor 阶段证据

- 执行身份：w4:p2；architect w4:p1。
- 派工 HEAD：`b4a27060d9a2615d8dc948024521de8d38bf44fc`；开局 `git status --short` 空，未提交、未归档、未推送。
- 已读 AGENTS、ROADMAP、四件套、design-spec §1/2/4/7.4、diagnosing-bugs、ui-ux-pro-max、Herdr 技能；根目录无 CONTEXT.md。
- Phase 1 进行中：从已有 gallery_input_test 的公开生产组件与真实文件解码路径构造受控四边标记像素对照；尚未声称复现或推断根因。
- 环境：已知 pdfrx_engine 缓存四处 `cache!` 补丁在开局已存在，本轮未修改。

## Phase 1 实测（未修复）

- `/tmp/b5_full_viewport_test.dart`：3窗口(1280×700、800×600、390×700) × 3原图(600×900、800×1000、1200×800) × 单/双 = 18通过、0失败、0skip，日志 `/tmp/b5-pixels-matched.log`。四边标记真实解码；oracle按每图可用区域等比contain计算必要留白，误差1.5px。
- 第一版仅setSurfaceSize而未同步MediaQuery造成harness假红，已排除，不能计入产品证据；日志 `/tmp/b5-pixels-first.log` 仅供追溯。
- 人工减宽240探针 `/tmp/b5_render_test.dart` 10通过2失败，仅为探针，800窗也强制减宽不符合生产900阈值，不作为产品红灯。
- 真实外围 `/tmp/b5_shell_render_test.dart` 接 `ReaderScaffold` + `ReaderThumbnailsView` + `ReaderGalleryView`，未模拟栏尺寸。GlobalPreferenceStore读取默认readerThumbnailWidth=240，设置expanded/fixed/left（均生产支持配置），1280×700，实测缩略图Rect(0,0,240,700)，gallery Rect(240,0,1280,700)，gallery内部MediaQuery=1280×700。600×900原图四边标记/网格，单面正对照通过：top y0..8/bottom y691..699；双面红灯：top y66..72/bottom y627..633，必要留白oracle=0。1通过1失败0skip，日志 `/tmp/b5-shell-red.log`，命令 `fvm flutter test --no-pub /tmp/b5_shell_render_test.dart --reporter expanded`（先按派工export代理/LD_LIBRARY_PATH）。截图 `/tmp/b5-shell-1280-600-{1,2}.png`，已逐张view_image，大小1040×700，非X11截图。
- harness首次缺Material宿主导致Slider异常，补Material重跑后上述单面对照无异常；不将初始化异常计产品红灯。
- 这是生产支持配置下的受控复现；缺owner原图/原窗口/原缩略图设置，不能宣称已还原owner原始输入。

## Phase 3 待验证假设（先列后探针）

1. 窗口MediaQuery被当作双面内容尺寸：预测固定栏改变实际约束但不改变MediaQuery时出现双重缩小；折叠/浮动恢复，使用真实约束可消除额外留白。
2. 壳层栏覆盖/额外扣高：预测单面亦受影响或gallery高度小于700，像素出现裁切/覆盖；实测边界可否定。
3. 双面解码或ComicImage适配错误：预测原图尺寸/四边缺失、匹配viewport仍错误；保持同一解码输入仅改变外围可否定。
4. PhotoView初始缩放/重建残留：预测新建与模式切换/稳定等待结果不同；重复挂载、稳定帧和resize检验。

生产代码仍零修改；1.1尚未完成，继续真实外围单变量对照和最小化。

## 单变量验证

`/tmp/b5_shell_render_test.dart` 仅变缩略图状态/模式/位置，保持同图、窗口、主题、解码链与gallery生产实现：10项=8通过2失败0skip（`/tmp/b5-shell-probes.log`）。固定左/右展开双面均y66..633；同配置单面均y0..699；折叠左栏、浮动左栏双面均y0..699；固定底栏实际viewport1280×560、双面y0..559。实际每个栏位置/尺寸与gallery的MediaQuery均输出日志。内容边界不被栏覆盖，图片四边存在；改变外围即可使同解码输入红/绿，排除源图黑边与解码错误。固定底栏可正确用满高度，排除统一padding扣高。

已定位直接依赖：本项目packages/photo_view的CustomChildWrapper以`childSize ?? outerSize`求ScaleBoundaries；外层PhotoView的LayoutBuilder从实际constraints求outerSize。gallery双面传入窗口MediaQuery作childSize，内层图片先在窗口大小中contain，再由PhotoView将整窗口缩入缩略图挤占后的阅读区域。例1280×700→1040×700，额外缩放0.8125，导致图片原700高降为568.75，形成上下65.625px。不是库自身忽略约束；将gallery该参数交回默认outerSize即可单变量验证，不改图片适配/设置/共享ComicImage或第三方库。

## 最小修复与红绿

- 生产仅`gallery_view.dart`双面`PhotoView.customChild`删除`childSize: MediaQuery.sizeOf(context)`，说明默认使用实际viewport；保留contain、min/max scale、原图、配置、页布局及共享ComicImage不变。未改库。
- 正式`test/features/reader/gallery_viewport_rendering_test.dart`实际ReaderScaffold+真实文件解码+最终RGBA四边边界，修复前10通过7失败0skip (`/tmp/b5-regression-red.log`)，修复后17通过0失败0skip (`/tmp/b5-regression-green.log`)。
- 同原始外围探针命令修复后10通过0失败0skip (`/tmp/b5-shell-green.log`)，固定侧栏双面scale=1.0、top y0..8/bottom y691..699；单面不变。其余必要留白按原比例仍保留。原始Phase1命令验证完成。
- 正式17项包含两主题×左右/底固定栏×单/双(12)、折叠/浮动(2)、三方向首图/异比配对/跨页独占/奇尾/resize800×600、390×700、1280×700/返回(3)。同项chrome开/关和每槽四边真实像素均检验；文本1.6、减少动画；未把这些子场景虚增为测试项计数。
- 生产与正式测试已format；按architect独立复核要求暂冻结这两文件，后续若改将先报告使旧复核结果作废。
- GUI宿主只读实测`DISPLAY=:1 xwininfo -root`为1080×760/16bit，不能把宿主裁切图宣称完整1280。将用真实1280内容RepaintBoundary另导出完整帧并明确区分。

- Architect独立复核：148通过0失败0skip、两文件SHA MATCH；独立analyze发现新增info `gallery_viewport_rendering_test.dart:1:8 unnecessary_import`。已按architect明确批准仅移除测试首行`dart:async`导入，这是冻结后唯一源码调整，生产/测试断言未改；按要求只重跑新增17和analyze，不重跑148。

## 1.3 自动化与保护（已完成）

- executor完整相关集合148通过0失败0skip：`/tmp/b5-related-tests.log`。命令：`fvm flutter test --no-pub test/features/reader/gallery_viewport_rendering_test.dart test/features/reader/gallery_input_test.dart test/features/reader/dual_page_split_test.dart test/features/reader/page_layout_test.dart test/features/reader/page_navigation_test.dart test/features/reader/continuous_input_test.dart test/features/reader/shell_presentation_test.dart test/features/reader/thumbnails_test.dart test/foundation/reader_preset_binding_test.dart test/foundation/reader_preset_inheritance_test.dart test/foundation/reader_preset_ordering_test.dart --reporter expanded`。其中新增17，原相关131。没有扩大到无关folder_creation_presentation两项已知失败，也未运行包含folder_order_ownership编译基线的全量测试；上述选定集合无排除/skip。
- import清理后仅重跑新增17通过0失败0skip：`/tmp/b5-regression-final.log`，不无故重跑148。
- `fvm flutter analyze --no-pub`：修改前`/tmp/b5-analyze-before.log`，最终`/tmp/b5-analyze-after.log`；完整逐项前后集合保存在`/tmp/b5-analyze-comparison.json`，raw/unique50=38tool+12其他，added=[] removed=[]。没有修任何基线问题。
- architect独立复跑148通过及SHA匹配；最终import清理后17再次全绿，独立analyze raw/unique50=38+12，added=[] removed=[]，证据`/tmp/b5-architect-new-final.log`、`/tmp/b5-architect-analyze-final-comparison.json`。
- 生产SHA256 `bf3a6995ee5716c9ac03ddb7a09f2085ff8945a704b5ee1483dbff41ae7a56f5`；正式测试SHA256 `33325350105627b2c062cea06dd75499cdcd9e35615601ad0fbef2b0895d95d3`。
- `git diff --check`、protected HEAD零diff及`openspec validate --changes reader-double-page-letterbox-fix`均通过。保护路径：AGENTS/BACKLOG/ROADMAP/design-spec、正式spec、pubspec.yaml/lock、本change proposal/design/specs、F10归档。最终交付前再核对完整变更清单。
- 无新增UI文案、无翻译改动、无图片文件改动/入库；无依赖新增、lock重生成或缓存补丁修改。
- GUI待architect全文读核`/tmp/b5_gui.dart`与`/tmp/b5_x11.py`，之后执行1.4；源码继续冻结。

## 1.4 原生 GUI、构建恢复与清理（已完成）

- 审核通过的固定脚本：`/tmp/b5_gui.dart`最终SHA `e01688d2b2c9e08de67369d0de04edfa6582b34e5118dea4eb989ba8210ecb07`（仅较初版删一多余末尾括号）；`/tmp/b5_x11.py` SHA `4ea18b4ae480c8281594223f1ce1a0cfb86ad27dd47dbd2956ef947c1caf4e9d`。helper执行前每次核对标题/PID/proc/exe/--b5-fixture，键白名单；鼠标本窗口局部转root、窗口及宿主全部路径点校验、try/finally释放。旧未核对版本未运行。
- GUI构建：`fvm flutter build linux --debug --no-pub --target /tmp/b5_gui.dart`，`/tmp/b5-gui-build.log`最终成功；首次多余括号编译错误只属/tmp harness，未修改生产main/runner。
- 启动：`env DISPLAY=:1 GDK_BACKEND=x11 XDG_CONFIG_HOME=/tmp/b5-gui/xdg/config XDG_DATA_HOME=/tmp/b5-gui/xdg/data XDG_CACHE_HOME=/tmp/b5-gui/xdg/cache build/linux/x64/debug/bundle/venera-next --b5-fixture`。业务/cache也固定`/tmp/b5-gui/{business,cache}`。日志`/tmp/b5-gui-run.log`。
- inspect核对PID573551、窗口0xa00002、标题`B5 reader controlled fixture`、实际client1280×700，root1080×760。**完整1280×700图是原生Flutter RepaintBoundary导出，不是完整宿主X11截图**；同时另导出gallery1040×700，未用1080宿主裁切冒充。
- 每次输入释放后等待稳定帧，再逐张view_image。以下文件均在`/tmp/b5-gui/`，完整帧为`<编号>-<label>-full.png`，同时保留`-gallery.png`及对应JSON：

| 编号/label | 实际场景与结果 |
|---|---|
| 00-startup / 01-single | 浅双/浅单，同600×900，viewport1040×700，四边完整、顶底占满；双面scale1.0、单面7/9 |
| 02-dark / 03-double | 深单/深双，四边完整、占满同一实际viewport |
| 04-chrome / 05-light | 深/浅chrome，跟随当前主题；1.6文字、减少动画，chrome为既有覆盖层，gallery独立导出仍完整 |
| 06-resize800 | 真实窗口resize到800×600，生产900阈值自动不显示栏，实际gallery800×600；双面完整 |
| 07-cover | 回到1280×700、首图单页，range(0,1)，完整 |
| 08-next / 11-previous | 异比配对600×900+800×1000，range(1,3)，等比/四边完整；后者从尾页返回；右图必要25px留白仍保留 |
| 09-next | 横向跨页图独占，range(3,4)，完整；保留必要等比留白 |
| 10-next | 奇数尾页，range(4,5)，完整 |
| 12-previous / 13-previous | 在window-local(600,350)真实double释放，再真实drag(600,350)→(680,380)释放，图像稳定无残留，page2/range(1,3)、scale1.0 |

- 各帧真实尺寸/ready/viewport/media/缩放/范围等汇总`/tmp/b5-gui/matrix.json`，JSON均ready=true。截图只/tmp、不入库。00/01/03–10另经architect独立view_image确认。
- **交互与输入局限**：GUI外围为生产ReaderScaffold+ReaderGalleryView，未接整页ReaderGestureHost/快捷键dispatcher；n/p是fixture控制键调用生产navigation，不能声称GUI验证生产键盘绑定。真实double未使scale变化，不能声称已验证GUI双击缩放；拖动后也未改变页。已有gallery_input原断言覆盖控制器缩放重置、翻页、选择等，148集合已通过；本轮没有改手势或键位代码。GUI只证明上述实际发生的事件及稳定渲染。并未验证用户真实书籍/原设置、真实持久化历史或整ReaderPage端到端操作。
- 正常退出：已核对helper `key q`，仅退出上述自身fixture。PID573551消失、X11窗口0xa00002消失；独立ps/X11核对只余qq/Chromium clipboard两个10px窗口，不动它们。保留本轮/tmp红灯及截图证据供复核，没有删除他人文件/进程。
- 正常main恢复：`fvm flutter build linux --debug --no-pub`，`/tmp/b5-main-build.log`成功；无--target。architect独立核对正常构建、清理、源码SHA均通过。没有重复已通过自动化。

## 最终交付结论与边界

根因已由真实生产外围和单变量探针确认：固定侧栏使阅读viewport小于窗口MediaQuery，双面路径以窗口作为childSize，先图片contain再整体缩入viewport，造成额外上下65.625px（像素66px）留白；本轮仅删除错误窗口尺寸覆盖，采用PhotoView已有实际约束默认值。四边不裁切、图片不拉伸、适配策略/用户缩放设置不变，其他模式/ComicImage/页序/历史映射/B3绑定继承/F9顺序均未改。

只确认受控生产支持配置下的缺陷；owner原始漫画/窗口/设置未知，不能声称还原原始输入，亦不能要求任意宽高比单双面等高。必要比例留白/源图黑边不属于本修复。原始widget红灯图`/tmp/b5-shell-1280-600-{1,2}.png`和日志保留，未以修复后图冒充修复前原生GUI。受控最终native图及正式RGBA断言共同覆盖修复效果。

任务1.1–1.4完成，等architect最终独立复核。实现未提交、未归档、未push；没有启动其他change。

最终executor改动仅4文件：`lib/features/reader/gallery_view.dart`、新增`test/features/reader/gallery_viewport_rendering_test.dart`、本change `tasks.md`、新增`delivery.md`。最后`git diff --check`通过，除gallery/tasks外所有已跟踪文件HEAD零diff；无图片/lock或受保护工件变更。末次status出现同change未跟踪`review.md`，由architect并行复核产生，executor未修改/删除，不混算为executor交付。四文件最终SHA清单在`/tmp/b5-delivery-sha256.txt`（delivery自包含不能内嵌自身SHA）。
