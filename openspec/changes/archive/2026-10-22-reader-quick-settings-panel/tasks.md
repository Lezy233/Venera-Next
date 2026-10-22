# Tasks

## 1. 前置检查

- [x] 1.1 确认 settings-ia-cleanup 的作用域选择器已落地；未落地则按 design.md D3 降级路径执行并记录技术债

  - 备注：已确认 ReaderSettings 顶部 SegmentedButton<ReaderSettingsScope>（reader.dart:220），comicId/source 传入时默认 ReaderSettingsScope.comic（:55）；_scopeTile 已不存在。无需 D3 降级。

## 2. 精简面板实现

- [x] 2.1 新建 `quick_settings_panel.dart`：默认高频项集合（阅读模式/亮度/翻页方向/缩放/翻页动画/缩略图开关；不含背景色——背景跟随主题是设计契约），项列表为常量数组
  - 备注：新增独立 ReaderQuickSettingsPanel，六项以 readerQuickSettings 常量数组定义；方向复用 reverseTapToTurnPages，缩放复用 enableDoubleTapToZoom，亮度滑杆始终可见，无需滚动查找。
- [x] 2.2 面板项经 `ReaderPreferenceStore`（comic scope）读写，作用域标识可见
  - 备注：直接 ReaderPreferenceStore(comic) 读写，阅读模式使用全量页同一 readerModeOverride 字段；作用域显式标注 This comic。复用 SettingsSaveState 排队/失败重试/离开保护及覆盖层反馈，共享亮度预览，监听存储变化以刷新外部修改。
- [x] 2.3 面板底部"全部设置"入口 → 设置 → 阅读（作用域"此漫画"）
  - 备注：底部 All settings 等待已接受保存完成后打开全量 ReaderSettings，传同一 comicId/source、亮度预览及模式/检测回调；自动选中“此漫画”。新路由保留原 ImageWork 保存归属。
- [x] 2.4 `settings_panel.dart` 改接精简面板，移除全量复用

  - 备注：ReaderSettingsPanel 默认改接快捷面板，全量 ReaderSettings 仅在 All settings 导航时构建。Scaffold 接收缩略图偏好变更时清除临时工具栏/拖拽覆盖，确保当前缩略图立即同步；未改变工具栏/手势布局或操作。

## 3. 验证

- [x] 3.1 验证 spec 场景：3 秒完成亮度调整；面板与全量页双向同步；作用域标识正确
  - 备注：新增 6 项快捷面板测试，设置/亮度/保存相关共 45 项通过；完整 Reader 集成套件 141 项通过、23 项按既有条件跳过。覆盖即时亮度预览、阻塞保存正文坐标不变、六项存储键、漫画隔离、模式双向同步、失败重试及失效请求保护。GUI DISPLAY=:1 使用真实 Reader + 隔离临时本地漫画页：打开并调亮度 1.001 秒，无滚动；漫画 70%、全局仍 50%；切连续模式使实际阅读视图变化；All settings 默认此漫画并显示同值，从全量页改右到左模式返回后快捷面板同步。截图仅存 /tmp/desktop-shell-quick-*.png，测量 /tmp/reader-quick-gui-result.json，不入库。
- [x] 3.2 `flutter analyze` 无新增告警（基线：38 个 tool/code_audit 环境项 + 12 个 lib/test 项，共 50）
  - 备注：fvm flutter analyze --no-pub = 50（tool/code_audit 38 + lib/test 12），无新增；Linux debug 主应用构建通过，GUI 临时入口不提交，构建产物已恢复主入口。git diff --check 通过；契约文件、正式 spec、design-spec.md、BACKLOG.md、pubspec.lock 均未改。
- [x] 3.3 新增词条补 zh_CN/zh_TW（如面板标题、「全部设置」入口等用户可见文案）
  - 备注：新增 Quick settings / All settings 的 zh_CN、zh_TW 译文；其余六项、作用域标识复用现有 tl 词条。
