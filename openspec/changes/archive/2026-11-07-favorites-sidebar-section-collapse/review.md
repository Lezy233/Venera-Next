# F11 architect独立复核

结论：符合，等待owner人工验收。HEAD仍`31b38e07d8c0df1ed9b424aaa67c0cc081176408`；实现未提交、不归档、不push，不启动其他change。tasks1.x 5/5。

## 实现与契约

已核对四件套、三份生产源码与新增行为测试。页面拥有local/series/network三组状态，向常驻侧栏和窄窗选择器提供同一来源；保存走既有SettingsSaveState/updateImplicit，未知字段合并、坏值逐项回退、失败重试/连续更新/离页等待均有真实文件行为验证。未更改收藏身份、数据库、来源配置、作者栏排序或当前内容业务代码。

组头可点击主体/箭头，菜单和网络设置独立；键盘Enter/Space/Left/Right作用于组头焦点，隐藏子项移除且焦点归还。当前摘要按有效系列id/来源key/本地身份判定，All与null区分；内容实例、多选、筛选、滚动和网络请求次数保持。新增UI使用token与主题，全部文案复用已有.tl，无翻译或新设计例外。

源码四项SHA与冻结交付相同，见reviewed-files.json。architect只执行独立复核与验收收尾，不改实现或测试。executor最后因用量限制退出，其GUI收尾由architect完成；旧/tmp证据被清理后已重留必要证据，本文不把历史临时路径冒称仍存在。

## 独立自动化

固定代理与原生库环境后运行：

```sh
env https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897 LD_LIBRARY_PATH=/home/_Le/Code/Projects/Venera-Next/build/linux/x64/debug/bundle/lib fvm flutter test --no-pub test/features/favorites/sidebar_sections_test.dart test/features/favorites/favorites_view_persistence_test.dart test/features/favorites/favorites_settings_persistence_test.dart test/features/favorites/favorite_series_test.dart test/features/favorites/favorite_hit_target_test.dart test/features/favorites/creator_platform_names_view_test.dart test/features/favorites/author_shelf_model_test.dart test/features/favorites/author_shelf_storage_test.dart test/features/favorites/author_shelf_order_test.dart test/features/favorites/author_shelf_ui_test.dart test/features/favorites/author_shelf_drag_test.dart test/features/favorites/author_shelf_independence_test.dart test/features/favorites/author_shelf_layout_test.dart test/features/favorites/author_shelf_hover_test.dart --reporter expanded
fvm flutter analyze --no-pub
```

独立相关140通过0失败0skip，包含26新增与114原相关，不能重复相加。临时证据清理前及重留后各独立跑过同一冻结集合；当前日志/tmp/f11-review-regression.log，非全库测试。新增覆盖真实生产坐标、键盘、错误文件写入/Retry、doInit磁盘重载、快速混合切换、窗口等待、当前内容实例/两项多选/筛选/滚动、同名身份、网络计数、隐藏焦点、空组、简繁×浅深×160/256宽度×1.6文字。

当前完整分析/tmp/f11-review-analyze.log raw=unique=50，38为tool/code_audit、12为其余。前轮独立基线集合比对added=[] removed=[]，该比对后四源码完全未变；临时日志清理后再次分析仍同一计数。当前全部诊断已持久化reviewed-analyze.json，便于之后不依赖/tmp。

原始坐标红灯0通过1失败为点击Local后子项不隐藏，最终26绿。新增测试中编译/fixture失败未混算产品红灯。窄窗关闭用例曾在动画时间恰等于duration时看到值0但状态reverse；本地SDK的isDone要求time>duration，最后按真实反向时长再推进1微秒清理，仍保留严格最终移除、磁盘值和保存屏障断言。未改生产生命周期，临时探针已移除。

既有folder_creation两个业务失败和folder_order编译基线不在140集合内；executor前后单列复验记录及派生loading计数见delivery.md，未删原断言或当作skip。额外42项阅读布局保护是executor运行的三文件集合，并非B5像素17项或独立148全量，本轮未触碰B5。

## 独立GUI与局限

只操作核对后的本轮fixture，DISPLAY=:1、GDK_BACKEND=x11，业务/cache/XDG均隔离/tmp/f11-gui。自身PID106449→112612，窗口0xa00002，宿主1080×760，实际窗口1280×800及390×800。重建验收helper SHA374c761603d6eebb505f3dc747b2aa770d39871da31a05b5566ae92c29ff3148；固定title/PID/exe/环境标志核对、动作白名单、坐标窗口/宿主预检与finally释放。

逐张view_image核对当前证据：

- /tmp/f11-gui/review-before-restart/frame-2/3/4.png：浅色选中两张→本地折叠后仍两张→深色仍两张，摘要与内容正确。
- frame5.png：Escape退出，多选清空、当前内容保持；Escape后卡片主动作的真实路由次数由已通过B4原回归保护，未把GUI未做的真实书籍打开算通过。
- frame7.png：窄窗选择器共享折叠状态；/tmp/f11-gui/x11-narrow-menu.png实际管理菜单打开，标题不误切换且选择器保留。
- frame9/10.png：Tab到组头，Right展开/Left收起并保留可见焦点。
- frame11/12.png：深色1.6文字与繁体窄窗选择器，独立菜单/摘要可用，无overflow。
- frame13.png及新进程/tmp/f11-gui/frame-0.png：local=false/series=false/network=true在真实进程重启后保持，重启前后implicitData文件cmp退出0。

frame图为完整RepaintBoundary输出，不冒称完整X11宿主；菜单图是实际X11窗口截图，底部受宿主高度限制。fixture使用受控本地库和封面占位，GUI无真实已安装网络来源；网络请求计数/当前身份由生产组件受控来源自动化覆盖。重启是稳定保存后终止进程，不冒称GUI验证未完成保存时优雅退出，该等待由自动化覆盖。没有为截图修改正常main/runner或实现。

## 正常构建与保护

正常`fvm flutter build linux --debug --no-pub`无target构建成功，/tmp/f11-review-main-build.log。最终kernel包含package:venera_next/main.dart且无f11_gui.dart，SHA296ad3d097a443e52db171ab67b4b8eac80d877bd7b8a2d5c3f0fd1d284b6f47。两个自身PID消失，X11只余原qq和Chromium clipboard两个10px窗口，未操作它们。

design-spec.md、openspec/specs/**、pubspec.yaml/lock、历史归档、本change proposal/design/delta spec、正常main/runner均HEAD零diff。其他收藏/阅读器业务实现无diff；无图片入库、依赖或锁文件变动。git diff --check与OpenSpec活动change校验通过。任务5/5与最终SHA匹配，等待owner人工验收；当前不授权实现提交、归档或push。
