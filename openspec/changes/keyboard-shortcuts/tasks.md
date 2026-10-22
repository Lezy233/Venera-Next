# Tasks

> 硬规则（全程有效）：契约文件（design-spec.md、openspec/specs/**、pubspec.yaml/lock）禁改；pubspec.lock 不得重新生成；`flutter analyze` 基线 = 50 项（tool/code_audit 38 + lib/test 12），交付不得新增；界面截图一律不入库（.gitignore 已忽略图片，例外须提交信息说明 + `git add -f`）；契约/任务歧义必须停工上报，不得自行裁量；工作区必须干净，提交前问 Kimi。

## 1. 注册表基建

- [ ] 1.1 新建动作注册表模块（design D1）：`ShortcutContext { global, reader }`、`ShortcutAction`（id/titleKey/context/defaultBindings/runner，runner 签名携带 KeyEvent 以保留连发语义）、静态默认表、覆盖合并求值、组合键编码/解码与展示格式化
- [ ] 1.2 默认表按 design D2 落地（4 迁移全局键 + Ctrl/Cmd+1..4 新增；reader 方向键四动作 + F12 + Space/PageDown/PageUp），macOS meta / 其余 control 的平台适配沿用 primaryShortcut 语义

## 2. 迁移与生效路径

- [ ] 2.1 main.dart 顶层绑定改为由注册表 global 条目动态构建，`desktop_chrome.dart` 的 desktopShortcuts 硬编码删除；Esc→pop 保留不变
- [ ] 2.2 阅读器键位接入注册表（reader_page KeyboardListener 先查注册表）：方向键 runner 仅委托视图现有 handler（continuous 的 vertical/reverse 语义、gallery 的 Timer 连发零改动）；F12/Space/PageUp/PageDown 调既有翻页/全屏入口
- [ ] 2.3 文本输入守卫（design D5）：EditableText 聚焦时 global 注册键不触发；阅读器既有焦点守卫接入同一检查；Esc 局部行为（全局 pop、exit_guard、右键菜单）不变

## 3. 覆盖存储与冲突检测

- [ ] 3.1 `settings['shortcutOverrides']` 持久化（编码见 design D3）：改键/清除/重置即时写入并经 appdata.updateSettings 生效，重启保留，缺省=默认
- [ ] 3.2 冲突检测（design D4）：同上下文重复拒绝保存并显示占用动作标题；跨上下文允许；持久化数据自身冲突时后加载者回退无键位；同动作多默认键不算冲突

## 4. 设置页与菜单

- [ ] 4.1 APP 分类页（`lib/features/settings/app.dart`）内以 CallbackSetting 新增「快捷键」入口，push 独立快捷键页（不新增主分类、不改动 categories/icons/switch；先例 about.dart About→Debug）；页面内分组列出动作+生效键位，点击捕获（Esc 取消），清除/重置/全部重置，冲突文案走 .tl；改动即时生效不纳入显式保存栏（若 _SettingsEditingScope 框架强约束冲突，停工上报）；新页面 + settings.dart export
- [ ] 4.2 translation.json 新增词条并同步 zh_CN + zh_TW（动作标题、分组标题、捕获提示、冲突提示、清除/重置文案）
- [ ] 4.3 macOS PlatformMenuBar 菜单项 accelerator = 注册表当前生效键位；键位被清除的项不显示（design D7）

## 5. 验证

- [ ] 5.1 单元/组件测试：注册表求值（默认/覆盖/清除/重置）、编码往返、冲突检测（同上下文拒绝/跨上下文允许）、文本守卫（EditableText 聚焦不触发 global 键）、存储往返（重启模拟）
- [ ] 5.2 行为对照测试：4 全局键 + 阅读器方向键/F12 默认行为逐项与迁移前一致（含 continuous reverse 方向语义、gallery 连发）
- [ ] 5.3 `fvm flutter analyze --no-pub` 无新增（基线 50 项）；相关测试全绿（日志存 /tmp）
- [ ] 5.4 GUI 走查（DISPLAY=:1，隔离数据目录）：全局 4 键 + Ctrl+1..4、阅读器方向/Space/F12、设置页捕获改键→立即生效→重启保留、搜索框聚焦时 Ctrl+B 不触发；截图仅存本地不入库
