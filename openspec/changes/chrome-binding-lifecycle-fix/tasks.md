# Tasks

## 1. 诊断与复现

- [x] 1.1 记录修复前启动日志中的 setState-during-build 错误全文与触发链（main_page.dart:74 → desktop_chrome.dart:109），确认无其他同型错误路径混入本 change 范围
  - 干净 HEAD 上使用实际应用启动复现；默认日志器会在 3000 字符截断，故 /tmp/chrome_binding_startup.dart 仅设置 Log.ignoreLimitation=true 再调用生产 main，完整框架错误及堆栈保存于 evidence/startup-before.txt。目标链：MainPage.didChangeDependencies:74 → _bindChrome:79 → bindGlobalActions:113 → notifyListeners → DesktopChromeScope.markNeedsBuild。真实 MainPage widget 回归测试修复前也因同一错误失败。
  - 其他路径仅记录：既有 reader/chapter_search 测试已注明阅读器注册也可能在构建期通知；收藏页 setLeftSidebar 亦在 didChangeDependencies 同步调用。这些均不在本次改动范围；实际启动另有环境/布局日志，不以本 change 清除。

## 2. 修复

- [x] 2.1 `_bindChrome` 调用移入帧后回调（addPostFrameCallback + mounted/已绑定守卫），全局动作注册语义不变 —— design D1
  - didChangeDependencies/build 共用 _scheduleChromeBinding；排队标志合并同帧请求，帧后 mounted 守卫与 _boundChrome 身份守卫确保当前控制器只绑定一次；上下文同步继续独立帧后执行。desktop_chrome.dart 通知机制未改。
- [x] 2.2 回调引用稳定化（State 字段持有，build 内不新建闭包）—— design D2
  - 四个全局动作以 late final State 字段持有；保留原设置/搜索去重导航、tab 更新、返回语义。build 不再产生绑定动作闭包。

## 3. 验证

- [x] 3.1 新增回归测试：模拟 didChangeDependencies 重建路径，断言构建期无 markNeedsBuild 错误且绑定不重复
  - 新测试运行实际 MainPage，记录 bindGlobalActions 的 SchedulerPhase、调用次数及四个回调身份；父 Builder 模拟同帧重复依赖失效，重建后仍仅绑定一次；控制器替换后只在帧后绑定且四个回调 identical，tab 导航、卸载清理保持正常。修复前目标错误红，修复后 2 项绿；相关六文件（生命周期、desktop_chrome、desktop_top_bar、导航上下文、断点、章节搜索）共 18 项通过，日志 /tmp/chrome-binding-tests.log。
- [x] 3.2 `flutter analyze` 无新增告警（基线：38 个 tool/code_audit 环境项 + 12 个 lib/test 项，共 50）
  - fvm flutter analyze --no-pub：50 项（tool/code_audit 38 + lib/test 12），改动源文件和测试无新增诊断。日志 /tmp/chrome-binding-analyze.log。
- [x] 3.3 GUI 走查：启动日志干净（无该错误）；阅读器内全局快捷键/命令中心动作工作正常（截图仅存本地，不入库）
  - 实际生产 main 启动前后对比：目标 setState/markNeedsBuild-during-build 从 1 次降为 0 次，bindGlobalActions 堆栈从 1 次降为 0 次，见 evidence/startup-comparison.txt；未清理原有环境/网络/布局日志。
  - DISPLAY=:1 隔离数据，真实 WindowFrame + MainPage + ReaderScaffold：帧后全局设置动作打开设置页；阅读器 Ctrl+F 打开章节列表，输入 sun 仅保留 Sunrise，Enter 选择第 2 章并关闭侧栏；点击命令中心再次过滤/Enter，仍选择第 2 章。GUI 日志 /tmp/chrome-binding-gui.log、/tmp/chrome-binding-gui-global.log 均无构建期错误。
  - 本地截图 /tmp/chrome-binding-global-settings.png、/tmp/chrome-binding-search.png、/tmp/chrome-binding-type.png、/tmp/chrome-binding-enter.png、/tmp/chrome-binding-click.png，均未入库。GUI 临时入口 /tmp/chrome_binding_gui.dart；未改生产入口/实际用户设置。
