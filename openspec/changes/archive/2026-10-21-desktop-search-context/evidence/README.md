# GUI 验证记录

环境：Flutter 3.47.7、Linux debug、DISPLAY=:1，expanded 窗口，命令中心可见。

阅读器截图使用临时 GUI 入口挂载生产 `DesktopSearchBox`、`ReaderScaffold`、`ReaderSidebarBinding` 和 `ReaderChaptersView`，通过真实键鼠输入操作；章节数据为固定合成样本，未访问网络漫画。临时入口不纳入实现或提交，运行结束已退出，并还原主应用 debug kernel。

样本：Volume 1 = #1 Prologue / #2 The SUN；Volume 2 = #3 Sunrise / #4 Finale。初始位于 #4。

| 截图 | 操作与结果 |
|---|---|
| [reader-click-filter.png](reader-click-filter.png) | 点击命令中心输入 `sun`，列表仅保留匹配，首个分组显示 The SUN，无 Prologue/Finale；键盘焦点仍在搜索框。 |
| [reader-enter.png](reader-enter.png) | 回车选择原全局索引 #2，面板关闭，正文测试标签显示 Current chapter: 2 - The SUN；运行日志记录 `GUI chapter select 2`。 |
| [reader-ctrl-f.png](reader-ctrl-f.png) | 从阅读内容按 Ctrl+F，输入 `sun`，与点击路径得到相同过滤列表。 |
| [reader-no-match.png](reader-no-match.png) | Ctrl+F 后输入 `missing`，显示 No chapters match “missing”；回车不跳转、不关闭面板，选择日志无新增。 |
| [favorites-filtered.png](favorites-filtered.png) | 主应用真实收藏页输入不匹配词，原文件夹列表清空。 |
| [favorites-cleared.png](favorites-cleared.png) | 主应用按 Ctrl+F + Backspace 清空输入，原文件夹全部 5 项恢复，提示语仍为“搜索收藏”。 |

主应用构建：`fvm flutter build linux --debug --no-pub` 通过。

自动化：相关章节、侧栏、壳层和命令中心测试共 66 项通过，其中新增 `chapter_search_test.dart` 的 4 项测试覆盖过滤模型/空态/清空恢复及真实 ReaderScaffold 的点击、Ctrl+F 链路。测试挂载时仅识别既有 chrome 构建期注册通知错误；搜索交互阶段仍断言无异常，生产 B1 逻辑未改。

`fvm flutter analyze --no-pub` = 50 项，tool/code_audit 38 + lib/test 12，变更文件无新增诊断。
