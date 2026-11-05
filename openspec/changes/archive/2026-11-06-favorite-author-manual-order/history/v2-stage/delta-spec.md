## ADDED Requirements

### Requirement: 文件夹作者横栏

具体本地收藏文件夹 MUST 提供纵向滚动的作者shelf视图；每个有效作者一栏，多作者漫画 MUST 可同时出现在多个栏且同栏去重。栏序 MUST 按完整folder order首次出现位置，无作者使用独立键并显示「未命名作者」置末。MUST NOT 提供栏间拖拽排序或修改作者元数据。

#### Scenario: 多作者与未知作者

- **WHEN** 文件夹顺序为甲乙共同作品、乙作品、无作者作品
- **THEN** 共同作品在甲、乙各显示一次，甲乙顺序沿首次出现及存储作者序，无作者栏最后；跨栏重复实例身份不冲突，多选只计同一业务身份一次

### Requirement: 三态布局与持久化

每栏 MUST 提供collapsed、normal、expanded三态，按文件夹+作者持久化；缺失或坏数据 MUST 回normal。collapsed MUST 等高单行横向浏览并显示作者名/本数，Shift+滚轮仅移动本栏；normal MUST 依现有封面列数排网格，行数ceil(N/列数)，折叠↔正常高度动画；expanded MUST 在同一网格底部显示本地平台名称面板。箭头与作者名称 MUST 分离命中并按design D3切态，不与长按拖拽冲突。

#### Scenario: 三态与滚轮隔离

- **WHEN** 两栏collapsed，用户在第一栏按Shift滚轮，再以箭头展开normal并点击作者名
- **THEN** 仅第一栏横移、父页及邻栏不滚动；normal的5本/2列为3行，随后expanded追加面板；重启后各文件夹作者状态保留

### Requirement: 作者子序列可靠排序

collapsed及normal漫画 MUST 支持鼠标长按栏内拖动与可访问替代操作，MUST NOT 跨栏落位。排序 MUST 在原目录/连接/文件夹生命周期下以最新完整成员验证移动及相邻身份，仅重排该作者占据的folder order子序列槽位并事务写回，隐藏项及其他作品槽位不丢失；MUST NOT 使用v1独立rank取代真实folder order。普通点击、多选、右键、详情/直读、键盘行为 MUST 保持。

多作者重叠导致其他作者投影改变时的规则尚待owner裁定（design D4）；executor MUST NOT 自行决定，相关分支与最终验收须等待architect工件更新，其余任务可执行。

#### Scenario: 单作者交错成员移动

- **WHEN** 顺序甲1/乙1/甲2/乙2中，将甲2移到甲1前
- **THEN** folder order为甲2/乙1/甲1/乙2，乙顺序及非排序字段保持，拖动不打开漫画；新实例读取同序

#### Scenario: 写入失败或归属变化

- **WHEN** 排队期间原文件夹消失、作者变化、切目录/连接或SQLite真实写入失败
- **THEN** 操作在原归属下拒绝或回滚，不写新库、不复活成员、不假成功，并提供可恢复局部反馈

### Requirement: 平台名称单源普通搜索

展开面板 MUST 读取CreatorPlatformNamesStore并按sourceKey分组，同源多名称分别显示；展示及空态 MUST NOT 发起网络请求。可用名称点击 MUST 按creator_platform_names_view.dart::_search语义读取绑定来源点击时SearchPageData当前默认选项，打开一次SearchResultPage(text: 名称, sourceKey: 绑定来源, options: 默认值)。MUST NOT 经过作者转换/聚合或请求其他来源。失效来源 MUST 保留记录、显示「来源不可用」并禁用点击。

#### Scenario: 同名来源不混淆

- **WHEN** A、B来源同名，展开面板后点击绑定A的名称
- **THEN** 展开本身0网络，点击后仅A普通搜索一次且使用A当前默认选项，B/作者转换/聚合请求为0，F8记忆不变
