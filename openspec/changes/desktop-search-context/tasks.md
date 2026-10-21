# Tasks

## 1. 侦察

- [ ] 1.1 侦察 `chapters.dart` 结构与现有过滤能力，确定改造范围（design.md D2 风险项）

## 2. 章节过滤链路

- [ ] 2.1 `DesktopReaderActions` 增加章节过滤回调；阅读器挂载时注册
- [ ] 2.2 章节列表支持按标题大小写不敏感过滤 + 空态提示
- [ ] 2.3 `focusSearch`/`submitSearch` 分流对齐：输入即过滤，回车跳转首个匹配章节

## 3. 一致性核对

- [ ] 3.1 核对 Ctrl/Cmd+F 与点击命令中心行为一致
- [ ] 3.2 核对收藏页空输入恢复完整列表
- [ ] 3.3 新增词条补 zh_CN/zh_TW（空态提示等）

## 4. 验证

- [ ] 4.1 验证 spec 三个场景（行为一致/快捷键对齐/空态反馈）
- [ ] 4.2 `flutter analyze` 无新增告警（基线：38 个 tool/code_audit 环境项 + 12 个 lib/test 项，共 50）
