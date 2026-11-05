# F10 文件夹作者分栏与三态交互（v2）

## Status

2026-11-05 owner替换原F10需求并要求派工。以BACKLOG「F10 替换需求 TODO」和本版四件套为准；v1单作者/独立rank契约作废，其工件和交付保留在history/v1，原未提交实现作为本轮输入保留。v1通过记录不代表v2完成。多作者重叠排序的冲突规则见design D4，等待owner裁定；其余工作可执行。

本轮不提交实现或归档/push。HEAD仍为5977b8523b516893f70fb5fe660bef72cc524611，工作区已有v1授权改动；本轮以派工时工作区v2四件套及SHA清单为契约，不能误读HEAD中的v1旧稿或清理脏改。

## Why

owner需要在文件夹内直接按作者浏览和整理漫画：纵向堆叠作者横栏，每栏可折叠、显示完整网格或展开平台名称。原F10平铺列表及独立排序编辑页不能满足此交互。

## What Changes

- 文件夹提供作者分栏视图；所有有效作者各有一栏，多作者漫画可跨栏出现，无作者归入最后的「未命名作者」。栏顺序沿文件夹成员排序首次出现位置，不提供栏间排序。
- 每栏折叠/正常/展开三态，按文件夹+作者可靠保存；折叠单行横滚，正常按现有封面列数网格，展开追加本地平台名称面板。
- 分离箭头、作者名称、Shift+滚轮及漫画长按拖动手势；直接在栏内重排现有folder order子序列。
- 平台名称仅在绑定来源普通搜索，选项取该来源当前默认；面板展示零网络，失效来源保留记录并禁用。

## Impact and Scope

仅具体本地收藏文件夹；全部收藏/系列/网络收藏不自动扩展此新布局。保留原排序模式与点击/多选/菜单/F7/F8行为。可复用或替换v1局部实现，但不以v1独立rank作为v2真相；不删除用户收藏或平台名称数据、不回写网络排序、不添加依赖、不统一美化、不启动F11。

入口：local_favorites_page.dart、favorite_filters.dart、favorites_manager.dart、favorites_repository.dart、creator_platform_names.dart、creator_platform_names_view.dart，必要的局部shelf组件/模型和comic_list.dart/comic_tile.dart复用接口。遵循design-spec.md §1–6，允许的界面结构变化仅为本需求作者分栏。
