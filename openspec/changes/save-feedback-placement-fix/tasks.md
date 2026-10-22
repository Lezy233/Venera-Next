# Tasks

## 1. 诊断

- [x] 1.1 测定遮挡带几何：GUI/VM 确认 `_SettingsSaveFeedback` 的 `Align(topCenter)` 与桌面壳顶栏的遮挡关系（顶栏高度、Stack 顶部起点、绘制顺序），记录数据
  - 诊断：DISPLAY=:1 下运行真实 WindowFrame + SettingsPage（临时数据目录、临时 GUI 入口，不改壳层）。Linux 外框内边距 4px，顶栏全局 y=4–40（36px），右栏反馈 Stack 起点 (285,4)，MediaQuery.padding.top=36；切换作用域后成功气泡 paint rect=(747.9,4)–(813.1,48)，与顶栏重叠 36px，仅露 8px。WindowFrame 先绘制正文、后绘制 OverlayHost 顶栏；正文只收到 MediaQuery inset，反馈 Align 未消费 inset。回归原码 14 例中 4 例失败（375/1280 宽 × 24/36px 未消费顶部 inset），已消费 inset 与零 inset 均通过。截图 /tmp/save-placement-before-scope.png。

## 2. 定位修复

- [x] 2.1 按 design.md D1 实施最小定位修复：保存反馈进入安全可视区，桌面/移动、单栏/双栏均完整可见；不硬编码魔数（经现有壳层/断点规范取数或组件自包含方案）
  - 仅在 Positioned.fill 内以 SafeArea(bottom: false) 包裹反馈 Align，使用宿主 MediaQuery 安全区；不改正文约束、位置、三态样式、保存语义或壳层。父层已消费 inset 时不会重复偏移，零 inset 保持原位置。

## 3. 验证

- [x] 3.1 新增回归测试（design.md D2）：带模拟遮挡带的宿主中断言反馈绘制区域不与遮挡带相交
  - 新增 12 例（375/1280 宽 × 0/24/36px inset × 未消费/已消费 inset）；比较 RenderBox.paintBounds 经 getTransformTo(null) 转换的全局矩形，逐态覆盖阻塞保存、失败、点击重试、成功；断言不与顶栏相交、不越出右栏/窗口、正文坐标尺寸不变。原码 4 红，修复后组件测试 14/14 绿。
- [x] 3.2 `flutter analyze` 无新增告警（基线：38 个 tool/code_audit 环境项 + 12 个 lib/test 项，共 50）
  - fvm flutter analyze --no-pub：50 issues（tool/code_audit 38 + lib/test 12），与派活基线一致；本次修改源文件/测试无诊断。日志 /tmp/save-placement-analyze.log。
- [x] 3.3 既有 save-feedback 相关测试全绿
  - fvm flutter test --no-pub：settings_save_feedback、settings_save_host、favorites_view_persistence、reader_settings_persistence、settings_inplace_editing、quick_settings_panel 六个文件共 77 项全部通过（含新增 12 项）。日志 /tmp/save-placement-tests.log。
- [x] 3.4 GUI 走查：设置 → 阅读切换作用域、快捷设置 → 全部设置切换作用域、收藏页保存——三处「已保存/保存中」反馈完整可见（截图仅存本地，不入库）
  - DISPLAY=:1、1280×900，隔离临时数据目录，真实 WindowFrame/SettingsPage/ReaderSettingsPanel/FavoritesPage：设置→阅读→此设备，Saved 矩形 (747.9,40)–(813.1,84)；快捷面板经生产 All settings 回调打开全量设置→此设备，Saved (607.4,40)–(672.6,84)；收藏切换 QA A，Saved (607.4,40)–(672.6,84)。三处均完整可见，顶栏遮挡交集从 36px 变为 0px；另阻塞保存 3s 确认保存中矩形 (759.5,40)–(801.5,82) 完整可见。
  - 截图仅在 /tmp/save-placement-after-settings-scope.png、/tmp/save-placement-after-settings-pending.png、/tmp/save-placement-after-quick-all-scope.png、/tmp/save-placement-after-favorites.png；几何日志 /tmp/save-placement-before.log、/tmp/save-placement-after.log、/tmp/save-placement-after-settings.log。GUI 临时入口位于 /tmp，未改生产入口、未写真实用户数据、截图未入库。
