# F10 v2.2 作者分栏卡片悬停补修

## 本轮边界与历史

2026-11-06 owner反馈作者分栏漫画缺少悬停背景提示，要求安排修改；整体样式/交互美化仅登记BACKLOG UX1，未启动全局设计。当前按工作区v2.2四件套和派工SHA执行4.x，HEAD仍5977b8523b516893f70fb5fe660bef72cc524611。当前授权dirty保留，开局快照，不清理、stash或还原他人工作。

v2.1独立排序tasks3.x 5/5及独立809通过/2既有失败/0skip、analyze50、GUI重启/正常构建与清理记录保存在history/v2.1和delivery-v2.1/review-v2.1。独立排序已完成，本轮仅补D3.1可见悬停反馈；旧通过记录不代替新hover证据。每项完成立即勾选并备注，交付delivery-v2.2.md，历史文件保持。

## 4. 实现与验收

- [x] 4.1 核对HEAD、dirty授权清单、v2.2工件SHA及原21文件快照，读诊断/UI技能与design-spec相关token；在生产作者分栏以真实mouse move坐标建立可见背景缺失红灯，和普通卡片同主题/模式对照，记录真实绘制反馈及业务路由/写入/请求为0，明确实际根因，不能只调回调或查状态变量。2026-11-06：四工件SHA全OK、HEAD5977b85、原21文件MATCH；/tmp/f10-v22-before.{patch,sha256}及untracked-before.tar保存授权dirty。真实mouse标题(138.7,267)、最终RGBA采样(2,325)，同主题/模式普通ComicTile 4277665791→4109235711，shelf保持4277665791；/tmp/f10-v22-red.log为0通过1目标失败0skip，实际mainNavigator仅首页1/主动作0/SQLite触发器写审计0/A-B请求[0,0]。ink-probe确认真实Ink已hovered，Material单变量probe同坐标像素变色，证明局部ColoredBox遮住祖先Material ink，非长按指针拦截；仅剩关闭动画偏好失败。诊断/UI技能已读，动态SDK诊断已从最终测试移除；不改共享组件。
- [x] 4.2 最小修复作者分栏卡片背景反馈，遵循D3.1主题/token/几何不变和实例隔离；覆盖浅深×折叠/正常×详细/画廊、标题/封面/主区域、移入移出/邻卡/跨栏同漫画、选中态移出恢复、拖动结束/Escape后恢复。保留每栏独立序、点击恰一次/多选/右键/独立按钮/Shift横滚/焦点；真实渲染及动作计数测试转绿。优先局部修复；如必须改变共享ComicTile/ClickInkWell，先报告根因和影响供architect裁定。2026-11-06：architect批准并更新D3.1后，仅ComicTile新增默认null hoverColor透传原ClickInkWell，shelf传透明，不再覆写Theme；menu/gesture零修改。真实右键菜单红灯见menu-red.log，修复后浅深两布局两模式8格菜单最终像素与普通卡片完全相同，独立hover/选中/主区域/中间帧/关闭动画/展开尺寸/真实拖动及Escape后短击一次均通过；零时长AnimatedSize自布局重入通过局部关闭动画时直接布局修复，正常动画仍AppMotion.normal。/tmp/f10-v22-hover-fixed.log为8通过0失败0skip；补尺寸/短击断言后/tmp/f10-v22-regression-final.log为204通过0失败0skip，含原UI/layout/drag/independence、B4与共享卡片默认保护。4.3 GUI/最终analyze等尚待完成。
- [x] 4.3 完成新增hover与受影响作者栏UI/layout/drag/independence、B4等相关回归及analyze raw/unique50=38+12具体集合零新增；保留原断言，两既有失败与一静态编译排除如实列出。最终源码GUI提供浅深/折叠网格悬停前后稳定对照图，邻卡/跨栏隔离及动作/请求计数，截图只/tmp；正常main构建与自身fixture精确清理、protected/翻译/最终SHA/diffcheck/OpenSpec、delivery-v2.2齐全后等待architect独立复核。未受影响既有检查不无故重复；不提交/归档/push。2026-11-06：最终204通过0失败0skip；analyze raw/unique50=38+12，具体集合新增/移除均[]，architect独立确认。GUI两PID共29张原始RepaintBoundary图已逐图核对，完整1280×700与390×700/1.6，菜单/选中/两布局长按及实例隔离通过；计数、磁盘、截图SHA在/tmp/f10-v22-gui-evidence.json。470908退出143，仅确认SIGTERM且来源未知，不称产品崩溃或正常清理，BadWindow动作不作证据。正常main --no-pub构建成功，kernel SHA a8541badbcf8b7f2a827851a1dbc7fb8f0d1c5c3c0ff1fb0c1b5cecf0a8f08d0；仅TERM核对过的自身474220后ps无两PID、helper fixtures=[]，architect独立X11确认。保护/翻译/diffcheck/OpenSpec通过；design变化仅architect D3.1授权。最终清单/tmp/f10-v22-final.sha256，命令/基线/限制详见delivery-v2.2.md。未提交/归档/push，待正式独立复核及owner验收。
