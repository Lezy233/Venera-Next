# Proposal

## Why

审计 P1-6：顶栏命令中心的外观提示语已随上下文切换（quick win 落地），但行为漂移未解决——阅读器内按回车打开的是章节列表（跳转而非过滤），收藏页是本地过滤，其他页打开全局搜索页。同一 affordance 三种行为且阅读器内的行为与"搜索章节"的提示语不符，构成错误级心智模型冲突（mistake）。统一 UI/UX 要求命令中心行为在三个上下文中都可预测。

## What Changes

- 阅读器内：命令中心变为真正的章节过滤（输入即过滤当前章节列表，回车跳转到首个匹配章节）
- 收藏页：保持本地过滤，但输入为空时显示占位提示（如"输入以过滤收藏"）
- 其他页：打开全局搜索页（现状保留）
- Ctrl/Cmd+F 与命令中心行为完全对齐

## Capabilities

### New Capabilities

- `shell/command-center`: 命令中心的统一搜索能力——外观提示语与行为在全局搜索/收藏过滤/章节过滤三上下文一一对应，输入即反馈

### Modified Capabilities

（无）

## Impact

- 代码：`lib/app_shell/desktop_chrome.dart`（`focusSearch`/`submitSearch` 分流逻辑）、`lib/app_shell/desktop_top_bar.dart`、`lib/features/reader/chapters.dart`（章节列表需暴露过滤入口）
- 依赖：建议在 design-system-foundation（断点统一，命令中心可见性规则归位）之后实施
