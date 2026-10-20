import 'package:venera_next/features/history/history_scope.dart';
import 'package:venera_next/features/favorites/favorites_scope.dart';
import 'package:venera_next/foundation/global_preference_store.dart';
import 'package:venera_next/foundation/application_preferences.dart';
import 'package:venera_next/components/file_save_task.dart';
import 'favorite_models.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/button.dart';
import 'package:venera_next/components/flyout.dart';
import 'package:venera_next/components/menu.dart';
import 'package:venera_next/components/message.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/components/select.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/components/sidebar_resize_handle.dart';
import 'package:venera_next/components/window_selection_task.dart';
import 'package:venera_next/features/comic_details/comic_details.dart';
import 'package:venera_next/features/comic_source/comic_source.dart';
import 'package:venera_next/features/comic_widgets/comic_widgets.dart';
import 'package:venera_next/app_shell/desktop_chrome.dart';
import 'package:venera_next/features/favorites/author_management_dialog.dart';
import 'package:venera_next/features/favorites/favorite_actions.dart';
import 'package:venera_next/features/favorites/favorite_filters.dart';
import 'package:venera_next/features/favorites/favorites_display.dart';
import 'package:venera_next/features/favorites/favorites_constants.dart';
import 'package:venera_next/features/favorites/favorites_manager.dart';
import 'package:venera_next/features/favorites/comic_reorder_page.dart';
import 'package:venera_next/features/favorites/folder_rename_dialog.dart';
import 'package:venera_next/features/favorites/favorite_confirmation_dialog.dart';
import 'package:venera_next/features/favorites/favorite_transfer_dialog.dart';
import 'package:venera_next/features/favorites/favorite_metadata_dialog.dart';
import 'package:venera_next/features/local_comics/local_comics.dart';
import 'package:venera_next/features/reader/reader.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/app_data_operations.dart';
import 'package:venera_next/foundation/selection_operation.dart';
import 'package:venera_next/routing/app_navigation.dart';
import 'package:venera_next/foundation/app_locale.dart';
import 'package:venera_next/foundation/log.dart';
import 'package:venera_next/foundation/navigation_admission.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/comic_type.dart';
import 'package:venera_next/foundation/consts.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/opencc.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';

/// If the number of comics in a folder exceeds this limit, it will be
/// fetched asynchronously.
const _asyncDataFetchLimit = 500;

class LocalFavoritesPage extends StatefulWidget {
  const LocalFavoritesPage({
    required this.folder,
    required this.showFolders,
    required this.onFolderSelected,
    required this.updateFolderList,
    this.importFolder = importNetworkFolder,
    super.key,
  });

  final String folder;
  final VoidCallback showFolders;
  final void Function(bool isNetwork, String? folder) onFolderSelected;
  final VoidCallback updateFolderList;
  final Future<void> Function(
    BuildContext context,
    String source,
    int pages,
    String folder,
    String remoteFolder,
  )
  importFolder;

  @override
  State<LocalFavoritesPage> createState() => _LocalFavoritesPageState();
}

class _LocalFavoritesPageState extends State<LocalFavoritesPage> {
  late List<FavoriteItem> comics;

  String? networkSource;
  String? networkFolder;

  Map<Comic, bool> selectedComics = {};

  String keyword = "";
  bool searchHasUpper = false;

  bool searchMode = false;

  bool multiSelectMode = false;

  DesktopChromeController? _chrome;
  late final VoidCallback _toggleRightCallback = _toggleFilterPanel;
  late final VoidCallback _searchCallback = _focusSearch;

  int? lastSelectedIndex;

  bool get isAllFolder => widget.folder == localAllFolderLabel;

  LocalFavoritesManager get manager => _store.manager;

  late final FavoriteStoreBinding _store;

  late final LocalFavoritesManager _observedManager;
  late final int _observedGeneration;
  late final String _observedDataPath;
  WindowSelectionTask? _queryOwner;
  final _metadataTasks = <WindowSelectionTask>{};

  Map<String, String> get _authorAliases {
    final stored = appdata.implicitData['local_favorites_author_aliases'];
    if (stored is! Map) return const {};
    return {
      for (final entry in stored.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  bool get _canReadObservedFolder =>
      mounted &&
      _queryOwner?.active == true &&
      _store.isCurrent &&
      _observedManager.connectionGeneration == _observedGeneration &&
      App.dataPath == _observedDataPath;

  bool isLoading = false;
  int _queryGeneration = 0;
  int _filterRequest = 0;
  ModalRoute<dynamic>? _updateFlyoutRoute;
  Object? _loadError;

  late String readFilterSelect;

  late Set<String> authorFilters;

  late Set<String> tagFilters;

  late String sortMode;

  late double _filterPanelWidth;

  late bool _filterPanelOpen;

  late double _filterAuthorShare;

  late bool _authorSectionExpanded;

  late bool _tagSectionExpanded;

  bool _resizingFilterPanel = false;

  static const _kFilterPanelBreakpoint = 900.0;
  static const _kFilterPanelMinWidth = 260.0;
  static const _kFilterPanelMaxWidth = 460.0;

  static Set<String> _readFilterValues(Object? value) =>
      value is List ? value.whereType<String>().toSet() : <String>{};

  String _storedSortMode() {
    final modes = appdata.implicitData['local_favorites_sort_modes'];
    final stored = modes is Map ? modes[widget.folder] : null;
    return stored is String && favoriteSortModes.contains(stored)
        ? stored
        : favoriteSortModes.first;
  }

  var searchResults = <FavoriteItem>[];

  void updateSearchResult() {
    setState(() {
      if (keyword.trim().isEmpty) {
        searchResults = comics;
      } else {
        searchResults = [];
        for (var comic in comics) {
          if (matchKeyword(keyword, comic) ||
              matchKeywordT(keyword, comic) ||
              matchKeywordS(keyword, comic)) {
            searchResults.add(comic);
          }
        }
      }
    });
  }

  void updateComics() {
    if (!_canReadObservedFolder) return;
    final manager = _observedManager;
    final generation = ++_queryGeneration;
    final folder = widget.folder;
    _loadError = null;
    isLoading = false;
    try {
      final count = isAllFolder
          ? manager.totalComics
          : manager.folderComics(folder);
      if (!isAllFolder && !manager.existsFolder(folder)) {
        comics = [];
      } else if (count < _asyncDataFetchLimit) {
        comics = isAllFolder
            ? manager.getAllComics()
            : manager.getFolderComics(folder);
      } else {
        isLoading = true;
        final reading = isAllFolder
            ? manager.getAllComicsAsync()
            : manager.getFolderComicsAsync(folder);
        unawaited(
          reading.then<void>(
            (value) {
              if (!_canReadObservedFolder ||
                  generation != _queryGeneration ||
                  widget.folder != folder) {
                return;
              }
              setState(() {
                isLoading = false;
                comics = value;
              });
            },
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites query', error, stack);
              if (!_canReadObservedFolder ||
                  generation != _queryGeneration ||
                  widget.folder != folder) {
                return;
              }
              setState(() {
                isLoading = false;
                _loadError = error;
              });
            },
          ),
        );
      }
    } catch (error, stack) {
      Log.error('Favorites query', error, stack);
      _loadError = error;
    }
    setState(() {});
  }

  List<FavoriteItem> filterComics(List<FavoriteItem> curComics) {
    return curComics.where((comic) {
      if (authorFilters.isNotEmpty &&
          !favoriteAuthorValues(
            comic,
            aliases: _authorAliases,
          ).any(authorFilters.contains)) {
        return false;
      }
      if (tagFilters.isNotEmpty && !_matchesTagFilters(comic)) {
        return false;
      }
      var history = HistoryScope.read(
        context,
      ).find(comic.id, ComicType(comic.sourceKey.hashCode));
      if (readFilterSelect == "UnCompleted") {
        return history == null || history.page != history.maxPage;
      } else if (readFilterSelect == "Completed") {
        return history != null && history.page == history.maxPage;
      }
      return true;
    }).toList();
  }

  bool _matchesTagFilters(FavoriteItem comic) {
    for (final tag in comic.tags) {
      if (tagFilters.contains(favoriteTagValue(tag)) ||
          tagFilters.contains(favoriteTagLabel(tag))) {
        return true;
      }
    }
    return false;
  }

  List<String> _collectFilterValues(Iterable<String> values) {
    final result = values.toSet().toList();
    result.sort();
    return result;
  }

  /// Keeps already selected values visible even when they are no longer in the
  /// aggregated options (for example a tag hidden by the new tag rules).
  List<String> _withSelected(List<String> available, Set<String> selected) =>
      _collectFilterValues([...available, ...selected]);

  void _applyAuthorAliases(Map<String, String> aliases) {
    final cleaned = <String, String>{
      for (final entry in aliases.entries)
        if (entry.value.isNotEmpty && entry.key != entry.value)
          entry.key: entry.value,
    };
    unawaited(
      appdata
          .updateImplicit((draft) {
            draft['local_favorites_author_aliases'] = cleaned;
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Favorite author aliases', error, stack);
            },
          ),
    );
    final mapped = authorFilters
        .map((value) => cleaned[value] ?? value)
        .toSet();
    setState(() {
      if (mapped.length != authorFilters.length ||
          !mapped.containsAll(authorFilters)) {
        authorFilters = mapped;
      }
    });
    if (mapped.length != authorFilters.length ||
        !mapped.containsAll(authorFilters)) {
      _persistFilters();
    }
  }

  void _persistFilters() {
    final readFilter = readFilterSelect;
    final authors = authorFilters.toList();
    final tags = tagFilters.toList();
    unawaited(
      appdata
          .updateImplicit((draft) {
            draft['local_favorites_read_filter'] = readFilter;
            draft['local_favorites_author_filter'] = authors;
            draft['local_favorites_tag_filter'] = tags;
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites filter', error, stack);
            },
          ),
    );
  }

  void _persistSortMode() {
    final folder = widget.folder;
    final mode = sortMode;
    final stored = appdata.implicitData['local_favorites_sort_modes'];
    final modes = <String, Object?>{
      if (stored is Map)
        for (final entry in stored.entries) '${entry.key}': entry.value,
      folder: mode,
    };
    unawaited(
      appdata
          .updateImplicit((draft) {
            draft['local_favorites_sort_modes'] = modes;
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites sort mode', error, stack);
            },
          ),
    );
  }

  void _setReadFilter(String value) {
    setState(() => readFilterSelect = value);
    _persistFilters();
    updateComics();
  }

  void _setSortMode(String value) {
    setState(() => sortMode = value);
    _persistSortMode();
  }

  void _toggleAuthorFilter(String value) {
    setState(() {
      if (!authorFilters.remove(value)) authorFilters.add(value);
    });
    _persistFilters();
  }

  void _toggleTagFilter(String value) {
    setState(() {
      if (!tagFilters.remove(value)) tagFilters.add(value);
    });
    _persistFilters();
  }

  void _setAuthorFilters(Set<String> value) {
    setState(() => authorFilters = Set<String>.of(value));
    _persistFilters();
  }

  void _setTagFilters(Set<String> value) {
    setState(() => tagFilters = Set<String>.of(value));
    _persistFilters();
  }

  void _setFilterAuthorShare(double value) {
    setState(() => _filterAuthorShare = value);
    unawaited(
      appdata
          .updateSettings((draft) {
            GlobalPreferenceStore(
              draft,
            ).write(LayoutPreferences.favoritesFilterAuthorShare, value);
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites filter section share', error, stack);
            },
          ),
    );
  }

  void _setAuthorSectionExpanded(bool value) {
    setState(() => _authorSectionExpanded = value);
    _persistSectionExpansion();
  }

  void _setTagSectionExpanded(bool value) {
    setState(() => _tagSectionExpanded = value);
    _persistSectionExpansion();
  }

  void _persistSectionExpansion() {
    final author = _authorSectionExpanded;
    final tag = _tagSectionExpanded;
    unawaited(
      appdata
          .updateImplicit((draft) {
            draft['local_favorites_author_expanded'] = author;
            draft['local_favorites_tag_expanded'] = tag;
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites filter sections', error, stack);
            },
          ),
    );
  }

  void _toggleFilterPanel() {
    setState(() => _filterPanelOpen = !_filterPanelOpen);
    _persistFilterPanel();
  }

  void _resizeFilterPanel(double delta) {
    setState(() {
      _resizingFilterPanel = true;
      if (!_filterPanelOpen) {
        if (delta >= 0) return;
        _filterPanelOpen = true;
        _filterPanelWidth = _kFilterPanelMinWidth;
        return;
      }
      final next = _filterPanelWidth - delta;
      if (next < _kFilterPanelMinWidth) {
        _filterPanelOpen = false;
        _filterPanelWidth = _kFilterPanelMinWidth;
        return;
      }
      _filterPanelWidth = next.clamp(
        _kFilterPanelMinWidth,
        _kFilterPanelMaxWidth,
      );
    });
  }

  void _finishFilterPanelResize() {
    if (_resizingFilterPanel) {
      setState(() => _resizingFilterPanel = false);
    }
    _persistFilterPanel();
  }

  void _persistFilterPanel() {
    final width = _filterPanelWidth;
    final open = _filterPanelOpen;
    unawaited(
      appdata
          .updateSettings((draft) {
            final store = GlobalPreferenceStore(draft);
            store.write(LayoutPreferences.favoritesFilterPanelWidth, width);
            store.write(LayoutPreferences.favoritesFilterPanelOpen, open);
          })
          .then<void>(
            (_) {},
            onError: (Object error, StackTrace stack) {
              Log.error('Favorites filter panel', error, stack);
            },
          ),
    );
  }

  List<String> _availableAuthors() => _collectFilterValues([
    for (final comic in comics)
      ...favoriteAuthorValues(comic, aliases: _authorAliases),
  ]);

  List<String> _availableTags() {
    final values = <String>[];
    for (final comic in comics) {
      for (final tag in comic.tags) {
        final separator = tag.indexOf(':');
        if (separator > 0 && isAuthorNamespace(tag.substring(0, separator))) {
          continue;
        }
        final label = favoriteTagLabel(tag);
        // Some sources use pure numeric tags; they are not useful filters.
        if (RegExp(r'^\d+$').hasMatch(label)) continue;
        values.add(label);
      }
    }
    return _collectFilterValues(values);
  }

  Widget _buildFilterPanel() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FilterSelectRow(
                    title: "Sort",
                    current: favoriteSortModeLabels[sortMode] ?? 'Manual',
                    values: [
                      for (final mode in favoriteSortModes)
                        favoriteSortModeLabels[mode] ?? 'Manual',
                    ],
                    enabled: true,
                    onSelected: (index) =>
                        _setSortMode(favoriteSortModes[index]),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _FilterSelectRow(
                    title: "Filter reading status",
                    current: readFilterSelect,
                    values: readFilterList,
                    enabled: true,
                    onSelected: (index) =>
                        _setReadFilter(readFilterList[index]),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _FilterSectionPanes(
                    authorOptions: _withSelected(
                      _availableAuthors(),
                      authorFilters,
                    ),
                    tagOptions: _withSelected(_availableTags(), tagFilters),
                    authors: authorFilters,
                    tags: tagFilters,
                    authorShare: _filterAuthorShare,
                    authorExpanded: _authorSectionExpanded,
                    tagExpanded: _tagSectionExpanded,
                    onAuthorsChanged: _setAuthorFilters,
                    onTagsChanged: _setTagFilters,
                    onAuthorShareChanged: _setFilterAuthorShare,
                    onAuthorExpandedChanged: _setAuthorSectionExpanded,
                    onTagExpandedChanged: _setTagSectionExpanded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyWithFilterPanel(Widget body) {
    if (context.width <= _kFilterPanelBreakpoint) return body;
    final open = _filterPanelOpen;
    return Stack(
      children: [
        Positioned.fill(right: open ? _filterPanelWidth : 0, child: body),
        if (open)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _filterPanelWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: context.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
              ),
              child: _buildFilterPanel(),
            ),
          ),
        Positioned(
          right: open ? _filterPanelWidth - SidebarResizeHandle.width / 2 : 0,
          top: 0,
          bottom: 0,
          width: SidebarResizeHandle.width,
          child: SidebarResizeHandle(
            mirror: true,
            expanded: open,
            onToggle: _toggleFilterPanel,
            onDrag: _resizeFilterPanel,
            onDragEnd: _finishFilterPanelResize,
          ),
        ),
      ],
    );
  }

  void _showFilterSheet() {
    final folder = widget.folder;
    final request = ++_filterRequest;
    bool isCurrent() =>
        mounted && widget.folder == folder && request == _filterRequest;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: _FavoriteFilterEditor(
                readFilter: readFilterSelect,
                sortMode: sortMode,
                authors: authorFilters,
                tags: tagFilters,
                authorOptions: _withSelected(
                  _availableAuthors(),
                  authorFilters,
                ),
                tagOptions: _withSelected(_availableTags(), tagFilters),
                editable: true,
                onReadFilter: (value) {
                  if (!isCurrent()) return;
                  _setReadFilter(value);
                },
                onSortMode: (value) {
                  if (!isCurrent()) return;
                  _setSortMode(value);
                },
                onAuthorToggle: (value) {
                  if (!isCurrent()) return;
                  _toggleAuthorFilter(value);
                },
                onTagToggle: (value) {
                  if (!isCurrent()) return;
                  _toggleTagFilter(value);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  bool matchKeyword(String keyword, FavoriteItem comic) {
    var list = keyword.split(" ");
    for (var k in list) {
      if (k.isEmpty) continue;
      if (checkKeyWordMatch(k, comic.title, false)) {
        continue;
      } else if (comic.subtitle != null &&
          checkKeyWordMatch(k, comic.subtitle!, false)) {
        continue;
      } else if (comic.tags.any((tag) {
        if (checkKeyWordMatch(k, tag, true)) {
          return true;
        } else if (tag.contains(':') &&
            checkKeyWordMatch(k, tag.split(':')[1], true)) {
          return true;
        } else if (appLocale.languageCode != 'en' &&
            checkKeyWordMatch(k, tag.translateTagsToCN, true)) {
          return true;
        }
        return false;
      })) {
        continue;
      } else if (checkKeyWordMatch(k, comic.author, true)) {
        continue;
      }
      return false;
    }
    return true;
  }

  bool checkKeyWordMatch(String keyword, String compare, bool needEqual) {
    String temp = compare;
    // 没有大写的话, 就转成小写比较, 避免搜索需要注意大小写
    if (!searchHasUpper) {
      temp = temp.toLowerCase();
    }
    if (needEqual) {
      return keyword == temp;
    }
    return temp.contains(keyword);
  }

  // Convert keyword to traditional Chinese to match comics
  bool matchKeywordT(String keyword, FavoriteItem comic) {
    if (!OpenCC.hasChineseSimplified(keyword)) {
      return false;
    }
    keyword = OpenCC.simplifiedToTraditional(keyword);
    return matchKeyword(keyword, comic);
  }

  // Convert keyword to simplified Chinese to match comics
  bool matchKeywordS(String keyword, FavoriteItem comic) {
    if (!OpenCC.hasChineseTraditional(keyword)) {
      return false;
    }
    keyword = OpenCC.traditionalToSimplified(keyword);
    return matchKeyword(keyword, comic);
  }

  @override
  void initState() {
    super.initState();
    _store = FavoritesScope.capture(context);
    _observedManager = _store.manager;
    _observedGeneration = _observedManager.connectionGeneration;
    _observedDataPath = App.dataPath;
    readFilterSelect =
        appdata.implicitData["local_favorites_read_filter"] ??
        readFilterList[0];
    authorFilters = _readFilterValues(
      appdata.implicitData['local_favorites_author_filter'],
    );
    tagFilters = _readFilterValues(
      appdata.implicitData['local_favorites_tag_filter'],
    );
    sortMode = _storedSortMode();
    final layout = GlobalPreferenceStore(appdata.settings);
    _filterPanelWidth = layout
        .read(LayoutPreferences.favoritesFilterPanelWidth)
        .toDouble();
    _filterPanelOpen = layout.read(LayoutPreferences.favoritesFilterPanelOpen);
    _filterAuthorShare = layout
        .read(LayoutPreferences.favoritesFilterAuthorShare)
        .toDouble();
    _authorSectionExpanded =
        appdata.implicitData['local_favorites_author_expanded'] != false;
    _tagSectionExpanded =
        appdata.implicitData['local_favorites_tag_expanded'] == true;
    if (!isAllFolder) {
      var (a, b) = _observedManager.findLinked(widget.folder);
      networkSource = a;
      networkFolder = b;
    } else {
      networkSource = null;
      networkFolder = null;
    }
    comics = [];
    _observedManager.addListener(updateComics);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chrome = DesktopChromeScope.maybeRead(context);
    _syncChrome();
    if (_queryOwner != null) return;
    _queryOwner = WindowSelectionTask(context);
    updateComics();
  }

  void _retireUpdateFlyout() {
    final route = _updateFlyoutRoute;
    _updateFlyoutRoute = null;
    scheduleMicrotask(() {
      final navigator = route?.navigator;
      if (navigator?.mounted == true && route!.isActive) {
        navigator!.removeRoute(route);
      }
    });
  }

  @override
  void didUpdateWidget(LocalFavoritesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.folder != widget.folder) {
      _cancelMetadataUpdates();
      _filterRequest++;
      sortMode = _storedSortMode();
      final linked = isAllFolder || !_canReadObservedFolder
          ? (null, null)
          : _observedManager.findLinked(widget.folder);
      networkSource = linked.$1;
      networkFolder = linked.$2;
      updateComics();
    }
    if (oldWidget.folder != widget.folder ||
        oldWidget.importFolder != widget.importFolder) {
      _retireUpdateFlyout();
    }
  }

  @override
  void dispose() {
    _chrome?.setRightSidebar(available: false, expanded: false);
    _chrome?.setFavoritesSearch(null);
    _cancelMetadataUpdates();
    _retireUpdateFlyout();
    _observedManager.removeListener(updateComics);
    scrollController.dispose();
    super.dispose();
  }

  void selectAll() {
    setState(() {
      if (searchMode) {
        selectedComics = searchResults.asMap().map((k, v) => MapEntry(v, true));
      } else {
        selectedComics = comics.asMap().map((k, v) => MapEntry(v, true));
      }
    });
  }

  void invertSelection() {
    setState(() {
      if (searchMode) {
        for (var c in searchResults) {
          if (selectedComics.containsKey(c)) {
            selectedComics.remove(c);
          } else {
            selectedComics[c] = true;
          }
        }
      } else {
        for (var c in comics) {
          if (selectedComics.containsKey(c)) {
            selectedComics.remove(c);
          } else {
            selectedComics[c] = true;
          }
        }
      }
    });
  }

  bool downloadComic(FavoriteItem c) {
    final library = LocalManager();
    var source = c.type.comicSource;
    if (source != null) {
      bool isDownloaded = library.isDownloaded(c.id, (c).type);
      if (isDownloaded) {
        return false;
      }
      library.addTask(
        ImagesDownloadTask(
          storage: library,
          source: source,
          comicId: c.id,
          comicTitle: c.title,
        ),
      );
      return true;
    }
    return false;
  }

  void downloadSelected() {
    int count = 0;
    for (var c in selectedComics.keys) {
      if (downloadComic(c as FavoriteItem)) {
        count++;
      }
    }
    if (count > 0) {
      context.showMessage(
        message: "Added @c comics to download queue.".tlParams({"c": count}),
      );
    }
  }

  var scrollController = ScrollController();

  void _syncChrome() {
    final chrome = _chrome;
    if (chrome == null) return;
    final wide =
        context.width > _kFilterPanelBreakpoint &&
        !searchMode &&
        !multiSelectMode;
    chrome.setRightSidebar(
      available: wide,
      expanded: _filterPanelOpen,
      toggle: _toggleRightCallback,
    );
    chrome.setFavoritesSearch(_searchCallback);
  }

  void _focusSearch() {
    if (!mounted || searchMode) return;
    setState(() => searchMode = true);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncChrome();
    });
    final target = widget;
    final selection = selectedComics.keys.cast<FavoriteItem>().toList();
    final selectedItems = selection.map((comic) => comic.detached()).toList();
    bool isCurrentSelection() =>
        _canReadObservedFolder &&
        widget.folder == target.folder &&
        multiSelectMode &&
        listEquals(selectedComics.keys.toList(), selection);
    var title = widget.folder;
    if (title == localAllFolderLabel) {
      title = "All".tl;
    }

    Widget body = SmoothCustomScrollView(
      controller: scrollController,
      slivers: [
        if (!searchMode && !multiSelectMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Folders".tl,
              child: context.width <= favoritesTwoPanelChangeWidth
                  ? IconButton(
                      icon: const Icon(Icons.menu),
                      color: context.colorScheme.primary,
                      onPressed: widget.showFolders,
                    )
                  : const SizedBox(),
            ),
            title: GestureDetector(
              onTap: context.width < favoritesTwoPanelChangeWidth
                  ? widget.showFolders
                  : null,
              child: Text(title),
            ),
            actions: [
              if (networkSource != null && !isAllFolder)
                Tooltip(
                  message: "Sync".tl,
                  child: Flyout(
                    flyoutBuilder: (context) {
                      final source = networkSource;
                      final remoteFolder = networkFolder;
                      if (source == null || remoteFolder == null) {
                        return const SizedBox.shrink();
                      }
                      final folder = widget.folder;
                      final importFolder = widget.importFolder;
                      final generation = _observedManager.connectionGeneration;
                      final route = ModalRoute.of(context);
                      if (!identical(_updateFlyoutRoute, route)) {
                        _updateFlyoutRoute = route;
                        route?.completed.then((_) {
                          if (identical(_updateFlyoutRoute, route)) {
                            _updateFlyoutRoute = null;
                          }
                        });
                      }
                      bool isCurrent() =>
                          _canReadObservedFolder &&
                          widget.folder == folder &&
                          widget.importFolder == importFolder &&
                          _observedManager.connectionGeneration == generation &&
                          _observedManager.findLinked(folder) ==
                              (source, remoteFolder) &&
                          NavigationAdmission.allows(this.context);
                      return _FavoriteFolderSyncPanel(
                        networkSource: source,
                        networkFolder: remoteFolder,
                        onUpdate: (pages) async {
                          if (!isCurrent()) return;
                          await importFolder(
                            this.context,
                            source,
                            pages,
                            folder,
                            remoteFolder,
                          );
                          if (isCurrent()) updateComics();
                        },
                      );
                    },
                    child: Builder(
                      builder: (context) {
                        return IconButton(
                          icon: const Icon(Icons.sync),
                          onPressed: () {
                            if (_updateFlyoutRoute == null &&
                                NavigationAdmission.allows(context)) {
                              Flyout.of(context).show();
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              const FavoriteDisplayButton(),
              // Narrow layouts no longer have the top-bar search box/panel
              // toggle, so keep the original inline actions there.
              if (context.width <= _kFilterPanelBreakpoint)
                Tooltip(
                  message: "Filter".tl,
                  child: IconButton(
                    icon: const Icon(Icons.sort_rounded),
                    color:
                        readFilterSelect != readFilterList[0] ||
                            authorFilters.isNotEmpty ||
                            tagFilters.isNotEmpty ||
                            !isManualFavoriteSort(sortMode)
                        ? context.colorScheme.primaryContainer
                        : null,
                    onPressed: () {
                      if (App.isMobile) {
                        _showFilterSheet();
                        return;
                      }
                      final folder = widget.folder;
                      final request = ++_filterRequest;
                      final availableAuthors = _availableAuthors();
                      final availableTags = _availableTags();
                      showDialog(
                        context: context,
                        builder: (context) {
                          return _LocalFavoritesFilterDialog(
                            folder: folder,
                            initReadFilterSelect: readFilterSelect,
                            initSortMode: sortMode,
                            initAuthors: authorFilters,
                            initTags: tagFilters,
                            availableAuthors: availableAuthors,
                            availableTags: availableTags,
                            updateConfig:
                                (readFilter, nextSortMode, authors, tags) {
                                  if (!mounted ||
                                      widget.folder != folder ||
                                      request != _filterRequest) {
                                    return;
                                  }
                                  setState(() {
                                    readFilterSelect = readFilter;
                                    sortMode = nextSortMode;
                                    authorFilters = authors;
                                    tagFilters = tags;
                                  });
                                  updateComics();
                                },
                          );
                        },
                      );
                    },
                  ),
                ),
              if (context.width <= _kFilterPanelBreakpoint)
                Tooltip(
                  message: "Search".tl,
                  child: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() {
                        keyword = "";
                        searchMode = true;
                        updateSearchResult();
                      });
                    },
                  ),
                ),
              if (!isAllFolder)
                MenuButton(
                  entries: [
                    MenuEntry(
                      icon: Icons.edit_outlined,
                      text: "Rename".tl,
                      onClick: () {
                        renameFavoriteFolder(
                          context,
                          manager: _observedManager,
                          folder: target.folder,
                          isCurrent: () =>
                              _canReadObservedFolder &&
                              widget.folder == target.folder,
                          onRenamed: (name) {
                            target.updateFolderList();
                            if (_canReadObservedFolder &&
                                _queryOwner?.canPresent == true &&
                                widget.folder == target.folder) {
                              target.onFolderSelected(false, name);
                            }
                          },
                        );
                      },
                    ),
                    if (isManualFavoriteSort(sortMode))
                      MenuEntry(
                        icon: Icons.reorder,
                        text: "Reorder".tl,
                        onClick: () {
                          if (_queryOwner?.canPresent != true) return;
                          reorderFavoriteComics(
                            context,
                            manager: _observedManager,
                            folder: target.folder,
                            isCurrent: () =>
                                _canReadObservedFolder &&
                                widget.folder == target.folder,
                          );
                        },
                      ),
                    MenuEntry(
                      icon: Icons.upload_file,
                      text: "Export".tl,
                      onClick: () {
                        if (!_canReadObservedFolder ||
                            _queryOwner?.canPresent != true ||
                            widget.folder != target.folder) {
                          return;
                        }
                        final json = _observedManager.folderToJson(
                          target.folder,
                        );
                        saveFileForWindow(
                          context,
                          data: utf8.encode(json),
                          filename: "${target.folder}.json",
                        );
                      },
                    ),
                    MenuEntry(
                      icon: Icons.update,
                      text: "Update Comics Info".tl,
                      onClick: () {
                        if (_queryOwner?.canPresent != true ||
                            !_canReadObservedFolder ||
                            widget.folder != target.folder) {
                          return;
                        }
                        _refreshMetadata(context, target.folder);
                      },
                    ),
                    MenuEntry(
                      icon: Icons.people_outline,
                      text: "Manage authors".tl,
                      onClick: () {
                        if (_queryOwner?.canPresent != true) return;
                        showFavoriteAuthorManagementDialog(
                          context: context,
                          comics: _observedManager.getAllComics(),
                          aliases: _authorAliases,
                          isCurrent: () =>
                              _canReadObservedFolder &&
                              widget.folder == target.folder,
                          onChanged: _applyAuthorAliases,
                        );
                      },
                    ),
                    MenuEntry(
                      icon: Icons.delete_outline,
                      text: "Delete Folder".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        if (_queryOwner?.canPresent != true) return;
                        confirmFavoriteMutation(
                          context: context,
                          manager: _observedManager,
                          folder: target.folder,
                          title: "Delete".tl,
                          content: "Delete folder '@f' ?".tlParams({
                            "f": target.folder,
                          }),
                          btnColor: context.colorScheme.error,
                          isCurrent: () =>
                              _canReadObservedFolder &&
                              widget.folder == target.folder,
                          mutate: () =>
                              _observedManager.deleteFolder(target.folder),
                          onCommitted: () {
                            target.updateFolderList();
                            if (_canReadObservedFolder &&
                                _queryOwner?.canPresent == true &&
                                widget.folder == target.folder) {
                              target.onFolderSelected(false, null);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
            ],
          )
        else if (multiSelectMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    multiSelectMode = false;
                    selectedComics.clear();
                  });
                },
              ),
            ),
            title: Text(
              "Selected @c comics".tlParams({"c": selectedComics.length}),
            ),
            actions: [
              MenuButton(
                entries: [
                  if (!isAllFolder)
                    MenuEntry(
                      icon: Icons.drive_file_move,
                      text: "Move to folder".tl,
                      onClick: () {
                        if (_queryOwner?.canPresent != true ||
                            !isCurrentSelection()) {
                          return;
                        }
                        showFavoriteTransferDialog(
                          context: context,
                          manager: _observedManager,
                          source: target.folder,
                          comics: selectedItems,
                          move: true,
                          isCurrent: isCurrentSelection,
                          onCommitted: _cancel,
                        );
                      },
                    ),
                  if (!isAllFolder)
                    MenuEntry(
                      icon: Icons.copy,
                      text: "Copy to folder".tl,
                      onClick: () {
                        if (_queryOwner?.canPresent != true ||
                            !isCurrentSelection()) {
                          return;
                        }
                        showFavoriteTransferDialog(
                          context: context,
                          manager: _observedManager,
                          source: target.folder,
                          comics: selectedItems,
                          move: false,
                          isCurrent: isCurrentSelection,
                          onCommitted: _cancel,
                        );
                      },
                    ),
                  MenuEntry(
                    icon: Icons.select_all,
                    text: "Select All".tl,
                    onClick: selectAll,
                  ),
                  MenuEntry(
                    icon: Icons.deselect,
                    text: "Deselect".tl,
                    onClick: _cancel,
                  ),
                  MenuEntry(
                    icon: Icons.flip,
                    text: "Invert Selection".tl,
                    onClick: invertSelection,
                  ),
                  if (!isAllFolder)
                    MenuEntry(
                      icon: Icons.delete_outline,
                      text: "Delete Comic".tl,
                      color: context.colorScheme.error,
                      onClick: () {
                        if (_queryOwner?.canPresent != true ||
                            !isCurrentSelection()) {
                          return;
                        }
                        confirmFavoriteMutation(
                          context: context,
                          manager: _observedManager,
                          folder: target.folder,
                          title: "Delete".tl,
                          content: "Delete @c comics?".tlParams({
                            "c": selectedItems.length,
                          }),
                          btnColor: context.colorScheme.error,
                          isCurrent: isCurrentSelection,
                          mutate: () => _observedManager.batchDeleteComics(
                            target.folder,
                            selectedItems,
                          ),
                          onCommitted: _cancel,
                        );
                      },
                    ),
                  MenuEntry(
                    icon: Icons.download,
                    text: "Download".tl,
                    onClick: downloadSelected,
                  ),
                  if (selectedComics.length == 1)
                    MenuEntry(
                      icon: Icons.copy,
                      text: "Copy Title".tl,
                      onClick: () {
                        Clipboard.setData(
                          ClipboardData(text: selectedComics.keys.first.title),
                        );
                        context.showMessage(message: "Copied".tl);
                      },
                    ),
                  if (selectedComics.length == 1)
                    MenuEntry(
                      icon: Icons.chrome_reader_mode_outlined,
                      text: "Read".tl,
                      onClick: () {
                        final c = selectedComics.keys.first as FavoriteItem;
                        appNavigation.rootContext.to(
                          () => ReaderWithLoading(
                            id: c.id,
                            sourceKey: c.sourceKey,
                          ),
                        );
                      },
                    ),
                  if (selectedComics.length == 1)
                    MenuEntry(
                      icon: Icons.arrow_forward_ios,
                      text: "Jump to Detail".tl,
                      onClick: () {
                        final c = selectedComics.keys.first as FavoriteItem;
                        appNavigation.mainNavigatorKey?.currentContext?.to(
                          () => ComicPage(id: c.id, sourceKey: c.sourceKey),
                        );
                      },
                    ),
                ],
              ),
            ],
          )
        else if (searchMode)
          SliverAppbar(
            style: context.width < changePoint
                ? AppbarStyle.shadow
                : AppbarStyle.blur,
            leading: Tooltip(
              message: "Cancel".tl,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    setState(() {
                      searchMode = false;
                    });
                  });
                },
              ),
            ),
            title: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search".tl,
                border: UnderlineInputBorder(),
              ),
              onChanged: (v) {
                keyword = v;
                searchHasUpper = keyword.contains(RegExp(r'[A-Z]'));
                updateSearchResult();
              },
            ).paddingBottom(8).paddingRight(8),
          ),
        if (_loadError != null)
          SliverToBoxAdapter(
            child: Column(
              children: [
                Text(_loadError.toString()),
                TextButton(onPressed: updateComics, child: Text('Retry'.tl)),
              ],
            ),
          )
        else if (isLoading)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: const Center(child: CircularProgressIndicator()),
            ),
          )
        else
          SliverGridComics(
            comics: sortFavoriteItems(
              filterComics(searchMode ? searchResults : comics),
              sortMode,
              aliases: _authorAliases,
            ),
            selections: selectedComics,
            useFavoriteDisplaySettings: true,
            menuBuilder: (c) {
              final authors = favoriteAuthorValues(c);
              return [
                if (authors.isNotEmpty)
                  MenuEntry(
                    icon: Icons.person_search,
                    text: "Filter by author".tl,
                    onClick: () {
                      setState(() {
                        authorFilters = authors.toSet();
                      });
                      _persistFilters();
                    },
                  ),
                if (!isAllFolder)
                  MenuEntry(
                    icon: Icons.delete,
                    text: "Delete".tl,
                    onClick: () async {
                      if (!_canReadObservedFolder ||
                          _queryOwner?.canPresent != true ||
                          widget.folder != target.folder) {
                        return;
                      }
                      final item = (c as FavoriteItem).detached();
                      final owner = WindowSelectionTask(context);
                      try {
                        await owner.run<void>((operation) async {
                          operation.checkActive();
                          await AppDataOperations.instance.access(() async {
                            // An accepted deletion may outlive its page, but
                            // cannot enter a replacement database after queuing.
                            if (!_store.isCurrent ||
                                _observedManager.connectionGeneration !=
                                    _observedGeneration ||
                                App.dataPath != _observedDataPath ||
                                !_observedManager.existsFolder(target.folder)) {
                              throw const SelectionCancelled();
                            }
                            await _observedManager.deleteComicWithId(
                              target.folder,
                              item.id,
                              item.type,
                            );
                          });
                        }, reportFailureOnClose: true);
                      } on SelectionCancelled {
                        // The original caller or database retired before admission.
                      } catch (error, stack) {
                        Log.error('Delete favorite', error, stack);
                        if (context.mounted &&
                            owner.canPresent &&
                            _canReadObservedFolder &&
                            widget.folder == target.folder) {
                          context.showMessage(message: error.toString());
                        }
                      }
                    },
                  ),
                MenuEntry(
                  icon: Icons.check,
                  text: "Select".tl,
                  onClick: () {
                    setState(() {
                      if (!multiSelectMode) {
                        multiSelectMode = true;
                      }
                      if (selectedComics.containsKey(c as FavoriteItem)) {
                        selectedComics.remove(c);
                        _checkExitSelectMode();
                      } else {
                        selectedComics[c] = true;
                      }
                      lastSelectedIndex = comics.indexOf(c);
                    });
                  },
                ),
                MenuEntry(
                  icon: Icons.download,
                  text: "Download".tl,
                  onClick: () {
                    downloadComic(c as FavoriteItem);
                    context.showMessage(message: "Download started".tl);
                  },
                ),
                if (GlobalPreferenceStore(
                      appdata.settings,
                    ).read(FavoritePreferences.onClickFavorite) ==
                    "viewDetail")
                  MenuEntry(
                    icon: Icons.menu_book_outlined,
                    text: "Read".tl,
                    onClick: () {
                      appNavigation.mainNavigatorKey?.currentContext?.to(
                        () =>
                            ReaderWithLoading(id: c.id, sourceKey: c.sourceKey),
                      );
                    },
                  ),
              ];
            },
            onTap: (c, heroID) {
              if (multiSelectMode) {
                setState(() {
                  if (selectedComics.containsKey(c as FavoriteItem)) {
                    selectedComics.remove(c);
                    _checkExitSelectMode();
                  } else {
                    selectedComics[c] = true;
                  }
                  lastSelectedIndex = comics.indexOf(c);
                });
              } else if (GlobalPreferenceStore(
                    appdata.settings,
                  ).read(FavoritePreferences.onClickFavorite) ==
                  "viewDetail") {
                appNavigation.mainNavigatorKey?.currentContext?.to(
                  () => ComicPage(
                    id: c.id,
                    sourceKey: c.sourceKey,
                    cover: c.cover,
                    title: c.title,
                    heroID: heroID,
                  ),
                );
              } else {
                appNavigation.mainNavigatorKey?.currentContext?.to(
                  () => ReaderWithLoading(id: c.id, sourceKey: c.sourceKey),
                );
              }
            },
            onLongPressed: (c, heroID) {
              setState(() {
                if (!multiSelectMode) {
                  multiSelectMode = true;
                  if (!selectedComics.containsKey(c as FavoriteItem)) {
                    selectedComics[c] = true;
                  }
                  lastSelectedIndex = comics.indexOf(c);
                } else {
                  if (lastSelectedIndex != null) {
                    int start = lastSelectedIndex!;
                    int end = comics.indexOf(c as FavoriteItem);
                    if (start > end) {
                      int temp = start;
                      start = end;
                      end = temp;
                    }

                    for (int i = start; i <= end; i++) {
                      if (i == lastSelectedIndex) continue;

                      var comic = comics[i];
                      if (selectedComics.containsKey(comic)) {
                        selectedComics.remove(comic);
                      } else {
                        selectedComics[comic] = true;
                      }
                    }
                  }
                  lastSelectedIndex = comics.indexOf(c as FavoriteItem);
                }
                _checkExitSelectMode();
              });
            },
          ),
      ],
    );
    body = AppScrollBar(
      topPadding: 48,
      controller: scrollController,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: body,
      ),
    );
    return PopScope(
      canPop: !multiSelectMode && !searchMode,
      onPopInvokedWithResult: (didPop, result) {
        if (multiSelectMode) {
          setState(() {
            multiSelectMode = false;
            selectedComics.clear();
          });
        } else if (searchMode) {
          setState(() {
            searchMode = false;
            keyword = "";
            updateComics();
          });
        }
      },
      child: _buildBodyWithFilterPanel(body),
    );
  }

  void _cancelMetadataUpdates() {
    for (final task in _metadataTasks.toList()) {
      task.cancel();
    }
  }

  void _refreshMetadata(BuildContext context, String folder) {
    final owner = WindowSelectionTask(context);
    _metadataTasks.add(owner);
    final result = showFavoriteMetadataDialog(
      context: context,
      owner: owner,
      manager: _observedManager,
      folder: folder,
      isCurrent: () => _canReadObservedFolder && widget.folder == folder,
    );
    unawaited(
      result.then<void>(
        (_) {
          _metadataTasks.remove(owner);
        },
        onError: (Object error, StackTrace stack) {
          // Presentation reports its original error and host; consume this page's
          // completion without transferring that failure to another page.
          _metadataTasks.remove(owner);
        },
      ),
    );
  }

  void _checkExitSelectMode() {
    if (selectedComics.isEmpty) {
      setState(() {
        multiSelectMode = false;
      });
    }
  }

  void _cancel() {
    setState(() {
      selectedComics.clear();
      multiSelectMode = false;
    });
  }
}

class _FavoriteFolderSyncPanel extends StatefulWidget {
  const _FavoriteFolderSyncPanel({
    required this.networkSource,
    required this.networkFolder,
    required this.onUpdate,
  });

  final Future<void> Function(int pages) onUpdate;
  final String networkFolder;
  final String networkSource;

  @override
  State<_FavoriteFolderSyncPanel> createState() =>
      _FavoriteFolderSyncPanelState();
}

class _FavoriteFolderSyncPanelState
    extends SettingsSaveState<_FavoriteFolderSyncPanel> {
  int updatePageNum = 9999999;
  bool startingUpdate = false;
  late final Future<void> Function(int) _update;

  Future<void> _submit() async {
    if (startingUpdate || !acceptsSettingsChanges) return;
    final pages = updatePageNum;
    final update = _update;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    setState(() => startingUpdate = true);
    try {
      await waitForSettingsSave();
      if (!mounted ||
          !acceptsSettingsChanges ||
          route?.isCurrent != true ||
          !NavigationAdmission.allows(context)) {
        return;
      }
      if (!await navigator.maybePop() || route?.isCurrent == true) return;
      await update(pages);
    } catch (error, stack) {
      Log.error('Favorite update settings', error, stack);
      if (mounted) context.showMessage(message: error.toString());
    } finally {
      if (mounted) setState(() => startingUpdate = false);
    }
  }

  String get _allPageText => 'All'.tl;

  static const pageCounts = [1, 2, 3, 5, 10, 20, 50, 100, 200, 9999999];

  @override
  void initState() {
    _update = widget.onUpdate;
    final stored = appdata.implicitData['local_favorites_update_page_num'];
    updatePageNum = stored is int && stored > 0 ? stored : 9999999;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var source = ComicSource.find(widget.networkSource);
    final sourceName = source?.name ?? widget.networkSource;
    var text = "The folder is Linked to @source".tlParams({
      "source": sourceName,
    });
    if (widget.networkFolder.isNotEmpty) {
      text += "\n${"Source Folder".tl}: ${widget.networkFolder}";
    }

    final target = (widget.networkSource, widget.networkFolder);
    return protectSettings(
      FlyoutContent(
        title: 'Sync'.tl,
        actions: [
          FilledButton(
            onPressed: startingUpdate ? null : _submit,
            child: Text('Update'.tl),
          ),
        ],
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text("Update the page number by the latest collection".tl),
                Select(
                  current: updatePageNum.toString() == '9999999'
                      ? _allPageText
                      : updatePageNum.toString(),
                  values: [
                    for (final value in pageCounts)
                      value == 9999999 ? _allPageText : '$value',
                  ],
                  minWidth: 48,
                  onTap: (index) {
                    if (!mounted ||
                        !acceptsSettingsChanges ||
                        startingUpdate ||
                        target !=
                            (widget.networkSource, widget.networkFolder) ||
                        index < 0 ||
                        index >= pageCounts.length) {
                      return;
                    }
                    final value = pageCounts[index];
                    setState(() {
                      updatePageNum = value;
                    });
                    saveSetting(
                      'local_favorites_update_page_num',
                      () => appdata.updateImplicit((draft) {
                        draft['local_favorites_update_page_num'] = value;
                      }),
                    );
                  },
                ),
              ],
            ),
            settingsSaveStatus,
          ],
        ),
      ),
    );
  }
}

class _LocalFavoritesFilterDialog extends StatefulWidget {
  const _LocalFavoritesFilterDialog({
    required this.folder,
    required this.initReadFilterSelect,
    required this.initSortMode,
    required this.initAuthors,
    required this.initTags,
    required this.availableAuthors,
    required this.availableTags,
    required this.updateConfig,
  });

  final String folder;
  final String initReadFilterSelect;
  final String initSortMode;
  final Set<String> initAuthors;
  final Set<String> initTags;
  final List<String> availableAuthors;
  final List<String> availableTags;
  final void Function(
    String readFilter,
    String sortMode,
    Set<String> authors,
    Set<String> tags,
  )
  updateConfig;

  @override
  State<_LocalFavoritesFilterDialog> createState() =>
      _LocalFavoritesFilterDialogState();
}

const readFilterList = ['All', 'UnCompleted', 'Completed'];

const favoriteSortModeLabels = {
  'manual': 'Manual',
  'timeNewest': 'Added (newest)',
  'timeOldest': 'Added (oldest)',
  'authorAsc': 'Author (A-Z)',
  'authorDesc': 'Author (Z-A)',
};

class _LocalFavoritesFilterDialogState
    extends SettingsSaveState<_LocalFavoritesFilterDialog> {
  List<String> optionTypes = ['Filter'];
  late var readFilter = widget.initReadFilterSelect;
  late var sortMode = widget.initSortMode;
  late final authors = <String>{...widget.initAuthors};
  late final tags = <String>{...widget.initTags};

  bool get _editable =>
      acceptsSettingsChanges && !savingSettings && !hasSettingsSaveError;

  List<String> _options(List<String> available, Set<String> selected) {
    final values = <String>{...available, ...selected}.toList();
    values.sort();
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final authorOptions = _options(widget.availableAuthors, authors);
    final tagOptions = _options(widget.availableTags, tags);
    Widget tabBar = Material(
      borderRadius: BorderRadius.circular(8),
      child: AppTabBar(
        key: PageStorageKey(optionTypes),
        tabs: optionTypes.map((e) => Tab(text: e.tl, key: Key(e))).toList(),
      ),
    ).paddingTop(context.padding.top);
    return protectSettings(
      ContentDialog(
        content: DefaultTabController(
          length: optionTypes.length,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tabBar,
              TabViewBody(
                children: [
                  _FavoriteFilterEditor(
                    readFilter: readFilter,
                    sortMode: sortMode,
                    authors: authors,
                    tags: tags,
                    authorOptions: authorOptions,
                    tagOptions: tagOptions,
                    editable: _editable,
                    onReadFilter: (value) => setState(() => readFilter = value),
                    onSortMode: (value) => setState(() => sortMode = value),
                    onAuthorToggle: (value) => setState(() {
                      if (!authors.remove(value)) authors.add(value);
                    }),
                    onTagToggle: (value) => setState(() {
                      if (!tags.remove(value)) tags.add(value);
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          settingsSaveStatus,
          TextButton(
            onPressed: savingSettings || hasSettingsSaveError
                ? null
                : () {
                    setState(() {
                      readFilter = readFilterList[0];
                      authors.clear();
                      tags.clear();
                    });
                  },
            child: Text("Clear".tl),
          ),
          FilledButton(
            onPressed: savingSettings || hasSettingsSaveError
                ? null
                : () {
                    final value = readFilter;
                    final selectedSortMode = sortMode;
                    final selectedAuthors = Set<String>.of(authors);
                    final selectedTags = Set<String>.of(tags);
                    final storedModes =
                        appdata.implicitData['local_favorites_sort_modes'];
                    final sortModes = <String, Object?>{
                      if (storedModes is Map)
                        for (final entry in storedModes.entries)
                          '${entry.key}': entry.value,
                      widget.folder: selectedSortMode,
                    };
                    saveSetting(
                      'local_favorites_filter',
                      () => appdata.updateImplicit((draft) {
                        draft['local_favorites_read_filter'] = value;
                        draft['local_favorites_author_filter'] = selectedAuthors
                            .toList();
                        draft['local_favorites_tag_filter'] = selectedTags
                            .toList();
                        draft['local_favorites_sort_modes'] = sortModes;
                      }),
                      onSaved: () {
                        widget.updateConfig(
                          value,
                          selectedSortMode,
                          selectedAuthors,
                          selectedTags,
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) leaveSettings();
                        });
                      },
                    );
                  },
            child: Text("Confirm".tl),
          ),
        ],
      ),
    );
  }
}

/// Shared presentation for the filter dialog, the right side panel and the
/// mobile bottom sheet. Hosts own persistence; this widget only edits values.

/// Shared presentation for the filter dialog, the right side panel and the
/// mobile bottom sheet. Hosts own persistence; this widget only edits values.
class _FavoriteFilterEditor extends StatelessWidget {
  const _FavoriteFilterEditor({
    required this.readFilter,
    required this.sortMode,
    required this.authors,
    required this.tags,
    required this.authorOptions,
    required this.tagOptions,
    required this.editable,
    required this.onReadFilter,
    required this.onSortMode,
    required this.onAuthorToggle,
    required this.onTagToggle,
  });

  final String readFilter;
  final String sortMode;
  final Set<String> authors;
  final Set<String> tags;
  final List<String> authorOptions;
  final List<String> tagOptions;
  final bool editable;
  final ValueChanged<String> onReadFilter;
  final ValueChanged<String> onSortMode;
  final ValueChanged<String> onAuthorToggle;
  final ValueChanged<String> onTagToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterSelectRow(
          title: "Sort",
          current: favoriteSortModeLabels[sortMode] ?? 'Manual',
          values: [
            for (final mode in favoriteSortModes)
              favoriteSortModeLabels[mode] ?? 'Manual',
          ],
          enabled: editable,
          onSelected: (index) => onSortMode(favoriteSortModes[index]),
        ),
        _FilterSelectRow(
          title: "Filter reading status",
          current: readFilter,
          values: readFilterList,
          enabled: editable,
          onSelected: (index) => onReadFilter(readFilterList[index]),
        ),
        _CollapsibleFilterChips(
          title: "Author",
          options: authorOptions,
          selected: authors,
          editable: editable,
          onToggle: onAuthorToggle,
        ),
        _CollapsibleFilterChips(
          title: "Tags",
          options: tagOptions,
          selected: tags,
          editable: editable,
          onToggle: onTagToggle,
        ),
      ],
    );
  }
}

/// One labelled dropdown row; sort and reading status share this shape.
const _kFilterHeadingStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
);

class _FilterSelectRow extends StatelessWidget {
  const _FilterSelectRow({
    required this.title,
    required this.current,
    required this.values,
    required this.enabled,
    required this.onSelected,
  });

  final String title;
  final String current;
  final List<String> values;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 48,
      title: Text(title.tl, style: _kFilterHeadingStyle),
      trailing: Select(
        current: current.tl,
        values: values.map((value) => value.tl).toList(),
        minWidth: 96,
        onTap: (index) {
          if (!enabled || index < 0 || index >= values.length) return;
          onSelected(index);
        },
      ),
    );
  }
}

/// A titled chip section that can be folded away independently.
class _CollapsibleFilterChips extends StatefulWidget {
  const _CollapsibleFilterChips({
    required this.title,
    required this.options,
    required this.selected,
    required this.editable,
    required this.onToggle,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final bool editable;
  final ValueChanged<String> onToggle;

  @override
  State<_CollapsibleFilterChips> createState() =>
      _CollapsibleFilterChipsState();
}

class _CollapsibleFilterChipsState extends State<_CollapsibleFilterChips> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(widget.title.tl),
          trailing: IconButton(
            tooltip: (expanded ? 'Collapse' : 'Expand').tl,
            icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onPressed: () => setState(() => expanded = !expanded),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final option in widget.options)
                      FilterChip(
                        label: Text(option),
                        selected: widget.selected.contains(option),
                        // Selected state is conveyed by colour, without a tick.
                        showCheckmark: false,
                        selectedColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        visualDensity: VisualDensity.compact,
                        onSelected: widget.editable
                            ? (_) => widget.onToggle(option)
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Two VSCode Explorer style sections for the right panel: collapsible headers,
/// a draggable splitter when both are open, per-section search and bulk select.
class _FilterSectionPanes extends StatefulWidget {
  const _FilterSectionPanes({
    required this.authorOptions,
    required this.tagOptions,
    required this.authors,
    required this.tags,
    required this.authorShare,
    required this.authorExpanded,
    required this.tagExpanded,
    required this.onAuthorsChanged,
    required this.onTagsChanged,
    required this.onAuthorShareChanged,
    required this.onAuthorExpandedChanged,
    required this.onTagExpandedChanged,
  });

  final List<String> authorOptions;
  final List<String> tagOptions;
  final Set<String> authors;
  final Set<String> tags;
  final double authorShare;
  final bool authorExpanded;
  final bool tagExpanded;
  final ValueChanged<Set<String>> onAuthorsChanged;
  final ValueChanged<Set<String>> onTagsChanged;
  final ValueChanged<double> onAuthorShareChanged;
  final ValueChanged<bool> onAuthorExpandedChanged;
  final ValueChanged<bool> onTagExpandedChanged;

  @override
  State<_FilterSectionPanes> createState() => _FilterSectionPanesState();
}

class _FilterSectionPanesState extends State<_FilterSectionPanes> {
  static const _headerHeight = 48.0;
  static const _splitterHeight = 8.0;
  static const _minShare = 0.2;
  static const _maxShare = 0.8;

  late double share = widget.authorShare.clamp(_minShare, _maxShare);
  final authorSearch = TextEditingController();
  final tagSearch = TextEditingController();
  String authorQuery = '';
  String tagQuery = '';

  @override
  void didUpdateWidget(covariant _FilterSectionPanes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authorShare != widget.authorShare) {
      share = widget.authorShare.clamp(_minShare, _maxShare);
    }
  }

  @override
  void dispose() {
    authorSearch.dispose();
    tagSearch.dispose();
    super.dispose();
  }

  List<String> _filtered(List<String> options, String query) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return options;
    return options
        .where((option) => option.toLowerCase().contains(keyword))
        .toList();
  }

  void _resize(double delta, double available) {
    if (available <= 0) return;
    setState(() {
      share = (share + delta / available).clamp(_minShare, _maxShare);
    });
  }

  void _endResize() => widget.onAuthorShareChanged(share);

  @override
  Widget build(BuildContext context) {
    final authorVisible = _filtered(widget.authorOptions, authorQuery);
    final tagVisible = _filtered(widget.tagOptions, tagQuery);
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxHeight;
        final bothExpanded = widget.authorExpanded && widget.tagExpanded;
        final double authorHeight;
        final double tagHeight;
        if (bothExpanded) {
          final available = math.max(
            0.0,
            total - 2 * _headerHeight - _splitterHeight,
          );
          final authorBody = available * share;
          authorHeight = _headerHeight + authorBody;
          tagHeight = _headerHeight + (available - authorBody);
        } else if (widget.authorExpanded) {
          authorHeight = math.max(_headerHeight, total - _headerHeight);
          tagHeight = _headerHeight;
        } else if (widget.tagExpanded) {
          authorHeight = _headerHeight;
          tagHeight = math.max(_headerHeight, total - _headerHeight);
        } else {
          authorHeight = _headerHeight;
          tagHeight = _headerHeight;
        }
        return Column(
          children: [
            _authorSection(
              expanded: widget.authorExpanded,
              onToggle: () =>
                  widget.onAuthorExpandedChanged(!widget.authorExpanded),
              options: authorVisible,
              controller: authorSearch,
              onQueryChanged: (value) => setState(() => authorQuery = value),
              height: authorHeight,
              divider: !bothExpanded,
            ),
            if (bothExpanded)
              MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) => _resize(
                    details.delta.dy,
                    math.max(1.0, total - 2 * _headerHeight - _splitterHeight),
                  ),
                  onVerticalDragEnd: (_) => _endResize(),
                  onVerticalDragCancel: _endResize,
                  child: SizedBox(
                    height: _splitterHeight,
                    child: Center(
                      child: Container(
                        height: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
            _section(
              title: "Tags",
              expanded: widget.tagExpanded,
              onToggle: () => widget.onTagExpandedChanged(!widget.tagExpanded),
              options: tagVisible,
              selected: widget.tags,
              controller: tagSearch,
              onQueryChanged: (value) => setState(() => tagQuery = value),
              onChanged: widget.onTagsChanged,
              height: tagHeight,
            ),
          ],
        );
      },
    );
  }

  Widget _authorSection({
    required bool expanded,
    required VoidCallback onToggle,
    required List<String> options,
    required TextEditingController controller,
    required ValueChanged<String> onQueryChanged,
    required double height,
    required bool divider,
  }) {
    final section = _section(
      title: "Author",
      expanded: expanded,
      onToggle: onToggle,
      options: options,
      selected: widget.authors,
      controller: controller,
      onQueryChanged: onQueryChanged,
      onChanged: widget.onAuthorsChanged,
      height: height,
    );
    if (!divider) return section;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: section,
    );
  }

  Widget _section({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required List<String> options,
    required Set<String> selected,
    required TextEditingController controller,
    required ValueChanged<String> onQueryChanged,
    required ValueChanged<Set<String>> onChanged,
    required double height,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          SizedBox(
            height: _headerHeight,
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  iconSize: 18,
                  tooltip: (expanded ? 'Collapse' : 'Expand').tl,
                  icon: Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                  ),
                  onPressed: onToggle,
                ),
                Expanded(
                  child: Text(
                    title.tl,
                    style: _kFilterHeadingStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${selected.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  iconSize: 16,
                  tooltip: 'Select all'.tl,
                  icon: const Icon(Icons.select_all),
                  onPressed: !expanded
                      ? null
                      : () {
                          final next = Set<String>.of(selected)
                            ..addAll(options);
                          onChanged(next);
                        },
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  iconSize: 16,
                  tooltip: 'Deselect all'.tl,
                  icon: const Icon(Icons.deselect),
                  onPressed: !expanded || selected.isEmpty
                      ? null
                      : () => onChanged(<String>{}),
                ),
              ],
            ),
          ),
          if (expanded)
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search'.tl,
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onChanged: onQueryChanged,
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: options.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No search results found'.tl,
                                style: const TextStyle(fontSize: 12),
                              ),
                            )
                          : Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final option in options)
                                  _chip(option, selected, onChanged),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    String option,
    Set<String> selected,
    ValueChanged<Set<String>> onChanged,
  ) {
    return FilterChip(
      label: Text(option, style: const TextStyle(fontSize: 12)),
      selected: selected.contains(option),
      showCheckmark: false,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        final next = Set<String>.of(selected);
        if (!next.remove(option)) next.add(option);
        onChanged(next);
      },
    );
  }
}
