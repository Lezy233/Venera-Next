# Tasks

> 硬规则：design-spec.md、openspec/specs/**、pubspec.yaml/lock禁改；不生成lock/不加依赖；analyze50=38+12零新增；新文案.tl+zh_CN/TW；截图仅/tmp；逐项完成即勾选备注；设计冲突停止上报；开工工作区干净、无无关改动，architect批准前不得提交。B3完成并经architect复核/批准提交后，再开始本change，独立新会话读取本目录。

- [x] 1.1 用生产ComicTile及SimpleComicTile(withTitle:true)建立真实坐标失败测试，复现首行/标题不可点，记录布局/徽章状态/坐标/根因与红灯证据；不预设徽章就是根因。
- [x] 1.2 修复可见标题/封面命中及装饰穿透，主动作复用原回调与身份；覆盖detailed/brief/gallery宽窄卡及带标题简卡，避免重复导航和竞争手势。
- [ ] 1.3 按修订design D2.1让brief<88px复用既有18px紧凑徽章，保留72px三状态无溢出用例并覆盖87/88边界，不调高测试下界；补真实坐标回归矩阵：首行左中右/后续行/封面、徽章组合、长标题/不同布局、准确作品与source身份；收藏详情/直读/多选、右键/独立操作、键盘与排序拖动保持。
- [ ] 2.1 跑新增及漫画卡片/列表/收藏显示/聚合搜索相关回归，analyze50零新增、protected零diff、diff-check；交付精确计数和日志。
- [ ] 2.2 DISPLAY=:1隔离GUI验证标题首行、聚合简卡与收藏多选等真实入口；截图仅/tmp，恢复正常main构建并停止自己的fixture，交付等待architect独立复核，不提交。

### 1.1 红灯记录

- 开工 HEAD e15dfd2161b72a3f24bd73ada8437695841f3df4，git status --short 为空。
- `fvm flutter test --no-pub test/features/comic_widgets/comic_hit_target_test.dart --reporter expanded`，日志 `/tmp/b4-red.log`：1通过2失败，0skip。生产 detailed 375×180，首行 glyph rect=(143.6,11)-(300.4,25)，tapAt(146.6,18)：无状态1次，收藏状态0次。生产 SimpleComicTile(withTitle:true)，tapAt(6.1,150)：0次。
- 两个最小路径：详细卡片的装饰Stack是原InkWell的兄弟节点，装饰容器空白部分也参与命中，遮住首行；简卡标题在封面手势区域之外。接着以逐变量修复与真实聚合路由测试确认。

### 1.2 修复记录

- 三布局共用原ClickInkWell，将其由布局内部提到状态Stack外：单一主动作/右键/长按识别器包含标题、封面和装饰；保留徽章位置与进度Tooltip。
- AnimatedTapRegion增加可选footer，将简卡标题纳入同一手势，footer仍在封面AnimatedPhysicalModel外，保留原阴影/圆角/标题尺寸。
- 原始3测试绿灯，日志`/tmp/b4-green-initial.log`：3通过0skip，同一首行/简卡坐标恢复恰好1次。生产聚合页准确来源详情测试已通过（两来源同id各标题/封面，4次目标详情，无SearchResultPage）。
