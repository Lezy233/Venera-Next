# F10 v2.2 悬停补修交付

2026-11-06，executor w4:p2。tasks4.1–4.3完成，交architect正式独立复核；未提交、归档或push。仅补作者分栏悬停反馈，不做UX1全局美化。HEAD仍为5977b8523b516893f70fb5fe660bef72cc524611，以工作区v2.2契约为准，旧通过不代替本轮验证。

## 开局、授权与保护

已读AGENTS、ROADMAP、当前四件套/D3.1、design-spec及diagnosing-bugs、项目ui-ux-pro-max技能。四件套和/tmp/f10-v22-artifacts.sha256全OK；原21实现/测试/翻译和/tmp/f10-v21-architect-reviewed-files.json全MATCH。授权dirty保留，无清理/stash/还原。52文件初始SHA在/tmp/f10-v22-before.sha256，git状态在/tmp/f10-v22-before-status.txt。

- 跟踪差异/tmp/f10-v22-before.patch，SHA256 `9e6c6a632bf127db2c516124200c98af0a9ed9dab345e07cf84e4afb6dccefa3`。
- 35未跟踪文件快照/tmp/f10-v22-untracked-before.tar，SHA256 `e64ecfc22f1ca548680d0e5b16c05505012dfc2734a5ef99d8ee5ff7d87200cd`。
- architect随后明确批准共享ComicTile最小可选接口并更新design D3.1。已重读裁定；该工件SHA变化属于architect授权，不还原、不按旧清单误报。executor未修改契约、planner文档、history或旧交付/复核。

## 根因、红绿过程与修复

新增测试用生产FavoriteFolderComics和同主题/模式普通ComicTile对照，真实PointerDeviceKind.mouse坐标移动；RepaintBoundary最终RGBA采样避开文字/封面，不以onHover状态或装饰属性替代。实际mainNavigator observer、A/B受控来源请求计数、真实SQLite触发器写审计（普通folder UPDATE、独立排序/栏状态）接通。

1. `/tmp/f10-v22-red.log`：0通过1目标失败0skip。标题(138.7,267)、背景采样(2,325)，普通卡片4277665791→4109235711，shelf保持4277665791；首页路由1、主动作0、写入0、A/B请求[0,0]，构成有效产品红灯。
2. 三假设为局部绘制遮挡、长按包装拦截、采样位置错误。`ink-probe.log`确认真实SDK Ink收到hovered；仅将ColoredBox换Material的单变量`material-probe.log`使同点4277665791→4109235711，确认不透明ColoredBox遮住祖先Material ink。临时动态SDK诊断已移除。
3. 本地Material+MouseRegion初版8格`hover-green.log`通过，但整卡透明hover Theme被菜单InheritedTheme.capture捕获。architect指出后以真实右键Copy Title菜单像素确认：`menu-red.log`为0通过1目标失败0skip，普通菜单4092459007→3924094463，shelf4092459007→4092459007。未以卡片8绿掩盖菜单回归。
4. architect批准后，仅ComicTile增加默认null的hoverColor，透传原主区域ClickInkWell；shelf传透明并移除Theme包装。共享menu/ClickInkWell不改，其余调用默认行为不变。修复后菜单浅色精确恢复4092459007→3924094463，深色亦与普通卡片同主题像素完全一致；原像素断言保留，移出恢复。
5. 扩展真实展开/拖动/Escape矩阵时，`hover-final.log`为4通过4失败，首次`regression.log`为200通过4失败，均0skip。四个normal用例关闭动画时展开触发RenderAnimatedSize自布局重入。当前SDK rendering/animated_size.dart:309–333在布局中forward零时长动画，同步通知markNeedsLayout；真实失败未归为基线或吞掉。局部_ShelfSizeTransition关闭动画时直接布局原子树，正常偏好仍保持AnimatedSize/AppMotion.normal/topCenter；关闭动画、展开尺寸及原布局中间帧断言均保留。
6. `/tmp/f10-v22-hover-fixed.log`为8通过0失败0skip；补展开卡片尺寸不变、Escape后短击恰一次断言后，最终受影响集合204通过0失败0skip。

实际表面按UI实例持有hover；ColorScheme.onSurface+AppOpacity.hover叠加原surface/secondaryContainer，AppMotion.fast，关闭动画即时反馈。无额外手势识别器或遮挡命中层；拖动/moving清除局部hover。几何、主题、业务选择身份、每栏独立排序模型不变。8格覆盖浅深×正常/折叠×详细/画廊，标题/封面/主区域、邻卡/跨栏同漫画、选中移出恢复、160ms中间帧、关闭动画、展开、真实拖动/Escape及菜单原主题像素，保留动作/路由/写入/来源计数。

## 命令与自动化结果

所有fvm前设置https_proxy与http_proxy为http://127.0.0.1:7897；测试使用`LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib`及`RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu`。全部Flutter --no-pub，无依赖安装或lock重生成。下列为实际命令（环境导出如上）：

```sh
fvm flutter test --no-pub test/features/favorites/author_shelf_hover_test.dart --plain-name 'hover light normal detailed' --reporter expanded > /tmp/f10-v22-red.log 2>&1
fvm flutter test --no-pub test/features/favorites/author_shelf_hover_test.dart --plain-name 'hover light collapsed detailed' --reporter expanded > /tmp/f10-v22-menu-red.log 2>&1
fvm flutter test --no-pub test/features/favorites/author_shelf_hover_test.dart --reporter expanded > /tmp/f10-v22-hover-fixed.log 2>&1
fvm flutter test --no-pub test/features/favorites/author_shelf_hover_test.dart test/features/favorites/author_shelf_ui_test.dart test/features/favorites/author_shelf_layout_test.dart test/features/favorites/author_shelf_drag_test.dart test/features/favorites/author_shelf_independence_test.dart test/features/favorites/favorite_hit_target_test.dart test/features/favorites/favorites_display_test.dart test/features/favorites/favorites_reorder_test.dart test/features/comic_widgets test/components/context_menu_test.dart --reporter expanded > /tmp/f10-v22-regression-final.log 2>&1
fvm flutter analyze --no-pub > /tmp/f10-v22-analyze-final.log 2>&1
```

最终204通过/0失败/0skip，包含作者栏UI/layout/drag/independence、B4命中、多选/右键/按钮/Shift横滚/焦点、共享默认卡片/menu保护；未删弱原回归文件。architect独立同204通过0skip、三源码SHA MATCH。未无故重跑未受影响的完整809或存储全矩阵；v2.1既有通过仅作未受影响保护依据，不称本轮新增通过。folder_creation_presentation_test两项同名HEAD既有失败本轮局部集合未运行；folder_order_ownership_test原静态编译基线文件排除，均不称skip，不以此排除本轮失败。

analyze最终raw50/unique50=tool/code_audit38+其他12；与/tmp/f10-v21-architect-analyze.log具体集合新增[]、移除[]。全部50条排序集合和比较在/tmp/f10-v22-analyze-comparison.json，architect独立复跑同结论。未修无关基线。

## GUI、计数与磁盘证据

仅/tmp/f10_v22_gui.dart与/tmp/f10_v22_x11.py，均经architect读核批准。helper新增独立move/rightclick，固定:1、严格v22标题+/proc PID/可执行名核对、宿主坐标边界及输入释放；旧批准脚本不改。harness复用生产LocalFavoritesPage，A/B文件夹各至少两共同作品、实际路由与SQLite审计；正常main/runner不改。业务数据/cache为/tmp/f10-v22-gui-{data,cache}，XDG隔离如下。

```sh
fvm flutter build linux --debug --no-pub --target /tmp/f10_v22_gui.dart > /tmp/f10-v22-gui-build.log 2>&1
env DISPLAY=:1 GDK_BACKEND=x11 XDG_CONFIG_HOME=/tmp/f10-v22-xdg/config XDG_DATA_HOME=/tmp/f10-v22-xdg/data XDG_CACHE_HOME=/tmp/f10-v22-xdg/cache build/linux/x64/debug/bundle/venera-next > /tmp/f10-v22-gui-run.log 2>&1
python3 /tmp/f10_v22_x11.py info
```

首次fixture构建因SQLite Row/Flutter Row导入歧义失败，仅/tmp导入改为`show Database, sqlite3`后构建成功，已报告architect，生产源码不变。PIL不可用，未安装依赖、未加工图片；仅标准库读取原始PNG采样与SHA。

宿主实测1080×760，宽帧为真实RepaintBoundary完整1280×700，非宿主裁切；窄帧390×700，使用F5/F6预设，无900高按钮。输入均在宿主内，release稳定后截图，每张均view_image。29原始帧只在/tmp；尺寸/SHA、截图关联写审计、请求/路由、初末状态和最终磁盘在/tmp/f10-v22-gui-evidence.json，原日志/tmp/f10-v22-gui-{470908,474220}.jsonl。

| PID及帧号（/tmp/f10-v22-frame-PID-N.png） | 实际动作与核对 |
| --- | --- |
| 470908，1/2/3 | 浅色正常，move(220,158)标题、移出(500,20)；只Alpha当前实例变化，Beta共同作品/邻卡不变 |
| 470908，4/5/6 | 深色正常，move(50,180)封面、移出恢复 |
| 470908，7/8/9、10/11/12 | 深/浅折叠横条标题/空白主区域悬停恢复；390内最右箭头切状态后回1280完整帧 |
| 470908，13/14/15 | 实际画廊，move(130,440)纯悬停与移出恢复 |
| 470908，16/17/18 | rightclick(220,158)，Copy Title move(300,233)，菜单反馈恢复；RGBA[236,238,244,255]→[227,229,234,255]→原值 |
| 470908，19/20/21 | 独立Select菜单，Selected 1 comics；两栏同步业务选中，仅当前UI实例hover，移出恢复选中底色 |
| 474220，1 | 折叠真实长按drag(640,158→220,158)，release移出后Alpha[C2,C1,…]、Beta[C1,C2,…]；普通order、B文件夹不变，无残留 |
| 474220，2 | 最右箭头回normal后真实网格长按反向排序，release移出无残留，其他栏/普通order保持 |
| 474220，3/4/5、6/7/8 | 390×700/1.6浅深，真实标题/封面move悬停与恢复 |

470908路由仅首页1及主动右键_ContextMenuRoute，474220仅首页；两PID来源请求均[]。470908写审计0→1仅对应明确折叠操作，hover/菜单/选择均不写。474220同隔离目录恢复Alpha collapsed，审计1→6对应首次独立栏序5项插入，再因normal状态和独立重排到17；主题/缩放/hover不再增加。原图8组前/中/后采样均变色并恢复。磁盘A/B普通序及独立栏序见上述JSON。

### SIGTERM真实限制与清理

470908窗口中途消失，BadWindow后的Escape/drag/move/F12均失败，未作为任何动作、截图或排序成功证据。重新info得到fixtures=[]、宿主ps无470908，会话38276退出143，仅能确认SIGTERM；run日志无Flutter异常/崩溃栈，信号来源未知，不能称产品崩溃或executor正常清理。没有设置额外宿主执行期限，亦无证据归因于期限。

经architect批准同隔离路径重启为474220，输出另存/tmp/f10-v22-gui-run-2.log、会话83856。重新核对标题/PID后才操作；X11复用0xa00002数值，不以旧id替代新PID验证。只补必要长按/窄屏，不重跑已通过场景，不改产品绕过退出。

```sh
fvm flutter build linux --debug --no-pub > /tmp/f10-v22-main-build.log 2>&1
ps -p 474220 -o pid=,comm=,args=
python3 /tmp/f10_v22_x11.py info
kill -TERM 474220
python3 /tmp/f10_v22_x11.py info
```

正常main构建成功，会话92405退出0。kernel含package:venera_next/main.dart，无v21/v22 fixture URI，SHA256 `a8541badbcf8b7f2a827851a1dbc7fb8f0d1c5c3c0ff1fb0c1b5cecf0a8f08d0`。ps和X11双重确认474220身份后仅TERM自身fixture；两PID已无、helper fixtures=[]，architect独立X11仅qq/Chromium clipboard两个10px窗口。会话83856清理后返回1，不称应用正常退出码0。未停止architect测试/其他进程。

## 最终文件SHA与验收状态

仅下列三份源码/测试及当前tasks、本交付为executor本轮变更。最终五文件SHA在/tmp/f10-v22-final.sha256；文档自身SHA存外部清单，避免自引用。

| 文件 | SHA256 |
| --- | --- |
| lib/features/favorites/author_shelf.dart | 6426479df5dee24d1a68c6030f18b787c338bd14ffb10a855dfeaf74d6d619a4 |
| lib/features/comic_widgets/comic_tile.dart | 5373842e32793101a0491344411434c2745d8e8dfe9b3cb423a3f4abff882975 |
| test/features/favorites/author_shelf_hover_test.dart | a6492ebc0467b86d00777c80eab768878ade950407f7200e045d7d22d9dee84f |

/tmp/f10-v22-protection.json逐一对照开局52输入，未授权变化[]；design仅architect D3.1批准更新。独立排序模型/仓储/manager、其他原实现/测试、AGENTS/BACKLOG/ROADMAP、history和旧交付/复核保留。共享menu/gesture、正常main/runner、pubspec.yaml/lock相对HEAD零diff。无新文案，translation.json保留原授权dirty与其他语言词条，本轮SHA仍`037b3e87a78675a89c13a9aeef8e526ca9603f1b7343be25b14568a62261de12`。截图不入库。

`git diff --check`通过；`openspec validate --changes favorite-author-manual-order`为1通过0失败。architect独立亦确认保护/diffcheck/OpenSpec和正常kernel/ps/X11通过。未重复已满足检查，未扩其他change。4.x全部落勾，保持未提交/归档/push，等待正式独立复核及owner验收。
