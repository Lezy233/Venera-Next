# F10 收藏作者优先、组内手动顺序

## Status

Owner已授权接续F9执行F10。本文及四件套为待确认草案：BACKLOG要求先确认多作者、缺作者及排序作用域；architect已提交建议，收到答复后将结论写入HEAD再派实现。executor不得按未确认草案实施。

## Why

现有收藏提供纯手动、收藏时间及作者名称排序；作者排序的同组作品按标题/id排列，不能在保持作者优先时手动调整组内顺序。现有系列页也没有这一模式。

## What Changes

- 本地收藏的全部/文件夹及系列视图新增「作者 → 手动顺序」，作者间名称升序，组内可拖动或上/下移并持久化。
- 建议沿用已有作者标签优先、首位有效作者和用户人工alias；缺作者组置末。显示分组不修改作者、不自动合并跨源实体。
- 建议每个文件夹/全部视图/系列独立记忆顺序；新增成员置组末，既有其他排序及其手动顺序保持。
- 持久化、来源身份、筛选、并发编辑与数据库/页面归属完整保护；组外移动不改作者，切换模式再回来和重启保持。

## Impact and Scope

入口为lib/features/favorites/favorite_filters.dart、local_favorites_page.dart、local_favorite_series_page.dart、comic_reorder_page.dart；存储涉及favorites_manager.dart/favorites_repository.dart及必要局部模型。只管理本地展示顺序，不回写网络收藏服务器，不进行作者实体自动合并，不扩展F11分类折叠/批量作者编辑。遵循design-spec.md §1–6，复用已有控件/token/主题，不统一美化或加依赖。
