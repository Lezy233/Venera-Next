# Tasks

## 1. 侦察

- [x] 1.1 侦察 `PopupWindowSetting` 全部使用点的覆盖层依赖（`PopupIndicatorWidget` 等），标记可就地化入口与暂缓入口

  - 备注：全库检索共 8 处调用：代理、DNS、漫画/评论关键词、四类页面筛选。均自带 PopUpWidgetScaffold；代理及 SettingsSaveState 对 PopupIndicatorWidget 使用可空读取并回退 ModalRoute，无硬覆盖层依赖。远程存储用途入口为直接 showPopUpWidget，另见 3.4。

## 2. 就地编辑链路

- [x] 2.1 `SettingsPage` 右栏 Navigator 支持子页入栈（就地展开回调）
  - 备注：右栏提供 SettingsPage.openEditor / Inherited 回调，推入调用者所在的内嵌 Navigator；分类 ValueKey 保留，切类销毁子栈。
- [x] 2.2 `PopupWindowSetting` 增加断点分流：双栏就地、单栏弹窗（断点引自 design-system-foundation）
  - 备注：分流复用 Breakpoints.isCompact；没有双栏上下文时仍回退原 root 弹窗，builder 保持复用。
- [x] 2.3 就地容器复用弹窗 scaffold 结构（标题/返回），保存反馈用 `withSettingsSaveFeedback` 覆盖层呈现（不占用右栏正文布局）
  - 备注：复用各 builder 自带的 PopUpWidgetScaffold（避免双标题），onBack/leaveSettings 回到右栏前一路由；页面筛选先迁到 withSettingsSaveFeedback，后续入口沿用相同包装，不改表单字段或业务逻辑。

## 3. 逐入口启用

- [x] 3.1 代理（`_ProxySettingView`）就地化
  - 备注：代理复用原 builder 和校验、保存成功后 leaveSettings；保存状态移出标题 trailing，改覆盖层。
- [x] 3.2 DNS Overrides 就地化
  - 备注：DNS 复用原 builder，保存反馈改覆盖层；开关、编辑和 resetDio 行为保留。
- [x] 3.3 关键词屏蔽就地化
  - 备注：漫画/评论关键词入口共享分流及原表单，删除保存反馈改覆盖层；添加关键词仍保留原校验对话框。
- [x] 3.4 WebDAV 相关入口就地化：注意 settings-ia-cleanup 已落地「远程存储」独立页（`remote_storage.dart`）；侦察其用途子弹窗（数据同步/存档备份/漫画库配置）是否走 `PopupWindowSetting`，是则就地化并对齐新页入口
  - 备注：remote_storage.dart 的三个用途入口直接 showPopUpWidget，均不走 PopupWindowSetting；按本任务“是则就地化”条件不改其导航，远程存储独立页入口保持原状。
- [x] 3.5 有硬覆盖层依赖的入口登记 design-spec.md 例外清单
  - 备注：1.1 确认 8 个入口无硬覆盖层依赖、无暂缓入口，故无需登记例外，也未修改禁止改动的 design-spec.md。

## 4. 验证

- [x] 4.1 验证 spec 场景：宽屏就地/窄屏弹窗/校验反馈一致
  - 备注：新增 23 项真实设置页回归，相关测试合计 59 项通过；覆盖 8 入口在 720/1280px 就地打开及返回、600/719px 弹窗、非法端口、切分类清栈、阻塞保存 Future 时坐标不变、失败 Retry、返回等待保存。GUI DISPLAY=:1 实跑确认 1280px 右栏就地、600px 居中弹窗，二者均显示同一“端口必须为数字”校验；返回均回原列表。截证：evidence/wide-inplace.png、evidence/compact-popup.png。未更改实际代理配置（非法表单未持久化）。
- [x] 4.2 `flutter analyze` 无新增告警（基线：38 个 tool/code_audit 环境项 + 12 个 lib/test 项，共 50）
  - 备注：fvm flutter analyze --no-pub 仍为 50 项（tool/code_audit 38 + lib/test 12），涉及变更文件无诊断；Linux debug --no-pub 构建通过。
