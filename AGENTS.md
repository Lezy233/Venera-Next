# AGENTS.md — Venera-Next 多 agent 协作入口

> 任何 agent（Kimi Code / dsh / 其他）在本仓库开局的**第一份必读文件**。
> 读完本文后按「最小阅读清单」继续，不要全库探索。

## 1. 项目一句话

Venera-Next 是 PC 优先的 Flutter 漫画阅读器，fork 自 venera-next，**已与上游决裂**
（不为保留上游结构/行为而保留；重构是预期行为，移动端可用但不再是设计中心）。

## 2. 角色路由（开局先确认你是谁）

| 角色 | 承担者 | 职责 | 禁区 |
|------|--------|------|------|
| **规划者** | Kimi | 写 proposal/spec/design/tasks；验收判定时对照 spec 判「符合/不符合/契约该改」；维护 BACKLOG/ROADMAP/design-spec.md | 不执行实现任务，不做代码 debug |
| **执行者** | dsh / deepseek-v4.1f | 按 change 的 tasks.md 逐个实现并勾选；flutter analyze 自检；交付说明 | 不得改 proposal/spec/design、design-spec.md、openspec/specs/ 下正式 spec；发现契约冲突须停止并报告，不自行改契约 |
| **验收人** | owner（人类） | 最终人工验收；验收通过后才归档 | — |

执行 agent 若被 owner 直接派活，默认走「执行者」列；若被 Kimi 派活做规划产物，走「规划者」列。

## 3. 硬规则（踩过坑，勿重蹈）

- **`pubspec.lock` 禁止重新生成**（项目铁律；flutter pub upgrade/add 会动它，动完必须还原）。
- 新 UI 文案必须走 `.tl` 翻译系统，并在 `assets/translation.json` 补 **zh_CN 和 zh_TW** 词条。
- `flutter analyze` 基线**已有 12 个预存在问题**（含 `settings_page_test.dart` 的 pdfrx 0.4.5 编译冲突，基线上同样失败）。交付标准 = **不新增**问题，不是清零；不要顺手修基线问题。
- **阅读器深色例外已彻底移除**（owner 2026-10-20 决定）：阅读器 chrome 跟随应用当前主题，任何 change 不得重新引入深色沉浸例外。
- 设计方向 = **现代极简**：浅色内容区 + 浅色壳，动态取色为唯一强调色来源，层级靠留白与 1px 分隔线。深色内容区主题是二期。
- 每完成一个任务**立即**在 tasks.md 勾选 `[x]` 并写备注，不批量补勾。
- **图片提交规则**（owner 2026-10-21）：界面截图一律不提交（已在 .gitignore 忽略 png/jpg/jpeg/gif/webp/bmp）。例外：README/app 资产等确需入库的图片，须在提交信息中特殊说明并 `git add -f`。GUI 走查截证留在本地或 change 目录但不入库。
- 交接介质是**仓库文件 + git**，不是对话历史；每个 change 开新会话执行（省 token），开局读本文件 + 对应 change 目录即可。

## 4. 当前状态（规划者维护，执行前核对）

- 分支：`redesign-2026`，已与远程同步（github.com/Lezy233/Venera-Next）。
- 已完成并归档：`design-system-foundation`（设计基座 + 验收缺陷 5.1–5.3 修复）；`settings-ia-cleanup`（2026-10-21 归档）；`save-bar-layout-fix`（2026-10-21 归档，commit 9669b5c）。
- **`desktop-shell-polish` 已实现完毕（tasks 11/11，commit 8095371），待 owner 人工验收**；验收通过运行 `openspec archive desktop-shell-polish --yes`。
- **`desktop-search-context` 已实现完毕（tasks 9/9，commit 12bdeed），待 owner 人工验收**；验收通过运行 `openspec archive desktop-search-context --yes`。
- 排队（按序执行）：reader-quick-settings-panel。bugfix 候选：B1（chrome 构建期绑定缺陷，见 BACKLOG）。
- 新功能愿景与批次（F1–F7）见 `openspec/BACKLOG.md`。

## 5. 最小阅读清单

1. 本文件（AGENTS.md）
2. `openspec/ROADMAP.md` — 执行顺序与依赖
3. 若执行/验收某个 change：`openspec/changes/<name>/` 下 proposal、design、specs/、tasks.md 全部
4. 涉及 UI 外观判定：`design-spec.md`（设计契约）

**默认禁止全库探索。** 以上文件 + 被指名的源文件即全部上下文。

## 6. Herdr 协作约定（如运行在 herdr 中）

- 本机 herdr 0.9.5。Kimi Code 原生支持（`--kind kimi`）；**dsh-tui 不被识别**，只当普通终端。
- orchestrator（通常是 Kimi）驱动 dsh 用 **pane 原语**：
  喂任务 `herdr pane send-text <pane> "<任务文本>"`（+ Enter），
  等交付 `herdr pane wait-output <pane> --regex "交付|完成"`，读结果 `herdr pane read <pane>`。
- 反馈回路（三层，按序使用）：① herdr 读屏（即时）→ ② openspec tasks.md 勾选 + 交付说明（会话内）→ ③ git commit/push（持久，全员可见）。
- 状态真相永远在仓库文件里：任何 agent 报告「完成」时，先用 git log / tasks.md 核对，再看屏幕说法。
