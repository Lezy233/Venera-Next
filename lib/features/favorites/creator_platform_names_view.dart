import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/search/search_result_page.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/translations.dart';
import 'creator_platform_names.dart';
import 'favorites_scope.dart';

/// Shared by the production desktop pane and both compact filter editors.
class CreatorPlatformNamesView extends StatelessWidget {
  const CreatorPlatformNamesView({
    super.key,
    required this.creators,
    this.revision = 0,
    this.isCurrent,
  });
  final Set<String> creators;
  final int revision;
  final bool Function()? isCurrent;
  @override
  Widget build(BuildContext context) => creators.length != 1
      ? const SizedBox.shrink()
      : _CreatorPlatformTree(
          key: ValueKey(creators.single),
          creator: creators.single,
          revision: revision,
          isCurrent: isCurrent,
        );
}

class _CreatorPlatformTree extends StatefulWidget {
  const _CreatorPlatformTree({
    super.key,
    required this.creator,
    required this.revision,
    this.isCurrent,
  });
  final String creator;
  final int revision;
  final bool Function()? isCurrent;
  @override
  State<_CreatorPlatformTree> createState() => _CreatorPlatformTreeState();
}

class _CreatorPlatformTreeState extends State<_CreatorPlatformTree> {
  late final FavoriteStoreBinding binding;
  late final CreatorPlatformNamesStore store;
  bool loading = true;
  bool busy = false;
  String? error;
  bool get current =>
      mounted && binding.isCurrent && widget.isCurrent?.call() != false;
  @override
  void initState() {
    super.initState();
    binding = FavoritesScope.capture(context);
    store = CreatorPlatformNamesStore(
      binding.manager,
      isCurrent: () => current,
    );
    store.addListener(_changed);
    binding.manager.addListener(_reload);
    scheduleMicrotask(_reload);
  }

  @override
  void didUpdateWidget(covariant _CreatorPlatformTree oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) scheduleMicrotask(_reload);
  }

  void _changed() {
    if (current) setState(() {});
  }

  Future<void> _reload() async {
    try {
      await store.refresh();
      if (current) {
        setState(() {
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (current) {
        setState(() {
          loading = false;
          error = 'Could not load platform names'.tl;
        });
      }
    }
  }

  @override
  void dispose() {
    binding.manager.removeListener(_reload);
    store.removeListener(_changed);
    store.dispose();
    super.dispose();
  }

  String sourceLabel(ComicSource source) =>
      ComicSource.all().where((e) => e.name == source.name).length > 1
      ? '${source.name} · ${source.key}'
      : source.name;

  bool available(String key) => ComicSource.find(key)?.searchPageData != null;
  void _search(CreatorPlatformRow row) {
    if (!store.active) return;
    final source = ComicSource.find(row.sourceKey);
    if (source?.searchPageData == null) return;
    final defaults = [
      for (final option
          in source!.searchPageData!.searchOptions ?? const <SearchOptions>[])
        option.defaultValue,
    ];
    context.to(
      () => SearchResultPage(
        text: row.name,
        sourceKey: row.sourceKey,
        options: defaults,
      ),
    );
  }

  Future<void> _edit([CreatorPlatformRow? row]) async {
    if (!store.active || busy) return;
    final aliasSnapshot = jsonEncode(creatorAliases());
    final sources = ComicSource.all()
        .where((e) => e.searchPageData != null)
        .toList();
    final controller = TextEditingController(text: row?.name);
    String? selected = sources.any((e) => e.key == row?.sourceKey)
        ? row!.sourceKey
        : sources.firstOrNull?.key;
    String? validation;
    final route = DialogRoute<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            (row == null ? 'Add platform name' : 'Edit platform name').tl,
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sources.isEmpty)
                  Text('No searchable sources'.tl)
                else
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: 'Platform'.tl),
                    items: [
                      for (final source in sources)
                        DropdownMenuItem(
                          value: source.key,
                          child: Text(
                            sourceLabel(source),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => update(() => selected = value),
                  ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Platform name'.tl,
                    errorText: validation,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'.tl),
            ),
            FilledButton(
              onPressed: selected == null
                  ? null
                  : () {
                      if (controller.text.trim().isEmpty) {
                        update(() => validation = 'Platform name is empty'.tl);
                        return;
                      }
                      Navigator.pop(dialogContext, (
                        selected!,
                        controller.text.trim(),
                      ));
                    },
              child: Text('Save'.tl),
            ),
          ],
        ),
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    if (result == null ||
        !store.active ||
        jsonEncode(creatorAliases()) != aliasSnapshot) {
      return;
    }
    await _save(
      () => store.change(
        widget.creator,
        previous: row,
        sourceKey: result.$1,
        name: result.$2,
      ),
    );
  }

  Future<void> _save(Future<void> Function() change) async {
    if (!store.active || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await change();
    } catch (_) {
      if (current) setState(() => error = 'Could not save platform names'.tl);
    } finally {
      if (current) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<CreatorPlatformRow>>{};
    for (final row in store.rows(widget.creator)) {
      (groups[row.sourceKey] ??= []).add(row);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: AppSizes.hairline),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Creator platform names'.tl,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(widget.creator),
              TextButton.icon(
                onPressed: busy || loading ? null : _edit,
                icon: const Icon(Icons.add),
                label: Text('Add platform name'.tl),
              ),
            ],
          ),
        ),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text('No platform names'.tl),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final group in groups.entries)
          ExpansionTile(
            key: PageStorageKey((widget.creator, group.key)),
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            title: Text(
              ComicSource.find(group.key) == null
                  ? group.key
                  : sourceLabel(ComicSource.find(group.key)!),
            ),
            subtitle: available(group.key)
                ? null
                : Text('Source unavailable'.tl),
            children: [
              for (final row in group.value)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: row.name,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: available(row.sourceKey) && !busy
                              ? () => _search(row)
                              : null,
                          child: Text(row.name),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !busy,
                      tooltip: 'Manage platform name'.tl,
                      onSelected: (value) {
                        if (value == 'edit') {
                          _edit(row);
                        } else {
                          _save(
                            () => store.change(widget.creator, previous: row),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text('Edit'.tl)),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'.tl),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}
