# Tasks

> 硬规则：design-spec.md、openspec/specs/**、pubspec.yaml/lock禁改；不生成lock/不加依赖；analyze50=38+12零新增；新文案.tl+zh_CN/TW；截图仅/tmp；逐项完成即勾选备注；设计冲突停止上报；开工工作区干净、无无关改动，architect批准前不得提交。B3完成并经architect复核/批准提交后，再开始本change，独立新会话读取本目录。

- [ ] 1.1 用生产ComicTile及SimpleComicTile(withTitle:true)建立真实坐标失败测试，复现首行/标题不可点，记录布局/徽章状态/坐标/根因与红灯证据；不预设徽章就是根因。
- [ ] 1.2 修复可见标题/封面命中及装饰穿透，主动作复用原回调与身份；覆盖detailed/brief/gallery宽窄卡及带标题简卡，避免重复导航和竞争手势。
- [ ] 1.3 补真实坐标回归矩阵：首行左中右/后续行/封面、徽章组合、长标题/不同布局、准确作品与source身份；收藏详情/直读/多选、右键/独立操作、键盘与排序拖动保持。
- [ ] 2.1 跑新增及漫画卡片/列表/收藏显示/聚合搜索相关回归，analyze50零新增、protected零diff、diff-check；交付精确计数和日志。
- [ ] 2.2 DISPLAY=:1隔离GUI验证标题首行、聚合简卡与收藏多选等真实入口；截图仅/tmp，恢复正常main构建并停止自己的fixture，交付等待architect独立复核，不提交。
