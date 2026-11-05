# F10 v2.1 executor交付（待architect独立复核）

tasks 3.1–3.5全部完成。owner独立栏序裁定已实现，无D4未决项；新生产红灯转绿、809通过/仅2项同名HEAD基线失败/0skip、analyze raw/unique50=38+12具体集合零增减、最终源码GUI/真实新PID/正常main恢复与清理均完成。源码保持architect冻结的21文件SHA，交付后停止实现，等待独立复核。未提交、归档或push，未启动其他change。

当前契约为工作区v2.1各作者栏独立排序，D4已由owner裁定；HEAD仍5977b8523b516893f70fb5fe660bef72cc524611。四件套与/tmp/f10-v21-artifacts.sha256全OK；开局20文件与/tmp/f10-v2-architect-reviewed-files.json全MATCH。旧v1/v2及planner dirty全部保留，不清空/stash/还原/提交；旧交付/复核/history不改。

开局完整跟踪差异/tmp/f10-v21-before.patch SHA256 6c26456af0483cc3fc74fbff32b855f23e5ec2e09dd6771f1d22cc48f9b22e2e；全部未跟踪快照/tmp/f10-v21-untracked-before.tar SHA256 2714042e76814f3c8644984081aab9124557e186738fe1076b7cd4e2a6ba8425，43文件SHA清单/tmp/f10-v21-before.sha256，状态/tmp/f10-v21-before-status.txt。

## 3.1 独立排序真实红灯

已使用diagnosing-bugs反馈循环与项目ui-ux-pro-max手势/命中/反馈检查，读取design-spec§1–6，不建新视觉系统。统一环境：export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897；LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib，RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu；所有Flutter --no-pub。

`fvm flutter test --no-pub test/features/favorites/author_shelf_independence_test.dart --reporter expanded > /tmp/f10-v21-red.log 2>&1`：0通过2目标失败0skip。真实LocalFavoritesPage，C1/C2均属于Alpha/Beta；normal及collapsed实际鼠标长按C2标题到C1标题。路由观察接真实mainNavigator：首页1，拖动无新增业务路由；受控A/B来源请求[0,0]。目标断言Alpha[C2,C1]失败，实际[C1,C2]；Beta及普通folder order仍[C1,C2]，证明合法共享作品栏内移动仍被旧pending拒绝，非复用旧分栏缺失红灯。完整坐标和计数在red.log。

脚手架清理registry API曾先后使用错误的无参configure和不存在reset，已核对source.dart真实API后显式恢复空registry；nullable作者ValueKey泛型与生产不同导致初始finder错误，也已修正。这些编译/finder失败不作为产品红灯；没有放松路由/请求/目标顺序断言。

## 3.2 原库独立顺序

根因由三个实际边界对应确认：旧manager在共享投影变化时抛AuthorShelfPolicyPending；旧投影不读取作者维度rank；旧writer写folder display_order。已移除pending/跨作者冲突分支，新增favorite_author_shelf_order(folder_name,author_key,comic_id,comic_type,rank)，writer只DELETE/INSERT当前作者记录，普通folder表不写。作者栏外序始终完整folder order首次出现，内序先读独立rank再过滤，可见项仅占用原完整独立序可见槽位。坏rank只读忽略/确定性回退；旧v1没有作者维度的rank完全保留，不盲迁移。

相关成员/作者增删在原事务协调当前文件夹已有栏记录，新增按初始folder投影追加、删除清理重加不复活；改名原子迁移新表和三态，删除清空；alias按新canonical查询，不从旧canonical复制。读取/build及普通mark-read没有新增全库协调。排序入队继续校验页面、原目录、connection generation、原文件夹token与最新作者/完整身份。

`fvm flutter test --no-pub test/features/favorites/author_shelf_order_test.dart test/features/favorites/author_shelf_storage_test.dart --reporter expanded > /tmp/f10-v21-storage.log 2>&1`：24通过0失败0skip（17独立排序+7三态）。覆盖旧rank隔离/坏类型及负数rank/重复rank只读不修、隐藏中间槽位、普通排序变化后已保存栏序不动、增删重加/作者移出再归入、alias目标顺序保留及fresh分离、unknown与真实同名、改名/删重建token、整DB复制换目录、原字段/其他文件夹及系列不变、SQLite中途写入失败回滚与幂等Retry、排队CRUD/alias/失效页面/换连接目录拒绝。

原3.1同命令仅日志改为/tmp/f10-v21-independent-green.log，2通过0失败0skip；Alpha C2/C1，Beta保持C1/C2，Beta随后可前移再移回，Alpha不变；普通folder order、其他文件夹、作者栏上下坐标不变，mainNavigator始终首页1、请求[0,0]。

## 3.3 控件接通及回归

原模型/原库/28项生产手势文件均保留，按新契约增强为独立栏序变化+普通folder order不变+其他作者不变；真实SQLite失败触发器从普通folder UPDATE改为独立表INSERT中途拒绝，不删除失败/元数据/身份/焦点/Escape后短击/实际mainNavigator断言。没有新增UI文案，三态最右侧箭头、作者名独立命中、左右Shift横滚、普通滚轮、右键多选和F7/F8逻辑不改。

`fvm flutter test --no-pub test/features/favorites/author_shelf_model_test.dart test/features/favorites/author_shelf_order_test.dart test/features/favorites/author_shelf_drag_test.dart test/features/favorites/author_shelf_independence_test.dart --reporter expanded > /tmp/f10-v21-order-interaction.log 2>&1`：47通过0失败0skip（存储新增7项前）。28项真实手势涵盖normal/collapsed、独立按钮/方向键Enter、长按0主动作、详情直读短击各1实际路由、Escape恢复焦点及后续短击、跨栏拒绝、拖动期间增删/作者/alias/改名/销毁、SQLite中途失败回滚和真实Retry。

最终完整受影响相关回归实际命令：

```sh
f10_favorite_tests=($(rg --files test/features/favorites | rg '_test.dart$' | rg -v 'folder_order_ownership_test.dart$'))
fvm flutter test --no-pub "${f10_favorite_tests[@]}" \
  test/features/comic_widgets test/features/search \
  test/components/context_menu_test.dart \
  test/foundation/directory_replacement_test.dart \
  test/foundation/file_replacement_test.dart \
  test/foundation/directory_selection_test.dart --reporter expanded \
  > /tmp/f10-v21-regression.log 2>&1
```

结果809通过、2失败、0skip，正常结束exit 1。仅有folder_creation_presentation_test.dart中`removed sidebar rejects a late Create Folder publication`与`removed sidebar rejects a late Sort publication`两项同名HEAD既有失败，依据保留在history/v1与history/v2-stage；未修改/删弱/排除它们。folder_order_ownership_test.dart为已记录静态编译基线文件，明确未运行，不称skip；无其他新失败。覆盖完整收藏/CRUD/身份/系列/普通排序、F7/F8及B4全部comic_widgets/收藏命中/展示/拖动/搜索/context_menu保护。原F9/B3的326通过0失败0skip保留在/tmp/f10-v2-f9-b3-protection.log及历史交付；本次其实现、设置/阅读/搜索实现、共享卡片和AppDataOperations零修改，未无故重复未受影响的F9/B3测试。

最终新增/受影响F10文件共70测试：model7、storage7、layout8、order17、production UI1、drag28、independence2，均纳入809结果。50问题基线之外，首轮analyze仅新增新测试一条unnecessary_underscores，已按真实API改(_,_)并重新analyze；未改运行行为或其他基线。`fvm flutter analyze --no-pub > /tmp/f10-v21-analyze-final.log 2>&1`最终raw=unique=50=38tool/code_audit+12其余，与/tmp/f10-v2-architect-analyze.log具体集合added=[]/removed=[]，诊断所在文件相对HEAD零diff。原始50项路径/位置/消息/规则均保存在/tmp/f10-v21-validation.json。

## GUI独立顺序、磁盘与真实新PID

新/tmp/f10_v21_gui.dart已先供architect读取核对，生产LocalFavoritesPage/Store/View/mainNavigator，C1与C2两个共同作品同时属于Alpha/Beta；新业务目录/tmp/f10-v21-gui-data、cache /tmp/f10-v21-gui-cache，与v2历史目录隔离。helper沿已核对/tmp/f10_v2_x11.py，硬编码仅DISPLAY=:1、匹配本轮title/PID并核对/proc、鼠标不得越过宿主，全部动作release。fixture标题仍为helper允许的`F10 v2 fixture PID <pid>`，但harness/数据/日志均为新v21；未借旧数据假称独立。

```sh
fvm flutter build linux --debug --no-pub --target /tmp/f10_v21_gui.dart \
  > /tmp/f10-v21-gui-build.log 2>&1
env DISPLAY=:1 GDK_BACKEND=x11 \
  XDG_CONFIG_HOME=/tmp/f10-v21-xdg/config \
  XDG_DATA_HOME=/tmp/f10-v21-xdg/data \
  XDG_CACHE_HOME=/tmp/f10-v21-xdg/cache \
  build/linux/x64/debug/bundle/venera-next > /tmp/f10-v21-gui-run.log 2>&1
# 真正新PID同命令启动，日志/tmp/f10-v21-gui-restart.log。
```

实际宿主1080×760，窗口1280×700或390×700；只用F5/F6切尺寸，没有点击900高的旧fixture按钮。完整帧由真实RepaintBoundary.toImage(pixelRatio:1)输出，非宿主裁切。初始PID232024、重启PID236997均先helper info核对窗口0xa00002/title/PID，再操作。全部截图动作release稳定后逐张view_image，截图仅/tmp；正常main/runner没有fixture修改。

| 场景 | 最终截图（路径均为/tmp/f10-v21-frame-前缀） |
|---|---|
| 1280初始两栏共同C1/C2 | 232024-1.png |
| normal Alpha C2前移、Beta不变 | 232024-2.png |
| 390右侧箭头双栏collapsed，Alpha/Beta各自顺序 | 232024-3.png |
| collapsed Alpha C1移回、Beta不动 | 232024-4.png |
| collapsed Beta C2前移、Alpha不动 | 232024-5.png |
| 左Shift横移、松键父纵滚恢复 | 232024-6.png |
| 1280深色1.6 / 390深色1.6 | 232024-7.png、232024-8.png |
| 390浅色1.6 / 1280浅色1.6长名 | 232024-9.png、232024-10.png |
| B同作者独立normal顺序，与A不同 | 232024-11.png |
| B expanded平台面板0网络 / 绑定A普通搜索 | 232024-12.png、232024-13.png |
| 新PID A collapsed两栏独立序 / B expanded独立序 / B平台面板恢复 | 236997-1.png、236997-2.png、236997-3.png |

真实normal长按在1280中(600,165)→(180,165)：Alpha从C1/C2改C2/C1，Beta仍C1/C2；Alpha/Beta栏头y121/y466不变，普通folder order及B文件夹不变。collapsed在同坐标把Alpha的C1移回，Beta仍C1/C2；再在Beta(600,358)→(180,358)长按C2，得到A/Alpha C1/C2、A/Beta C2/C1，互不联动。390右箭头(370,121)/(370,314)独立切态；长按及栏头均无漫画主路由。

左右Shift回原点/clamp与横移，松键后同坐标普通滚轮使父纵53、Alpha横106、Beta横0；对应截图6和controller日志。宽度/主题/1.6场景保留长名、最右箭头、等高与反序共同作品，无新增溢出。此前完整8格布局/三态矩阵已在本轮809回归重跑，未用历史布局绿灯替代受影响验证。

B/Alpha再以normal长按(600,165)→(180,165)得C2/C1，A/Alpha仍C1/C2。B作者名独立点expanded，平台树保留同源多名、A/B同名不同key与失效来源disabled，展开请求0。面板显示后F7仅在/tmp fixture将A当前defaults变other，实际点击(180,369)绑定f10-a的Bound name：真实mainNavigator新增AppPageRoute一次（含首页总page2）、请求仅f10-a一次`text=Bound name,page=1,options=[other]`，B为0；受控来源不冒称真实平台内容命中。F8记忆及无作者转换/聚合保护另由本轮生产UI/F7/F8回归保持，非仅configure回调计数。

磁盘SQLite只读核对独立表：A/Alpha ranks C1=0/C2=1、A/Beta C2=0/C1=1、B/Alpha C2=0/C1=1；两文件夹普通display_order均仍C1=1/C2=2及原其余成员。状态表为A Alpha/Beta collapsed、B Alpha expanded，B Beta缺键按normal。原始动作/顺序/controller/路由/来源请求在/tmp/f10-v21-gui-232024.jsonl。

精确`kill -TERM 232024`后重新启动PID236997，startup同时恢复上述A/B各栏独立序和collapsed/expanded/normal，真实切B并纵滚到平台面板，全部三张重启图核对一致。新进程仅首页1、0搜索请求，普通folder order仍保持；证据/tmp/f10-v21-gui-236997.jsonl，不用manager重开冒称PID。随后仅`kill -TERM 236997`精确停止本轮fixture，architect独立测试/analyze进程未动。

## 正常构建、清理与最终保护

`fvm flutter build linux --debug --no-pub > /tmp/f10-v21-main-build.log 2>&1`成功，恢复正常lib/main.dart入口；没有为fixture修改main/runner。最终bundle/data/flutter_assets/kernel_blob.bin SHA256为`eab752b18343dffe29ff17dcaae0cbda9552452c6147d64616f12587d65e6222`，包含`package:venera_next/main.dart`（偏移105648199），不含`file:///tmp/f10_v21_gui.dart`或fixture标题（查找均-1）。

独立`ps -eo pid,comm,args`最终相关行保存/tmp/f10-v21-final-processes.txt，为无venera-next/dart/flutter_tester匹配；独立`python3 /tmp/f10_v2_x11.py info`返回DISPLAY=:1、宿主1080×760、fixtures=[]。只停止自身两个精确PID，从未停止architect复核测试/analyze。截图、fixture/harness、隔离业务库及XDG均只留/tmp，未入库。

本轮实际实现变更仅author_shelf_model.dart（独立投影/槽位）、favorites_repository.dart（新作者维度SQLite表/成员协调/改名删除）、favorites_manager.dart（安全原归属writer与rank读取）、author_shelf.dart（投影接独立rank）。原author_shelf_model/order/drag三个测试文件只更新受新契约影响断言并增强独立性、原有其他断言保留；新增author_shelf_independence_test.dart真实生产两栏长按、双向操作/栏上下坐标/实际路由/请求保护。不改其他源码、翻译或依赖。

`python3 /tmp/f10_v21_verify.py`生成/tmp/f10-v21-validation.json与/tmp/f10-v21-final.sha256：

- 21份实现/测试/翻译逐文件与/tmp/f10-v21-architect-test-start.json全MATCH，冻结后无实现变更。
- 以本轮开局/tmp/f10-v21-before.sha256为保护基准，授权范围外变更=[]。AGENTS/BACKLOG/ROADMAP及proposal/design/spec、history/**、旧delivery/review全部保持开局SHA；没有使用旧v2脚本还原planner更新。
- 正常main/runner、pubspec.yaml/lock、design-spec、openspec/specs/**、共享comic_widgets、系列页和其他阅读/设置/搜索实现相对HEAD零diff；五Fake与旧v1存储文件等授权输入保持本轮开局SHA。
- assets/translation.json与开局逐字节相同，无新文案；旧简繁及其他语言无变化。未加依赖、pub upgrade/add或重生成lock，未热补丁变更依赖。
- analyze raw/unique50=38+12，具体诊断集合对照/tmp/f10-v2-architect-analyze.log零增减；所有诊断文件HEAD零diff。完整50条路径/位置/消息/规则在validation.json，不只比较数量。
- `git diff --check`通过，`openspec validate --changes favorite-author-manual-order`为1通过0失败。最终文件SHA含当前tasks与本文；/tmp/f10-v21-evidence.sha256另列原始测试/analyze/build/GUI计数日志、harness/helper及16张截图SHA，PNG IHDR尺寸再次核对为1280×700或390×700。

当前HEAD仍5977b8523b516893f70fb5fe660bef72cc524611，工作区dirty保留。待architect独立复核与明确提交批准，未经批准不提交，不归档/push。
