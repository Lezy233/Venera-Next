# Tasks

> 硬规则：design-spec.md、openspec/specs/**、pubspec.yaml/lock 禁改；不得生成 lock；analyze 基线50=38+12零新增；截图只留/tmp；每项完成即勾选并备注；architect批准前不得提交。工作区已有本change未提交实现，须保留F6并定向替换F7，无无关改动。
> 历史：2026-11-01 B2旧详情入口测试曾通过，但owner实际搜索无结果；2026-11-02批准废止旧F7/B2，改平台名称树。旧2.x/4.x记录不作为新设计完成证据，新任务如下。

## 1. 搜索方案基础（F6保留，仍需最终回归）

- [x] 1.1 定义 search profile 模型、JSON、名称校验和持久化。备注：已有 SearchProfile/SearchProfileSource 实现，本轮保留。
- [x] 1.2 方案 CRUD、默认选择、未知来源/schema降级及旧设置兼容。备注：已有 SearchProfileManager 实现，本轮保留并回归。
- [x] 1.3 聚合搜索/分页传递逐源有效options。备注：已有实现，移除作者分支时不得回退F6选项。

## 2. 创作者平台名称（新F7）

- [x] 2.1 删除旧详情跨平台按钮、作者fallback、专用intent/converter/parser/聚合作者分支及专用测试/孤立词条，保留原单源标签/快捷方式与F6。备注：定向移除 AuthorSearchAction/Intent/Query/Resolution、source getter/parser 及聚合作者分支，删除旧专用测试/词条；全 lib/test/translation 检索无旧接口残留，F6 profile/options 路径保留。
- [x] 2.2 实现全部本地收藏原名按来源收集、anchor/alias归属、手动名称与隐藏记录模型和持久化；含CRUD/去重/坏数据/归并重置/失败及写入归属。备注：creator_platform_names.dart 通过 allComics()逐folder原名收集、动态alias/稳定anchor、版本化entries/hidden、latest-draft updateImplicit、失败回滚及页面/目录/store generation守卫；10项模型/真实数据库持久化测试通过（/tmp/f7-model-tests.log），含同id/type跨folder不同tag与同id跨type两源。
- [x] 2.3 接入生产收藏右栏创作者区：单选树、零选/多选隐藏、平台折叠、同源多名称、显式添加/编辑/删除、键盘及有界滚动。备注：生产 _FilterSectionPanes 作者列表与平台树共享有界滚动空间；零/多选隐藏，平台标题仅折叠，名称TextButton+显式添加/更多菜单。真实260px侧栏及Tab/Enter/Space测试通过（/tmp/f7-ui-tests-v5.log）。
- [x] 2.4 接入现有窄屏筛选入口，使用其当前本地作者选择和同一平台树组件，不重置筛选/导航返回状态。备注：_LocalFavoritesFilterDialog依据其本地authors构建同树；_showFilterSheet用StatefulBuilder维护实时本地选择。窄屏生产弹窗选择与搜索返回测试通过，底层未应用筛选未被覆盖。
- [x] 2.5 名称点击使用绑定sourceKey的普通搜索与正常默认options，分页一致；失效来源保留并禁用，无标签/作者转换或聚合方案依赖。备注：树行直达绑定key的普通SearchResultPage，传原名与该源当前默认options；未用tag/author/profile通道。真实结果页Next分页及语言过滤开/关等价测试通过，卸载记录模型保留。

## 3. 设置与验证

- [ ] 3.1 Explore设置和搜索入口的F6方案管理/选择UI。备注：独立复核重开：现有SearchProfilesSettings仅名称新建/重命名/删除，无来源启用/顺序/options编辑，未满足方案CRUD与恢复契约；须补可达更新编辑入口，并修正显式选择全局设置时不能被默认方案覆盖。新F7仍不增加搜索方案入口。
- [x] 3.2 新增平台名称/管理/错误状态`.tl`双语，清理仅服务旧F7的词条。备注：新增平台树、CRUD、来源不可用/空态/错误等12项词条，zh_CN/zh_TW齐备，旧作者聚合/跨平台按钮孤立词条已删除。
- [ ] 3.3 添加模型/持久化/CRUD/自动名称隐藏恢复/alias/来源失效/数据目录切换及生产宽窄入口、选择零请求、准确单源关键词/default options/分页/返回状态测试；更新F6测试去除旧作者API依赖并跑相关回归。备注：待实现。
- [ ] 3.4 跑相关测试（原生库可用时不得依赖skip）和flutter analyze，确认50=38+12零新增，diff-check及受保护文件零diff。备注：待实现。
- [ ] 3.5 隔离数据GUI验证F6方案管理/切换及新F7生产收藏入口：同源两名+另一源一名、单选/多选、维护后重进、正确单源搜索和返回、窄屏；截图仅/tmp，区分受控来源链路与真实平台内容命中。恢复正常生产构建并停止临时fixture。备注：待实现，不沿用旧B2截图作为证据。
