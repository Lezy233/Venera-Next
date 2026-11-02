# Design

## D1 证据与边界

正式约束为 openspec/specs/reader/mode-presets/spec.md 和 settings/reader-scope-model/spec.md。旧归档reader-mode-presets设计D4曾定义下拉仅为局部上次提示，本change以owner B3决定替代该提示语义；保留正式契约的19键、缺失键不改值、作用域正交及删除不回写。

入口：lib/features/settings/reader_presets.dart 的 ReaderPresetSelector局部_appliedId/build/_apply，以及管理页apply；lib/foundation/reader_presets.dart 的_snapshot/apply；settings/reader.dart与reader/quick_settings_panel.dart分别传当前作用域与漫画作用域。先跑真实页面销毁/重建失败用例，不把局部变量缺少恢复等同于参数未保存。需要的实现诊断由executor完成，architect仅规划与复核。

## D2 持久引用与身份

新增向后兼容的settings元数据readerPresetSelections（或等价封装），记录最后成功应用的presetId。身份明确区分global、device+已有deviceId、comic+(sourceKey,comicId)，漫画元组须无分隔符歧义；两个来源相同comicId不得串用。缺省/坏记录/失效ID均为无，不更改既有参数，也不推断旧数据已选择某方案。同值不同ID方案保持用户明确选择的身份。

方案参数和目标引用通过同一appdata.updateSettings事务写入最新草稿。读取/清除引用不得启用设备或漫画层；选择「无」只清当前层引用，不清参数，不影响其他层。active调用先按现有规则归一到具体作用域，UI继续传明确层。异步操作捕获原作用域、deviceId/漫画身份及数据目录归属，页面/身份切换不能回写到新归属或显示旧操作成功。缺失方案不得造成成功应用提示。

## D3 匹配与生命周期

引用不是设置的第二数据源。只在目标ID存在、具有至少一个有效白名单键且其声明键均匹配时显示该名称。逐键用当前作用域ReaderPreferenceStore的规范化生效值比较；部分方案只比较声明键，数值表示int/double按既有normalize语义处理。readerMode比较该层现有求值结果（global不掺device/comic；device沿用启用/继承；comic沿用readerModeOverride与布局resolve）。autoReaderMode读取实际作用域值，不直接用_snapshot进行匹配，因为_snapshot强制auto=false会掩盖手改。保留既有模式应用与求值通道，不借此重构auto/override机制。

手改组合键后立即重算，失配显示无；手改方案外亮度等不改变匹配。匹配恢复时可重新显示原引用；不自动改参数。切换层/漫画、重进、重启均从同一存储读取。管理页应用同样保存引用；重命名按ID显示新名称；删除使引用无效但不回写参数；方案更新后按新值重新校验。重置目标层应清其选择引用，不能因重置值偶然相同继续声称已选择；其他层引用保留。

## D4 保存可信度

复用SettingsSaveState/既有效果分发；仅持久化成功且归属仍有效时显示已保存/派发当前页效果。appdata可能在IO失败前发布draft，执行者须复现并处理本操作的参数和引用状态，失败后不留下新方案的假成功显示，不覆盖并发无关设置；支持重试。不得仅隐藏toast而让错误引用作为成功状态重进恢复。

## D5 框架容纳检查

沿用design-spec.md §2/§3/§4/§6/§7.2/§7.4的token、既有设置控件、断点与主题。仅修状态语义，不增壳层/断点/配色例外，阅读器chrome跟随主题。新文案.tl+zh_CN/zh_TW。

## 验证

真实选择器复现→修复；三层应用与重建、JSON重载/进程重启、相同ID不同source/设备隔离、同值方案身份、19键失配/方案外项、部分/空/坏/删除/改名/更新、重置、None不写参数、保存IO失败与重试、切换归属。复跑原方案和阅读设置/快捷面板回归，GUI隔离数据DISPLAY=:1截图仅/tmp，恢复生产main构建并停止自己的fixture。
