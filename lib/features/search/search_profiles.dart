import 'package:flutter/material.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/foundation/translations.dart';
import 'search_profile.dart';
import 'search_page.dart' show SearchOptionWidget;

String _profileError(Object error) =>
    error is FormatException &&
        const {
          'Search profile name is empty',
          'Search profile name is too long',
          'Search profile name already exists',
        }.contains(error.message)
    ? error.message.toString().tl
    : 'Could not save search profile'.tl;

class SearchProfilesSettings extends StatefulWidget {
  const SearchProfilesSettings({super.key});
  @override
  State<SearchProfilesSettings> createState() => _SearchProfilesSettingsState();
}

class _SearchProfilesSettingsState extends State<SearchProfilesSettings> {
  final manager = SearchProfileManager.instance;
  @override
  void initState() {
    super.initState();
    manager.addListener(_changed);
  }

  @override
  void dispose() {
    manager.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<SearchProfile?> _nameDialog({SearchProfile? profile}) async {
    final controller = TextEditingController(text: profile?.name);
    var saving = false;
    SearchProfile? pending = profile;
    String? error;
    final route = DialogRoute<SearchProfile>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(
              (profile == null
                      ? 'Create search profile'
                      : 'Rename search profile')
                  .tl,
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              enabled: !saving,
              decoration: InputDecoration(
                labelText: 'Name'.tl,
                errorText: error,
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: Text('Cancel'.tl),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          SearchProfile saved;
                          if (pending == null) {
                            saved = await manager.create(
                              controller.text,
                              searchProfileSourcesFromGlobals(),
                            );
                          } else {
                            await manager.rename(pending!.id, controller.text);
                            saved = manager.byId(pending!.id)!;
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, saved);
                          }
                        } catch (failure) {
                          if (failure is SearchProfileSaveFailure) {
                            pending = failure.profile;
                          }
                          if (dialogContext.mounted) {
                            update(() {
                              saving = false;
                              error = _profileError(failure);
                            });
                          }
                        }
                      },
                child: Text('Save'.tl),
              ),
            ],
          ),
        ),
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    return result;
  }

  Future<void> _edit(SearchProfile profile) => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => SearchProfileEditor(profile: profile)),
  );
  Future<void> _run(Future<void> Function() change) async {
    try {
      await change();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_profileError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = manager.all;
    return CustomScrollView(
      slivers: [
        SliverAppbar(
          title: Text('Search profiles'.tl),
          actions: [
            IconButton(
              onPressed: () async {
                final profile = await _nameDialog();
                if (mounted && profile != null) await _edit(profile);
              },
              icon: const Icon(Icons.add),
              tooltip: 'Create search profile'.tl,
            ),
          ],
        ),
        if (profiles.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text('No search profiles'.tl),
            ),
          )
        else
          SliverList.builder(
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final selected = manager.defaultId == profile.id;
              return ListTile(
                leading: IconButton(
                  tooltip: 'Default search profile'.tl,
                  icon: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onPressed: () => _run(
                    () => manager.setDefault(selected ? null : profile.id),
                  ),
                ),
                title: Text(profile.name),
                subtitle: Text(
                  '${profile.sources.where((item) => item.enabled).length} ${'sources'.tl}',
                ),
                onTap: () => _edit(profile),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Manage search profile'.tl,
                  onSelected: (action) {
                    if (action == 'edit') {
                      _edit(profile);
                    } else if (action == 'rename') {
                      _nameDialog(profile: profile);
                    } else {
                      _run(() => manager.remove(profile.id));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('Edit'.tl)),
                    PopupMenuItem(value: 'rename', child: Text('Rename'.tl)),
                    PopupMenuItem(value: 'delete', child: Text('Delete'.tl)),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class SearchProfileEditor extends StatefulWidget {
  const SearchProfileEditor({super.key, required this.profile});
  final SearchProfile profile;
  @override
  State<SearchProfileEditor> createState() => _SearchProfileEditorState();
}

class _SearchProfileEditorState extends State<SearchProfileEditor> {
  late List<SearchProfileSource> entries;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    entries = [
      for (final entry in widget.profile.sources)
        SearchProfileSource(
          sourceKey: entry.sourceKey,
          enabled: entry.enabled,
          options: ComicSource.find(entry.sourceKey)?.searchPageData == null
              ? List.of(entry.options)
              : resolveSearchProfileOptions(
                  ComicSource.find(entry.sourceKey)!.searchPageData!,
                  entry.options,
                ),
        ),
      for (final source in ComicSource.all())
        if (source.searchPageData != null &&
            !widget.profile.sources.any((e) => e.sourceKey == source.key))
          SearchProfileSource(
            sourceKey: source.key,
            enabled: false,
            options: resolveSearchProfileOptions(source.searchPageData!, []),
          ),
    ];
  }

  void _change(int index, {bool? enabled, List<String>? options}) {
    final current = entries[index];
    setState(
      () => entries[index] = SearchProfileSource(
        sourceKey: current.sourceKey,
        enabled: enabled ?? current.enabled,
        options: options ?? current.options,
      ),
    );
  }

  void _move(int index, int delta) => setState(() {
    final entry = entries.removeAt(index);
    entries.insert(index + delta, entry);
  });
  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await SearchProfileManager.instance.update(widget.profile.id, entries);
      if (mounted) Navigator.pop(context);
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          error = _profileError(failure);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppbar(
            title: Text(widget.profile.name),
            actions: [
              TextButton(
                onPressed: saving ? null : _save,
                child: Text('Save'.tl),
              ),
            ],
          ),
          if (error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          SliverList.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final source = ComicSource.find(entry.sourceKey);
              final schema =
                  source?.searchPageData?.searchOptions ??
                  const <SearchOptions>[];
              final effectiveOptions = source?.searchPageData == null
                  ? entry.options
                  : resolveSearchProfileOptions(
                      source!.searchPageData!,
                      entry.options,
                    );
              final label = source == null
                  ? entry.sourceKey
                  : ComicSource.all()
                            .where((e) => e.name == source.name)
                            .length >
                        1
                  ? '${source.name} · ${source.key}'
                  : source.name;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    title: Text(label),
                    subtitle: source?.searchPageData == null
                        ? Text('Source unavailable'.tl)
                        : null,
                    value: entry.enabled,
                    onChanged: saving
                        ? null
                        : (value) => _change(index, enabled: value),
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Move up'.tl,
                        onPressed: saving || index == 0
                            ? null
                            : () => _move(index, -1),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        tooltip: 'Move down'.tl,
                        onPressed: saving || index == entries.length - 1
                            ? null
                            : () => _move(index, 1),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                    ],
                  ),
                  if (entry.enabled)
                    IgnorePointer(
                      ignoring: saving,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < schema.length; i++)
                              SearchOptionWidget(
                                option: schema[i],
                                value: effectiveOptions[i],
                                sourceKey: entry.sourceKey,
                                onChanged: (value) {
                                  final values = List<String>.of(
                                    effectiveOptions,
                                  );
                                  values[i] = value;
                                  _change(index, options: values);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  const Divider(height: AppSizes.hairline),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
