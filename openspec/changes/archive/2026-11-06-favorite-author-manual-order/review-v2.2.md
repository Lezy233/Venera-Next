# F10 v2.2 architect 独立复核

最终验收更新：2026-11-06 owner人工验收通过并授权归档推送。以下为实现冻结时的独立复核记录；其中未提交/待验收描述为当时状态，由本条最终授权更新。

2026-11-06。当前源码悬停补修符合D3.1，等待owner最终人工验收；未提交、未归档、未push。HEAD仍5977b8523b516893f70fb5fe660bef72cc524611，原授权dirty保留。v2.1独立排序的既有证据见history/v2.1及review-v2.1，本次没有把历史全量结果冒称重新运行。

## 根因、边界及红绿

生产FavoriteFolderComics在真实鼠标标题坐标(138.7,267)、背景采样(2,325)下，普通同主题卡片RGBA从4277665791变4109235711，而作者栏保持4277665791。/tmp/f10-v22-red.log为1项目标失败；真实Ink状态探针确认指针到达，单变量ColoredBox改Material后同一采样变色，根因为局部不透明背景遮住祖先Material ink。

最终局部Material和逐实例MouseRegion使用既有ColorScheme/AppOpacity.hover及AppMotion.fast，保留选中底色、焦点和按压反馈。architect独立审阅指出整卡Theme传播到菜单的风险后，executor用真实右键+鼠标+最终像素确认菜单回归：普通菜单4092459007→3924094463，作者栏菜单不变，见/tmp/f10-v22-menu-red.log。已在D3.1裁定仅增加ComicTile默认null的可选hoverColor并透传原ClickInkWell；作者栏传透明色，移除整卡Theme，菜单及gesture实现零修改。最终菜单像素与普通卡片严格相等，未弱化断言。

扩展关闭动画/展开测试另暴露4项RenderAnimatedSize自布局重入，未作为基线排除。局部尺寸包装在关闭动画时直接返回原子树，正常偏好保留原高度动画、对齐与布局。最终测试保留160ms悬停中间帧、选中移出恢复、展开尺寸、真实拖动/Escape、Escape后短击一次、邻卡与跨栏共同作品隔离、真实路由/SQLite写审计/受控来源零副作用断言。

## 独立执行

环境：fvm3.47.7，https_proxy/http_proxy=http://127.0.0.1:7897；原生测试LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib、RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu。全部Flutter --no-pub，无依赖变更。

```
fvm flutter test --no-pub test/features/favorites/author_shelf_hover_test.dart test/features/favorites/author_shelf_ui_test.dart test/features/favorites/author_shelf_layout_test.dart test/features/favorites/author_shelf_drag_test.dart test/features/favorites/author_shelf_independence_test.dart test/features/favorites/favorite_hit_target_test.dart test/features/favorites/favorites_display_test.dart test/features/favorites/favorites_reorder_test.dart test/features/comic_widgets test/components/context_menu_test.dart --reporter expanded
fvm flutter analyze --no-pub
```

独立回归/tmp/f10-v22-architect-regression.log：204通过、0失败、0skip。executor最终同集合/tmp/f10-v22-regression-final.log同为204通过。hover最终8格覆盖浅深×正常/折叠×详细/画廊，正常格还真实切expanded；共享默认卡片及B4保护在同一集合。

独立analyze /tmp/f10-v22-architect-analyze.log：raw/unique均50=38 tool/code_audit+12其他，与/tmp/f10-v21-architect-analyze.log具体集合added=[]、removed=[]，对照/tmp/f10-v22-architect-analyze-comparison.json。历史全量2项folder_creation_presentation_test失败及folder_order_ownership_test静态编译排除本轮未运行，均未算skip，也未用于吞掉本次4项已修复失败。

## GUI 原始证据抽查

已读核/tmp/f10_v22_x11.py与/tmp/f10_v22_gui.dart，固定DISPLAY=:1、GDK_BACKEND=x11、隔离XDG与业务数据，按标题/PID/proc和宿主坐标边界操作，仅fixture窗口。宿主1080×760，完整1280×700图由实际RepaintBoundary输出，未冒充宿主裁切图。所有截图仅/tmp，未入库。

architect已逐张view_image核对：

- /tmp/f10-v22-frame-470908-2.png与3.png：浅色正常详细卡移入/移出，邻卡及Beta栏同作品不随动。
- 同PID 4/5/6：深色正常移入/移出；8/9：深色折叠移入/移出；14/15：浅色画廊折叠反馈/恢复。
- 同PID 16/17/18：真实右键菜单中Copy Title移入/移出保持自身反馈。
- 同PID 19/20/21：Selected 1 comics保持，跨栏共同作品均选中，仅Alpha当前实例hover变化，移出恢复选中底色。
- /tmp/f10-v22-frame-474220-1.png：真实长按后Alpha C2/C1、Beta仍C1/C2。该会话随后另一次显式拖动恢复Alpha C1/C2，并非悬停改序。
- 同PID 4/5和7/8：390×700、1.6文字缩放，浅色/深色正常网格移入反馈及移出恢复。

原始两PID jsonl与/tmp/f10-v22-gui-evidence.json记录：无来源请求，470908仅首页及一次主动右键PopupRoute，474220仅首页。悬停不增加写审计；折叠与排序明确输入才写入。独立自动化另覆盖主动作计数、拖动取消与选中语义。受控空封面fixture不声称验证真实平台图片内容。

470908过程中收到SIGTERM而退出，会话退出143，信号来源未知，之后旧句柄动作失败不算证据；不能推断为产品崩溃或正常主动清理。已换核对后的新PID补齐必要场景。原始有效图保留，不安装图片依赖或加工截图。

## 构建、清理及保护

/tmp/f10-v22-main-build.log显示正常fvm flutter build linux --debug --no-pub成功。architect独立strings核对最终kernel包含package:venera_next/main.dart、不含v21/v22 fixture URI，kernel SHA256 a8541badbcf8b7f2a827851a1dbc7fb8f0d1c5c3c0ff1fb0c1b5cecf0a8f08d0。

474220经ps、标题及/proc核对后定点TERM；architect独立ps确认470908/474220均不存在，helper fixtures=[]，X11只qq/Chromium clipboard两个10px窗口。正常main/runner零diff，无后台fixture残留。

design-spec.md、openspec/specs/**、pubspec.yaml/lock、lib/main.dart、linux/runner、共享menu/gesture零diff；git diff --check和openspec validate --changes favorite-author-manual-order通过。v2.1的21文件中20完全不变，唯一变动为授权author_shelf.dart；本次另改ComicTile及新增hover测试。冻结前后三文件SHA全MATCH，最终23文件SHA见/tmp/f10-v22-architect-reviewed-files.json。

已读executor最终delivery-v2.2.md，tasks4.x全部3/3，/tmp/f10-v22-final.sha256五文件全MATCH，最终23实现/测试/翻译文件与architect冻结清单全MATCH。当前实现不再变更，独立复核结论为符合，等待owner人工验收；保持未提交、不归档、不push。AGENTS/BACKLOG/ROADMAP已同步待验收。整体样式/交互美化仅BACKLOG UX1 TODO，未启动实现。
