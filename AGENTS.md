# AGENTS.md — Venera-Next 多 agent 协作入口

> 任何 agent（Kimi Code / dsh / 其他）在本仓库开局的**第一份必读文件**。
> 读完本文后按「最小阅读清单」继续，不要全库探索。

## 1. 项目一句话

Venera-Next 是 PC 优先的 Flutter 漫画阅读器，fork 自 venera-next，**已与上游决裂**
（不为保留上游结构/行为而保留；重构是预期行为，移动端可用但不再是设计中心）。

## 2. 角色路由（开局先确认你是谁）

| 角色 | 承担者 | 职责 | 禁区 |
|------|--------|------|------|
| **规划者** | codex（2026-10-25 起，自 Kimi 移交；此前为 Kimi） | 写 proposal/spec/design/tasks；验收判定时对照 spec 判「符合/不符合/契约该改」；维护 BACKLOG/ROADMAP/design-spec.md | 不做代码 debug（与执行者同体时除外，见下） |
| **执行者** | codex（herdr pane w3:p2） | 按 change 的 tasks.md 逐个实现并勾选；flutter analyze 自检；交付说明 | 不得改 proposal/spec/design、design-spec.md、openspec/specs/ 下正式 spec；发现契约冲突须停止并报告，不自行改契约 |
| **验收人** | owner（人类） | 最终人工验收；验收通过后才归档 | — |

**同体协议（owner 2026-10-25 裁决，为节省 Kimi 额度，规划与执行由 codex 一肩挑）**：失去独立规划者复核，用以下自检协议补强——
1. 实现完成后、提交前，必须**独立复验**：重跑 `fvm flutter analyze --no-pub`（=50 项基线，零新增）、重跑新增测试与相关回归套件、核对 tasks.md 勾选、核对受保护文件（design-spec.md、openspec/specs/**、pubspec.yaml/lock）零 diff；复验结果写进交付报告。
2. **设计裁决与事实勘误分离**：proposal/design/spec/tasks 中的事实错误（计数、路径、与代码现状不符）可自行勘误并提交；**涉及取舍的设计裁决**（语义、交互、范围变更）必须停下来问 owner，不得自问自答。
3. owner 的人工验收仍是最终闸门；交付报告必须附「验收路径建议」。

执行 agent 若被 owner 直接派活，默认走「执行者」列；若被派活做规划产物，走「规划者」列。

## 3. 硬规则（踩过坑，勿重蹈）

- **`pubspec.lock` 禁止重新生成**（项目铁律；flutter pub upgrade/add 会动它，动完必须还原）。
- 新 UI 文案必须走 `.tl` 翻译系统，并在 `assets/translation.json` 补 **zh_CN 和 zh_TW** 词条。
- `flutter analyze` 基线 = **50 项**（tool/code_audit 环境 38 项 + lib/test 预存在 12 项，含 `folder_order_ownership_test.dart` 编译错误与 pdfrx 0.4.5 冲突）。交付标准 = **不新增**问题，不是清零；不要顺手修基线问题。
- **环境要点**：Flutter 走 fvm 3.47.7（.fvmrc）；跑 fvm 前 `export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897`；pub-cache 热补丁 `~/.pub-cache/hosted/pub.dev/pdfrx_engine-0.4.5/lib/src/native/pdf_file_cache.dart` 368/380/382/392 行 `cache.`→`cache!.`（被清需重打）；GUI 验证 `DISPLAY=:1` 用隔离数据目录，截图只留 /tmp。
- **阅读器深色例外已彻底移除**（owner 2026-10-20 决定）：阅读器 chrome 跟随应用当前主题，任何 change 不得重新引入深色沉浸例外。
- 设计方向 = **现代极简**：浅色内容区 + 浅色壳，动态取色为唯一强调色来源，层级靠留白与 1px 分隔线。深色内容区主题是二期。
- 每完成一个任务**立即**在 tasks.md 勾选 `[x]` 并写备注，不批量补勾。
- **图片提交规则**（owner 2026-10-21）：界面截图一律不提交（已在 .gitignore 忽略 png/jpg/jpeg/gif/webp/bmp）。例外：README/app 资产等确需入库的图片，须在提交信息中特殊说明并 `git add -f`。GUI 走查截证留在本地或 change 目录但不入库。
- 交接介质是**仓库文件 + git**，不是对话历史；每个 change 开新会话执行（省 token），开局读本文件 + 对应 change 目录即可。

## 4. 当前状态（规划者维护，执行前核对）

- 分支：`redesign-2026`，已与远程同步（github.com/Lezy233/Venera-Next）。
- 已完成并归档：`design-system-foundation`（设计基座 + 验收缺陷 5.1–5.3 修复）；`settings-ia-cleanup`（2026-10-21 归档）；`save-bar-layout-fix`（2026-10-21 归档，commit 9669b5c）；`desktop-shell-polish`（2026-10-21 归档，commit ae00919）；`desktop-search-context`（2026-10-21 归档，commit 5833677）；`reader-quick-settings-panel`（2026-10-22 归档，commit 11c495e）；`save-feedback-placement-fix`（2026-10-22 归档，commit 63d45e7）；`chrome-binding-lifecycle-fix`（2026-10-22 归档，commit 0121b81，BACKLOG B1）；`keyboard-shortcuts`（2026-10-23 归档，commit b735663，BACKLOG F3，批次 A——动作注册表/多键位自定义/冲突检测/独立主分类/平台默认键）；`reader-mode-presets`（2026-10-23 归档，commit 1c8fbc3，BACKLOG F4，批次 A——阅读模式方案 CRUD + 面板方案切换）。
- ROADMAP 队列已清空，bugfix 候选已清，批次 A（F3+F4）完成。下一批：批次 B 锚点 F1（页面多开，propose 首要做 design-spec.md 框架容纳检查）或批次 C（F5/F6+F7），排期由 owner 决定，见 `openspec/BACKLOG.md`。

## 5. 最小阅读清单

1. 本文件（AGENTS.md）
2. `openspec/ROADMAP.md` — 执行顺序与依赖
3. 若执行/验收某个 change：`openspec/changes/<name>/` 下 proposal、design、specs/、tasks.md 全部
4. 涉及 UI 外观判定：`design-spec.md`（设计契约）

**默认禁止全库探索。** 以上文件 + 被指名的源文件即全部上下文。

## 6. Herdr 协作约定（如运行在 herdr 中）

- 本机 herdr 0.9.5。Kimi Code 原生支持（`--kind kimi`）；**dsh-tui 不被识别**，只当普通终端。
- orchestrator 驱动执行 agent（codex，pane w3:p2）用 **agent 原语**：
  派活 `herdr agent prompt w3:p2 "<任务全文>"`（长文本先写 /tmp 文件再 `"$(cat /tmp/x.txt)"`），
  读交付 `herdr agent read w3:p2 --source recent-unwrapped --lines 200`，
  阻塞处理 `herdr agent wait w3:p2 --until blocked` + `herdr agent send-keys w3:p2 <key>`（选择题 down/up+enter，打开问题 shift+left）。
- 反馈回路（三层，按序使用）：① herdr 读屏（即时）→ ② openspec tasks.md 勾选 + 交付说明（会话内）→ ③ git commit/push（持久，全员可见）。
- 状态真相永远在仓库文件里：任何 agent 报告「完成」时，先用 git log / tasks.md 核对，再看屏幕说法。
- openspec CLI：`openspec validate --changes <name>` / `openspec validate --specs` / `openspec archive <name> --yes`（owner 验收通过后）。
