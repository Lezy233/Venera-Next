# Tasks

> 硬规则（全程有效）：契约文件（design-spec.md、openspec/specs/**、pubspec.yaml/lock）禁改——本 change 的 spec delta 除外；pubspec.lock 不得重新生成；不得新增依赖；`flutter analyze` 基线 = 50 项（tool/code_audit 38 + lib/test 12），交付不得新增；界面截图不入库（留 /tmp）；新文案 .tl + zh_CN/zh_TW 同步；契约/任务歧义停工上报；工作区保持干净，提交前问 Kimi。

## 1. 方案管理器

- [x] 1.1 新建 `lib/foundation/reader_presets.dart`：`ReaderPresetStore`（list/createFromCurrent/rename/updateFromCurrent/delete/apply），存储 `readerModePresets`（design D1），经 `appdata.updateSettings` 原子写
  - 新增 ReaderPresetStore 与只读模型；CRUD/apply 均通过 appdata.updateSettings 串行原子写，顺序为创建顺序；复用已有 uuid 依赖。
- [x] 1.2 名称校验：trim 非空、≤30 字符、大小写不敏感重名拒绝（.tl 提示）；删除不回写已应用设置
  - 名称 trim、Unicode 字符数≤30、大小写不敏感同库唯一；返回独立错误词条供 UI 翻译；删除只写方案列表。
- [x] 1.3 快照/应用按键映射（design D2/D3）：19 键集合；模式键快照记录 resolve 后生效模式 + `autoReaderMode=false`；apply 逐键走 `ReaderPreferenceStore`（comic 层模式键经 `writeComicModeOverride`，与既有模式切换通道一致）
  - 固定 typed 偏好清单 19 键；漫画模式使用现有 resolve，快照关闭 auto；应用逐键写入，漫画 readerMode 使用 writeComicModeOverride，缺失键不补写。

## 2. 设置页入口

- [x] 2.1 `lib/features/settings/reader.dart`「阅读模式」组后新增「阅读模式方案」组：当前方案下拉（应用到选择器当前层）+「管理方案…」入口（push 管理页，先例 About→Debug `context.to`）
  - 阅读模式组后接入共用 ReaderPresetSelector，目标取当前作用域；选择仅作上次应用提醒，切换作用域不清空；管理页走 context.to 并传递保存作用域。未发现就地编辑框架强约束。
- [x] 2.2 方案管理页：列表（名称+应用+重命名/更新为当前值/删除，删除与更新带确认）、顶部「新建方案」（名称输入→快照）；空态提示（无方案时引导新建）
  - 新增 reader_presets.dart：管理页提供空态/新建/应用/重命名/更新/删除；更新与删除先确认，名称错误显示在输入框，异步写期间禁用操作。

## 3. 快捷设置面板

- [x] 3.1 `ReaderQuickSetting` 枚举与清单新增 `preset` 项（置于 mode 后）：下拉「方案：无/各方案」，选择即 `apply(id, comic)`；面板作用域标识与其余项不变；与设置页共用同一 store
  - 枚举与常量清单在 mode 后新增 preset；复用同一 selector/store，固定 comic 写入，应用结果逐键交给原 onChanged → ReaderSettingsRequest.apply 效果链，其余项不变。
- [x] 3.2 translation.json 新词条（方案组标题、管理页文案、重名/空名提示、确认文案、面板方案标签），zh_CN/zh_TW 同步
  - 新增方案组/管理/空态/名称校验/确认文案，全部 .tl；translation.json 同步补 zh_CN、zh_TW，既有词条复用。

## 4. 验证

- [x] 4.1 单元/组件测试：管理器 CRUD、名称校验、快照键集合（恰好 19 键、模式键快照语义）、apply 按 scope 分派（global/device/comic，comic 模式键走 override）、删除不回写
  - reader_presets_test.dart 9 项通过：CRUD/JSON 重读、名称与并发重名、恰好 19 键、auto 与漫画 override 求值、global/device/comic 应用及层自动启用、缺失键/方案外键不写、删除不回写。连同面板既有 6 项合计 15 绿；/tmp/reader-presets-core.log。
- [x] 4.2 集成测试：设置页入口（下拉应用+管理页 CRUD）、面板方案项（应用到漫画层后全量页同步，无第二数据源）
  - reader_presets_test.dart 组件测试 5/5 绿（/tmp/reader-presets-ui.log）：默认/设备/漫画三层应用及跨层保持提示、管理页全 CRUD/确认取消/空名错误、面板应用后全量页同源读取。日志 ReaderPresetNameError 为该用例主动提交空名的预期校验异常，已由对话框捕获并断言提示，不是 Appdata 初始化失败；末尾 All tests passed。
- [x] 4.3 `fvm flutter analyze --no-pub` 无新增（基线 50）；相关回归全绿（阅读器/设置/壳层套件，日志 /tmp）
  - 最终 analyze 50=38 tool/code_audit+12 lib/test，无新增（/tmp/reader-presets-analyze-final.log）；完整阅读器/设置/壳层及方案管理器回归 1109 通过、34 平台跳过，73 秒（/tmp/reader-presets-regression-bounded.log，150 秒上限）。一次有界 harness 调整仅更新双下拉定位及新增方案组后懒加载控件的滚动定位，未改产品语义；此前中途失败日志保留 /tmp/reader-presets-regression{,-final}.log。GUI 后标准 main.dart Linux debug 构建通过并恢复正常 bundle（/tmp/reader-presets-standard-build.log），最终 analyze 再次为 50。
- [x] 4.4 GUI 走查（DISPLAY=:1 隔离数据）：设置页建方案（改几项设置→快照→切到另一套→应用恢复）；面板切方案立即生效且亮度等方案外项不变；重启保留；截图只留 /tmp
  - DISPLAY=:1，真实 app.main，隔离 XDG_DATA_HOME=/tmp/reader-presets-gui-data，/tmp 临时宿主仅准备本地漫画、分发 UI 输入与记录状态。设置页经管理页新建 Manga dual（19 键），改模式与每屏页数后下拉应用恢复；实际阅读器面板 continuousTopToBottom→方案→galleryRightToLeft，亮度 75 与作用域 This comic 保持；完全重启后同一 ID/名称/19 键仍在管理页可见，再次应用使模式与 portrait/landscape=1 恢复为画廊/2。日志 /tmp/reader-presets-gui-final.log、/tmp/reader-presets-gui-restart.log；截图 /tmp/reader-presets-{created-final,panel-before,panel-applied,restart-library,two-fields-changed,restart-applied}.png，仅本地不入库。早期临时脚本误填桌面搜索框、误 pop 根路由的输入定位失误已纠正，产品未为此改动；既有 setReaderActions 等构建期通知只记录不扩修。
