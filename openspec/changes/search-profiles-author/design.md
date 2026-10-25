# Design

## 现状与边界

`AggregatedSearchPage` 当前只读取 `DiscoveryPreferences.searchSources` 并为每源使用 `SearchPageData` 默认选项；`SearchResultPage` 未携带聚合方案的逐源选项。搜索选项属于来源 schema，方案必须按 source key 保存并在 schema 变化时安全降级。

## 搜索方案模型

新增 appdata 顶层 `searchProfiles`，记录稳定 id、名称、来源顺序、每个来源的 option 值和 enabled 状态；另存可选默认 profile id。方案名称 trim 后非空、≤30 字符、同库不重名（大小写不敏感）。未知/卸载来源在读取时忽略，保存时不破坏其余来源；删除来源时清理对应条目。现有 `searchSources` 与 `defaultSearchTarget` 保留，未选择方案时维持当前行为。

方案管理入口放在 Explore 设置，聚合搜索页提供方案选择。方案加载使用各源当前 `SearchPageData.searchOptions` 校验已存值，无法恢复的值回退该选项默认值。结果页构造参数携带 profile snapshot，分页和切源不丢失选项。

## 作者跨源搜索

在 `ComicDetails.findAuthor()` 或标准作者 tag 入口产生 `AuthorSearchIntent`（原始显示值、标准化值、来源上下文）。来源通过搜索能力声明提供作者查询转换；转换结果是该源可接受的 keyword/options，无法转换的来源返回 unsupported。聚合结果按方案来源顺序执行，unsupported 来源在结果页显示跳过状态。不得把普通作者文本自动当作所有来源都支持的统一语法。

## 框架容纳检查

- 搜索方案管理复用设置 list-detail、聚合结果现有 surface 和 `design-spec.md` 第 2–4、7.2–7.3 节，无新增 token/断点/壳层例外。
- 作者入口和结果状态使用现有内容区布局，不新增深色 surface 或第二套导航。
- 所有新增文案遵循第 6 节，使用 `.tl` 并补 `zh_CN`/`zh_TW`。

## 验证与风险

覆盖方案持久化/迁移、来源顺序和 option 恢复、卸载来源、聚合分页、作者能力转换及 unsupported 状态。主要风险是来源脚本能力不一致；能力声明必须让不支持的来源显式跳过，而不是发送猜测查询。
