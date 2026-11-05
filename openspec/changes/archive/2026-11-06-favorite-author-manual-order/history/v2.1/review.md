# F10 v2.1 独立复核（2026-11-06）

结论：**符合owner各作者栏排序独立的澄清，tasks 3.1–3.5全部完成，待owner人工验收。** 保持未提交，不归档、不push，不开启其他change。

## 契约与实现

owner明确甲栏操作不影响乙栏，D4已改为文件夹+canonical作者/独立unknown+完整漫画身份分别保存顺序。新原库表favorite_author_shelf_order具备作者维度；合法共享作品移动不再走AuthorShelfPolicyPending，普通folder display_order和其他作者记录保持。初始顺序沿当前folder order，新增/删除重加、过滤隐藏槽位、坏rank、alias、改名/重建及原库归属按D4处理。

已读取模型、目标栏writer和成员协调实现：排序writer只更新当前folder_name+author_key；成员协调限制在有保存记录的相关文件夹，不在普通读取/标已读路径扫描全库。原v1单份rank未盲迁移，三态、最右箭头、原点击/多选/右键/F7/F8行为保留。

HEAD为5977b8523b516893f70fb5fe660bef72cc524611，授权脏改保留。工作区v2.1四件套为本轮依据，前三份契约与派工SHA保持匹配；tasks已按实际完成更新。v1/v2阶段历史完整保留，不能替代本轮独立排序证据。

## 红绿及独立复跑

生产LocalFavoritesPage normal/collapsed中，从真实标题坐标(565.4,119)长按C2移到(138.7,119)：初始两次均失败，Alpha仍C1/C2；真实主导航仅首页1，A/B请求0。日志/tmp/f10-v21-red.log。harness初始化和ValueKey类型错误已先修正，不计产品红灯。

修复后同序列为Alpha C2/C1、Beta C1/C2、普通folder C1/C2；再单独调整Beta，Alpha保持不变。两布局均通过，见/tmp/f10-v21-independent-green.log。

architect使用fvm和--no-pub独立复跑完整收藏（仅排除原静态编译基线folder_order_ownership_test.dart）、comic_widgets、search、context_menu及目录/文件替换回归：**809通过、2既有失败、0skip**，日志/tmp/f10-v21-architect-regression.log。唯一失败仍为folder_creation_presentation_test.dart的`removed sidebar rejects a late Create Folder publication`和`removed sidebar rejects a late Sort publication`；没有新增失败。排除编译文件不是skip。

architect独立analyze：**raw50、unique50=38 tool/code_audit+12其他**，具体诊断集合added/removed均为空。日志/tmp/f10-v21-architect-analyze.log，计数/tmp/f10-v21-architect-analyze-counts.json。本轮F10受影响70测试已包含在上述完整回归；F9/B3及AppDataOperations实现零改动，326通过为此前已复核保护记录，不冒称本轮另跑。

## GUI、磁盘与重启

新/tmp隔离业务目录与XDG，DISPLAY=:1、GDK_BACKEND=x11；harness只挂生产组件，normal main/runner未改。X11宿主1080×760，1280×700与390×700整帧由RepaintBoundary输出，实际输入坐标受宿主限制；图片仅/tmp。

architect独立查看/tmp/f10-v21-frame-232024-2.png：Alpha两本共同作品为C2/C1，Beta同时为C1/C2。独立查看新PID图236997-1.png与236997-2.png：A两栏collapsed且顺序不同，B的Alpha expanded并保留自己的顺序，右侧箭头及平台树正常。

独立比较/tmp/f10-v21-gui-232024.jsonl与/tmp/f10-v21-gui-236997.jsonl：

- 重启前最终A/Alpha=C1/C2、A/Beta=C2/C1；B/Alpha=C2/C1、B/Beta=C1/C2。普通folder仍C1/C2及原其余成员。
- 新PID启动即恢复上述各栏独立顺序，以及A两栏collapsed、B/Alpha expanded、B/Beta normal；无需额外搜索，只有首页路由。
- 旧PID的展开0请求；名称点击仅f10-a请求一次，text=Bound name、page=1、options=[other]，业务路由仅新增一次，其他来源0。

executor另记录两布局实际长按、左/右Shift与松键纵滚、主题/1.6及长名、16张整帧和SQLite逐行核对，完整动作与命令见delivery-v2.1.md。受控来源证据不夸称真实平台内容命中。

## 正常构建、清理与文件检查

正常main --no-pub Linux debug构建成功（/tmp/f10-v21-main-build.log）。architect独立读取kernel：SHA256 eab752b18343dffe29ff17dcaae0cbda9552452c6147d64616f12587d65e6222，含package:venera_next/main.dart，不含v21/v2 fixture URI及标题，记录/tmp/f10-v21-architect-main-proof.json。

独立ps核对232024和236997均不存在；X11仅原qq/Chromium clipboard两个10×10窗口，无fixture。仅精确停止本轮PID，未停止其他程序。

全部最终清单SHA匹配；21份实现/测试/翻译与独立测试开始快照一致，冻结后无源码变更，复核记录/tmp/f10-v21-architect-reviewed-files.json。受保护的design-spec、正式spec、pubspec/lock、main/runner、共享comic_widgets、系列页及未受影响实现零diff；翻译与本轮开局字节一致。OpenSpec validate 1通过0失败，diffcheck通过。planner在收到交付后只更新本复核及AGENTS/BACKLOG/ROADMAP待验收状态；其文档SHA变化不需要executor回滚，不改变已验证源码版本。

## Owner验收路径

在具体收藏文件夹选择作者分栏，找两本共同属于甲乙作者的作品：正常网格在甲栏交换，确认乙栏和作者栏上下位置不变；折叠后在乙栏单独交换，确认甲栏不动。再在另一个文件夹调整同作者，重启后检查每个文件夹、每位作者的顺序和折叠状态分别保留。普通文件夹排序应始终不受栏内拖动影响。
