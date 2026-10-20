# Tasks

## 1. 前置检查

- [ ] 1.1 确认 settings-ia-cleanup 的作用域选择器已落地；未落地则按 design.md D3 降级路径执行并记录技术债

## 2. 精简面板实现

- [ ] 2.1 新建 `quick_settings_panel.dart`：默认高频项集合（阅读模式/亮度/翻页方向/缩放/背景色/缩略图开关），项列表为常量数组
- [ ] 2.2 面板项经 `ReaderPreferenceStore`（comic scope）读写，作用域标识可见
- [ ] 2.3 面板底部"全部设置"入口 → 设置 → 阅读（作用域"此漫画"）
- [ ] 2.4 `settings_panel.dart` 改接精简面板，移除全量复用

## 3. 验证

- [ ] 3.1 验证 spec 场景：3 秒完成亮度调整；面板与全量页双向同步；作用域标识正确
- [ ] 3.2 `flutter analyze` 无新增告警
- [ ] 3.3 新增词条补 zh_CN/zh_TW
