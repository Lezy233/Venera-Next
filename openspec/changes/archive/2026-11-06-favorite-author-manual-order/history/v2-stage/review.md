# F10 v2 阶段独立复核（2026-11-06）

结论：已实现部分的回归、静态检查及GUI恢复证据通过；整个change未完成，未批准提交。design D4多作者重叠排序冲突仍需owner裁定，tasks 2.6、2.7保持未完成。不得归档或push，不启动其他change。

## 复核基线

HEAD仍为`5977b8523b516893f70fb5fe660bef72cc524611`，以工作区v2四件套为契约。旧v1授权脏改保留，历史记录在history/v1；没有以旧v1绿灯替代v2验收。

2026-11-06独立核对`/tmp/f10-v2-final.sha256`全部匹配，随后executor仅补交付文档和任务备注；源码与测试的SHA仍须保持该清单一致。受保护的design-spec.md、openspec/specs/**、pubspec.yaml/lock、正常main/runner均零diff；`git diff --check`通过。

已收到executor正式阶段交付：tasks 6/8，2.8已完成并记录完整GUI/重启/构建/清理证据，2.6/2.7如实未勾。architect随后仅更新AGENTS/BACKLOG/ROADMAP状态与本复核文件，因此executor先前的文档SHA不再作为后续planner编辑后的零变化要求。最终20份源码/测试/翻译SHA已独立冻结为`/tmp/f10-v2-architect-reviewed-files.json`，相对executor验证清单全匹配；实现未再修改。OpenSpec validate为1通过0失败。

## 独立复跑

统一环境：http(s)_proxy=http://127.0.0.1:7897，LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib，RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu。Flutter使用fvm和`--no-pub`。

- 完整收藏测试（仅排除既有静态编译基线文件folder_order_ownership_test.dart）+test/features/comic_widgets+test/features/search+context_menu_test+directory_replacement/file_replacement/directory_selection：**800通过、2项既有失败、0skip**。日志`/tmp/f10-v2-architect-regression.log`。两失败均为folder_creation_presentation_test.dart中的`removed sidebar rejects a late Create Folder publication`和`removed sidebar rejects a late Sort publication`；旧HEAD基线记录不变，不作新增失败豁免。
- `fvm flutter analyze --no-pub`：**raw50、unique50=38 tool/code_audit+12其他**。与已记录具体诊断集合比较，added/removed均空。日志`/tmp/f10-v2-architect-analyze.log`，计数`/tmp/f10-v2-architect-analyze-counts.json`。
- executor另跑F9/B3保护**326通过、0失败、0skip**，日志`/tmp/f10-v2-f9-b3-protection.log`；该数字为executor证据，不冒称本次architect另跑。

## GUI与构建核对

architect独立查看首图发现栏头箭头左置，按owner“栏头右侧箭头”要求打回；修正后布局/状态/交互40项通过。最终图`/tmp/f10-v2-frame-75523-1.png`已独立查看，箭头位于最右。另独立查看`/tmp/f10-v2-frame-75523-8.png`，390宽、深色、1.6倍文字及长名截断可见。旧PID62257/71089图片不计最终证据。

X11宿主1080×760，1280场景由完整RepaintBoundary生成真实1280×700帧，未用宿主裁切图冒充。GUI helper只操作标题与/proc校验的本轮fixture，实际输入坐标不越过宿主；图片仅/tmp。

独立读取`/tmp/f10-v2-gui-75523.jsonl`：A真实排序为Alpha-2/Beta-1/Alpha-1/Beta-2；平台名称Bound name只打开一个业务路由并请求f10-a一次，options为点击前更新的other，无其他来源请求。

独立比较新PID80160日志：A的Alpha expanded/Beta collapsed，B的Alpha collapsed/Beta normal从磁盘恢复；A排序保留，B原顺序未改变。实际日志为`/tmp/f10-v2-gui-80160.jsonl`，不是manager重开替代进程重启。

正常main构建日志`/tmp/f10-v2-main-build.log`成功。architect独立读取最终kernel：SHA256 `e35ca53f484736fc246222ff479b8b325c370205645bd26ea29d3b2b75a3c8e7`，包含package:venera_next/main.dart，不含/tmp/f10_v2_gui.dart或fixture标题。独立ps核对62257/71089/75523/80160均不存在；X11仅原qq/Chromium clipboard两个10×10窗口，无fixture。

## 未决边界

两本漫画同时属于甲、乙时，在甲栏交换并写入唯一folder order，乙栏顺序也会变化，无法同时满足“写回folder order”和“其他作者相对顺序不变”。owner尚未选择冲突时拒绝并提示，或允许共享作品同步换序。当前AuthorShelfPolicyPending只为临时保护边界，不是最终产品策略。

待裁定后由architect修订D4/spec/tasks，再交executor实现冲突分支并补相应用例；变更相关源码后复核受影响测试及最终SHA。当前不要求重复已通过且未受影响的检查。
