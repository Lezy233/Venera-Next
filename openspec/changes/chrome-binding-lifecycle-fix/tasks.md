# Tasks

## 1. 诊断与复现

- [ ] 1.1 记录修复前启动日志中的 setState-during-build 错误全文与触发链（main_page.dart:74 → desktop_chrome.dart:109），确认无其他同型错误路径混入本 change 范围

## 2. 修复

- [ ] 2.1 `_bindChrome` 调用移入帧后回调（addPostFrameCallback + mounted/已绑定守卫），全局动作注册语义不变 —— design D1
- [ ] 2.2 回调引用稳定化（State 字段持有，build 内不新建闭包）—— design D2

## 3. 验证

- [ ] 3.1 新增回归测试：模拟 didChangeDependencies 重建路径，断言构建期无 markNeedsBuild 错误且绑定不重复
- [ ] 3.2 `flutter analyze` 无新增告警（基线：38 个 tool/code_audit 环境项 + 12 个 lib/test 项，共 50）
- [ ] 3.3 GUI 走查：启动日志干净（无该错误）；阅读器内全局快捷键/命令中心动作工作正常（截图仅存本地，不入库）
