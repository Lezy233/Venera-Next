# Tasks

## 1. 侦察

- [x] 1.1 侦察 `chapters.dart` 结构与现有过滤能力，确定改造范围（design.md D2 风险项）

  - 备注：ReaderChapterMenuData 已提供全局章节索引及分组快照，ReaderChaptersView 无过滤能力；基于快照过滤标题、保留索引，不改章节源或居中 sliver 滚动算法，不做高亮。ReaderScaffold 经 SidebarBinding 打开章节，需保持输入焦点且复用已打开面板。

## 2. 章节过滤链路

- [x] 2.1 `DesktopReaderActions` 增加章节过滤回调；阅读器挂载时注册
  - 备注：DesktopReaderActions 注册 filterChapters 与提交回调，ReaderScaffold 持有查询通知器及原章节请求，复用已打开面板；跳转保留原请求的会话/索引有效性校验。
- [x] 2.2 章节列表支持按标题大小写不敏感过滤 + 空态提示
  - 备注：标题 trim + toLowerCase + contains，跨分组保留原全局索引，过滤时只呈现含匹配项的组；空态带当前过滤词，清空恢复原分组与当前章定位。
- [x] 2.3 `focusSearch`/`submitSearch` 分流对齐：输入即过滤，回车跳转首个匹配章节
  - 备注：输入/提交优先 reader，其次当前 favorites，最后全局搜索；回车选择源顺序首匹配，无匹配不跳转。点击调用 focusSearch，章节路由在命令中心存在时不抢键盘焦点；B1 绑定与通知方法未改。

## 3. 一致性核对

- [x] 3.1 核对 Ctrl/Cmd+F 与点击命令中心行为一致
  - 备注：真实 ReaderScaffold + DesktopSearchBox 的点击/Ctrl+F 两条路径测试均通过：保持搜索焦点、实时过滤、无匹配反馈、回车选源顺序首匹配及关闭面板，未重复获取 sidebar pause。
- [x] 3.2 核对收藏页空输入恢复完整列表
  - 备注：LocalFavoritesPage.updateSearchResult 对空白 query 直接恢复 comics；真实 app GUI 输入不匹配词后列表为空，经 Ctrl+F + Backspace 清空恢复原文件夹 5 项，命令中心提示仍为“搜索收藏”。补充 TextField 清空字符串下发及提示语断言。
- [x] 3.3 新增词条补 zh_CN/zh_TW（空态提示等）
  - 备注：新增 No chapters match “@query” 的 zh_CN/zh_TW 译文，空态使用 tlParams；收藏空输入沿用现有 Search favorites 提示语。

## 4. 验证

- [x] 4.1 验证 spec 三个场景（行为一致/快捷键对齐/空态反馈）
  - 备注：66 项相关测试通过；GUI expanded 下点击输入/Ctrl+F 同样实时过滤，sun 回车由 #4 跳首匹配 #2，missing 空态含词且回车不跳转，收藏清空恢复完整内容。阅读器截证使用真实生产组件和合成章节，收藏截证为主应用实跑；见 evidence/README.md 及六张截图。Linux debug 主应用构建通过，未改全局搜索页、ReaderWindow 或 B1。
- [x] 4.2 `flutter analyze` 无新增告警（基线：38 个 tool/code_audit 环境项 + 12 个 lib/test 项，共 50）
  - 备注：fvm flutter analyze --no-pub = 50（tool/code_audit 38 + lib/test 12），涉及变更文件无新增诊断。相关章节、侧栏、壳层及命令中心测试共 66 项通过。
