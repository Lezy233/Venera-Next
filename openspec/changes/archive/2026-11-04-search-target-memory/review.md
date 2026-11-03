# F8 交付及独立复核（已验收归档）

最终状态：owner于2026-11-04验收通过并授权归档推送，实现提交3749a52，归档2026-11-04-search-target-memory。下文未提交/待验收措辞为各阶段历史记录，以本段最终状态为准。

开工与交付 HEAD：`cb1e32889d5cdee37d3f9205a8974b5702fb3b2a`。开工工作区干净。未提交、归档或推送；F9 未执行。

## 根因与实现

原 SearchPage 仅在页面内保存模式、来源和方案，initState 每次重新读取默认值；方案删除只改变下拉显示值，实际路由仍可能持有旧 ID；建议路径还存在来源空断言。

- `lib/features/search/search_selection.dart`：带版本的独立 searchSelection 记录，区分无记录和明确 null；只写自身字段。使用既有 updateSettings 的独立 recoveryKey、串行草稿、补偿与恢复，不修改通用事务。捕获提交目录并在入队后的回调复核。局部追踪在途保存，使保存中重开的页面读取此前持久选择，并在完成通知后解析最终值，不把 publish-before-IO 草稿当成功。
- `lib/features/search/search_page.dart`：接入来源芯片、聚合开关、方案下拉；保存期间禁止选择与搜索启动，成功后确认。保留最近单源，非空方案切聚合，明确全局设置不改变模式。来源按 key、方案按 ID 动态解析，失效提示不写回记忆；名称变化不重置临时 options。失败回到原选择，补偿未完成时禁用写入并提供恢复重试，不自动重放失败选择。空来源仍保留错误与恢复入口。保存后恢复复选框键盘焦点。
- `assets/translation.json`：zh_CN/zh_TW 各追加 5 条，全部旧词条原值不变。
- `test/features/search/search_target_memory_test.dart`：新增 25 项，包括生产控件、路由和实际 fixture 请求断言。只读复用 B3 测试中的 WriteHooks 来观察真实 native File IO 故障，未修改或运行其 main。
- 本 change 的 tasks.md 与本交付说明。

临时 options、关键词、过滤器、页码与结果未进入记忆。未修改 F6 CRUD、普通结果页或创作者显式入口。

## 红灯与诊断

```sh
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
fvm flutter test --no-pub test/features/search/search_target_memory_test.dart
```

原始最小用例真实点击 Platform B → 销毁 SearchPage → 重开 → 文本框提交搜索；断言生产 SearchResultPage.sourceKey、options，以及两个来源的真实请求次数。修复前期望 b 实际 a，0 通过、1 失败，证据 `/tmp/f8-red.log`；同一用例修复后 1 通过、0 skip，`/tmp/f8-green.log`。

诊断排序：页面没有写入选择 → 初始化默认覆盖已有记录 → 控件正确但路由取旧目标。初始代码没有持久化路径，证实第一项。新增真实 UI 回归保留该 seam；没有只调用回调代替控件操作。

## D5 矩阵（最终均通过，0 skip）

| D5 行 | 实际覆盖 |
|---|---|
| 旧目录、无记录、坏类型/版本 | 4 个生产 SearchPage 初始化用例：null、数值、错误版本、错误字段类型；默认聚合/方案兼容，初始化不创建 appdata 文件、不改原记录 |
| 聚合+方案A、重开、新搜索 | 真实下拉选择 p、销毁重开、检查 Checkbox/Dropdown、文本框提交；实际 AggregatedSearchPage.profileId=p，仅 B 请求一次、options=other；另含真实磁盘重载与 GUI 新 PID |
| 单源B、模式切换、明确 null | 来源芯片、聚合开关、下拉选择全局设置后重开；默认修改不会覆盖记忆，sourceKey=b，null 不复活默认；临时 Other 重开恢复 normal；历史点击仅 B 一次 |
| 同名来源、失效/恢复、空来源 | A/B 同名但 key 不同；配置禁用与 registry 移除触发可见回退，原记忆保持 b，恢复原 key 后路由到 B；空来源无请求/异常；恢复入口在空态仍可用 |
| 已开页方案/来源变更、显式入口 | 删除方案后回退全局且不套用另一个默认；恢复同 ID、改名/更新 options 后使用最新内容；来源改名保留临时 options；显式普通结果页 sourceKey/options 正确且不改记忆；F7 生产名称树回归覆盖实际显式入口 |
| 真实保存/补偿/恢复/目录 | appdata.json 与 syncdata.json.tmp 真目录障碍导致 native IO 失败；两种文件各有 one-shot 真实失败后持久补偿，其他字段保留；持续失败时 UI 禁用、重试恢复两文件且不重放失败选择；排队目录切换分别覆盖局部存储及生产旧页→新目录页面 |
| 快速选择、无变化返回 | 排队期间真实 Checkbox 禁用且搜索不启动；保存中重开同目录等待持久结果；显式结果与无变化重开不覆盖；375/1280×浅/深共4用例真实 Space 连续切换与焦点恢复，无溢出 |

完整最终命令（F8 25 + 相关 34 = **59 通过，0 skip**）：

```sh
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
fvm flutter test --no-pub \
  test/features/search/search_target_memory_test.dart \
  test/features/search/search_persistence_test.dart \
  test/features/search/search_profile_test.dart \
  test/features/search/search_profile_flow_test.dart \
  test/features/search/search_shortcuts_test.dart \
  test/features/search/search_filter_test.dart \
  test/features/favorites/creator_platform_names_test.dart \
  test/features/favorites/creator_platform_names_view_test.dart
```

日志：`/tmp/f8-regression-final.log`，结尾 `+59: All tests passed!`。故障测试中的红色 IO 日志为预期故障断言，不是测试失败。

```sh
fvm flutter analyze --no-pub
```

`/tmp/f8-analyze-final.log`：raw=50、unique=50，其中 tool/code_audit=38、其余=12，零新增。计数与翻译/保护校验摘要 `/tmp/f8-validation-summary.json`。

## GUI 与进程恢复

有界 fixture `/tmp/f8_gui.dart` 使用生产 SearchPage、生产聚合/单源结果页与无网络来源 fixture；windowManager.ensureInitialized/show。XDG config/data/cache 分别为 `/tmp/f8-xdg/{config,data,cache}`，业务数据 `/tmp/f8-gui-data`、缓存 `/tmp/f8-gui-cache`。正常 main/runner 没有为 fixture 改动。

运行环境 DISPLAY=:1、GDK_BACKEND=x11、LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib。`/tmp/f8_x11.py` 由已读核对的 B3 helper 复制并追加窗口内键盘与有界 resize，明确操作窗口 `0xa00002`；鼠标 release 后等待稳定，每张下列证据均已 view_image 核对。

注意：:1 桌面只有1080×760，普通 X11截图会裁掉1280窗口右侧，故不将裁切图当 expanded 完整证据。expanded 使用 fixture 中 RepaintBoundary 在鼠标释放800ms及 endOfFrame 后导出完整实际1280帧；compact 使用 X11 原生截图。xwininfo 核对窗口尺寸，截图没有拼接或重绘。

| 证据 | 场景与结果 |
|---|---|
| `/tmp/f8-frame-565588-0.png`（1280×800） | expanded浅色，真实重启恢复聚合+Plan B，来源芯片禁用、方案下拉显示p |
| `/tmp/f8-compact-profile.png`（600×740） | compact浅色，真实下拉选择Plan B后聚合状态正确 |
| `/tmp/f8-aggregate-destination.png` | 恢复后键盘输入book+Enter，实际聚合目的页只包含Platform B；完整请求审计见jsonl |
| `/tmp/f8-compact-dark-single.png`（600×740） | 深色主题单源B、normal临时默认选项，控件与主题清晰 |
| `/tmp/f8-compact-dark-fallback.png`（600×740） | 动态禁用B，即时回退A并在控件附近显示来源失效说明，未覆盖记忆B |
| `/tmp/f8-compact-dark-null.png`（600×740） | 恢复B后明确选Global settings，保持单源模式 |
| `/tmp/f8-frame-565588-1.png`（1280×740） | expanded深色，单源B+明确null，右侧下拉与布局完整可见 |
| `/tmp/f8-single-restart.png`（600×740） | 再次真实新PID恢复单源B+null，关键词空、normal选项，无溢出 |
| `/tmp/f8-single-destination.png`（600×740） | 新PID键盘输入single+Enter，实际单源结果页Platform B，page1/2，单次normal请求 |

`/tmp/f8-gui-audit.jsonl` 记录：

- PID559166 保存 `{mode:aggregated,sourceKey:a,profileId:p}`，退出；PID565588 启动读取相同记录。提交book产生 `route:aggregated:p`，仅B/page1/options[other]一次。
- PID565588 保存 `{mode:single,sourceKey:b,profileId:null}`，退出；PID568402 启动读取相同记录。提交single产生 `route:single:b:[normal]`，仅B/page1/options[normal]一次。
- PID554999 为初始截图fixture，已退出；最终四个已记录PID554999/559166/565588/568402均不在ps中，X11树中无F8窗口，只保留原有qq/clipboard窗口。

GUI过程的Enter提交为真实键盘事件；最终复选框保存后的焦点修复、在途保存重开保护与空态恢复反馈，另由最终25项真实组件测试复核。

## 正常构建与保护

```sh
export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897
export RUSTUP_TOOLCHAIN=1.92.0-x86_64-unknown-linux-gnu
fvm flutter build linux --debug --no-pub
git diff --check
```

正常main构建成功，`/tmp/f8-main-build.log`。显式使用已安装Rust1.92.0是为绕过一次工具链远端校验下载TLS故障；没有新增依赖、改pubspec或重生成lock。SDK cache与X11访问通过任务内窄权限执行，无自动审批拒绝待处理。

开工保护SHA `/tmp/f8-protected-start.sha256`；其中81个保护文件逐一完全一致（B3/B4源文件与测试、F8 proposal/design/spec、正式spec、main/runner、pubspec/lock、design-spec等）。同清单内共享translation.json因本次授权文案追加整体SHA不同，已额外逐语言逐旧key比较原值全同，仅两语言各新增上述5条。B4保护测试search_profile_flow_test.dart零diff。git diff --check通过，只有本交付列出的F8文件发生变化。

待 architect 独立复核批准；未自行提交、归档或push。

## Architect 独立复核（2026-11-04）

结论：符合本change契约，交owner人工验收。保持未提交、未归档、未push；F9尚未启动。

- 独立执行上述8文件回归：59通过、0失败、0skip，日志`/tmp/f8-architect-regression.log`。
- 独立analyze：raw/unique均50=38+12，与`/tmp/b3-planner-final-analyze.log`及executor最终日志的具体问题集合完全相同，零新增。独立日志`/tmp/f8-architect-analyze.log`。
- 独立核对81个保护文件SHA全部一致；translation.json仅zh_CN/zh_TW各追加5条，原有全部语言/词条原值不变。`git diff --check`和OpenSpec校验通过。5/5 tasks均有证据。
- 已逐张view_image抽查expanded浅色聚合+p、expanded深色单源B+null、compact深色失效回退、compact新PID单源恢复，以及聚合/单源实际目的页。结合jsonl核对559166→565588→568402持久恢复与请求sourceKey/profileId/options及各一次。
- 正常main构建日志成功；独立核对kernel含package:venera_next/main.dart且无f8_gui.dart。ps无554999/559166/565588/568402，X11只余原有qq/Chromium clipboard小窗口，fixture清理正确。
- 最终4份源码/测试/翻译SHA记录`/tmp/f8-architect-reviewed-files.sha256`，独立复跑后无源代码修改。

Owner建议路径：选聚合及某方案→关闭/重开搜索→重启后再搜索；改为单源和全局设置→重启再搜索；检查所选来源/方案保持，默认方案不被改变。来源不可用时应有可见回退说明且不发往失效来源。
