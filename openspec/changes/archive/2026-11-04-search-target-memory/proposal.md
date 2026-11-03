# F8 搜索目标记忆

## Why

SearchPage 每次打开都读取默认搜索目标与默认方案，用户刚选择的聚合/单源及方案身份丢失。F6 已验收；owner 在 B3 验收后明确安排 F8 → F9。

## What Changes

- 在当前数据目录记忆搜索页最后一次明确选择的聚合/单源模式、单源 sourceKey 及搜索方案 ID（包括明确选择「全局设置」的空 ID）。关闭、重开、新搜索及应用重启沿用。
- 首次无记忆沿用现有默认配置；已有有效记忆优先，不回写默认目标、默认方案或方案内容。
- 来源/方案失效时确定性安全回退，在控件附近说明；无可搜索来源保持既有空态且不发请求。
- 选择可靠保存、错误可恢复，异步写入保护原数据目录，防止快速选择和失败覆盖较新选择。

## Scope

不记忆关键词、逐来源临时 options/过滤器、页码及结果；不修改普通结果页/创作者平台名称入口的既有显式参数，不改搜索方案 CRUD/聚合请求规则。UI 沿用现有控件，遵循 design-spec.md §1–5、§6 交互；无统一美化或新依赖。

## Impact

主要入口 lib/features/search/search_page.dart；持久化参考 lib/features/search/search_profile.dart、lib/foundation/appdata.dart、application_preferences.dart/global_preference_store.dart。允许增加局部搜索选择模型/存储及对应测试，不重构阅读方案或应用全局持久化。F9 等本 change 验收后另开会话。
