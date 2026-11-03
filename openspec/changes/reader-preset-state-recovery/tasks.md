# Tasks

> 状态：2026-11-03 owner否决第一轮交互；以下1.x/2.x是第一轮历史完成记录，不代表返工完成。当前执行3.x/4.x。原「手改失配显示无」断言按新design替代，原失败恢复/其他回归保留。

> 硬规则：正式契约design-spec.md、openspec/specs/**、pubspec.yaml/lock禁改；不生成lock/不加依赖；analyze50=38+12零新增；新文案.tl+zh_CN/TW；截图仅/tmp；逐项完成即勾选并备注；有设计冲突停止报告architect；工作区开工须干净、无无关改动，architect批准前不得提交。

- [x] 1.1 按diagnosing-bugs建立真实选择器“应用→已保存→销毁重建→无”的可运行失败复现，分别核对方案库、参数落盘、显示；记录命令/红灯证据与确认根因，不将静态推断当复现。备注：真实组件测试两次稳定红灯（Saved/方案库及边距落盘断言均通过，重建后ID为空）；见diagnosis.md及/tmp/b3-red{,-minimal}.log。已确认局部_appliedId丢失，非参数落盘失败。
- [x] 1.2 实现按作用域/设备/来源漫画的持久引用、与apply同事务及None/重置清引用，保留19键/部分键/CRUD和旧数据兼容；同步补模型/落盘回归。备注：JSON元组身份、apply同事务写引用、None及目标reset清引用、active归一化/设备捕获已实现；模型11通过0skip（/tmp/b3-model.log）。失败恢复按1.4继续。
- [x] 1.3 实现引用+生效参数匹配恢复，设置页/管理页/快捷面板共用，覆盖切层/重进/改名删除更新、手改失配与方案外项保持。备注：移除局部_appliedId，三入口共用引用+规范化生效值校验；19键、部分/空方案、auto、override、同值ID、CRUD及原真实重建红灯均已转绿，阶段矩阵25通过0skip（/tmp/b3-matrix.log）。
- [x] 1.4 按修订D4实现本操作拥有字段/引用的失败恢复与原目录有界耐久补偿、保留并发更新；补偿失败持续错误/目标暂停/同进程重进保护，重试恢复不自动apply；覆盖D4.5四类真实故障/部分落盘/反复失败/归属与并发矩阵及D4.4故障退出加载边界，任何新增文案补齐.tl简繁。备注：appdata显式recoveryKey opt-in，字段存在性/后续接管三方恢复、有界两文件补偿、目标持续错误/暂停/只恢复不重放已实现；D4.5真实双向单文件故障、反复失败、归属、None/reset及D4.4加载边界均通过，组件重进/无Saved/重试恢复亦通过；新增文案已补简繁。最终相关回归108通过0skip（/tmp/b3-regression-final.log）。
- [x] 2.1 运行新增与相关方案/设置/快捷面板回归，复跑analyze50零新增、protected零diff、diff-check；交付精确计数/日志路径。备注：10个相关测试文件108通过0skip；analyze原始50/唯一50=38tool+12其余，零新增；protected及proposal/design/spec零diff、diff-check通过，翻译JSON简繁7词条校验通过。日志/tmp/b3-regression-final.log、/tmp/b3-analyze-final.log。
- [x] 2.2 DISPLAY=:1隔离GUI验证三层与重进/实际重启、手改失配、原症状消失，截图/tmp；恢复lib/main.dart正常构建并停止自己的fixture，交付等待独立复核，不提交。备注：全局应用/重进、设备隔离/手改失配、漫画与快捷面板同引用均已GUI核对；PID119298→241341实际重启三层恢复，新进程面板浅深主题/重建截图均通过（/tmp/b3-restart-{global,device,comic,panel-light,panel-dark}.png）。正常lib/main.dart构建成功（/tmp/b3-production-build.log），kernel确认无b3_gui.dart且含正常main；fixture已停止，main/runner零diff；详见delivery.md，未提交。

## Owner验收返工：持续编辑当前方案

> 工件以本轮planner提交HEAD为准。当前工作区含已验收B4及planner维护文件，这是明确授权的保留基线，不能要求清空、stash、还原或顺带提交。开工核对git status与`/tmp/b3-rework-protected-files.json`；B4五个源码/测试文件、tasks及delta工件本轮零修改。executor仅实现B3并逐项备注；提交须planner批准，禁归档/push。

> 当前阶段检查点：生产真实tap红灯已转绿；`/tmp/b3-rework-regression-stage.log`为265通过0失败0skip，B4保护回归`/tmp/b3-rework-b4-protection.log`为174通过0失败0skip。旧76通过7失败、控件故障测试的中途失败均已被此结果覆盖，不是当前未解决失败。最后一处反馈归属补丁待窄回归；analyze阶段51中的唯一新增测试大括号提示已修，待复跑。当前无挂起命令；未提交/归档/push，尚未进行本轮GUI/生产构建。依赖分支仍暂停等待owner：绑定漫画方案时既有“Follow default”写`readerModeOverride=null`，确定模式方案字段与此动作的衔接待planner新HEAD定义；不自行实现、不删除或降低此项要求，获新契约后补实现/回归。下方勾选仅表示当前已定契约的任务完成，不代表整个返工完成或可验收。

> 权限检查点：最后两文件format请求两次均由自动权限审核超时退回，未启动；工作区内直接format也因SDK cache只读失败。随后四文件窄回归与analyze各独立请求一次，同样审核超时、均未启动，故没有对应新测试结果或运行PID。停止重试，不后台忙转，等待planner处理任务内权限；3.3/4.1/4.2不勾选。最近一次保护核对13份SHA全MATCH，diff-check通过。此前265/174结果真实保留，但不冒充最后补丁后的最终验收。

> 新HEAD窄验证检查点：B4已由planner提交归档，当前HEAD为45335d931c8804c711389ba8b1e804a82b2b7301，B3返工保留未提交。按planner指令仅执行两文件format及四文件窄回归：format成功（2文件、仅reader_mode.dart有格式变化），`/tmp/b3-rework-last-controls.log`为35通过0失败0skip，进程已退出。planner独立analyze为50=38+12（`/tmp/b3-planner-current-analyze.log`），executor未扩大复跑。旧265/174仍仅作阶段结果；重定位后保护清单含正式B4 spec共14份全MATCH。上方权限阻塞已解除；Follow default、GUI及正常main构建仍待后续指令/新契约，不宣布返工完成，不提交。

- [x] 3.1 用生产ReaderSettings/ReaderPresetSelector建立owner路径红灯：选条漫→改瀑布流后当前方案变无且方案库未更新；同时建立两目标共享与无选择隔离的可运行证据，记录旧规则与新断言替代依据。完成标准：真实控件输入、准确ID/方案值/有效mode及红灯命令均可复跑，非直接回调假测。备注：真实tap选择Strip→打开生产Select菜单改Waterfall，实际mode已变而准确ID=null、库仍continuous；共享/不同ID/无绑定隔离模型红灯已复跑。命令及证据/tmp/b3-rework-{red,shared-red}.log；旧失配断言仅按D1/D2.2替换为持续绑定与旧引用迁移场景。
- [x] 3.2 按design D1–D2实现持久编辑绑定、统一19键读取、共享ID/不同ID隔离和幂等旧引用迁移；覆盖全局/设备/同id不同source漫画、auto/override、部分缺失键、None保留最新效果、重置/更新/重命名/删除。完成标准：模型/JSON重载矩阵通过，当前方案不再因普通编辑清空，未选择用户数据不被重新应用覆盖。备注：已定语义的三层19键逐键/部分补键/共享隔离/JSON重载/旧匹配失配迁移幂等/None与CRUD矩阵已通过，包含在265通过0skip阶段回归中；原auto及漫画override求值规则保留。Follow default另按上方待裁定项补充，不宣称此依赖分支完成。
- [x] 3.3 接入全量设置、快捷面板和既有19键设置动作的统一编辑归属与可靠保存，保留非组合项原作用域；补.tl+简繁共享编辑提示，保留既有控件/主题。完成标准：19项逐键及方案外项验证通过，选择A编辑/切B编辑/切回A均身份和值一致，控件与实际ReaderSettings同源。备注：已定19键动作统一进入绑定字段编辑与原串行可靠保存；原控件/token/主题保留，共享编辑提示走.tl并补简繁。三层19键/方案外项/AB切换/真实模式与面板动作见265项阶段通过；最后模式控件反馈归属补丁已format并以四文件35通过0失败0skip窄验证（/tmp/b3-rework-last-controls.log）。Follow default仍按待裁定分支保留，待planner新HEAD另行补验；不据此宣布整个返工完成。
- [x] 3.4 按D4及D4.6扩展方案字段/绑定/必要物化字段的所有权恢复、两文件有界补偿与共享对象冲突暂停；保留并发其他字段/rename/方案及后续接管。完成标准：真实双向单文件故障、补偿反复失败、重进与重试不重放、切ID/来源/目录、部分新增键存在性、None/删除失败矩阵通过，无假成功，不弱化原可靠保存断言。备注：已定动作覆盖真实双向文件故障/原目录补偿、部分新增键缺省恢复、共享目标冲突暂停、None/删除/更新失败、并发rename/字段/其他方案及同字段接管；原失败恢复测试保留，字段与selector两条真实控件重试不重放且无Saved均通过。证据/tmp/b3-rework-regression-stage.log（265通过0skip）。Follow default失败语义待新契约后补验，不自行推断。
- [ ] 4.1 跑B3新增与方案/设置/快捷面板/模式求值相关回归，以及B4已验收174项命中相关回归；analyze raw/unique50=38+12零新增，protected与B4基线SHA全MATCH，diff-check通过。备注准确通过/skip计数、原日志命令与受新契约替换的旧断言清单。
- [ ] 4.2 DISPLAY=:1 GDK_BACKEND=x11、隔离XDG/业务目录GUI走owner完整路径（选条漫→改瀑布流仍条漫、实际生效、切方案再切回、三层/面板、同ID共享、None独立编辑、真实进程重启）。稳定后截图只/tmp，恢复正常main构建并停自己的fixture。交planner独立复核，不提交/归档/push。

  阶段备注（未勾选）：按planner授权完成不依赖Follow default的已定GUI路径。默认条漫A→改瀑布流仍同ID，B→A、方案None保留效果及独立编辑、三层显式选择隔离/同ID共享、生产快捷面板共享编辑、控件销毁重建均已实际点击并逐张核对。PID277621停止后以新PID308570真实重启，默认/设备/漫画/面板均恢复A及waterfallTopToBottom；证据及精确ID见`/tmp/b3-rework-gui-evidence.md`、`/tmp/b3-rework-gui-audit.json`、`/tmp/b3-rework-gui-run{1,2}.log`。有效图包括`/tmp/b3-rework-owner-waterfall.png`、`/tmp/b3-rework-{global-b,global-a-return,global-none,none-independent-edit,panel-shared-edit,device-shared-edit}.png`及`/tmp/b3-rework-restart-{global,device,comic,panel}.png`。临时harness/helper仅/tmp，截图已release稳定后采集；未发现本次已定路径的产品状态缺陷。正常lib/main.dart构建已恢复成功（`/tmp/b3-rework-normal-build.log`），kernel确认正常main且无harness；两个PID已退出，X11无fixture窗口；16份窄验证源码SHA未变。Follow default仍未操作/实现，待owner裁定与planner新HEAD后补验，不宣称整个4.2或B3返工完成，未提交。


## 跟随默认：owner最终裁定

> owner明确「保持方案绑定并保存继承行为」。此前所有“待裁定”检查点均为历史，不再阻塞；按design D2.4执行。已有GUI/265/174/35结果保留为阶段证据，本次完成后仍需最终复核。

- [ ] 3.5 按D2.4及新增spec实现共享modeBehavior与单向继承求值，保持ID/名称、19键范围及旧数据兼容；覆盖全量控件/快捷面板、三层同ID无环、上层动态更新/不同layout、fixed切回、纯继承/坏元数据、其他字段不清行为、None/删除保留继承及快照动作；继承编辑纳入现有失败恢复/并发/归属保护。先建立生产控件红灯，再实现，逐项记录准确ID、实际模式与持久行为；不为测试直接调用回调。

完成3.5后复跑4.1（B3最终完整相关矩阵及B4保护、analyze50零新增、protected/diffcheck），补4.2生产控件Follow default实际点击/动态跟随/切固定/切方案及实际重启证据；其余已留证场景不重复造数据。正常main构建恢复、fixture停止、待planner独立复核，未批准不提交/归档/push。
