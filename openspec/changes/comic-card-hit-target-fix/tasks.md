# Tasks

> 硬规则：design-spec.md、openspec/specs/**、pubspec.yaml/lock禁改；不生成lock/不加依赖；analyze50=38+12零新增；新文案.tl+zh_CN/TW；截图仅/tmp；逐项完成即勾选备注；设计冲突停止上报；开工工作区干净、无无关改动，architect批准前不得提交。B3完成并经architect复核/批准提交后，再开始本change，独立新会话读取本目录。

- [x] 1.1 用生产ComicTile及SimpleComicTile(withTitle:true)建立真实坐标失败测试，复现首行/标题不可点，记录布局/徽章状态/坐标/根因与红灯证据；不预设徽章就是根因。
- [x] 1.2 修复可见标题/封面命中及装饰穿透，主动作复用原回调与身份；覆盖detailed/brief/gallery宽窄卡及带标题简卡，避免重复导航和竞争手势。
- [x] 1.3 按修订design D2.1让brief<88px复用既有18px紧凑徽章，保留72px三状态无溢出用例并覆盖87/88边界，不调高测试下界；补真实坐标回归矩阵：首行左中右/后续行/封面、徽章组合、长标题/不同布局、准确作品与source身份；收藏详情/直读/多选、右键/独立操作、键盘与排序拖动保持。
- [x] 2.1 跑新增及漫画卡片/列表/收藏显示/聚合搜索相关回归，analyze50零新增、protected零diff、diff-check；交付精确计数和日志。
- [x] 2.2 DISPLAY=:1隔离GUI验证标题首行、聚合简卡与收藏多选等真实入口；截图仅/tmp，恢复正常main构建并停止自己的fixture，交付等待architect独立复核，不提交。

### 1.1 红灯记录

- 开工 HEAD e15dfd2161b72a3f24bd73ada8437695841f3df4，git status --short 为空。
- `fvm flutter test --no-pub test/features/comic_widgets/comic_hit_target_test.dart --reporter expanded`，日志 `/tmp/b4-red.log`：1通过2失败，0skip。生产 detailed 375×180，首行 glyph rect=(143.6,11)-(300.4,25)，tapAt(146.6,18)：无状态1次，收藏状态0次。生产 SimpleComicTile(withTitle:true)，tapAt(6.1,150)：0次。
- 两个最小路径：详细卡片的装饰Stack是原InkWell的兄弟节点，装饰容器空白部分也参与命中，遮住首行；简卡标题在封面手势区域之外。接着以逐变量修复与真实聚合路由测试确认。

### 1.2 修复记录

- 三布局共用原ClickInkWell，将其由布局内部提到状态Stack外：单一主动作/右键/长按识别器包含标题、封面和装饰；保留徽章位置与进度Tooltip。
- AnimatedTapRegion增加可选footer，将简卡标题纳入同一手势，footer仍在封面AnimatedPhysicalModel外，保留原阴影/圆角/标题尺寸。
- 原始3测试绿灯，日志`/tmp/b4-green-initial.log`：3通过0skip，同一首行/简卡坐标恢复恰好1次。生产聚合页准确来源详情测试已通过（两来源同id各标题/封面，4次目标详情，无SearchResultPage）。

### 1.3 矩阵与边界

- 按HEAD dbf863b修订D2.1，仅brief<88px徽章尺寸复用18px；brief定位仍(6,8)，padding保留；gallery规则不变。72/87/88两viewport尺寸/位置与坐标动作测试已通过。
- 新卡片测试92项：375/1280 viewport × detailed/brief/72px brief/gallery/72px gallery × 8状态，实际glyph行左中右、封面及(20,18)装饰点；同id来源不同的邻卡隔离。另含原始红灯、阈值、Tooltip、默认详情source/hero与路由次数、Tab/Enter与按压。
- 生产收藏4项覆盖list/gallery × detail/read偏好，tapAt实际行与装饰点；检查实际AppPageRoute产生的ComicPage/ReaderWithLoading及id/source/hero，每次1路由（目的页服务不挂载、无网络）。右键Copy Title副作用1次且不导航、菜单Details1路由；长按邻卡进入真实多选，标题选择/封面取消选择，Escape后再点标题恢复原偏好动作。
- 真实AggregatedSearchPage覆盖两个source同id的标题/封面，共4次准确详情，无外层SearchResultPage误触。已有favorites_reorder的6项mouse/touch/列宽/持久化拖动回归已通过，0skip。
- 完整相关回归初跑出现8项进度语义回归：InkWell扩大后合并了进度标签；已在产品_ReadingProgressBadge保留独立Semantics container，原测试零改动。`/tmp/b4-semantics-green.log`：原进度测试+生产收藏20项全部通过，0skip；继续整体复跑。

### 2.1 最终自动化验证

- 命令：`LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib fvm flutter test --no-pub test/features/comic_widgets test/features/favorites/favorite_hit_target_test.dart test/features/favorites/favorites_display_test.dart test/features/favorites/favorites_reorder_test.dart test/features/search test/components/context_menu_test.dart --reporter expanded`。
- `/tmp/b4-regression-final.log`：174通过，0失败，0skip。新增97项（卡片92、生产收藏4、真实聚合1），相关既有77项；含排序mouse/touch六项实际拖动与持久化。
- `fvm flutter analyze --no-pub`：`/tmp/b4-analyze-final.log` raw/unique=50/50，tool/code_audit=38、其余12，零新增；包含既存folder_order_ownership编译错误。不修基线。
- architect独立复跑：`/tmp/b4-architect-regression.log` 174通过0skip；`/tmp/b4-architect-analyze.log` raw/unique50=38+12；源码hash与`/tmp/b4-architect-reviewed-files.json`一致。此后不再修改源码。
- protected（design-spec、openspec/specs、pubspec.yaml/lock、正常main、change proposal/design/spec）相对当前HEAD零diff；`git diff --check`通过；本轮文件无DEBUG临时instrumentation。无依赖/新UI文案/截图入库。

### 2.2 GUI、构建与交付

- fixture入口`/tmp/b4_gui.dart`，生产ComicTile/真实AggregatedSearchPage/LocalFavoritesPage，无网络，windowManager ensureInitialized/show，有界宿主；生产main/runner始终零修改。`DISPLAY=:1 GDK_BACKEND=x11`，XDG_CONFIG/DATA/CACHE分别隔离`/tmp/b4-xdg-*`，业务数据`/tmp/b4-gui-data`与`/tmp/b4-gui-cache`。fixture pid309241，核对窗口0x1800003实际1261×1530。
- `/tmp/b4-detail-before.png`显示375px详细卡三状态+双行标题；首行(146,70)点击后`/tmp/b4-detail-first-line.png`：OPEN #1 same-id/source=a/hero42。
- `/tmp/b4-aggregate-live.png`为真实聚合页；来源A标题(60,302)点击后`/tmp/b4-aggregate-title-a.png`：OPEN #2 result-1/source=a；返回后来源B标题(60,529)，`/tmp/b4-aggregate-title-b.png`：OPEN #3 result-1/source=b。准确详情、每点1次，无来源整行搜索误入。计数日志`/tmp/b4-gui-x11.log`。
- 生产收藏列表长按邻卡(610,126)进入Selected1；首卡标题首行(126,126)点击后`/tmp/b4-favorites-title-selected.png`为Selected2、首卡+邻卡选中；封面徽章点(30,126)点击后`/tmp/b4-favorites-cover-deselected.png`为Selected1、仅邻卡选中；OPEN计数始终3，无详情/阅读导航。两张原截图曾截到上一帧，已在release后等0.7秒重截、view_image逐张核对数量与高亮，以上路径现为稳定后的正确结果，截图仅/tmp未入库。
- 正常构建：`fvm flutter build linux --debug --no-pub -t lib/main.dart`，`/tmp/b4-normal-build.log`成功；覆盖fixture构建产物。自己的两个fixture运行会话均Ctrl-C停止，最终xwininfo窗口树无0x1800003/B4窗口；临时harness/helper保留/tmp用于复核，仓库没有fixture入口。
- 全部tasks已勾选；源码/测试5文件SHA256仍与architect独立复核记录完全一致；最终protected零diff、diff-check通过。仅此change实现/测试/tasks改动，未提交、未归档、未push，交architect复核。
