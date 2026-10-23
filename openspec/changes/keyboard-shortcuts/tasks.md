# Tasks

> 硬规则（全程有效）：契约文件（design-spec.md、openspec/specs/**、pubspec.yaml/lock）禁改；pubspec.lock 不得重新生成；`flutter analyze` 基线 = 50 项（tool/code_audit 38 + lib/test 12），交付不得新增；界面截图一律不入库（.gitignore 已忽略图片，例外须提交信息说明 + `git add -f`）；契约/任务歧义必须停工上报，不得自行裁量；工作区必须干净，提交前问 Kimi。

## 1. 注册表基建

- [x] 1.1 新建动作注册表模块（design D1）：`ShortcutContext { global, reader }`、`ShortcutAction`（id/titleKey/context/defaultBindings/runner，runner 签名携带 KeyEvent 以保留连发语义）、静态默认表、覆盖合并求值、组合键编码/解码与展示格式化
  - 新增 foundation/shortcuts/shortcut_registry.dart：常量动作表、携带 KeyEvent 的 runner/运行时 target、纯求值与组合键 codec；D8 的上下文/栈升级入口写入模块注释。
- [x] 1.2 默认表按 design D2 落地（4 迁移全局键 + Ctrl/Cmd+1..4 新增；reader 方向键四动作 + F12 + Space/PageDown/PageUp），macOS meta / 其余 control 的平台适配沿用 primaryShortcut 语义
  - 静态表登记 8 个 global + 7 个 reader 动作；nextPage 两个默认绑定，macOS 仅默认 global Ctrl 映射为 Meta，用户显式覆盖保持原修饰键。

## 2. 迁移与生效路径

- [x] 2.1 main.dart 顶层绑定改为由注册表 global 条目动态构建，`desktop_chrome.dart` 的 desktopShortcuts 硬编码删除；Esc→pop 保留不变
  - 新增 app_shell/global_shortcuts.dart，以 ShortcutManager 每次事件读取 registry global 生效表；main.dart 改挂 GlobalShortcuts，删除 desktopShortcuts 表；Esc→pop 原代码保留。既有章节搜索测试改走新入口。
- [x] 2.2 阅读器键位接入注册表（reader_page KeyboardListener 先查注册表）：方向键 runner 仅委托视图现有 handler（continuous 的 vertical/reverse 语义、gallery 的 Timer 连发零改动）；F12 调既有全屏入口；Space/PageDown/PageUp 按 design D2 分模式（gallery→toNextPage/toPrevPage；continuous→滚动一视口高，边界无操作、不自动切章）
  - 新增 ReaderShortcutSession 保留按下动作直到松键；ReaderState 通过可消费的 Focus 分发，映射规范方向事件给原视图 handler。gallery/continuous 的原 handleKeyEvent 正文不改；continuous 新增独立 scrollKeyboardPage，沿用既有 context.height 高度单位（含横向连续模式）滚动并 clamp 边界，不走跳图/切章入口。F12 保留原 KeyUp 与先于视图 primary-focus 守卫的特例。
- [x] 2.3 文本输入守卫（design D5）：EditableText 聚焦时 global 注册键不触发；阅读器既有焦点守卫接入同一检查；Esc 局部行为（全局 pop、exit_guard、右键菜单）不变
  - 统一 shortcutTextInputFocused 检查 EditableText 祖先；global manager 在守卫前不执行任何动作，reader 保留 primary-focus 约束并消费匹配事件，跨上下文同键由 reader 优先。Esc、progress_bar 的局部 Home/End 不改。

## 3. 覆盖存储与冲突检测

- [x] 3.1 `settings['shortcutOverrides']` 持久化（编码见 design D3）：改键/清除/重置即时写入并经 appdata.updateSettings 生效，重启保留，缺省=默认
  - 新增 shortcut_store.dart：改键/清除/单项重置/全部重置均经 appdata.updateSettings 串行草稿提交，缺省读取为空覆盖。
- [x] 3.2 冲突检测（design D4）：同上下文重复拒绝保存并显示占用动作标题；跨上下文允许；持久化数据自身冲突时后加载者回退无键位；同动作多默认键不算冲突
  - 冲突检查在提交事务内依据当前生效表执行；同域拒绝、跨域允许；加载求值按常量表顺序认领，后加载冲突动作整项无键位。

## 4. 设置页与菜单

- [x] 4.1 APP 分类页（`lib/features/settings/app.dart`）内以 CallbackSetting 新增「快捷键」入口，push 独立快捷键页（不新增主分类、不改动 categories/icons/switch；先例 about.dart About→Debug）；页面内分组列出动作+生效键位，点击捕获（Esc 取消），清除/重置/全部重置，冲突文案走 .tl；改动即时生效不纳入显式保存栏（若 _SettingsEditingScope 框架强约束冲突，停工上报）；新页面 + settings.dart export
  - 新增 KeyboardShortcutsSettings，APP/Behavior 下 CallbackSetting push 独立页并 export；不改主分类。分组显示、Focus 捕获、Esc 取消、冲突标题、清除/单项重置/全部重置均接入 ShortcutStore，无显式保存栏。捕获期间统一暂停应用键位，焦点离开时自动取消捕获，避免旧页面阻塞全局键。
- [x] 4.2 translation.json 新增词条并同步 zh_CN + zh_TW（动作标题、分组标题、捕获提示、冲突提示、清除/重置文案）
  - 新增动作/分组/捕获/冲突/清除/重置英文 key，translation.json 同步补 zh_CN/zh_TW；已有词条复用，不新增依赖。
- [x] 4.3 macOS PlatformMenuBar 菜单项 accelerator = 注册表当前生效键位；键位被清除的项不显示（design D7）
  - macOS 菜单监听 settings/Focus/捕获状态，以同一 registry 求值提供 Settings/Search/左右栏/主页面导航/阅读器全屏 accelerator。清除即不显示；编辑捕获或文本输入时临时暂停对应原生 accelerator，避免绕过 Flutter 输入守卫。Windows/Linux 内联菜单未改；全屏菜单委托当前 Reader 的 toggleFullscreen 回调，保留阅读会话的窗口所有权。原生菜单执行时也复核捕获/文本焦点，覆盖菜单重建前的旧 accelerator；普通菜单点击仍可用，4 项组件补测全绿（/tmp/shortcuts-menu-final-tests.log）。

## 5. 验证

- [x] 5.1 单元/组件测试：注册表求值（默认/覆盖/清除/重置）、编码往返、冲突检测（同上下文拒绝/跨上下文允许）、文本守卫（EditableText 聚焦不触发 global 键）、存储往返（重启模拟）
  - shortcut_registry_test.dart 4 项 + app_shell/keyboard_shortcuts_test.dart 4 项通过；覆盖默认/平台/编码、冲突、动作释放、global 文本守卫、真实捕获 UI、JSON 持久化 reload/clear/reset、原生菜单求值。连同 chapter_search 4 项共 12 绿，日志 /tmp/shortcuts-tests-initial.log。
- [x] 5.2 行为对照测试：4 全局键 + 阅读器方向键/F12 默认行为逐项与迁移前一致（含 continuous reverse 方向语义、gallery 连发）
  - 新增实际 Reader 集成测试 9 项：七种模式逐一比较四方向；gallery 的 Space/PageDown/PageUp；四种连续模式一视口步长与边界不启动滚动/不切章；改键后的 gallery Timer 连发及覆盖改变后的 KeyUp 停止；F12 KeyUp 时机与覆盖。上述 9 项纳入最终 211 项回归全绿，/tmp/shortcuts-regression.log（最终按 D2 高度单位再次验证）。原 4 全局键与 1–4 导航/阅读器搜索分流亦已组件覆盖。
- [x] 5.3 `fvm flutter analyze --no-pub` 无新增（基线 50 项）；相关测试全绿（日志存 /tmp）
  - fvm flutter analyze --no-pub：50（tool/code_audit 38 + lib/test 12），/tmp/shortcuts-analyze.log；相关套件 211 项通过、23 项既有平台跳过，/tmp/shortcuts-regression.log。涵盖新增 17 项及既有完整 Reader 集成、壳层、连续输入、就地设置和 APP 控件持久化。原生菜单执行时守卫及捕获失焦清理补测 4 项通过，/tmp/shortcuts-menu-final-tests.log。
- [x] 5.4 GUI 走查（DISPLAY=:1，隔离数据目录）：全局 4 键 + Ctrl+1..4、阅读器方向/Space/F12、设置页捕获改键→立即生效→重启保留、搜索框聚焦时 Ctrl+B 不触发；截图仅存本地不入库
  - DISPLAY=:1、隔离目录 /tmp/keyboard-shortcuts-gui-data、真实 MainPage/FavoritesPage/Reader/APP 设置页；宿主 /tmp/keyboard_shortcuts_gui.dart 补齐 DataSync/FollowUpdates/Favorites/History scopes，使用生成的本地漫画，不访问真实用户数据。
  - 全局实测：Ctrl+1..4 的 tab=0/1/2/3；Ctrl+, 打开设置；Ctrl+B left=true→false；Ctrl+Alt+B right=false→true；Ctrl+F 聚焦命令中心后再次 Ctrl+B，left 保持 false。APP→Behavior→Keyboard shortcuts 的 CallbackSetting 入口、捕获改为 Ctrl+Shift+P 均通过。截图 /tmp/shortcuts-app-category.png、/tmp/shortcuts-remapped-settings.png、/tmp/shortcuts-text-guard.png。
  - 即时/重启：修改后 Ctrl+, 无操作、Ctrl+Shift+P 打开设置；完全结束并重新启动进程，JSON 覆盖仍为 app.openSettings=ctrl+shift+p，旧键仍无操作、新键仍打开设置。证据 /tmp/shortcuts-restart-old-disabled.png、/tmp/shortcuts-restart-new-settings.png；日志 /tmp/shortcuts-gui.log、/tmp/shortcuts-gui-restart.log；最终高度步长实证 /tmp/shortcuts-gui-height-final.log。
  - 阅读器：本地 gallery Right 1→2、Left 2→1、Space 1→2、PageDown 2→3、PageUp 3→2；重启后同样可用。F12 的 frameHidden=false→true→false，顶栏隐藏/恢复；Ctrl+F 输入 sun 并 Enter 进入第 2 章 Sunrise。continuous Down 滚动 225px，Space 225→1125（一视口高 900px，与旧方向键 225px 的四倍一致），PageUp 1125→225，Up 反向滚动；改键后的 Ctrl+Shift+P 仍分流到阅读快捷设置。截图 /tmp/shortcuts-reader-final-space.png、/tmp/shortcuts-fullscreen-final-enter.png、/tmp/shortcuts-fullscreen-final-exit.png、/tmp/shortcuts-height-space.png、/tmp/shortcuts-reader-remapped-settings.png。
  - 截图全部 /tmp 留存、不入库。macOS 原生系统菜单无实机环境，以菜单模型/accelerator/全屏委托组件测试覆盖（/tmp/shortcuts-menu-final-tests.log，4 项全绿）；Windows/Linux 内联菜单未改。收藏/阅读器注册时既有构建期通知日志仍可见（setLeftSidebar/setReaderActions 等），只记录不扩修；临时 GUI 宿主早期缺失 scope/Material 已补齐后重新走查。

## 6. 验收修订（owner 2026-10-22 反馈）

- [x] 6.1 诊断并修复「漫画页面被顶栏遮挡一部分」：先对照 cc71d9a^（改动前）判定是否本 change 引入（GUI 双版本对照，记录证据）；无论是否回归，在本 change 内修复并回归验证
  - 真实应用 main.dart 双版本（隔离 XDG 数据、同一红边本地漫画、横向连续模式）对照：63f5ec4=cc71d9a^ 与 b690395 均为 viewport y=4、height=892、padding.top=36，顶栏 [4,40) 相交 36px，属于既有问题；GlobalShortcuts 不改变尺寸。ReaderScaffold 仅桌面正文消费 SafeArea，控件/WindowFrame 不改；修复后 viewport y=40、height=856、padding=0，相交 0px。三模式几何回归（画廊/纵向连续/横向连续，显示→隐藏→恢复）3 绿；日志 /tmp/shortcuts-revision-{before,current,fixed}-probe.log、geometry-{red,green}.log；截图 /tmp/shortcuts-revision-{before-reader,current-reader-probe,fixed-reader}.png，仅本地。
- [x] 6.2 快捷键设置入口改为**独立主分类**（owner 裁决，取代 4.1 的 APP 内入口方案）：categories/icons/switch 三处登记 + settings.dart export，撤销 app.dart 的 CallbackSetting 入口；以修订后的 design D6 与 settings/navigation delta 为准
  - SettingsPage 追加第 8 分类（保留既有索引），categories/icons 与两种布局的内容 switch 均登记 KeyboardShortcutsSettings；settings.dart 已有 export，保留；撤销 APP CallbackSetting。shortcut category follows settings navigation at 600.0/1000.0 两项通过，验证 compact push/back 与宽屏右栏初始着陆、根路由不 push；/tmp/shortcuts-revision-categories.log。
- [x] 6.3 同一动作**多键位**（owner 裁决）：覆盖存储改 List（design D3：键不存在=默认、空列表=显式解绑）；设置页逐键显示/添加/单独删除；冲突检测逐键进行；既有单键持久化数据兼容（读取旧格式视为单元素列表）
  - 覆盖归一化为 Map<String,List<String>>，兼容旧字符串/旧空字符串；缺省默认、空列表解绑，串行事务内逐键检查冲突并去重。UI 的 InputChip 点击替换/单独删除、添加按钮追加；清除与重置保留。新增双语 Add/Remove shortcut；新增列表求值与旧 JSON reload/并发追加/第二键冲突测试，并扩展真实捕获测试验证原键仍触发、替换只影响目标键、逐键删除即时失效。注册表+壳层快捷键 12 项全绿，/tmp/shortcuts-revision-multi-tests.log。
- [x] 6.4 win/linux 右栏切换默认键改 **Ctrl+Shift+B**（owner 裁决，macOS 保持 Cmd+Alt+B）：注册表默认值按平台求值；更新相关测试断言与 zh 文案
  - 常量动作表保留默认列表并增加 macOS 专用列表，bindingsForPlatform 统一求值；win/linux Ctrl+Shift+B、macOS Cmd+Alt+B，用户显式旧 Ctrl+Alt+B 覆盖仍保留。默认表/旧键不触发/新键右栏切换组件断言已更新，快捷键套件 12 项全绿（/tmp/shortcuts-revision-platform-tests.log）。词条不含硬编码键位示例，无需额外改译文。
- [x] 6.5 复验：analyze 基线 50 无新增；快捷键相关测试（含 6.2–6.4 更新）全绿；GUI 走查遮挡修复 + 新入口 + 多键位 + Ctrl+Shift+B
  - 中断恢复后完整复验：`fvm flutter test --no-pub test/foundation/shortcuts test/app_shell test/features/reader test/features/settings/settings_page_test.dart test/features/settings/settings_inplace_editing_test.dart test/features/settings/app_controls_persistence_test.dart`，952 项通过、25 项既有跳过；日志 /tmp/shortcuts-revision-regression-final.log。注册表/快捷键相关 12 项包含在内，分类导航 600/1000 宽度、追加/替换/删除、旧字符串迁移、逐键冲突、平台默认及菜单回归均通过。
  - 6.1 补充：仅加 SafeArea 会使连续视图 PhotoView 仍取安全区外 Reader.size，产生二次居中裁切及 4 项 loading-neighbor 页码回归；以 LayoutBuilder 使用实际正文约束修正。新增内外高度一致断言先红后绿（/tmp/shortcuts-viewport-inner-red.log、/tmp/shortcuts-viewport-inner-green.log）；7 种模式的顶栏显示/隐藏/恢复几何测试 + 上述 4 项页码回归合计 11 绿，亦纳入 952 项完整回归。原方向键 handler/连发逻辑不改。
  - 最终 `fvm flutter analyze --no-pub` = 50（tool/code_audit 38 + lib/test 12），无新增；/tmp/shortcuts-revision-analyze-final.log。
  - DISPLAY=:1 运行真实 app.main（/tmp 临时入口仅生成本地测试漫画、分发输入及记录几何；隔离 XDG 数据目录 /tmp/shortcuts-revision-final-data）。画廊/纵向连续/横向连续 viewport 均 y=40、height=856，顶栏 [4,40) 交集 0px，红边完整；F12 隐藏后 y=4、恢复后 y=40。独立主分类直接可达；添加 Ctrl+Shift+P 后保留 Ctrl+,，点击旧键替换为 Ctrl+Shift+Q 后 P 保留，删除 P 后仅剩 Q，JSON 实际存储为列表。收藏页选 All 后 Ctrl+Shift+B 使 right=false→true→false，Ctrl+Alt+B 保持不变。日志 /tmp/shortcuts-revision-final-gui.log，截图 /tmp/shortcuts-revision-final-{reader,gallery,vertical,horizontal,fullscreen,restored,category,add,replace,delete,right-open,old-key-noop,right-closed}.png，仅本地。
  - 前次中断前的 /tmp 对照文件已因桌面重启丢失，6.1 的双版本测量记录保留；本轮几何及 GUI 截证已重新生成。macOS 无实机，平台求值与菜单模型由测试覆盖；既有 setReaderActions/setLeftSidebar 构建期通知日志仅记录，不扩修。标准 main.dart Linux debug 构建通过并恢复正常 bundle（/tmp/shortcuts-revision-standard-build.log）；临时 GUI 入口不入库。契约文件/pubspec.* 零改动，截图不入库，不提交，待验收。
