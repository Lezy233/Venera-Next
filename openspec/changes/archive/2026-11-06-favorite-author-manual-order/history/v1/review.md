# F10 architect 独立复核

> 2026-11-05 owner随后替换F10需求，见BACKLOG「F10 替换需求 TODO」。下文仅记录旧版契约的历史复核，旧实现未获owner验收；新需求待重新规划，不以本结论或旧tasks完成作为新需求通过依据。

2026-11-05，基准HEAD `5977b8523b516893f70fb5fe660bef72cc524611`。结论：实现符合本change契约，待owner人工验收。未批准提交，未归档或push；F9先前仅本地归档提交的状态保持。

## 独立自动化与边界

- 完整收藏/系列/身份/F7/B4/F8/目录生命周期回归：`/tmp/f10-architect-regression-final.log`，759通过、2失败、0skip。命令范围与delivery.md完整相关回归相同；作者选择实际缺陷修复后重新独立执行。
- 两项失败均为`folder_creation_presentation_test.dart`中的`removed sidebar rejects a late Create Folder publication`及`removed sidebar rejects a late Sort publication`。architect在独立HEAD副本再次运行该文件得到20通过/同2失败，日志`/tmp/f10-architect-head-baseline.log`。它们不计为通过，也未删除或弱化断言。
- 已知静态基线编译失败文件`folder_order_ownership_test.dart`未纳入完整命令；这是一份明确未运行的文件，不伪称skip测试或全库全绿。
- 新增存储15+生产UI20+原repository29+view persistence7：独立71通过，`/tmp/f10-architect-core-final.log`。覆盖实际SQLite回滚/重试、备份/替换、复合身份、独立scope、CRUD/alias、隐藏成员、拖动并发、页面销毁与旧异步归属。
- 最后补强mainNavigator及实际详情/直读路由观察后，独立再次运行生产UI20项全部通过，`/tmp/f10-architect-route-ui.log`。原configure回调0本身不作为收藏页真实路由次数证明。
- F9/B3保护21文件独立326通过、0失败、0skip，`/tmp/f10-architect-f9-b3.log`。上述核心与完整集合存在重叠，不将所有数字相加冒称不同测试总量。
- 最终独立`fvm flutter analyze --no-pub`为raw/unique均50＝tool/code_audit38+其余12，`/tmp/f10-architect-analyze-route.log`；与`/tmp/f9-architect-analyze.log`逐条具体集合相同，added/removed均空。

全部Flutter命令使用既定代理、fvm及`--no-pub`，原生测试设置bundle/lib的LD_LIBRARY_PATH。完整命令与中间失败修复过程见delivery.md；中间失败日志没有被抹去。

## 实现复核

确认带类型all/folder/series作用域及完整(id,type)身份；独立rank不改旧display_order，改名/删除重建与成员清理保持归属；操作在原目录/连接generation/scope token下验证最新身份与作者组并事务写入。成员协调限于成员事务，普通已读/更新不引入全库rank扫描。新UI简繁各7条，旧语言词条原值保持。

本轮复核推动修复了真实删除回执计数覆盖、旧过滤保存入队时序，以及GUI才暴露的作者下拉弹层使回调失效。最后一项保留真实Alpha→Beta选择红灯及修复断言，排序写入的页面/数据库归属保护仍在。五份旧Fake只补查询接口，原行为/布局/ownership断言保留。

保护文件（proposal/design/delta spec、正式spec、design-spec、pubspec/lock、main/runner）零diff，授权清单外无实现改动；`git diff --check`、OpenSpec validate通过。tasks 5/5均已勾选并有备注，最终delivery已读取核对。15份实现/测试/翻译SHA与最终冻结记录全部MATCH，独立索引`/tmp/f10-architect-reviewed-files.json`。随后architect仅新增本复核与更新AGENTS/BACKLOG/ROADMAP待验收状态。

## GUI、重启与清理

已逐张view_image抽查最终证据：

- `/tmp/f10-final2-a-drag.png`：Alpha组实际鼠标拖动得到二/一/三，完整复合身份保留；`final2-beta.png`仅Beta且上下移均禁用。
- `final2-alpha-keyboard-enter.png`、`final2-alpha-keyboard-space.png`及`final3-a-route-keyboard.png`：实际键盘移动与audit顺序一致。早先误标的`final2-a-keyboard.png`仍为Beta，明确作废。
- `final2-compact-{dark,light}16-alpha.png`：390宽浅深1.6长名无新增溢出；`/tmp/f10-frame-871803-{0,1}.png`为1280×740浅深1.6完整渲染帧，非1080宽X11宿主裁切图。
- PID882305保存文件夹A＝二/一/三、同名seriesA＝三/二/一，两份均authorManual；真实TERM退出后PID887436恢复两份不同顺序。`/tmp/f10-final-restart-a.png`、`/tmp/f10-final-restart-series.png`已独立看图核对。
- 独立读取两个最终PID的13条带实际路由observer审计，primary均0；全部/文件夹B状态及作品身份/作者/标签保持，重启完整scope状态一致。`/tmp/f10-gui-validation-final.json`失败清单为空。只证明隔离生产组件本地语义，不宣称网络平台验证。

正常默认main构建`/tmp/f10-main-build.log`成功；architect独立核对kernel含`package:venera_next/main.dart`且无`f10_gui.dart`。独立宿主ps无fixture，X11仅保留原qq/Chromium clipboard小窗。生产main/runner未为fixture修改；截图与临时宿主/helper只在/tmp。

## 建议owner验收

1. 文件夹A选择「作者→手动顺序」，进入排序编辑选择作者，用拖动、上下移和键盘调整组内顺序；检查不会打开漫画或移动到其他作者组。
2. 在另一文件夹与系列设置不同顺序，切换旧排序再返回，确认互不覆盖；保留筛选时进入编辑器仍能编辑完整组。
3. 重启后确认各视图模式与顺序保持，多选、右键与漫画标题/封面主动作仍按既有规则执行。

等待owner验收及明确后续提交/归档/推送指令，不启动其他change。
