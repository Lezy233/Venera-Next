# Tasks

> 硬规则：design-spec.md、openspec/specs/**、pubspec.yaml/lock 禁改；pubspec.lock 不得重新生成；analyze 基线 50 项不得新增；截图只留 `/tmp`；工作区必须干净；architect 批准前不得提交。

## 1. 搜索方案基础

- [x] 1.1 定义 search profile 模型、JSON 编解码、名称校验和 appdata 持久化迁移。备注：新增 SearchProfile/SearchProfileSource 模型、JSON 解码、名称 trim/长度/大小写校验，并持久化至现有 settings 通道。
- [x] 1.2 实现方案 CRUD、默认选择、来源卸载/未知来源清理和现有设置兼容。备注：SearchProfileManager 支持新建/重命名/更新/删除/默认选择；读取时忽略卸载来源并按当前 option schema 回退无效值，缺省方案继续使用 searchSources/defaultSearchTarget。
- [x] 1.3 为聚合搜索和结果分页传递 profile 的逐源有效 options。备注：AggregatedSearchPage 使用 profile 解析后的来源顺序/options 快照，_SliverSearchResult 和 SearchResultPage 分页均复用同一 options，不回退默认值。

## 2. 作者跨源搜索

- [x] 2.1 定义来源作者查询能力与转换接口，补齐能力声明及 unsupported 结果模型。备注：ComicSource 增加 authorSearchConverter，JS 来源通过 search.author 声明；AuthorSearchQuery/unsupported 状态模型已接入。
- [ ] 2.2 从标准作者 tag/详情作者入口创建 AuthorSearchIntent，并按方案来源执行聚合作者搜索。备注：原实现仅在无既有单源跳转时提供 fallback，且使用首位作者，未满足 B2；2026-11-01 复核重开，完成 4.1/4.2 后再勾选。
- [x] 2.3 在结果页展示来源跳过/失败状态，不改变现有单源 tag 跳转和快捷方式。备注：聚合结果对未声明 authorSearchConverter 的来源显示 Author search unsupported，并跳过网络请求；已有单源 target 优先保持。

## 3. 设置与验证

- [x] 3.1 在 Explore 设置和聚合搜索页加入方案管理/选择 UI，遵循 design-spec。备注：Explore 增加 Search profiles 管理页，聚合搜索入口增加 profile 下拉选择并传递 profileId。
- [x] 3.2 新增 `.tl` 文案并补 `zh_CN`/`zh_TW`。备注：方案管理、全局回退、作者 unsupported 及校验提示均已补双语词条，代码使用 .tl。
- [x] 3.3 添加模型、持久化、分页、source schema 变化、作者转换和 unsupported 状态测试。备注：search_profile_test.dart 覆盖 JSON 顺序/启用/options、AuthorSearchIntent、Manager CRUD/默认/名称校验；聚合页统一复用解析 options，unsupported 分支不发请求。
- [x] 3.4 运行相关测试与 `fvm flutter analyze --no-pub`，确认基线 50 项无新增。备注：搜索 profile/persistence/filter/shortcuts/source parser 回归 12 项全绿，新增 profile 测试 3 项全绿；analyze 50 项，新增问题 0。
- [ ] 3.5 用 `DISPLAY=:1` 隔离数据目录走查方案切换和作者入口；截图仅存 `/tmp`。备注：已构建并在隔离 XDG 目录启动，窗口截图 `/tmp/search-profiles-gui-20261025/search-home.png`、`search-explore.png`，日志 `/tmp/search-profiles-gui-20261025.log`；日志中的 2 次右侧/1 次底部 15px overflow 发生在启动即显示的既有 Home 页面，持久化 logs 仅有 `null` 无新增代码堆栈；新增 profile compact widget 测试无异常，且 profile 下拉已限定 160px 防止自身溢出。当前会话 XTest 导航事件不生效，无法完成方案切换/作者入口交互，保持未勾选。

## 4. B2 作者入口验收修正（owner 2026-11-01 批准）

- [ ] 4.1 为每个非空标准作者标签添加可见「跨平台搜索」操作，支持 Tab/Enter/Space，窄屏可换行；原单源标签行为不变。备注：待实现。
- [ ] 4.2 使用所选作者 tag 原始值创建 intent，修正多作者 fallback；作者完整结果/分页沿用转换查询，unsupported 行不可绕过限制，转换异常与全不支持有明确状态。备注：待实现。
- [ ] 4.3 补齐 `.tl` 双语文案与有意义的入口 widget/查询链路回归测试：有单源 target、多作者、键盘、窄屏、unsupported 零请求、转换结果传递。备注：待实现，不以纯模型构造测试代替用户入口测试。
- [ ] 4.4 跑新增与相关回归、analyze 基线计数、受保护文件/差异检查，并用隔离数据 GUI 展示真实作者详情入口，截图留 `/tmp`；如 GUI 仍阻塞须如实交付，不虚勾。备注：待实现。
