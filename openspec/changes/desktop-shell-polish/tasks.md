# Tasks

## 1. 侦察

- [ ] 1.1 侦察 `PopupWindowSetting` 全部使用点的覆盖层依赖（`PopupIndicatorWidget` 等），标记可就地化入口与暂缓入口

## 2. 就地编辑链路

- [ ] 2.1 `SettingsPage` 右栏 Navigator 支持子页入栈（就地展开回调）
- [ ] 2.2 `PopupWindowSetting` 增加断点分流：双栏就地、单栏弹窗（断点引自 design-system-foundation）
- [ ] 2.3 就地容器复用弹窗 scaffold 结构（标题/返回/保存状态条）

## 3. 逐入口启用

- [ ] 3.1 代理（`_ProxySettingView`）就地化
- [ ] 3.2 DNS Overrides 就地化
- [ ] 3.3 关键词屏蔽就地化
- [ ] 3.4 WebDAV 相关入口就地化（若 settings-ia-cleanup 已改远程存储页则对齐其入口）
- [ ] 3.5 有硬覆盖层依赖的入口登记 design-spec.md 例外清单

## 4. 验证

- [ ] 4.1 验证 spec 场景：宽屏就地/窄屏弹窗/校验反馈一致
- [ ] 4.2 `flutter analyze` 无新增告警
