# Architect 独立复核（2026-11-04）

最终状态：owner于2026-11-04验收通过并授权归档提交，实现commit bc3f82a，归档2026-11-04-reader-preset-ordering。本次未授权push，保持本地提交。以下为独立复核记录。

## 独立验证

- 按delivery.md的三个完整命令独立复跑：231通过（F9新增22+B3相关209）、95通过（B3实际模式/作用域/手势）、199通过（B4/F8保护），合计525通过、0失败、0skip。日志分别为`/tmp/f9-architect-regression.log`、`/tmp/f9-architect-effective.log`、`/tmp/f9-architect-protection.log`。
- 独立`fvm flutter analyze --no-pub`：raw/unique均50=tool/code_audit38+其余12，与独立HEAD日志`/tmp/f9-head-analyze.log`具体问题集合完全一致。独立日志`/tmp/f9-architect-analyze.log`，零新增。
- 独立检查HEAD跟踪文件内容：授权清单之外零diff。1725份直接字节/对象一致，另外3份Windows脚本按仓库规定CRLF规范化后与HEAD对象一致（Git原始diff也为空）。F9只改既定4份Dart源码、翻译和tasks，新增2份测试与交付文档；正式spec、proposal/design/delta spec、main/runner、pubspec/lock、design-spec、F8/B4及原B3测试均无改动。
- 所有原翻译语言/词条原值保持，仅简繁各追加2条授权文案。7份最终实现/测试/翻译SHA全部MATCH，复跑后无源码修改。5/5 tasks有证据，OpenSpec和`git diff --check`通过。
- 独立摘要`/tmp/f9-architect-audit.json`。源代码SHA基准为`/tmp/f9-final-implementation.sha256`。

## GUI、重启与清理

已逐张view_image核对：鼠标拖动B得到B/A/C、下移按钮得到A/B/C、键盘后A/C/B；390深色1.6及1280浅深1.6完整帧无新增溢出，首尾方向禁用；PID106532重启管理页仍A/C/B；新PID全局/设备/漫画下拉和生产快捷面板均None/A/C/B、选B。面板浅深两图均显示Follow default及实际Waterfall。

截图为delivery.md中的final-*及`/tmp/f9-frame-104621-{0,1}.png`。结合`/tmp/f9-gui-audit.jsonl`独立解析最终PID104621/106532的11个事件：仅方案列表顺序变化，方案全部对象及其他raw设置保持，三层绑定均B，实际waterfall，无应用回调。早期误点事件未计入最终通过证据。

正常main构建日志`/tmp/f9-main-build.log`成功；独立核对生产kernel含package:venera_next/main.dart且无f9_gui.dart。独立ps无venera-next，X11仅原有qq/Chromium clipboard小窗口，无fixture。截图只/tmp，未入库。

原/tmp证据在中断后丢失及从HEAD隔离重建过程，见delivery.md；本复核使用现存重建证据及最终日志，未把已丢失路径作为现存证明。

## Owner建议验收

1. 打开管理方案，用拖动手柄和上/下移调整顺序，确认没有误应用其他方案。
2. 重开设置与阅读器快捷面板，确认同一顺序，当前方案名称、设置与跟随默认行为保持。
3. 重启应用再次检查顺序和当前方案；首项上移、末项下移应禁用。
