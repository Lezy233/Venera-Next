# Tasks

## 1. 覆盖层渲染模式

- [x] 1.1 `SettingsSaveState` 增加覆盖层渲染模式：页面根 `Stack` + `Align(topCenter)` 浮动状态条，状态条参与绘制不参与布局约束 —— 依据 design.md D1
  - 备注：新增 withSettingsSaveFeedback；正文为 Stack 唯一非定位子项，浮动条由 Positioned.fill + Align(topCenter) 绘制，适用无界 Sliver 内容。
- [x] 1.2 全库 grep `SettingsSaveState` 使用点，确认仅收藏页/阅读模式/阅读设置外层三处，列出清单核对 —— 依据 design.md D2
  - 备注：rg -n "SettingsSaveState|settingsSaveStatus" lib test 确认存在第四处以上，旧插入式调用共 34 处、19 个 lib 文件；本次目标为 favorites_page、reader_mode（全局/单书两个分支）、reader 外层。其他调用文件：features/comic_details/chapters.dart, features/comic_source/comic_source_page.dart, features/comic_source/source_import_dialog.dart, features/comic_source/source_repository_page.dart, features/comic_widgets/comic_tile.dart, features/favorites/comic_reorder_page.dart, features/favorites/local_favorites_page.dart, features/follow_updates/follow_updates_folder_dialog.dart, features/follow_updates/follow_updates_page.dart, features/settings/app_controls.dart, features/settings/keyword_blocking.dart, features/settings/network.dart, features/settings/reader_brightness.dart, features/settings/remote_storage.dart, features/settings/setting_components.dart, features/settings/webdav_settings.dart；reader.dart 的自定义图片处理子页亦保留旧路径。按 D2 保留兼容 API，不扩大迁移范围。
- [x] 1.3 保存三态（进行中/成功/失败+重试）在覆盖层模式下完整保留，protect/leave/admission 语义不动 —— 依据 spec「保存语义不变」
  - 备注：覆盖层复用原进度指示及 Retry；成功用现有 Saved.tl 反馈 2 秒，计数仅记录成功结果、计时器由呈现组件持有并释放；未改 admission/protect/leave 或持久化逻辑。

## 2. 接入点改造

- [x] 2.1 收藏页（`lib/features/favorites/favorites_page.dart:117`）改用覆盖层模式，移除 Expanded 前的插入式状态条
  - 备注：FavoritesPage 根部接入 withSettingsSaveFeedback，移除 Expanded 前状态条；文件夹选择和保存流程保持原状。
- [x] 2.2 阅读模式（`lib/features/settings/reader_mode.dart:253`）改用覆盖层模式，移除设置项列表前的插入式状态条
  - 备注：ReaderModeSettings 的全局/设备及单书两个分支均包裹覆盖层，删除各自 Column 首项的插入式状态条。
- [x] 2.3 阅读设置外层（`lib/features/settings/reader.dart:354`）改用覆盖层模式，Sliver 场景同样接入 Stack 覆盖层
  - 备注：覆盖层包裹阅读设置的 SmoothCustomScrollView，移除状态条 Sliver；原滚动内容及 protectSettings 保留。
- [x] 2.4 旧插入式路径处理：全库确认仅三处接入后移除旧路径（design.md D2 倾向方案）或标记弃用，备注说明
  - 备注：检索发现 34 处原调用（19 个 lib 文件），按 D2 保留 settingsSaveStatus 并以内部注释标为 legacy；本次删除目标三个接入点的四个插入位置，其他调用不改。

## 3. 回归测试

- [x] 3.1 新增坐标回归测试：阻塞保存 Future，断言保存中正文关键 Widget 坐标与保存前一致（收藏页与阅读页两条路径）—— 依据 design.md D3
  - 备注：已新增并通过 10 项真实页面坐标测试：收藏切换 A→B 阻塞 AppDataOperations 保存；阅读设置覆盖 375/1280 宽、全局/单书、内层/外层保存。断言保存前/中/成功/反馈消失后坐标一致及滚动偏移不变。
- [x] 3.2 保存失败路径测试：覆盖层下失败态与重试入口可用
  - 备注：新增 settings_save_feedback_test.dart 的 2 项宽/窄屏测试：阻塞→失败→点击 Retry→再次保存→成功→反馈消失，正文位置/尺寸不变；覆盖层以外输入不被吞掉。

## 4. 验证与收尾

- [x] 4.1 `flutter analyze` 无新增问题（基线：38 个 tool/code_audit 环境项 + 12 个 lib/test 项）
  - 备注：fvm flutter analyze --no-pub：仍为 50 项（38 项 tool/code_audit + 12 项其余），与指定基线一致；修改的组件及新增测试无新增诊断。日志 /tmp/save-bar-analyze.log。
- [x] 4.2 相关既有测试全绿（reader_settings_persistence、favorites、settings_save_host 等）
  - 备注：配置 LD_LIBRARY_PATH=build/linux/x64/debug/bundle/lib 后，新增测试 + settings_save_host + reader_settings_persistence + favorites 可运行用例共 520 项通过；排除既有 folder_order_ownership_test.dart（:144 的 onReorder 可空返回编译错误，属于上述 12 项基线，文件与 HEAD 完全一致，未顺手修复）。初跑 QJS 缺库已由环境路径解决。日志 /tmp/save-bar-tests.log；Linux debug --no-pub 构建成功。
- [x] 4.3 手动走查：收藏页切文件夹、阅读页改设置，目视确认无下移-回弹且保存反馈可见
  - 备注：DISPLAY=:1 运行本次 debug 构建，使用 Flutter Inspector 驱动真实 GUI 回调并目视复核截图；收藏实际切至全部再返回、阅读模式真实保存均测得位移 0px，浮动反馈可见，完成后复位截图一致。脚本 /tmp/save_bar_gui.py，结果 /tmp/save-bar-gui-check.log；诊断实例已退出。
- [x] 4.4 若新增用户可见文案：走 `.tl` 系统并补 zh_CN/zh_TW 词条
  - 备注：未新增用户可见词条；进度语义复用 Save.tl、重试复用 Retry.tl、成功复用 Saved.tl（zh_CN/zh_TW 均已存在）。
