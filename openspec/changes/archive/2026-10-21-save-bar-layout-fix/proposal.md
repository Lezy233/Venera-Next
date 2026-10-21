# Proposal

## Why

owner 报告两个页面的相同视觉缺陷：「收藏」页切换文件夹时、「设置 → 阅读」分类修改任意阅读模式设置时，整个页面会先下移约 42px 再弹回原位。纯显示层问题，不影响功能，但出现在最高频的操作路径上（每次保存都可见）。

2026-10-21 的诊断（executor 通过 Dart VM 驱动真实 UI 复现并做像素断言）确认根因：`SettingsSaveState` 保存状态条（18px 指示器 + 上下各 12px padding = 42px）在保存进行期间**以插入正文布局流的方式**临时占位，保存结束即移除，导致正文下移-回弹。三个受害点：收藏页 `favorites_page.dart:117`（Column 中 Expanded 前插入）、阅读模式 `reader_mode.dart:253`、阅读设置外层 `reader.dart:354`（Sliver）。该机制由 f1ddfb1（2026-10-05）引入，**早于 settings-ia-cleanup，与该 change 无关**。

## What Changes

- 保存反馈从「插入正文布局流」改为「覆盖层渲染」：保存状态条以浮动形式呈现在内容区顶部，不占据、不推挤正文布局
- 三个接入点（收藏页、阅读模式、阅读设置外层）统一改用覆盖层模式
- 新增回归测试：阻塞保存 Future，断言保存前/中/后正文坐标不变

## Capabilities

### New Capabilities

- `components/save-feedback`: 保存反馈的呈现能力——保存状态（保存中/成功/失败）以不占用正文布局的覆盖层形式呈现，任何页面接入后保存期间正文坐标保持不变

### Modified Capabilities

（无——项目尚无该能力的正式 spec）

## Impact

- 代码：`lib/components/settings_save_state.dart`（核心改造）、`lib/features/favorites/favorites_page.dart`、`lib/features/settings/reader_mode.dart`、`lib/features/settings/reader.dart`（三个接入点）
- 数据：无（保存语义、admission/protect 机制、数据读写全部不变）
- 翻译：大概率无新词条（复用现有保存状态文案）；若覆盖层需要新文案则走 `.tl` 系统补 zh_CN/zh_TW
- 依赖：无新依赖

## Out of Scope

- `main_page.dart:74` → `desktop_chrome.dart:109` 的构建期 setState 缺陷（3995a9f 引入）：独立缺陷，记入 BACKLOG 另行处理
- 保存反馈的视觉样式重设计（本次仅迁移呈现层位置，样式沿用现有状态条）
- 移动端专属适配（覆盖层方案需保持移动端可用，但不针对移动端重新设计）
