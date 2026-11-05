## 派工前条件

Owner已于2026-11-04确认每个文件夹/系列独立记忆，D1与proposal已更新。executor按architect正式派活的新会话执行，以当前HEAD为准。

## 1. 实现与证据（完成一项立即勾选并备注）

- [x] 1.1 核对HEAD/干净工作区、最小阅读与保护SHA；用生产收藏/系列排序控件建立缺失能力红灯，记录真实身份/顺序/无主动作断言。备注：HEAD 5977b8523b516893f70fb5fe660bef72cc524611，初始工作区干净；保护树/SHA见 /tmp/f10-protected-head-tree.txt、/tmp/f10-protected-head.sha。隔离 HEAD /tmp/f10-red-head 运行生产 UI 测试，2 项按预期失败：收藏实际 Manual 菜单无新模式、系列无 Sort；失败前核对 (same,0)/(same,31)/(beta,0) 及打开次数0；日志 /tmp/f10-red-complete.log。后续完整坐标/输入绿灯纳入1.3–1.5。
- [x] 1.2 实现作者归组、独立作用域排序模型和事务存储，覆盖旧库兼容、复合身份、CRUD/alias/筛选隐藏、并发及真实失败/目录归属；不改旧display_order或网络API。备注：/tmp/f10-storage-final.log 15项全绿，含整库备份恢复、真实新目录/新连接排队拒绝、普通已读/更新零全库rank协调及删除回执无rank/有rank两分支；/tmp/f10-ui-matrix-green.log覆盖筛选隐藏/销毁/实际拖动并发。rank与旧display_order隔离，未改网络API。
- [x] 1.3 接入本地收藏/系列新模式与组内编辑器，完成拖动/上下移/键盘/首尾/焦点/跨组保护及双语；保留原点击、多选、右键、F7与系列交互。备注：/tmp/f10-ui-matrix-green.log 20项F10真实生产UI+原7项保存回归=27通过0失败0skip；实际按钮/拖动/Tab+Enter/Space、同复合身份焦点、首尾、完整作者组限制、失败Retry、compact选择Confirm重开、过滤返回、scope切换异步隔离均通过，主动作0。完整相关回归上一轮752通过/仅2项已独立HEAD复现的既有失败；最终冻结验证见1.4。
- [x] 1.4 完成design D6全部矩阵、相关收藏/存储/身份/系列/F7/B4/F8/F9保护回归，analyze raw/unique50=38+12零新增；记录完整命令、通过/失败/skip、保护零diff与diffcheck。备注：最终完整相关回归/tmp/f10-regression-group-final.log 759通过/仅2项独立HEAD确认既有失败/0skip；F9/B3保护326通过，核心42通过，真实mainNavigator路由计数增强后20项UI全绿；最终analyze-freeze raw/unique50=38+12，具体集合added/removed均空，保护/旧翻译无损、diffcheck通过。D6 GUI与两新模式不同序真实重启见/tmp/f10-gui-validation-final.json：PID882305→887436，实际路由13事件primary0，失败清单空。完整命令与基线两项名称见delivery.md。
- [x] 1.5 完成隔离生产组件GUI（两作用域/组内排序/跨组保护/两宽度主题缩放/真实进程重启），正常main构建、清理fixture；交付等待architect独立复核，不自行提交/归档/push。备注：最终GUI证据索引见delivery；A与同名series A均authorManual，Alpha分别31/0/3与3/31/0，PID882305→887436真实重启后主视图/audit一致，B/All不变，实际route observer共13事件primary0。390浅深1.6长名与1280×740实际RepaintBoundary完整帧已核对，错误的早期Beta键盘图作废。/tmp/f10-main-build.log正常main构建成功；architect独立确认kernel仅含package:venera_next/main.dart无f10_gui，ps无fixture，X11仅原qq/Chromium clipboard小窗。截图仅/tmp；未提交/归档/push。architect已独立复核并写review、更新待owner验收状态，executor交付停止。
