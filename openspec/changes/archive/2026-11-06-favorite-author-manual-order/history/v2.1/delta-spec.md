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

### Requirement: 作者栏独立可靠排序

collapsed及normal漫画 MUST 支持鼠标长按栏内拖动与可访问替代操作，MUST NOT 跨栏落位。每栏漫画顺序 MUST 按文件夹+canonical作者或独立unknown持久化，并使用(id,type)完整漫画身份；多作者漫画在不同栏的顺序 MUST 独立。操作 MUST 在原目录/连接/文件夹生命周期下读取最新成员、alias和该栏完整顺序，验证移动及相邻身份并事务更新仅该栏顺序。MUST NOT 因共享作者拒绝合法移动、联动其他栏、写回普通folder display_order或改变作者栏上下顺序。普通点击、多选、右键、详情/直读、键盘行为 MUST 保持。

#### Scenario: 多作者作品各栏互不影响

- **WHEN** 甲乙两栏均有共同作品C1/C2且初始均为C1/C2，用户在甲栏把C2移到C1前
- **THEN** 甲栏为C2/C1、乙栏仍C1/C2，普通folder order、栏上下顺序、其他文件夹/系列及非排序字段均不变；拖动不打开漫画，不因多作者提示冲突；重启仍保留两栏不同顺序

#### Scenario: 文件夹隔离与过滤移动

- **WHEN** 两个文件夹都有作者甲，用户只在第一个文件夹甲栏的过滤结果中移动可见作品
- **THEN** 只更新该文件夹甲栏的可见槽位，隐藏成员、其他作者及第二个文件夹顺序不变；折叠状态与平台名称记录不被排序清除

#### Scenario: 写入失败或归属变化

- **WHEN** 排队期间原文件夹消失、作者变化、切目录/连接或SQLite真实写入失败
- **THEN** 操作在原归属下拒绝或回滚，不写新库、不复活成员、不假成功，并提供可恢复局部反馈

### Requirement: 作者栏顺序持久化及成员维护

初次无记录时 MUST 沿真实folder order的作者子序列显示，已有独立顺序 MUST 保留；新增或新归入成员按folder order追加，移出/删除成员清理，重加不复活旧位置。过滤后移动 MUST 仅重排该栏完整顺序中的可见槽位，隐藏成员位置不变。坏记录 MUST 确定性回退、无遗漏/重复且build不写库。改名迁移、删重建隔离、alias及整库备份/目录切换 MUST 按design D4保持可靠归属。

#### Scenario: 独立顺序在改名和重启后保留

- **WHEN** 两文件夹同作者具有不同顺序，用户改名其中一个文件夹并重启
- **THEN** 两文件夹各自顺序及折叠状态保留，删除重建的文件夹从初始顺序开始，不继承已删除身份的排序

#### Scenario: 新增和删除重加

- **WHEN** 已排序作者栏新增作品，或删除原作品后重新加入
- **THEN** 已有有效成员相对顺序不变，新成员按完整folder order在新成员中的次序追加；不复活旧位置，其他栏保存的顺序不被该栏排序操作覆盖

### Requirement: 平台名称单源普通搜索

展开面板 MUST 读取CreatorPlatformNamesStore并按sourceKey分组，同源多名称分别显示；展示及空态 MUST NOT 发起网络请求。可用名称点击 MUST 按creator_platform_names_view.dart::_search语义读取绑定来源点击时SearchPageData当前默认选项，打开一次SearchResultPage(text: 名称, sourceKey: 绑定来源, options: 默认值)。MUST NOT 经过作者转换/聚合或请求其他来源。失效来源 MUST 保留记录、显示「来源不可用」并禁用点击。

#### Scenario: 同名来源不混淆

- **WHEN** A、B来源同名，展开面板后点击绑定A的名称
- **THEN** 展开本身0网络，点击后仅A普通搜索一次且使用A当前默认选项，B/作者转换/聚合请求为0，F8记忆不变
