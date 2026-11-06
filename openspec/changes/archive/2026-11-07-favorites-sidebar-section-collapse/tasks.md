# F11 收藏侧栏大分类折叠

基线e5a11aa，执行工件以派工HEAD为准。每项完成立即勾选并备注命令/计数/证据；设计冲突先报告architect，不自行修订工件。

- [x] 1.1 核对HEAD和干净工作区，读最小清单/UI技能及被指名源文件；记录生产组头、两侧栏入口、当前身份/内容和保存生命周期。先以真实生产控件坐标/键盘建立缺失行为红灯及既有相关基线，排除fixture异常；记录实际修改范围，不全库探索。
- [x] 1.2 按D2/D4实现三组独立状态与可靠持久化、默认/坏数据回退、两入口共享、快速切换/失败重试/离页等待；真实文件重载红绿通过，不覆盖其他设置或扩大存储重构。
  备注：`favoritesSidebarSections` map使用local/series/network布尔值，页面拥有同一ValueNotifier传给两个入口；updateImplicit合并未知字段及其他设置，SettingsSaveState保存同一目标的完整最终快照并保留失败链。`/tmp/f11-sections-iteration3.log` 中默认/坏项5例、生产标题、快速混合切换+doInit磁盘重载、真实.tmp写失败/旧文件保留/可见Retry、移除页后WindowFrame等待共9例已通过；后续键盘语义Tristate测试断言错误另行修正，未将其计入通过。两入口坐标互通补充于1.3。
- [x] 1.3 按D2/D3/D5实现组头命中/独立菜单/键盘焦点语义、隐藏条目处理及当前项摘要；真实生产FavoritesPage坐标验证内容实例、多选/筛选、同名身份和网络请求次数不变，窄窗不误关闭。新文案.tl+zh_CN/zh_TW，不扩美化。
  备注：`/tmp/f11-sections-final.log` 独立26通过0失败0skip。覆盖生产文字/箭头坐标、Tab/Enter/Space/Left/Right、隐藏焦点归还、当前All/同名系列/网络身份、真实内容实例/两项多选/UnCompleted筛选/滚动/Escape、网络请求0/1保持、空组菜单/网络设置、窄窗共享/菜单不关闭及真实磁盘坏项/混合切换/失败Retry/离页等待。简繁×浅深×160/256×1.6文字无overflow。全部文案复用已有.tl（Expand/Collapse/Settings/组名/All），无新增key。窄窗测试根因是SDK动画isDone严格大于duration，见delivery，未改生产生命周期。四源码冻结SHA见delivery和/tmp/f11-source.sha256。
- [x] 1.4 完成D6新增及受影响原回归，保留原语义断言；记录通过/失败/skip和HEAD基线区别。analyze raw/unique50=38+12具体集合零新增、protected零diff、diffcheck/OpenSpec和最终源码SHA通过，冻结源码供architect独立复核。
  备注：新增独立26通过；architect冻结源码14文件独立140通过0失败0skip（/tmp/f11-architect-regression.log）。执行者与architect独立analyze raw/unique50=38tool+12其余，具体集合added=[] removed=[]。三文件阅读布局保护42通过0失败0skip（非B5 gallery像素17项，未冒称重跑）。受保护正式spec/design/pubspec/lock/历史归档及本change proposal/design/delta零diff；diffcheck/OpenSpec通过，四源码SHA复验OK。已知folder_creation两业务失败与folder_order编译错误及并行编译派生loading计数独立列delivery，不吞新增失败、不改原断言。保持冻结，余GUI/构建/清理见1.5。
- [x] 1.5 按D6隔离GUI真实标题/键盘/菜单/当前组及多选保持、窄窗与重启持久化走查，输入后稳定逐图核对，截图只/tmp、helper先读核；正常main构建恢复并停自身fixture，独立ps/X11清理。delivery.md交付真实命令/计数/文件SHA、保护、GUI场景和局限，等待architect独立复核，不提交/归档/push，不启动其他change。
  备注：executor触发用量限制后，architect仅完成独立GUI验收/正常构建与清理，不改实现或测试。/tmp旧证据清理后重留：自身PID106449→112612；两项选择前后、当前组摘要/深浅、390窄窗共享/实际管理菜单、Tab/Right/Left、繁体1.6文字、真实重启local=false/series=false/network=true及磁盘cmp一致均逐图核对。正常main构建/tmp/f11-review-main-build.log成功，kernel无fixture入口，两个PID及X11窗口均清除；四源码SHA不变。刷新独立回归140通过0失败0skip、analyze raw/unique50=38+12，详见review.md与reviewed-analyze.json；未提交/归档/push。

1.1备注：HEAD 31b38e07d8c0df1ed9b424aaa67c0cc081176408、开局干净。最小工件/UI清单/诊断技能及入口与直接保存测试已读；页面SettingsSaveState持有保存/重试/离页等待，生产侧栏两入口无独立折叠。真实标题坐标红灯 `/tmp/f11-red.log` 0通过1失败（Local后A仍存在，非初始化异常）；相关基线 `/tmp/f11-baseline-test.log` 45通过2既有folder_creation失败0skip；analyze `/tmp/f11-baseline-analyze.log` 50项。计划修改side_bar.dart、favorites_page.dart，新增小型分组偏好模块及sidebar_sections测试，必要翻译和本change tasks/delivery；不触碰保护实现。
