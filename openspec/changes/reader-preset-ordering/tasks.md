## 前置

仅F8验收后由architect另行派活，新会话核对HEAD与干净工作区。

## 1. 实现与证据（逐项完成立即勾选并备注）

- [x] 1.1 最小阅读，核对B3归档契约及保护SHA；建立生产管理页排序缺失红灯和顺序/身份不变断言。HEAD 7336ef5、开工工作区干净。中断后原/tmp SHA/红灯/helper丢失；已从HEAD独立解出/tmp/f9-head，重建/tmp/f9-protected-head.sha256，并在独立checkout执行flutter test --no-pub test/features/settings/f9_red_probe_test.dart --reporter expanded。两项红灯0通过2失败：管理页缺少ReorderableListView；并发CRUD后C/A/D未恢复A/C/D；现存日志/tmp/f9-red-rebuilt.log。原/tmp/f9-start-sha256.txt及/tmp/f9-red.log不再作为现存证据。
- [x] 1.2 实现稳定ID的局部移动与持久化；覆盖首尾/空/单项、并发CRUD、目录归属及真实IO失败/补偿/恢复，保护B3语义。新增foundation矩阵13通过0skip（最终含于/tmp/f9-final-regression.log）；按最新raw列表移动、无变化不写；顺序独立恢复保留并发CRUD/字段及后续排序接管；仅排序关闭writer自动迁移以保持全部raw状态，其他调用默认不变。
- [x] 1.3 管理页接入拖动与可键盘操作上/下移、焦点与禁用状态及双语；验证所有选择器/快捷面板同序，不误应用。最终新增UI矩阵9通过0skip（/tmp/f9-ui-final.log），真实鼠标双向拖动/点击、拖动中并发新增改名、Tab+Enter/Space、390/1280×浅深×1.6、同ID焦点/禁用、真实故障重进/重试、三层选择器和生产quick panel同序且未派发应用。新增文案简繁齐全。
- [x] 1.4 完成D4矩阵与B3相关回归，analyze raw/unique50=38+12零新增；记录命令/通过skip计数、保护零diff及diff-check。最终F9 22+B3相关209=231通过0失败0skip（/tmp/f9-final-regression.log），B4/F8保护集199通过0失败0skip（/tmp/f9-b4-f8-protection.log）。/tmp/f9-analyze-final.log与独立HEAD的/tmp/f9-head-analyze.log逐条集合一致：raw/unique50=38+12；本change新增3项已修复，基线未改。保护允许清单外零diff、原翻译零删除/修改、git diff --check通过；摘要/tmp/f9-validation-summary.json。完整命令与D4矩阵见delivery.md。
- [x] 1.5 完成隔离GUI拖动/替代操作/两宽度主题/真实重启与面板证据，正常main构建和fixture清理；交付等待architect独立复核，不自行提交/归档/push。最终源码PID104621→106532，鼠标拖动/按钮/Tab+Enter及390/1280浅深1.6逐张核对；新PID管理页、三层下拉、生产面板None/A/C/B一致，B三层绑定/19键/inherit/实际waterfall全部保持，无应用回调。1280采用完整渲染边界帧，未用1080宿主裁切图冒充。正常main构建/tmp/f9-main-build.log成功，kernel仅main无fixture，ps无venera-next、X11无F9窗口、实现SHA全MATCH（/tmp/f9-cleanup.log）。B3实际效果补充7文件95通过，B3相关合计304；全次最终命令集525通过0失败0skip。细节、误点排除与证据表见delivery.md；未提交/归档/push。
