import 'dart:convert';

import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'sidebar_sections.dart';
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/file_save_task.dart';
import 'package:venera_next/components/gesture.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/pop_up_widget.dart';
import 'package:venera_next/components/window_selection_task.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/favorites/favorite_actions.dart';
import 'package:venera_next/features/favorites/favorites_constants.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/folder_order_dialog.dart';
import 'package:venera_next/features/favorites/comic_reorder_page.dart';
import 'package:venera_next/features/favorites/folder_rename_dialog.dart';
import 'package:venera_next/features/favorites/favorite_confirmation_dialog.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';
import 'package:venera_next/routing/settings.dart';
import 'favorite_series.dart';

abstract interface class FolderList {
  void update();

  void updateFolders();
}

class FavoritesFolderSidebar extends StatefulWidget {
  const FavoritesFolderSidebar({
    super.key,
    required this.selectedFolder,
    required this.isNetworkSelected,
    required this.onFolderSelected,
    this.selectedSeries,
    this.onSeriesSelected,
    this.onFolderListReady,
    this.onSelected,
    this.withAppbar = false,
    this.sections,
    this.onSectionChanged,
  });

  final String? selectedFolder;

  final bool isNetworkSelected;

  final void Function(bool isNetwork, String? folder) onFolderSelected;
  final String? selectedSeries;
  final ValueChanged<String?>? onSeriesSelected;

  final ValueChanged<FolderList>? onFolderListReady;

  final VoidCallback? onSelected;

  final bool withAppbar;
  final FavoriteSidebarSections? sections;
  final void Function(FavoriteSidebarSection, bool)? onSectionChanged;

  @override
  State<FavoritesFolderSidebar> createState() => _FavoritesFolderSidebarState();
}

class _FavoritesFolderSidebarState extends State<FavoritesFolderSidebar>
    with ContextMenuOwner
    implements FolderList {
  var folders = <String>[];

  var networkFolders = <String>[];
  late final FavoriteStoreBinding _store;
  late final LocalFavoritesManager _manager;
  late final int _managerGeneration;
  late final FavoriteSidebarSections _sections;
  final _headerFocus = {
    for (final section in FavoriteSidebarSection.values) section: FocusNode(),
  };
  final _groupFocus = {
    for (final section in FavoriteSidebarSection.values)
      section: FocusScopeNode(),
  };
  final _focusedHeaders = <FavoriteSidebarSection>{};

  void _sectionsChanged() {
    if (!mounted) return;
    for (final section in FavoriteSidebarSection.values) {
      if (!_sections.expanded(section) && _groupFocus[section]!.hasFocus) {
        _headerFocus[section]!.requestFocus();
      }
    }
    setState(() {});
  }

  void _setExpanded(FavoriteSidebarSection section, bool expanded) {
    if (widget.onSectionChanged case final change?) {
      change(section, expanded);
    } else {
      _sections.setExpanded(section, expanded);
    }
  }

  bool get _hasManager =>
      _store.isCurrent && _manager.connectionGeneration == _managerGeneration;

  void findNetworkFolders() {
    networkFolders.clear();
    var all = ComicSource.all()
        .where((e) => e.favoriteData != null)
        .map((e) => e.favoriteData!.key)
        .toList();
    var settings = GlobalPreferenceStore(
      appdata.settings,
    ).read(DiscoveryPreferences.favoritePages);
    for (var p in settings) {
      if (all.contains(p) && !networkFolders.contains(p)) {
        networkFolders.add(p);
      }
    }
  }

  @override
  void initState() {
    _sections = widget.sections ?? FavoriteSidebarSections(null);
    _sections.addListener(_sectionsChanged);
    _store = FavoritesScope.capture(context);
    _manager = _store.manager;
    _managerGeneration = _manager.connectionGeneration;
    widget.onFolderListReady?.call(this);
    folders = _manager.folderNames;
    findNetworkFolders();
    appdata.settings.addListener(updateFolders);
    _manager.addListener(updateFolders);
    super.initState();
  }

  @override
  void dispose() {
    _sections.removeListener(_sectionsChanged);
    if (widget.sections == null) _sections.dispose();
    for (final node in _headerFocus.values) {
      node.dispose();
    }
    for (final node in _groupFocus.values) {
      node.dispose();
    }
    appdata.settings.removeListener(updateFolders);
    _manager.removeListener(updateFolders);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: context.colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
      ),
      child: Column(
        children: [
          if (widget.withAppbar)
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const CloseButton(),
                  const SizedBox(width: 8),
                  Text("Folders".tl, style: ts.s18),
                ],
              ),
            ).paddingTop(context.padding.top),
          Expanded(
            child: ListView(
              padding: widget.withAppbar
                  ? EdgeInsets.zero
                  : EdgeInsets.only(top: context.padding.top),
              children: [
                _group(FavoriteSidebarSection.local, buildLocalTitle(), [
                  if (_sections.expanded(FavoriteSidebarSection.local)) ...[
                    buildLocalFolder(localAllFolderLabel),
                    for (final folder in folders) buildLocalFolder(folder),
                  ],
                ]),
                _group(FavoriteSidebarSection.series, buildSeriesTitle(), [
                  if (_sections.expanded(FavoriteSidebarSection.series))
                    for (final series in _manager.series) buildSeries(series),
                ]),
                _group(FavoriteSidebarSection.network, buildNetworkTitle(), [
                  if (_sections.expanded(FavoriteSidebarSection.network))
                    for (final folder in networkFolders)
                      buildNetworkFolder(folder),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(
    FavoriteSidebarSection section,
    Widget title,
    List<Widget> items,
  ) => FocusScope(
    node: _groupFocus[section],
    child: Column(children: [title, ...items]),
  );

  String? _currentName(FavoriteSidebarSection section) {
    final series = _manager.seriesById(widget.selectedSeries ?? '');
    if (series != null) {
      return section == FavoriteSidebarSection.series ? series.name : null;
    }
    final folder = widget.selectedFolder;
    if (folder == null) return null;
    if (widget.isNetworkSelected) {
      return section == FavoriteSidebarSection.network &&
              networkFolders.contains(folder)
          ? getFavoriteDataOrNull(folder)?.title
          : null;
    }
    return section == FavoriteSidebarSection.local &&
            (folder == localAllFolderLabel || folders.contains(folder))
        ? (folder == localAllFolderLabel
              ? 'All'.tl
              : getFavoriteDataOrNull(folder)?.title ?? folder)
        : null;
  }

  Widget _sectionHeader(
    FavoriteSidebarSection section,
    String title,
    IconData icon,
    Widget action,
  ) {
    final expanded = _sections.expanded(section);
    final current = expanded ? null : _currentName(section);
    void toggle() => _setExpanded(section, !expanded);
    final scheme = context.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: [
              title,
              ?current,
              (expanded ? 'Collapse' : 'Expand').tl,
            ].join('\n'),
            child: Semantics(
              label: [title, ?current].join(', '),
              button: true,
              expanded: expanded,
              selected: current != null,
              onTap: toggle,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                      _setExpanded(section, false),
                  const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                      _setExpanded(section, true),
                },
                child: FocusableActionDetector(
                  focusNode: _headerFocus[section],
                  onShowFocusHighlight: (focused) => setState(() {
                    if (focused) {
                      _focusedHeaders.add(section);
                    } else {
                      _focusedHeaders.remove(section);
                    }
                  }),
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                  },
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        toggle();
                        return null;
                      },
                    ),
                  },
                  child: ExcludeSemantics(
                    child: Material(
                      color: current != null
                          ? scheme.primaryContainer.withValues(
                              alpha: AppOpacity.selectedContainer,
                            )
                          : scheme.surface.withValues(alpha: 0),
                      child: InkWell(
                        canRequestFocus: false,
                        onTap: toggle,
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: AppSizes.navItemSize,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                width: AppSizes.settingsSelectedIndicatorWidth,
                                color: current != null
                                    ? scheme.primary
                                    : scheme.primary.withValues(alpha: 0),
                              ),
                              bottom: BorderSide(
                                width: AppSizes.hairline,
                                color: _focusedHeaders.contains(section)
                                    ? scheme.primary
                                    : scheme.primary.withValues(alpha: 0),
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                expanded
                                    ? Icons.expand_more
                                    : Icons.chevron_right,
                                size: AppSizes.shellIconSize,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(icon, size: AppSizes.shellIconSize),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (current != null)
                                      Text(
                                        current,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: AppFontSize.bodySmall,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        action,
      ],
    );
  }

  Widget buildSeriesTitle() => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: context.colorScheme.outlineVariant, width: 0.6),
      ),
    ),
    child: _sectionHeader(
      FavoriteSidebarSection.series,
      'Series'.tl,
      Icons.collections_bookmark_outlined,
      MenuButton(
        entries: [
          MenuEntry(
            icon: Icons.add,
            text: 'Create series'.tl,
            onClick: () => _createSeries(context),
          ),
          if (widget.selectedSeries != null)
            MenuEntry(
              icon: Icons.edit,
              text: 'Rename series'.tl,
              onClick: () => _renameSeries(context),
            ),
          if (widget.selectedSeries != null)
            MenuEntry(
              icon: Icons.delete_outline,
              text: 'Delete series'.tl,
              onClick: () => _deleteSeries(context),
            ),
          MenuEntry(
            icon: Icons.sort,
            text: 'Sort series'.tl,
            onClick: () => _sortSeries(),
          ),
        ],
      ),
    ),
  );

  Widget buildSeries(FavoriteSeries series) {
    final selected = widget.selectedSeries == series.id;
    return ClickInkWell(
      onTap: () {
        widget.onSeriesSelected?.call(series.id);
        widget.onSelected?.call();
      },
      child: Container(
        height: 42,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: selected
              ? context.colorScheme.primaryContainer.toOpacity(0.36)
              : null,
          border: Border(
            left: BorderSide(
              color: selected
                  ? context.colorScheme.primary
                  : context.colorScheme.surface.withValues(alpha: 0),
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Expanded(child: Text(series.name)),
            Text(_manager.seriesMemberIdentities(series.id).length.toString()),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  void _showFolderContextMenu(String folder, Offset position) {
    if (!_hasManager || !_manager.existsFolder(folder)) return;
    contextMenus.show(context, position, [
      MenuEntry(
        icon: Icons.edit_outlined,
        text: 'Rename'.tl,
        onClick: () {
          renameFavoriteFolder(
            context,
            manager: _manager,
            folder: folder,
            isCurrent: () => _hasManager && _manager.existsFolder(folder),
            onRenamed: (name) {
              updateFolders();
              if (widget.selectedFolder == folder &&
                  !widget.isNetworkSelected) {
                widget.onFolderSelected(false, name);
              }
            },
          );
        },
      ),
      MenuEntry(
        icon: Icons.reorder,
        text: 'Reorder'.tl,
        onClick: () {
          reorderFavoriteComics(
            context,
            manager: _manager,
            folder: folder,
            isCurrent: () => _hasManager && _manager.existsFolder(folder),
          );
        },
      ),
      MenuEntry(
        icon: Icons.upload_file,
        text: 'Export'.tl,
        onClick: () {
          if (!_hasManager || !_manager.existsFolder(folder)) return;
          saveFileForWindow(
            context,
            data: utf8.encode(_manager.folderToJson(folder)),
            filename: '$folder.json',
          );
        },
      ),
      MenuEntry(
        icon: Icons.delete_outline,
        text: 'Delete Folder'.tl,
        color: context.colorScheme.error,
        onClick: () {
          confirmFavoriteMutation(
            context: context,
            manager: _manager,
            folder: folder,
            title: 'Delete'.tl,
            content: "Delete folder '@f' ?".tlParams({'f': folder}),
            btnColor: context.colorScheme.error,
            isCurrent: () => _hasManager && _manager.existsFolder(folder),
            mutate: () => _manager.deleteFolder(folder),
            onCommitted: () {
              updateFolders();
              if (widget.selectedFolder == folder &&
                  !widget.isNetworkSelected) {
                widget.onFolderSelected(false, null);
              }
            },
          );
        },
      ),
    ], isValid: () => _hasManager && _manager.existsFolder(folder));
  }

  Future<void> _createSeries(BuildContext context) async {
    final name = await _askSeriesName(context, 'Create series'.tl);
    if (name == null || !_hasManager) return;
    try {
      await _manager.createSeries(name);
      updateFolders();
    } catch (error) {
      if (context.mounted) {
        context.showMessage(message: favoriteSeriesErrorMessage(error));
      }
    }
  }

  Future<void> _renameSeries(BuildContext context) async {
    final id = widget.selectedSeries;
    final current = id == null ? null : _manager.seriesById(id);
    if (current == null) return;
    final name = await _askSeriesName(
      context,
      'Rename series'.tl,
      current.name,
    );
    if (name == null || !_hasManager) return;
    try {
      await _manager.renameSeries(id!, name);
      updateFolders();
    } catch (error) {
      if (context.mounted) {
        context.showMessage(message: favoriteSeriesErrorMessage(error));
      }
    }
  }

  Future<void> _deleteSeries(BuildContext context) async {
    final id = widget.selectedSeries;
    if (id == null || !_hasManager) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete series'.tl),
        content: Text('Delete this series?'.tl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tl),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'.tl),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _manager.deleteSeries(id);
      widget.onSeriesSelected?.call(null);
      updateFolders();
    }
  }

  Future<void> _sortSeries() async {
    if (!_hasManager) return;
    final sorted = _manager.series.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _manager.reorderSeries(sorted.map((item) => item.id).toList());
    updateFolders();
  }

  Future<String?> _askSeriesName(
    BuildContext context,
    String title, [
    String initial = '',
  ]) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tl),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Save'.tl),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Widget buildLocalTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _sectionHeader(
        FavoriteSidebarSection.local,
        'Local'.tl,
        Icons.local_activity,
        MenuButton(
          entries: [
            MenuEntry(
              icon: Icons.add,
              text: 'Create Folder'.tl,
              onClick: () {
                if (!_hasManager) return;
                newFolder(
                  context,
                  onChanged: (next) {
                    if (!mounted || !_hasManager) return;
                    setState(() => folders = next);
                  },
                );
              },
            ),
            MenuEntry(
              icon: Icons.reorder,
              text: 'Sort'.tl,
              onClick: () {
                if (!_hasManager) return;
                final owner = WindowSelectionTask(context);
                if (!owner.canPresent) return;
                sortFolders(context).then<void>(
                  (_) {
                    if (owner.canPresent && _hasManager) updateFolders();
                  },
                  onError: (Object error, StackTrace stack) {
                    Log.error('Favorite folder list', error, stack);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNetworkTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.colorScheme.outlineVariant,
            width: 0.6,
          ),
        ),
      ),
      child: _sectionHeader(
        FavoriteSidebarSection.network,
        'Network'.tl,
        Icons.cloud,
        IconButton(
          tooltip: 'Settings'.tl,
          icon: const Icon(Icons.settings),
          onPressed: () {
            showPopUpWidget(
              appNavigation.rootContext,
              setFavoritesPagesWidget(),
            );
          },
        ),
      ),
    );
  }

  Widget buildLocalFolder(String name) {
    bool isSelected =
        name == widget.selectedFolder && !widget.isNetworkSelected;
    int count = 0;
    if (_hasManager) {
      count = name == localAllFolderLabel
          ? _manager.totalComics
          : _manager.folderComics(name);
    }
    var folderName = name == localAllFolderLabel
        ? "All".tl
        : getFavoriteDataOrNull(name)?.title ?? name;
    return ClickInkWell(
      onTap: () {
        if (isSelected) {
          return;
        }
        widget.onFolderSelected(false, name);
        widget.onSelected?.call();
      },
      onSecondaryTapDown: name == localAllFolderLabel
          ? null
          : (details) => _showFolderContextMenu(name, details.globalPosition),
      child: Container(
        height: 42,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primaryContainer.toOpacity(0.36)
              : null,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? context.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Expanded(child: Text(folderName)),
            Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(count.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNetworkFolder(String key) {
    var data = getFavoriteDataOrNull(key);
    if (data == null) {
      return const SizedBox();
    }
    bool isSelected = key == widget.selectedFolder && widget.isNetworkSelected;
    return ClickInkWell(
      onTap: () {
        if (isSelected) {
          return;
        }
        widget.onFolderSelected(true, key);
        widget.onSelected?.call();
      },
      child: Container(
        height: 42,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primaryContainer.toOpacity(0.36)
              : null,
          border: Border(
            left: BorderSide(
              color: isSelected
                  ? context.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 16),
        child: Text(data.title),
      ),
    );
  }

  @override
  void update() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void updateFolders() {
    if (!mounted || !_hasManager) return;
    setState(() {
      folders = _manager.folderNames;
      findNetworkFolders();
    });
  }
}
