# Tasks

> 硬规则（全程有效）：契约文件（design-spec.md、openspec/specs/**、pubspec.yaml/lock）禁改——本 change 的 spec delta 除外；pubspec.lock 不得重新生成；不得新增依赖；`flutter analyze` 基线 = 50 项（tool/code_audit 38 + lib/test 12），交付不得新增；界面截图不入库（留 /tmp）；新文案 .tl + zh_CN/zh_TW 同步；契约/任务歧义停工上报；工作区保持干净，提交前问 Kimi。

## 1. 方案管理器

- [ ] 1.1 新建 `lib/foundation/reader_presets.dart`：`ReaderPresetStore`（list/createFromCurrent/rename/updateFromCurrent/delete/apply），存储 `readerModePresets`（design D1），经 `appdata.updateSettings` 原子写
- [ ] 1.2 名称校验：trim 非空、≤30 字符、大小写不敏感重名拒绝（.tl 提示）；删除不回写已应用设置
- [ ] 1.3 快照/应用按键映射（design D2/D3）：19 键集合；模式键快照记录 resolve 后生效模式 + `autoReaderMode=false`；apply 逐键走 `ReaderPreferenceStore`（comic 层模式键经 `writeComicModeOverride`，与既有模式切换通道一致）

## 2. 设置页入口

- [ ] 2.1 `lib/features/settings/reader.dart`「阅读模式」组后新增「阅读模式方案」组：当前方案下拉（应用到选择器当前层）+「管理方案…」入口（push 管理页，先例 About→Debug `context.to`）
- [ ] 2.2 方案管理页：列表（名称+应用+重命名/更新为当前值/删除，删除与更新带确认）、顶部「新建方案」（名称输入→快照）；空态提示（无方案时引导新建）

## 3. 快捷设置面板

- [ ] 3.1 `ReaderQuickSetting` 枚举与清单新增 `preset` 项（置于 mode 后）：下拉「方案：无/各方案」，选择即 `apply(id, comic)`；面板作用域标识与其余项不变；与设置页共用同一 store
- [ ] 3.2 translation.json 新词条（方案组标题、管理页文案、重名/空名提示、确认文案、面板方案标签），zh_CN/zh_TW 同步

## 4. 验证

- [ ] 4.1 单元/组件测试：管理器 CRUD、名称校验、快照键集合（恰好 19 键、模式键快照语义）、apply 按 scope 分派（global/device/comic，comic 模式键走 override）、删除不回写
- [ ] 4.2 集成测试：设置页入口（下拉应用+管理页 CRUD）、面板方案项（应用到漫画层后全量页同步，无第二数据源）
- [ ] 4.3 `fvm flutter analyze --no-pub` 无新增（基线 50）；相关回归全绿（阅读器/设置/壳层套件，日志 /tmp）
- [ ] 4.4 GUI 走查（DISPLAY=:1 隔离数据）：设置页建方案（改几项设置→快照→切到另一套→应用恢复）；面板切方案立即生效且亮度等方案外项不变；重启保留；截图只留 /tmp
