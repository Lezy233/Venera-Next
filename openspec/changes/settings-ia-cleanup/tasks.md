# Tasks

## 1. WebDAV 共享连接存储与迁移

- [ ] 1.1 在 `appdata.settings` 中新增共享连接 key（结构 `{url, user, pass}`），定义读写入口并在 `foundation/` 中加序列化/解析
- [ ] 1.2 实现启动迁移：共享 key 为空时从数据同步旧配置复制；三份旧配置不一致时以数据同步为准并置"待确认"标记（不删除旧 key）
- [ ] 1.3 为三个用途（数据同步/存档备份/漫画库）改读共享连接；各用途排他性设置保持独立 key
- [ ] 1.4 编写迁移逻辑的单元测试（一致/不一致/全新用户三种情况）

## 2. 远程存储 UI 收敛

- [ ] 2.1 新建"远程存储"设置页：顶部连接表单（复用 `WebDavConnectionFields`）+ 测试连接按钮
- [ ] 2.2 页内三个用途分组：启用开关、跳转现有配置弹窗、一句话用途说明、连接状态副标题（已配置/未配置）
- [ ] 2.3 未配置连接时点击用途入口 → 引导先完成连接配置
- [ ] 2.4 `app.dart` 的 App → Data 下用单一"远程存储"入口替换三个平级入口（旧弹窗组件保留一个版本周期）
- [ ] 2.5 新增翻译词条并补 zh_CN/zh_TW

## 3. 阅读设置作用域选择器

- [ ] 3.1 `ReaderSettings` 顶部改为作用域 `SegmentedButton`（默认/此设备/此漫画），页面内容随所选作用域整体重建
- [ ] 3.2 删除条目级 `useDeviceSettings`/`comicId` 混排传参，scope 作为页面级单值传入保存逻辑
- [ ] 3.3 作用域切换接入 `protectSettings` 语义（保存中禁用切换），保留各作用域一键重置
- [ ] 3.4 阅读器内面板默认选中"此漫画"，删除 `_scopeTile`；跨层级提示文案改为具体动作（"修改默认设置请前往 设置 → 阅读"）
- [ ] 3.5 验证：修改单部漫画设置后保存状态条可见，且不影响默认设置

## 4. 设置分类调整

- [ ] 4.1 `Initial Page` 与 `Reverse default chapter order` 从 `explore_settings.dart` 迁入 `app.dart`（APP 分类）
- [ ] 4.2 `settings_page.dart` 分类数组移除 Reading statistics 与 Debug；主导航降至 7 项
- [ ] 4.3 `about.dart` 增加"高级"组：Debug、Logs 入口
- [ ] 4.4 在历史/统计相关页面为 Reading statistics 提供替代入口
- [ ] 4.5 检查所有 `SettingsPage(initialPage: n)` 引用点，修正因分类删减导致的索引错位

## 5. 验证与收尾

- [ ] 5.1 `flutter analyze` 无新增告警
- [ ] 5.2 手动走查：三用途共享连接配置、单部漫画设置隔离、设置分类盲测（对照 spec 验收标准）
- [ ] 5.3 更新 `doc/ui-audit-2026-10-20.md` 中对应条目的状态
