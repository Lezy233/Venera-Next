# Tasks

> 硬规则：正式契约design-spec.md、openspec/specs/**、pubspec.yaml/lock禁改；不生成lock/不加依赖；analyze50=38+12零新增；新文案.tl+zh_CN/TW；截图仅/tmp；逐项完成即勾选并备注；有设计冲突停止报告architect；工作区开工须干净、无无关改动，architect批准前不得提交。

- [x] 1.1 按diagnosing-bugs建立真实选择器“应用→已保存→销毁重建→无”的可运行失败复现，分别核对方案库、参数落盘、显示；记录命令/红灯证据与确认根因，不将静态推断当复现。备注：真实组件测试两次稳定红灯（Saved/方案库及边距落盘断言均通过，重建后ID为空）；见diagnosis.md及/tmp/b3-red{,-minimal}.log。已确认局部_appliedId丢失，非参数落盘失败。
- [x] 1.2 实现按作用域/设备/来源漫画的持久引用、与apply同事务及None/重置清引用，保留19键/部分键/CRUD和旧数据兼容；同步补模型/落盘回归。备注：JSON元组身份、apply同事务写引用、None及目标reset清引用、active归一化/设备捕获已实现；模型11通过0skip（/tmp/b3-model.log）。失败恢复按1.4继续。
- [x] 1.3 实现引用+生效参数匹配恢复，设置页/管理页/快捷面板共用，覆盖切层/重进/改名删除更新、手改失配与方案外项保持。备注：移除局部_appliedId，三入口共用引用+规范化生效值校验；19键、部分/空方案、auto、override、同值ID、CRUD及原真实重建红灯均已转绿，阶段矩阵25通过0skip（/tmp/b3-matrix.log）。
- [x] 1.4 按修订D4实现本操作拥有字段/引用的失败恢复与原目录有界耐久补偿、保留并发更新；补偿失败持续错误/目标暂停/同进程重进保护，重试恢复不自动apply；覆盖D4.5四类真实故障/部分落盘/反复失败/归属与并发矩阵及D4.4故障退出加载边界，任何新增文案补齐.tl简繁。备注：appdata显式recoveryKey opt-in，字段存在性/后续接管三方恢复、有界两文件补偿、目标持续错误/暂停/只恢复不重放已实现；D4.5真实双向单文件故障、反复失败、归属、None/reset及D4.4加载边界均通过，组件重进/无Saved/重试恢复亦通过；新增文案已补简繁。最终相关回归108通过0skip（/tmp/b3-regression-final.log）。
- [x] 2.1 运行新增与相关方案/设置/快捷面板回归，复跑analyze50零新增、protected零diff、diff-check；交付精确计数/日志路径。备注：10个相关测试文件108通过0skip；analyze原始50/唯一50=38tool+12其余，零新增；protected及proposal/design/spec零diff、diff-check通过，翻译JSON简繁7词条校验通过。日志/tmp/b3-regression-final.log、/tmp/b3-analyze-final.log。
- [x] 2.2 DISPLAY=:1隔离GUI验证三层与重进/实际重启、手改失配、原症状消失，截图/tmp；恢复lib/main.dart正常构建并停止自己的fixture，交付等待独立复核，不提交。备注：全局应用/重进、设备隔离/手改失配、漫画与快捷面板同引用均已GUI核对；PID119298→241341实际重启三层恢复，新进程面板浅深主题/重建截图均通过（/tmp/b3-restart-{global,device,comic,panel-light,panel-dark}.png）。正常lib/main.dart构建成功（/tmp/b3-production-build.log），kernel确认无b3_gui.dart且含正常main；fixture已停止，main/runner零diff；详见delivery.md，未提交。
