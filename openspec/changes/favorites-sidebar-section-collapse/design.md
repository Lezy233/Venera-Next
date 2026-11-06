# F11 设计与验收边界

## D1 最小上下文与范围

生产FavoritesFolderSidebar在side_bar.dart按本地（含全部）、系列、网络依次展示；FavoritesPage分别承载常驻侧栏与窄窗选择器。LocalFavoritesPage的创作者/标签采用chevron_right/expand_more及Expand/Collapse tooltip，仅作为交互参照，不改其既有状态。planner只读取接口与布局契约，不承担实现debug。

executor只读AGENTS/ROADMAP、本change四件套、design-spec §1/2/3/4/5/6/7.3、相关源文件及其直接测试依赖。使用ui-ux-pro-max已有UI检查清单核对命中/焦点/反馈，不生成新设计系统；遇到失败使用diagnosing-bugs反馈循环，不将初始化异常当产品红灯。

## D2 三组状态、标题和操作边界

固定三组local/series/network，顺序不变，各自expanded布尔状态，默认true。折叠隐藏该组全部子条目，本地包含All；组头始终显示，空组也可折叠且保留菜单/设置。三组互不联动，不依赖当前选择自动展开；后续选择或外部数据刷新不重置折叠。此状态与整个左栏显隐、右栏创作者/标签及F10作者shelf三态完全独立。

标题主体（展开箭头、原图标与文字所在可用区域）左键切换一次。右侧本地/系列管理菜单、网络设置为独立命中区，点击仅执行原动作，不切换分组、不导航、不关闭窄窗选择器。切换分组本身不得调用onFolderSelected/onSeriesSelected/onSelected，不触发目录/来源选择、菜单或来源网络请求。

沿用现有箭头语义：展开为expand_more、收起为chevron_right；Expand/Collapse tooltip翻译可复用。标题有明确hover/pressed/focus反馈，可通过Tab聚焦、Enter/Space切换一次；焦点在标题时Left收起、Right展开（幂等），不注册窗口级快捷键。折叠后隐藏条目不参与Tab和可访问性树；若焦点原在将被隐藏条目上，归还该组头，不跳内容或其他窗口。Semantics提供组名、button、expanded及适用的selected状态，避免嵌套控件重复朗读或同一事件双触发。

## D3 当前位置与内容保持

分组归属按有效当前身份：selectedSeries非空且有效优先为系列；否则有效selectedFolder按isNetworkSelected归本地或网络；未选中则无当前组。本地All是既有明确条目身份，不把null伪装成All。来源key/系列id为身份，不能按显示名判断；本地、系列、网络同名时仅正确组标记当前。

当前组折叠时组头保留清楚的当前标记：复用现有选中底色/左侧细条，并在组头显示当前条目名（本地All用既有翻译，网络用已有来源标题，系列用系列名）；文字超宽可省略，但tooltip及语义含完整名称。标记有文字信息，不能只改变颜色或增加装饰性尾随箭头。展开后保留原子条目选中语义，不额外把其他组标为当前。选中项改名/合法删除或来源卸载时沿用现有选择恢复规则，只更新展示，不借本change另修其业务。

折叠与展开仅影响侧栏子项可见性，不卸载或重建当前内容的身份：现有LocalFavoritesPage/LocalFavoriteSeriesPage/NetworkFavoritePage的当前实例/有效状态不因折叠重置。多选选择集合/数量、Escape退出、筛选、滚动与作者独立排序均保持；网络内容不得因切换组头额外发起请求。折叠含当前项的组后，重新展开仍显示原选中项；无需再次点击来恢复内容。窄窗切换组不关闭选择器；实际选择子项仍沿用原关闭流程。

## D4 持久化与失败恢复

状态作用域为本机应用收藏导航偏好，按local/series/network固定标识保存，不按文件夹/系列/来源/翻译名分裂，也不写收藏数据库、folder order或网络配置。使用已有appdata.updateImplicit事务保存新namespaced数据，记录实际key/格式；不得以整份旧implicitData覆盖其他写入。缺失/非map整体回退三组展开；单项只接受bool，坏项或缺项单独回退true，其他合法项保留，不将字符串false当false。未知字段及不相关implicitData保持，旧数据不迁移或改动既有作者/标签、侧栏宽度显隐偏好。

FavoritesPage内桌面侧栏与窄窗选择器使用同一有效状态来源：resize、关闭/重开选择器、刷新、离开再回、真实重启后保持；不得出现两个各自初始化的侧栏互相覆盖新值。允许以页面拥有的状态与回调或等价小模块接入，不为此扩大重构。

使用既有可靠设置保存/失败反馈流程，允许即时预览：快速连续切换的最终意图正确保存，按组更新不丢其他组更新，失败不静默当成功或显示Saved。保留旧可靠磁盘数据与最新待保存意图，提供既有可见错误/重试入口，重试成功才认定持久化成功；旧失败/旧回调不得覆盖新意图或更新已销毁widget。已接受保存不因关闭选择器/离页/关闭自身窗口被丢弃，按既有保存等待机制处理。不新增依赖，不另造全局存储或后台重试服务。

## D5 UI与保护

遵守design-spec和现有侧栏密度；新增间距/圆角/颜色/动效走token及ColorScheme，不美化历史0.6分隔/42行等无关代码，不统一修改卡片或主题。箭头是折叠功能控件，非选中装饰。新增当前项摘要可使标题按文字合理增高，160最窄栏和1.6文字不能溢出或挤没独立菜单；不改侧栏宽度范围、应用断点和窗口框架。动效若引入，使用现有motion token并尊重减少动画，快速反转可中断。允许不增加非必要动画。

所有新增UI/语义/tooltip文案.tl，assets/translation.json补zh_CN/zh_TW；已有文案复用。阅读器chrome继续跟随主题。design-spec.md、openspec/specs/**、pubspec.yaml、pubspec.lock及此前归档禁止executor改动，proposal/design/delta spec不可自行修订；冲突报告architect。

## D6 回归矩阵与交付

| 场景 | 证据要求 |
|---|---|
| 三组独立性 | 生产FavoritesFolderSidebar，各有至少2子项；标题文字中心/箭头坐标点击，子项消失/返回，其他两组不变；空组仍保留组头与管理入口 |
| 手势/键盘 | Tab/Enter/Space、Left/Right幂等、焦点语义与隐藏子项不可聚焦；组头菜单/网络设置实际点击仅原动作，回调和路由准确次数，窄窗不误关闭 |
| 当前内容 | 本地具体文件夹/All、系列、网络分别选中后收起再展开；同名身份隔离、折叠头摘要准确；真实内容实例/多选2项/筛选不变，Escape可退出后主动作恢复；网络请求计数不增加 |
| 存储生命周期 | 默认/坏整体/坏单项/未知字段、连续混合切换、保存中离页/重开、写入失败与重试；真实磁盘读取/重新初始化，不只测内存；桌面与窄窗两入口保持 |
| UI矩阵 | 1280×800与390×800、侧栏160/默认宽度、浅深主题、中文简繁、文字1.6及减少动画；无overflow，hover/focus/当前标记可见，菜单独立可用 |
| 既有保护 | favorites_view_persistence、favorites_settings_persistence、favorite_series、favorite_hit_target、creator_platform_names_view、author_shelf相关实际受影响测试；保留原语义断言，不删弱断言绕失败 |

测试必须驱动真实生产控件文本/箭头坐标和键盘，持久化须真实文件/重载；网络来源可使用受控本地fixture计数，不访问真实来源。不能仅调用回调或只断言helper属性替代。对HEAD既有folder_creation_presentation两失败和folder_order_ownership静态编译基线单列，不用其掩盖新增失败/skip。适量行为测试，不复制实现细节。

GUI用生产FavoritesPage和真实侧栏，最少浅深/当前组折叠/窄窗入口、多选保持、关闭重启保持；mouse/key后等稳定逐图读核。DISPLAY=:1 GDK_BACKEND=x11，隔离业务/cache/XDG于本轮/tmp；harness仅/tmp，main/runner不为fixture改，windowManager.ensureInitialized/show。helper先全文读核SHA，固定本轮title/PID/proc exe/fixture标志、命令白名单、坐标窗口和宿主矩形预检，按下finally释放；只操作本轮窗口。先xwininfo实际尺寸，宿主不足的完整RepaintBoundary图明确标注而非冒充完整X11。截图只/tmp不入库。末尾正常main --no-pub构建恢复、停自身fixture并独立ps/X11清理。

所有fvm前export https_proxy=http://127.0.0.1:7897 http_proxy=http://127.0.0.1:7897；fvm3.47.7，Flutter均--no-pub，原生LD_LIBRARY_PATH=$PWD/build/linux/x64/debug/bundle/lib。仅允许已知pdfrx缓存四处cache!环境补丁，不动lock。权限由architect逐项读屏代批，重复Flutter/已核对helper可申请合理窄前缀，不申请全局权限。

任务逐项勾选备注；delivery.md给出红绿/真实动作命令、各测试通过/失败/skip计数、analyze raw/unique50=38+12具体集合对照、改动/SHA/保护diff、diffcheck/OpenSpec、GUI场景与局限、正常构建清理。architect独立复核前不提交，owner验收前不归档，不push，不启动其他change。
