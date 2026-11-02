# Design

## D1 现状与复现

统一入口lib/features/comic_widgets/comic_tile.dart：ComicTile._onTap优先页面回调，否则详情；detailed/brief/gallery已有ClickInkWell包裹封面标题，外层Stack负责收藏/进度/更新装饰。SimpleComicTile在withTitle=true时标题位于仅包封面的AnimatedTapRegion外。聚合搜索aggregated_search_page.dart使用withTitle=true。以上是结构事实，外层徽章是否导致owner首行问题必须通过真实坐标复现确认，不预设唯一根因。

执行者按diagnosing-bugs在生产组件中建立能复现的tapAt失败测试，至少覆盖可见标题首行和聚合简卡；定位首行遮挡场景时记录状态组合/布局/坐标与动作计数。若原症状仅在特定路径复现，把该最小路径纳入测试；不能通过直接调用_onTap来证明命中区域。

## D2 命中与动作语义

可见完整标题区域（含首行/后续显示行）与封面都属于同卡片主动作区域；非交互装饰不得截断该区域。主动作复用现有回调，不能另开重复导航手势；same id不同source身份与hero传递不变。标题按现有截断/宽高显示，不扩大到邻卡。

普通卡片执行原详情入口；收藏优先遵守FavoritePreferences.onClickFavorite详情或直接阅读；多选时标题/封面都切换选择且不打开页面。右键只开原菜单，复制/收藏/菜单按钮等显式独立操作不得附带主动作；菜单详情仅一次导航。无动作的装饰允许点击穿透到当前卡片；真正可操作的徽章/控件仍保留自己的独立语义。排序页保留拖拽和禁用长按菜单行为。保留原键盘焦点/激活与hover/pressed反馈，不叠加竞争手势区域。

## D3 验证矩阵

- detailed双行长标题首行左/中/右和第二行、封面，覆盖无徽章/收藏/阅读进度/更新及组合；每次恰好一次对应作品动作。
- brief、gallery宽窄卡（含原单行阈值）标题/封面；375px与桌面宽屏无溢出或邻卡误触。
- 真实聚合搜索SimpleComicTile(withTitle:true)标题/封面，绑定准确作品与sourceKey。
- 生产收藏列表/画廊的详情与直接阅读偏好、多选、右键及独立菜单；排序页拖拽回归。
- 用tester.tapAt或鼠标坐标落在具体文本行与遮挡区域，断言目标身份与次数；无网络依赖的隔离fixture可用，不能替换为纯回调测试。

## D4 框架容纳检查

依据design-spec.md §2/§3/§4/§6/§7.3保留既有token、断点、布局与主题；仅修命中区域及事件归属。ui-ux-pro-max的触达范围/按压反馈/手势冲突检查适用，不生成新视觉系统或改样式；不新增框架/主题例外，新文案若有须.tl+简繁。
